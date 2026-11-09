-- config.lua
-- Defaults for the mod's saved settings (SMODS merges config/War.jkr over this).
-- Add new settings here with a sane default so old saves keep working.

return {
    icon        = "jimbo",    -- player icon key, see WAR.ICONS in core/avatar.lua
    server_env  = "release",  -- "release" → port 7777, "beta" → port 7778 (same VPS, separate DB)
    war_profile = 69,         -- profile slot used for War games (all unlocks, isolated saves)
}
