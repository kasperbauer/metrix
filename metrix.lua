-- metrix 210924
--
-- metropolix for norns
--
-- K2: play/pause
-- K3: reset
-- Enc1: select track
-- Enc2/3: transpose octaves
-- K1 + Enc2/3: rotate sequences

musicUtil = require('musicutil')
util = require('util')
include('lib/chords')
preset = include('lib/preset')
sequencer = include('lib/sequencer')
track = include('lib/track')
stage = include('lib/stage')
include('lib/helpers')

m = midi.connect()

-- manual grid rotation
function grid:led(x, y, val)
    _norns.grid_set_led(self.dev, y, 9 - x, val)
end

-- restore default rotation on script clear
function cleanup()
    function grid:led(x, y, val)
        _norns.grid_set_led(self.dev, x, y, val)
    end
end

g = grid.connect()

-- molly the poly
MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
engine.name = "MollyThePoly"

-- page selector
local maxPages = 4
local selectedPage = 1

-- momentary pressed keys
local momentary = {}
for x = 1, 8 do
    momentary[x] = {}
    for y = 1, 16 do
        momentary[x][y] = false
    end
end

local keys = {}
keys[1] = false
keys[2] = false
keys[3] = false

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
    seq:toggleTrack(2)
    m = midi.connect(params:get('midi_device'))
    clock.run(redrawClock)
    math.randomseed(util.time())
    redrawGrid()
    setupCrowInputs()
end

function setupCrowInputs()
    crow.input[2].change = onCrowInputChange
    crow.input[2].mode("change", 2.0, 0.25, "both")
    resetSequencer()
end

function onCrowInputChange(v)
    if v then
        seq:start()
    else
        resetSequencer()
    end
end

