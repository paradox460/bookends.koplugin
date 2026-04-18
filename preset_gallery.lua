--- Preset Gallery: fetch remote index + preset files, cache to disk.
-- Mirrors updater.lua's HTTP pattern (LuaSocket + curl fallback).

local DataStorage = require("datastorage")
local logger = require("logger")

local Gallery = {}

local INDEX_URL = "https://raw.githubusercontent.com/AndyHazz/bookends-presets/main/index.json"
local BASE_URL  = "https://raw.githubusercontent.com/AndyHazz/bookends-presets/main/"
local CACHE_TTL = 24 * 3600  -- 24h

-- Session in-memory cache of downloaded preset data
local _preset_cache = {}

local function cacheDir()
    local dir = DataStorage:getSettingsDir() .. "/bookends_gallery_cache"
    local lfs = require("libs/libkoreader-lfs")
    if lfs.attributes(dir, "mode") ~= "directory" then
        lfs.mkdir(dir)
    end
    return dir
end

local function httpGet(url, user_agent)
    local ok_require, http, ltn12, socket, socketutil = pcall(function()
        return require("socket/http"), require("ltn12"), require("socket"), require("socketutil")
    end)
    if ok_require then
        local body = {}
        local ok_req, code = pcall(function()
            socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
            local c = socket.skip(1, http.request({
                url = url,
                method = "GET",
                headers = { ["User-Agent"] = user_agent },
                sink = ltn12.sink.table(body),
                redirect = true,
            }))
            socketutil:reset_timeout()
            return c
        end)
        if ok_req and code == 200 then return table.concat(body) end
        pcall(function() socketutil:reset_timeout() end)
    end
    -- curl fallback
    local handle = io.popen(string.format("curl -s -L -H 'User-Agent: %s' %q", user_agent, url))
    if handle then
        local body = handle:read("*a")
        handle:close()
        if body and body ~= "" then return body end
    end
    return nil
end

function Gallery.isOnline()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok or not NetworkMgr then return false end
    return NetworkMgr:isWifiOn() and NetworkMgr:isConnected()
end

function Gallery.getCacheTimestamp()
    local ts_path = cacheDir() .. "/index.timestamp"
    local f = io.open(ts_path, "r")
    if not f then return nil end
    local ts = tonumber(f:read("*l"))
    f:close()
    return ts
end

function Gallery.getCachedIndex()
    local path = cacheDir() .. "/index.json"
    local f = io.open(path, "r")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    local ok, json = pcall(require, "json")
    if not ok then return nil end
    local ok2, data = pcall(json.decode, body)
    if ok2 then return data end
    return nil
end

function Gallery.fetchIndex(user_agent, callback)
    if not Gallery.isOnline() then
        callback(nil, "offline")
        return
    end
    local body = httpGet(INDEX_URL, user_agent or "KOReader-Bookends")
    if not body then
        callback(nil, "fetch failed")
        return
    end
    local ok_req, json = pcall(require, "json")
    if not ok_req then callback(nil, "json module missing"); return end
    local ok, data = pcall(json.decode, body)
    if not ok or type(data) ~= "table" or type(data.presets) ~= "table" then
        callback(nil, "invalid index")
        return
    end
    -- Cache
    local path = cacheDir() .. "/index.json"
    local f = io.open(path, "w")
    if f then f:write(body); f:close() end
    local ts_file = io.open(cacheDir() .. "/index.timestamp", "w")
    if ts_file then ts_file:write(tostring(os.time())); ts_file:close() end
    callback(data, nil)
end

function Gallery.downloadPreset(slug, preset_url, user_agent, callback)
    if _preset_cache[slug] then
        callback(_preset_cache[slug], nil)
        return
    end
    if not Gallery.isOnline() then
        callback(nil, "offline")
        return
    end
    local body = httpGet(BASE_URL .. preset_url, user_agent or "KOReader-Bookends")
    if not body then callback(nil, "fetch failed"); return end
    -- Sandboxed load to evaluate the Lua preset
    local fn, err = loadstring(body)
    if not fn then callback(nil, "parse error: " .. tostring(err)); return end
    setfenv(fn, {})
    local ok, preset = pcall(fn)
    if not ok or type(preset) ~= "table" then
        callback(nil, "runtime error")
        return
    end
    _preset_cache[slug] = preset
    callback(preset, nil)
end

function Gallery.clearCache()
    _preset_cache = {}
end

return Gallery
