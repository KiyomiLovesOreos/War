-- objects/blinds/jimbo.lua

-- The war_jimbo blind is registered but never appears in a run (in_pool=false).
-- It stays so runs saved before the rival-blind rework still resolve the key,
-- and so the blind-select screen has a named entry for the rival position.
SMODS.Blind({
    key         = "war_jimbo",
    mult        = 1,
    dollars     = 5,
    boss_colour = {0.25, 0.66, 0.92, 1},
    boss        = { min = 1, max = 10 },
    atlas       = "war_icons_free",
    pos         = { x = 0, y = 0 },
    discovered  = true,
    in_pool     = function(self) return false end,
})

function WAR.icon_sprite(row, size)
    size = size or 1.4
    local atlas = G.ANIMATION_ATLAS and G.ANIMATION_ATLAS["war_icons_free"]
    if not atlas then return nil end
    local s = AnimatedSprite(0, 0, size, size, atlas, {x=0, y=row or 0})
    s:define_draw_steps({
        { shader="dissolve", shadow_height=0.05 },
        { shader="dissolve" },
    })
    return s
end

function WAR.is_pvp_blind() return WAR.GAME.pvp_round() end

print("[WAR] pvp blind loaded")
