-- core/sync.lua
-- Protocol dispatcher: routes incoming relay messages to game/UI handlers.
--
-- Message categories (relay → client):
--   auth:     registered, logged_in, logged_out, salt, auth_error
--   lobby:    created, joined, guest_joined, peer_left, peer_rejoined,
--             rejoined, peer_ready, stopGame, lobbyOptions/config, error, stats
--   game:     startGame, startBlind, enemyInfo, playerInfo, enemyLocation,
--             endPvP, winGame, loseGame, chat, achievementUnlocked, entitlementGranted
--
-- WAR.NET.poll() is called every frame from game_hooks.lua and returns a list
-- of decoded JSON messages. Auth messages go to WAR.AUTH.handle; everything
-- else is handled inline in WAR.SYNC.tick or dispatched to a lifecycle function.

WAR.SYNC = {}

function WAR.NET.on_relay_disconnected()
    if WAR.GAME.active then
        WAR.GAME.active = false
        WAR.UI.show_message(localize('war_relay_lost'))
        WAR.UI.hide_waiting()
    elseif WAR.GAME._end_screen ~= nil then
        -- Game already finished: drop cleanly, don't attempt to rejoin the
        -- old lobby (it's closed on the relay side once someone leaves).
        WAR.LOBBY.code    = nil
        WAR.LOBBY.is_host = false
        WAR.LOBBY_STATE   = "none"
        if WAR.UI.update_connection_status then WAR.UI.update_connection_status() end
    elseif WAR.LOBBY.code then
        local code     = WAR.LOBBY.code
        local is_host  = WAR.LOBBY.is_host
        WAR.LOBBY.code    = nil
        WAR.LOBBY.is_host = false
        WAR.LOBBY_STATE   = "none"
        WAR.UI.hide_lobby()
        WAR.UI.show_message(localize('war_disconnected'))
        -- Both hosts and guests can now reconnect; hosts use rejoin_host.
        if WAR.UI.start_reconnect then
            WAR.UI.start_reconnect(code, is_host)
        end
    end
    if WAR.UI.update_connection_status then WAR.UI.update_connection_status() end
end

function WAR.SYNC.tick()
    local msgs = WAR.NET.poll()
    for _, m in ipairs(msgs) do
        local a = m.action

        -- auth
        if a == "registered" or a == "logged_in" or a == "logged_out"
        or a == "salt"       or a == "auth_error" then
            WAR.AUTH.handle(m)

        -- lobby lifecycle
        elseif a == "created" then
            WAR.LOBBY.code    = m.code
            WAR.LOBBY.is_host = true
            -- Push the host's options so the relay and the client agree on
            -- defaults even if the settings popup is never opened.
            if WAR.LOBBY.push_config then WAR.LOBBY.push_config() end
            if WAR.UI.on_lobby_created then
                local ok, err = pcall(WAR.UI.on_lobby_created, m.code)
                if not ok then print("[WAR SYNC] on_lobby_created: " .. tostring(err)) end
            end

        elseif a == "joined" then
            WAR.LOBBY.code    = m.code
            WAR.LOBBY.is_host = false
            WAR.LOBBY.peer_version = m.mod_version or m.host_mod_version
            WAR.LOBBY.peer_smods   = m.smods_version
            if WAR.AVATAR then
                WAR.AVATAR.set_enemy("host", m.pfp or m.host_avatar)
            end
            if WAR.UI.on_joined_as_guest then
                WAR.UI.on_joined_as_guest(m.host_username, m.code)
            end

        elseif a == "guest_joined" then
            WAR.LOBBY.peer_version = m.mod_version
            WAR.LOBBY.peer_smods   = m.smods_version
            if WAR.AVATAR then
                WAR.AVATAR.set_enemy("guest", m.pfp or m.avatar)
            end
            if WAR.UI.on_guest_joined then
                WAR.UI.on_guest_joined(m.username)
            end

        elseif a == "peer_left" then
            if WAR.GAME.active then
                WAR.SYNC.on_stop_game(localize('war_opp_disconnected'))
            else
                if WAR.UI.on_peer_left then WAR.UI.on_peer_left() end
            end

        elseif a == "peer_rejoined" then
            -- The other player reconnected to the lobby.
            if m.mod_version then WAR.LOBBY.peer_version = m.mod_version end
            if m.smods_version then WAR.LOBBY.peer_smods = m.smods_version end
            if m.username then
                if WAR.LOBBY.is_host then
                    WAR.LOBBY.guest_name = m.username
                else
                    WAR.LOBBY.host_name = m.username
                end
            end
            if WAR.UI.update_lobby_status then WAR.UI.update_lobby_status() end
            if WAR.UI.update_connection_status then WAR.UI.update_connection_status() end

        elseif a == "rejoined" then
            -- Host successfully reclaimed their lobby after a TCP drop.
            WAR.LOBBY._reconnect_code     = nil
            WAR.LOBBY._reconnect_attempts = 0
            WAR.LOBBY._reconnect_is_host  = false
            WAR.LOBBY.code    = m.code
            WAR.LOBBY.is_host = true
            WAR.LOBBY_STATE   = "in_lobby"
            if m.guest_username then WAR.LOBBY.guest_name = m.guest_username end
            if m.guest_mod_version then WAR.LOBBY.peer_version = m.guest_mod_version end
            if m.guest_smods_version then WAR.LOBBY.peer_smods = m.guest_smods_version end
            if m.options then
                for k, v in pairs(m.options) do WAR.LOBBY.config[k] = v end
            end
            WAR.UI.show_lobby()
            if WAR.UI.update_connection_status then WAR.UI.update_connection_status() end

        elseif a == "peer_ready" then
            WAR.LOBBY.peer_ready = m.ready == true
            if WAR.UI.update_lobby_status then WAR.UI.update_lobby_status() end

        elseif a == "stopGame" then
            if WAR.GAME.active then
                WAR.SYNC.on_stop_game(localize('war_opp_left'))
            end

        elseif a == "error" then
            WAR.UI.show_message(WAR.error_text(m.reason))

        elseif a == "stats" then
            if WAR.UI.on_stats then WAR.UI.on_stats(m) end

        elseif a == "modData" then
            local id = m.mod_id or ""
            WAR.MODCOMPAT._state[id] = m.data or {}
            local h = WAR.MODCOMPAT._handlers[id]
            if h then pcall(h, WAR.MODCOMPAT._state[id]) end

        elseif a == "lobbyOptions" or a == "config" then
            if m.lives     then WAR.LOBBY.config.lives     = tonumber(m.lives) end
            -- gamemode/ruleset decide which bans apply, so the guest has to
            -- track the host's pick or their run would ban a different set.
            if m.gamemode  then WAR.LOBBY.config.gamemode  = m.gamemode end
            if m.ruleset   then WAR.LOBBY.config.ruleset   = m.ruleset end
            if m.seed      then WAR.LOBBY.config.seed      = m.seed end
            if m.back      then WAR.LOBBY.config.back      = m.back end
            if m.stake     then WAR.LOBBY.config.stake     = tonumber(m.stake) end
            if m.challenge then WAR.LOBBY.config.challenge = m.challenge end
            if m.sleeve    ~= nil then WAR.LOBBY.config.sleeve = (m.sleeve ~= "") and m.sleeve or nil end
            if m.pvp_start_ante then
                WAR.LOBBY.config.pvp_start_ante = tonumber(m.pvp_start_ante)
            end
            if m.death_on_round_loss    ~= nil then WAR.LOBBY.config.death_on_round_loss    = m.death_on_round_loss    end
            if m.hide_score_until_played ~= nil then WAR.LOBBY.config.hide_score_until_played = m.hide_score_until_played end
            if m.comeback_gold           ~= nil then WAR.LOBBY.config.comeback_gold           = m.comeback_gold           end
            if m.pvp_boss_effects        ~= nil then WAR.LOBBY.config.pvp_boss_effects        = m.pvp_boss_effects        end
            if m.timer_seconds           ~= nil then WAR.LOBBY.config.timer_seconds           = tonumber(m.timer_seconds) or 0 end
            if WAR.UI.update_deck_info then WAR.UI.update_deck_info() end
            if WAR.UI.create_lobby_panels then WAR.UI.create_lobby_panels() end

        elseif a == "hello" then
            WAR.GAME.enemy_location = ""

        -- game start
        elseif a == "startGame" then
            WAR.SYNC.on_start_game(m)

        -- PvP blind barrier
        elseif a == "blindTimer" then
            local secs = tonumber(m.seconds) or 0
            if secs > 0 then
                local my_role = WAR.LOBBY.is_host and "host" or "guest"
                WAR.GAME.start_pvp_timer(secs, m.late ~= my_role, m.paused == true)
            else
                WAR.GAME.stop_pvp_timer()
            end

        elseif a == "startBlind" then
            WAR.SYNC.on_start_blind(m)

        -- live game data
        elseif a == "enemyInfo" then
            WAR.SYNC.on_enemy_info(m)

        elseif a == "playerInfo" then
            WAR.GAME.ease_lives({ my = tonumber(m.lives) }, true)
            WAR.UI.refresh_hud()

        elseif a == "enemyStats" then
            WAR.GAME.enemy_stats = {
                jokers      = m.jokers or {},
                joker_names = m.joker_names or {},
                consumables = m.consumables or {},
                deck        = m.deck,
            }
            if WAR.UI.refresh_end_screen then WAR.UI.refresh_end_screen() end

        elseif a == "enemyLocation" then
            WAR.GAME.enemy_location = m.location or ""
            WAR.UI.refresh_hud()

        -- round resolution
        elseif a == "endPvP" then
            WAR.SYNC.on_end_pvp(m)

        -- game over
        elseif a == "winGame" then
            WAR.GAME.score_result = m
            if WAR.GAME.jolly_valid then
                WAR.NET.claim_achievement("jolly")
            end
            if WAR.GAME.droll_valid then
                WAR.NET.claim_achievement("droll")
            end
            if WAR.GAME.riff_raff_valid then
                WAR.NET.claim_achievement("riff_raff")
            end
            if WAR.GAME.missing_joker_valid then
                WAR.NET.claim_achievement("missing_joker")
            end
            WAR.GAME.send_end_increments()
            WAR.SYNC.on_game_over(true)

        elseif a == "loseGame" then
            WAR.GAME.score_result = m
            WAR.GAME.send_end_increments()
            WAR.SYNC.on_game_over(false)

        elseif a == "chat" then
            if WAR.UI.show_chat then WAR.UI.show_chat(m.text) end

        -- entitlements / achievements
        elseif a == "achievementUnlocked" then
            local key = m.key
            if key then
                WAR.AVATAR.grant_local(key)
                local title = localize("war_achievement_unlocked") or "Achievement Unlocked"
                local name  = localize("war_icon_" .. key) or key
                if WAR.UI.tell then WAR.UI.tell(title .. ": " .. name, G.C.PURPLE) end
            end

        elseif a == "entitlementGranted" then
            local key = m.key
            if key then
                WAR.AVATAR.grant_local(key)
                local name = localize("war_icon_" .. key) or key
                if WAR.UI.tell then WAR.UI.tell(name .. " icon unlocked", G.C.PURPLE) end
            end
        end
    end
end

function WAR.SYNC.on_start_game(m)
    WAR.GAME.active       = true
    WAR.GAME.my_lives     = tonumber(m.lives) or 4
    WAR.GAME.enemy_lives  = tonumber(m.lives) or 4
    WAR.GAME.enemy_score  = 0
    WAR.GAME.enemy_score_display = 0
    WAR.GAME._score_ease  = nil
    WAR.GAME.jolly_valid  = true
    WAR.GAME.droll_valid  = true
    WAR.GAME.prob_hits    = 0
    WAR.GAME.oops_claimed = false
    WAR.GAME.riff_raff_valid   = true
    WAR.GAME.missing_joker_valid = true
    WAR.GAME.cola_claimed        = false
    WAR.GAME.garygpt_claimed     = false
    WAR.GAME.match_stake         = nil
    WAR.GAME.match_deck          = nil
    WAR.GAME._hand_state_sent    = true  -- stays true until first SELECTING_HAND
    WAR.GAME.reset_achievements()
    WAR.GAME.enemy_hands  = 0
    WAR.GAME.enemy_hands_masked = false
    WAR.GAME.enemy_skips  = 0
    WAR.GAME.is_pvp_blind    = false
    WAR.GAME.end_pvp_pending = false
    WAR.GAME.enemy_masked    = false
    WAR.MODCOMPAT._state  = {}

    if m.lives     then WAR.LOBBY.config.lives     = tonumber(m.lives) end
    if m.seed      then WAR.LOBBY.config.seed      = m.seed end
    if m.back      then WAR.LOBBY.config.back      = m.back end
    if m.stake     then WAR.LOBBY.config.stake     = tonumber(m.stake) end
    if m.challenge then WAR.LOBBY.config.challenge = m.challenge end
    if m.sleeve    ~= nil then WAR.LOBBY.config.sleeve = (m.sleeve ~= "") and m.sleeve or nil end

    -- activate gm/rs
    local gm, rs = WAR.LOBBY.config.gamemode, WAR.LOBBY.config.ruleset
    if WAR.GAMEMODES[gm] and WAR.GAMEMODES[gm]["activate"] then
        WAR.GAMEMODES[gm]["activate"]()
    end
    if WAR.RULESETS[rs] and WAR.RULESETS[rs]["activate"] then
        WAR.RULESETS[rs]["activate"]()
    end

    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    WAR.UI.hide_lobby()

    -- Both sides run on the all-unlocked War profile. A guest who never opened
    -- the deck picker is still on their own profile, where the deck back and the
    -- sleeve would draw their locked art even though the run uses them.
    if WAR.UI.enter_war_profile then WAR.UI.enter_war_profile() end

    -- vanilla start_run wants the challenge object, not its id: it reads
    -- args.challenge.deck / .jokers / .rules when building the run.
    local challenge = WAR.challenge_by_id(m.challenge)

    local params = {
        seed      = m.seed,
        stake     = tonumber(m.stake) or 1,
        back      = m.back,
        challenge = challenge,
    }
    -- CardSleeves reads the sleeve off the run args while init_game_object
    -- builds G.GAME; without this the run starts sleeveless even though the
    -- lobby panel showed one.
    if WAR.LOBBY.config.sleeve then
        params.casl_sleeve_choice = WAR.LOBBY.config.sleeve
    end

    -- Short pause so UI finishes closing, then wipe-transition into the run
    G.E_MANAGER:add_event(Event({
        trigger   = "after",
        delay     = 0.1,
        blockable = false,
        func = function()
            G.SETTINGS.paused = true
            G.FUNCS.wipe_on()
            G.E_MANAGER:add_event(Event({
                no_delete = true,
                func = function() G:delete_run(); return true end,
            }))
            G.E_MANAGER:add_event(Event({
                trigger   = "immediate",
                no_delete = true,
                func = function()
                    -- vanilla start_run reads G.GAME.viewed_back, not args.back;
                    -- set it here so both host and guest get the correct deck
                    if params.back then
                        pcall(function()
                            G.GAME.viewed_back = Back(get_deck_from_name(params.back))
                        end)
                    end
                    G:start_run(params)
                    return true
                end,
            }))
            G.FUNCS.wipe_off()
            return true
        end,
    }))

    WAR.log("[WAR SYNC] game started seed=" .. tostring(m.seed))
end

function WAR.SYNC.on_start_blind(m)
    local hands = (G.GAME.round_resets and G.GAME.round_resets.hands) or 4
    WAR.GAME.enemy_score         = 0
    WAR.GAME.enemy_score_display = 0
    WAR.GAME._score_ease         = nil
    WAR.GAME.enemy_hands  = hands
    WAR.GAME.enemy_hands_masked = true
    WAR.GAME.enemy_skips  = 0
    WAR.GAME.is_pvp_blind = true
    WAR.GAME.enemy_masked = false
    WAR.GAME.pvp_lost     = false
    WAR.GAME.score_result = nil

    WAR.UI.hide_waiting()
    WAR.UI.refresh_hud()

    -- Suppress boss blind effects if the option is off
    if WAR.LOBBY.config.pvp_boss_effects == false and G.GAME and G.GAME.blind then
        G.GAME.blind.disabled = true
    end

    WAR.GAME.stop_pvp_timer()

    -- Publish my opening state so the rival's HUD shows a real hand count
    -- instead of the server's default until my first hand lands.
    if WAR.GAME.send_hand_state then WAR.GAME.send_hand_state(0, hands) end

    local e = WAR.GAME._pending_blind_e
    WAR.GAME._pending_blind_e = nil
    WAR.GAME._blind_starting  = true
    if e then
        G.FUNCS.select_blind(e)
    end
    WAR.GAME._blind_starting = false
end

function WAR.SYNC.on_enemy_info(m)
    WAR.log(("[WAR NET] enemyInfo score=%s hands=%s%s"):format(
        tostring(m.score), tostring(m.handsLeft), m.noScore and " (hidden)" or ""))
    if m.noScore or m.score == nil then
        WAR.GAME.enemy_masked = true
    else
        local new_score = WAR.SCORE.decode(m.score)
        WAR.GAME.enemy_masked = false
        -- Count up from wherever the display sits, as BMP does with its 0.75s ease.
        WAR.GAME._score_ease = {
            from  = WAR.GAME.enemy_score_display or 0,
            to    = new_score,
            start = G.TIMERS and G.TIMERS.REAL or 0,
            dur   = 0.75,
        }
        WAR.GAME.enemy_score = new_score
    end
    if m.handsLeft ~= nil then
        WAR.GAME.enemy_hands = tonumber(m.handsLeft) or 0
        WAR.GAME.enemy_hands_masked = false
    end
    if m.skips ~= nil then
        local skips = tonumber(m.skips) or 0
        if skips > (WAR.GAME.enemy_skips or 0) then
            play_sound("negative", 0.865, 0.4)
            play_sound("gong",     0.765, 0.4)
        end
        WAR.GAME.enemy_skips = skips
    end
    if m.lives ~= nil then
        WAR.GAME.ease_lives({ enemy = tonumber(m.lives) }, true)
    end
    -- DO NOT update G.GAME.blind.chips here — it is held at 999M during PvP
    -- so vanilla never auto-wins. Display is driven by WAR.UI._hud.enemy_score.
    WAR.UI.refresh_hud()
    if WAR.UI.juice_pvp_hud then WAR.UI.juice_pvp_hud() end
end

function WAR.SYNC.on_end_pvp(m)
    -- is_pvp_blind stays set until the state machine actually leaves the
    -- blind; clearing it here let vanilla evaluate the 999M target itself
    -- and end the run.
    WAR.GAME.pvp_lost        = m.lost == true
    WAR.GAME.end_pvp_pending = true
    WAR.UI.show_end_pvp(not m.lost)
end

function WAR.SYNC.on_game_over(i_won)
    WAR.GAME.active       = false
    WAR.GAME.is_pvp_blind = false
    -- Capture board data while game objects (G.jokers etc.) are still live.
    -- G:load_profile inside exit_war_profile may clear joker/consumable state,
    -- so both the relay send and the end-screen snapshot must happen first.
    if WAR.GAME.send_board_stats then WAR.GAME.send_board_stats() end
    WAR.GAME._my_board_snapshot = WAR.GAME.my_board and WAR.GAME.my_board()
    if WAR.UI.exit_war_profile then WAR.UI.exit_war_profile() end
    WAR.GAME._end_screen     = not not i_won
    WAR.GAME._stats_refreshed = nil
    local function show()
        if i_won then WAR.UI.show_win_game() else WAR.UI.show_lose_game() end
    end
    -- Give the relay a beat to bring the opponent's board in before painting it.
    if G.E_MANAGER and Event then
        G.E_MANAGER:add_event(Event({
            trigger = "after", delay = 0.35, blockable = false,
            func = function() show(); return true end,
        }))
    else
        show()
    end
end

function WAR.SYNC.on_stop_game(msg)
    WAR.GAME.active       = false
    WAR.GAME.is_pvp_blind = false
    WAR.MODCOMPAT._state  = {}
    if WAR.UI.exit_war_profile then WAR.UI.exit_war_profile() end
    WAR.UI.hide_waiting()
    WAR.UI.show_message(msg or localize('war_game_stopped'))
    if G.STAGE ~= G.STAGES.MAIN_MENU then
        G.FUNCS.go_to_menu()
    end
end

function WAR.SYNC.my_username()
    return WAR.AUTH.user or "Player"
end

function WAR.MODCOMPAT.register(mod_id, handler)
    assert(type(mod_id) == "string" and mod_id ~= "", "WAR.MODCOMPAT.register: mod_id must be a non-empty string")
    assert(type(handler) == "function", "WAR.MODCOMPAT.register: handler must be a function")
    WAR.MODCOMPAT._handlers[mod_id] = handler
end

function WAR.MODCOMPAT.send(mod_id, data)
    if not WAR.NET.connected() then return end
    WAR.NET.send({ action="modData", mod_id=mod_id, data=data })
end

-- Returns the last data table received from the opponent for this mod_id,
-- or nil if nothing has arrived yet this game.
function WAR.MODCOMPAT.get(mod_id)
    return WAR.MODCOMPAT._state[mod_id]
end

print("[WAR] sync loaded")
