--
--
-- polix
-- metropolix for norns
--
--
g = grid.connect()
g:rotation(45)

local page = 1
local maxPages = 4

function init()
    redrawGrid()
end

function redrawGrid()
    drawPages()
end

function drawPages()
    for i = 1, maxPages do
        g:led(i, 16, 5)
    end
    g:led(page, 16, 15)
    g:refresh()
end

function g.key(x, y, z)
    if z == 1 and y == 16 and x <= maxPages then
        selectPage(x)
    end
end

function selectPage(pageNumber)
    page = pageNumber or 1
    redrawGrid()
end

drawPages()
