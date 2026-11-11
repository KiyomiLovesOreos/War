-- ui/lobby.lua
-- Lobby bottom bar + popups.

WAR.LOBBY.host_name   = nil
WAR.LOBBY.guest_name  = nil
WAR.LOBBY.ready       = false
WAR.LOBBY.peer_ready  = false
WAR.UI._lobby_status  = ""
WAR.UI._code_revealed = false
WAR.UI._lobby_deck_info = ""

local function _get_stake_name(order)
    local center = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake
                   and G.P_CENTER_POOLS.Stake[order]
    if not center then
        return localize('war_stake') .. tostring(order)
    end
    -- Use the same path as SMODS's stake selector: localize by center key.
    -- center.name is nil on modded stake Centers (the display name lives on the
    -- SMODS object, not the Center); localize({type='name_text',...}) is the
    -- canonical route for both vanilla and modded stakes.
    local name = center.key and localize({type='name_text', set='Stake', key=center.key})
    if name and name ~= "" and name ~= center.key then return name end
    -- Fall back: raw name on center or SMODS object, then numbered fallback.
    local smods_stake = G.P_STAKES and center.key and G.P_STAKES[center.key]
    return center.name
        or (smods_stake and smods_stake.name)
        or (localize('war_stake') .. tostring(order))
end

-- Stake icon for the lobby panel. Vanilla stakes all sit in the shipped "chips"
-- atlas (the gold stake even has its own shader draw), so they go through the
-- vanilla helper; a modded stake names its own atlas and is built here instead.
function WAR.UI.stake_sprite(order, scale)
    local center = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake
                   and G.P_CENTER_POOLS.Stake[order]
    local atlas_key = center and (center.atlas or "chips")
    if not center or not center.pos or not atlas_key or atlas_key == "chips" then
        return get_stake_sprite(order, scale)
    end
    local atlas = G.ASSET_ATLAS and G.ASSET_ATLAS[atlas_key]
    if not atlas then return get_stake_sprite(order, scale) end
    local spr = Sprite(0, 0, scale, scale, atlas, center.pos)
    spr.states.drag.can = false
    return spr
end

-- The Back center the lobby's config actually points at. The relay carries the
-- deck's display name, so names and keys both have to resolve; a challenge goes
-- through its own deck type (vanilla keeps the challenge back on b_challenge).
function WAR.UI.deck_center(back_key, ch_tbl)
    local function resolve(v)
        if not v or v == "" then return nil end
        if G.P_CENTERS then
            for _, c in pairs(G.P_CENTERS) do
                if c.set == "Back" and (c.key == v or c.name == v) then return c end
            end
        end
        return get_deck_from_name and get_deck_from_name(v) or nil
    end
    if ch_tbl then
        local t = ch_tbl.deck and ch_tbl.deck.type
        if type(t) == "table" then t = t.name or t.key end
        return resolve(t)
            or resolve(ch_tbl.starting_params and ch_tbl.starting_params.back)
            or (G.P_CENTERS and G.P_CENTERS.b_challenge)
    end
    return resolve(back_key)
end

-- Sprite for a Back center, taken from the center's own atlas so modded decks
-- and the challenge back show their real art instead of the vanilla sheet.
function WAR.UI.deck_sprite(center, w, h)
    if not center or not center.pos then return nil end
    local atlas = G.ASSET_ATLAS and G.ASSET_ATLAS[center.atlas or "centers"]
    if not atlas then return nil end
    return Sprite(0, 0, w or 1.6, h or 2.13, atlas, center.pos)
end

function WAR.UI.update_lobby_status()
    if not WAR.LOBBY.guest_name then
        WAR.UI._lobby_status = localize('war_status_waiting')
        if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end
        return
    end
    local mismatch = WAR.version_mismatch()
    if mismatch then
        WAR.UI._lobby_status = localize('war_version_mismatch') .. " (" .. mismatch .. ")"
    else
        local mine   = WAR.LOBBY.ready
        local theirs = WAR.LOBBY.peer_ready
        if mine and theirs then
            WAR.UI._lobby_status = localize('war_status_starting')
        elseif mine then
            WAR.UI._lobby_status = localize('war_status_you_ready')
        elseif theirs then
            WAR.UI._lobby_status = localize('war_status_opp_ready')
        else
            WAR.UI._lobby_status = localize('war_status_connected')
        end
    end
    if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end
end

function WAR.UI.update_deck_info()
    local back  = WAR.LOBBY.config.back
    local stake = tonumber(WAR.LOBBY.config.stake) or 1
    local sname = _get_stake_name(stake)
    -- A challenge run's deck is fixed by the challenge, so show its name
    -- instead of the literal "Challenge Deck" placeholder.
    local ch = WAR.LOBBY.config.challenge
    local ch_tbl = WAR.challenge_by_id(ch)
    local label = back
    if ch_tbl then
        label = localize(ch_tbl.id, "challenge_names") or ch_tbl.name or back
    end
    if label and label ~= "" then
        local seed = WAR.LOBBY.config.seed
        local seed_str = (seed and seed ~= "" and seed ~= 0) and ("  ·  " .. tostring(seed)) or ""
        WAR.UI._lobby_deck_info = label .. "  ·  " .. sname .. seed_str
    else
        WAR.UI._lobby_deck_info = ""
    end
    if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end
end

function WAR.UI.on_lobby_created(code)
    print("[WAR UI] on_lobby_created code=" .. tostring(code))
    WAR.LOBBY.host_name   = WAR.SYNC.my_username()
    WAR.LOBBY.guest_name  = nil
    WAR.LOBBY.ready       = false
    WAR.LOBBY.peer_ready  = false
    WAR.UI._code_revealed = false
    WAR.UI.update_lobby_status()
    WAR.UI.update_deck_info()
    G.FUNCS.wipe_on()
    G.E_MANAGER:add_event(Event({
        no_delete = true,
        func = function()
            if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
            local ok, err = pcall(WAR.UI.show_lobby, G.UIDEF.war_lobby_bar())
            if not ok then print("[WAR UI] show_lobby error: " .. tostring(err)) end
            return true
        end,
    }))
    G.FUNCS.wipe_off()
end

function WAR.UI.on_guest_joined(username)
    WAR.LOBBY.guest_name  = username or WAR.GAME.peer_username or localize('war_role_guest')
    WAR.LOBBY.ready       = false
    WAR.LOBBY.peer_ready  = false
    WAR.UI.update_lobby_status()
    WAR.UI.show_lobby(G.UIDEF.war_lobby_bar())
end

function WAR.UI.on_joined_as_guest(host_username, code)
    WAR.LOBBY.host_name   = host_username or localize('war_role_host')
    WAR.LOBBY.guest_name  = WAR.SYNC.my_username()
    WAR.LOBBY.ready       = false
    WAR.LOBBY.peer_ready  = false
    WAR.UI._code_revealed = false
    WAR.UI.update_lobby_status()
    WAR.UI.update_deck_info()
    G.FUNCS.wipe_on()
    G.E_MANAGER:add_event(Event({
        no_delete = true,
        func = function()
            if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
            local ok, err = pcall(WAR.UI.show_lobby, G.UIDEF.war_lobby_bar())
            if not ok then print("[WAR UI] show_lobby (guest) error: " .. tostring(err)) end
            return true
        end,
    }))
    G.FUNCS.wipe_off()
end

function WAR.UI.on_peer_left()
    WAR.LOBBY.guest_name  = nil
    WAR.LOBBY.ready       = false
    WAR.LOBBY.peer_ready  = false
    WAR.UI.update_lobby_status()
    WAR.UI.show_lobby(G.UIDEF.war_lobby_bar())
end

-- 4 equal-width slots: [Ready/Start] [Options] [Players|Code] [Leave]
-- Matches Balatro native bar proportions (minh ~1.55, padding, emboss, rounded).

