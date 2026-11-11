-- gamemodes/attrition.lua  (TODO: rename file to vanilla.lua)
-- Standard PvP mode — vanilla item pool, PvP boss blinds from Ante 3.

WAR.GAMEMODES["vanilla"] = {
    key             = "vanilla",
    name            = "war_gm_vanilla_name",
    description     = {
        "war_gm_vanilla_desc_1",
        "war_gm_vanilla_desc_2",
        "war_gm_vanilla_desc_3",
        "war_gm_vanilla_desc_4",
    },
    starting_lives  = 4,
    pvp_start_ante  = 3,
    rulesets        = {"standard"},
}

print("[WAR] gamemode: vanilla loaded")
