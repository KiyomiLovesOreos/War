-- ui/hud.lua
-- In-run HUD showing opponent state.
--
-- Lives:     replaces the ante counter (hud_ante) in the main HUD.
--            Re-uses the existing DynaText object (only changes its ref_table/ref_value)
--            so mods that patch ease_ante and call :update_text() on the ante DynaText
--            do not crash. The "/ 8" slot becomes "vs {enemy_lives}".
--
-- PvP round: takes over G.HUD_blind while a rival boss is being played.
--            The blind chip's own AnimatedSprite atlas is swapped to war_icons
--            so the rival's icon fills the chip at full scale. The vanilla boss
--            sprite is drawn on top as a quarter-size badge in the bottom-right
--            corner, updated live so Luchador rerolls show through.
--            The blind name slot shows the opponent's username.
--            Everything is restored by reset_blind_hud() on Blind:defeat.

-- State refs — kept as a table so T-node and DynaText ref_value reads stay live.
WAR.UI._lives_dyna = nil
WAR.UI._hud = {
    my_lives    = "?",
    enemy_lives = "?",
    enemy_score = "?",
    enemy_hands = "?",
    enemy_name  = "",
    enemy_loc   = "",
}

function WAR.UI.refresh_hud()
    if not WAR.GAME.active then return end
    WAR.UI._hud.my_lives    = tostring(WAR.GAME.my_lives    or "?")
    WAR.UI._hud.enemy_lives = tostring(WAR.GAME.enemy_lives or "?")
    WAR.UI._hud.enemy_score = (WAR.GAME.score_masked and WAR.GAME.score_masked())
                              and "???" or WAR.SCORE.format(WAR.GAME.enemy_score or 0)
    WAR.UI._hud.enemy_hands = WAR.GAME.enemy_hands_masked and "???"
                              or tostring(WAR.GAME.enemy_hands or "?")
    WAR.UI._hud.enemy_loc   = WAR.GAME.enemy_location or ""
    local name = WAR.LOBBY.is_host and WAR.LOBBY.guest_name or WAR.LOBBY.host_name
    WAR.UI._hud.enemy_name  = name or ""
    if WAR.UI._lives_dyna then pcall(WAR.UI._lives_dyna.update_text, WAR.UI._lives_dyna) end
end

-- \u2500\u2500 Rival chip visual \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
-- The blind chip's AnimatedSprite atlas is swapped to war_icons so the rival's
-- icon renders at full chip scale. The original boss sprite becomes a small badge
-- in the bottom-right corner so the boss effect remains visible (including live
-- updates when Luchador rerolls).

WAR.UI.RIVAL_ICON = { badge_scale = 0.45, badge_dx = 0.53, badge_dy = 0.53 }
WAR.UI._rival_icons = {}

function WAR.UI.rival_icon_row()
    local role = WAR.LOBBY.is_host and "guest" or "host"
    local key  = WAR.AVATAR and WAR.AVATAR["_enemy_" .. role] or "jimbo"
    local icon = WAR.AVATAR and WAR.AVATAR.icon(key)
    if not icon then return nil, nil end
    return icon.atlas or "war_icons_free", icon.row or 0
end

-- Unlist a sprite from the animation/sprite registries by identity.
-- AnimatedSprite:remove() is buggy (removes last entry, not self).
local function _unlist_sprite(spr)
    if not spr then return end
    spr.states.visible = false
    for _, list in ipairs({ G.ANIMATIONS, G.I.SPRITE, G.MOVEABLES, G.I.MOVEABLE }) do
        for i = #list, 1, -1 do
            if list[i] == spr then table.remove(list, i) end
        end
    end
end

-- Resolve the boss blind sprite position. Works on select screen and in-run.
local function _boss_pos_for(chip)
    if G.GAME then
        if G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind then
            return G.GAME.blind.config.blind.pos
        end
        if G.GAME.round_resets and G.GAME.round_resets.blind_choices then
            local bk = G.GAME.round_resets.blind_choices.Boss
            if bk and G.P_BLINDS and G.P_BLINDS[bk] then
                return G.P_BLINDS[bk].pos
            end
        end
    end
    return chip and chip._war_orig_pos or {x=0, y=0}
