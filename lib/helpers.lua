function isNumeric(x)
    if tonumber(x) ~= nil then
        return true
    end
    return false
end

function drawIcon(name, x, y, level)
    screen.level(level or 15)
    screen.move(x, y)

    if name == 'play' then
        local w, h = 4, 7
        screen.line(x + w, y + h / 2)
        screen.line(x, y + h)
        screen.line(x, y)
        screen.fill()
        screen.close()
    end
end
