local curses = require "curses"
local utils = require "utils"
local Room = require "room"
local Input = require "input"
local utf8 = require "utf8"
local Callback = require "ps.callbacks"
local psutils = require "ps.utils"
local storage = require "storage"

local client = {}
local methods = {}
local mt = {__index = methods}

--[[
_(room name)_TOP_____________
|DISPLAY                    |
|                           |
|                           |
|___________________________|
#### BAR (status, rooms) ####
__INPUT______________________
]]

client.new = function(screen, client)
    local t = setmetatable({}, mt)
    t.screen = screen
    local height, width = screen:getmaxyx()
    t.sections = {
        top = screen:sub(1, width, 0, 0),
        display = screen:sub(height - 3, width, 1, 0),
        bar = screen:sub(1, width, height - 2, 0),
        input = screen:sub(1, width, height - 1, 0),
    }

    t.sections.top:wbkgd(curses.color_pair(1))
    t.sections.display:wbkgd(curses.color_pair(2))
    t.sections.bar:wbkgd(curses.color_pair(3))
    t.sections.input:wbkgd(curses.color_pair(4))

    t.input = Input.new(t.sections.input)

    t.callbacks = {}
    t.callbacks.send = Callback:new()

    t.windows = {}

    t.rooms = {}
    t:newRoom("")
    t:updateRoom("", {type = "status", name = "~"})

    t.PMs = {}
    t.PMs[client.users:getUser("")] = t.rooms[""]

    t.client = client

    t:switchWindow(1)

    return t
end

