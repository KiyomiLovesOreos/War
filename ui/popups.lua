-- ui/popups.lua
-- In-game overlays: waiting barrier, endPvP result, win/lose screens.

function WAR.UI.show_waiting(msg)
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu({
        definition = create_UIBox_generic_options({
            no_esc   = true,
            contents = {
                { n=G.UIT.R, config={ align="cm", padding=0.15 }, nodes={
                    { n=G.UIT.O, config={ object=DynaText({
                        string  = { msg or localize('war_pvp_waiting') },
                        colours = { G.C.UI.TEXT_LIGHT },
                        scale   = 0.55,
                        pop_in  = 0,
                        silent  = true,
                    }) }},
                }},
            },
        }),
    })
end

function WAR.UI.hide_waiting()
    if G.OVERLAY_MENU and G.SETTINGS.paused then
        G.FUNCS.exit_overlay_menu()
    end
end

-- Brief overlay shown after each PvP blind resolves.
-- Dismisses automatically after 2 seconds (player can also press any key).

function WAR.UI.show_end_pvp(won)
    local colour = won and G.C.GREEN or G.C.RED
    local label  = won and localize('war_round_won') or localize('war_round_lost')
    local result = won
        and localize('war_you_scored_more')
        or  localize('war_you_scored_less')

    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu({
        definition = create_UIBox_generic_options({
            no_esc  = false,
            colour  = won and G.C.BLACK or nil,
            outline_colour = won and G.C.EDITION or nil,
            contents = {
                { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                    { n=G.UIT.O, config={ object=DynaText({
                        string  = { label },
                        colours = { colour },
                        scale   = 1.2,
                        pop_in  = 0.2,
                        shadow  = true,
                        rotate  = won or nil,
                        float   = true,
                    }) }},
                }},
                { n=G.UIT.R, config={ align="cm", padding=0.06 }, nodes={
                    { n=G.UIT.T, config={
                        text   = result,
                        scale  = 0.38,
                        colour = G.C.UI.TEXT_LIGHT,
                    }},
                }},
                { n=G.UIT.R, config={ align="cm", padding=0.08 }, nodes={
                    { n=G.UIT.T, config={
                        text   = localize('war_lives_you') .. tostring(WAR.GAME.my_lives)
                               .. "   " .. localize('war_lives_opp') .. tostring(WAR.GAME.enemy_lives),
                        scale  = 0.38,
                        colour = G.C.UI.TEXT_LIGHT,
                    }},
                }},
                { n=G.UIT.R, config={ align="cm", minh=0.3 }, nodes={} },
                UIBox_button({
                    label  = { localize('war_continue') },
                    button = "war_dismiss_end_pvp",
                    colour = colour,
                    minw   = 3.8, minh=0.7, scale=0.38,
                }),
            },
        }),
    })

    -- Auto-dismiss after 3 seconds
    G.E_MANAGER:add_event(Event({
        trigger   = "after",
        delay     = 3,
        timer     = "REAL",
        blockable = false,
        func = function()
            if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
            return true
        end,
    }))
end

function G.FUNCS.war_dismiss_end_pvp(e)
    G.FUNCS.exit_overlay_menu()
end

-- Non-blocking: the lives counter changes, but a bare number change is easy
-- to miss mid-round. Uses the same two sounds vanilla plays when a run ends.
function WAR.UI.tell(text, colour)
    if not G.play then return end
    attention_text({
        scale  = 0.75,
        text   = tostring(text),
        maxw   = 12,
        hold   = 1.2,
        align  = "cm",
        offset = { x = 0, y = -2 },
        colour = colour or G.C.RED,
        major  = G.play,
    })
    play_sound("negative", 0.5, 0.7)
    play_sound("whoosh2", 0.9, 0.7)
end

-- Out of hands on a rival round: the relay decides who won, so tell the player
-- why they can't play instead of leaving them staring at a dead board.
function WAR.UI.wait_for_enemy()
    if not G.play then return end
    attention_text({
        scale  = 0.8,
        text   = localize('war_wait_enemy'),
        hold   = 5,
        align  = "cm",
        offset = { x = 0, y = -1.5 },
        major  = G.play,
    })
end

local function _fmt_score(n)
    if not n or n == 0 then return "0" end
    if n >= 1e9  then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6  then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3  then return string.format("%.1fK", n / 1e3) end
    return string.format("%d", math.floor(n))
end

