local utils = require "utils"
local curses = require "curses"

local input = {}
local methods = {}
local mt = {__index = methods}

input.new = function(window)
    t = setmetatable({}, mt)
    t.buffer = {}
    t.utf8buffer = {}
    t.cursor = 1
    t.offset = 0
    t.escape = false
    t.window = window

    return t
end

methods.erase = function(self)
    self.buffer = {}
    self.utf8buffer = {}
    self.cursor = 1
    self.offset = 0
    self.escape = false
    self:redraw()
end

methods.redraw = function(self)
    local _, width = self.window:getmaxyx()
    local cursorPos = self.cursor - self.offset
    if cursorPos < 3 and self.offset > 0 then
        self.offset = math.max(0, self.cursor - 3)
        cursorPos = math.min(3, self.offset + self.cursor)
    elseif cursorPos > width - 1 then
        self.offset = self.cursor - width + 12
        cursorPos = width - 12
    end
    local start = self.offset + 1
    local end_ = math.min(start + width - 3, #self.buffer)
    self.window:move(0, 0)
    self.window:clrtoeol()
    self.window:attron(curses.A_REVERSE)
    if self.offset > 0 then
        self.window:addstr("<")
    end
    if self.offset + width - 2 < #self.buffer then
        --error("lel")
        self.window:mvaddstr(0, width - 1, ">")
    end
    self.window:attroff(curses.A_REVERSE)
    self.window:mvaddstr(0, 1, table.concat(self.buffer, "", start, end_))
    self.window:move(0, cursorPos)
    self.window:noutrefresh()
    curses.doupdate()
end

methods.backspace = function(self)
    table.remove(self.buffer, self.cursor - 1)
    self.cursor = math.max(1, math.min(#self.buffer+1, self.cursor - 1))
    self:redraw()
end

methods.type = function(self, c)
    table.insert(self.utf8buffer, c)
    if utils.isUtf8Char(self.utf8buffer) then
        local char = {}
        for i, v in ipairs(self.utf8buffer) do
            char[i] = string.char(v)
            self.utf8buffer[i] = nil
        end
        char = table.concat(char)
        table.insert(self.buffer, self.cursor, char)
        self.cursor = self.cursor + 1
    end
    self:redraw()
end

methods.delete = function(self)
    table.remove(self.buffer, self.cursor)
    self:redraw()
end

methods.moveCursor = function(self, direction)
    self.cursor = math.max(1, math.min(#self.buffer+1, self.cursor + direction))
    self:redraw()
end

methods.get = function(self)
    return table.concat(self.buffer)
end

return input
