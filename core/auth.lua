-- core/auth.lua
-- Register, login, session token. Password never leaves the client.

WAR.AUTH = {
    user     = nil,   -- logged-in username
    user_id  = nil,
    token    = nil,
    state    = "idle", -- idle | connecting | registering | logging_in | logged_in | guest
    on_done  = nil,   -- callback(ok, err)
}

local SESSION_FILE = "War_session.dat"

local function sha256_hex(s)
    -- LuaJIT/LOVE doesn't ship a sha256; we implement a compact one.
    -- Using the bit library which is available in LuaJIT.
    local bit = require("bit")
    local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
    local rshift, lshift, rrotate = bit.rshift, bit.lshift, bit.ror

    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    local function preprocess(msg)
        local len = #msg
        local bits = len * 8
        msg = msg .. "\128"
        while #msg % 64 ~= 56 do msg = msg .. "\0" end
        -- append length as 64-bit big-endian
        for i = 7, 0, -1 do
            msg = msg .. string.char(math.floor(bits / 2^(i*8)) % 256)
        end
        return msg
    end

    local function words(chunk)
        local w = {}
        for i = 0, 15 do
            local b1, b2, b3, b4 = chunk:byte(i*4+1, i*4+4)
            w[i+1] = bor(lshift(b1,24), lshift(b2,16), lshift(b3,8), b4)
        end
        for i = 17, 64 do
            local s0 = bxor(rrotate(w[i-15],7), rrotate(w[i-15],18), rshift(w[i-15],3))
            local s1 = bxor(rrotate(w[i-2],17), rrotate(w[i-2],19),  rshift(w[i-2],10))
            w[i] = band(w[i-16] + s0 + w[i-7] + s1, 0xFFFFFFFF)
        end
        return w
    end

    local h = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    }

    local msg = preprocess(s)
    for i = 1, #msg / 64 do
        local w = words(msg:sub((i-1)*64+1, i*64))
        local a,b,c,d,e,f,g,hh = h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]
        for j = 1, 64 do
            local S1   = bxor(rrotate(e,6), rrotate(e,11), rrotate(e,25))
            local ch   = bxor(band(e,f), band(bnot(e),g))
            local temp1 = band(hh + S1 + ch + K[j] + w[j], 0xFFFFFFFF)
            local S0   = bxor(rrotate(a,2), rrotate(a,13), rrotate(a,22))
            local maj  = bxor(band(a,b), band(a,c), band(b,c))
            local temp2 = band(S0 + maj, 0xFFFFFFFF)
            hh=g; g=f; f=e
            e = band(d + temp1, 0xFFFFFFFF)
            d=c; c=b; b=a
            a = band(temp1 + temp2, 0xFFFFFFFF)
        end
        h[1]=band(h[1]+a,0xFFFFFFFF); h[2]=band(h[2]+b,0xFFFFFFFF)
        h[3]=band(h[3]+c,0xFFFFFFFF); h[4]=band(h[4]+d,0xFFFFFFFF)
        h[5]=band(h[5]+e,0xFFFFFFFF); h[6]=band(h[6]+f,0xFFFFFFFF)
        h[7]=band(h[7]+g,0xFFFFFFFF); h[8]=band(h[8]+hh,0xFFFFFFFF)
    end

    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x",
        h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8])
end

WAR.AUTH.sha256 = sha256_hex

local function make_salt()
    local t = {}
    for i = 1, 16 do t[i] = string.format("%02x", math.random(0,255)) end
    return table.concat(t)
end

local function make_verifier(salt, password)
    return sha256_hex(salt .. sha256_hex(password))
end

-- Session file

local function session_path()
    -- love.filesystem writes to the game's save directory
    return SESSION_FILE
end

local function save_session(username, token)
    local data = username .. "\n" .. token
    love.filesystem.write(session_path(), data)
end

local function load_session()
    local data, _ = love.filesystem.read(session_path())
    if not data then return nil, nil end
    local username, token = data:match("^([^\n]+)\n(.+)$")
    return username, token
end

function WAR.AUTH.clear_session()
    love.filesystem.remove(session_path())
    WAR.AUTH.user   = nil
    WAR.AUTH.token  = nil
    WAR.AUTH.state  = "idle"
