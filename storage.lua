local sql = require "lsqlite3"
local utils = require "utils"

local XDG_DATA_HOME = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
local psdir = XDG_DATA_HOME .. "/NixPSClient"
-- test if the path exist
local f = io.open(psdir, "r")
if f then
    -- check if f is a directory
    local res, err, errno = f:read(0)
    f:close()
    if errno ~= 21 then
        return
    end
else
    local ret, reason, code = os.execute("mkdir -p '" .. psdir .. "'")
    if ret == nil or (type(ret) == "number" and (ret ~= 0)) then
        return
    end
end

local storage = {}

local db = sql.open(psdir .. "/storage.db")

db:exec[[
CREATE TABLE IF NOT EXISTS misc (
    id TEXT PRIMARY KEY,
    data TEXT
);
]]

db:exec[[
CREATE TABLE IF NOT EXISTS cookies (
    username TEXT PRIMARY KEY,
    store TEXT,
    timestamp INTEGER
);
]]

db:exec[[
CREATE TABLE IF NOT EXISTS rooms (
    username TEXT PRIMARY KEY,
    rooms TEXT
);
]]

storage.getCookie = function(username)
    local stmt
    if username then
        stmt = db:prepare("SELECT store FROM cookies WHERE username = ?")
        stmt:bind_values(username)
    else
        stmt = db:prepare("SELECT store FROM cookies ORDER BY timestamp DESC LIMIT 1")
    end        
    local res = stmt:step()
    local store
    if res == sql.ROW then
        store = stmt:get_value(0)
    end
    return stmt:finalize() and store
end

storage.saveCookie = function(username, store)
    -- TODO: extract timestamp and username from store
    local stmt = db:prepare("INSERT OR REPLACE INTO cookies (username, store, timestamp) VALUES (?, ?, ?)")
    stmt:bind_values(username, store, os.time())
    stmt:step()
    return stmt:finalize()
end

storage.getAutojoin = function(username)
    local stmt = db:prepare("SELECT rooms FROM rooms WHERE username = ?")
    stmt:bind_values(username)
    local res = stmt:step()
    local rooms
    if res == sql.ROW then
        rooms = stmt:get_value(0)
    end
    return stmt:finalize() and utils.split(rooms)
end

storage.setAutojoin = function(username, rooms)
    local stmt = db:prepare("INSERT OR REPLACE INTO rooms (username, rooms) VALUES (?, ?)")
    stmt:bind_values(username, table.concat(rooms, "|"))
    stmt:step()
    return stmt:finalize()
end


return storage