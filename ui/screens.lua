-- ui/screens.lua
-- All pre-lobby overlay screens.

local _orig_create_UIBox_main_menu_buttons = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
    local menu = _orig_create_UIBox_main_menu_buttons()
    pcall(function()
        menu.nodes[1].nodes[1].nodes[1].nodes[1].config.button = "war_play"
    end)
    return menu
end

function G.UIDEF.war_play_options()
    return create_UIBox_generic_options({
        contents = {
            UIBox_button({ label={localize('war_single_player')}, button="war_singleplayer",
                           colour=G.C.BLUE,  minw=5, minh=0.8 }),
            UIBox_button({ label={localize('war_online')},        button="war_online",
                           colour=G.C.GREEN, minw=5, minh=0.8 }),
        },
    })
end

function G.FUNCS.war_play(e)       WAR.UI.open(G.UIDEF.war_play_options()) end
function G.FUNCS.war_singleplayer(e)
    G.FUNCS.exit_overlay_menu()
    G.FUNCS.setup_run(e)
end
function G.FUNCS.war_online(e)     WAR.UI.open(G.UIDEF.war_private_options()) end
function G.FUNCS.war_private(e)    WAR.UI.open(G.UIDEF.war_private_options()) end

function G.UIDEF.war_private_options()
    return create_UIBox_generic_options({
        back_func = "war_play",
        contents = {
            UIBox_button({ label={localize('war_join_lobby')},   button="war_join_screen",
                           colour=G.C.GREEN,     minw=5, minh=0.8 }),
            UIBox_button({ label={localize('war_create_lobby')}, button="war_open_gamemode_select",
                           colour=G.C.BLUE, minw=5, minh=0.8 }),
        },
    })
end

-- Each element wrapped in R so create_UIBox_generic_options stacks them vertically.

WAR.UI._join_code = { code="" }

function G.UIDEF.war_join_screen()
    WAR.UI._join_code.code = ""
    return create_UIBox_generic_options({
        back_func = "war_private",
        contents = {
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                create_text_input({ id="war_join_code", w=5, h=0.9,
                    prompt_text=localize('war_lobby_code_prompt'), max_length=5, all_caps=true,
                    ref_table=WAR.UI._join_code, ref_value="code" }),
            }},
            UIBox_button({ label={localize('war_paste_code')}, button="war_paste_code",
                           colour=G.C.PERISHABLE, minw=5 }),
            UIBox_button({ label={localize('war_join')},       button="war_do_join",
                           colour=G.C.GREEN, minw=5, minh=0.8 }),
        },
    })
end

function G.FUNCS.war_join_screen(e)
    WAR.UI.open(G.UIDEF.war_join_screen())
end

function G.FUNCS.war_paste_code(e)
    local ok, text = pcall(function() return love.system.getClipboardText() end)
    if ok and text then
        WAR.UI._join_code.code = string.sub(string.upper(text:gsub("[^%a%d]","")), 1, 5)
    end
end

function G.FUNCS.war_do_join(e)
    local code = (WAR.UI._join_code.code or ""):gsub("%s",""):upper()
    if #code < 5 then return end
    G.FUNCS.exit_overlay_menu()
    local ok, err = WAR.LOBBY.join(code)
    if not ok then
        WAR.UI.open(create_UIBox_generic_options({
            back_func = "war_join_screen",
            contents = {
                { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                    { n=G.UIT.T, config={ text=localize('war_could_not_join')..WAR.error_text(err),
                        scale=0.38, colour=G.C.RED, shadow=true }},
                }},
            },
        }))
    end
end

function G.FUNCS.war_do_create(e)
    G.FUNCS.exit_overlay_menu()
    local ok, err = WAR.LOBBY.create()
    if not ok then
        WAR.UI.open(create_UIBox_generic_options({
            back_func = "war_private",
            contents = {
                { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                    { n=G.UIT.T, config={ text=localize('war_could_not_create')..WAR.error_text(err),
                        scale=0.38, colour=G.C.RED, shadow=true }},
                }},
            },
        }))
    end
    -- success: server replies "created" -> sync.lua -> WAR.UI.on_lobby_created()
end

WAR.UI._sel_gamemode = nil
WAR.UI._sel_ruleset  = nil