function G.UIDEF.war_lobby_bar()
    local is_host  = WAR.LOBBY.is_host
    local has_peer = WAR.LOBBY.guest_name ~= nil

    -- Shared helper: split-slot column (top button + gap + bottom button)
    local function split_slot(top_btn, bot_btn)
        return { n=G.UIT.C, config={ align="tm", minw=3.5, minh=1.55 }, nodes={
            { n=G.UIT.R, config={ align="lm", mid=true }, nodes={ top_btn }},
            { n=G.UIT.R, config={ align="cm", minh=0.1 }, nodes={} },
            { n=G.UIT.R, config={ align="lm", mid=true }, nodes={ bot_btn }},
        }}
    end

    -- Slot 1: READY/UNREADY — same for both players.
    -- Host needs an opponent present before they can ready up.
    local can_ready = not is_host or has_peer
    -- Gray  = nobody has readied yet (or only self is ready, waiting for peer)
    -- Red   = opponent is ready and waiting on you
    -- Green = both ready, game starting
    local ready_col
    if not can_ready then
        ready_col = G.C.GREY
    elseif WAR.LOBBY.ready and WAR.LOBBY.peer_ready then
        ready_col = G.C.GREEN
    elseif WAR.LOBBY.peer_ready then
        ready_col = G.C.RED
    elseif WAR.LOBBY.ready then
        ready_col = G.C.ORANGE
    else
        ready_col = G.C.GREY
    end
    local slot1 = UIBox_button({
        id="war_lobby_s1", col=true,
        label={WAR.LOBBY.ready and localize('war_unready') or localize('war_ready')},
        button=can_ready and "war_lobby_ready" or nil,
        colour=ready_col,
        minw=3.5, minh=1.55, scale=0.5,
    })

    -- Slot 2: LOBBY SETTINGS (top) + DECK & STAKE (bottom)
    local slot2 = split_slot(
        UIBox_button({
            id="war_lobby_opts_btn",
            label={localize('war_lobby_settings')}, button="war_lobby_options",
            colour=G.C.BLUE, minw=3.5, minh=0.72, scale=0.35,
        }),
        UIBox_button({
            id="war_deck_stake_btn",
            label={localize('war_deck_stake')}, button="war_open_deck_stake",
            colour=G.C.ORANGE, minw=3.5, minh=0.72, scale=0.35,
        })
    )

    -- Slot 3: PLAYERS (top) + CODE (bottom)
    local slot3 = split_slot(
        UIBox_button({
            id="war_lobby_players_btn",
            label={localize('war_players')}, button="war_lobby_players",
            colour=G.C.PURPLE, minw=3.5, minh=0.72, scale=0.4,
        }),
        UIBox_button({
            id="war_code_btn",
            label={localize('war_code')}, button="war_open_code",
            colour=G.C.PALE_GREEN, minw=3.5, minh=0.72, scale=0.4,
        })
    )

    return {
        n = G.UIT.ROOT,
        config = { align="cm", colour=G.C.CLEAR },
        nodes = {
            { n=G.UIT.C, config={ align="bm" }, nodes={
                { n=G.UIT.R, config={
                    align="cm", mid=true,
                    padding=0.1, r=0.1, emboss=0.1, colour=G.C.L_BLACK,
                }, nodes={
                    slot1,
                    { n=G.UIT.B, config={ w=0.02, h=0.1 }},
                    slot2,
                    { n=G.UIT.B, config={ w=0.02, h=0.1 }},
                    slot3,
                    { n=G.UIT.B, config={ w=0.02, h=0.1 }},
                    UIBox_button({
                        id="war_lobby_leave_btn", col=true,
                        label={localize('war_leave')}, button="war_lobby_leave",
                        colour=G.C.RED, minw=3.5, minh=1.55, scale=0.5,
                    }),
                }},
            }},
        },
    }
end

function G.FUNCS.war_lobby_ready(e)
    WAR.LOBBY.ready = not WAR.LOBBY.ready
    -- Mirror the same gray/red/green logic as the bar builder
    if WAR.LOBBY.ready and WAR.LOBBY.peer_ready then
        e.config.colour = G.C.GREEN
    elseif WAR.LOBBY.peer_ready then
        e.config.colour = G.C.RED
    elseif WAR.LOBBY.ready then
        e.config.colour = G.C.ORANGE
    else
        e.config.colour = G.C.GREY
    end
    e.children[1].children[1].config.text = WAR.LOBBY.ready and localize('war_unready') or localize('war_ready')
    e.UIBox:recalculate()
    WAR.NET.send({ action = WAR.LOBBY.ready and "ready" or "unready" })
    WAR.UI.update_lobby_status()
end

function G.FUNCS.war_lobby_leave(e)
    WAR.LOBBY.leave()
    WAR.UI.hide_lobby()
end

-- Code popup: click-to-reveal toggle + copy button
function G.UIDEF.war_code_popup()
    return create_UIBox_generic_options({ contents={
        { n=G.UIT.R, config={ align="cm", padding=0.12 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_code_label'),
                scale=0.45, colour=G.C.UI.TEXT_LIGHT, shadow=true }},
        }},
        UIBox_button({
            id="war_reveal_btn",
            label={localize('war_reveal')}, button="war_reveal_code",
            colour=G.C.PALE_GREEN, minw=5,
        }),
        UIBox_button({
            label={localize('war_copy')}, button="war_copy_code",
            colour=G.C.PERISHABLE, minw=5,
        }),
    }})
end

function G.FUNCS.war_open_code(e)
    WAR.UI.open_popup(G.UIDEF.war_code_popup())
end

function G.FUNCS.war_reveal_code(e)
    local code = WAR.LOBBY.code
    if not code then return end
    local tc = e.children[1].children[1].config
    if tc.text ~= code then
        tc.text = code
        e.config.colour = G.C.ETERNAL
    else
        tc.text = localize('war_reveal')
        e.config.colour = G.C.PALE_GREEN
    end
    e.UIBox:recalculate()
end

function G.FUNCS.war_copy_code(e)
    if love.system and WAR.LOBBY.code then
        love.system.setClipboardText(WAR.LOBBY.code)
    end
end

-- Toggle for host: interactive. For guest: arrows/button disabled, same visual.
local function war_toggle(label, ref_value)
    local cfg = WAR.LOBBY.config
    if cfg[ref_value] == nil then cfg[ref_value] = false end
    local t = create_toggle({
        label     = label,
        ref_table = cfg,
        ref_value = ref_value,
        callback  = function()
            WAR.NET.send({ action="config", [ref_value]=cfg[ref_value] })
        end,
    })
    if not WAR.LOBBY.is_host then
        -- t = R → nodes[2] = C(toggle col) → nodes[1] = C(black bg) → nodes[1] = C(button)
        local btn = t.nodes[2] and t.nodes[2].nodes[1] and t.nodes[2].nodes[1].nodes[1]
        if btn and btn.config then
            btn.config.button          = nil
            btn.config.hover           = false
            btn.config.toggle_callback = nil
        end
    end
    return t
end