local function _card_node(key, cw, ch, fallback_name)
    local center = G.P_CENTERS and G.P_CENTERS[key]
    if not center then
        -- Center not found (mod not loaded on this client).
        -- Show the vanilla locked-card placeholder so it still looks like a
        -- card slot rather than a bare text label (mismatched mod list case).
        local lock_center = G.P_CENTERS and G.P_CENTERS["locked"]
        if lock_center then
            local ok2, lcard = pcall(Card, 0, 0, cw, ch, nil, lock_center)
            if ok2 and lcard then
                lcard.states.drag.can    = false
                lcard.states.collide.can = false
                lcard.states.hover.can   = false
                lcard.T.r = 0
                return { n=G.UIT.O, config={ object=lcard, minh=ch, minw=cw } }
            end
        end
        -- Locked center also unavailable: last-resort text.
        local label = fallback_name or key
        return { n=G.UIT.T, config={ text=label, scale=0.22, colour=G.C.UI.TEXT_INACTIVE } }
    end
    -- Force the center to appear unlocked/discovered before construction.
    -- After exit_war_profile(), _relock_sweep sets modded centers back to
    -- unlocked=false. Card objects reference the center directly, so we must
    -- leave it unlocked — the end screen is temporary and the game resets
    -- profile state on menu transition anyway.
    center.unlocked  = true
    center.discovered = true
    local ok, card = pcall(Card, 0, 0, cw, ch, nil, center)
    if not ok or not card then
        -- Center found but Card construction failed (e.g. modded atlas issue):
        -- fall back to the display name so the joker still appears as text.
        local label = fallback_name or center.name or key
        return { n=G.UIT.T, config={ text=label, scale=0.22, colour=G.C.UI.TEXT_INACTIVE } }
    end
    card.states.drag.can    = false
    card.states.collide.can = false
    card.states.hover.can   = false
    card.T.r = 0
    return { n=G.UIT.O, config={ object=card, minh=ch, minw=cw } }
end

local function _card_row(keys, cw, ch, names)
    if not keys or #keys == 0 then return nil end
    local nodes = {}
    for i, key in ipairs(keys) do
        local name = names and names[i]
        local node = _card_node(key, cw, ch, name)
        if node then nodes[#nodes+1] = { n=G.UIT.C, config={ padding=0.04 }, nodes={ node } } end
    end
    if #nodes == 0 then return nil end
    return { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes=nodes }
end

-- One player's board panel.
local function _board_panel(name, ante, lives, score, is_record, board)
    local cw = (G.CARD_W or 0.73) * 0.7
    local ch = (G.CARD_H or 1.0)  * 0.7

    local rows = {
        { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={
            { n=G.UIT.T, config={ text=name, scale=0.42, colour=G.C.UI.TEXT_LIGHT, shadow=true }},
        }},
        { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
            { n=G.UIT.T, config={
                text   = "Ante " .. tostring(ante or 1) .. "   "
                         .. tostring(lives or 0) .. " " .. localize('war_panel_lives_label'),
                scale  = 0.3,
                colour = (lives or 0) > 0 and G.C.GREEN or G.C.RED,
            }},
        }},
        { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
            { n=G.UIT.T, config={
                text   = _fmt_score(score or 0),
                scale  = 0.42,
                colour = is_record and G.C.GOLD or G.C.UI.TEXT_LIGHT,
                shadow = is_record or nil,
            }},
        }},
    }

    if is_record then
        rows[#rows+1] = { n=G.UIT.R, config={ align="cm", padding=0.02 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_end_new_record'), scale=0.28, colour=G.C.GOLD }},
        }}
    end

    if board then
        local joker_row = _card_row(board.jokers, cw, ch, board.joker_names)
        rows[#rows+1] = joker_row or { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_end_board_empty'), scale=0.28, colour=G.C.UI.TEXT_INACTIVE }},
        }}
        local consm_row = _card_row(board.consumables, cw * 0.78, ch * 0.78)
        if consm_row then rows[#rows+1] = consm_row end
        if board.deck then
            rows[#rows+1] = { n=G.UIT.R, config={ align="cm", padding=0.03 }, nodes={
                { n=G.UIT.T, config={ text=board.deck, scale=0.28, colour=G.C.UI.TEXT_INACTIVE }},
            }}
        end
    else
        rows[#rows+1] = { n=G.UIT.R, config={ align="cm", padding=0.08 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_end_board_waiting'), scale=0.28, colour=G.C.UI.TEXT_INACTIVE }},
        }}
    end

    return {
        n=G.UIT.C,
        config={ align="tm", minw=5.5, r=0.1, padding=0.14, colour=G.C.BLACK, emboss=0.05 },
        nodes=rows,
    }
end