-- Ordered display list of gamemodes
local function war_gm_list()
    local keys = {"vanilla"}   -- add new gamemode keys here in desired display order
    local out = {}
    for _, k in ipairs(keys) do
        if WAR.GAMEMODES[k] then out[#out+1] = WAR.GAMEMODES[k] end
    end
    return out
end

-- Ordered list of rulesets available for a given gamemode
local function war_rs_list(gm_key)
    local gm = WAR.GAMEMODES[gm_key]
    if not gm then return {} end
    local out = {}
    local blacklist = gm.rulesetBlacklist or {}
    for i, k in pairs(WAR.RULESETS or {}) do
        if not blacklist[k] then out[#out+1] = WAR.RULESETS[i] end
    end
    return out
end

-- Styled section pill — matches the reference mod's category header
local function war_pill(text, col)
    col = col or mix_colours(G.C.ORANGE, G.C.BLACK, 0.6)
    return { n=G.UIT.R, config={ align="cm", padding=0.05 }, nodes={
        { n=G.UIT.R, config={
            align="cm", r=0.1, outline=1, line_emboss=1,
            outline_colour=col, colour=mix_colours(col, G.C.BLACK, 0.4),
            minw=3.2, emboss=0.1, padding=0.07,
        }, nodes={
            { n=G.UIT.T, config={ text=text, scale=0.45, colour=G.C.WHITE, shadow=true }},
        }},
    }}
end

-- Right info panel: outer C has no colour so it won't flex-expand in the row;
-- inner R carries the dark background, sizes to the inner content column.
local function war_info_panel(nodes)
    return { n=G.UIT.C, config={ align="tm", minw=6.5 }, nodes={
        { n=G.UIT.R, config={
            align="cm", r=0.1, colour=G.C.BLACK, emboss=0.05,
            padding=0.25, minh=5.8,
        }, nodes={
            { n=G.UIT.C, config={ align="tm", minw=6.0 }, nodes=nodes },
        }},
    }}
end

local function war_do_create_with_config()
    -- Config already populated by selection screens
    G.FUNCS.exit_overlay_menu()
    local ok, err = WAR.LOBBY.create()
    if not ok then
        WAR.UI.open(create_UIBox_generic_options({
            back_func = "war_private",
            contents = {
                { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                    { n=G.UIT.T, config={ text=localize('war_could_not_create')..WAR.error_text(err),
                        scale=0.38, colour=G.C.RED, shadow=true }},
                }},
            },
        }))
    end
    -- success: server replies "created" → sync.lua → WAR.UI.on_lobby_created()
end

function G.UIDEF.war_gamemode_select(sel_key)
    local gms = war_gm_list()
    if not sel_key and gms[1] then sel_key = gms[1].key end
    local sel = WAR.GAMEMODES[sel_key] or gms[1]
    WAR.UI._sel_gamemode = sel and sel.key

    -- Left: pill + gamemode buttons
    local left = { war_pill(localize('war_gamemodes'), mix_colours(G.C.ORANGE, G.C.BLACK, 0.6)) }
    for _, gm in ipairs(gms) do
        left[#left+1] = { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={
            UIBox_button({
                id="gm_"..gm.key, col=true,
                chosen=sel_key == gm.key and "vert" or false,
                label={localize("war_gm_".. gm.key.. "_name") or ""}, button="war_select_gamemode",
                colour=G.C.RED, minw=3.0, scale=0.42, minh=0.65,
            }),
        }}
    end

    -- Right: description lines + confirm button
    local has_rulesets = sel and #war_rs_list(sel.key) > 1
    local confirm_label = has_rulesets and localize('war_next') or localize('war_create_lobby')
    local right_nodes = {}
    if sel then
        local predesc = localize("war_gm_".. sel.key.. "_desc")
        local desc = type(predesc) == "table" and predesc or {predesc or ""}
        for _, line in ipairs(desc) do
            right_nodes[#right_nodes+1] = { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={
                { n=G.UIT.T, config={ text=line, scale=0.38, colour=G.C.UI.TEXT_LIGHT }},
                -- pretty sure this'll crash if theres a table in the desc bt whatever
            }}
        end
    end
    right_nodes[#right_nodes+1] = { n=G.UIT.R, config={ align="cm", minh=0.4 }, nodes={} }
    right_nodes[#right_nodes+1] = UIBox_button({
        label={confirm_label}, button="war_confirm_gamemode",
        colour=G.C.BLUE, minw=6.2, minh=0.8, scale=0.48,
    })

    return create_UIBox_generic_options({
        back_func = "war_private",
        contents = {
            { n=G.UIT.C, config={ align="tm", minw=3.4, padding=0.1 }, nodes=left },
            { n=G.UIT.B, config={ w=0.2, h=0.1 }},
            war_info_panel(right_nodes),
        },
    })
end

function G.FUNCS.war_open_gamemode_select(e)
    WAR.UI._sel_gamemode = nil
    WAR.UI._sel_ruleset  = nil
    WAR.LOBBY.config.gamemode = nil
    WAR.LOBBY.config.ruleset  = nil
    WAR.UI.open(G.UIDEF.war_gamemode_select())
end

function G.FUNCS.war_select_gamemode(e)
    local key = (e.config.id or ""):match("^gm_(.+)$")
    if key then WAR.UI.open(G.UIDEF.war_gamemode_select(key)) end
end