-- General tab: starting lives
local function war_opts_general_content()
    local cfg  = WAR.LOBBY.config
    local opts = {}
    for i = 2, 32 do opts[#opts+1] = tostring(i) end
    local cur  = tonumber(cfg.lives) or 4
    local idx  = math.max(1, math.min(#opts, cur - 1))
    local lives_ctrl = create_option_cycle({
        options      = WAR.LOBBY.is_host and opts or {tostring(cfg.lives or 4)},
        opt_callback = WAR.LOBBY.is_host and "war_set_lives" or nil,
        current_option = WAR.LOBBY.is_host and idx or 1,
        minw=4, scale=0.45, label=localize('war_opt_lives'),
    })

    local timer_opts  = { localize('war_timer_off'), "30", "60", "90", "120" }
    local timer_secs  = tonumber(cfg.timer_seconds) or 0
    local timer_idx   = 1
    for i, v in ipairs(timer_opts) do
        if tonumber(v) == timer_secs then timer_idx = i end
    end
    local timer_ctrl = create_option_cycle({
        options        = WAR.LOBBY.is_host and timer_opts or { timer_secs > 0 and tostring(timer_secs) or localize('war_timer_off') },
        opt_callback   = WAR.LOBBY.is_host and "war_set_timer" or nil,
        current_option = WAR.LOBBY.is_host and timer_idx or 1,
        minw=4, scale=0.45, label=localize('war_opt_timer'),
    })

    local ante_opts = {}
    for i = 1, 8 do ante_opts[#ante_opts+1] = tostring(i) end
    local pvp_ante     = tonumber(cfg.pvp_start_ante) or 3
    local pvp_ante_idx = math.max(1, math.min(#ante_opts, pvp_ante))
    local pvp_ante_ctrl = create_option_cycle({
        options        = WAR.LOBBY.is_host and ante_opts or { tostring(pvp_ante) },
        opt_callback   = WAR.LOBBY.is_host and "war_set_pvp_ante" or nil,
        current_option = WAR.LOBBY.is_host and pvp_ante_idx or 1,
        minw=4, scale=0.45, label=localize('war_opt_pvp_ante'),
    })

    return { n=G.UIT.ROOT, config={
        emboss=0.05, minh=4, r=0.1, minw=10,
        align="tm", padding=0.2, colour=G.C.BLACK,
    }, nodes={ lives_ctrl, pvp_ante_ctrl, timer_ctrl }}
end

-- Gameplay tab: toggles
local function war_opts_gameplay_content()
    local cfg = WAR.LOBBY.config
    if cfg.death_on_round_loss    == nil then cfg.death_on_round_loss    = true  end
    if cfg.hide_score_until_played == nil then cfg.hide_score_until_played = false end
    if cfg.comeback_gold           == nil then cfg.comeback_gold           = true  end
    return { n=G.UIT.ROOT, config={
        emboss=0.05, minh=4, r=0.1, minw=10,
        align="tm", padding=0.2, colour=G.C.BLACK,
    }, nodes={
        war_toggle(localize('war_opt_death_round'),   "death_on_round_loss"),
        war_toggle(localize('war_opt_hide_score'),    "hide_score_until_played"),
        war_toggle(localize('war_opt_comeback_gold'), "comeback_gold"),
    }}
end

-- Bans tab: what the active gamemode + ruleset disable.
local function war_opts_bans_content()
    return { n=G.UIT.ROOT, config={
        emboss=0.05, minh=4, r=0.1, minw=10,
        align="tm", padding=0.2, colour=G.C.BLACK,
    }, nodes={
        { n=G.UIT.C, config={ align="tl" }, nodes=WAR.UI.bans_panel(
            WAR.LOBBY.config.gamemode, WAR.LOBBY.config.ruleset) },
    }}
end

function G.UIDEF.war_options_popup(back_func)
    local top = {}
    if not WAR.LOBBY.is_host then
        top[1] = { n=G.UIT.R, config={ align="cm", padding=0.3 }, nodes={
            { n=G.UIT.T, config={
                text=localize('war_host_only'),
                scale=0.5, colour=G.C.UI.TEXT_LIGHT, shadow=true,
            }},
        }}
    end
    top[#top+1] = create_tabs({
        colour = G.C.BOOSTER,
        tabs = {
            { label=localize('war_tab_general'),  chosen=true, tab_definition_function=war_opts_general_content  },
            { label=localize('war_tab_gameplay'),              tab_definition_function=war_opts_gameplay_content  },
            { label=localize('war_tab_bans'),                  tab_definition_function=war_opts_bans_content      },
        },
    })
    return create_UIBox_generic_options({
        back_func = back_func or "exit_overlay_menu",
        contents = {
            { n=G.UIT.R, config={ padding=0, align="cm" }, nodes=top },
        },
    })
end

function G.FUNCS.war_lobby_options(e)
    WAR.UI.open_instant(G.UIDEF.war_options_popup())
end

function G.FUNCS.war_set_lives(args)
    if not WAR.LOBBY.is_host then return end
    WAR.LOBBY.config.lives = tonumber(args.to_val) or 4
    WAR.NET.send({ action="config", lives=WAR.LOBBY.config.lives })
    if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end
end

function G.FUNCS.war_set_pvp_ante(args)
    if not WAR.LOBBY.is_host then return end
    -- option_cycle hands the callback {from_val, to_val, ...}, not the UI element
    local n = tonumber(args and args.to_val)
    if not n then return end
    WAR.LOBBY.config.pvp_start_ante = n
    WAR.LOBBY.config.pvp_ante_set    = true
    WAR.NET.send({ action="config", pvp_start_ante=n })
    if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end
end

function G.FUNCS.war_set_timer(args)
    if not WAR.LOBBY.is_host then return end
    local v = args.to_val
    WAR.LOBBY.config.timer_seconds = (v == localize('war_timer_off')) and 0 or tonumber(v) or 0
    WAR.NET.send({ action="config", timer_seconds=WAR.LOBBY.config.timer_seconds })
    if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end
end

function G.UIDEF.war_players_popup()
    local h  = WAR.LOBBY.host_name  or "Host"
    local g  = WAR.LOBBY.guest_name or localize('war_waiting_ellipsis')
    local gc = WAR.LOBBY.guest_name and G.C.GREEN or G.C.UI.TEXT_INACTIVE

    local function avatar_node(role)
        if not WAR.AVATAR then return { n=G.UIT.B, config={w=0.1,h=0.1} } end
        local s = WAR.AVATAR.sprite(role, 0.45)
        if not s then return { n=G.UIT.B, config={w=0.1,h=0.1} } end
        return { n=G.UIT.O, config={ object=s, minh=0.45, minw=0.45 } }
    end

    local host_av  = WAR.LOBBY.is_host and avatar_node(nil) or avatar_node("host")
    local guest_av = WAR.LOBBY.is_host and avatar_node("guest") or avatar_node(nil)

    return create_UIBox_generic_options({ contents={
        { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_players_title'),
                scale=0.45, colour=G.C.UI.TEXT_LIGHT, shadow=true }},
        }},
        { n=G.UIT.R, config={ align="cm", padding=0.1, r=0.07,
            colour=G.C.UI.TRANSPARENT_DARK, mid=true }, nodes={
            host_av,
            { n=G.UIT.B, config={ w=0.2, h=0.1 } },
            { n=G.UIT.C, config={ align="cm" }, nodes={
                { n=G.UIT.R, config={ align="cm" }, nodes={
                    { n=G.UIT.T, config={ text=h, scale=0.42, colour=G.C.BLUE, shadow=true }},
                }},
                { n=G.UIT.R, config={ align="cm" }, nodes={
                    { n=G.UIT.T, config={ text=localize('war_role_host'), scale=0.32, colour=G.C.UI.TEXT_INACTIVE }},
                }},
            }},
        }},
        { n=G.UIT.R, config={ align="cm", padding=0.1, r=0.07,
            colour=G.C.UI.TRANSPARENT_DARK, mid=true }, nodes={
            guest_av,
            { n=G.UIT.B, config={ w=0.2, h=0.1 } },
            { n=G.UIT.C, config={ align="cm" }, nodes={
                { n=G.UIT.R, config={ align="cm" }, nodes={
                    { n=G.UIT.T, config={ text=g, scale=0.42, colour=gc, shadow=true }},
                }},
                { n=G.UIT.R, config={ align="cm" }, nodes={
                    { n=G.UIT.T, config={ text=localize('war_role_guest'), scale=0.32, colour=G.C.UI.TEXT_INACTIVE }},
                }},
            }},
        }},
    }})
end

function G.FUNCS.war_lobby_players(e)
    WAR.UI.open_popup(G.UIDEF.war_players_popup())
end

-- WAR._deck_selecting:    set while the setup_run overlay is open for War deck selection.
-- WAR._deck_select_return: "rulesets" when opened pre-lobby, nil when opened from lobby bar.
WAR._deck_selecting    = false
WAR._deck_select_return = nil

-- Profile 69 is the dedicated War profile. It is switched to before deck selection opens
-- and switched back when the game ends. Run saves (stats, wins, joker usage) land in
-- profile 4, leaving the player's main profile untouched.
-- "W" is pre-initialised in G.PROFILES by the lovely patch in war.toml (before game.lua's
-- first load_profile), so the slot already has all_unlocked=true when enter_war_profile runs.
local WAR_PROFILE = "W"  -- string key, separate from vanilla's numeric slots (1-3)

WAR.UI._war_orig_profile = nil   -- nil when not in a War session
WAR.UI._war_unlocks      = nil   -- { centers/blinds/tags = {key -> original flags} }

-- `all_unlocked` on the profile object only drives vanilla's unlock-all button.
-- The sprite code reads the per-center flags instead: Back:set_sprite_pos falls
-- back to the locked back art and CardSleeves:is_unlocked() swaps in the locked
-- sleeve art, so a guest on a fresh profile saw both locked even though the run
-- used them. Flip the flags like vanilla's unlock-all does, and keep the
-- originals so the player's own profile is exactly as it was on the way out.
local function _unlock_sweep(src, store)
    for k, v in pairs(src) do
        if not v.demo and not v.wip then
            store[k] = { unlocked = v.unlocked, discovered = v.discovered, alerted = v.alerted }
            v.unlocked, v.discovered, v.alerted = true, true, true
        end
    end
end

local function _relock_sweep(src, store)
    for k, v in pairs(src) do
        local o = store[k]
        if o and not v.demo and not v.wip then
            v.unlocked, v.discovered, v.alerted = o.unlocked, o.discovered, o.alerted
        end
    end
end

local function _refresh_unlock_ui()
    pcall(function()
        if set_profile_progress   then set_profile_progress()   end
        if set_discover_tallies   then set_discover_tallies()   end
    end)
end

-- Switch to the War profile. No-op if already on it.
function WAR.UI.enter_war_profile()
    local slot = (WAR.CONFIG and WAR.CONFIG.war_profile) or WAR_PROFILE
    if WAR.UI._war_orig_profile ~= nil then return end
    local orig = G.SETTINGS and G.SETTINGS.profile
    if not orig or orig == slot then return end
    WAR.UI._war_orig_profile = orig
    G.PROFILES[slot] = G.PROFILES[slot] or {}
    G:load_profile(slot)
    G.PROFILES[slot].all_unlocked = true
    if not WAR.UI._war_unlocks then
        local snap = { centers = {}, blinds = {}, tags = {} }
        _unlock_sweep(G.P_CENTERS, snap.centers)
        if G.P_BLINDS then _unlock_sweep(G.P_BLINDS, snap.blinds) end
        if G.P_TAGS   then _unlock_sweep(G.P_TAGS,   snap.tags)   end
        WAR.UI._war_unlocks = snap
        _refresh_unlock_ui()
    end
end

-- Return to the player's original profile and put the flags back.
function WAR.UI.exit_war_profile()
    local orig = WAR.UI._war_orig_profile
    if not orig then return end
    WAR.UI._war_orig_profile = nil
    G:load_profile(orig)
    -- Immediately persist the restored profile so a subsequent crash or
    -- force-quit can't leave G.SETTINGS.profile = "W" on disk.
    if G.save_settings then pcall(G.save_settings, G) end
    local snap = WAR.UI._war_unlocks
    if snap then
        WAR.UI._war_unlocks = nil
        _relock_sweep(G.P_CENTERS, snap.centers)
        if G.P_BLINDS then _relock_sweep(G.P_BLINDS, snap.blinds) end
        if G.P_TAGS   then _relock_sweep(G.P_TAGS,   snap.tags)   end
        _refresh_unlock_ui()
    end
end

-- Hook 1: suppress vanilla Continue tab (greyed-out fallback; Lovely patch also handles it).
local _orig_can_continue = G.FUNCS.can_continue
G.FUNCS.can_continue = function(e)
    if WAR._deck_selecting then
        if e and e.config and e.config.func then
            e.config.colour = G.C.UI.BACKGROUND_INACTIVE
            e.config.button = nil
        end
        return false
    end
    return _orig_can_continue(e)
end

-- Hook 2: intercept start_run — handles both vanilla and SMODS paths.
--   Reads SMODS arg format (deck_choice/stake_choice) and captures seed.
local _orig_start_run = G.FUNCS.start_run
G.FUNCS.start_run = function(e, args)
    if WAR._deck_selecting then
        -- Guest is in read-only browse mode — close cleanly without touching config.
        if not WAR.LOBBY.is_host then
            WAR._deck_selecting     = false
            WAR._deck_select_return = nil
            G.FUNCS.exit_overlay_menu()
            return
        end
        local return_dest         = WAR._deck_select_return
        WAR._deck_selecting       = false
        WAR._deck_select_return   = nil
        G.FUNCS.exit_overlay_menu()
        args = args or {}
        -- Deck name: SMODS sends args.deck_choice.name, vanilla sends args.deck.name
        WAR.LOBBY.config.back = args.challenge and "Challenge Deck"
            or (args.deck_choice and type(args.deck_choice) == "table" and args.deck_choice.name)
            or (args.deck and args.deck.name)
            or (G.GAME.viewed_back and G.GAME.viewed_back.name)
        -- Stake: SMODS sends args.stake_choice (order number), vanilla sends args.stake
        WAR.LOBBY.config.stake     = args.stake_choice or args.stake or 1
        WAR.LOBBY.config.challenge = (args.challenge and args.challenge.id) or ""
        -- Seed: SMODS sets args.seed=nil when the enable toggle is off, even if
        -- the user typed something.  Fall back to choices.seed directly so the
        -- typed value isn't silently dropped.
        local _seed = args.seed
        if (not _seed or _seed == "") and
           SMODS and SMODS.RunSelect and SMODS.RunSelect.Setup then
            local ch = SMODS.RunSelect.Setup.choices
            if ch and ch.seed and ch.seed ~= "" then _seed = ch.seed end
        end
        WAR.LOBBY.config.seed = (_seed and _seed ~= "") and _seed or nil
        -- CardSleeves compat: capture sleeve choice if available.
        if WAR.COMPAT and WAR.COMPAT.capture_sleeve then
            WAR.LOBBY.config.sleeve = WAR.COMPAT.capture_sleeve(args)
        end
        WAR.UI.update_deck_info()
        if WAR.LOBBY.code and WAR.LOBBY.is_host then
            WAR.NET.send({
                action    = "config",
                back      = WAR.LOBBY.config.back,
                stake     = WAR.LOBBY.config.stake,
                challenge = WAR.LOBBY.config.challenge,
                seed      = WAR.LOBBY.config.seed or "",
                sleeve    = WAR.LOBBY.config.sleeve or "",
            })
        end
        if return_dest == "rulesets" then
            WAR.UI.open(G.UIDEF.war_ruleset_select(WAR.UI._sel_gamemode, WAR.UI._sel_ruleset))
        end
        return
    end
    _orig_start_run(e, args)
end

-- Hook 3: challenge picks.
-- Vanilla start_challenge_run closes the overlay BEFORE calling start_run, and
-- closing it clears the deck-select flags — so the start_run intercept above
-- never saw the pick and a local single-player challenge actually launched.
-- Re-arm the flags across the close so the pick lands in the lobby config.
local _orig_start_challenge = G.FUNCS.start_challenge_run
G.FUNCS.start_challenge_run = function(e)
    local challenge = WAR.challenge_by_id(e and e.config and e.config.id)
    if not (WAR._deck_selecting and challenge) then
        return _orig_start_challenge(e)
    end
    -- Guest browse mode: same silent close as start_run.
    if not WAR.LOBBY.is_host then
        WAR._deck_selecting     = false
        WAR._deck_select_return = nil
        G.FUNCS.exit_overlay_menu()
        return
    end
    local return_dest = WAR._deck_select_return
    G.FUNCS.exit_overlay_menu()
    WAR._deck_selecting     = true
    WAR._deck_select_return = return_dest
    G.FUNCS.start_run(e, { stake = 1, challenge = challenge })
end

-- Hook 4: intercept Back button inside setup_run (back_func = "options" in vanilla).
local _orig_options = G.FUNCS.options
G.FUNCS.options = function(e)
    if WAR._deck_selecting then
        local return_dest         = WAR._deck_select_return
        WAR._deck_selecting       = false
        WAR._deck_select_return   = nil
        G.FUNCS.exit_overlay_menu()
        if return_dest == "rulesets" then
            WAR.UI.open(G.UIDEF.war_ruleset_select(WAR.UI._sel_gamemode, WAR.UI._sel_ruleset))
        end
        return
    end
    _orig_options(e)
end

-- Hook 5: clear flags whenever the overlay closes for any other reason.
local _orig_exit_overlay = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function(e)
    -- Guest was browsing in read-only mode — restore their actual profile.
    if WAR._deck_selecting and not WAR.LOBBY.is_host then
        WAR.UI.exit_war_profile()
    end
    WAR._deck_selecting     = false
    WAR._deck_select_return = nil
    _orig_exit_overlay(e)
end

-- Lazy SMODS hooks — applied once after setup_run opens (SMODS fns not available at load time).
local _war_smods_hooked = false
local function war_apply_smods_hooks()
    if _war_smods_hooked then return end
    _war_smods_hooked = true

    -- Hook challenge_highlight: swap PLAY to SELECT when in War lobby.
    if G.UIDEF and G.UIDEF.challenge_highlight then
        local _orig_ch = G.UIDEF.challenge_highlight
        G.UIDEF.challenge_highlight = function(...)
            local def = _orig_ch(...)
            if not (WAR._deck_selecting and def) then return def end
            local function swap_play(node)
                if type(node) ~= "table" then return end
                if node.config and node.config.button == "start_challenge_run" then
                    for _, child in ipairs(node.nodes or {}) do
                        if child.config and child.config.text then
                            child.config.text = localize('war_select_cap')
                        end
                    end
                end
                for _, child in ipairs(node.nodes or {}) do swap_play(child) end
            end
            swap_play(def)
            return def
        end
    end

    -- Hook run_select_can_change_page: swap text to SELECT and force blue on final page.
    -- We REPLACE the original entirely when deck-selecting to avoid infinite flicker.
    if G.FUNCS.run_select_can_change_page then
        local _orig_ccp = G.FUNCS.run_select_can_change_page
        G.FUNCS.run_select_can_change_page = function(e)
            if WAR._deck_selecting and SMODS and SMODS.RunSelect then
                local R = SMODS.RunSelect
                local pages = R.Internals.pages
                local cur   = R.Internals.current_page
                local nxt   = R.Functions and R.Functions.get_page_key(1)
                local final = not pages or cur == #pages or (nxt and nxt > #pages)
                if final then
                    if R.Internals.next_button_text ~= localize('war_select') then
                        R.Internals.next_button_text = localize('war_select')
                        pcall(function()
                            e.children[1].children[1].config.object:remove()
                            e.children[1].children[1].config.object = DynaText({
                                string     = {{ref_table=R.Internals, ref_value='next_button_text'}},
                                colours    = {G.C.WHITE}, shadow=true,
                                maxw=1.8, pop_in_rate=0, scale=0.4, silent=true,
                            })
                            e.children[1].children[1].config.object.ui_object_updated = true
                        end)
                    end
                    e.config.colour = G.C.BLUE
                    e.config.button = 'run_select_start_run'
                    return
                end
            end
            _orig_ccp(e)
        end
    end

    -- Hook run_select_quick_start: block Last Run while deck-selecting.
    if G.FUNCS.run_select_quick_start then
        local _orig_qs = G.FUNCS.run_select_quick_start
        G.FUNCS.run_select_quick_start = function(skip_wipe)
            if WAR._deck_selecting then return end
            _orig_qs(skip_wipe)
        end
    end
end

-- Restore previously selected deck/stake/seed before opening setup_run.
local function war_restore_deck_state()
    if WAR.LOBBY.config.back then
        pcall(function()
            G.GAME.viewed_back = Back(get_deck_from_name(WAR.LOBBY.config.back))
        end)
    end
    if WAR.LOBBY.config.stake then
        G.viewed_stake = WAR.LOBBY.config.stake
        pcall(function() G.FUNCS.change_stake({to_key = G.viewed_stake}) end)
    end
    -- Restore seed into SMODS run selector
    if SMODS and SMODS.RunSelect and SMODS.RunSelect.Setup then
        local seed = WAR.LOBBY.config.seed
        if seed and seed ~= "" and seed ~= 0 then
            SMODS.RunSelect.Setup.choices.seed        = tostring(seed)
            SMODS.RunSelect.Setup.choices.enable_seed = true
        else
            SMODS.RunSelect.Setup.choices.seed        = ""
            SMODS.RunSelect.Setup.choices.enable_seed = false
        end
    end
end

-- After setup_run opens: zero-size the Continue tab, hide Last Run button.
-- NOTE: Challenges tab is intentionally left visible.
-- The Lovely patch in war.toml already prevents Continue from showing; this
-- zeros it out as an extra safety measure without causing layout orphan artifacts.
local function war_clean_run_select_ui()
    if not G.OVERLAY_MENU then return end

    -- Zero-size the Continue tab button (safer than remove() which orphans it).
    pcall(function()
        local cont = G.OVERLAY_MENU:get_UIE_by_ID('tab_but_'..localize('b_continue'))
        if cont then
            cont.config.minw    = 0.001
            cont.config.maxw    = 0.001
            cont.config.minh    = 0.001
            cont.config.button  = nil
            cont.config.hover   = false
            cont.config.colour  = G.C.CLEAR
            cont.config.outline = 0
        end
    end)

    -- Hide Last Run (quick_start) button: navigate from next_selection up to nav bar row,
    -- then find the sibling whose inner node has button='run_select_quick_start'.
    -- Use remove() here — nav bar is a plain R row so removing one C child is clean.
    pcall(function()
        local next_sel = G.OVERLAY_MENU:get_UIE_by_ID('next_selection')
        if not next_sel or not next_sel.parent or not next_sel.parent.parent then return end
        local nav_bar = next_sel.parent.parent  -- the R row holding all nav elements
        for _, outer_c in ipairs(nav_bar.children or {}) do
            if outer_c.children then
                for _, inner in ipairs(outer_c.children or {}) do
                    if inner.config and inner.config.button == 'run_select_quick_start' then
                        outer_c:remove()
                        return
                    end
                end
            end
        end
    end)

    -- Set initial SELECT text on the nav Next button if SMODS is on final page.
    pcall(function()
        if not (SMODS and SMODS.RunSelect) then return end
        local R = SMODS.RunSelect
        local pages = R.Internals.pages
        local cur   = R.Internals.current_page
        local nxt   = R.Functions and R.Functions.get_page_key(1)
        local final = not pages or cur == #pages or (nxt and nxt > #pages)
        if final then
            R.Internals.next_button_text = localize('war_select')
        end
    end)
end

-- Opened from the lobby bar (in-lobby deck change)
function G.FUNCS.war_open_deck_stake(e)
    WAR._deck_select_return = nil
    WAR._deck_selecting     = true
    WAR.UI.enter_war_profile()
    war_apply_smods_hooks()
    if WAR.LOBBY.is_host then war_restore_deck_state() end
    G.FUNCS.setup_run(e)
    war_clean_run_select_ui()
end

-- Opened from the pre-lobby rulesets screen
function G.FUNCS.war_open_deck_stake_pre_lobby(e)
    WAR._deck_select_return = "rulesets"
    WAR._deck_selecting     = true
    WAR.UI.enter_war_profile()
    war_apply_smods_hooks()
    if WAR.LOBBY.is_host then war_restore_deck_state() end
    G.FUNCS.setup_run(e)
    war_clean_run_select_ui()
end

-- Left panels: fixed ROOT width (LBOX_W) so both panels are identical in size.
-- ROOT is right-aligned (align="cr") so text sits at the visible right edge.
-- Offset x = -(LBOX_W - LVIS) puts LVIS units on-screen, rest off the left.
-- Right panel: no spacer, auto-fits content, sits near the right edge.

G.WAR_LOBBY_LEFT       = nil
G.WAR_LOBBY_SPECTATORS = nil
G.WAR_LOBBY_RIGHT      = nil
G.WAR_LOBBY_LOGO       = nil   -- WR ambigram title sprite

-- Persists drag-repositioned panel offsets for the current session.
-- Keys: "left", "spec", "right".  nil = use layout defaults.
WAR.UI._panel_offsets = WAR.UI._panel_offsets or {}

-- Drag state for lobby panels.
WAR.UI._drag = { active=false, was_down=false, panel=nil, key=nil,
                 start_cx=0, start_cy=0, start_ox=0, start_oy=0 }

local PAD   = 0.12   -- ROOT padding (uniform)
local C_PAD = 0.10   -- content column padding

-- Left panel geometry
local LBOX_W = 2.2   -- total box width (must fit any content + padding)
local LVIS   = 1.2   -- how much shows at the left screen edge
local LOFF   = -(LBOX_W - LVIS)   -- UIBox x-offset = -1.0

local function war_panel_box(definition, align, ox, oy, key)
    local saved = key and WAR.UI._panel_offsets[key]
    local b = UIBox({ definition=definition, config={
        align=align, bond="Glued",
        offset={x = saved and saved.x or ox, y = saved and saved.y or oy},
        major=G.ROOM_ATTACH,
    }})
    b:align_to_major()
    return b
end

-- Fixed-width box, content right-aligned so text sits at the visible edge.
local function left_panel_root(inner_nodes)
    return {
        n = G.UIT.ROOT,
        config = { align="cc", colour=G.C.L_BLACK, emboss=0.05, r=0.1,
                   padding=PAD, minw=LBOX_W },
        nodes = {
            { n=G.UIT.C, config={ align="tm", padding=C_PAD }, nodes=inner_nodes },
        },
    }
end

-- Right panel: content only, no spacer — box auto-fits and sits flush to edge.
local function right_panel_root(inner_nodes)
    return {
        n = G.UIT.ROOT,
        config = { align="cl", colour=G.C.L_BLACK, emboss=0.05, r=0.1, padding=PAD },
        nodes = {
            { n=G.UIT.C, config={ align="tm" }, nodes=inner_nodes },
        },
    }
end

local function war_colour_box(inner, border_col, minw, minh)
    return { n=G.UIT.R, config={
        align="cm", r=0.08, padding=0.08,
        colour=mix_colours(border_col, G.C.BLACK, 0.7),
        outline=1, outline_colour=border_col,
        emboss=0.05, minw=minw or 1.8, minh=minh or 0,
    }, nodes={ inner }}
end

function WAR.UI.create_lobby_panels()
    WAR.UI.remove_lobby_panels()
    if not (G.STAGE and G.STAGE == G.STAGES.MAIN_MENU) then return end

    local cfg = WAR.LOBBY.config

    local host_ready  = WAR.LOBBY.is_host and WAR.LOBBY.ready or WAR.LOBBY.peer_ready
    local guest_ready = WAR.LOBBY.is_host and WAR.LOBBY.peer_ready or WAR.LOBBY.ready

    local TS   = 0.22
    local GRAY = G.C.GREY
    local LBW  = 1.7    -- min-width for left-panel colour boxes
    local LBH_name   = 0.34
    local LBH_header = 0.28

    local function left_box(inner, border_col, minh)
        return war_colour_box(
            { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={ inner } },
            border_col, LBW, minh or LBH_name
        )
    end

    -- own name = blue box, rival = red box, empty slot = gray box
    local function player_row(name, ready, is_own)
        local border   = (name == nil) and GRAY or (is_own and G.C.BLUE or G.C.RED)
        local icon_key = is_own
            and ((WAR.AVATAR and WAR.AVATAR.selected) or "jimbo")
            or  ((WAR.AVATAR and WAR.AVATAR["_enemy_" .. (WAR.LOBBY.is_host and "guest" or "host")]) or "jimbo")
        -- Build a small icon sprite if the atlas is available
        local icon_node
        pcall(function()
            local icon  = WAR.AVATAR and WAR.AVATAR.icon and WAR.AVATAR.icon(icon_key)
            local aname = (icon and icon.atlas) or "war_icons_free"
            local row   = (icon and icon.row)   or 0
            local atlas = G.ANIMATION_ATLAS and G.ANIMATION_ATLAS[aname]
            if atlas then
                local spr = AnimatedSprite(0, 0, 0.5, 0.5, atlas, { x=0, y=row })
                icon_node = { n=G.UIT.O, config={ object=spr, minh=0.5, minw=0.5 } }
            end
        end)
        local name_text = { n=G.UIT.T, config={
            text   = name or localize('war_waiting_ellipsis'),
            scale  = TS, colour = G.C.WHITE, shadow = true,
        }}
        local inner = icon_node
            and { n=G.UIT.R, config={ align="lm" }, nodes={
                    icon_node,
                    { n=G.UIT.B, config={ w=0.07, h=0.1 } },
                    name_text,
                }}
            or  name_text
        return left_box(inner, border)
    end

    -- Players panel
    local players_def = left_panel_root({
        left_box(
            { n=G.UIT.T, config={ text=localize('war_panel_players'),
                scale=TS-0.03, colour=G.C.WHITE, shadow=true }},
            GRAY, LBH_header
        ),
        { n=G.UIT.R, config={ minh=0.05 }, nodes={} },
        player_row(WAR.LOBBY.host_name or localize('war_role_host'), host_ready,  WAR.LOBBY.is_host),
        { n=G.UIT.R, config={ minh=0.04 }, nodes={} },
        player_row(WAR.LOBBY.guest_name,                              guest_ready, not WAR.LOBBY.is_host),
    })

    -- Spectators panel
    local spectators_def = left_panel_root({
        left_box(
            { n=G.UIT.T, config={ text=localize('war_panel_spectators'),
                scale=TS-0.03, colour=G.C.WHITE, shadow=true }},
            GRAY, LBH_header
        ),
        { n=G.UIT.R, config={ minh=0.05 }, nodes={} },
        left_box(
            { n=G.UIT.T, config={ text="—", scale=TS, colour=G.C.WHITE }},
            GRAY
        ),
    })

    -- Right panel: vertical stack
    local stake = tonumber(cfg.stake) or 1
    local lives = tonumber(cfg.lives) or 4
    local seed  = (cfg.seed and cfg.seed ~= "" and cfg.seed ~= 0)
                  and tostring(cfg.seed) or localize('war_panel_seed_random')

    -- Deck sprite — challenges resolve through their own deck, and a modded deck
    -- lives in its own atlas, so the center decides which sheet to draw from.
    local deck_node
    local ch_tbl      = WAR.challenge_by_id(cfg.challenge)
    local deck_center = WAR.UI.deck_center(cfg.back, ch_tbl)
    if not deck_center and G.GAME and G.GAME.selected_back
       and G.GAME.selected_back.effect then
        deck_center = G.GAME.selected_back.effect.center
    end
    if deck_center then
        local ok, deck_spr = pcall(WAR.UI.deck_sprite, deck_center, 1.6, 2.13)
        if ok and deck_spr then
            local sleeve_key = cfg.sleeve
            if sleeve_key and sleeve_key ~= ""
               and WAR.COMPAT and WAR.COMPAT.sleeve_sprite then
                local ok2, sleeve_spr = pcall(WAR.COMPAT.sleeve_sprite, sleeve_key, 1.6, 2.13)
                if ok2 and sleeve_spr then
                    local orig_draw = deck_spr.draw
                    deck_spr.draw = function(self)
                        if orig_draw then orig_draw(self) end
                        -- Sync both T and VT so the sleeve sits exactly on the
                        -- deck through layout transitions and panel drags.
                        sleeve_spr.T  = self.T
                        sleeve_spr.VT = self.VT or self.T
                        sleeve_spr:draw()
                    end
                end
            end
            deck_node = { n=G.UIT.O, config={ object=deck_spr, w=1.6, h=2.13 } }
        end
    end
    if not deck_node then
        deck_node = { n=G.UIT.T, config={
            text=(cfg.back and cfg.back ~= "" and cfg.back) or "—",
            scale=0.32, colour=G.C.WHITE, shadow=true,
        }}
    end

    local RS = 0.28   -- text scale for right panel info boxes
    local RW = 1.8    -- min box width (drives right panel visible width: ~1.8+0.24+0.24 ≈ 2.3u)
    local RH = 0.60   -- uniform box height for grid look

    local stake_sprite = WAR.UI.stake_sprite(ch_tbl and 1 or stake, 0.32)
    local stake_name   = ch_tbl
        and (localize(ch_tbl.id, "challenge_names") or ch_tbl.name or localize('war_panel_challenge'))
        or _get_stake_name(stake)

    local stake_box = war_colour_box(
        { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
            { n=G.UIT.O, config={ w=0.32, h=0.32, object=stake_sprite,
                hover=true, can_collide=false }},
            { n=G.UIT.B, config={ w=0.06, h=0.1 }},
            { n=G.UIT.T, config={ text=stake_name, scale=RS,
                colour=G.C.WHITE, shadow=true }},
        }}, G.C.BLUE, RW, RH)

    local lives_box = war_colour_box(
        { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
            { n=G.UIT.T, config={
                text=tostring(lives).." "..localize('war_panel_lives_label'),
                scale=RS, colour=G.C.WHITE, shadow=true }},
        }}, {0.93, 0.32, 0.65, 1}, RW, RH)

    local timer_secs = tonumber(cfg.timer_seconds) or 0
    local timer_text = timer_secs > 0
        and (timer_secs .. "s " .. localize('war_panel_timer_label'))
        or  localize('war_panel_timer_off')
    local timer_col  = timer_secs > 0 and G.C.SECONDARY_SET.Uncommon or G.C.IMPORTANT
    local timer_box = war_colour_box(
        { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
            { n=G.UIT.T, config={ text=timer_text,
                scale=RS, colour=G.C.WHITE, shadow=true }},
        }}, timer_col, RW, RH)

    local seed_bar = war_colour_box(
        { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
            { n=G.UIT.T, config={ text=seed, scale=RS,
                colour=G.C.WHITE, shadow=true }},
        }}, G.C.GREEN, RW, 0)

    -- Vertical stack: deck → gap → stake → lives → timer → seed
    local right_content = {
        { n=G.UIT.R, config={ align="cm", r=0.08,
            colour=mix_colours(G.C.RED, G.C.BLACK, 0.7),
            outline=1, outline_colour=G.C.RED, emboss=0.05, padding=0.07,
        }, nodes={ deck_node }},
        { n=G.UIT.R, config={ minh=0.08 }, nodes={} },
        stake_box,
        { n=G.UIT.R, config={ minh=0.06 }, nodes={} },
        lives_box,
        { n=G.UIT.R, config={ minh=0.06 }, nodes={} },
        timer_box,
        { n=G.UIT.R, config={ minh=0.06 }, nodes={} },
        seed_bar,
    }

    G.WAR_LOBBY_LEFT       = war_panel_box(players_def,              "cli", LOFF,  -1.1, "left")
    G.WAR_LOBBY_SPECTATORS = war_panel_box(spectators_def,           "cli", LOFF,   1.1, "spec")
    G.WAR_LOBBY_RIGHT      = war_panel_box(right_panel_root(right_content), "cri", -PAD,  0, "right")

    -- Centre visuals: WR ambigram + ace card
    -- WAR.UI.CENTRE exposes size/offset knobs for live tuning in DebugPlus:
    --   WAR.UI.CENTRE.logo_oy = -1.0; WAR.UI.create_lobby_panels()
    WAR.UI.CENTRE = WAR.UI.CENTRE or {
        logo_w  = 13 * 1.1,   -- logo width in room units (height scales with aspect ratio)
        logo_oy = -1.5,        -- logo y offset from room centre (negative = up)
        ace_w   = 1.2 * (G.CARD_W or 0.71) * 1.1,  -- card width (height scales with aspect ratio)
        ace_oy  = 0,           -- card y offset from room centre
    }
    local C = WAR.UI.CENTRE
    local LOGO_W = C.logo_w
    local LOGO_H = LOGO_W * (253 / 379)
    local ACE_W  = C.ace_w
    local ACE_H  = ACE_W * (95 / 71)

    -- Hide the Balatro word-mark.
    if G.SPLASH_LOGO then
        G.SPLASH_LOGO._war_vis = G.SPLASH_LOGO.states.visible
        G.SPLASH_LOGO.states.visible = false
    end

    -- Debug: log title_top position so we can derive the correct offsets.
    if G.title_top then
        print("[WAR] title_top T x=" .. tostring(G.title_top.T.x)
              .. " y=" .. tostring(G.title_top.T.y)
              .. " w=" .. tostring(G.title_top.T.w)
              .. " h=" .. tostring(G.title_top.T.h))
    end

    local tatlas = G.ASSET_ATLAS["war_lobby_title"]
    local catlas = G.ASSET_ATLAS["war_lobby_card"]

    -- Use UIBox + G.UIT.O (same technique as the right-panel deck card,
    -- which renders correctly). Anchored to G.ROOM_ATTACH at centre.
    local function war_centre_box(atlas, w, h, oy)
        if not atlas then return nil end
        local ok, spr = pcall(Sprite, 0, 0, w, h, atlas, {x=0, y=0})
        if not ok or not spr then return nil end
        local b = UIBox({
            definition = {
                n = G.UIT.ROOT,
                config = { align="cm", colour=G.C.CLEAR, padding=0 },
                nodes  = {{ n=G.UIT.O, config={
                    object=spr, w=w, h=h, hover=false, can_collide=false,
                }}},
            },
            config = { align="cm", bond="Glued", offset={x=0, y=oy},
                       major=G.ROOM_ATTACH },
        })
        b:align_to_major()
        return b
    end

    G.WAR_LOBBY_LOGO = war_centre_box(tatlas, LOGO_W, LOGO_H, C.logo_oy)

    -- Swap the vanilla menu card's sprites so it displays our custom ace.
    -- The vanilla Card object is kept visible so its mouse-tilt shader runs.
    -- children.center = card background layer; children.front = suit/rank layer.
    local menu_card = G.title_top and G.title_top.cards and G.title_top.cards[1]
    if menu_card and catlas then
        WAR.UI._card_swap = {
            center_atlas = menu_card.children.center and menu_card.children.center.atlas,
            center_pos   = menu_card.children.center and {
                x = menu_card.children.center.sprite_pos.x,
                y = menu_card.children.center.sprite_pos.y,
            },
            center_scale = menu_card.children.center and {
                x = menu_card.children.center.scale.x,
                y = menu_card.children.center.scale.y,
            },
            front_vis = menu_card.children.front
                        and menu_card.children.front.states.visible,
        }
        if menu_card.children.center then
            menu_card.children.center.atlas  = catlas
            menu_card.children.center.scale  = {x = catlas.px, y = catlas.py}
            menu_card.children.center:set_sprite_pos({x=0, y=0})
        end
        -- Hide the suit/rank layer — our image has these baked in.
        if menu_card.children.front then
            menu_card.children.front.states.visible = false
        end
    end
