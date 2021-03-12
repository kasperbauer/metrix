lattice = require('lattice')
voice = include('lib/voice')

local DEBUG = true
local DEBUG_MUTE_VOICE = 2

m = midi.connect()

local sequencer = {}

local scales = {};
for i = 1, #musicUtil.SCALES do
    local scale = musicUtil.SCALES[i]
    -- get all scales with max 8 notes
    if #scale.intervals <= 8 then
        table.insert(scales, scale)
    end
end

local directions = {
    [1] = 'forward',
    [2] = 'reverse',
    [3] = 'alternate',
    [4] = 'random'
}

function sequencer:new(onPulseAdvance)
    local t = setmetatable({}, {
        __index = sequencer
    })

    t.lattice = lattice:new()
    t.lattice.ppqn = 192
    t.voices = {}
    t.probabilities = {}
    t.stepIndex = {}
    t.pulseCount = {}
    t.activePulse = {}
    t.direction = directions[1]
    t.alternateDirection = 'forward'
    t.patterns = {}
    t.noteOffPattern = nil
    t.events = {}

    -- 0 equals C
    t.rootNote = 0

    -- 1 equals major
    t.scale = scales[1]

    t.onPulseAdvance = onPulseAdvance or function()
    end

    return t
end

function sequencer:addVoices(voiceCount)
    for i = 1, voiceCount do
        self:addVoice()
    end
end

function sequencer:addVoice(args)
    local voice = voice:new(args)
    table.insert(self.voices, voice)
    local voiceIndex = #self.voices
    self:addPattern(voice.division, voiceIndex)
    self:resetStepIndex(voiceIndex)
    self:resetPulseCount(voiceIndex)
end

function sequencer:resetVoices()
    self.voices = {}
    self.patterns = {}
    self.events = {}
    self.lattice = lattice:new()
end

function sequencer:getVoice(voiceIndex)
    return self.voices[voiceIndex]
end

function sequencer:addPattern(division, voiceIndex)
    local pattern = self.lattice:new_pattern({
        action = function()
            self:advanceToNextPulse(voiceIndex)
            self.onPulseAdvance()
        end,
        division = division
    })
    table.insert(self.patterns, pattern)
end

function sequencer:addEventPattern()
    if self.eventPattern then
        return
    end

    self.eventPattern = self.lattice:new_pattern({
        action = function(t)
            self:handleEvents(t)
        end,
        division = 1 / self.lattice.ppqn / 4 -- do every ppqn
    })
end

function sequencer:playPause()
    self:addEventPattern()

    if DEBUG then
        local pattern = self.patterns[DEBUG_MUTE_VOICE]
        pattern.enabled = false
    end

    if self.lattice.enabled then
        self.lattice:stop()
        m:stop()
        self:noteOffAll()
    else
        self:refreshProbabilities()
        if self.lattice.transport == 0 then
            m:start()
        else
            m:continue()
        end
        self.lattice:start()
    end
end

function sequencer:reset()
    print('EVENTS')
    tab.print(self.events)

    self:refreshProbabilities()
    for i = 1, #self.voices do
        self:setActivePulse(i, 1, 1)
        self:resetStepIndex(i)
        self:resetPulseCount(i)
    end
    -- TODO: activate on next norns release
    -- self.lattice.hard_restart()
end

function sequencer:refreshProbabilities()
    math.randomseed(self.lattice.transport)

    for voiceIndex = 1, #self.voices do
        local probabilities = {}
        for i = 1, 8 do
            table.insert(probabilities, math.random(1, 100) / 100)
        end
        self.probabilities[voiceIndex] = probabilities
    end

    local prob = self.probabilities[1]
end

function sequencer:resetStepIndex(voiceIndex)
    local voice = self:getVoice(voiceIndex)
    if (self.direction == 'forward') then
        self.stepIndex[voiceIndex] = voice.loop.start
    elseif (self.direction == 'reverse') then
        self.stepIndex[voiceIndex] = voice.loop.stop
    elseif (self.direction == 'alternate') then
        if self.alternateDirection == 'forward' then
            self.stepIndex[voiceIndex] = voice.loop.start
        elseif self.alternateDirection == 'forward' then
            self.stepIndex[voiceIndex] = voice.loop.stop
        end
    end
end

function sequencer:resetPulseCount(voiceIndex)
    local voice = self:getVoice(voiceIndex)
    self.pulseCount[voiceIndex] = 1
end

function sequencer:advanceToNextPulse(voiceIndex)
    self:setActivePulse(voiceIndex)

    local voice = self:getVoice(voiceIndex)
    local stepIndex = self.stepIndex[voiceIndex]
    local pulseCount = self.pulseCount[voiceIndex]
    local pulse = voice:getPulse(stepIndex, pulseCount, self.scale, self.rootNote)

    if pulse == nil or stepIndex < voice.loop.start or stepIndex > voice.loop.stop then
        self:prepareNextPulse(voiceIndex, pulse)
        self:advanceToNextPulse(voiceIndex)
        return
    end

    local pulseProbability = pulse.probability or 1
    local stepProbability = self.probabilities[voiceIndex][stepIndex]
    local skip = pulseProbability < stepProbability

    if not skip then
        self:playNote(voiceIndex, pulse)
    end

    self:prepareNextPulse(voiceIndex, pulse)
