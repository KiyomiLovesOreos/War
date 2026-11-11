-- compat/cardsleeves.lua
-- Compatibility with the CardSleeves mod.
-- Sends the selected sleeve key over the relay so both players see
-- each other's sleeve in the lobby panel deck card.

if not (SMODS.Mods and SMODS.Mods["CardSleeves"]) then return end

WAR.COMPAT = WAR.COMPAT or {}

-- Called from lobby.lua's start_run intercept to read the chosen sleeve.
-- Returns the sleeve key string, or nil if none / the blank slot was chosen.
function WAR.COMPAT.capture_sleeve(args)
    local key = (args and args.casl_sleeve_choice)
             or G.viewed_sleeve
             or (G.GAME and G.GAME.selected_sleeve)
    if not key or key == "sleeve_casl_none" then return nil end
    return key
end

-- Returns a Sprite for the given sleeve key at size w×h, ready to draw
-- over the deck card in the lobby panel. Returns nil on any failure.
function WAR.COMPAT.sleeve_sprite(key, w, h)
    if not key or key == "sleeve_casl_none" then return nil end
    local center = CardSleeves.Sleeve:get_obj(key)
    if not center or not center.atlas or not center.pos then return nil end
    local atlas = G.ASSET_ATLAS and G.ASSET_ATLAS[center.atlas]
    if not atlas then return nil end
    return Sprite(0, 0, w, h, atlas, center.pos)
end

WAR.log("[WAR] compat/cardsleeves loaded")