end

function WAR.UI.remove_lobby_panels()
    if G.WAR_LOBBY_LEFT       then G.WAR_LOBBY_LEFT:remove();       G.WAR_LOBBY_LEFT       = nil end
    if G.WAR_LOBBY_SPECTATORS then G.WAR_LOBBY_SPECTATORS:remove(); G.WAR_LOBBY_SPECTATORS = nil end
    if G.WAR_LOBBY_RIGHT      then G.WAR_LOBBY_RIGHT:remove();      G.WAR_LOBBY_RIGHT      = nil end
    if G.WAR_LOBBY_LOGO       then G.WAR_LOBBY_LOGO:remove();       G.WAR_LOBBY_LOGO       = nil end
    -- Clear drag state; positions are kept in _panel_offsets for the session.
    WAR.UI._drag = { active=false, was_down=false, panel=nil, key=nil,
                     start_cx=0, start_cy=0, start_ox=0, start_oy=0 }
    if G.SPLASH_LOGO and G.SPLASH_LOGO._war_vis ~= nil then
        G.SPLASH_LOGO.states.visible = G.SPLASH_LOGO._war_vis
        G.SPLASH_LOGO._war_vis = nil
    end
    -- Restore the vanilla menu card's original sprites
    local menu_card = G.title_top and G.title_top.cards and G.title_top.cards[1]
    if menu_card and WAR.UI._card_swap then
        local s = WAR.UI._card_swap
        if menu_card.children.center and s.center_atlas then
            menu_card.children.center.atlas  = s.center_atlas
            menu_card.children.center.scale  = s.center_scale
            menu_card.children.center:set_sprite_pos(s.center_pos)
        end
        if menu_card.children.front and s.front_vis ~= nil then
            menu_card.children.front.states.visible = s.front_vis
        end
        WAR.UI._card_swap = nil
    end
