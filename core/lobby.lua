-- core/lobby.lua

WAR.LOBBY_STATE = "none"

function WAR.LOBBY.create()
    -- Gamemode and related config set by selection screen; apply defaults for anything missing
    if not WAR.LOBBY.config.gamemode then WAR.LOBBY.config.gamemode = "vanilla" end
    if not WAR.LOBBY.config.lives    then WAR.LOBBY.config.lives    = 4 end
    -- seed intentionally not set here; the deck selector is where the host picks it,
    -- and the server calls gen_seed() when none is provided.

    local ok, err = WAR.NET.connect()
    if not ok then return false, err end

    WAR.LOBBY_STATE = "hosting"
    local mod_ver, smods_ver = WAR.mod_versions()
    WAR.NET.send({
        action        = "create",
        gamemode      = WAR.LOBBY.config.gamemode,
        pfp           = WAR.AVATAR and WAR.AVATAR.selected or "default",
        mod_version   = mod_ver,
        smods_version = smods_ver,
    })
    -- code arrives async via sync.lua dispatch (action="created")
    return true
end

function WAR.LOBBY.join(code)
    WAR.LOBBY_STATE = "joining"
    local ok, err = WAR.NET.connect()
    if not ok then WAR.LOBBY_STATE = "none"; return false, err end
    local mod_ver, smods_ver = WAR.mod_versions()
    WAR.NET.send({ action="join", code=code:upper():gsub("%s",""),
                   pfp = WAR.AVATAR and WAR.AVATAR.selected or "default",
                   mod_version = mod_ver, smods_version = smods_ver })
    -- confirmation arrives async (action="joined")
    return true
end

-- Send the whole option set so the relay's copy matches the host's defaults
-- the moment the lobby exists (the toggles only send on change).
function WAR.LOBBY.push_config()
    local cfg = WAR.LOBBY.config
    WAR.NET.send({
        action                  = "config",
        lives                   = cfg.lives or 4,
        death_on_round_loss     = cfg.death_on_round_loss ~= false,
        hide_score_until_played = cfg.hide_score_until_played == true,
        comeback_gold           = cfg.comeback_gold ~= false,
        pvp_start_ante          = cfg.pvp_start_ante or 3,
        gamemode                = cfg.gamemode or "vanilla",
        ruleset                 = cfg.ruleset or "standard",
        timer_seconds           = cfg.timer_seconds or 0,
        pvp_boss_effects        = cfg.pvp_boss_effects ~= false,
        back                    = cfg.back or "Red Deck",
        stake                   = cfg.stake or 1,
        sleeve                  = cfg.sleeve or "",
    })
end

function WAR.LOBBY.leave()
    if WAR.UI and WAR.UI.exit_war_profile then WAR.UI.exit_war_profile() end
    WAR.NET.send({ action = "leave" })
    WAR.NET.disconnect()
    WAR.LOBBY.code    = nil
    WAR.LOBBY.is_host = false
    WAR.LOBBY_STATE   = "none"
    WAR.GAME.active   = false
    WAR.MODIFIERS     = {}
end

print("[WAR] lobby loaded")
