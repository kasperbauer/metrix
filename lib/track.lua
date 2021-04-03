include('lib/math')
stage = include('lib/stage')

local track = {}

local divisions = {1 / 1, 1 / 2, 3 / 8, 1 / 4, 3 / 16, 1 / 8, 1 / 16, 1 / 32}
local playbackOrders = {'forward', 'reverse', 'alternate', 'random'}

function track:new(args)
    local t = setmetatable({}, {
        __index = track
    })

    args = args or {}

    t.division = args.division or 1 / 8
    t.loop = args.loop or {
        start = 1,
        stop = 8
    }
    t.playbackOrder = args.playbackOrder or playbackOrders[1]
    t.alternatePlaybackOrder = 'forward'

    local stages = {};
    if args.stages then
        for i, stageData in ipairs(args.stages) do
            stages[i] = stage:new(stageData)
        end
    else
        for i = 1, 8 do
            stages[i] = stage:new({
                pitch = i
            })
        end
    end
    t.stages = stages

    -- reset accumulation on loading preset
    for i = 1, 8 do
        t.stages[i].accumulatedPitch = t.stages[i].pitch
    end

    return t
end

function track:randomize(paramNames)
    for i, name in ipairs(paramNames) do
        if name == 'playbackOrder' then
            self.playbackOrder = playbackOrders[math.random(1, 4)]
        end
        if name == 'division' then
            self.division = divisions[math.random(1, 8)]
        end
    end

    for k, stage in pairs(self.stages) do
        stage:randomize(paramNames)
    end
end

function track:setLoop(start, stop)
    -- switch start / stop values if start > stop
    if start > stop then
        local temp = start
        start = stop
        stop = temp
    end

    self.loop.start = start or 1
    self.loop.stop = stop or 8
end

function track:getStageWithIndex(stageIndex)
    return self.stages[stageIndex]
end

function track:resetPitches()
    for k, stage in pairs(self.stages) do
        stage:resetPitch()
    end
end

function track:setDivision(division)
    self.division = division
end

function track:getDivisions()
    return divisions
end

function track:getDivisionIndex()
    return tab.key(divisions, self.division)
end

function track:setAll(paramName, value)
    for k, stage in pairs(self.stages) do
        stage:setParam(paramName, value)
    end
end

function track:getPulse(trackIndex, stageIndex, pulseCount)
    local stage = self:getStageWithIndex(stageIndex)

    if pulseCount > stage.pulseCount then
        return nil
    end

    local first = pulseCount == 1
    local last = pulseCount >= stage.pulseCount
    local octave = self:getOctaveByIndex(trackIndex, stageIndex)
    local midiNote = self:getMidiNote(stage.accumulatedPitch, octave)
    local scale = self:getScale()
    local accumulatedOctave = math.floor(((midiNote - 24) / 12) + 1)
    local slideAmount = stage.slide and params:get('slide_amount_tr_' .. trackIndex) or 0

    local pulse = {
        pulseCount = pulseCount,
        pitch = stage.accumulatedPitch,
        octave = octave,
        midiNote = midiNote,
        hz = self:getHz(midiNote),
        volts = self:getVolts(midiNote, octave),
        noteName = self:getNoteName(midiNote) .. accumulatedOctave,
        gateType = stage.gateType,
        gateLength = stage.gateLength,
        probability = stage.probability,
        ratchetCount = stage.ratchetCount,
        first = first,
        last = last,
        duration = 1,
        slideAmount = slideAmount,
    }

    local rest = {
        gateType = 'rest',
        first = first,
        last = last,
        duration = 1,
        noteName = pulse.noteName
    }

    local void = {
        gateType = 'void',
        first = first,
        last = last,
        duration = 1,
        noteName = pulse.noteName
    }

    if stage.gateType == 'rest' then
        return rest
    end

    if stage.gateType == 'multiple' then
        return pulse
    end

    if stage.gateType == 'single' then
        if pulse.first then
            return pulse
        else
            return rest
        end
    end

    if stage.gateType == 'hold' then
        if pulse.first then
            pulse.duration = pulse.duration * stage.pulseCount
            return pulse
        else
            return void
        end
    end
end

function track:getOctaveByIndex(trackIndex, stageIndex)
    local stage = self.stages[stageIndex]
    return params:get('octave_range_tr_' .. trackIndex) + stage.octave
end

function track:getScale()
    local scaleIndex = params:get('scale')
    return musicUtil.SCALES[scaleIndex]
end

function track:getRootNote()
    return params:get("root_note")
end

function track:getMidiNote(pitch, octave)
    local scale = self:getScale()
    local pitch = pitch
    -- 24 == C1
    local scaleRoot = 24 + (self:getRootNote() - 1)
    local midiScale = musicUtil.generate_scale_of_length(scaleRoot, scale.name, pitch)
    local midiNote = midiScale[pitch] + (octave - 1) * 12;
    return util.clamp(midiNote, 0, 127)
end

function track:getHz(midiNote)
    return musicUtil.note_num_to_freq(midiNote)
end

function track:getNoteName(midiNote)
    return musicUtil.note_num_to_name(midiNote)
end

function track:getVolts(midiNote, octave)
    local offset = 24 -- c1
    local volts = (midiNote - offset) / 12
    -- limit eurorack to 0-10V
    return util.clamp(volts, 0, 10)
end

function track.getPlaybackOrders()
    return playbackOrders
end

function track:setPlaybackOrder(playbackOrder)
    self.playbackOrder = playbackOrder
end

function track:stageIsInLoop(stageIndex)
    return stageIndex >= self.loop.start and stageIndex <= self.loop.stop
end

function track:getPlaybackOrderSymbol()
    local short = '>'
    if self.playbackOrder == 'reverse' then
        short = '<'
    elseif self.playbackOrder == 'alternate' then
        short = '< >'
    elseif self.playbackOrder == 'random' then
        short = '?'
    end

    return short
end

function track:getHumanReadableDivision()
    local index = tab.key(divisions, self.division)
    local humanReadableDivisions = {
        [1] = "1/1",
        [2] = "1/2",
        [3] = "1/4.",
        [4] = "1/4",
        [5] = "1/8.",
        [6] = "1/8",
        [7] = "1/16",
        [8] = "1/32"
    }
    return humanReadableDivisions[index]
end

return track
