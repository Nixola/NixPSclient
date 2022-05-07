local curses = require "curses"
local cqueues = require "cqueues"
local PS = require "ps"
local utils = require "utils"
local Client = require "client"

local loop, looperr = cqueues.new()

local function main()
    os.setlocale("") -- for proper unicode support, or that's what Copilot thinks
    local screen = curses.initscr()
    local test = curses.start_color()
    screen:clear()
    screen:keypad()

    curses.cbreak ()
    curses.echo (false)	-- not noecho !
    curses.nl (false)	-- not nonl !
    screen:idcok(false)
    screen:idlok(false)
    screen:nodelay(true)

    curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLUE)
    curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLACK)
    curses.init_pair(3, curses.COLOR_WHITE, curses.COLOR_BLUE)
    curses.init_pair(4, curses.COLOR_WHITE, curses.COLOR_BLACK)

    local client = PS.new(nil, loop)
    local interface = Client.new(screen, client)
    client.rawCallbacks.updateuser:register(function(_, nick)
        interface:log("", "Your username is now " .. nick:gsub("^%s*", "") .. ".")
    end)
    client.rawCallbacks.init:register(function(room, type)
        interface:newRoom(room.id):setType(type)
    end)
    client.rawCallbacks.deinit:register(function(room)
        interface:deleteRoom(room.id)
    end)
    client.rawCallbacks.title:register(function(room, name)
        interface:updateRoom(room.id, {name = name})
        interface:switchRoom(room.id)
    end)
    client.callbacks.chat:register(function(message)
        if not message.self then
            if message.text:lower():find(client.self.name:lower()) and not message.backlog then
                --curses.flash()
                curses.beep()
            end
        end
        interface:message(message)
    end)

    interface.callbacks.send:register(function(str)
        client:send(str)
    end)

    --client:connect("[REDACTED]", "[REDACTED]") -- yes I will add a /connect command or something

    loop:wrap(function()
        while true do
            interface:getInput()
            cqueues.sleep(1/60)
        end
    end)

    local success, err = loop:loop()

    curses.endwin()
    if not success then
        print(err)
    end
    for err in loop:errors(1) do
        print(err)
    end
end

local function err(str)
    curses.endwin()
    print(str)
    print(debug.traceback())
end

xpcall(main, err)