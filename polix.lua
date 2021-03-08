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
local loopWasSelected = false
local voiceWasSelected = false

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
    local on, off = z == 1, z == 0;

    if on then
        momentary[x][y] = true
    else
        momentary[x][y] = false
    end

    -- row 1 & 2: set seq length / loop
    if y <= 2 then
        if selectedVoice ~= y then
            selectVoice(y)
        else
            local held, tapped, voice = getMomentaryInRow(y), x, getSelectedVoice()

            if on then
                if held and held ~= tapped then
                    voice:setLoop(held, tapped)
                    loopWasSelected = true
                end
            else
                if held == false then
                    if loopWasSelected == false and voiceWasSelected == false then
                        voice:setLoop(tapped, tapped)
                    end

                    if loopWasSelected then
                        loopWasSelected = false
                    end

                    if voiceWasSelected then
                        voiceWasSelected = false
                    end
                end
            end
        end
    end

    -- row 16: select page
    if on and y == 16 and x <= maxPages then
        selectPage(x)
    end

    redrawGrid()
end

function getMomentaryInRow(y)
    for x = 1, 8 do
        if momentary[x][y] then
            return x
        end
    end

    return false
end

function getSelectedVoice(voiceNumber)
    return voice[selectedVoice]
end

function selectPage(pageNumber)
    selectedPage = pageNumber or 1
end

function selectVoice(voiceNumber)
    selectedVoice = voiceNumber or 1

    if selectedVoice == 1 then
        notSelectedVoice = 2
    else
        notSelectedVoice = 1
    end

    voiceWasSelected = true
end