end

-- The boss a given chip belongs to: the live blind in-run, the upcoming boss on
-- the select screen (where G.GAME.blind still points at the previous one).
local function _current_boss_pos(tag)
    if tag == "select" then
        local bk = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices
                   and G.GAME.round_resets.blind_choices.Boss
        local def = bk and G.P_BLINDS and G.P_BLINDS[bk]
        return def and def.pos
    end
    local b = G.GAME and G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind
    return b and b.pos
end

-- The chip sprite is drawn through draw_self in both places it shows up (UI
-- object nodes call it directly, Blind:draw calls draw_shader) and neither path
-- walks children, so the boss badge has to be drawn from inside the chip's own
-- draw. Pinning the badge to the chip's visible box also keeps it correct while
-- the chip floats and juices.
local function _draw_boss_badge(chip, bb)
    if not (bb and bb.states and bb.states.visible) then return end
    if not (chip.VT and chip.VT.w) then return end
    local cfg = WAR.UI.RIVAL_ICON
    local w, h = chip.VT.w, chip.VT.h or chip.VT.w
    local bw, bh = w * cfg.badge_scale, h * cfg.badge_scale
    bb.VT.x, bb.VT.y = chip.VT.x + w * cfg.badge_dx, chip.VT.y + h * cfg.badge_dy
    bb.VT.w, bb.VT.h = bw, bh
    bb.VT.r, bb.T.r  = 0, 0
    bb.T.x, bb.T.y   = bb.VT.x, bb.VT.y
    bb.T.w, bb.T.h   = bw, bh
    bb.offset_seconds = chip.offset_seconds
    bb:draw_shader("dissolve")
end

local function _chip_draw_self(self)
    local orig = self._war_orig_draw_self
    if orig then orig(self) end
    local entry = self._war_badge_entry
    if entry then _draw_boss_badge(self, entry.boss_badge) end
end

function WAR.UI.drop_rival_icon(entry)
    local p = entry and entry.parent
    if not p then return end
    if p._war_orig_draw_self then
        p.draw_self = p._war_orig_draw_self
        p._war_orig_draw_self = nil
    end
    p._war_badge_entry = nil
    local bb = entry.boss_badge
    if bb then _unlist_sprite(bb) end
    if p._war_orig_atlas then
        p.atlas = p._war_orig_atlas
        if p._war_orig_scale then
            p.scale.x = p._war_orig_scale.x
            p.scale.y = p._war_orig_scale.y
            p._war_orig_scale = nil
        end
        p:set_sprite_pos(_boss_pos_for(p))
        p._war_orig_atlas = nil
        p._war_orig_pos   = nil
    end
end

function WAR.UI.clear_rival_icon(parent)
    for i = #WAR.UI._rival_icons, 1, -1 do
        local e = WAR.UI._rival_icons[i]
        if parent == nil or e.parent == parent then
            WAR.UI.drop_rival_icon(e)
            table.remove(WAR.UI._rival_icons, i)
        end
    end
end

