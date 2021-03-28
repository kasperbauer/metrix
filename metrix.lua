-- metrix v1.0
--
-- metropolix for norns
--
-- K2: play/pause
-- K3: reset and restart
--
-- Enc2: select track
musicUtil = require('lib/musicutil')
preset = include('lib/preset')
sequencer = include('lib/sequencer')
track = include('lib/track')
include('lib/helpers')

m = midi.connect()
g = grid.connect()
g:rotation(45)

-- molly the poly
MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
engine.name = "MollyThePoly"

-- page selector
local maxPages = 3
local selectedPage = 1

-- momentary pressed keys
local momentary = {}
for x = 1, 8 do
    momentary[x] = {}
    for y = 1, 16 do
        momentary[x][y] = false
    end
end

-- brightness levels
local ledLevels = {
    off = 0,
    low = 4,
    mid = 9,
    high = 15
}

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

-- redraw
local gridIsDirty = true
local screenIsDirty = false

function init()
    initEngine()
    addParams()
    m = midi.connect(params:get('midi_device'))
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
    local csMillis = controlspec.new(0, 5, 'lin', 0.05, 0.05, 's')
    local scaleNames = {}
    for i = 1, #musicUtil.SCALES do
        table.insert(scaleNames, string.lower(musicUtil.SCALES[i].name))
    end

    params:add_separator("METRIX")
    params:add_group("General", 3)
    params:add_option("scale", "Scale", scaleNames, 1)
    params:add_option("root_note", "Root Note", musicUtil.NOTE_NAMES, 1)
    params:add_number("midi_device", "MIDI Device", 1, #midi.vports, 1)
    params:set_action("midi_device", function(port)
        m = midi.connect(port)
    end)

    for i = 1, 2 do
        params:add_group("Track " .. i, 17)
        params:add_separator('Output')
        params:add_binary("mute_tr_" .. i, "Mute", "toggle", 0)
        params:add_binary("output_audio_tr_" .. i, "Audio", "toggle", 1)
        params:add_binary("output_midi_tr_" .. i, "MIDI", "toggle", 1)
        params:add_binary("output_crow_tr_" .. i, "Crow", "toggle", 1)
        params:add_separator('Pitch')
        params:add_option("octave_range_tr_" .. i, "Octave Range",
            {"1 to 4", "2 to 5", "3 to 6", "4 to 7", "5 to 8", "6 to 9"}, 4)
        params:add_number("transpose_limit_tr_" .. i, "Acc. Limit", 1, 127, 7)
        params:add_option("transpose_trigger_tr_" .. i, "Transpose Trigger", sequencer:getTransposeTriggers(), 1)
        params:add_control("slide_amount_tr_" .. i, "Slide Time", csMillis)
        params:add_separator('MIDI')
        params:add_number("midi_ch_tr_" .. i, "MIDI Channel", 1, 127, i)
        params:add_separator('Crow')
        params:add_option("crow_gate_type_tr_" .. i, "GateType", sequencer:getCrowGateTypes(), 3)
        params:add_control("crow_attack_tr_" .. i, "Env. Attack", csMillis)
        params:add_control("crow_sustain_tr_" .. i, "Env. Sustain", csMillis)
        params:add_control("crow_release_tr_" .. i, "Env. Release", csMillis)
    end
end

function redraw() -- 128x64
    screen.clear()
    screen.level(ledLevels.high)

    -- transport
    if seq.lattice.enabled then
        screen.move(120, 8)
        screen.font_size(8)
        screen.font_face(1)
        screen.text_right(seq.lattice.transport)
        drawIcon('play', 124, 2)
    end

    -- seperator
    screen.level(10)
    screen.move(63, 0)
    screen.line_width(2)
    screen.line(63, 64)
    screen.stroke()

    -- track sections
    local pulseWidth, pulseHeight = 6, 3
    for trackIndex = 1, #seq.tracks do
        local track = seq:getTrack(trackIndex)
        local pulse = seq.activePulse[trackIndex]
        local x0 = trackIndex == 2 and 72 or 0
        local width = ((pulseWidth + 1) * 8) - 1

        if pulse then
            screen.level(15)
            screen.move(x0, 64)
            screen.text(pulse.noteName)
        end

        screen.level(15)
        screen.move(x0 + width, 64)
        screen.text_right(track:getPlaybackOrderShort())

        -- grid
        for stageIndex = 1, 8 do
            local stage = track:getStageWithIndex(stageIndex)
            local activePulseCoords = seq.activePulseCoords[trackIndex]

            local x = x0 + ((stageIndex - 1) * (pulseWidth + 1))

            for pulseIndex = 1, stage.pulseCount do
                local y = 48 - (pulseIndex * (pulseHeight + 1))

                if seq:isMuted(trackIndex) then
                    screen.level(1)
                elseif activePulseCoords and activePulseCoords.x == stageIndex and activePulseCoords.y == pulseIndex then
                    screen.level(15)
                elseif track:stageIsInLoop(stageIndex) then
                    screen.level(4)
                else
                    screen.level(1)
                end

                screen.rect(x, y, pulseWidth, pulseHeight)
                screen.fill()
                screen.close()
            end
        end

        -- track selection
        if trackIndex == seq.currentTrack then
            screen.level(12)
            screen.rect(x0, 32 + (pulseHeight * 4) + 5, width, 2)
            screen.fill()
            screen.close()
        end
    end

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
            drawMatrix('probability', stage:getProbabilities(), 12, 15)
            -- drawMatrix('gateLength', stage:getGateLengths(), 12, 15)
        else
            drawMatrix('pulseCount', {8, 7, 6, 5, 4, 3, 2, 1}, 3, 10, true)
            drawMatrix('gateType', stage:getGateTypes(), 12, 15)
        end
    elseif selectedPage == 2 then
        if shiftIsHeld() then
            drawMatrix('transpose', {7, 6, 5, 4, 3, 2, 1, 0}, 3, 10)
            drawBooleanMatrix('slide', 12)
            drawBooleanMatrix('accent', 13)
        else
            drawMatrix('pitch', {8, 7, 6, 5, 4, 3, 2, 1}, 3, 10)
            drawMatrix('octave', {3, 2, 1, 0}, 12, 15)
        end
    elseif selectedPage == 3 then
        drawPresetPicker()
        drawTrackOptions()
    end

    if selectedPage < 3 then
        drawPulseCursor()
    end

    drawMomentary()

    g:refresh()
end

function drawBottomRow()
    local y = 16

    if modIsHeld() then
        for x = 1, (maxPages - 1) do
            g:led(x, y, ledLevels.mid)
        end
    elseif shiftIsHeld() then
        for x = 1, #seq.tracks do
            if not seq:isMuted(x) then
                g:led(x, y, ledLevels.high)
            else
                g:led(x, y, ledLevels.low)
            end
        end
    else
        for x = 1, maxPages do
            g:led(x, y, ledLevels.low)
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
                    g:led(x, y, ledLevels.high)
                else
                    g:led(x, y, ledLevels.mid)
                end
            else
                if (isSelected) then
                    g:led(x, y, ledLevels.low)
                else
                    g:led(x, y, ledLevels.off)
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
        local stageIndex = x

        for y = from, to do
            local i = y - offset;
            local key = tab.key(options, value)

            if track:stageIsInLoop(stageIndex) then
                if value == options[i] then
                    g:led(x, y, 11)
                elseif filled and isNumeric(key) and key <= i then
                    g:led(x, y, 11)
                elseif filled and isNumeric(key) and key > i then
                    g:led(x, y, ledLevels.off)
                else
                    g:led(x, y, ledLevels.low)
                end
            else
                if value == options[i] then
                    g:led(x, y, ledLevels.low)
                else
                    g:led(x, y, ledLevels.off)
                end
            end
        end
    end
end

function drawBooleanMatrix(paramName, y)
    local track = seq:getCurrentTrack()

    for x = 1, 8 do
        local stageIndex = x
        local value = track.stages[x][paramName]
        if track:stageIsInLoop(stageIndex) then
            if value then
                g:led(x, y, ledLevels.high)
            else
                g:led(x, y, ledLevels.low)
            end
        elseif value then
            g:led(x, y, ledLevels.low)
        end
    end
end

function drawPresetPicker()
    for y = 1, 8 do
        for x = 1, 8 do
            local presetIndex = (y - 1) * 8 + x
            if (pre.current == presetIndex) then
                g:led(x, y, ledLevels.high)
            elseif pre:exists(presetIndex) then
                g:led(x, y, ledLevels.mid)
            else
                g:led(x, y, ledLevels.low)
            end
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
            g:led(x, y, ledLevels.low)

            if track.playbackOrder == playbackOrders[1] and x == 1 then
                g:led(x, y, ledLevels.high)
            elseif track.playbackOrder == playbackOrders[2] and x == 2 then
                g:led(x, y, ledLevels.high)
            elseif track.playbackOrder == playbackOrders[3] and x == 3 then
                g:led(x, y, ledLevels.high)
            elseif track.playbackOrder == playbackOrders[4] and x == 4 then
                g:led(x, y, ledLevels.high)
            end
        end
        y = y + 1

        for x = 1, 8 do
            -- rows 13 & 15: divisions
            if x == track:getDivisionIndex() then
                g:led(x, y, ledLevels.high)
            else
                g:led(x, y, ledLevels.low)
            end
        end
        y = y + 1
    end
end

function drawMomentary()
    for x = 1, 8 do
        for y = 1, 16 do
            if momentary[x][y] then
                g:led(x, y, ledLevels.high)
            end
        end
    end
end

function drawPulseCursor()
    local coords = seq.activePulseCoords[seq.currentTrack];
    if coords then
        local x = coords.x
        local y = 11 - coords.y
        g:led(x, y, ledLevels.high);
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

function enc(n, d)
    -- track selection
    if n == 2 then
        if d > 0 then
            selectTrack(2)
        else
            selectTrack(1)
        end
    end

    requestGridRedraw()
    requestScreenRedraw()
end

function g.key(x, y, z)
    local on, off = z == 1, z == 0
    local track = seq:getCurrentTrack()
    local stage = track:getStageWithIndex(x)
    local held, tapped = getMomentariesInRow(y), x

    momentary[x][y] = z == 1 and true or false

    -- row 1 & 2: set seq length / loop
    if selectedPage ~= 3 and y <= 2 then
        if on and modIsHeld() then
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

    -- row 3-10: pulse & gate matrix
    if selectedPage == 1 and on then
        if y >= 3 and y <= 10 then
            if shiftIsHeld() then
                local ratchetCount = 11 - y
                setParam(stage, 'ratchetCount', ratchetCount)
            else
                local pulseCount = 11 - y
                setParam(stage, 'pulseCount', pulseCount)
            end
        elseif y >= 12 and y <= 15 then
            if shiftIsHeld() then
                local probabilities = stage:getProbabilities()
                local probability = probabilities[y - 11]
                setParam(stage, 'probability', probability)
                -- local gateLengths = stage:getGateLengths()
                -- local gateLength = gateLengths[math.abs(11 - y)]
                -- setParam(stage, 'gateLength', gateLength)
            else
                local gateTypes = stage:getGateTypes()
                local gateType = gateTypes[math.abs(11 - y)]
                setParam(stage, 'gateType', gateType)
            end
        end
    end

    -- row 3-10: pitch matrix
    if selectedPage == 2 and on then
        if y >= 3 and y <= 10 then
            if shiftIsHeld() then
                local transpose = 10 - y
                setParam(stage, 'transpose', transpose)
            else
                local pitch = 11 - y
                setParam(stage, 'pitch', pitch)
                setParam(stage, 'accumulatedPitch', pitch)
            end
        elseif y >= 12 and y <= 15 then
            if shiftIsHeld() and y == 12 then
                stage:toggleParam('slide')
            elseif shiftIsHeld() and y == 13 then
                stage:toggleParam('accent')
            else
                local octave = 15 - y
                setParam(stage, 'octave', octave)
            end
        end
    end

    if selectedPage == 3 and on then
        -- row 1-4: load presets
        if y >= 1 and y <= 8 then
            local presetIndex = (y - 1) * 8 + x
            if shiftIsHeld() and modIsHeld() then
                pre:delete(presetIndex)
            elseif shiftIsHeld() then
                savePreset(presetIndex)
            elseif pre:exists(presetIndex) then
                loadPreset(presetIndex)
            end
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

    -- row 16: select page / randomize / mute
    if on and y == 16 and x <= maxPages then
        if shiftIsHeld() and not modIsHeld() and x <= 2 then
            seq:toggleTrack(x)
        elseif modIsHeld() then
            if x == 1 then
                track:randomize({'pulseCount', 'ratchetCount', 'gateType', 'probability'})
            elseif x == 2 then
                track:randomize({'pitch', 'transpose', 'octave', 'slide', 'accent'})
            end
        else
            selectPage(x)
        end
    end

    requestGridRedraw()
    requestScreenRedraw()
end

function setParam(stage, paramName, value)
    if modIsHeld() then
        local track = seq:getCurrentTrack()
        track:setAll(paramName, value)
    else
        stage:setParam(paramName, value)
    end
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

function requestScreenRedraw()
    screenIsDirty = true
end

function requestGridRedraw()
    gridIsDirty = true
end
