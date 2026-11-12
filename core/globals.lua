-- core/globals.lua

WAR.log = WAR.log or function() end

WAR.RULESETS = {}

-- Ban lists are plain data on layers, gamemodes and rulesets. A gamemode or
-- ruleset composes layers and may add its own on top; resolution unions the
-- arrays left to right and lets later scalars win (BMP's layer model, sized to
-- what War actually has).
WAR.BAN_CATEGORIES = {
    { field = "banned_jokers",       set = "Joker",      label = "war_bans_jokers" },
    { field = "banned_consumables",  set = "Consumable", label = "war_bans_consumables" },
    { field = "banned_vouchers",     set = "Voucher",    label = "war_bans_vouchers" },
    { field = "banned_enhancements", set = "Enhanced",   label = "war_bans_enhancements" },
    { field = "banned_tags",         set = "Tag",        label = "war_bans_tags" },
    { field = "banned_blinds",       set = "Blind",      label = "war_bans_blinds" },
}

WAR.LAYERS    = {}
WAR.MODIFIERS = {}   -- runtime-only layer names, applied after the ruleset

function WAR.Layer(name, def)
    def = def or {}
    def.key = def.key or name
    WAR.LAYERS[name] = def
    return def
end

local LAYER_ARRAYS  = { "banned_jokers", "banned_consumables", "banned_vouchers",
                        "banned_enhancements", "banned_tags", "banned_blinds" }
local LAYER_SCALARS = { "multiplayer_content", "standard", "on_apply_bans" }

