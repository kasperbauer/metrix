include('lib/math')

local track = {}

local gateTypes = {
    [1] = 'hold',
    [2] = 'multiple',
    [3] = 'single',
    [4] = 'rest'
}

local gateLengths = {
    [1] = 1,
    [2] = 0.75,
    [3] = 0.5,
    [4] = 0.1
}

local probabilities = {
    [1] = 1,
    [2] = 0.75,
    [3] = 0.5,
    [4] = 0.25
}

local octaves = {
    [1] = 3,
    [2] = 2,
    [3] = 1,
    [4] = 0
}

local divisions = {
    [1] = 1 / 1,
    [2] = 1 / 2,
    [3] = 3 / 8,
    [4] = 1 / 4,
    [5] = 3 / 16,
    [6] = 1 / 8,
    [7] = 1 / 16,
    [8] = 1 / 32
}

local playbackOrders = {
    [1] = 'forward',
    [2] = 'reverse',
    [3] = 'alternate',
    [4] = 'random'
}

function track:new(args)
    local t = setmetatable({}, {
        __index = track
    })

    args = args or {}

    t.division = args.division or 1 / 16
    t.loop = args.loop or {
        start = 1,
        stop = 8
    }
    t.playbackOrder = playbackOrders[1]
    t.alternatePlaybackOrder = 'forward'
    t.transpositionLimit = 4 -- in notes in scale

    if args.stages then
        t.stages = args.stages
    else
        local stages = {};
        for i = 1, 8 do
            stages[i] = {
                pulseCount = i,
                ratchetCount = 1,
                gateType = gateTypes[2],
                gateLength = gateLengths[1],
                pitch = i,
                octave = octaves[1],
                probability = probabilities[1],
                transposition = 0,
                accumulatedPitch = i
            }
        end
        t.stages = stages
    end

    return t
end

function track:randomize(paramNames)
    for i, name in ipairs(paramNames) do
        for stage = 1, 8 do
            if name == 'pulseCount' then
                self:setPulseCount(stage, math.lowerRandom(1, 8))
            end
            if name == 'pitch' then
                self:setPitch(stage, math.random(1, 8))
            end
            if name == 'octave' then
                self:setOctave(stage, octaves[math.random(1, 4)])
            end
            if name == 'gateType' then
                self:setGateType(stage, gateTypes[math.random(1, 4)])
            end
            if name == 'gateLength' then
                self:setGateLength(stage, gateLengths[math.random(1, 4)])
            end
            if name == 'ratchetCount' then
                self:setRatchetCount(stage, math.lowerRandom(1, 8, 4))
            end
            if name == 'probability' then
                self:setProbability(stage, probabilities[math.random(1, 4)])
            end
            if name == 'transposition' then
                self:setTransposition(stage, math.lowerRandom(0, 7, 4))
            end
        end
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

function track:setPulseCount(stage, pulseCount)
    self.stages[stage].pulseCount = pulseCount
end

function track:setRatchetCount(stage, ratchetCount)
    self.stages[stage].ratchetCount = ratchetCount
end

function track:setGateType(stage, gateType)
    self.stages[stage].gateType = gateType
end

function track:setGateLength(stage, gateLength)
    self.stages[stage].gateLength = gateLength
end

function track:setPitch(stage, pitch)
    self.stages[stage].pitch = pitch
    self.stages[stage].accumulatedPitch = pitch
end

function track:resetPitch(stageIndex)
    self.stages[stageIndex].accumulatedPitch = self.stages[stageIndex].pitch
end

function track:resetPitches()
    for stageIndex = 1, #self.stages do
        self:resetPitch(stageIndex)
    end
end

function track:setOctave(stage, octave)
    self.stages[stage].octave = octave
end

function track:setProbability(stage, probability)
    self.stages[stage].probability = probability
end

function track:setDivision(division)
    self.division = division
end

function track:getGateTypes()
    return gateTypes
end

function track:getGateLengths()
    return gateLengths
end

function track:getProbabilities()
    return probabilities
end

function track:getOctaves()
    return octaves
end

function track:getDivisions()
    return divisions
end

function track:getDivisionIndex()
    return tab.key(divisions, self.division)
end

function track:setAll(param, value)
    for i = 1, 8 do
        self.stages[i][param] = value
    end
end

function track:getPulse(trackIndex, stageIndex, pulseCount, scale, rootNote)
    local stage = self.stages[stageIndex]

    if pulseCount > stage.pulseCount then
        return nil
    end

    local first, last = pulseCount == 1, pulseCount >= stage.pulseCount
    local midiNote = self:getMidiNote(trackIndex, stageIndex, scale, rootNote)

    local pulse = {
        pitch = stage.pitch,
        octave = stage.octave,
        midiNote = midiNote,
        hz = self:getHz(midiNote),
        volts = self:getVolts(trackIndex, stageIndex, scale, rootNote),
        pitchName = self:getNoteName(midiNote),
        gateType = stage.gateType,
        gateLength = stage.gateLength,
        probability = stage.probability,
        ratchetCount = stage.ratchetCount,
        first = first,
        last = last,
        duration = 1
    }

    local rest = {
        gateType = 'rest',
        first = first,
        last = last,
        duration = 1
    }

    local void = {
        gateType = 'void',
        first = first,
        last = last,
        duration = 1
    }

    self:accumulatePitch(stageIndex)

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

function track:getMidiNote(trackIndex, stageIndex, scale, rootNote)
    local stage = self.stages[stageIndex]
    local rootOctave = params:get('octave_range_tr_' .. trackIndex) - 1
    local rootNoteInOctave = rootNote + (12 * (stage.octave + rootOctave))
    local pitch = stage.accumulatedPitch
    local midiScale = musicUtil.generate_scale_of_length(rootNoteInOctave, scale.name, pitch)
    return midiScale[pitch]
end

function track:accumulatePitch(stageIndex)
    local stage = self.stages[stageIndex]
    local pitch = stage.accumulatedPitch + stage.transposition
    if (pitch > stage.pitch + self.transpositionLimit) then
        self:setAccumulatedPitch(stageIndex, stage.pitch)
    else
        self:setAccumulatedPitch(stageIndex, pitch)
    end
end

function track:getHz(midiNote)
    return musicUtil.note_num_to_freq(midiNote)
end

function track:getNoteName(midiNote)
    return musicUtil.note_num_to_name(midiNote)
end

function track:getVolts(trackIndex, stageIndex, scale, rootNote)
    local stage = self.stages[stageIndex]
    local voltsPerSemitone = 1 / 12
    local rootOctave = params:get('octave_range_tr_' .. trackIndex) - 1
    local rootVolts = (rootOctave + stage.octave) + (rootNote * voltsPerSemitone)
    local pitch = stage.accumulatedPitch
    if (pitch > #scale.intervals) then
        local factor = math.floor(pitch / #scale.intervals)
        pitch = pitch - (factor * #scale.intervals)
    end

    local semitones = scale.intervals[pitch]
    return rootVolts + (semitones * voltsPerSemitone)
end

function track.getPlaybackOrders()
    return playbackOrders
end

function track:setPlaybackOrder(playbackOrder)
    self.playbackOrder = playbackOrder
end

function track:setTransposition(stageIndex, transposition)
    self.stages[stageIndex].transposition = transposition

    if transposition == 0 then
        self:resetPitch(stageIndex)
    end
end

function track:setAccumulatedPitch(stageIndex, pitch)
    self.stages[stageIndex].accumulatedPitch = pitch
end

return track
