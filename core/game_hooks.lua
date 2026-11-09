-- core/game_hooks.lua

local _auto_login_done = false

-- Count pseudorandom "hits" during PvP hand scoring for the Oops achievement.
-- Only fires while in HAND_PLAYED state (the scoring phase) during a PvP round.
WAR.GAME.prob_hits = 0
local _orig_pseudo = pseudorandom
function pseudorandom(key, mn, mx)
    local r = _orig_pseudo(key, mn, mx)
    if G.STATE == G.STATES.HAND_PLAYED
       and WAR.GAME.active and WAR.GAME.pvp_round()
       and WAR.NET.connected() and r < 0.5 then
        WAR.GAME.prob_hits = WAR.GAME.prob_hits + 1
    end
    -- Lucky card: count actual triggers via their known pseudorandom keys.
    -- Both checks fire on the minimum value: pseudorandom(key,1,5)==1 is a hit.
    if WAR.GAME.active and WAR.NET.connected()
       and (key == 'lucky_mult' or key == 'lucky_money')
       and mn ~= nil and r == mn then
        WAR.GAME.count('lucky')
    end
    return r
end

local _orig_game_update = Game.update
function Game:update(dt)
    _orig_game_update(self, dt)
    if not _auto_login_done then
        _auto_login_done = true
        WAR.AUTH.auto_login(function(ok)
            if ok then
                print("[WAR AUTH] auto-login as " .. tostring(WAR.AUTH.user))
            end
            if WAR.UI.update_connection_status then WAR.UI.update_connection_status() end
        end)
    end
    -- Tick round-counter timer display while waiting for readyBlind.
    -- DynaText already reads G.GAME.round each frame, so just overwrite it.
    if WAR.GAME._pvp_timer and G.TIMERS and G.GAME then
        local t = WAR.GAME._pvp_timer
        t._orig_round = t._orig_round or G.GAME.round
        if t.paused then
            G.GAME.round = t._paused_remaining or t.secs
        else
            local elapsed = G.TIMERS.REAL - t.start
            G.GAME.round  = math.max(0, math.ceil(t.secs - elapsed))
        end
    end
    if WAR.UI.sync_rival_icons then WAR.UI.sync_rival_icons() end
    if WAR.NET.connected() then
        local ok, err = pcall(WAR.SYNC.tick)
        if not ok then print("[WAR TICK] " .. tostring(err)) end
    end
    -- Score goes out on hand end, blind start, deck-out and hand-count gains.
    -- Never mid-scoring: those frames carry partial totals.
    -- Keep the rival icons glued to their chips (sprites never move children)
    if WAR.UI.sync_rival_icons then WAR.UI.sync_rival_icons() end
    -- Drag repositioning for lobby panels (main menu only)
    if WAR.UI.update_panel_drag and G.STAGE == G.STAGES.MAIN_MENU then
        WAR.UI.update_panel_drag()
    end
    -- Force-advance to NEW_ROUND when endPvP arrives in non-HAND_PLAYED states
    -- (e.g. arrives while drawing cards or selecting hand). HAND_PLAYED is now
    -- handled directly in update_hand_played, so this only covers other states.
    if WAR.GAME.active and WAR.GAME.end_pvp_pending and G.STAGE == G.STAGES.RUN then
        local state = G.STATE
        if state ~= G.STATES.NEW_ROUND
           and not (G.GAME.STOP_USE and G.GAME.STOP_USE > 0) then
            WAR.GAME.end_pvp_pending = false
            WAR.GAME.is_pvp_blind    = false
            if G.hand then G.hand:unhighlight_all() end
            G.STATE_COMPLETE = false
            G.STATE          = G.STATES.NEW_ROUND
        end
    end
    -- Keep the vanilla card visible so the Card's mouse-tilt shader still works.
    -- We only suppress it if it was already invisible before the lobby opened.
end

local _orig_main_menu = Game.main_menu
function Game:main_menu(change_context)
    _orig_main_menu(self, change_context)
    -- Safety net: restore original profile if the player quit a War run via vanilla means.
    if WAR.UI.exit_war_profile then WAR.UI.exit_war_profile() end
    if WAR.UI.update_connection_status then
        WAR.UI.update_connection_status()
    end