end

-- Per-frame drag handler for the three lobby info panels.
-- Called from Game:update while the panels exist. Lets players reposition
-- panels anywhere on screen; positions survive panel rebuilds for the session.
-- Double-click (two presses within 0.3 s on the same panel) resets it to default.
local _drag_click_time  = 0
local _drag_click_panel = nil

function WAR.UI.update_panel_drag()
    local drag = WAR.UI._drag
    if not G.CONTROLLER then return end

    local is_down = G.CONTROLLER.is_cursor_down
    local cx = G.CURSOR and G.CURSOR.T.x or 0
    local cy = G.CURSOR and G.CURSOR.T.y or 0

    local panel_list = {
        { box=G.WAR_LOBBY_LEFT,       key="left",  def_x=LOFF,  def_y=-1.1, align="cli" },
        { box=G.WAR_LOBBY_SPECTATORS, key="spec",  def_x=LOFF,  def_y= 1.1, align="cli" },
        { box=G.WAR_LOBBY_RIGHT,      key="right", def_x=-PAD,  def_y= 0,   align="cri" },
    }

    -- Press began this frame.
    if is_down and not drag.was_down then
        for _, p in ipairs(panel_list) do
            local b = p.box
            if b and b:collides_with_point(G.CURSOR.T) then
                -- Double-click: reset to default.
                local now = G.TIMERS and G.TIMERS.REAL or 0
                if _drag_click_panel == p.key and (now - _drag_click_time) < 0.3 then
                    WAR.UI._panel_offsets[p.key] = nil
                    _drag_click_panel = nil
                    WAR.UI.create_lobby_panels()
                    break
                end
                _drag_click_time  = now
                _drag_click_panel = p.key

                drag.active   = true
                drag.panel    = b
                drag.key      = p.key
                drag.start_cx = cx
                drag.start_cy = cy
                drag.start_ox = b.alignment.offset.x
                drag.start_oy = b.alignment.offset.y
                break
            end
        end
    end

    -- Drag in progress.
    if drag.active and is_down and drag.panel then
        local dx = cx - drag.start_cx
        local dy = cy - drag.start_cy
        drag.panel.alignment.offset.x = drag.start_ox + dx
        drag.panel.alignment.offset.y = drag.start_oy + dy
        drag.panel:align_to_major()
        drag.panel:hard_set_VT()
    end

    -- Release: commit position.
    if drag.active and not is_down then
        if drag.panel then
            WAR.UI._panel_offsets[drag.key] = {
                x = drag.panel.alignment.offset.x,
                y = drag.panel.alignment.offset.y,
            }
        end
        drag.active = false
        drag.panel  = nil
        drag.key    = nil
    end

    drag.was_down = is_down
