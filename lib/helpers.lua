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
    elseif name == 'pause' then
        local h = 7;
        screen.rect(x, y, 2, h)
        screen.fill()
        screen.rect(x + 3, y, 2, h)
        screen.fill()
        screen.close()
    elseif name == 'stop' then
        local w, h = 5,5
        screen.rect(x, y + 1, w, h)
        screen.fill()
        screen.close()
    end
end