end

local _orig_start_run = Game.start_run
function Game:start_run(start_params)
    if WAR.GAME.active and WAR.LOBBY.config.seed then
        start_params = start_params or {}
        start_params.seed = tostring(WAR.LOBBY.config.seed)
    end
    _orig_start_run(self, start_params)
    if WAR.GAME.active then
        -- Record stake and deck for end-of-match achievement increments.
        WAR.GAME.match_stake = G.GAME and G.GAME.stake
        WAR.GAME.match_deck  = G.GAME and G.GAME.back and G.GAME.back.name
        -- Bans come from the gamemode + ruleset pair so the ruleset screen can
        -- show exactly what is disabled. Fall back to the standard ruleset when
        -- a lobby was created before a ruleset was recorded.
        local rs_key = WAR.LOBBY.config.ruleset or "standard"
        local gm_key = WAR.LOBBY.config.gamemode or "vanilla"
        G.GAME.banned_keys = G.GAME.banned_keys or {}
        for k in pairs(WAR.banned_keys_for(gm_key, rs_key)) do
            G.GAME.banned_keys[k] = true
        end
    end
    if WAR.GAME.active and WAR.UI.setup_lives_hud then
        G.E_MANAGER:add_event(Event({
            trigger = "after", delay = 0.5, blockable = false,
            func = function() WAR.UI.setup_lives_hud(); return true end,
        }))
    end
end

local _orig_reroll_boss = G.FUNCS.reroll_boss
if _orig_reroll_boss then
    G.FUNCS.reroll_boss = function(e)
        if WAR.GAME.active then return end
        _orig_reroll_boss(e)
    end
end

-- update_hand_played is the only place that runs exactly once per finished
-- hand, after the chip total has settled. Evaluating G.FUNCS.evaluate_round
-- instead reports the score once per *blind* (it is the cash-out screen),
-- which is why the opponent saw 0 hands / 0 score for a whole round.

function WAR.GAME.hands_left()
    return (G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left) or 0
end

-- G.GAME.chips is a number in vanilla, an Amulet BigNum table once Amulet loads.
-- Try .number, then :to_number(), then the printed form.
function WAR.GAME.my_chips()
    local raw = G.GAME and G.GAME.chips
    if type(raw) == "number" then return raw end
    if type(raw) == "table" then
        if type(raw.number) == "number" then return raw.number end
        if type(raw.to_number) == "function" then
            local ok, n = pcall(raw.to_number, raw)
            if ok and type(n) == "number" then return n end
        end
    end
    return tonumber((tostring(raw):gsub(",", ""):gsub("%s", ""))) or 0
end

