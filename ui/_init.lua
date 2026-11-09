-- ui/_init.lua

WAR.UI = WAR.UI or {}

-- Stubs replaced by popups.lua / hud.lua
function WAR.UI.show_waiting(msg)   print("[WAR UI stub] waiting: " .. tostring(msg)) end
function WAR.UI.hide_waiting()      print("[WAR UI stub] hide_waiting") end
function WAR.UI.show_end_pvp(won)   print("[WAR UI stub] end_pvp won=" .. tostring(won)) end
function WAR.UI.show_win_game()     print("[WAR UI stub] win") end
function WAR.UI.show_lose_game()    print("[WAR UI stub] lose") end
function WAR.UI.show_message(msg)   print("[WAR UI stub] message: " .. tostring(msg)) end
function WAR.UI.show_chat(text)     print("[WAR UI stub] chat: " .. tostring(text)) end
function WAR.UI.refresh_hud()       end
function WAR.UI.create_hud()        end

print("[WAR] ui/_init loaded")