end
-- Guests send 'join' with the lobby code; hosts send 'rejoin_host'.
-- The relay holds guest slots for 120 s and host slots for 60 s.

WAR.LOBBY._reconnect_code     = nil
WAR.LOBBY._reconnect_attempts = 0
WAR.LOBBY._reconnect_is_host  = false

local WAR_MAX_RECONNECT   = 5
local WAR_RECONNECT_DELAY = 4   -- seconds between attempts

local function war_try_reconnect()
    if not WAR.LOBBY._reconnect_code then return end
    if WAR.LOBBY.code then return end   -- already back in a lobby

    WAR.LOBBY._reconnect_attempts = (WAR.LOBBY._reconnect_attempts or 0) + 1
    if WAR.LOBBY._reconnect_attempts > WAR_MAX_RECONNECT then
        print("[WAR] Auto-reconnect: max attempts reached, giving up")
        WAR.LOBBY._reconnect_code     = nil
        WAR.LOBBY._reconnect_attempts = 0
        WAR.LOBBY._reconnect_is_host  = false
        return
    end

    local code    = WAR.LOBBY._reconnect_code
    local is_host = WAR.LOBBY._reconnect_is_host
    print("[WAR] Auto-reconnect attempt " .. WAR.LOBBY._reconnect_attempts
          .. "/" .. WAR_MAX_RECONNECT .. " code=" .. code
          .. " host=" .. tostring(is_host))

    WAR.AUTH.auto_login(function(ok)
        if not ok or not code then
            G.E_MANAGER:add_event(Event({
                trigger="after", delay=WAR_RECONNECT_DELAY, timer="REAL", blockable=false,
                func=function() war_try_reconnect(); return true end,
            }))
            return
        end

        if is_host then
            -- Host rejoins: relay keeps the slot open for HOST_TTL seconds.
            WAR.NET.send({action="rejoin_host", code=code})
            -- On success the relay sends 'rejoined'; handled in sync.lua.
            -- Queue a retry in case this attempt silently fails.
            G.E_MANAGER:add_event(Event({
                trigger="after", delay=WAR_RECONNECT_DELAY, timer="REAL", blockable=false,
                func=function()
                    if not WAR.LOBBY.code then war_try_reconnect() end
                    return true
                end,
            }))
        else
            local jok, jerr = WAR.LOBBY.join(code)
            if not jok then
                print("[WAR] Auto-reconnect join failed: " .. tostring(jerr))
                G.E_MANAGER:add_event(Event({
                    trigger="after", delay=WAR_RECONNECT_DELAY, timer="REAL", blockable=false,
                    func=function() war_try_reconnect(); return true end,
                }))
            end
            -- On success, on_joined_as_guest fires and clears _reconnect_code.
        end
    end)
