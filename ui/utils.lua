-- ui/utils.lua
-- Shared helpers. All War UI built on top of these.

WAR.UI.UTILS = {}

-- WAR.UI.open: show a War screen with a vanilla-style slide-up (bond='Weak', y=10).
-- Matches G.FUNCS.overlay_menu exactly: start offset y=10, target y=0, align_to_major.
function WAR.UI.open(definition, offset_y)
    if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
    G.SETTINGS.paused = true
    G.CONTROLLER.locks.frame_set = true
    G.CONTROLLER.locks.frame     = true
    G.CONTROLLER:mod_cursor_context_layer(1)
    G.OVERLAY_MENU = UIBox{
        definition = definition,
        config = {
            align  = "cm",
            offset = { x = 0, y = offset_y or 10 },
            major  = G.ROOM_ATTACH,
            bond   = "Weak",
        }
    }
    G.OVERLAY_MENU.alignment.offset.y = 0
    G.ROOM.jiggle = G.ROOM.jiggle + 1
    G.OVERLAY_MENU:align_to_major()
end

-- WAR.UI.open_popup: bottom-up slide for smaller overlay popups.
function WAR.UI.open_popup(definition)
    if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
    G.SETTINGS.paused = true
    G.CONTROLLER.locks.frame_set = true
    G.CONTROLLER.locks.frame     = true
    G.CONTROLLER:mod_cursor_context_layer(1)
    G.OVERLAY_MENU = UIBox{
        definition = definition,
        config = {
            align  = "cm",
            offset = { x = 0, y = 0 },
            major  = G.ROOM_ATTACH,
            bond   = "Weak",
        }
    }
    local box   = G.OVERLAY_MENU
    local SLIDE = 10
    local function place()
        box:align_to_major()
        box.VT.x = box.T.x
        box.VT.y = box.T.y + SLIDE
    end
    place()
    -- second pass in case a child object resized the box
    G.E_MANAGER:add_event(Event({
        trigger = "immediate", blockable = false,
        func = function()
            if G.OVERLAY_MENU == box then place() end
            return true
        end,
    }))
    G.ROOM.jiggle = G.ROOM.jiggle + 1
end

-- WAR.UI.open_instant: overlay popup, appears immediately with no animation.
-- bond='Glued' means animated child objects can't cause it to drift or slide.
function WAR.UI.open_instant(definition)
    if G.OVERLAY_MENU then G.OVERLAY_MENU:remove() end
    G.SETTINGS.paused = true
    G.CONTROLLER.locks.frame_set = true
    G.CONTROLLER.locks.frame     = true
    G.CONTROLLER:mod_cursor_context_layer(1)
    G.OVERLAY_MENU = UIBox{
        definition = definition,
        config = {
            align  = "cm",
            offset = { x = 0, y = 0 },
            major  = G.ROOM_ATTACH,
            bond   = "Glued",
        }
    }
    G.ROOM.jiggle = G.ROOM.jiggle + 1
end

-- WAR.UI.show_lobby: replaces the main menu button row with the lobby bar.
-- Mirrors G.FUNCS.display_lobby_main_menu_UI from BalatroMultiplayer exactly:
-- removes G.MAIN_MENU_UI and stores the lobby bar there instead.
function WAR.UI.show_lobby(definition)
    if G.MAIN_MENU_UI then G.MAIN_MENU_UI:remove() end
    -- Hide the profile/run button while in a lobby
    if G.PROFILE_BUTTON then G.PROFILE_BUTTON:remove(); G.PROFILE_BUTTON = nil end
    G.MAIN_MENU_UI = UIBox{
        definition = definition,
        config = {
            align  = "bmi",
            offset = { x = 0, y = 0 },
            major  = G.ROOM_ATTACH,
            bond   = "Glued",
        }
    }
    G.MAIN_MENU_UI.alignment.offset.y = 0
    G.ROOM.jiggle = G.ROOM.jiggle + 1
    G.MAIN_MENU_UI:align_to_major()
end

-- WAR.UI.hide_lobby: removes the lobby bar and restores the standard main menu.
function WAR.UI.hide_lobby()
    if G.MAIN_MENU_UI then G.MAIN_MENU_UI:remove() end
    G.MAIN_MENU_UI = UIBox{
        definition = create_UIBox_main_menu_buttons(),
        config = {
            align  = "bmi",
            offset = { x = 0, y = 0 },
            major  = G.ROOM_ATTACH,
            bond   = "Glued",
        }
    }
    G.MAIN_MENU_UI.alignment.offset.y = 0
    G.ROOM.jiggle = G.ROOM.jiggle + 1
    G.MAIN_MENU_UI:align_to_major()
    -- Restore profile button
    if not G.PROFILE_BUTTON and not G.F_DISP_USERNAME then
        G.PROFILE_BUTTON = UIBox{
            definition = create_UIBox_profile_button(),
            config = { align="bli", offset={x=0,y=0}, major=G.ROOM_ATTACH, bond="Glued" }
        }
        G.PROFILE_BUTTON.alignment.offset.x = 0
        G.PROFILE_BUTTON:align_to_major()
    end
end

-- WAR.UI.create_spacer: mirrors MP.UI.create_spacer exactly.
--   create_spacer()           -> horizontal gap (C, minw)
--   create_spacer(size, true) -> vertical gap   (R, minh)
function WAR.UI.create_spacer(size, row)
    size = size or 0.2
    if row then
        return { n=G.UIT.R, config={ align="cm", minh=size }, nodes={} }
    else
        return { n=G.UIT.C, config={ align="cm", minw=size }, nodes={} }
    end
end

-- convenience function for creating a blind sprite
function WAR.UI.create_blind_sprite(center, x, y, w, h)
    return SMODS.create_sprite(x, y, w, h, center.atlas or "blind_chips", center.pos or G.P_BLINDS.bl_small.pos)
end

-- creates a mini blind icon that is attached to a given node on the bottom left
function WAR.UI.mini_blind(center, size, node)
    return UIBox({
        definition = {
            n = G.UIT.ROOT,
            config = {
                colour = G.C.CLEAR,
            },
            nodes = {
                {
                    n = G.UIT.O,
                    config = {
                        object = WAR.UI.create_blind_sprite(center, node.T.x, node.T.y, size, size)
                    }
                }
            }
        },
        config = {
            parent = node,
            align = "bli",
            offset = {
                x = -size / 6, y = size / 6
            },
        }
    })
end

print("[WAR] ui/utils loaded")