end

function WAR.AUTH.handle(msg)
    local a = msg.action

    if a == "registered" then
        print("[WAR AUTH] registered " .. tostring(WAR.AUTH._pending_username))
        -- after register, immediately log in to get a token
        WAR.NET.send({
            action   = "login",
            username = WAR.AUTH._pending_username,
            verifier = WAR.AUTH._pending_verifier,
        })

    elseif a == "salt" then
        -- server returned salt; compute verifier and send login
        local verifier = make_verifier(msg.salt, WAR.AUTH._pending_password)
        WAR.AUTH._pending_verifier  = verifier
        WAR.AUTH._pending_password  = nil  -- clear asap
        WAR.NET.send({
            action   = "login",
            username = WAR.AUTH._pending_username,
            verifier = verifier,
        })

    elseif a == "logged_in" then
        WAR.AUTH.user   = msg.username
        WAR.AUTH.token  = msg.token
        WAR.AUTH.state  = "logged_in"
        if msg.token then
            print("[WAR AUTH] login " .. tostring(msg.username))
            save_session(msg.username, msg.token)
        else
            print("[WAR AUTH] token_login " .. tostring(msg.username))
        end
        WAR.AUTH._pending_username = nil
        WAR.AUTH._pending_verifier = nil
        -- Relay delivers the full entitlements list on every successful login.
        if msg.entitlements and type(msg.entitlements) == "table" then
            WAR.AVATAR.entitlements = {}
            for _, k in ipairs(msg.entitlements) do
                WAR.AVATAR.grant_local(k)
            end
        end
        if WAR.AUTH.on_done then WAR.AUTH.on_done(true, nil) end

    elseif a == "logged_out" then
        WAR.AUTH.clear_session()
        if WAR.AUTH.on_done then WAR.AUTH.on_done(true, nil) end

    elseif a == "auth_error" then
        print("[WAR AUTH] auth_error " .. tostring(msg.reason))
        WAR.AUTH.state = "idle"
        WAR.AUTH._pending_password = nil
        WAR.AUTH._pending_username = nil
        WAR.AUTH._pending_verifier = nil
        if WAR.AUTH.on_done then WAR.AUTH.on_done(false, WAR.error_text(msg.reason)) end
    end
end

function WAR.AUTH.auto_login(cb)
    WAR.AUTH.on_done = cb
    local username, token = load_session()
    if not username or not token then
        cb(false, "no_session")
        return
    end
    local ok, err = WAR.NET.connect()
    if not ok then cb(false, err); return end
    WAR.AUTH._pending_username = username
    WAR.NET.send({ action = "token_login", token = token })
end

function WAR.AUTH.register(username, password, cb)
    WAR.AUTH.on_done = cb
    WAR.AUTH.state   = "registering"
    local ok, err = WAR.NET.connect()
    if not ok then cb(false, err); return end
    local salt     = make_salt()
    local verifier = make_verifier(salt, password)
    WAR.AUTH._pending_username = username
    WAR.AUTH._pending_verifier = verifier
    password = nil  -- clear immediately
    WAR.NET.send({ action="register", username=username, salt=salt, verifier=verifier })
end

function WAR.AUTH.login(username, password, cb)
    WAR.AUTH.on_done           = cb
    WAR.AUTH.state             = "logging_in"
    WAR.AUTH._pending_username = username
    WAR.AUTH._pending_password = password
    local ok, err = WAR.NET.connect()
    if not ok then cb(false, err); return end
    -- first fetch salt, then server sends back salt -> handle() computes verifier
    WAR.NET.send({ action = "get_salt", username = username })
end

function WAR.AUTH.guest()
    WAR.AUTH.state = "guest"
    WAR.AUTH.user  = "Guest"
    WAR.AUTH.token = nil
end

function WAR.AUTH.logout(cb)
    WAR.AUTH.on_done = cb
    if WAR.AUTH.token then
        WAR.NET.send({ action = "logout", token = WAR.AUTH.token })
    end
    WAR.AUTH.clear_session()
    if cb then cb(true) end
end

print("[WAR] auth loaded")