end

-- Clear reconnect state once successfully back in a lobby.
local _war_orig_on_joined = WAR.UI.on_joined_as_guest
function WAR.UI.on_joined_as_guest(host_username, code)
    WAR.LOBBY._reconnect_code     = nil
    WAR.LOBBY._reconnect_attempts = 0
    WAR.LOBBY._reconnect_is_host  = false
    _war_orig_on_joined(host_username, code)
end

-- Called from sync.lua on_relay_disconnected with (code, is_host).
function WAR.UI.start_reconnect(code, is_host)
    WAR.LOBBY._reconnect_code     = code
    WAR.LOBBY._reconnect_attempts = 0
    WAR.LOBBY._reconnect_is_host  = is_host or false
    G.E_MANAGER:add_event(Event({
        trigger="after", delay=WAR_RECONNECT_DELAY, timer="REAL", blockable=false,
        func=function() war_try_reconnect(); return true end,
    }))
end

-- Small top-right label showing relay/lobby state. Rebuilt on every change.

G.HUD_war_connection = nil

local function _war_cs_state()
    if WAR.LOBBY.code      then return localize('war_cs_in_lobby'),  G.C.WHITE end
    if WAR.NET.connected() then return localize('war_cs_connected'), G.C.WHITE end
    return localize('war_cs_offline'), G.C.WHITE