function WAR.UI.attach_rival_icon(parent, tag)
    if not (parent and parent.children) then return end
    WAR.UI.clear_rival_icon(parent)

    local atlas_key, row = WAR.UI.rival_icon_row()
    local icons_atlas = atlas_key and G.ANIMATION_ATLAS and G.ANIMATION_ATLAS[atlas_key]
    local blind_atlas = G.ANIMATION_ATLAS and G.ANIMATION_ATLAS["blind_chips"]
    if not (icons_atlas and row ~= nil) then return end

    parent._war_orig_atlas = parent.atlas
    parent._war_orig_pos   = _boss_pos_for(parent)
    parent._war_orig_scale = { x = parent.scale.x, y = parent.scale.y }

    -- Swap chip to show rival pfp at full scale.
    -- scale.x/y store the atlas frame pixel size; must match the new atlas or
    -- set_sprite_pos builds a quad with wrong dimensions and shows garbage.
    local apx = icons_atlas.px or icons_atlas.w or parent.scale.x
    local apy = icons_atlas.py or icons_atlas.h or parent.scale.y
    parent.atlas   = icons_atlas
    parent.scale.x = apx
    parent.scale.y = apy
    parent:set_sprite_pos({x=0, y=row})

    -- Create boss badge sprite — drawn by the chip's draw_self override above.
    local boss_spr = nil
    if blind_atlas then
        local bp  = _current_boss_pos(tag) or parent._war_orig_pos or {x=0, y=0}
        local bsz = (parent.T.w or 1) * WAR.UI.RIVAL_ICON.badge_scale
        local ok, spr = pcall(AnimatedSprite, 0, 0, bsz, bsz, blind_atlas, bp)
        if ok and spr then
            spr:define_draw_steps({
                {shader="dissolve", shadow_height=0.05},
                {shader="dissolve"},
            })
            spr.states.drag.can    = false
            spr.states.collide.can = false
            spr.states.hover.can   = false
            spr.states.visible     = true
            spr.float              = false   -- prevent the blind chip's floating rotation
            spr.T.r                = 0
            spr._war_boss_pos = {x=bp.x, y=bp.y}
            boss_spr = spr
        end
    end

    local entry = {
        parent     = parent,
        boss_badge = boss_spr,
        tag        = tag,
        pfp_atlas  = icons_atlas,
        pfp_row    = row,
        pfp_scale  = { x = apx, y = apy },
    }
    WAR.UI._rival_icons[#WAR.UI._rival_icons + 1] = entry

    parent._war_badge_entry    = entry
    parent._war_orig_draw_self = parent.draw_self
    parent.draw_self           = _chip_draw_self

    WAR.UI.sync_rival_icons()
end

function WAR.UI.sync_rival_icons()
    for i = #WAR.UI._rival_icons, 1, -1 do
        local e = WAR.UI._rival_icons[i]
        local p = e.parent
        local alive = p and p.states and p.states.visible ~= false
                      and not (e.tag == "select" and not G.blind_select)
        if not alive then
            WAR.UI.drop_rival_icon(e)
            table.remove(WAR.UI._rival_icons, i)
        else
            -- Re-enforce the pfp every frame: Blind:set_blind and Blind:load call
            -- set_sprite_pos with the boss pos once the chip animates in, which
            -- would otherwise leave a stamp frame on the chip.
            if e.pfp_atlas and p.atlas ~= e.pfp_atlas then
                p.atlas = e.pfp_atlas
                if e.pfp_scale then
                    p.scale.x = e.pfp_scale.x
                    p.scale.y = e.pfp_scale.y
                end
                p:set_sprite_pos({x = 0, y = e.pfp_row or 0})
            elseif not p.animation or p.animation.x ~= 0 or p.animation.y ~= (e.pfp_row or 0) then
                p:set_sprite_pos({x = 0, y = e.pfp_row or 0})
            end
            -- Luchador reroll: move the badge onto the new boss as soon as it lands.
            local bb = e.boss_badge
            local bp = bb and _current_boss_pos(e.tag)
            if bp then
                local old = bb._war_boss_pos
                if not old or bp.x ~= old.x or bp.y ~= old.y then
                    bb:set_sprite_pos(bp)
                    bb._war_boss_pos = {x = bp.x, y = bp.y}
                end
            end
        end
    end
end

-- Apply rival chip treatment to the boss choice on the blind-select screen.
local _orig_blind_choice = create_UIBox_blind_choice
create_UIBox_blind_choice = function(type, run_info)
    local def = _orig_blind_choice(type, run_info)
    if run_info or type ~= "Boss" or not WAR.GAME.active then return def end
    if not WAR.is_rival_blind(G.P_BLINDS[G.GAME.round_resets.blind_choices.Boss]) then
        return def
    end

    local function find_chip(node)
        if _G.type(node) ~= "table" then return nil end
        if node.n == G.UIT.O and node.config and node.config.object
           and node.config.object.animation then
            return node.config.object
        end
        for _, child in ipairs(node.nodes or {}) do
            local hit = find_chip(child)
            if hit then return hit end
        end
    end

    local chip = find_chip(def)
    if chip then WAR.UI.attach_rival_icon(chip, "select") end
    return def
end

-- Per-frame func on HUD_blind_count: advances the count-up ease and updates text/scale.
G.FUNCS.war_blind_chip_scale = function(e)
    -- Advance ease if one is running. Whole chips only, like BMP: fractional
    -- steps just make the number jitter between text widths.
    local ease = WAR.GAME._score_ease
    if ease and G.TIMERS then
        local frac = ease.dur > 0
            and math.min((G.TIMERS.REAL - ease.start) / ease.dur, 1.0)
            or  1.0
        WAR.GAME.enemy_score_display = math.floor(ease.from + (ease.to - ease.from) * frac)
        if frac >= 1.0 then
            WAR.GAME.enemy_score_display = ease.to
            WAR.GAME._score_ease = nil
        end
    end

    WAR.UI._hud.enemy_hands = WAR.GAME.enemy_hands_masked and "???"
                              or tostring(WAR.GAME.enemy_hands or "?")

    if WAR.GAME.score_masked and WAR.GAME.score_masked() then
        WAR.UI._hud.enemy_score = "???"
        WAR.UI.sync_rival_icons()
        return
    end

    -- With no ease running the display value can be stale (it only moves while
    -- an ease exists), so fall back to the score the relay last reported.
    local display = (WAR.GAME._score_ease and WAR.GAME.enemy_score_display)
                    or WAR.GAME.enemy_score or 0
    WAR.UI._hud.enemy_score = WAR.SCORE.format(display)
    local s = tonumber(display) or 0
    if s > 0 then e.config.scale = scale_number(s, 0.7, 100000) end
    WAR.UI.sync_rival_icons()
end

-- Juice the chip count and hands display when a new enemyInfo arrives.
function WAR.UI.juice_pvp_hud()
    if not (WAR.GAME.is_pvp_blind and G.HUD_blind) then return end
    local ce = G.HUD_blind:get_UIE_by_ID("HUD_blind_count")
    local re = G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned")
    if ce then ce:juice_up() end
    if re then re:juice_up() end
end

-- Replace the ante counter with a lives display.
-- Called from game_hooks.lua once per run start (0.5 s after start_run).
--
-- Structure of hud_ante:
--   children[1]          R row  -> "ANTE" label text
--     children[1]        T node -> text = "ANTE"  (we change to "Lives")
--   children[2]          R row  -> number area
--     children[1]        O node -> config.object = DynaText(ante ref)  <- keep alive!
--     children[2]        T node -> text = " "   (spacer)
--     children[3]        T node -> text = "/ "  (we change to "vs")
--     children[4]        T node -> ref_table=G.GAME, ref_value='win_ante'  <- redirect
function WAR.UI.setup_lives_hud()
    if not WAR.GAME.active then return end
    if not (G.HUD and G.HUD.get_UIE_by_ID) then return end
    local hud_ante = G.HUD:get_UIE_by_ID("hud_ante")
    if not hud_ante then return end

    WAR.UI.refresh_hud()

    if hud_ante.children[1] and hud_ante.children[1].children[1] then
        hud_ante.children[1].children[1].config.text = localize('war_hud_lives')
    end

    local row = hud_ante.children[2]
    if not row then return end

    local o_node = row.children[1]
    if o_node and o_node.config and o_node.config.object
       and o_node.config.object.config then
        o_node.config.object.config.string = {
            { ref_table = WAR.UI._hud, ref_value = "my_lives" },
        }
        o_node.config.object.config.colours = { G.C.BLUE }
        o_node.config.object:update_text()
        WAR.UI._lives_dyna = o_node.config.object
    end

    if row.children[3] then
        row.children[3].config.text   = "vs"
        row.children[3].config.colour = G.C.UI.TEXT_DARK
    end

    if row.children[4] then
        local dynatext_scale = (o_node and o_node.config and o_node.config.object
                                and o_node.config.object.config.scale) or 0.8
        row.children[4].config.ref_table = WAR.UI._hud
        row.children[4].config.ref_value = "enemy_lives"
        row.children[4].config.colour    = G.C.RED
        row.children[4].config.scale     = dynatext_scale
    end

    G.HUD:recalculate()
end

-- Take over G.HUD_blind for the duration of a rival round.
function WAR.UI.update_blind_hud()
    if not WAR.GAME.active then return end
    if not (G.HUD_blind and G.HUD_blind.get_UIE_by_ID) then return end
    WAR.UI.refresh_hud()

    local count_el = G.HUD_blind:get_UIE_by_ID("HUD_blind_count")
    if count_el then
        count_el.config.ref_table = WAR.UI._hud
        count_el.config.ref_value = "enemy_score"
        count_el.config.func      = "war_blind_chip_scale"
    end

    -- Blind name -> opponent username
    local name_el = G.HUD_blind:get_UIE_by_ID("HUD_blind_name")
    if name_el and name_el.config and name_el.config.object then
        local obj = name_el.config.object
        obj._war_orig_string = obj.config.string
        obj._war_orig_maxw   = obj.config.maxw
        obj.config.string = {{ ref_table = WAR.UI._hud, ref_value = "enemy_name" }}
        obj.config.maxw   = 4.5
        obj.scale = obj.config.scale
        obj:update_text(true)
        if obj.config.maxw then
            obj.scale = obj.scale * math.min(1, obj.config.maxw / (obj.config.W or 1))
        end
        obj:update_text(true)
    end

    local hud_blind = G.HUD_blind:get_UIE_by_ID("HUD_blind")
    if hud_blind then
        local labels = hud_blind.children[2]
            and hud_blind.children[2].children[2]
            and hud_blind.children[2].children[2].children[2]
        if labels then
            if labels.children[1] and labels.children[1].children[1] then
                labels.children[1].children[1].config.text = localize('war_hud_enemy_score')
            end
            if labels.children[3] and labels.children[3].children[1] then
                labels.children[3].children[1].config.text = localize('war_hud_enemy_hands')
            end
        end
    end

    local reward_el = G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned")
    if reward_el then
        reward_el.parent.parent.states.visible = false
        reward_el.config.object.config.string = {
            { ref_table = WAR.UI._hud, ref_value = "enemy_hands" },
        }
        reward_el.config.object:update_text()
    end

    G.HUD_blind.alignment.offset.y = 0

    G.E_MANAGER:add_event(Event({
        trigger = 'after', delay = 0.15, blockable = false,
        func = function()
            if not G.HUD_blind then return true end
            local re = G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned")
            local ce = G.HUD_blind:get_UIE_by_ID("HUD_blind_count")
            if re then re.parent.parent.states.visible = true; re.config.object:pop_in(0) end
            if ce then ce:juice_up() end
            return true
        end,
    }))
end

-- Restore G.HUD_blind to vanilla state after the rival round ends.
function WAR.UI.reset_blind_hud()
    if not (G.HUD_blind and G.HUD_blind.get_UIE_by_ID) then return end

    local count_el = G.HUD_blind:get_UIE_by_ID("HUD_blind_count")
    if count_el then
        count_el.config.ref_table = G.GAME.blind
        count_el.config.ref_value = "chip_text"
        count_el.config.func      = nil
    end

    local name_el = G.HUD_blind:get_UIE_by_ID("HUD_blind_name")
    if name_el and name_el.config and name_el.config.object then
        local obj = name_el.config.object
        if obj._war_orig_string then
            obj.config.string = obj._war_orig_string
            obj.config.maxw   = obj._war_orig_maxw
            obj._war_orig_string = nil
            obj._war_orig_maxw   = nil
            obj.scale = obj.config.scale
            obj:update_text(true)
            if obj.config.maxw then
                obj.scale = obj.scale * math.min(1, obj.config.maxw / (obj.config.W or 1))
            end
            obj:update_text(true)
        end
    end

    local hud_blind = G.HUD_blind:get_UIE_by_ID("HUD_blind")
    if hud_blind then
        local labels = hud_blind.children[2]
            and hud_blind.children[2].children[2]
            and hud_blind.children[2].children[2].children[2]
        if labels then
            if labels.children[1] and labels.children[1].children[1] then
                labels.children[1].children[1].config.text = localize('ph_blind_score_at_least')
            end
            if labels.children[3] and labels.children[3].children[1] then
                labels.children[3].children[1].config.text = localize('ph_blind_reward')
            end
        end
    end

    local reward_el = G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned")
    if reward_el then
        reward_el.config.object.config.string = {
            { ref_table = G.GAME.current_round, ref_value = "dollars_to_be_earned" },
        }
        reward_el.config.object:update_text()
    end
end

-- ── Timer HUD ─────────────────────────────────────────────────────────────
-- When a blind timer is running, we hijack the "Round" label to say "Timer"
-- (or "Paused") and make the whole round-counter box clickable so the player
-- can pause/resume the visual countdown.  The relay's authoritative timer
-- keeps running regardless; local pause is display-only.

local function _round_label_node()
    if not (G.HUD and G.HUD.get_UIE_by_ID) then return nil, nil end
    local row = G.HUD:get_UIE_by_ID('row_round_text')
    if not row then return nil, nil end
    local c = row.parent
    local label = c and c.children[1] and c.children[1].children[1]
    return c, label
end

function WAR.UI.update_timer_hud_label()
    local _, label = _round_label_node()
    if not label then return end
    local t = WAR.GAME._pvp_timer
    if t then
        label.config.text = t.paused and localize('war_round_paused')
                                      or localize('war_round_timer')
    else
        label.config.text = localize('k_round')
    end
end

function WAR.UI.setup_timer_hud()
    local c = _round_label_node()
    if not c then return end
    local t = WAR.GAME._pvp_timer
    if c._war_timer_orig then
        -- Timer already set up: re-sync button presence if is_mine changed.
        if t and t.is_mine and not c.config.button then
            c.config.hover  = true
            c.config.button = 'war_timer_toggle'
            c.config.shadow = true
        elseif (not t or not t.is_mine) and c.config.button == 'war_timer_toggle' then
            c.config.hover  = c._war_timer_orig.hover
            c.config.button = c._war_timer_orig.button
            c.config.shadow = c._war_timer_orig.shadow
        end
        WAR.UI.update_timer_hud_label()
        return
    end
    c._war_timer_orig = {
        hover  = c.config.hover,
        button = c.config.button,
        shadow = c.config.shadow,
    }
    if t and t.is_mine then
        c.config.hover  = true
        c.config.button = 'war_timer_toggle'
        c.config.shadow = true
    end
    WAR.UI.update_timer_hud_label()
end

function WAR.UI.reset_timer_hud()
    local c, label = _round_label_node()
    if not c then return end
    if c._war_timer_orig then
        c.config.hover  = c._war_timer_orig.hover
        c.config.button = c._war_timer_orig.button
        c.config.shadow = c._war_timer_orig.shadow
        c._war_timer_orig = nil
    end
    if label then label.config.text = localize('k_round') end
end

-- Toggle sends to the relay, which pauses/resumes the authoritative countdown
-- and broadcasts the new state to both players via blindTimer.
G.FUNCS.war_timer_toggle = function(e)
    local t = WAR.GAME._pvp_timer
    if not (t and t.is_mine) then return end
    WAR.NET.send({ action = t.paused and "resumeTimer" or "pauseTimer" })
end

print("[WAR] ui/hud loaded")