function WAR.GAME.send_hand_state(score, hands)
    if not score then WAR.GAME.settle_chips() end
    if G.play and G.play.cards and #G.play.cards > 0 then
        -- Jolly: invalidate if no pair in this hand.
        local ranks = {}
        local has_pair = false
        for _, card in ipairs(G.play.cards) do
            if card.base and card.base.value then
                local r = card.base.value
                ranks[r] = (ranks[r] or 0) + 1
                if ranks[r] >= 2 then has_pair = true; break end
            end
        end
        if not has_pair then WAR.GAME.jolly_valid = false end
        -- Droll: invalidate if not all 5 cards share a suit.
        if #G.play.cards == 5 then
            local suit = nil
            local is_flush = true
            for _, card in ipairs(G.play.cards) do
                local s = card.base and card.base.suit
                if s and s ~= "Wild" then
                    if not suit then suit = s
                    elseif s ~= suit then is_flush = false; break end
                end
            end
            if not is_flush then WAR.GAME.droll_valid = false end
        else
            WAR.GAME.droll_valid = false
        end
        -- Per-card counters for the cumulative achievements, one bump per card.
        for _, card in ipairs(G.play.cards) do
            if card.base and card.base.suit == 'Hearts' then
                WAR.GAME.count('bloodstone')
            end
            if card.seal == 'Red' then
                WAR.GAME.count('pizza')
                WAR.GAME.count('red_seal')
            end
            if card.seal == 'Blue' then WAR.GAME.count('blue_seal') end
            if card.config and card.config.center then
                local ck = card.config.center.key
                if ck == 'm_stone' then
                    -- Stone feeds both: osage counts to 1000, stone to 100.
                    WAR.GAME.count('osage')
                    WAR.GAME.count('stone')
                end
                if ck == 'm_wild'  then WAR.GAME.count('wild')  end
                if ck == 'm_mult'  then WAR.GAME.count('mult')  end
                if ck == 'm_gold'  then WAR.GAME.count('gold')  end
            end
        end
        -- Steel: triggers while held in hand during scoring.
        if G.hand and G.hand.cards then
            for _, card in ipairs(G.hand.cards) do
                if card.config and card.config.center
                   and card.config.center.key == 'm_steel' then
                    WAR.GAME.count('steel')
                end
            end
        end
    end
    -- Missing joker: invalidate if joker slots are full at any hand.
    if WAR.GAME.missing_joker_valid and G.jokers then
        local lim = G.jokers.config and G.jokers.config.card_limit or 5
        if #G.jokers.cards >= lim then
            WAR.GAME.missing_joker_valid = false
        end
    end
    -- Cola: claim as soon as 5 or more tags exist at once.
    if not WAR.GAME.cola_claimed and G.GAME and G.GAME.tags
       and #G.GAME.tags >= 5 then
        WAR.GAME.cola_claimed = true
        WAR.NET.claim_achievement('cola')
    end
    -- Riff-raff: invalidate the moment any non-Common joker is detected.
    if WAR.GAME.riff_raff_valid and G.jokers and G.jokers.cards then
        for _, jkr in ipairs(G.jokers.cards) do
            local rar = jkr.config and jkr.config.center and jkr.config.center.rarity
            if rar and rar ~= 1 then
                WAR.GAME.riff_raff_valid = false
                break
            end
        end
    end
    -- Oops: send claim as soon as threshold is crossed, once per game.
    if WAR.GAME.prob_hits >= 25 and not WAR.GAME.oops_claimed then
        WAR.GAME.oops_claimed = true
        WAR.NET.claim_achievement("oops")
    end
    local out_score = score or WAR.GAME.my_chips()
    local out_hands = hands or WAR.GAME.hands_left()
    WAR.NET.send({
        action    = "playHand",
        score     = WAR.SCORE.encode(out_score),
        handsLeft = out_hands,
        skips     = (G.GAME and G.GAME.skips) or 0,
    })
    print(("[WAR NET] playHand score=%s hands=%s"):format(WAR.SCORE.encode(out_score), out_hands))
end