end

function WAR.UI.update_connection_status()
    if G.HUD_war_connection then G.HUD_war_connection:remove(); G.HUD_war_connection = nil end
    if not (G.STAGE and G.STAGE == G.STAGES.MAIN_MENU) then return end
    local text, col = _war_cs_state()
    G.HUD_war_connection = UIBox({
        definition = {
            n = G.UIT.ROOT,
            config = { align = "cm", colour = G.C.UI.TRANSPARENT_DARK },
            nodes = {{
                n = G.UIT.R,
                config = { align = "cm", padding = 0.05 },
                nodes = {{
                    n = G.UIT.T,
                    config = { text = text, scale = 0.3, colour = col, shadow = true },
                }},
            }},
        },
        config = {
            align  = "tri",
            bond   = "Glued",
            offset = { x = 0, y = 0.9 },
            major  = G.ROOM_ATTACH,
        },
    })
    G.HUD_war_connection:align_to_major()
end

-- Patch lobby show/hide so the indicator and panels stay current.
local _war_orig_show_lobby = WAR.UI.show_lobby
function WAR.UI.show_lobby(definition)
    _war_orig_show_lobby(definition)
    WAR.UI.create_lobby_panels()
    WAR.UI.update_connection_status()
end

local _war_orig_hide_lobby = WAR.UI.hide_lobby
function WAR.UI.hide_lobby()
    _war_orig_hide_lobby()
    WAR.UI.remove_lobby_panels()
    WAR.UI.update_connection_status()
end

print("[WAR] ui/lobby loaded")