function resetSequencer()
    seq:stop()
    seq:reset()
    requestScreenRedraw()
    requestGridRedraw()
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
    for i, scale in ipairs(musicUtil.SCALES) do
        table.insert(scaleNames, string.lower(scale.name))
    end

    params:add_separator("METRIX")
    params:add_group("General", 5)
    params:add_option("scale", "Scale", scaleNames, 1)
    params:set_action("scale", requestGridRedraw)
    params:add_option("root_note", "Root Note", musicUtil.NOTE_NAMES, 1)
    params:set_action("root_note", requestGridRedraw)
    params:add_number("midi_device", "MIDI Device", 1, #midi.vports, 1)
    params:set_action("midi_device", function(port)
        m = midi.connect(port)
    end)
    params:add_binary("midi_send_transport", "Send MIDI Transp. Msgs", "toggle", 0)
    params:add_trigger("reset_all_tracks", "Reset all Tracks")
    params:set_action("reset_all_tracks", function()
        seq:resetTrack(1)
        seq:resetTrack(2)
        requestGridRedraw()
        requestScreenRedraw()
    end)

    for i = 1, 2 do
        params:add_group("Track " .. i, 19)
        params:add_separator('Output')
        params:add_binary("mute_tr_" .. i, "Mute", "toggle", 0)
        params:add_binary("output_audio_tr_" .. i, "Audio", "toggle", 1)
        params:set_action("output_audio_tr_" .. i, function(val)
            if val == 0 then
                seq:noteOffAll({'audio'})
            end
        end)
        params:add_binary("output_midi_tr_" .. i, "MIDI", "toggle", 1)
        params:set_action("output_midi_tr_" .. i, function(val)
            if val == 0 then
                seq:noteOffAll({'midi'})
            end
        end)
        params:add_binary("output_crow_tr_" .. i, "Crow", "toggle", 1)
        params:set_action("output_crow_tr_" .. i, function(val)
            if val == 0 then
                seq:noteOffAll({'crow'})
            end
        end)
        params:add_separator('Pitch')
        params:add_option("octave_range_tr_" .. i, "Octave Range", seq:getOctaveRanges(), 3)
        params:add_number("transpose_limit_tr_" .. i, "Acc. Limit", 1, 127, 7)
        params:add_option("transpose_trigger_tr_" .. i, "Transpose Trigger", sequencer:getTransposeTriggers(), 1)
        params:add_control("slide_amount_tr_" .. i, "Slide Time", csMillis)
        params:add_separator('MIDI')
        params:add_number("midi_ch_tr_" .. i, "MIDI Channel", 1, 127, i)
        params:add_separator('Crow')
        params:add_option("crow_gate_type_tr_" .. i, "GateType", sequencer:getCrowGateTypes(), 2)
        params:add_control("crow_attack_tr_" .. i, "Env. Attack", csMillis)
        params:add_control("crow_sustain_tr_" .. i, "Env. Sustain", csMillis)
        params:add_control("crow_release_tr_" .. i, "Env. Release", csMillis)
        params:add_separator('Reset')
        params:add_trigger("reset_tr_" .. i, "Reset Track")
        params:set_action("reset_tr_" .. i, function()
            seq:resetTrack(i)
            requestGridRedraw()
            requestScreenRedraw()
        end)
    end
end

function clockIsSynced()
    return params:string("clock_source") == "link" or params:string("clock_source") == "midi" or
               params:string("clock_source") == "crow"
end

function redraw() -- 128x64
    screen.clear()

    screen.level(ledLevels.high)
    screen.font_size(8)
    screen.font_face(1)
    screen.move(2, 7)

    local scaleMomentaries = getMomentariesInRow(1, 9)
    local rootNoteMomentaries = getMomentariesInRow(13, 14)
    local presetMomentaries = getMomentariesInRow(1, 8)
    if selectedPage == 4 and #scaleMomentaries > 0 then
        local scale = getScale()
        screen.text(string.lower(scale.name))
    elseif selectedPage == 4 and #rootNoteMomentaries > 0 then
        local noteName = musicUtil.NOTE_NAMES[params:get('root_note')]
        screen.text(string.lower(noteName))
    elseif selectedPage == 3 and #presetMomentaries > 0 then
        if shiftIsHeld() and modIsHeld() then
            screen.text('deleted')
        elseif shiftIsHeld() then
            screen.text('saved')
        else
            screen.text('loaded')
        end
    else
        --- bpm
        local tempo = number_format(clock.get_tempo(), 1)

        if clockIsSynced() then
            screen.circle(2, 5, 1)
            screen.move(6, 7)
        end
        screen.text(tempo .. " bpm")
    end

    -- transport
    if seq.lattice.transport > 0 then
        if seq.lattice.enabled then
            drawIcon('play', 122, 1)
        else
            drawIcon('pause', 121, 1)
        end
    else
        drawIcon('stop', 121, 1)
    end

    -- seperator
    screen.level(ledLevels.low)
    screen.move(63, 9)
    screen.line_width(2)
    screen.line(63, 64)
    screen.stroke()

    -- octaves
    local range1, range2 = params:get('octave_range_tr_1'), params:get('octave_range_tr_2')
    local ranges = {range1, range2}
    local octaveRanges = seq:getOctaveRanges()
    for trackIndex = 1, 2 do
        for rangeIndex, range in ipairs(octaveRanges) do
            if rangeIndex == ranges[trackIndex] then
                screen.rect(57 + (trackIndex - 1) * 9, 31 - ((rangeIndex - 1) * 4), 3, 3)
            else
                screen.rect(58 + (trackIndex - 1) * 9, 32 - ((rangeIndex - 1) * 4), 1, 1)
            end
        end
    end

    -- track sections
    local blockWidth, blockHeight = 6, 3
    for trackIndex = 1, #seq.tracks do
        local track = seq:getTrack(trackIndex)
        local pulse = seq.activePulse[trackIndex]
        local x0 = trackIndex == 2 and 72 or 0
        local width = ((blockWidth + 1) * 8) - 1

        if pulse and pulse.noteName then
            screen.level(15)
            screen.move(x0, 64)
            screen.text(pulse.noteName)
        end

        screen.level(15)
        screen.move(x0 + width, 64)
        screen.text_right(track:getPlaybackOrderSymbol())
        screen.move(x0 + width / 2, 64)
        screen.text_center(track:getHumanReadableDivision())

        -- grid
        local y0 = 44
        for stageIndex = 1, 8 do
            local stage = track:getStageWithIndex(stageIndex)
            local activePulseCoords = seq.activePulseCoords[trackIndex]

            local x = x0 + ((stageIndex - 1) * (blockWidth + 1))

            for pulseIndex = 1, stage.pulseCount do
                local y = y0 - (pulseIndex * (blockHeight + 1))

                if seq:isMuted(trackIndex) then
                    screen.level(1)
                elseif activePulseCoords and activePulseCoords.x == stageIndex and activePulseCoords.y == pulseIndex then
                    screen.level(15)
                elseif track:stageIsInLoop(stageIndex) then
                    screen.level(4)
                else
                    screen.level(1)
                end

                screen.rect(x, y, blockWidth, blockHeight)
                screen.fill()
                screen.close()
            end

            if seq:isMuted(trackIndex) then
                screen.level(4)
                screen.move(x0 + width / 2, y0 + 9)
                screen.text_center('muted')
            elseif track:stageIsInLoop(stageIndex) then
                screen.level(4)
                screen.move(x + blockWidth / 2, y0 + 9)
                screen.text_center(stage:getGateTypeSymbol())
            end
        end

        -- track selection
        if trackIndex == seq.currentTrack then
            local widthLoop = (track.loop.stop - (track.loop.start - 1)) * (blockWidth + 1)
            local xLoop = x0 + (track.loop.start - 1) * (blockWidth + 1)
            screen.level(12)
            screen.rect(xLoop, y0 + 1, widthLoop - 1, 2)
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
        drawTrackPicker(1)
        drawLoopPicker(2)
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
            drawMatrix('transposeAmount', {7, 6, 5, 4, 3, 2, 1, 0}, 3, 10)
            drawBooleanMatrix('slide', 12)
            drawMatrix('transpositionDirection', stage:getTranspositionDirections(), 13, 15)
        else
            drawMatrix('pitch', {8, 7, 6, 5, 4, 3, 2, 1}, 3, 10)
            drawMatrix('octave', {3, 2, 1, 0}, 12, 15)
        end
    elseif selectedPage == 3 then
        drawPresetPicker()
        drawTrackOptions()
    elseif selectedPage == 4 then
        drawScalePicker()
        drawRootNotePicker()
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
        for x = 1, 2 do
            g:led(x, y, ledLevels.mid)
        end
    else
        for x = 1, maxPages do
            g:led(x, y, ledLevels.low)
        end
        g:led(selectedPage, 16, ledLevels.high)
    end
end

function drawShift()
    g:led(8, 1, ledLevels.low)
    g:led(8, 16, ledLevels.low)
end

function drawMod()
    g:led(7, 1, ledLevels.low)
    g:led(7, 16, ledLevels.low)
end

function drawTrackPicker(y)
    for x = 1, #seq.tracks do
        if (x == seq.currentTrack) then
            g:led(x, y, ledLevels.high)
        elseif seq:isMuted(x) then
            g:led(x, y, ledLevels.low)
        else
            g:led(x, y, ledLevels.mid)
        end
    end
end

function drawLoopPicker(y)
    for x = 1, 8 do
        local track = seq:getCurrentTrack()
        local isMuted = seq:isMuted(seq.currentTrack)
        local stage = track:getStageWithIndex(x)
        local start, stop = track.loop.start, track.loop.stop

        if (x >= start and x <= stop) then
            if not isMuted and not stage.skip then
                g:led(x, y, ledLevels.high)
            else
                g:led(x, y, ledLevels.mid)
            end
        else
            g:led(x, y, ledLevels.low)
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

function drawScalePicker()
    local scaleIndex = 1
    local currentScaleIndex = params:get('scale')

    -- default scales
    for y = 1, 6 do
        for x = 1, 8 do
            if scaleIndex > 41 then
                break
            end

            if (currentScaleIndex == scaleIndex) then
                g:led(x, y, ledLevels.high)
            else
                g:led(x, y, ledLevels.low)
            end

            scaleIndex = scaleIndex + 1
        end
    end

    -- major chords
    for x = 1, 8 do
        if scaleIndex > 48 then
            break
        end

        if (currentScaleIndex == scaleIndex) then
            g:led(x, 8, ledLevels.high)
        else
            g:led(x, 8, ledLevels.low)
        end

        scaleIndex = scaleIndex + 1
    end

    -- minor chords
    for x = 1, 8 do
        if scaleIndex > #musicUtil.SCALES then
            break
        end

        if (currentScaleIndex == scaleIndex) then
            g:led(x, 9, ledLevels.high)
        else
            g:led(x, 9, ledLevels.low)
        end

        scaleIndex = scaleIndex + 1
    end
end

function drawRootNotePicker()
    local noteMap = getNoteMap()
    local rootNote = params:get('root_note')
    for pitch, coords in ipairs(noteMap) do
        if rootNote == pitch then
            g:led(coords.x, coords.y, ledLevels.high)
        else
            g:led(coords.x, coords.y, ledLevels.low)
        end
    end
end

function getNoteMap()
    local noteMap = {}
    noteMap[1] = {
        x = 1,
        y = 14
    }
    noteMap[2] = {
        x = 2,
        y = 13
    }
    noteMap[3] = {
        x = 2,
        y = 14
    }
    noteMap[4] = {
        x = 3,
        y = 13
    }
    noteMap[5] = {
        x = 3,
        y = 14
    }
    noteMap[6] = {
        x = 4,
        y = 14
    }
    noteMap[7] = {
        x = 5,
        y = 13
    }
    noteMap[8] = {
        x = 5,
        y = 14
    }
    noteMap[9] = {
        x = 6,
        y = 13
    }
    noteMap[10] = {
        x = 6,
        y = 14
    }
    noteMap[11] = {
        x = 7,
        y = 13
    }
    noteMap[12] = {
        x = 7,
        y = 14
    }

    return noteMap;
end

function getNoteFromCoords(x, y)
    local noteMap = getNoteMap()
    for pitch, coords in ipairs(noteMap) do
        if x == coords.x and y == coords.y then
            return pitch
        end
    end
end

function drawTrackOptions()
    local playbackOrders = track.getPlaybackOrders()
    local y = 10

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
        y = y + 2
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
        keys[n] = true

        if not keys[1] and n == 2 then
            seq:toggle()
        elseif not keys[1] and n == 3 then
            seq:reset()
        end
    else
        keys[n] = false
    end
    requestScreenRedraw()
    requestGridRedraw()
end

function enc(n, d)
    -- track selection
    if n == 1 then
        local trackIndex = d > 0 and 2 or 1
        selectTrack(trackIndex)
    end

    -- octave range
    if n > 1 then
        local trackIndex = n - 1

        if keys[1] then
            local track = seq:getTrack(trackIndex)
            if keys[2] then
                track:rotateGates(d)
            elseif keys[3] then
                track:rotatePitch(d)
            else
                track:rotate(d)
            end
        else
            local octaveRanges, octaveRange = seq:getOctaveRanges(), params:get("octave_range_tr_" .. trackIndex) + d
            octaveRange = util.clamp(octaveRange, 1, #octaveRanges)
            params:set("octave_range_tr_" .. trackIndex, octaveRange)
        end
    end

    requestGridRedraw()
    requestScreenRedraw()
end

function g.key(x, y, z)
    -- manual grid rotation
    local tempX, tempY = x, y
    x = 9 - tempY
    y = tempX

    local on, off = z == 1, z == 0
    local track = seq:getCurrentTrack()

    momentary[x][y] = z == 1 and true or false

    -- row 1: select track
    if selectedPage < 3 and y == 1 and x <= #seq.tracks and on then
        local selectedTrack = seq:getTrack(x)

        if modIsHeld() and shiftIsHeld() then
            selectedTrack:randomizeAll()
        elseif modIsHeld() then
            selectedTrack:randomize({'pulseCount', 'ratchetCount', 'pitch', 'transposeAmount', 'transposeDirection'})
        elseif shiftIsHeld() then
            seq:toggleTrack(x)
        else
            seq:changeTrack(x)
        end
    end

    -- row 2: loopy
    if selectedPage < 3 and y == 2 then
        local stage = track:getStageWithIndex(x)

        if on and modIsHeld() and shiftIsHeld() then
            track:activateAllStages()
            track:setLoop(1, 8)
        elseif on and modIsHeld() then
            track:setLoop(1, 8)
        elseif not modIsHeld() then
            local pushed = getMomentariesInRow(y)

            if on then
                if #pushed == 2 and not shiftIsHeld() then
                    local start, stop = pushed[1], pushed[2]
                    local activeStages = track:getActiveStagesInRange(start, stop)
                    if (#activeStages == 0) then
                        local firstStage = track:getStageWithIndex(start);
                        firstStage.skip = false
                    end
                    track:setLoop(start, stop)
                    loopWasSelected = true
                elseif #pushed == 1 and shiftIsHeld() then
                    local activeStages = track:getActiveStagesInRange()
                    if #activeStages > 1 or stage.skip then
                        stage:toggleParam('skip')
                    end
                end
            elseif #pushed == 0 and not shiftIsHeld() then
                if loopWasSelected == false and trackWasSelected == false then
                    local stage = track:getStageWithIndex(x)
                    stage.skip = false
                    track:setLoop(x, x)
                end

                loopWasSelected = false
                trackWasSelected = false
            end
        end
    end

    -- page 1: pulses & gates
    -- row 3-10: pulse & gate matrix
    if selectedPage == 1 and on then
        local stage = track:getStageWithIndex(x)

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

    -- page 2: pitch
    -- row 3-10: pitch matrix
    if selectedPage == 2 and on then
        local stage = track:getStageWithIndex(x)

        if y >= 3 and y <= 10 then
            if shiftIsHeld() then
                local transposeAmount = 10 - y
                setParam(stage, 'transposeAmount', transposeAmount)
            else
                local pitch = 11 - y
                setParam(stage, 'pitch', pitch)
                setParam(stage, 'accumulatedPitch', pitch)
            end
        elseif y >= 12 and y <= 15 then
            if shiftIsHeld() and y == 12 then
                stage:toggleParam('slide')
            elseif shiftIsHeld() and y <= 15 then
                local direction = stage:getTranspositionDirections()[y - 12]
                setParam(stage, 'transpositionDirection', direction)
            else
                local octave = 15 - y
                setParam(stage, 'octave', octave)
            end
        end
    end

    -- page 3: presets / settings
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

        -- rows 10 & 13: playback order
        if (y == 10 or y == 13) and x <= 4 then
            local trackIndex = 1
            if y == 13 then
                trackIndex = 2
            end
            local track = seq:getTrack(trackIndex)
            local playbackOrders = track:getPlaybackOrders()
            track:setPlaybackOrder(playbackOrders[x])
        end

        -- rows 11 & 14: divisions
        if y == 11 or y == 14 then
            local trackIndex = 1
            if y == 14 then
                trackIndex = 2
            end
            local divisions = track:getDivisions()
            local division = divisions[x]
            seq:setDivision(trackIndex, division)
        end
    end

    -- page 4: scales
    if selectedPage == 4 and on then
        -- row 1-6: default scales
        if y >= 1 and y <= 6 then
            local scaleIndex = (y - 1) * 8 + x
            if scaleIndex <= 41 then
                params:set("scale", scaleIndex)
            end
            -- row 8: major chords
        elseif y == 8 then
            local scaleIndex = (y - 1) * 8 + x - 15
            if scaleIndex <= 48 then
                params:set("scale", scaleIndex)
            end
            -- row 9: major chords
        elseif y == 9 then
            local scaleIndex = (y - 1) * 8 + x - 16
            if scaleIndex <= #musicUtil.SCALES then
                params:set("scale", scaleIndex)
            end
        elseif y == 13 or y == 14 then
            local rootNote = getNoteFromCoords(x, y)
            if rootNote then
                params:set('root_note', rootNote)
            end
        end
    end

    -- row 16: select page
    if on and y == 16 and x <= maxPages then
        if modIsHeld() and shiftIsHeld() then
            if x == 1 then
                track:randomize({'pulseCount', 'ratchetCount', 'gateType', 'probability'})
            elseif x == 2 then
                track:randomize({'pitch', 'transposeAmount', 'octave', 'slide', 'transposeDirection'})
            end
        elseif modIsHeld() then
            if x == 1 then
                track:randomize({'pulseCount', 'ratchetCount'})
            elseif x == 2 then
                track:randomize({'pitch', 'transposeAmount', 'transposeDirection'})
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

function getMomentariesInRow(yStart, yEnd)
    local momentaries, y = {}, yStart
    local yEnd = yEnd or yStart

    while y <= yEnd do
        for x = 1, 8 do
            if momentary[x][y] then
                table.insert(momentaries, x)
            end
        end

        y = y + 1
    end

    return momentaries
end

function shiftIsHeld()
    return momentary[8][16] or momentary[8][1];
end

function modIsHeld()
    return momentary[7][16] or momentary[7][1];
end

function selectPage(pageNumber)
    selectedPage = pageNumber or 1
end

function loadPreset(presetIndex)
    local data = pre:load(presetIndex)

    if not data then
        return
    end

    for trackIndex, track in pairs(data.tracks) do
        seq:swapTrack(trackIndex, track)
    end

    if data.scaleIndex then
        params:set('scale', data.scaleIndex)
    end

    if data.rootNote then
        params:set('root_note', data.rootNote)
    end

    if data.mutes then
        params:set('mute_tr_1', data.mutes[1])
        params:set('mute_tr_2', data.mutes[2])
    end

    if data.octaveRanges then
        params:set('octave_range_tr_1', data.octaveRanges[1])
        params:set('octave_range_tr_2', data.octaveRanges[2])
    end

    requestGridRedraw()
end

function savePreset(presetIndex)
    local mute1, mute2 = params:get('mute_tr_1'), params:get('mute_tr_2')
    local range1, range2 = params:get('octave_range_tr_1'), params:get('octave_range_tr_2')
    local data = {
        tracks = seq.tracks,
        scaleIndex = params:get('scale'),
        rootNote = params:get('root_note'),
        mutes = {mute1, mute2},
        octaveRanges = {range1, range2}
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

function clock.transport.start()
    if clockIsSynced() then
        seq:reset()
        seq:start()
    end
end

function clock.transport.stop()
    if clockIsSynced() then
        seq:stop()
        seq:reset()
        requestScreenRedraw()
        requestGridRedraw()
    end
end

function grid.add()
    g = grid.connect()
    requestGridRedraw()
end

function getScale()
    local scaleIndex = params:get('scale')
    return musicUtil.SCALES[scaleIndex]
end
