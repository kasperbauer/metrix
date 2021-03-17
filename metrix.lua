--
--
-- metrix v0.1
-- metropolix for norns
-- github.com/kasperbauer/metrix
--
--
musicUtil = require('lib/musicutil')
preset = include('lib/preset')
sequencer = include('lib/sequencer')
track = include('lib/track')
include('lib/helpers')

g = grid.connect()
g:rotation(45)

-- molly the poly
MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
engine.name = "MollyThePoly"

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

-- grid state helpers
local loopWasSelected = false
local trackWasSelected = false

-- presets
pre = preset:new()

-- sequencer
seq = sequencer:new(function()
    requestGridRedraw()
    requestScreenRedraw()
end)
seq:addTracks(2)

-- scales
local scales = seq:getScales()

-- redraw
local gridIsDirty = true
local screenIsDirty = false

function init()
    initEngine()
    addParams()
    clock.run(redrawClock)
    math.randomseed(util.time())
end

function initEngine()
    if engine.name == 'MollyThePoly' then
        params:add_group("MOLLY THE POLY", 46)
        MollyThePoly.add_params()
    end
end

function addParams()
    for i = 1, #seq.tracks do
        params:add_group("Metrix: Track " .. i, 9)
        params:add_separator("General")
        params:add_binary("mute_tr_" .. i, "Mute Track", "toggle", false)
        params:add_separator("Pitch")
        params:add_option("octave_range_tr_" .. i, "Octave Range",
            {"0 to 3", "1 to 4", "2 to 5", "3 to 6", "4 to 7", "5 to 8", "6 to 9"}, 3)
        params:add_separator("Accumulator")
        params:add_number("transpose_limit_tr_" .. i, "Acc. Limit", 1, 127, 7)
        params:add_option("transpose_trigger_tr_" .. i, "Transpose Trigger", seq:getTransposeTriggers(), 1)
        params:add_separator("MIDI")
        params:add_number("midi_ch_tr_" .. i, "MIDI Channel", 1, 127, i)
    end
end

function redraw()
    screen.clear()
    screen.move(0, 8)
    screen.text('METRIX')
    screen.move(0, 48)
    if seq then
        screen.text(seq.lattice.transport)
    end
    screen.move(0, 60)
    if seq and seq.lattice.enabled then
        screen.text('||')
    else
        screen.text('>')
    end
    screen.move(20, 60)
    screen.text('reset')
    screen.update()
end

function redrawClock()
    while true do
        clock.sleep(1 / 30)
        if screenIsDirty then
            redraw()
            screenIsDirty = false
        end
        if gridIsDirty then
            redrawGrid()
            gridIsDirty = false
        end
    end
end

function redrawGrid()
    g:all(0)
    drawBottomRow()
    drawShift()
    drawMod()

    if selectedPage >= 1 and selectedPage <= 3 then
        drawLoopPicker()
    end

    -- pulse matrix
    if selectedPage == 1 then
        if shiftIsHeld() then
            drawMatrix('ratchetCount', {8, 7, 6, 5, 4, 3, 2, 1}, 3, 10, true)
            drawMatrix('gateLength', track:getGateLengths(), 12, 15)
        else
            drawMatrix('pulseCount', {8, 7, 6, 5, 4, 3, 2, 1}, 3, 10, true)
            drawMatrix('gateType', track:getGateTypes(), 12, 15)
        end
    elseif selectedPage == 2 then
        if shiftIsHeld() then
            drawMatrix('transposition', {7, 6, 5, 4, 3, 2, 1, 0}, 3, 10)
        else
            drawMatrix('pitch', {8, 7, 6, 5, 4, 3, 2, 1}, 3, 10)
        end
        drawMatrix('octave', track:getOctaves(), 12, 15)
    elseif selectedPage == 3 then
        drawMatrix('probability', track:getProbabilities(), 12, 15)
    elseif selectedPage == 4 then
        drawPresetPicker()
        drawScalePicker()
        drawTrackOptions()
    end

    if selectedPage ~= 4 then
        drawActivePulse()
    end

    drawMomentary()

    g:refresh()
end

function drawBottomRow()
    local y = 16

    if modIsHeld() then
        for x = 1, 3 do
            g:led(x, y, 3)
        end
    else
        for x = 1, maxPages do
            g:led(x, y, 3)
        end
        g:led(selectedPage, 16, 15)
    end
end

function drawShift()
    g:led(8, 16, 3)
end

function drawMod()
    g:led(7, 16, 3)
end

function drawLoopPicker()
    for y = 1, 2 do
        for x = 1, 8 do
            local track = seq:getTrack(y);
            local isSelected, start, stop = seq.currentTrack == y, track.loop.start, track.loop.stop

            if (x >= start and x <= stop) then
                if (isSelected) then
                    g:led(x, y, 15)
                else
                    g:led(x, y, 7)
                end
            else
                if (isSelected) then
                    g:led(x, y, 3)
                else
                    g:led(x, y, 0)
                end
            end
        end
    end