methods.newRoom = function(self, id)
    self.rooms[id] = Room.new(id)
    self.windows[#self.windows + 1] = self.rooms[id]

    self:redrawStatus()
    return self.rooms[id]
end

methods.newPM = function(self, user)
    local room = Room.new(user.name)
    room:setType("pm")
    room:setName("(PM) " .. user.name)
    self.PMs[user] = room
    self.windows[#self.windows + 1] = room
    self:redrawStatus()
    curses.beep()
    return room
end

methods.deleteRoom = function(self, id)
    local room = self.rooms[id]
    if room then
        for i, v in ipairs(self.windows) do
            if v == room then
                table.remove(self.windows, i)
                if self.window == room then
                    self:switchWindow(math.min(i, #self.windows))
                end
                break
            end
        end
        self.rooms[id] = nil

        self:redrawStatus()
    end
end

methods.updateRoom = function(self, id, params)
    if params.type then
        self.rooms[id]:setType(params.type)
    end
    if params.name then
        self.rooms[id]:setName(params.name)
    end
    self:redrawStatus()
end

methods.switchRoom = function(self, roomID)
    local room = self.rooms[roomID]
    for i, v in ipairs(self.windows) do
        if v == room then
            self:switchWindow(i)
            break
        end
    end
end

methods.switchWindow = function(self, room)
    local room = self.windows[room]
    if not room or self.window == room then return end
    self.sections.display:erase()
    self.sections.display:noutrefresh()

    -- TODO: store current input in the old room
    -- TODO: get input and cursor from the new room if any
    self.input:erase()

    self.sections.top:erase()
    self.sections.top:mvaddstr(0, 1, room.name)
    self.sections.top:noutrefresh()

    self.window = room
    self.window:render(self.sections.display)

    self.input:redraw()
end

methods.redrawStatus = function(self)
    self.sections.bar:erase()
    local cursor = 1
    for i, v in ipairs(self.windows) do
        local str = ("[%d: %s%s]"):format(i, v.shortType, v.id)
        self.sections.bar:mvaddstr(0, cursor, str)
        self.sections.bar:addstr(" ")
        cursor = cursor + utf8.len(str) + 1
    end
    self.sections.bar:noutrefresh()
    self.sections.input:noutrefresh()
    curses.doupdate()
end

methods.resize = function(self)
    local height, width = self.screen:getmaxyx()
    self.sections.top:resize(1, width)
    self.sections.display:resize(height - 3, width)
    self.sections.bar:move_window(height - 2, 0)
    self.sections.bar:resize(1, width)
    self.sections.input:move_window(height - 1, 0)
    self.sections.input:resize(1, width)

    self:redraw()
end

methods.redraw = function(self)
    self.sections.top:erase()
    self.sections.top:mvaddstr(0, 1, self.window.name)
    self.sections.top:noutrefresh()

    self.window:render(self.sections.display)

    self:redrawStatus()
    
    self.input:redraw()
end

methods.log = function(self, roomID, txt)
    local room = self.rooms[roomID]
    if not room then return end
    room:log(txt)
    if room == self.window then
        room:render(self.sections.display)
        self.sections.input:noutrefresh()
        curses.doupdate()
    end
end

methods.message = function(self, message)
    local roomID = message.room and message.room.id or message.self and message.recipient or message.sender
    local room = self.rooms[roomID] or self.PMs[roomID]
    if not message.room and not room then
        room = self:newPM(roomID)
    end
    room:message(message)
    if room == self.window then
        room:render(self.sections.display)
        self.sections.input:noutrefresh()
        curses.doupdate()
    end
end

methods.send = function(self, text)
    local str
    if self.window.type == "pm" then
        str = "|/pm " .. self.window.id .. ", " .. text
    else
        str = self.window.id .. "|" .. text
    end
    self.callbacks.send:fire(str)
end

methods.getInput = function(self)
    local c = self.screen:getch()
    if not c then return end

    -- TODO: handle input overflow
    -- TODO: handle characters that are made up of several code points

    if self.input.escape then
        if c >= 48 and c <= 57 then -- number key
            local n = (c - 49) % 10 + 1
            self:switchWindow(n)
        end
        self.input.escape = false
    elseif c == curses.KEY_BACKSPACE or c == 127 or c == ('\b'):byte() then -- backspace
        self.input:backspace()
    elseif c == 23 then -- ctrl-w
        self.input:backspace(true)
    elseif c >= 32 and c < 256 then -- either a printable character or utf-8
        self.input:type(c)
    elseif c == curses.KEY_DC then
        self.input:delete()
    elseif c == curses.KEY_LEFT or c == curses.KEY_RIGHT then
        local d = c == curses.KEY_LEFT and -1 or 1
        self.input:moveCursor(d)
    elseif c == curses.KEY_HOME then
        self.input:moveCursor(-math.huge)
    elseif c == curses.KEY_END then
        self.input:moveCursor(math.huge)
    elseif c == 13 or c == 15 or c == curses.KEY_ENTER then
        local input = self.input:get()
        self.input:erase()
        if input:match("/") then -- this is a command, possibly run it locally
            local cmd, args = input:match("^/([^%s]+)%s*(.*)$") -- TODO: this is horrifying. fix it
            local out = {}
            self.client.rawCallbacks.updateuser:register(function(_, name)
                local userid = psutils.userID(name)
                local cookies = out.cookies
                if cookies then
                    storage.saveCookie(userid, cookies)
                end
            end)
            if cmd then
                if cmd == "connect" and args:match("^(.*),(.*)$") then
                    local nick, pass = args:match("^(.*),(.*)$")
                    self.client:connect(nick, pass, out)
                    return
                elseif cmd == "reconnect" then
                    local cookies = storage.getCookie(#args > 0 and args or nil)
                    self.client:connect(nil, nil, cookies, out)
                    return
                elseif cmd == "quit" then
                    os.exit()
                end
            end
        end
        self:send(input)
    elseif c == 27 then
        self.input.escape = true
    elseif c == curses.KEY_PPAGE then
        self.window.scroll = math.max(0, self.window.scroll - 1)
        self:redraw()
    elseif c == curses.KEY_NPAGE then
        self.window.scroll = self.window.scroll + 1
        self:redraw()
    elseif c == curses.KEY_RESIZE then
        self:resize()
    end
end



return client