function G.FUNCS.war_confirm_gamemode(e)
    local gm = WAR.GAMEMODES[WAR.UI._sel_gamemode]
    if not gm then return end
    -- Always go to rulesets screen — lobby settings live there
    WAR.UI._sel_ruleset = nil
    WAR.UI.open(G.UIDEF.war_ruleset_select(gm.key))
end

-- Everything the gamemode + ruleset pair disables, shown as real Card objects
-- so the art (soul layers included) and the vanilla hover popup come for free.

local BAN_SCALE  = 0.62
local BAN_COLS   = 5
local BAN_CELL_W = 1.02

local function war_ban_name(key, set)
    local ok, name = pcall(localize, { type = "name_text", key = key, set = set })
    if ok and name and name ~= "" then return name end
    local c = G.P_CENTERS and G.P_CENTERS[key]
    if c and c.name then return c.name end
    return key
end

-- A single card sits in a throwaway CardArea, the same way vanilla renders the
-- card-usage histograms: bypass_discovery_* forces the real art (legendary soul
-- layers included) instead of the undiscovered card back.
local function war_ban_area(key)
    local center = G.P_CENTERS and G.P_CENTERS[key]
    if not center then return nil end
    local ok, card = pcall(Card, 0, 0, G.CARD_W*BAN_SCALE, G.CARD_H*BAN_SCALE, nil, center,
        { bypass_discovery_center = true, bypass_discovery_ui = true })
    if not (ok and card) then return nil end
    card.ambient_tilt    = 0.7
    card.states.drag.can = false          -- drag would pull it out of the grid

    local area = CardArea(0, 0, G.CARD_W*BAN_SCALE, G.CARD_H*BAN_SCALE,
        { card_limit = 2, type = "title", highlight_limit = 0 })
    area:emplace(card)
    return area
end

-- Tags are not centers, so they get their own path: Tag:generate_UI already
-- carries the hover popup and the right art.
local function war_ban_tag(key)
    if not (G.P_TAGS and G.P_TAGS[key]) then return nil end
    local ok, tag = pcall(Tag, key)
    if not (ok and tag) then return nil end
    local ok2, node = pcall(tag.generate_UI, tag, G.CARD_H*BAN_SCALE*0.8)
    if ok2 then return node end
end

local function war_ban_cell(key, set)
    local top
    if set == "Tag" then top = war_ban_tag(key) end
    if not top then
        local area = war_ban_area(key)
        top = area and { n=G.UIT.O, config={ object = area } }
                   or  { n=G.UIT.B, config={ w = G.CARD_W*BAN_SCALE, h = G.CARD_H*BAN_SCALE } }
    end

    return { n=G.UIT.C, config={ align="cm", padding=0.06, minw=BAN_CELL_W }, nodes={
        { n=G.UIT.R, config={ align="cm", minh=G.CARD_H*BAN_SCALE + 0.08 }, nodes={ top } },
        { n=G.UIT.R, config={ align="cm" }, nodes={
            { n=G.UIT.T, config={
                text=war_ban_name(key, set), scale=0.26,
                colour=G.C.UI.TEXT_LIGHT, maxw=BAN_CELL_W*0.95,
            }},
        }},
    }}
end

-- Rows for every non-empty category, gamemode bans first.
function WAR.UI.bans_panel(gm_key, rs_key)
    local gm = WAR.resolve_gamemode(gm_key)
    local rs = WAR.resolve_ruleset(rs_key)
    local out = {}

    for _, cat in ipairs(WAR.BAN_CATEGORIES) do
        local keys, seen = {}, {}
        for _, src in ipairs({ gm, rs }) do
            for _, k in ipairs(src and src[cat.field] or {}) do
                if not seen[k] then seen[k] = true; keys[#keys+1] = k end
            end
        end
        if #keys > 0 then
            out[#out+1] = { n=G.UIT.R, config={ align="cl", padding=0.04 }, nodes={
                { n=G.UIT.T, config={ text=localize(cat.label), scale=0.34,
                    colour=G.C.ORANGE, shadow=true }},
            }}
            local row = nil
            for i, key in ipairs(keys) do
                if (i - 1) % BAN_COLS == 0 then
                    row = {}
                    out[#out+1] = { n=G.UIT.R, config={ align="cm" }, nodes=row }
                end
                row[#row+1] = war_ban_cell(key, cat.set)
            end
        end
    end

    if #out == 0 then
        out[1] = { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_bans_none'), scale=0.32,
                colour=G.C.UI.TEXT_INACTIVE }},
        }}
    end
    return out
end

