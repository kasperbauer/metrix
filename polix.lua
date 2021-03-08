--
--
-- polix
-- metropolix for norns
--
--
g = grid.connect()
g:rotation(45)

local maxPages = 4
local selectedPage = 1

local selectedVoice = 1
local notSelectedVoice = 2

local momentary = {}
for x = 1, 8 do
    momentary[x] = {}
    for y = 1, 16 do
        momentary[x][y] = false
    end
end

local voice = include('lib/voice')
local voices = {}
voice[1] = voice:new({
    start = 2,
    stop = 6
})
voice[2] = voice:new({
    start = 5,
    stop = 8
})

function init()
    redrawGrid()
end

function redrawGrid()
    drawPageSelector()
    drawLoopSelector()
    g:refresh()
end

function drawPageSelector()
    y = 16
    for x = 1, maxPages do
        g:led(x, y, 3)
    end
    g:led(selectedPage, 16, 15)
end

function drawLoopSelector()
    for y = 1, 2 do
        for x = 1, 8 do
            if y == selectedVoice then
                local start = voice[selectedVoice].loop.start
                local stop = voice[selectedVoice].loop.stop

                if (x >= start and x <= stop) then
                    g:led(x, y, 15)
                else
                    g:led(x, y, 5)
                end
            else
                local start = voice[notSelectedVoice].loop.start
                local stop = voice[notSelectedVoice].loop.stop

                if (x >= start and x <= stop) then
                    g:led(x, y, 8)
                else
                    g:led(x, y, 2)
                end
            end
        end
    end
end

function g.key(x, y, z)
    if z == 1 then
        momentary[x][y] = true

        -- rows 1 & 2: seq length / loop
        if y <= 2 then
            selectVoice(y)
            -- row 16: page selector
        elseif y == 16 and x <= maxPages then
            selectPage(x)
        end
    else
        momentary[x][y] = false
    end
end

function selectPage(pageNumber)
    selectedPage = pageNumber or 1
    redrawGrid()
end

function selectVoice(voiceNumber)
    selectedVoice = voiceNumber or 1

    if selectedVoice == 1 then
        notSelectedVoice = 2
    else
        notSelectedVoice = 1
    end

    redrawGrid()
end