end

function sequencer:prepareNextPulse(voiceIndex, pulse)
    local voice = self:getVoice(voiceIndex)

    if pulse and not pulse.last then
        self.pulseCount[voiceIndex] = self.pulseCount[voiceIndex] + 1
    elseif voice.loop.start == voice.loop.stop then
        self.stepIndex[voiceIndex] = voice.loop.start
        self:resetPulseCount(voiceIndex)
    else
        self:resetPulseCount(voiceIndex)

        if self.direction == 'forward' then
            self:advanceToNextStep(voiceIndex, 1)

        elseif self.direction == 'reverse' then
            self:advanceToNextStep(voiceIndex, -1)

        elseif self.direction == 'alternate' then
            local stepIndex = self.stepIndex[voiceIndex]

            if stepIndex == voice.loop.stop then
                self.alternateDirection = 'reverse'
            elseif stepIndex == voice.loop.start then
                self.alternateDirection = 'forward'
            end

            if self.alternateDirection == 'forward' then
                self:advanceToNextStep(voiceIndex, 1)
            elseif self.alternateDirection == 'reverse' then
                self:advanceToNextStep(voiceIndex, -1)
            end

        elseif self.direction == 'random' then
            self:advanceToNextStep(voiceIndex)
        end
    end
end

function sequencer:advanceToNextStep(voiceIndex, amount)
    self:refreshProbabilities()

    local voice = self:getVoice(voiceIndex)

    if self.direction == 'random' then
        local randomStep = math.random(voice.loop.start, voice.loop.stop)
        self.stepIndex[voiceIndex] = randomStep;
    else
        self.stepIndex[voiceIndex] = self.stepIndex[voiceIndex] + amount;
    end

    if self.stepIndex[voiceIndex] > voice.loop.stop then
        self:resetStepIndex(voiceIndex)
    elseif self.stepIndex[voiceIndex] < voice.loop.start then
        self:resetStepIndex(voiceIndex)
    end
end

function sequencer:setActivePulse(voiceIndex, x, y)
    x = x or self.stepIndex[voiceIndex]
    y = y or self.pulseCount[voiceIndex]

    self.activePulse[voiceIndex] = {
        x = x,
        y = y
    }
end

function sequencer:getDirections()
    return directions
end

function sequencer:setDirection(direction)
    self.direction = direction
end

function sequencer:getScales()
    return scales
end

function sequencer:setScale(scaleIndex)
    self.scale = scales[scaleIndex]
end

function sequencer:playNote(voiceIndex, pulse)
    if pulse.gateType == 'void' then
        return
    end

    if pulse.gateType ~= 'rest' then
        self:addEvent('noteOff', pulse, voiceIndex, self.lattice.transport)
        self:noteOn(voiceIndex, pulse)
    end

end

function sequencer:addEvent(type, pulse, voiceIndex, ppqnNow)
    local ppqnPerWhole = self.lattice.ppqn * 4
    local division = self.voices[voiceIndex].division
    local ppqnEventLength = pulse.gateLength * ppqnPerWhole * division * pulse.duration
    local ppqnEvent = math.ceil(ppqnNow + ppqnEventLength) - 1

    local event = {
        type = type,
        voiceIndex = voiceIndex,
        pulse = pulse
    }

    if self.events[ppqnEvent] == nil then
        self.events[ppqnEvent] = {}
    end
    table.insert(self.events[ppqnEvent], event)
end

function sequencer:noteOn(voiceIndex, pulse)
    if DEBUG then
        print(self.lattice.transport, voiceIndex, 'noteOn', pulse.midiNote, pulse.noteName, 127)
    end

    m:note_on(pulse.midiNote, 127, voiceIndex)

    -- trigger on outputs 1 and 3, pitch on outputs 2 and 4
    crow.output[(voiceIndex * 2) - 1].action = "{ to(5,0), to(0,0.005) }"
    crow.output[voiceIndex * 2].volts = pulse.volts

    engine.noteOn(voiceIndex, pulse.hz, 100)
end

function sequencer:handleEvents(transport)
    if self.events[transport] == nil then
        return
    end

    local events = self.events[transport]
    for k, event in pairs(events) do
        local pulse, type = event.pulse, event.type

        if (type == 'noteOff') then
            self:noteOff(pulse, event.voiceIndex)
        end

        if DEBUG then
            print(self.lattice.transport, event.voiceIndex, type, pulse.midiNote, pulse.noteName, 127)
        end
    end
    self.events[transport] = nil
end

function sequencer:noteOff(pulse, voiceIndex, transport)
    m:note_off(pulse.midiNote, 127, voiceIndex)
    engine.noteOff(voiceIndex)

    if DEBUG then
        print(transport or self.lattice.transport, voiceIndex, 'noteOff', pulse.midiNote, pulse.noteName, 127)
    end
end

function sequencer:noteOffAll()
    tab.print(self.events)
    for k1, events in pairs(self.events) do
        for k2, event in pairs(events) do
            if event.type == 'noteOff' then
                self:noteOff(event.pulse, event.voiceIndex, k1)
            end
            self.events[k1] = nil
        end
    end

    engine.noteOffAll()
end

return sequencer