end

function drawMatrix(paramName, options, from, to, filled)
    filled = filled or false

    local track = seq:getCurrentTrack()

    for x = 1, 8 do
        local value = track.stages[x][paramName]
        local offset = from - 1;

        for y = from, to do
            local i = y - offset;
            local key = tab.key(options, value)

            if stageInLoop(x, track) then
                if value == options[i] then
                    g:led(x, y, 11)
                elseif filled and isNumeric(key) and key <= i then
                    g:led(x, y, 11)
                elseif filled and isNumeric(key) and key > i then
                    g:led(x, y, 0)
                else
                    g:led(x, y, 3)
                end
            else
                if value == options[i] then
                    g:led(x, y, 3)
                else
                    g:led(x, y, 0)
                end
            end
        end
    end
end

function stageInLoop(stageIndex, track)
    return stageIndex >= track.loop.start and stageIndex <= track.loop.stop
end

function drawPresetPicker()
    for y = 1, 4 do
        for x = 1, 8 do
            local presetIndex = (y - 1) * 8 + x
            if (pre.current == presetIndex) then
                g:led(x, y, 15)
            elseif pre:exists(presetIndex) then
                g:led(x, y, 7)
            else
                g:led(x, y, 3)
            end
        end
    end
end

function drawScalePicker()
    local rows = math.ceil(#scales / 8)

    scaleIndex = 1
    for y = 6, 6 + rows do
        for x = 1, 8 do
            if (scaleIndex > #scales) then
                break
            elseif seq.scale.name == scales[scaleIndex].name then
                g:led(x, y, 15)
            else
                g:led(x, y, 3)
            end
            scaleIndex = scaleIndex + 1
        end
    end
end

function drawTrackOptions()
    local playbackOrders = track.getPlaybackOrders()
    local y = 12

    for trackIndex = 1, #seq.tracks do
        local track = seq:getTrack(trackIndex)

        -- rows 12 & 15: playback orders
        for x = 1, #playbackOrders do
            g:led(x, y, 3)

            if track.playbackOrder == playbackOrders[1] and x == 1 then
                g:led(x, y, 15)
            elseif track.playbackOrder == playbackOrders[2] and x == 2 then
                g:led(x, y, 15)
            elseif track.playbackOrder == playbackOrders[3] and x == 3 then
                g:led(x, y, 15)
            elseif track.playbackOrder == playbackOrders[4] and x == 4 then
                g:led(x, y, 15)
            end
        end
        y = y + 1

        for x = 1, 8 do
            -- rows 13 & 15: divisions
            if x == track:getDivisionIndex() then
                g:led(x, y, 15)
            else
                g:led(x, y, 3)
            end
        end
        y = y + 1
    end
end

function drawMomentary()
    for x = 1, 8 do
        for y = 1, 16 do
            if momentary[x][y] then
                g:led(x, y, 15)
            end
        end
    end
end

function drawActivePulse()
    if seq.activePulse[seq.currentTrack] then
        local x = seq.activePulse[seq.currentTrack].x
        local y = 11 - seq.activePulse[seq.currentTrack].y
        g:led(x, y, 15);
    end
end

function key(n, z)
    if z == 1 then
        if n == 2 then
            seq:playPause()
        elseif n == 3 then
            seq:reset()
        end
    end
    requestScreenRedraw()
    requestGridRedraw()
end

function g.key(x, y, z)
    local on, off = z == 1, z == 0
    local stageIndex, track = x, seq:getCurrentTrack()
    local stage = track.stages[stageIndex]
    local held, tapped = getMomentariesInRow(y), x

    momentary[x][y] = z == 1 and true or false

    -- row 1 & 2: set seq length / loop
    if selectedPage ~= 4 and y <= 2 then
        if shiftIsHeld() then
            if on then
                seq:toggleTrack(y)
            end
        elseif on and modIsHeld() then
            selectTrack(y)
            track = seq:getCurrentTrack()
            track:setLoop(1, 8)
        elseif seq.currentTrack ~= y then
            selectTrack(y)
        else
            local pushed = getMomentariesInRow(y)
            if on then
                if #pushed == 2 then
                    track:setLoop(pushed[1], pushed[2])
                    loopWasSelected = true
                end
            elseif #pushed == 0 then
                if loopWasSelected == false and trackWasSelected == false then
                    track:setLoop(x, x)
                end

                loopWasSelected = false
                trackWasSelected = false
            end
        end
    end

    -- row 3-10: pulse & gate type matrix
    if selectedPage == 1 and on then
        if y >= 3 and y <= 10 then
            if shiftIsHeld() then
                local ratchetCount = 11 - y
                if modIsHeld() then
                    track:setAll('ratchetCount', ratchetCount)
                else
                    track:setRatchetCount(stageIndex, ratchetCount)
                end
            else
                local pulseCount = 11 - y
                if modIsHeld() then
                    track:setAll('pulseCount', pulseCount)
                else
                    track:setPulseCount(stageIndex, pulseCount)
                end
            end
        elseif y >= 12 and y <= 15 then
            if shiftIsHeld() then
                local gateLengths = track:getGateLengths()
                local gateLength = gateLengths[math.abs(11 - y)]
                if modIsHeld() then
                    track:setAll('gateLength', gateLength)
                else
                    track:setGateLength(stageIndex, gateLength)
                end
            else
                local gateTypes = track:getGateTypes()
                local gateType = gateTypes[math.abs(11 - y)]
                if modIsHeld() then
                    track:setAll('gateType', gateType)
                else
                    track:setGateType(stageIndex, gateType)
                end
            end
        end
    end

    -- row 3-10: pitch & octave matrix
    if selectedPage == 2 and on then
        if y >= 3 and y <= 10 then
            local pitch = 11 - y
            if shiftIsHeld() then
                track:setTransposition(stageIndex, pitch - 1)
            elseif modIsHeld() then
                track:setAll('pitch', pitch)
            else
                track:setPitch(stageIndex, pitch)
            end
        elseif y >= 12 and y <= 15 then
            local octaves = track:getOctaves()
            local octave = octaves[y - 11]
            if modIsHeld() then
                track:setAll('octave', octave)
            else
                track:setOctave(stageIndex, octave)
            end
        end
    end

    -- row 3-10: ratchet & probability matrix
    if selectedPage == 3 and on then
        if y >= 12 and y <= 15 then
            local probabilities = track:getProbabilities()
            local probability = probabilities[y - 11]
            if modIsHeld() then
                track:setAll('probability', probability)
            else
                track:setProbability(stageIndex, probability)
            end
        end
    end

    -- row 16: select page
    if on and y == 16 and x <= maxPages then
        if modIsHeld() then
            if x == 1 then
                track:randomize({'pulseCount', 'ratchetCount', 'gateType', 'gateLength'})
            elseif x == 2 then
                track:randomize({'pitch', 'transposition', 'octave'})
            elseif x == 3 then
                track:randomize({'probability'})
            end
        else
            selectPage(x)
        end
    end

    if selectedPage == 4 and on then
        -- row 1-4: load presets
        if y >= 1 and y <= 4 then
            local presetIndex = (y - 1) * 8 + x
            if shiftIsHeld() and modIsHeld() then
                pre:delete(presetIndex)
            elseif shiftIsHeld() then
                savePreset(presetIndex)
            elseif pre:exists(presetIndex) then
                loadPreset(presetIndex)
            end
        end

        local scaleRows, scaleIndex = math.ceil(#scales / 8), (y - 6) * 8 + x

        -- rows 6 - ?
        if y >= 6 and y <= 6 + scaleRows and scaleIndex <= #scales then
            selectScale(scaleIndex)
        end

        -- rows 12 & 14: playback order
        if (y == 12 or y == 14) and x <= 4 then
            local trackIndex = 1
            if y == 14 then
                trackIndex = 2
            end
            local track = seq:getTrack(trackIndex)
            local playbackOrders = track:getPlaybackOrders()
            track:setPlaybackOrder(playbackOrders[x])
        end

        -- rows 13 & 15: divisions
        if y == 13 or y == 15 then
            local trackIndex = 1
            if y == 15 then
                trackIndex = 2
            end
            local divisions = track:getDivisions()
            local division = divisions[x]
            local track = seq:getTrack(trackIndex)
            local pattern = seq:getPattern(trackIndex)
            track:setDivision(division)
            pattern:set_division(division)
        end
    end

    requestGridRedraw()
end

function getMomentariesInRow(y)
    local momentaries = {}

    for x = 1, 8 do
        if momentary[x][y] then
            table.insert(momentaries, x)
        end
    end

    return momentaries
end

function shiftIsHeld()
    return momentary[8][16];
end

function modIsHeld()
    return momentary[7][16];
end

function selectPage(pageNumber)
    selectedPage = pageNumber or 1
end

function loadPreset(presetIndex)
    local data = pre:load(presetIndex)

    if not data then
        return
    end

    seq:resetTracks()

    for i, track in pairs(data.tracks) do
        seq:addTrack(track)
    end
    seq:changeTrack(1)

    requestGridRedraw()
end

function savePreset(presetIndex)
    local data = {
        tracks = seq.tracks
    }
    pre:save(presetIndex, data)
end

function selectTrack(trackIndex)
    seq:changeTrack(trackIndex)
    trackWasSelected = true
end

function selectScale(scaleIndex)
    seq:setScale(scaleIndex)
end

function requestScreenRedraw()
    screenIsDirty = true
end

function requestGridRedraw()
    gridIsDirty = true
end
