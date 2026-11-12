-- objects/blinds/jimbo.lua

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
