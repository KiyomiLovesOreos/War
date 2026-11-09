-- core/net.lua
-- Relay networking. Both players connect to the relay server.
-- Relay assigns lobby codes and forwards messages between clients.

local json = require("json")

WAR.NET.RELAY_HOST = "167.71.87.77"
WAR.NET.RELAY_PORT = 7777

local sock      = nil
local recv_buf  = ""
WAR.NET._expected_seq = nil   -- next expected _seq from server; nil = first message

function WAR.NET.connect()
    if sock then return true end
    local socket = require("socket")
    local s = socket.tcp()
    s:settimeout(8)
    -- Beta env uses port 7778; resolved here (not at load time) so WAR.CONFIG exists.
    local port = (WAR.CONFIG and WAR.CONFIG.server_env == "beta")
                 and 7778 or WAR.NET.RELAY_PORT
    local ok, err = s:connect(WAR.NET.RELAY_HOST, port)
    if not ok then s:close(); return false, err end
    s:settimeout(0)
    -- Ask the OS to send keepalive probes on idle connections.
    -- This catches dead sockets that TCP itself wouldn't detect for minutes.
    pcall(function() s:setoption("keepalive", true) end)
    sock = s
    WAR.NET.sock = sock
    recv_buf = ""
    WAR.NET._expected_seq = nil
    print("[WAR NET] connected to relay")
    return true
end

function WAR.NET.disconnect()
    if sock then
        pcall(function() sock:close() end)
        sock = nil
        WAR.NET.sock = nil
        recv_buf = ""
        WAR.NET._expected_seq = nil
    end
end

function WAR.NET.connected()
    return sock ~= nil
end

function WAR.NET.send(msg)
    if not sock then return end
    local ok, err = sock:send(json.encode(msg) .. "\n")
    if not ok then print("[WAR NET] send err: " .. tostring(err)) end
end

-- Achievement plumbing. Call sites name the achievement key and nothing else,
-- so the wire shape lives in one place per direction.
function WAR.NET.claim_achievement(key)
    if not key then return end
    WAR.NET.send({ action = "claimAchievement", key = key })
end

function WAR.NET.increment_achievement(key, count)
    if not key or not count or count <= 0 then return end
    WAR.NET.send({ action = "incrementAchievement", key = key, count = count })
end

function WAR.NET.poll()
    if not sock then return {} end
    -- receive(4096) with timeout=0 returns nil,"timeout",partial when < 4096 bytes
    -- available. Accumulate the partial too, not just the "full" chunk.
    local chunk, err, partial = sock:receive(4096)
    if chunk then
        recv_buf = recv_buf .. chunk
    elseif partial and #partial > 0 then
        recv_buf = recv_buf .. partial
    elseif err == "closed" then
        print("[WAR NET] relay disconnected")
        WAR.NET.disconnect()
        WAR.NET.on_relay_disconnected()
        return {}
    end

    local msgs = {}
    while true do
        local line, rest = recv_buf:match("^([^\n]+)\n(.*)")
        if not line then break end
        recv_buf = rest
        local ok, decoded = pcall(json.decode, line)
        if ok and decoded then
            -- Track sequence numbers from server to detect relay bugs.
            local seq = decoded._seq
            if seq ~= nil then
                if WAR.NET._expected_seq ~= nil and seq ~= WAR.NET._expected_seq then
                    print("[WAR NET] seq gap: expected " .. WAR.NET._expected_seq
                          .. " got " .. seq)
                end
                WAR.NET._expected_seq = seq + 1
            end

            -- Respond to heartbeat pings here, before they reach game logic.
            if decoded.action == "ping" then
                WAR.NET.send({action = "pong"})
            else
                msgs[#msgs+1] = decoded
            end
        end
    end
    return msgs
end

function WAR.NET.on_relay_disconnected() end

print("[WAR] net loaded")