function G.UIDEF.war_ruleset_bans(gm_key, rs_key, back_func)
    return create_UIBox_generic_options({
        back_func = back_func or "exit_overlay_menu",
        contents = {
            { n=G.UIT.R, config={ align="cm", padding=0.08 }, nodes={
                { n=G.UIT.T, config={ text=localize('war_bans_title'), scale=0.45,
                    colour=G.C.UI.TEXT_LIGHT, shadow=true }},
            }},
            { n=G.UIT.R, config={
                align="cm", r=0.1, colour=G.C.BLACK, emboss=0.05, padding=0.15,
            }, nodes={
                { n=G.UIT.C, config={ align="tl" }, nodes=WAR.UI.bans_panel(gm_key, rs_key) },
            }},
        },
    })
end

function G.FUNCS.war_open_bans(e)
    local gm = WAR.UI._sel_gamemode or WAR.LOBBY.config.gamemode
    local rs = WAR.UI._sel_ruleset  or WAR.LOBBY.config.ruleset
    WAR.UI.open(G.UIDEF.war_ruleset_bans(gm, rs, "war_return_to_rulesets"))
end

function G.UIDEF.war_ruleset_select(gm_key, sel_key)
    local rulesets = war_rs_list(gm_key)
    if not sel_key and rulesets[1] then sel_key = rulesets[1].key end
    local sel = WAR.RULESETS[sel_key] or rulesets[1]
    WAR.UI._sel_ruleset = sel and sel.key

    -- Left: pill + ruleset buttons
    local left = { war_pill(localize('war_rulesets'), mix_colours(G.C.RED, G.C.BLACK, 0.6)) }
    for _, rs in ipairs(rulesets) do
        left[#left+1] = { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={
            UIBox_button({
                id="rs_"..rs.key, col=true,
                chosen=sel_key == rs.key and "vert" or false,
                label={localize("war_rs_".. rs.key.. "_name") or ""}, button="war_select_ruleset",
                colour=G.C.RED, minw=3.0, scale=0.42, minh=0.65,
            }),
        }}
    end

    -- Right: description lines + confirm
    local right_nodes = {}
    if sel then
        local predesc = localize("war_rs_".. sel.key.. "_desc") -- funny how this changes by two characters (gm -> rs)
        local desc = type(predesc) == "table" and predesc or {predesc or ""}
        for _, line in ipairs(desc) do
            right_nodes[#right_nodes+1] = { n=G.UIT.R, config={ align="cm", padding=0.04 }, nodes={
                { n=G.UIT.T, config={ text=line, scale=0.38, colour=G.C.UI.TEXT_LIGHT }},
            }}
        end
    end
    right_nodes[#right_nodes+1] = { n=G.UIT.R, config={ align="cm", minh=0.4 }, nodes={} }
    right_nodes[#right_nodes+1] = UIBox_button({
        label={localize('war_view_bans')}, button="war_open_bans",
        colour=G.C.ORANGE, minw=6.2, minh=0.62, scale=0.4,
    })
    right_nodes[#right_nodes+1] = UIBox_button({
        label={localize('war_create_lobby')}, button="war_confirm_ruleset",
        colour=G.C.BLUE, minw=6.2, minh=0.8, scale=0.48,
    })

    return create_UIBox_generic_options({
        back_func = "war_back_to_gamemodes",
        contents = {
            { n=G.UIT.C, config={ align="tm", minw=3.4, padding=0.1 }, nodes=left },
            { n=G.UIT.B, config={ w=0.2, h=0.1 }},
            war_info_panel(right_nodes),
        },
    })
end

function G.FUNCS.war_back_to_gamemodes(e)
    WAR.UI.open(G.UIDEF.war_gamemode_select(WAR.UI._sel_gamemode))
end

function G.FUNCS.war_settings_from_ruleset(e)
    -- Open lobby settings with a back_func that returns here
    WAR.UI.open_instant(G.UIDEF.war_options_popup("war_return_to_rulesets"))
end

function G.FUNCS.war_return_to_rulesets(e)
    WAR.UI.open(G.UIDEF.war_ruleset_select(WAR.UI._sel_gamemode, WAR.UI._sel_ruleset))
end

function G.FUNCS.war_select_ruleset(e)
    local key = (e.config.id or ""):match("^rs_(.+)$")
    if key then WAR.UI.open(G.UIDEF.war_ruleset_select(WAR.UI._sel_gamemode, key)) end
end

function G.FUNCS.war_confirm_ruleset(e)
    local gm  = WAR.GAMEMODES[WAR.UI._sel_gamemode]
    local rs  = WAR.RULESETS[WAR.UI._sel_ruleset]
    if not gm then return end
    WAR.LOBBY.config.gamemode      = gm.key
    WAR.LOBBY.config.ruleset       = rs and rs.key
    -- The gamemode only supplies the starting point; a host who picked an ante
    -- in the lobby keeps it when they come back through this screen.
    if not WAR.LOBBY.config.pvp_ante_set then
        WAR.LOBBY.config.pvp_start_ante = gm.pvp_start_ante or 3
    end
    war_do_create_with_config()
end

print("[WAR] ui/screens loaded")
