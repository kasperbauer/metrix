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
    [1] = 5,
    [2] = 4,
    [3] = 3,
    [4] = 2
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
    t.mute = false
    t.playbackOrder = playbackOrders[1]
    t.alternatePlaybackOrder = 'forward'
    t.transpositionLimit = 4 -- in notes in scale

    if args.steps then
        t.steps = args.steps
    else
        local steps = {};
        for i = 1, 8 do
            steps[i] = {
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
        t.steps = steps
    end

    return t
end

function track:randomize(params)
    for i = 1, #params do
        local key = params[i]
        for step = 1, 8 do
            if key == 'pulseCount' then
                self:setPulseCount(step, math.lowerRandom(1, 8))
            end
            if key == 'pitch' then
                self:setPitch(step, math.random(1, 8))
            end
            if key == 'octave' then
                self:setOctave(step, octaves[math.random(1, 4)])
            end
            if key == 'gateType' then
                self:setGateType(step, gateTypes[math.random(1, 4)])
            end
            if key == 'gateLength' then
                self:setGateLength(step, gateLengths[math.random(1, 4)])
            end
            if key == 'ratchetCount' then
                self:setRatchetCount(step, math.lowerRandom(1, 8, 4))
            end
            if key == 'probability' then
                self:setProbability(step, probabilities[math.random(1, 4)])
            end
            if key == 'transposition' then
                self:setTransposition(step, math.lowerRandom(0, 7, 4))
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

function track:setPulseCount(step, pulseCount)
    self.steps[step].pulseCount = pulseCount
end

function track:setRatchetCount(step, ratchetCount)
    self.steps[step].ratchetCount = ratchetCount
end

function track:setGateType(step, gateType)
    self.steps[step].gateType = gateType
end

function track:setGateLength(step, gateLength)
    self.steps[step].gateLength = gateLength
end

function track:setPitch(step, pitch)
    self.steps[step].pitch = pitch
    self.steps[step].accumulatedPitch = pitch
end

function track:resetPitch(stepIndex)
    self.steps[stepIndex].accumulatedPitch = self.steps[stepIndex].pitch
end

function track:resetPitches()
    for stepIndex = 1, #self.steps do
        self:resetPitch(stepIndex)
    end
end

function track:setOctave(step, octave)
    self.steps[step].octave = octave
end

function track:setProbability(step, probability)
    self.steps[step].probability = probability
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
        self.steps[i][param] = value
    end
end

function track:getPulse(stepIndex, pulseCount, scale, rootNote)
    local step = self.steps[stepIndex]

    if pulseCount > step.pulseCount then
        return nil
    end

    local first, last = pulseCount == 1, pulseCount >= step.pulseCount
    local midiNote = self:getMidiNote(stepIndex, scale, rootNote)

    local pulse = {
        pitch = step.pitch,
        octave = step.octave,
        midiNote = midiNote,
        hz = self:getHz(midiNote),
        volts = self:getVolts(stepIndex, scale, rootNote),
        pitchName = self:getNoteName(midiNote),
        gateType = step.gateType,
        gateLength = step.gateLength,
        probability = step.probability,
        ratchetCount = step.ratchetCount,
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

    self:accumulatePitch(stepIndex)

    if step.gateType == 'rest' then
        return rest
    end

    if step.gateType == 'multiple' then
        return pulse
    end

    if step.gateType == 'single' then
        if pulse.first then
            return pulse
        else
            return rest
        end
    end

    if step.gateType == 'hold' then
        if pulse.first then
            pulse.duration = pulse.duration * step.pulseCount
            return pulse
        else
            return void
        end
    end
end

function track:getMidiNote(stepIndex, scale, rootNote)
    local step = self.steps[stepIndex]
    local rootNoteInOctave = rootNote + (12 * step.octave)
    local pitch = step.accumulatedPitch
    local midiScale = musicUtil.generate_scale_of_length(rootNoteInOctave, scale.name, pitch)
    return midiScale[pitch]
end

function track:accumulatePitch(stepIndex)
    local step = self.steps[stepIndex]
    local pitch = step.accumulatedPitch + step.transposition
    if (pitch > step.pitch + self.transpositionLimit) then
        self:setAccumulatedPitch(stepIndex, step.pitch)
    else
        self:setAccumulatedPitch(stepIndex, pitch)
    end
end

function track:getHz(midiNote)
    return musicUtil.note_num_to_freq(midiNote)
end

function track:getNoteName(midiNote)
    return musicUtil.note_num_to_name(midiNote)
end

function track:getVolts(stepIndex, scale, rootNote)
    local step = self.steps[stepIndex]
    local voltsPerSemitone = 1 / 12
    local rootVolts = step.octave + (rootNote * voltsPerSemitone)
    local pitch = step.accumulatedPitch
    if (pitch > #scale.intervals) then
        local factor = math.floor(pitch / #scale.intervals)
        pitch = pitch - (factor * #scale.intervals)
    end

    local semitones = scale.intervals[pitch]
    return rootVolts + (semitones * voltsPerSemitone)
end

function track:toggle()
    self.mute = not self.mute
end

function track:mute()
    self.mute = true
end

function track:unmute()
    self.mute = false
end

function track.getPlaybackOrders()
    return playbackOrders
end

function track:setPlaybackOrder(playbackOrder)
    self.playbackOrder = playbackOrder
end

function track:setTransposition(stepIndex, transposition)
    self.steps[stepIndex].transposition = transposition
    
    if transposition == 0 then
        self:resetPitch(stepIndex)
    end
end

function track:setAccumulatedPitch(stepIndex, pitch)
    self.steps[stepIndex].accumulatedPitch = pitch
end

return track
