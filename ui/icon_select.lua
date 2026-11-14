-- ui/icon_select.lua

local COLS = 8
local CHIP = 0.8

local function _icon_spr(atlas_key, row)
    local atlas = G.ANIMATION_ATLAS and G.ANIMATION_ATLAS[atlas_key]
    if not atlas then return nil end
    local ok, spr = pcall(AnimatedSprite, 0, 0, CHIP, CHIP, atlas, { x=0, y=row })
    if not ok or not spr then return nil end
    spr:define_draw_steps({ {shader="dissolve", shadow_height=0.05}, {shader="dissolve"} })
    spr.states.drag.can    = false
    spr.states.collide.can = false
    return spr
end

local function icon_cell(icon, selected)
    local entitled = WAR.AVATAR.is_entitled(icon.key)

    if icon.achieve and not entitled then
        local locked_spr = _icon_spr("war_icons_locked", 0)
        local inner = locked_spr
            and { n=G.UIT.O, config={ object=locked_spr } }
            or  { n=G.UIT.B, config={ w=CHIP, h=CHIP } }
        return { n=G.UIT.C, config={
            id      = "war_icon_cell_" .. icon.key,
            align   = "cm", r=0.08, padding=0.06,
            colour  = { 0, 0, 0, 0 },
            hover   = true,
            tooltip = { title = localize{ key = "war_icon_" .. icon.key, set = 'WAR_Icon', type = 'raw_descriptions' }[1] or icon.key },
        }, nodes={ inner }}
    end

    local spr = _icon_spr(icon.atlas or "war_icons_free", icon.row or 0)
    local inner = spr
        and { n=G.UIT.O, config={ object=spr } }
        or  { n=G.UIT.B, config={ w=CHIP, h=CHIP } }

    return { n=G.UIT.C, config={
        id        = "war_icon_cell_" .. icon.key,
        align     = "cm", r=0.08, padding=0.06,
        colour    = selected and {0.18, 0.55, 0.18, 1} or {0, 0, 0, 0},
        emboss    = selected and 0.08 or nil,
        hover     = true,
        button    = "war_select_icon",
        tooltip = { title = localize{ key = "war_icon_" .. icon.key, set = 'WAR_Icon', type = 'name_text' } or icon.key },
        ref_table = { icon_key = icon.key },
        ref_value = "icon_key",
    }, nodes={ inner }}
end

local function build_page(icons_list)
    local rows, row = {}, nil
    for i, icon in ipairs(icons_list) do
        if (i - 1) % COLS == 0 then row = {}; rows[#rows+1] = row end
        row[#row+1] = icon_cell(icon, WAR.AVATAR.selected == icon.key)
    end
    local row_nodes = {}
    for _, r in ipairs(rows) do
        row_nodes[#row_nodes+1] = { n=G.UIT.R, config={ align="cm" }, nodes=r }
    end
    if not row_nodes[1] then
        row_nodes[1] = { n=G.UIT.R, config={ align="cm" }, nodes={
            { n=G.UIT.T, config={ text=localize("war_none") or "None", scale=0.4,
                colour=G.C.UI.TEXT_INACTIVE } }
        }}
    end
    return { n=G.UIT.ROOT, config={
        emboss=0.05, minh=4, r=0.1, minw=10,
        align="tm", padding=0.2, colour=G.C.BLACK,
    }, nodes={
        { n=G.UIT.R, config={ align="cm", r=0.1, colour=G.C.BLACK, padding=0.1, emboss=0.05 },
          nodes=row_nodes },
    }}
end

function G.UIDEF.war_icon_select()
    local free_list    = WAR.AVATAR.by_kind("free")
    local ach_list     = WAR.AVATAR.by_kind("achievement")
    local special_list = {}
    local logged_in    = WAR.AUTH and WAR.AUTH.state == "logged_in"

    -- Specials only exist for accounts that were granted them.
    for _, icon in ipairs(WAR.AVATAR.by_kind("special")) do
        if WAR.AVATAR.is_entitled(icon.key) then
            special_list[#special_list+1] = icon
        end
    end

    local tabs = {
        { label  = localize("war_tab_icons_free"),
          chosen = true,
          tab_definition_function = function() return build_page(free_list) end },
        { label  = localize("war_tab_icons_achievement"),
          tab_definition_function = function() return build_page(ach_list) end },
    }
    if logged_in and #special_list > 0 then
        tabs[#tabs+1] = {
            label  = localize("war_tab_icons_special"),
            tab_definition_function = function() return build_page(special_list) end,
        }
    end

    return create_UIBox_generic_options({
        back_func = "war_back_to_config",
        contents = {
            { n=G.UIT.C, config={ align="cm", padding=0 }, nodes={
                create_tabs({ colour=G.C.BOOSTER, tabs=tabs }),
            }},
        },
    })
end

G.FUNCS.war_open_icon_select = function(e)
    WAR.UI.open_instant(G.UIDEF.war_icon_select())
end

G.FUNCS.war_select_icon = function(e)
    local key = e.config.ref_table and e.config.ref_table.icon_key
    if not key then return end
    if not WAR.AVATAR.is_entitled(key) then return end
    WAR.AVATAR.save_choice(key)

    local repainted = false
    for _, icon in ipairs(WAR.ICONS) do
        local cell = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("war_icon_cell_" .. icon.key)
        if cell then
            local sel = (icon.key == key)
            cell.config.colour = sel and {0.18, 0.55, 0.18, 1} or {0, 0, 0, 0}
            cell.config.emboss = sel and 0.08 or nil
            repainted = true
        end
    end
    if not repainted then WAR.UI.open_instant(G.UIDEF.war_icon_select()) end
end

print("[WAR] ui/icon_select loaded")
