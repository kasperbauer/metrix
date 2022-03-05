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
        local w, h = 5, 5
        screen.rect(x, y + 1, w, h)
        screen.fill()
        screen.close()
    end
end

function number_format(number, decimals)
    local power = 10 ^ decimals
    return math.floor(number * power) / power
end

function tab.rotate(data, d)
    if d > 0 then
        local last = table.remove(data)
        table.insert(data, 1, last)
    else
        local first = table.remove(data, 1)
        table.insert(data, first)
    end
end

function tab.merge(table1, table2)
    for k, v in pairs(table2) do
        table1[k] = v
    end
end

function tab.pick(data, props)
    local picks = {}

    for i, item in ipairs(data) do
        local pick = {}

        for i, key in ipairs(props) do
            pick[key] = item[key]
        end

        table.insert(picks, pick)
    end

    return picks;
end