local function _end_game_screen(won)
    local bg   = won and G.C.GREEN or G.C.RED
    local bg_a = { bg[1], bg[2], bg[3], 0 }
    ease_value(bg_a, 4, won and 0.45 or 0.75, nil, nil, true)

    local title_key    = won and "ph_you_win" or "ph_game_over"
    local title_colour = won and G.C.EDITION   or G.C.RED

    local r        = WAR.GAME.score_result or {}
    local my_name  = WAR.SYNC.my_username()
    local opp_name = r.opp_name or localize('war_end_opponent')
    local view_opp = WAR.GAME._end_view ~= "mine"

    local name, ante, lives, score, is_rec, board
    if view_opp then
        name   = opp_name
        ante   = r.opp_ante
        lives  = r.opp_lives ~= nil and r.opp_lives or WAR.GAME.enemy_lives
        score  = r.opp_score
        is_rec = r.opp_new_record
        board  = WAR.GAME.enemy_stats
    else
        name   = my_name
        ante   = r.my_ante or (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante)
        lives  = r.my_lives ~= nil and r.my_lives or WAR.GAME.my_lives
        score  = r.score
        is_rec = r.new_record
        board  = WAR.GAME._my_board_snapshot or (WAR.GAME.my_board and WAR.GAME.my_board())
    end

    return create_UIBox_generic_options({
        padding    = 0,
        bg_colour  = bg_a,
        colour     = won and G.C.BLACK or nil,
        outline_colour = won and G.C.EDITION or nil,
        no_back    = true,
        no_esc     = won,
        contents = {
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                { n=G.UIT.O, config={ object=DynaText({
                    string  = { localize(title_key) },
                    colours = { title_colour },
                    shadow  = true,
                    float   = true,
                    rotate  = won or nil,
                    spacing = won and 10 or nil,
                    scale   = 1.5,
                    pop_in  = 0.4,
                    maxw    = 6.5,
                }) }},
            }},
            { n=G.UIT.R, config={ align="cm", padding=0.08 }, nodes={
                { n=G.UIT.T, config={
                    text   = won and localize('war_defeated_opp') or localize('war_better_luck'),
                    scale  = 0.42,
                    colour = G.C.UI.TEXT_LIGHT,
                }},
            }},
            UIBox_button({
                label  = { view_opp and localize('war_end_view_mine') or localize('war_end_view_opp') },
                button = "war_end_toggle_view",
                colour = G.C.GREY,
                minw = 3.5, minh = 0.6, scale = 0.34,
                focus_args = { snap_to = true },
            }),
            { n=G.UIT.R, config={ align="cm", padding=0.08 }, nodes={
                _board_panel(name, ante, lives, score, is_rec, board),
            }},
            { n=G.UIT.R, config={ align="cm", minh=0.1 }, nodes={} },
            UIBox_button({
                label  = { localize('war_back_to_menu') },
                button = "war_end_to_menu",
                colour = won and G.C.BLUE or G.C.GREY,
                minw   = 4, minh=0.75, scale=0.38,
                focus_args = { snap_to=true },
            }),
        },
    })
end

function WAR.UI.show_win_game()
    G.SETTINGS.paused = true
    WAR.GAME._end_screen = true
    WAR.GAME._end_won   = true
    WAR.GAME._end_view  = "opp"
    G.FUNCS.overlay_menu({ definition = _end_game_screen(true) })
    play_sound("cancel", 1.0, 0.8)
    play_sound("holo1",  0.865, 0.9)
end

function WAR.UI.show_lose_game()
    G.SETTINGS.paused = true
    WAR.GAME._end_screen = true
    WAR.GAME._end_won   = false
    WAR.GAME._end_view  = "opp"
    G.FUNCS.overlay_menu({ definition = _end_game_screen(false) })
    play_sound("cancel", 0.9, 0.7)
end

-- The opponent's board can land after our screen is up: repaint once when it does.
function WAR.UI.refresh_end_screen()
    if WAR.GAME._end_screen == nil or WAR.GAME._stats_refreshed then return end
    WAR.GAME._stats_refreshed = true
    G.FUNCS.overlay_menu({ definition = _end_game_screen(WAR.GAME._end_won) })
end

function G.FUNCS.war_end_toggle_view(e)
    WAR.GAME._end_view = WAR.GAME._end_view == "opp" and "mine" or "opp"
    G.FUNCS.overlay_menu({ definition = _end_game_screen(WAR.GAME._end_won) })
end

function G.FUNCS.war_end_to_menu(e)
    WAR.GAME.active             = false
    WAR.GAME._end_screen        = nil
    WAR.GAME._stats_refreshed   = nil
    WAR.GAME._my_board_snapshot = nil
    G.FUNCS.exit_overlay_menu()
    -- Clean up the relay connection so the socket and lobby code don't linger
    -- on the main menu. Without this the auto-reconnect fires with the old code
    -- and reports "lobby not found" when the connection eventually drops.
    WAR.LOBBY.leave()
    G.FUNCS.go_to_menu()
end

function WAR.UI.show_message(msg)
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu({
        definition = create_UIBox_generic_options({
            contents = {
                { n=G.UIT.R, config={ align="cm", padding=0.15 }, nodes={
                    { n=G.UIT.T, config={
                        text   = tostring(msg),
                        scale  = 0.42,
                        colour = G.C.UI.TEXT_LIGHT,
                        maxw   = 7,
                    }},
                }},
                { n=G.UIT.R, config={ align="cm", minh=0.15 }, nodes={} },
                UIBox_button({
                    label  = { localize('war_ok') },
                    button = "war_dismiss_message",
                    colour = G.C.BLUE, minw=2.5, minh=0.6, scale=0.38,
                }),
            },
        }),
    })
end

function G.FUNCS.war_dismiss_message(e)
    G.FUNCS.exit_overlay_menu()
end

print("[WAR] ui/popups loaded")