local function merge_layer(src, dst)
    for _, f in ipairs(LAYER_ARRAYS) do
        local list = dst[f]
        if not list then list = {}; dst[f] = list end
        for _, k in ipairs(src[f] or {}) do list[#list + 1] = k end
    end
    for _, f in ipairs(LAYER_SCALARS) do
        if src[f] ~= nil then dst[f] = src[f] end
    end
end

-- Definition -> [layer, layer, ..., definition, modifier, modifier]
function WAR.layer_chain(def)
    local chain = {}
    for _, name in ipairs(def and def.layers or {}) do chain[#chain + 1] = name end
    if def then chain[#chain + 1] = def end
    for _, name in ipairs(WAR.MODIFIERS) do
        local mod = WAR.LAYERS[name]
        if mod then chain[#chain + 1] = mod end
    end
    return chain
end

function WAR.resolve(def)
    if not def then return nil end
    local out = { key = def.key, name = def.name, description = def.description }
    for _, src in ipairs(WAR.layer_chain(def)) do
        if type(src) == "string" then
            local name = src
            src = WAR.LAYERS[name]
            if not src then print("[WAR] unknown layer: " .. tostring(name)) end
        end
        if src then merge_layer(src, out) end
    end
    return out
end

function WAR.resolve_gamemode(key) return WAR.resolve(WAR.GAMEMODES and WAR.GAMEMODES[key or ""]) end
function WAR.resolve_ruleset(key) return WAR.resolve(WAR.RULESETS[key or ""]) end

function WAR.has_modifier(name)
    for _, n in ipairs(WAR.MODIFIERS) do if n == name then return true end end
    return false
end

function WAR.add_modifier(name)
    if not (name and WAR.LAYERS[name]) then return false end
    if WAR.has_modifier(name) then return false end
    WAR.MODIFIERS[#WAR.MODIFIERS + 1] = name
    return true
end

function WAR.remove_modifier(name)
    for i = #WAR.MODIFIERS, 1, -1 do
        if WAR.MODIFIERS[i] == name then table.remove(WAR.MODIFIERS, i); return true end
    end
    return false
end

WAR.RULESETS["standard"] = {
    key         = "standard",
    name        = "war_rs_standard_name",
    description = { "war_rs_standard_desc_1", "war_rs_standard_desc_2" },
    layers      = {},
    -- Nothing is banned: a rival round is a real vanilla boss with the rival
    -- layered on top, so Chicot / Luchador / boss rerolls act on the boss half
    -- and stay legal. Add fields here (or to a layer) to ban things again.
}

-- Every banned key from a gamemode + ruleset pair, as key -> true.
function WAR.banned_keys_for(gm_key, rs_key)
    local out = {}
    for _, src in ipairs({ WAR.resolve_gamemode(gm_key), WAR.resolve_ruleset(rs_key) }) do
        for _, cat in ipairs(WAR.BAN_CATEGORIES) do
            for _, k in ipairs(src and src[cat.field] or {}) do
                out[k] = true
            end
        end
    end
    return out
end

-- G.CHALLENGES is a plain array, but vanilla hands out both numeric indices
-- (challenge list buttons) and id strings (run config) for the same entry.
function WAR.challenge_by_id(ref)
    if not (ref and G and G.CHALLENGES) then return nil end
    if type(ref) == "number" then return G.CHALLENGES[ref] end
    for _, c in ipairs(G.CHALLENGES) do
        if c.id == ref then return c end
    end
    if get_challenge_int_from_id then
        local i = get_challenge_int_from_id(ref)
        if i and i > 0 then return G.CHALLENGES[i] end
    end
end

WAR.LOBBY = {
    code        = nil,
    is_host     = false,
    config      = {
        lives                  = 4,
        pvp_start_ante         = 3,
        death_on_round_loss    = true,
        hide_score_until_played = false,
        comeback_gold          = true,
        timer_seconds          = 90,
        pvp_boss_effects       = true,  -- false = boss blind effects suppressed during PvP
        back                   = "Red Deck",
        stake                  = 1,
        -- sleeve = nil by default (no sleeve)
    },
    -- display refs for lobby bar DynaText
    host_name   = nil,
    guest_name  = nil,
    ready       = false,
}

WAR.GAME = {
    active          = false,
    my_lives        = 0,
    my_score        = 0,
    -- enemy state (updated live from enemyInfo)
    enemy_score         = 0,
    enemy_score_display = 0,   -- animated display value; eases toward enemy_score
    _score_ease         = nil, -- {from, to, start, dur} set by on_enemy_info; nil = no ease running
    enemy_masked        = false, -- relay withheld the rival's score (noScore)
    enemy_hands     = 0,
    enemy_hands_masked = false, -- hand count hidden until the first enemyInfo
    enemy_stats     = nil,      -- { jokers, consumables, deck } from enemyStats
    enemy_skips     = 0,
    enemy_lives     = 0,
    enemy_location  = "",
    -- blind state
    is_pvp_blind     = false,   -- set by startBlind, cleared when the round resolves
    end_pvp_pending  = false,   -- set when endPvP arrives; cleared when state advances
    pvp_lost         = false,   -- set by on_end_pvp; used for comeback gold
    non_pvp_failed   = false,   -- set when failRound is sent; used for comeback gold
    _blind_chips_target = nil,  -- original chip requirement saved before Mr. Bones can modify it
    _pending_blind_e = nil,    -- stored e from intercepted select_blind
    _blind_starting  = false,  -- flag: re-entering select_blind from startBlind
    round_ended      = false,  -- duplicate end_round guard, cleared by new_round
}

-- ease_lives({ my = N, enemy = N }) — set either/both sides' lives and sync.
-- Plays the right sounds when lives drop. Pass no_sync=true from relay message
-- handlers to avoid the setLives → playerInfo → ease_lives → setLives loop.
function WAR.GAME.ease_lives(opts, no_sync)
    opts = opts or {}
    if opts.my ~= nil then
        local before = WAR.GAME.my_lives
        WAR.GAME.my_lives = tonumber(opts.my) or WAR.GAME.my_lives
        if before and WAR.GAME.my_lives < before then
            if WAR.UI and WAR.UI.tell then
                WAR.UI.tell(localize('war_life_lost'))
            end
            play_sound("cancel", 0.9,   0.7)
            play_sound("holo1",  0.865, 0.6)
        end
    end
    if opts.enemy ~= nil then
        local before = WAR.GAME.enemy_lives
        WAR.GAME.enemy_lives = tonumber(opts.enemy) or WAR.GAME.enemy_lives
        if before and WAR.GAME.enemy_lives < before then
            if WAR.UI and WAR.UI.tell then
                WAR.UI.tell(localize('war_rival_life_lost'), G.C.BLUE)
            end
            play_sound("holo1",  0.865, 0.9)
            play_sound("cancel", 0.9,   0.7)
        end
    end
    if WAR.UI and WAR.UI.refresh_hud then
        WAR.UI.refresh_hud()
    end
    if not no_sync and WAR.GAME.active and WAR.NET and WAR.NET.connected() then
        local msg = { action = "setLives" }
        if opts.my    ~= nil then msg.my_lives    = WAR.GAME.my_lives    end
        if opts.enemy ~= nil then msg.enemy_lives = WAR.GAME.enemy_lives end
        WAR.NET.send(msg)
    end
end

-- Cumulative achievements the client counts during a run. game_hooks bumps
-- WAR.GAME.count(key) at the point the thing happens; the relay owns the
-- target, so a new "score N of X" achievement is one entry here plus a call
-- at the count site.
WAR.ACH_COUNTERS = {
    "oneshot", "bloodstone", "pizza", "osage", "stone",
    "wild", "mult", "gold", "steel", "lucky",
    "blue_seal", "gold_seal", "purple_seal", "red_seal",
}

WAR.GAME.ach = {}
WAR.GAME.ach_flags = {}

function WAR.GAME.count(key, n)
    WAR.GAME.ach[key] = (WAR.GAME.ach[key] or 0) + (n or 1)
end

function WAR.GAME.reset_achievements()
    WAR.GAME.ach = {}
    WAR.GAME.ach_flags = {}
end

-- A rival round is a boss blind from pvp_start_ante onward. The boss is not
-- touched: it stays whatever vanilla rolled for the seed, so its art, debuffs
-- and every name-keyed effect behave as in a non-War run. The rival part is
-- layered on top (target = opponent's score, readyBlind barrier, second icon).
function WAR.is_rival_blind(center)
    if not (WAR.GAME and WAR.GAME.active) then return false end
    local cfg  = (WAR.LOBBY and WAR.LOBBY.config) or {}
    local ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    if ante < (cfg.pvp_start_ante or 3) then return false end
    center = center
        or (G.GAME and G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind)
    return (center and center.boss) and true or false
end

-- True while the round on screen is being played as a rival blind.
function WAR.GAME.pvp_round()
    if not WAR.GAME.active then return false end
    return WAR.GAME.is_pvp_blind or WAR.is_rival_blind()
end

-- Rival score is hidden while the relay withholds it, and until we've played a
-- hand this blind (BMP does the same).
function WAR.GAME.score_masked()
    if WAR.GAME.enemy_masked then return true end
    if not (WAR.LOBBY.config and WAR.LOBBY.config.hide_score_until_played) then return false end
    local played = G.GAME and G.GAME.current_round and G.GAME.current_round.hands_played
    return (played or 0) == 0
end

-- Versions exchanged at join so a build mismatch shows up before the run starts.
function WAR.mod_versions()
    local mod = SMODS and SMODS.Mods and SMODS.Mods["War"]
    return tostring(mod and mod.version or "unknown"),
           tostring((SMODS and SMODS.version) or "unknown")
end

-- nil when the opponent's build matches, otherwise "theirs / ours" for the bar.
function WAR.version_mismatch()
    local mine, smods = WAR.mod_versions()
    local theirs = WAR.LOBBY.peer_version
    if not theirs then return nil end
    if tostring(theirs) ~= mine then return tostring(theirs) .. " / " .. mine end
    local peer_smods = WAR.LOBBY.peer_smods
    if peer_smods and tostring(peer_smods) ~= smods then
        return tostring(peer_smods) .. " / " .. smods
    end
    return nil
end

-- Blind clock is the relay's: it tells both clients how long is left, so the two
-- countdowns can't disagree.
function WAR.GAME.start_pvp_timer(secs, is_mine, paused)
    if not (secs and secs > 0) then WAR.GAME.stop_pvp_timer(); return end
    local orig = WAR.GAME._pvp_timer and WAR.GAME._pvp_timer._orig_round
    WAR.GAME._pvp_timer = {
        start             = (G.TIMERS and G.TIMERS.REAL) or 0,
        secs              = secs,
        is_mine           = is_mine or false,
        paused            = paused  or false,
        _paused_remaining = paused and secs or nil,
        _orig_round       = orig,
    }
    if WAR.UI and WAR.UI.setup_timer_hud then WAR.UI.setup_timer_hud() end
end

function WAR.GAME.stop_pvp_timer()
    local t = WAR.GAME._pvp_timer
    if t and t._orig_round and G.GAME then G.GAME.round = t._orig_round end
    WAR.GAME._pvp_timer = nil
    if WAR.UI and WAR.UI.reset_timer_hud then WAR.UI.reset_timer_hud() end
end

WAR.NET = {
    server_sock = nil,
    recv_buf    = "",
}

WAR.GAMEMODES = {}

-- The relay sends stable machine codes (not prose). Map them here so the
-- client can show a translated message; unknown codes pass through unchanged.

WAR.ERROR_KEYS = {
    missing_fields  = "war_err_missing_fields",
    bad_username    = "war_err_bad_username",
    username_taken  = "war_err_username_taken",
    bad_credentials = "war_err_bad_credentials",
    invalid_token   = "war_err_invalid_token",
    no_user         = "war_err_no_user",
    no_lobby        = "war_err_no_lobby",
    full            = "war_err_lobby_full",
}

function WAR.error_text(code)
    if code == nil then return localize('war_server_error') end
    local key = WAR.ERROR_KEYS[tostring(code)]
    return key and localize(key) or tostring(code)
end

-- Other mods register a handler and call send() to exchange arbitrary data
-- with the opponent's copy of that mod over the relay.
--
-- Usage (in any mod that loads after War):
--   WAR.MODCOMPAT.register("MyModId", function(data) ... end)
--   WAR.MODCOMPAT.send("MyModId", { key = value, ... })
--
WAR.MODCOMPAT = {
    _handlers = {},
    _state    = {},   -- last received data per mod_id, readable via WAR.MODCOMPAT.get()
}

-- Static sprites shown in the lobby centre: the WR ambigram logo and the
-- ace card that slots into the A position to complete the WAR ambigram.
SMODS.Atlas({ key="lobby_title", path="lobby_title.png", px=379, py=253 })
SMODS.Atlas({ key="lobby_card",  path="lobby_card.png",  px=71,  py=95  })
-- Icon picker sheets (21-frame animated, one row per icon)
SMODS.Atlas({ key="war_icons_free",        path="icons_free.png",        px=34, py=34, atlas_table="ANIMATION_ATLAS", frames=21 })
SMODS.Atlas({ key="war_icons_achievement", path="icons_achievement.png", px=34, py=34, atlas_table="ANIMATION_ATLAS", frames=21 })
SMODS.Atlas({ key="war_icons_special",     path="icons_special.png",     px=34, py=34, atlas_table="ANIMATION_ATLAS", frames=21 })
SMODS.Atlas({ key="war_icons_locked",      path="locked_icon.png",       px=34, py=34, atlas_table="ANIMATION_ATLAS", frames=21 })

-- Full IEEE 754 double precision for wire transmission: any score Balatro can
-- produce (up to ~1.8e308) survives the JSON round-trip without loss of
-- relative precision (~17 significant digits). The relay stores Python floats
-- which have the same range and precision.

WAR.SCORE = {}

function WAR.SCORE.encode(n)
    if type(n) == "table" then
        -- Amulet BigNum stores the float in .number; generic SMODS to_big fallback
        -- reads tostring and strips formatting characters.
        if type(n.number) == "number" then
            n = n.number
        elseif type(n.to_number) == "function" then
            n = n:to_number()
        else
            n = tonumber((tostring(n):gsub(",", ""):gsub("%s", ""))) or 0
        end
    end
    n = tonumber(n) or 0
    return string.format("%.17g", n)
end

function WAR.SCORE.decode(s)
    return tonumber(s) or 0
end

-- Display a score using Balatro's own formatter where available.
function WAR.SCORE.format(n)
    n = type(n) == "number" and n or (tonumber(n) or 0)
    if number_format then return number_format(n) end
    if n >= 1e9 then return string.format("%.3e", n) end
    return tostring(math.floor(n))
end

print("[WAR] globals loaded")