-- Final board for the end screen. Keys only; names resolve on each client.
local function _board_keys(area)
    local out = {}
    for _, card in ipairs(area and area.cards or {}) do
        local center = card.config and card.config.center
        if center and center.key then out[#out + 1] = center.key end
    end
    return out
end

function WAR.GAME.my_board()
    return {
        jokers      = _board_keys(G.jokers),
        consumables = _board_keys(G.consumeables),
        deck        = G.GAME and G.GAME.back and G.GAME.back.name,
    }
end

function WAR.GAME.send_board_stats()
    if not WAR.NET.connected() then return end
    local board = WAR.GAME.my_board()
    WAR.NET.send({
        action      = "gameStats",
        jokers      = board.jokers,
        consumables = board.consumables,
        deck        = board.deck,
    })
    print(("[WAR NET] gameStats jokers=%d consumables=%d"):format(#board.jokers, #board.consumables))
end

-- Drop the blind target to my score so vanilla ends the round as a pass.
-- Used when the server's PvP result comes in (the target is held at 999M
-- during the blind) and when a normal blind was failed.
function WAR.GAME.force_pass()
    if G.GAME and G.GAME.blind then
        G.GAME.blind.chips = math.floor(WAR.GAME.my_chips())
    end
end

-- The chip counter eases toward the new total, and that ease is still running
-- when vanilla flips STATE_COMPLETE at the end of a hand — reading G.GAME.chips
-- at that moment reports the PREVIOUS hand's total. Settle the pending ease
-- before reporting.
function WAR.GAME.settle_chips()
    -- G.E_MANAGER uses .queues (plural, keyed table), not .queue
    local queues = G.E_MANAGER and G.E_MANAGER.queues
    if not queues then return end
    for _, queue in pairs(queues) do
        if type(queue) == "table" then
            for i = #queue, 1, -1 do
                local e    = queue[i]
                local ease = e and e.ease
                if ease and ease.ref_table == G.GAME and ease.ref_value == "chips" then
                    local target = math.floor(ease.end_val or WAR.GAME.my_chips())
                    G.GAME.chips   = target
                    ease.start_val = target
                    ease.end_val   = target
                    return
                end
            end
        end
    end
end

-- Vanilla advances to NEW_ROUND when chips >= target OR hands_left < 1.
-- During PvP we block both: blind.chips is kept at 999M so vanilla never
-- detects a win, and exhausted hands loops back to HAND_PLAYED while
-- waiting for the server's endPvP signal.

local _orig_update_hand_played = Game.update_hand_played
function Game:update_hand_played(dt)
    if self.buttons then self.buttons:remove(); self.buttons = nil end
    if self.shop    then self.shop:remove();    self.shop    = nil end

    if WAR.GAME.active and WAR.GAME.pvp_round() then
        -- endPvP received — advance unconditionally (follows BMP's approach).
        -- The old guard "if not STATE_COMPLETE" prevented this from firing when
        -- parked waiting for the opponent, which blocked round resolution.
        if WAR.GAME.end_pvp_pending and not (G.GAME.STOP_USE and G.GAME.STOP_USE > 0) then
            WAR.GAME.end_pvp_pending = false
            WAR.GAME.is_pvp_blind    = false
            WAR.GAME.force_pass()
            if G.hand then G.hand:unhighlight_all() end
            WAR.GAME.stop_pvp_timer()
            G.STATE_COMPLETE = false
            G.STATE          = G.STATES.NEW_ROUND
            return
        end
        -- Still playing: advance state; score is tracked per-frame by Game:update.
        if not G.STATE_COMPLETE then
            G.STATE_COMPLETE = true
            G.E_MANAGER:add_event(Event({
                trigger = "immediate",
                func = function()
                    -- Settled total for the hand just played, and the last report
                    -- before the next blind: without it a dropped final frame
                    -- leaves the rival's counter on a partial number.
                    WAR.GAME.send_hand_state()
                    if G.GAME.current_round.hands_left > 0 then
                        G.STATE          = G.STATES.DRAW_TO_HAND
                        G.STATE_COMPLETE = false
                    else
                        -- Hands exhausted: discard remaining cards and show waiting
                        -- indicator. The end_pvp check above fires when endPvP arrives.
                        if G.hand and G.hand.cards[1] then
                            G.FUNCS.draw_from_hand_to_discard()
                        end
                        WAR.UI.wait_for_enemy()
                    end
                    return true
                end,
            }))
        end
        return
    end

    _orig_update_hand_played(self, dt)
end

-- win_game() must not fire, but `win_ante` is left at its real value: vanilla
-- gates the finisher bosses in get_new_boss() on `ante % win_ante`, so faking
-- win_ante silently changed which boss ante 8 rolled.

local _orig_win_game = win_game
win_game = function(...)
    if WAR.GAME.active then
        G.GAME.won = nil
        return
    end
    return _orig_win_game(...)
end

-- Same set of send points BMP uses, minus the ones we already cover.

-- Extra hands (Burglar-style gains) must reach the opponent immediately, or
-- their hand counter is stale until your next play.
local _orig_ease_hands_played = ease_hands_played
ease_hands_played = function(mod, instant)
    _orig_ease_hands_played(mod, instant)
    if WAR.GAME.active and WAR.GAME.pvp_round() and (mod or 0) > 0 then
        WAR.GAME.send_hand_state()
    end
end

-- Deck out: nothing left to draw while hands are still on the counter. Report
-- the exhausted state and park in the played state until the relay resolves.
-- Guards both cases: some hands played (partial deck-out) and no hands played
-- yet (deck drained before the first hand could be played).
local _orig_update_selecting_hand = Game.update_selecting_hand
function Game:update_selecting_hand(dt)
    -- Reset the per-hand send flag whenever we're in a selection phase for a
    -- non-pvp blind, so update_draw_to_hand / update_new_round fire once per hand.
    if WAR.GAME.active and not WAR.GAME.pvp_round() then
        WAR.GAME._hand_state_sent = false
    end
    if WAR.GAME.active and WAR.GAME.pvp_round()
       and (G.GAME.current_round.hands_left or 0) > 0
       and #G.hand.cards < 1 and #G.deck.cards < 1 and #G.play.cards < 1 then
        G.GAME.current_round.hands_left = 0
        WAR.GAME.send_hand_state()
        G.STATE_COMPLETE = false
        G.STATE          = G.STATES.HAND_PLAYED
        return
    end
    _orig_update_selecting_hand(self, dt)
end

-- Non-pvp: state transitions to DRAW_TO_HAND after a hand that didn't beat the
-- blind (more hands remain).  Vanilla owns the state machine fully; we just
-- read the settled total here, one frame after the last scoring event fired.
local _orig_update_draw_to_hand = Game.update_draw_to_hand
function Game:update_draw_to_hand(dt)
    if WAR.GAME.active and not WAR.GAME.pvp_round()
       and not WAR.GAME._hand_state_sent then
        WAR.GAME._hand_state_sent = true
        WAR.GAME.send_hand_state()
    end
    _orig_update_draw_to_hand(self, dt)
end

-- Non-pvp: on first entry to NEW_ROUND the chip total is settled. Report it,
-- check for a failed blind, then block the run-win trigger for the whole
-- round eval (ante 8 mid-match shouldn't end the game).
local _orig_update_new_round = Game.update_new_round
function Game:update_new_round(dt)
    if WAR.GAME.active and not WAR.GAME.pvp_round()
       and not WAR.GAME._hand_state_sent then
        WAR.GAME._hand_state_sent = true
        WAR.GAME.send_hand_state()
        if WAR.GAME.hands_left() < 1 and G.GAME.blind then
            local chips  = WAR.GAME.my_chips()
            local target = type(G.GAME.blind.chips) == "number" and G.GAME.blind.chips
            if target and chips < target then
                WAR.NET.send({ action = "failRound" })
                WAR.GAME.force_pass()
            end
        end
    end
    if WAR.GAME.active then
        local saved = G.GAME and G.GAME.win_ante
        if saved then G.GAME.win_ante = 999 end
        _orig_update_new_round(self, dt)
        if saved then G.GAME.win_ante = saved end
    else
        _orig_update_new_round(self, dt)
    end
end

-- end_round can be reached twice in the same blind (a boss defeat plus a state
-- re-entry). Only the first call per round should run.
local _orig_end_round = end_round
end_round = function(...)
    if WAR.GAME.active then
        if WAR.GAME.round_ended then return end
        WAR.GAME.round_ended = true
    end
    return _orig_end_round(...)
end

-- Cash-out: on a rival round the "score at least" figure is the opponent's
-- final score, not the boss's own requirement.
-- When the player lost and comeback_gold is on, a bonus row is added here.
local _orig_add_round_eval_row = add_round_eval_row
add_round_eval_row = function(config)
    if config and config.name == "blind1" and WAR.GAME.active and WAR.GAME.pvp_round()
       and G.GAME and G.GAME.blind then
        local prev = G.GAME.blind.chip_text
        G.GAME.blind.chip_text = WAR.SCORE.format(WAR.GAME.enemy_score or 0)
        local ok, err = pcall(_orig_add_round_eval_row, config)
        G.GAME.blind.chip_text = prev
        if not ok then error(err) end
        -- Comeback gold: awarded when we lost and the option is enabled
        if WAR.GAME.pvp_lost and WAR.LOBBY.config.comeback_gold ~= false then
            _orig_add_round_eval_row({
                bonus   = true,
                name    = "war_comeback",
                pitch   = (config.pitch or 0.9) + 0.06,
                dollars = 4,
            })
        end
        return
    end
    return _orig_add_round_eval_row(config)
end

-- The boss blind itself is untouched: a rival round is a real vanilla boss with
-- the rival layered on top. Only the target and the HUD change.

local _orig_set_blind = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    _orig_set_blind(self, blind, reset, silent)
    -- reset/nil calls clear the blind (Amulet and friends use set_blind(nil, true));
    -- they must not pin a target or leave a badge behind.
    if reset or not blind then return end
    if WAR.GAME.active and WAR.is_rival_blind(blind) then
        -- The boss keeps its real chip target; the race is the win condition and
        -- end_round's game-over branch is suppressed while a rival round is live
        -- (see lovely/war.toml), so nothing here has to fake a number.
        WAR.UI.update_blind_hud()
        local chip = self.children and self.children.animatedSprite
        if chip then WAR.UI.attach_rival_icon(chip, "blind") end
    elseif self.children and self.children.animatedSprite and WAR.UI.clear_rival_icon then
        WAR.UI.clear_rival_icon(self.children.animatedSprite)
    end
end

local _orig_blind_defeat = Blind.defeat
function Blind:defeat(silent)
    _orig_blind_defeat(self, silent)
    if WAR.GAME.active then
        if WAR.UI.clear_rival_icon and self.children and self.children.animatedSprite then
            WAR.UI.clear_rival_icon(self.children.animatedSprite)
        end
        if WAR.UI.reset_blind_hud then WAR.UI.reset_blind_hud() end
    end
end

-- The barrier fires on the boss blind of a rival ante, whatever boss vanilla
-- rolled — the boss itself stays in place.

local _orig_select_blind = G.FUNCS.select_blind
G.FUNCS.select_blind = function(e)
    if WAR.GAME.active and not WAR.GAME._blind_starting then
        local blind  = e and e.config and e.config.ref_table
        if blind and WAR.is_rival_blind(blind) then
            WAR.GAME._pending_blind_e = e
            WAR.NET.send({ action = "readyBlind" })
            WAR.UI.show_waiting(localize('war_pvp_waiting'))
            return
        end
    end
    _orig_select_blind(e)
    if WAR.GAME.active then
        -- Check joker slots at the blind entry point (shop just ended).
        if WAR.GAME.missing_joker_valid and G.jokers then
            local lim = G.jokers.config and G.jokers.config.card_limit or 5
            if #G.jokers.cards >= lim then WAR.GAME.missing_joker_valid = false end
        end
        WAR.NET.send({ action = "setLocation", location = "Blind" })
    end
end

local _orig_ease_ante = ease_ante
ease_ante = function(amt, ...)
    local result = _orig_ease_ante(amt, ...)
    if WAR.GAME.active and G.GAME and G.GAME.round_resets then
        WAR.NET.send({
            action = "setAnte",
            ante   = G.GAME.round_resets.ante,
        })
    end
    return result
end

-- new_round() is a global function (functions/state_events.lua), not a
-- G.FUNCS entry — hooking G.FUNCS.new_round never fired, so the relay never
-- cleared its per-round lives blocker and only the first failed round could
-- ever cost a life.

local _orig_new_round_fn = new_round
new_round = function(...)
    if WAR.GAME.active then
        WAR.NET.send({ action = "newRound" })
        WAR.GAME.round_ended = false
    end
    return _orig_new_round_fn(...)
end

local _orig_go_shop = G.FUNCS.to_shop
if _orig_go_shop then
    G.FUNCS.to_shop = function(e)
        if WAR.GAME.active then
            WAR.NET.send({ action = "setLocation", location = "Shop" })
            -- Gold seal gives $3 per held card at round end; count them here
            -- (once per round, before G.hand is cleared for the next blind).
            if G.hand and G.hand.cards then
                for _, card in ipairs(G.hand.cards) do
                    if card.seal == 'Gold' then WAR.GAME.count('gold_seal') end
                end
            end
        end
        return _orig_go_shop(e)
    end
end

-- Holding R restarts the run. In a match that would desync or dodge a loss, so
-- swallow the hold while a lobby or run is live.
local _orig_key_hold_update = Controller.key_hold_update
function Controller:key_hold_update(key, dt)
    if key == "r" and (WAR.GAME.active or WAR.LOBBY.code) then
        self.held_key_times[key] = nil
        return
    end
    return _orig_key_hold_update(self, key, dt)
end

-- Some Steamodded builds still call save_run while saving is disabled; in a
-- multiplayer run that crashes on transient hand data.
local _orig_save_run = save_run
save_run = function(...)
    if G and G.F_NO_SAVING then return end
    return _orig_save_run(...)
end

-- Track The Soul (one-off claim) and The Sun (cumulative).
local _orig_use_consumable = Card.use_consumable
function Card:use_consumable(area, copier)
    if WAR.GAME.active and self.config and self.config.center then
        local key = self.config.center.key
        if key == 'c_the_soul' and not WAR.GAME.ach_flags.the_soul then
            WAR.GAME.ach_flags.the_soul = true
            WAR.NET.claim_achievement('the_soul')
        end
        if key == 'c_sun' then
            WAR.GAME.count('oneshot')
        end
    end
    return _orig_use_consumable(self, area, copier)
end

-- Card.sell_card hook: claim egg when a joker worth $15 or more is sold.
local _orig_sell_card = Card.sell_card
function Card:sell_card(...)
    if WAR.GAME.active and not WAR.GAME.ach_flags.egg
       and self.config and self.config.center
       and self.config.center.set == 'Joker'
       and (self.sell_cost or 0) >= 15 then
        WAR.GAME.ach_flags.egg = true
        WAR.NET.claim_achievement('egg')
    end
    return _orig_sell_card(self, ...)
end

-- Sends cumulative per-game counts to the relay at game end (win or lose).
-- One line per key in WAR.ACH_COUNTERS; the relay owns the targets.
function WAR.GAME.send_end_increments()
    for _, key in ipairs(WAR.ACH_COUNTERS) do
        local n = WAR.GAME.ach[key]
        if n and n > 0 then WAR.NET.increment_achievement(key, n) end
    end
    -- One increment per match for the stake the player ran on.
    local STAKE_KEYS = {
        [1]="white_stake",  [2]="red_stake",    [3]="green_stake", [4]="black_stake",
        [5]="blue_stake",   [6]="purple_stake",  [7]="orange_stake",[8]="gold_stake",
    }
    local sk = WAR.GAME.match_stake and STAKE_KEYS[WAR.GAME.match_stake]
    if sk then WAR.NET.increment_achievement(sk, 1) end
    -- One increment per match for the deck the player ran on.
    local DECK_KEYS = {
        ["Red Deck"]     = "red_deck",    ["Blue Deck"]    = "blue_deck",
        ["Yellow Deck"]  = "yellow_deck", ["Green Deck"]   = "green_deck",
        ["Black Deck"]   = "black_deck",  ["Ghost Deck"]   = "ghost_deck",
        ["Painted Deck"] = "painted_deck",["Plasma Deck"]  = "plasma_deck",
    }
    local dk = WAR.GAME.match_deck and DECK_KEYS[WAR.GAME.match_deck]
    if dk then WAR.NET.increment_achievement(dk, 1) end
end

-- Garygpt: claim when the Splash Joker (j_splash) is destroyed (dissolved).
local _orig_start_dissolve = Card.start_dissolve
if _orig_start_dissolve then
    function Card:start_dissolve(...)
        if WAR.GAME.active and not WAR.GAME.garygpt_claimed
           and self.config and self.config.center
           and self.config.center.key == 'j_splash' then
            WAR.GAME.garygpt_claimed = true
            WAR.NET.claim_achievement('garygpt')
        end
        return _orig_start_dissolve(self, ...)
    end
end

-- Purple seal creates a tarot when discarded; count per highlighted card.
local _orig_discard_hand = G.FUNCS.discard_hand
if _orig_discard_hand then
    G.FUNCS.discard_hand = function(e)
        if WAR.GAME.active and G.hand and G.hand.cards then
            for _, card in ipairs(G.hand.cards) do
                if card.highlighted and card.seal == 'Purple' then
                    WAR.GAME.count('purple_seal')
                end
            end
        end
        return _orig_discard_hand(e)
    end
end

print("[WAR] game_hooks loaded")
