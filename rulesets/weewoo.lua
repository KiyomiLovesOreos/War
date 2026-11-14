
WAR.RULESETS["weeworld"] = {
    key         = "weeworld",
    layers      = {},


        -- custom stuff for the ruleset
    ignoredSets = {
        Default = true,
        Edition = true,
        Enhanced = true,
        Back = true
    }

    -- wowie ME, BITTERDOES did something here!!
    -- removes majority of all Jokers, Consumables and Vouchers, other than that
}

local maxSets = {
    -- set name = int
    Joker = 30,
    Tarot = 8,
    Planet = 6,
    Spectral = 8,
    Booster = 16,
    Voucher = 4,
}

WAR.RULESETS["weeworld"]["activate"] = function()

    G.GAME.banned_keys = {}

    local sets = {}
    local t2Vouchers = {}

    for _, object in pairs(G.P_CENTERS) do -- differentiate sets    
        if
            not object.set or not object.key or
            WAR.RULESETS["weeworld"].ignoredSets[object.set] --or
            -- here we'll check if host has mod this items from
        then goto continue end

        if object.requires then table.insert(t2Vouchers, object) goto continue end

        sets[object.set] = sets[object.set] or {}
        table.insert(sets[object.set], object)

        ::continue::
    end
    -- where the magic happens, shuffles set tables, then top to bottom until hitting maxSet
    for set, objects in pairs(sets) do
        table.sort(objects, function(a, b) return a.key < b.key end)

        for ix = #objects, 2, -1 do
            local j = pseudorandom(objects[ix].key, 1, ix)
            objects[ix], objects[j] = objects[j], objects[ix]
        end

        for i = #objects, maxSets[set] or #objects*1/4, -1 do -- 1/4 meaning leaves 1 4th
            print(objects[i])
            G.GAME.banned_keys[objects[i].key] = true
        end
    end


    -- remove corresponding tier two vouchers
    for _, voucher in pairs(t2Vouchers) do
        for _, required in pairs(voucher.requires) do
            if G.GAME.banned_keys[required] then
                G.GAME.banned_keys[voucher.key] = true
                break
            end
        end
    end
end