local utf8 = require "utf8"
local utils = require "utils"
local curses = require "curses"

local room = {}
local methods = {}
local mt = {__index = methods}

local types = {
    chat = "#",
    pm = "",
    battle = "!",
    status = "~",
}

room.new = function(id)
    local t = setmetatable({}, mt)
    t.id = id
    t.lines = {}

    t.scroll = 0

    return t
end

methods.setType = function(self, type)
    self.type = type
    self.shortType = types[type] or ""
end

methods.setName = function(self, name)
    self.name = name
end

methods.message = function(self, message)
    self.lines[#self.lines + 1] = message
    if self.scroll > 0 then
        self.scroll = self.scroll + 1
    end
end

methods.log = function(self, text)
    self.lines[#self.lines + 1] = text
end

methods.render = function(self, window)
    --[[ TODO FIXME the first message is always printed fully; this should not necessarily happen.
         when the first message is longer than a line, it should be possible to print it partially.
    ]]
    local height, width = window:getmaxyx()
    window:erase()
    local lines = {}
    local i = #self.lines
    self.scroll = math.max(0, math.min(self.scroll, #self.lines - height))
    while #lines < height and i > 0 do
        local line = self.lines[i - self.scroll]
        local n = #lines + 1
        for part in utils.wrapLine(line, width - 2) do
            table.insert(lines, n, part)
        end
        i = i - 1
    end

    for i = 1, math.min(height, #lines) do
        window:mvaddstr(i - 1, 1, lines[math.min(#lines, height) - i + 1])
    end

    window:noutrefresh()
    curses.doupdate()
end

return room