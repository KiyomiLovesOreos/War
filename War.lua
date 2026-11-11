-- War.lua
-- Copyright (C) 2026 Amolyte
-- Licensed under the GNU General Public License v3.0 — see LICENSE.

WAR = SMODS.current_mod
WAR.ROOT = WAR.path

-- Set to 0 to silence verbose in-game logging (scoring, auth, network events).
-- Error and warning prints are always shown regardless.
WAR.console_log = 0

-- Set to 1 to connect to the beta relay (port 7778) instead of the live server.
WAR.beta_test = 0

function WAR.log(...)
    if WAR.console_log == 1 then print(...) end
end

function WAR.load(path)
    return SMODS.load_file(path)()
end

function WAR.load_dir(dir)
    local init = dir .. "/_init.lua"
    local ok = SMODS.load_file(init)
    if ok then ok() end
    for _, f in ipairs(NFS.getDirectoryItems(WAR.ROOT .. dir)) do
        if f:match("%.lua$") and f ~= "_init.lua" then
            SMODS.load_file(dir .. "/" .. f)()
        end
    end
end

WAR.load("core/globals.lua")
WAR.load("core/net.lua")
WAR.load("core/lobby.lua")
WAR.load("core/auth.lua")
WAR.load("core/avatar.lua")
WAR.load("core/sync.lua")
WAR.load("core/game_hooks.lua")

-- Load saved pfp choice once all modules are initialised.
if WAR.AVATAR then WAR.AVATAR.load_choice() end

-- Objects (blinds) must load before gamemodes so bl_war_jimbo exists
-- when attrition gamemode references it
WAR.load_dir("objects/blinds")
WAR.load_dir("gamemodes")

-- UI: explicit order (lobby last; it references symbols from earlier files)
WAR.load("ui/_init.lua")
WAR.load("ui/utils.lua")
WAR.load("ui/account.lua")
WAR.load("ui/screens.lua")
WAR.load("ui/icon_select.lua")
WAR.load("ui/hud.lua")
WAR.load("ui/popups.lua")
WAR.load("ui/lobby.lua")

WAR.load_dir("compat")
