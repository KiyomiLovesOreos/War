-- core/avatar.lua
-- Player icons: the sprite the opponent sees next to your name while in a run.
-- Icons are rows on the split atlas sheets (icons_free/achievement/special.png),
-- 21 animation frames per row. The chosen key is sent as a plain string to the
-- relay; no image data crosses the wire.

WAR.AVATAR = {}

-- key     = stable id used on the wire (never shown to players directly)
-- atlas   = which war_icons_* atlas the sprite lives in
-- row     = row index within that atlas
-- achieve = achievement key required; shows locked placeholder if not entitled
-- special = if true, hidden entirely unless the account has been granted this key
WAR.ICONS = {
    { key = "jimbo",           atlas = "war_icons_free",         row = 0 },
    { key = "blueprint",       atlas = "war_icons_free",         row = 1 },
    { key = "brainstorm",      atlas = "war_icons_free",         row = 2 },
    { key = "verity",          atlas = "war_icons_free",         row = 3 },
    { key = "sock_and_buskin", atlas = "war_icons_free",         row = 4 },
    { key = "photograph",      atlas = "war_icons_free",         row = 5 },
    { key = "drool",           atlas = "war_icons_free",         row = 6 },
    { key = "stencil",         atlas = "war_icons_free",         row = 7 },
    { key = "spades",          atlas = "war_icons_free",         row = 8 },
    { key = "hearts",          atlas = "war_icons_free",         row = 9 },
    { key = "clubs",           atlas = "war_icons_free",         row = 10 },
    { key = "diamonds",        atlas = "war_icons_free",         row = 11 },
    { key = "spades_hc",       atlas = "war_icons_free",         row = 12 },
    { key = "hearts_hc",       atlas = "war_icons_free",         row = 13 },
    { key = "clubs_hc",        atlas = "war_icons_free",         row = 14 },
    { key = "diamonds_hc",     atlas = "war_icons_free",         row = 15 },
    { key = "ralsei",          atlas = "war_icons_free",         row = 16 },
    { key = "eight_ball",      atlas = "war_icons_free",         row = 17 },
    { key = "even_steven",     atlas = "war_icons_free",         row = 18 },
    { key = "odd_todd",        atlas = "war_icons_free",         row = 19 },
    { key = "missing",         atlas = "war_icons_free",         row = 20 },
    { key = "azure",           atlas = "war_icons_free",         row = 21 },
    { key = "flowery",         atlas = "war_icons_free",         row = 22 },
    { key = "pig",             atlas = "war_icons_free",         row = 23 },
    { key = "persona",         atlas = "war_icons_free",         row = 24 },
    { key = "raised_fist",     atlas = "war_icons_free",         row = 25 },
    { key = "popcorn",         atlas = "war_icons_free",         row = 26 },
    { key = "gift_card",       atlas = "war_icons_free",         row = 27 },
    { key = "stamp",           atlas = "war_icons_free",         row = 28 },
    { key = "superposition",   atlas = "war_icons_free",         row = 29 },
    { key = "fibonacci",       atlas = "war_icons_free",         row = 30 },
    { key = "scholar",         atlas = "war_icons_free",         row = 31 },
    { key = "ride_the_bus",    atlas = "war_icons_free",         row = 32 },
    { key = "pareidolia",      atlas = "war_icons_free",         row = 33 },
    { key = "brutalists_heart",atlas = "war_icons_free",         row = 34 },
    { key = "chud",            atlas = "war_icons_free",         row = 35 },
    { key = "sob",             atlas = "war_icons_free",         row = 36 },
    { key = "tasque_manager",  atlas = "war_icons_free",         row = 37 },
    { key = "jolly",           atlas = "war_icons_achievement",  row = 0,  achieve = "jolly" },
    { key = "oops",            atlas = "war_icons_achievement",  row = 1,  achieve = "oops" },
    { key = "droll",           atlas = "war_icons_achievement",  row = 2,  achieve = "droll" },
    { key = "meta",            atlas = "war_icons_achievement",  row = 3,  achieve = "meta" },
    { key = "brilliant",       atlas = "war_icons_achievement",  row = 4,  achieve = "brilliant" },
    { key = "blunder",         atlas = "war_icons_achievement",  row = 5,  achieve = "blunder" },
    { key = "the_soul",        atlas = "war_icons_achievement",  row = 6,  achieve = "the_soul" },
    { key = "oneshot",         atlas = "war_icons_achievement",  row = 7,  achieve = "oneshot" },
    { key = "egg",             atlas = "war_icons_achievement",  row = 8,  achieve = "egg" },
    { key = "bloodstone",      atlas = "war_icons_achievement",  row = 9,  achieve = "bloodstone" },
    { key = "pizza",           atlas = "war_icons_achievement",  row = 10, achieve = "pizza" },
    { key = "riff_raff",       atlas = "war_icons_achievement",  row = 11, achieve = "riff_raff" },
    { key = "garygpt",         atlas = "war_icons_achievement",  row = 12, achieve = "garygpt" },
    { key = "missing_joker",   atlas = "war_icons_achievement",  row = 13, achieve = "missing_joker" },
    { key = "cola",            atlas = "war_icons_achievement",  row = 14, achieve = "cola" },
    { key = "osage",           atlas = "war_icons_achievement",  row = 15, achieve = "osage" },
    { key = "stone",           atlas = "war_icons_achievement",  row = 16, achieve = "stone" },
    { key = "gold",            atlas = "war_icons_achievement",  row = 17, achieve = "gold" },
    { key = "steel",           atlas = "war_icons_achievement",  row = 18, achieve = "steel" },
    { key = "wild",            atlas = "war_icons_achievement",  row = 19, achieve = "wild" },
    { key = "mult",            atlas = "war_icons_achievement",  row = 20, achieve = "mult" },
    { key = "lucky",           atlas = "war_icons_achievement",  row = 21, achieve = "lucky" },
    { key = "white_stake",     atlas = "war_icons_achievement",  row = 22, achieve = "white_stake" },
    { key = "red_stake",       atlas = "war_icons_achievement",  row = 23, achieve = "red_stake" },
    { key = "green_stake",     atlas = "war_icons_achievement",  row = 24, achieve = "green_stake" },
    { key = "blue_stake",      atlas = "war_icons_achievement",  row = 25, achieve = "blue_stake" },
    { key = "black_stake",     atlas = "war_icons_achievement",  row = 26, achieve = "black_stake" },
    { key = "purple_stake",    atlas = "war_icons_achievement",  row = 27, achieve = "purple_stake" },
    { key = "orange_stake",    atlas = "war_icons_achievement",  row = 28, achieve = "orange_stake" },
    { key = "gold_stake",      atlas = "war_icons_achievement",  row = 29, achieve = "gold_stake" },
    { key = "jimbo_stake",     atlas = "war_icons_achievement",  row = 30, achieve = "jimbo_stake" },
    { key = "red_deck",        atlas = "war_icons_achievement",  row = 31, achieve = "red_deck" },
    { key = "blue_deck",       atlas = "war_icons_achievement",  row = 32, achieve = "blue_deck" },
    { key = "yellow_deck",     atlas = "war_icons_achievement",  row = 33, achieve = "yellow_deck" },
    { key = "green_deck",      atlas = "war_icons_achievement",  row = 34, achieve = "green_deck" },
    { key = "black_deck",      atlas = "war_icons_achievement",  row = 35, achieve = "black_deck" },
    { key = "ghost_deck",      atlas = "war_icons_achievement",  row = 36, achieve = "ghost_deck" },
    { key = "painted_deck",    atlas = "war_icons_achievement",  row = 37, achieve = "painted_deck" },
    { key = "plasma_deck",     atlas = "war_icons_achievement",  row = 38, achieve = "plasma_deck" },
    { key = "red_seal",        atlas = "war_icons_achievement",  row = 39, achieve = "red_seal" },
    { key = "blue_seal",       atlas = "war_icons_achievement",  row = 40, achieve = "blue_seal" },
    { key = "gold_seal",       atlas = "war_icons_achievement",  row = 41, achieve = "gold_seal" },
    { key = "purple_seal",     atlas = "war_icons_achievement",  row = 42, achieve = "purple_seal" },
    { key = "eyes",            atlas = "war_icons_achievement",  row = 43, achieve = "eyes" },
    { key = "hack",            atlas = "war_icons_achievement",  row = 44, achieve = "hack" },
    { key = "hit_the_road",    atlas = "war_icons_achievement",  row = 45, achieve = "hit_the_road" },
    { key = "supernova",       atlas = "war_icons_achievement",  row = 46, achieve = "supernova" },
    { key = "bean",            atlas = "war_icons_special",      row = 0,  special = true },
    { key = "zaino",           atlas = "war_icons_special",      row = 1,  special = true },
    { key = "doc",             atlas = "war_icons_special",      row = 2,  special = true },
    { key = "murphy",          atlas = "war_icons_special",      row = 3,  special = true },
    { key = "thunderedge",     atlas = "war_icons_special",      row = 4,  special = true },
    { key = "soulware",        atlas = "war_icons_special",      row = 5,  special = true },
    { key = "sheila",          atlas = "war_icons_special",      row = 6,  special = true },
    { key = "astra",           atlas = "war_icons_special",      row = 7,  special = true },
    { key = "lizie",           atlas = "war_icons_special",      row = 8,  special = true },
    { key = "inky",            atlas = "war_icons_special",      row = 9,  special = true },
    { key = "revo",            atlas = "war_icons_special",      row = 10, special = true },
    { key = "argel",           atlas = "war_icons_special",      row = 11, special = true },
    { key = "baggute",         atlas = "war_icons_special",      row = 12, special = true },
    { key = "amolyte",         atlas = "war_icons_special",      row = 13, special = true },
    { key = "gabby",           atlas = "war_icons_special",      row = 14, special = true },
}

