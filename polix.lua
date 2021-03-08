--
--
-- polix v0.1
-- metropolix for norns
-- github.com/kasperbauer/polix
--
--
g = grid.connect()
g:rotation(45)

-- meta
local VERSION = '0.1'

-- page selector
local maxPages = 4
local selectedPage = 2

-- momentary pressed keys
local momentary = {}
for x = 1, 8 do
    momentary[x] = {}
    for y = 1, 16 do
        momentary[x][y] = false
    end
end

-- voices data
local selectedVoice = 1
local notSelectedVoice = 2
local voice = include('lib/voice')
local voices = {}
voice[1] = voice:new({
    loop = {
        start = 1,
        stop = 6
    }
})
voice[2] = voice:new({
    loop = {
        start = 5,
        stop = 8
    }
})

-- grid state helpers
local loopWasSelected = false
local voiceWasSelected = false

-- directions
local directions = {
    [1] = 'forward',
    [2] = 'reverse',
    [3] = 'alternate',
    [4] = 'random'
}
local selectedDirection = directions[1]

function init()
    redrawGrid()
end

function redrawGrid()
    g:all(0)

    drawLoopSelector()
    drawPageSelector()
    drawShift()

    -- pulse matrix
    if selectedPage == 1 then
        drawTopMatrix('pulses', true)
        drawBottomMatrix('gateType', voice:getGateTypes())
    elseif selectedPage == 2 then
        drawTopMatrix('note', false)
        drawBottomMatrix('octave', voice:getOctaves())
    elseif selectedPage == 3 then
        drawTopMatrix('ratchets', true)
        drawBottomMatrix('probability', voice:getProbabilities())
    elseif selectedPage == 4 then
        -- drawPresetSelector()
        -- drawScaleSelector()
        -- drawRootNoteSelector()
    end

    g:refresh()
end

function drawPageSelector()
    local y = 16

    if shiftIsHeld() == false then
        for x = 1, maxPages do
            g:led(x, y, 3)
        end
        g:led(selectedPage, 16, 15)
    else
        for x = 1, #directions do
            g:led(x, y, 3)

            if selectedDirection == directions[1] and x == 1 then
                g:led(x, y, 15)
            elseif selectedDirection == directions[2] and x == 2 then
                g:led(x, y, 15)
            elseif selectedDirection == directions[3] and x == 3 then
                g:led(x, y, 15)
            elseif selectedDirection == directions[4] and x == 4 then
                g:led(x, y, 15)
            end
        end
    end
end

function drawShift()
    if shiftIsHeld() then
        g:led(8, 16, 15)
    else
        g:led(8, 16, 3)
    end
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
                    g:led(x, y, 3)
                end
            else
                local start = voice[notSelectedVoice].loop.start
                local stop = voice[notSelectedVoice].loop.stop

                if (x >= start and x <= stop) then
                    g:led(x, y, 7)
                else
                    g:led(x, y, 0)
                end
            end
        end
    end
end

function drawTopMatrix(paramName, filled)
    local voice = getSelectedVoice()

    for x = 1, 8 do
        for y = 3, 10 do
            local value = voice.steps[x][paramName]

            if stepInLoop(x, voice) then
                if 11 - y == value then
                    g:led(x, y, 15)
                elseif 11 - y < value and filled then
                    g:led(x, y, 15)
                elseif 11 - y < value and filled == false then
                    g:led(x, y, 3)
                else
                    g:led(x, y, 0)
                end
            else
                if 11 - y == value then
                    g:led(x, y, 3)
                else
                    g:led(x, y, 0)
                end
            end
        end
    end
end

