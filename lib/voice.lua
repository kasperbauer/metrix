local voice = {}

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

function voice:new(args)
    local t = setmetatable({}, {
        __index = voice
    })

    args = args or {}

    t.division = args.division or 1 / 16
    t.loop = args.loop or {
        start = 1,
        stop = 8
    }

    if args.steps then
        t.steps = args.steps
    else
        local steps = {};
        for i = 1, 8 do
            steps[i] = {
                pulseCount = i,
                ratchetCount = 1,
                gateType = gateTypes[2],
                gateLength = gateLengths[3],
                note = i,
                octave = octaves[3],
                probability = probabilities[1]
            }
        end
        t.steps = steps
    end

    return t
end

function voice:randomize(params)
    math.randomseed(util.time())
    for i = 1, #params do
        local key = params[i]
        for step = 1, 8 do
            if key == 'pulseCount' then
                self:setPulseCount(step, math.random(1, 8))
            end
            if key == 'note' then
                self:setNote(step, math.random(1, 8))
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
                self:setRatchetCount(step, math.random(1, 8))
            end
            if key == 'probability' then
                self:setProbability(step, probabilities[math.random(1, 4)])
            end
        end
    end

end

function voice:setLoop(start, stop)
    -- switch start / stop values if start > stop
    if start > stop then
        local temp = start
        start = stop
        stop = temp
    end

    self.loop.start = start or 1
    self.loop.stop = stop or 8
end

function voice:setPulseCount(step, pulseCount)
    self.steps[step].pulseCount = pulseCount
end

function voice:setRatchetCount(step, ratchetCount)
    self.steps[step].ratchetCount = ratchetCount
end

function voice:setGateType(step, gateType)
    self.steps[step].gateType = gateType
end

function voice:setGateLength(step, gateLength)
    self.steps[step].gateLength = gateLength
end

function voice:setNote(step, note)
    self.steps[step].note = note
end

function voice:setOctave(step, octave)
    self.steps[step].octave = octave
end

function voice:setProbability(step, probability)
    self.steps[step].probability = probability
end

function voice:setDivision(division)
    self.division = division
end

function voice:getGateTypes()
    return gateTypes
end

function voice:getGateLengths()
    return gateLengths
end

function voice:getProbabilities()
    return probabilities
end

function voice:getOctaves()
    return octaves
end

function voice:getDivisions()
    return divisions
end

function voice:getDivisionIndex()
    return tab.key(divisions, self.division)
end

function voice:setAll(param, value)
    for i = 1, 8 do
        self.steps[i][param] = value
    end
end

function voice:getPulse(stepIndex, pulseCount, scale, rootNote)
    local step = self.steps[stepIndex]

    if pulseCount > step.pulseCount then
        return nil
    end

    local first, last = pulseCount == 1, pulseCount >= step.pulseCount
    local midiNote = self:getMidiNote(step.note, scale, step.octave, rootNote)

    local pulse = {
        note = step.note,
        octave = step.octave,
        midiNote = midiNote,
        hz = self:getHz(midiNote),
        volts = self:getVolts(step.note, scale, step.octave, rootNote),
        noteName = self:getNoteName(midiNote),
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

    tab.print(pulse)

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
            return rest
        end
    end
end

function voice:getMidiNote(note, scale, octave, rootNote)
    local rootNoteInOctave = rootNote + (12 * octave)
    local midiScale = musicUtil.generate_scale_of_length(rootNoteInOctave, scale.name, 8)
    return midiScale[note]
end

function voice:getHz(midiNote)
    return musicUtil.note_num_to_freq(midiNote)
end

function voice:getNoteName(midiNote)
    return musicUtil.note_num_to_name(midiNote)
end

function voice:getVolts(note, scale, octave, rootNote)
    local voltsPerSemitone = 1/12
    local rootVolts = octave + (rootNote * voltsPerSemitone)
    local semitones = scale.intervals[note]
    return rootVolts + (semitones * voltsPerSemitone)
end

return voice
