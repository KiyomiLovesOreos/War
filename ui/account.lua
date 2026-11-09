-- ui/account.lua
-- Account management screens + SMODS config tab.

-- Return to the War config page (used as back_func on screens opened from it).
function G.FUNCS.war_back_to_config(e)
    local mod = SMODS.Mods and SMODS.Mods["War"]
    if create_UIBox_mods and mod then
        G.ACTIVE_MOD_UI = mod
        WAR.UI.open(create_UIBox_mods({}))
    else
        G.FUNCS.exit_overlay_menu()
    end
end

SMODS.Mods["War"].config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { r=0.1, minw=6, align="cm", padding=0.3, colour=G.C.BLACK },
        nodes = {
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                { n=G.UIT.T, config={ text=localize('war_account_label'), scale=0.4,
                    colour=G.C.UI.TEXT_LIGHT, shadow=true }},
                { n=G.UIT.T, config={
                    ref_table=WAR.AUTH, ref_value="user",
                    scale=0.4, colour=G.C.GREEN, shadow=true }},
            }},
            { n=G.UIT.R, config={ align="cm", minh=0.15 }, nodes={} },
            UIBox_button({ label={localize('war_manage_account')}, button="war_open_account",
                colour=G.C.BLUE, minw=5 }),
            { n=G.UIT.R, config={ align="cm", minh=0.15 }, nodes={} },
            UIBox_button({ label={localize('war_icon')}, button="war_open_icon_select",
                colour=G.C.GREEN, minw=5 }),
        },
    }
end

function G.UIDEF.war_account_screen()
    local name      = WAR.AUTH.user or localize('war_none')
    local logged_in = WAR.AUTH.state == "logged_in"
    local nodes = {
        { n=G.UIT.R, config={ align="cm", padding=0.15 }, nodes={
            { n=G.UIT.T, config={ text=localize('war_current_account'), scale=0.4,
                colour=G.C.UI.TEXT_LIGHT, shadow=true }},
            { n=G.UIT.T, config={ text=name, scale=0.4,
                colour=G.C.GREEN, shadow=true }},
        }},
    }
    if not logged_in then
        nodes[#nodes+1] = UIBox_button({ label={localize('war_log_in')},   button="war_open_login",
            colour=G.C.BLUE,  minw=5 })
        nodes[#nodes+1] = UIBox_button({ label={localize('war_register')}, button="war_open_register",
            colour=G.C.GREEN, minw=5 })
    else
        nodes[#nodes+1] = UIBox_button({ label={localize('war_log_out')}, button="war_confirm_logout",
            colour=G.C.RED, minw=5 })
    end
    nodes[#nodes+1] = UIBox_button({ label={localize('war_close')}, button="war_account_close",
        colour=G.C.ORANGE, minw=5 })
    return create_UIBox_generic_options({ contents=nodes })
end

function G.FUNCS.war_open_account(e) WAR.UI.open(G.UIDEF.war_account_screen()) end
function G.FUNCS.war_account_close(e) G.FUNCS.exit_overlay_menu() end

WAR.UI._login = { username="", password="" }

function G.UIDEF.war_login_screen()
    WAR.UI._login.username = ""
    WAR.UI._login.password = ""
    return create_UIBox_generic_options({
        back_func = "war_open_account",
        contents = {
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                create_text_input({ id="war_login_user", w=5, h=0.9,
                    prompt_text=localize('war_username_prompt'), max_length=24,
                    ref_table=WAR.UI._login, ref_value="username" }),
            }},
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                create_text_input({ id="war_login_pass", w=5, h=0.9,
                    prompt_text=localize('war_password_prompt'), max_length=64,
                    ref_table=WAR.UI._login, ref_value="password" }),
            }},
            UIBox_button({ label={localize('war_log_in')}, button="war_do_login",
                colour=G.C.BLUE, minw=5 }),
        },
    })
end

function G.FUNCS.war_open_login(e)
    WAR.UI.open(G.UIDEF.war_login_screen())
end

function G.FUNCS.war_do_login(e)
    local u = WAR.UI._login.username
    local p = WAR.UI._login.password
    if u == "" or p == "" then return end
    G.FUNCS.exit_overlay_menu()
    WAR.AUTH.login(u, p, function(ok, err)
        WAR.UI.open(G.UIDEF.war_account_screen())
    end)
end

WAR.UI._register = { username="", password="", confirm="" }

function G.UIDEF.war_register_screen()
    WAR.UI._register.username = ""
    WAR.UI._register.password = ""
    WAR.UI._register.confirm  = ""
    return create_UIBox_generic_options({
        back_func = "war_open_account",
        contents = {
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                create_text_input({ id="war_reg_user", w=5, h=0.9,
                    prompt_text=localize('war_username_prompt'), max_length=24,
                    ref_table=WAR.UI._register, ref_value="username" }),
            }},
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                create_text_input({ id="war_reg_pass", w=5, h=0.9,
                    prompt_text=localize('war_password_prompt'), max_length=64,
                    ref_table=WAR.UI._register, ref_value="password" }),
            }},
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                create_text_input({ id="war_reg_conf", w=5, h=0.9,
                    prompt_text=localize('war_confirm_pass_prompt'), max_length=64,
                    ref_table=WAR.UI._register, ref_value="confirm" }),
            }},
            UIBox_button({ label={localize('war_create_account')}, button="war_do_register",
                colour=G.C.BLUE, minw=5 }),
        },
    })
end

function G.FUNCS.war_open_register(e)
    WAR.UI.open(G.UIDEF.war_register_screen())
end

function G.FUNCS.war_do_register(e)
    local u = WAR.UI._register.username
    local p = WAR.UI._register.password
    local c = WAR.UI._register.confirm
    if u == "" or p == "" or p ~= c then return end
    G.FUNCS.exit_overlay_menu()
    WAR.AUTH.register(u, p, function(ok, err)
        WAR.UI.open(G.UIDEF.war_account_screen())
    end)
end

function G.UIDEF.war_confirm_logout()
    return create_UIBox_generic_options({
        contents = {
            { n=G.UIT.R, config={ align="cm", padding=0.1 }, nodes={
                { n=G.UIT.T, config={ text=localize('war_logout_confirm'),
                    scale=0.42, colour=G.C.UI.TEXT_LIGHT, shadow=true }},
            }},
            UIBox_button({ label={localize('war_yes_log_out')}, button="war_do_logout",
                colour=G.C.RED, minw=5 }),
            UIBox_button({ label={localize('war_no_stay')},     button="war_open_account",
                colour=G.C.GREEN, minw=5 }),
        },
    })
end

function G.FUNCS.war_confirm_logout(e) WAR.UI.open(G.UIDEF.war_confirm_logout()) end
function G.FUNCS.war_do_logout(e)
    WAR.AUTH.logout(function()
        WAR.UI.open(G.UIDEF.war_account_screen())
    end)
end

print("[WAR] ui/account loaded")