function drawBottomMatrix(param, options)
    local voice = getSelectedVoice()

    for x = 1, 8 do
        local value = voice.steps[x][param]

        for y = 12, 15 do
            if stepInLoop(x, voice) then
                if value == options[1] and y == 12 then
                    g:led(x, y, 10)
                elseif value == options[2] and y == 13 then
                    g:led(x, y, 10)
                elseif value == options[3] and y == 14 then
                    g:led(x, y, 10)
                elseif value == options[4] and y == 15 then
                    g:led(x, y, 10)
                else
                    -- if value == options[4] then
                    --     g:led(x, y, 0)
                    -- else
                    g:led(x, y, 3)
                    -- end
                end
            else
                if value == options[1] and y == 12 then
                    g:led(x, y, 3)
                elseif value == options[2] and y == 13 then
                    g:led(x, y, 3)
                elseif value == options[3] and y == 14 then
                    g:led(x, y, 3)
                elseif value == options[4] and y == 15 then
                    g:led(x, y, 3)
                else
                    g:led(x, y, 0)
                end
            end
        end
    end
end

function stepInLoop(stepIndex, voice)
    return stepIndex >= voice.loop.start and stepIndex <= voice.loop.stop
end

function g.key(x, y, z)
    local on, off = z == 1, z == 0
    local stepIndex, voice = x, getSelectedVoice()
    local step = voice.steps[stepIndex]

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
            local held, tapped = getMomentaryInRow(y), x

            if on then
                if held and held ~= tapped then
                    voice:setLoop(held, tapped)
                    loopWasSelected = true
                end
            else
                if held == false then
                    if loopWasSelected == false and voiceWasSelected == false then
                        if tapped == 1 and voice.loop.start == 1 and voice.loop.stop == 1 then
                            voice:setLoop(1, 8)
                        else
                            voice:setLoop(tapped, tapped)
                        end
                    end

                    loopWasSelected = false
                    voiceWasSelected = false
                end
            end
        end
    end

    -- row 3-10: pulse & gate type matrix
    if selectedPage == 1 and on then

        if y >= 3 and y <= 10 then
            local pulseCount = 11 - y
            voice:setPulses(stepIndex, pulseCount)
        elseif y >= 12 and y <= 15 then
            local gateTypes = voice:getGateTypes()
            local gateType = gateTypes[math.abs(11 - y)]
            if (stepIndex == 1 and step.gateType == gateType) then
                setForAllSteps('gateType', gateType)
            else
                voice:setGateType(stepIndex, gateType)
            end
        end
    end

    -- row 3-10: pitch & octave matrix
    if selectedPage == 2 and on then
        if y >= 3 and y <= 10 then
            local note = 11 - y
            voice:setNote(stepIndex, note)
        elseif y >= 12 and y <= 15 then
            local octaves = voice:getOctaves()
            local octave = octaves[y - 11]
            if (stepIndex == 1 and step.octave == octave) then
                setForAllSteps('octave', octave)
            else
                voice:setOctave(stepIndex, octave)
            end
        end
    end

    -- row 3-10: ratchet & probability matrix
    if selectedPage == 3 and on then
        if y >= 3 and y <= 10 then
            local ratchetCount = 11 - y
            voice:setRatchets(stepIndex, ratchetCount)
        elseif y >= 12 and y <= 15 then
            local probabilities = voice:getProbabilities()
            local probability = probabilities[y - 11]
            if (stepIndex == 1 and step.probability == probability) then
                setForAllSteps('probability', probability)
            else
                voice:setProbability(stepIndex, probability)
            end
        end
    end

    -- row 16: select page
    if on and y == 16 and x <= maxPages then
        if shiftIsHeld() == false then
            selectPage(x)
        else
            selectDirection(directions[x])
        end
    end

    redrawGrid()
end

function setForAllSteps(param, value)
    local voice = getSelectedVoice()
    for i = 1, 8 do
        voice.steps[i][param] = value
    end
end

function getMomentaryInRow(y)
    for x = 1, 8 do
        if momentary[x][y] then
            return x
        end
    end

    return false
end

function shiftIsHeld()
    return momentary[8][16];
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

function selectDirection(direction)
    selectedDirection = direction
end