WAR.AVATAR.selected = "jimbo"

-- Lookup index, built once from the ordered table so callers don't rescan it.
WAR.ICONS_BY_KEY = {}
for _, icon in ipairs(WAR.ICONS) do WAR.ICONS_BY_KEY[icon.key] = icon end

-- kind = "free" | "achievement" | "special", in sheet order.
function WAR.AVATAR.by_kind(kind)
    local out = {}
    for _, icon in ipairs(WAR.ICONS) do
        local k = icon.special and "special" or (icon.achieve and "achievement" or "free")
        if k == kind then out[#out + 1] = icon end
    end
    return out
end

-- Entitlements delivered by the relay on login; both achievement and special icon keys land here.
WAR.AVATAR.entitlements = {}

function WAR.AVATAR.icon(key)
    return WAR.ICONS_BY_KEY[key]
end

function WAR.AVATAR.is_entitled(key)
    local icon = WAR.AVATAR.icon(key)
    if not icon then return false end
    if not icon.achieve and not icon.special then return true end
    for _, k in ipairs(WAR.AVATAR.entitlements) do
        if k == key then return true end
    end
    return false
end

function WAR.AVATAR.grant_local(key)
    for _, k in ipairs(WAR.AVATAR.entitlements) do
        if k == key then return end
    end
    WAR.AVATAR.entitlements[#WAR.AVATAR.entitlements + 1] = key
end

-- Stored in SMODS config (config/War.jkr, field `icon`).
-- War_pfp.txt is read once on first load to migrate choices from an older build.

local function _write_setting(key)
    if WAR.config then WAR.config.icon = key end
    if SMODS and SMODS.save_mod_config then SMODS.save_mod_config(WAR) end
end

function WAR.AVATAR.load_choice()
    local key = WAR.config and WAR.config.icon

    if not WAR.AVATAR.icon(key) then
        local ok, data = pcall(love.filesystem.read, "War_pfp.txt")
        if ok and data then
            local legacy = data:match("^%s*(.-)%s*$")
            if WAR.AVATAR.icon(legacy) then
                WAR.AVATAR.selected = legacy
                _write_setting(legacy)
                return
            end
        end
        key = "jimbo"
    end

    WAR.AVATAR.selected = key
    _write_setting(key)
end

function WAR.AVATAR.save_choice(key)
    if not WAR.AVATAR.icon(key) then return end
    WAR.AVATAR.selected = key
    _write_setting(key)
end

WAR.AVATAR._enemy_host  = "jimbo"
WAR.AVATAR._enemy_guest = "jimbo"

-- role = "host" | "guest"
function WAR.AVATAR.set_enemy(role, key)
    WAR.AVATAR["_enemy_" .. (role or "enemy")] = WAR.AVATAR.icon(key) and key or "jimbo"
end

function WAR.AVATAR.sprite_for(key, size)
    local icon  = WAR.AVATAR.icon(key)
    local atlas_key = icon.atlas or "war_icons_free"
    local atlas = G.ANIMATION_ATLAS and G.ANIMATION_ATLAS[atlas_key]
    if not icon or not atlas then return nil end
    size = size or 0.5
    local ok, s = pcall(AnimatedSprite, 0, 0, size, size, atlas, { x = 0, y = icon.row })
    return ok and s or nil
end

-- role = "host"|"guest"|nil  (nil = own icon)
function WAR.AVATAR.sprite(role, size)
    local key = role and WAR.AVATAR["_enemy_" .. role] or WAR.AVATAR.selected
    return WAR.AVATAR.sprite_for(key, size)
end

print("[WAR] avatar loaded")
