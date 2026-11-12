SMODS.Joker {
    key = "title_card",
    atlas = "war_titlecard",
    pos = {x = 0, y = 0},
    soul_pos = {x = 0, y = 1},
    display_size = { w = 115 * 1.3, h = 85 * 1.3 },

    unlocked = true,
    discovered = true,
    no_collection = true,
    no_mod_badges = true,

    in_pool = function() return false end
}

WAR.description_loc_vars = function()
    return {
        text_colour = G.C.WHITE,
        background_colour = G.C.CLEAR,
        scale = 1.25
    }
end

function WAR.custom_ui(nodes)
    nodes[#nodes - 1] = nil;

    local warcard_area = CardArea(
        G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2,
        G.ROOM.T.h,
        2 * G.CARD_W,
        G.CARD_H,
        { card_limit = 1, type = "title_2", highlight_limit = 0, collection = true }
    )

    local card =
        Card(warcard_area.T.x + warcard_area.T.w / 2, warcard_area.T.y, G.CARD_W, G.CARD_H, G.P_CARDS.empty, G.P_CENTERS["j_war_title_card"], {
            bypass_lock = true,
            bypass_discovery_center = true,
        })
    card.no_ui = true
    warcard_area:emplace(card)
    local war_card = {
        n = G.UIT.O,
        config = {
            object = warcard_area,
        },
    }

    local loc_desc = nodes[#nodes]
    nodes[#nodes] = {
        n = G.UIT.C,
        config = { padding = 0.2, align = "cm" },
        nodes = {
            {
                n = G.UIT.R,
                config = { minw = 5, align = "tm" },
                nodes = { war_card }
            }, {
                n = G.UIT.R,
                config = { minw = 5, padding = 0.2, align = "cm" },
                nodes = { loc_desc }
            }
        }
    }
    -- nodes[#nodes+1] = z
end