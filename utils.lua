local utils = {}
local bit32 = require "bit32"
local utf8 = require "utf8"

utils.isUtf8Char = function(t)
    if t[1] < 0x80 then -- 0x0_, single character
        return #t == 1
    elseif t[1] < 0xc0 then -- 0x10_, continuation byte, invalid
        return false
    elseif t[1] < 0xe0 then -- 0x110_, 2 bytes
        return #t == 2 and bit32.band(t[2], 0xc0) == 0x80
    elseif t[1] < 0xf0 then -- 0x1110_, 3 bytes
        return #t == 3 and bit32.band(t[2], 0xc0) == 0x80 and bit32.band(t[3], 0xc0) == 0x80
    elseif t[1] < 0xf8 then -- 0x11110_, 4 bytes
        return #t == 4 and bit32.band(t[2], 0xc0) == 0x80 and bit32.band(t[3], 0xc0) == 0x80 and bit32.band(t[4], 0xc0) == 0x80
    end
    -- otherwise, it's invalid
    return false
end

utils.wrapLine = function(line, width)
    local indent = ""
    if type(line) == "string" then
        text = line
    else
        local rank = line.room and line.room:getUserRank(line.sender) or " "
        indent = rank .. line.sender.name .. ": "
        text =  line.text
    end

    -- splitting 
    local words = {}
    for word in text:gmatch("%s*%S+%s*") do
        words[#words + 1] = word
    end

    -- iterator
    local i = 1
    return function()
        if i > #words then return end
        local length = 0
        local start = i
        while i <= #words do
            length = length + utf8.len(words[i])
            indent = start == 1 and indent or (" "):rep(utf8.len(indent))
            if length > width - utf8.len(indent) then
                local continue = false
                if start == i then -- single word is too long; split it
                    local word = words[i]
                    local beginning = word:sub(1, utf8.offset(word, width - utf8.len(indent)))
                    local ending = word:sub(utf8.offset(word, width - utf8.len(indent) + 1))
                    words[i] = beginning
                    table.insert(words, i+1, ending)
                    continue = true
                end
                if not continue then
                    break
                end
            end
            i = i + 1
        end
        local line = indent .. table.concat(words, "", start, math.min(i-1, #words))
        return line
    end
end


return utils