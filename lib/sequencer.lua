lattice = require('lattice')
track = include('lib/track')

local DEBUG = false
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

function sequencer:new(onPulseAdvance)
    local t = setmetatable({}, {
        __index = sequencer
    })

    t.lattice = lattice:new()
    t.lattice.ppqn = 192
    t.tracks = {}
    t.currentTrack = 0
    t.probabilities = {}
    t.stepIndex = {}
    t.pulseCount = {}
    t.activePulse = {}
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

function sequencer:addTracks(trackCount)
    for i = 1, trackCount do
        self:addTrack()
    end
    self.currentTrack = 1
end

function sequencer:addTrack(args)
    local track = track:new(args)
    table.insert(self.tracks, track)
    local trackIndex = #self.tracks
    self:addPattern(track.division, trackIndex)
    self:resetStepIndex(trackIndex)
    self:resetPulseCount(trackIndex)
    self.currentTrack = trackIndex
end

function sequencer:resetTracks()
    self.tracks = {}
    self.patterns = {}
    self.events = {}
    self.lattice = lattice:new()
end

function sequencer:getCurrentTrack()
    return self.tracks[self.currentTrack]
end

function sequencer:getTrack(trackIndex)
    return self.tracks[trackIndex]
end

function sequencer:changeTrack(trackIndex)
    self.currentTrack = trackIndex
end

function sequencer:addPattern(division, trackIndex)
    local pattern = self.lattice:new_pattern({
        action = function()
            self:advanceToNextPulse(trackIndex)
            self.onPulseAdvance()
        end,
        division = division
    })
    table.insert(self.patterns, pattern)
end

function sequencer:getPattern(patternIndex)
    return self.patterns[patternIndex]
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
        self.events = {}
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
    self:refreshProbabilities()
    for i = 1, #self.tracks do
        self:setActivePulse(i, 1, 1)
        self:resetStepIndex(i)
        self:resetPulseCount(i)
    end
    -- TODO: activate on next norns release
    -- self.lattice.hard_restart()
end

function sequencer:refreshProbabilities()
    for trackIndex = 1, #self.tracks do
        local probabilities = {}
        for i = 1, 8 do
            table.insert(probabilities, math.random(1, 100) / 100)
        end
        self.probabilities[trackIndex] = probabilities
    end

    local prob = self.probabilities[1]
end

function sequencer:resetStepIndex(trackIndex)
    local track = self:getTrack(trackIndex)
    if (track.playbackOrder == 'forward') then
        self.stepIndex[trackIndex] = track.loop.start
    elseif (track.playbackOrder == 'reverse') then
        self.stepIndex[trackIndex] = track.loop.stop
    elseif (track.playbackOrder == 'alternate') then
        if self.alternatePlaybackOrder == 'forward' then
            self.stepIndex[trackIndex] = track.loop.start
        elseif self.alternatePlaybackOrder == 'reverse' then
            self.stepIndex[trackIndex] = track.loop.stop
        end
    end
end

function sequencer:resetPulseCount(trackIndex)
    local track = self:getTrack(trackIndex)
    self.pulseCount[trackIndex] = 1
end

function sequencer:advanceToNextPulse(trackIndex)
    self:setActivePulse(trackIndex)

    local track = self:getTrack(trackIndex)
    local stepIndex = self.stepIndex[trackIndex]
    local pulseCount = self.pulseCount[trackIndex]
    local pulse = track:getPulse(stepIndex, pulseCount, self.scale, self.rootNote)

    if pulse == nil or stepIndex < track.loop.start or stepIndex > track.loop.stop then
        self:prepareNextPulse(trackIndex, pulse)
        self:advanceToNextPulse(trackIndex)
        return
    end

    local pulseProbability = pulse.probability or 1
    local stepProbability = self.probabilities[trackIndex][stepIndex]
    local skip = pulseProbability < stepProbability

    if not skip then
        self:playNote(trackIndex, pulse)
    end

    self:prepareNextPulse(trackIndex, pulse)
end

function sequencer:prepareNextPulse(trackIndex, pulse)
    local track = self:getTrack(trackIndex)

    if pulse and not pulse.last then
        self.pulseCount[trackIndex] = self.pulseCount[trackIndex] + 1
    elseif track.loop.start == track.loop.stop then
        self.stepIndex[trackIndex] = track.loop.start
        self:resetPulseCount(trackIndex)
    else
        self:resetPulseCount(trackIndex)

        if track.playbackOrder == 'forward' then
            self:advanceToNextStep(trackIndex, 1)

        elseif track.playbackOrder == 'reverse' then
            self:advanceToNextStep(trackIndex, -1)

        elseif track.playbackOrder == 'alternate' then
            local stepIndex = self.stepIndex[trackIndex]

            if stepIndex == track.loop.stop then
                self.alternatePlaybackOrder = 'reverse'
            elseif stepIndex == track.loop.start then
                self.alternatePlaybackOrder = 'forward'
            end

            if self.alternatePlaybackOrder == 'forward' then
                self:advanceToNextStep(trackIndex, 1)
            elseif self.alternatePlaybackOrder == 'reverse' then
                self:advanceToNextStep(trackIndex, -1)
            end

        elseif track.playbackOrder == 'random' then
            self:advanceToNextStep(trackIndex)
        end
    end
end

function sequencer:advanceToNextStep(trackIndex, amount)
    self:refreshProbabilities()

    local track = self:getTrack(trackIndex)

    if track.playbackOrder == 'random' then
        local randomStep = math.random(track.loop.start, track.loop.stop)
        self.stepIndex[trackIndex] = randomStep;
    else
        self.stepIndex[trackIndex] = self.stepIndex[trackIndex] + amount;
    end

    if self.stepIndex[trackIndex] > track.loop.stop then
        self:resetStepIndex(trackIndex)
    elseif self.stepIndex[trackIndex] < track.loop.start then
        self:resetStepIndex(trackIndex)
    end
end

function sequencer:setActivePulse(trackIndex, x, y)
    x = x or self.stepIndex[trackIndex]
    y = y or self.pulseCount[trackIndex]

    self.activePulse[trackIndex] = {
        x = x,
        y = y
    }
end

function sequencer:getScales()
    return scales
end

function sequencer:setScale(scaleIndex)
    self.scale = scales[scaleIndex]
end

function sequencer:playNote(trackIndex, pulse)
    if pulse.gateType == 'void' then
        return
    end

    local track = self:getTrack(trackIndex)

    if pulse.gateType ~= 'rest' and not track.mute then
        local transport = self.lattice.transport

        if pulse.ratchetCount > 1 then
            self:addRatchets(trackIndex, pulse, transport)
        else
            local ppqnPerWhole = self.lattice.ppqn * 4
            local division = self.tracks[trackIndex].division
            local ppqnPulseLength = pulse.gateLength * ppqnPerWhole * division * pulse.duration
            local ppqnNoteOff = math.ceil(transport + ppqnPulseLength) - 1

            self:addEvent('noteOff', pulse, trackIndex, ppqnNoteOff)
            self:noteOn(trackIndex, pulse)
        end
    end

end

function sequencer:addRatchets(trackIndex, pulse, transport)
    local ratchetCount = pulse.ratchetCount
    local ppqnPerWhole = self.lattice.ppqn * 4
    local division = self.tracks[trackIndex].division
    local ppqnRatchetLength = ppqnPerWhole * division * pulse.duration / ratchetCount
    local ppqnPulseLength = ppqnPerWhole * division * pulse.duration
    local ppqnGateLength = pulse.gateLength * ppqnPulseLength

    -- play first ratchet instantly
    local ppqnNoteOff = math.ceil(transport + math.min(ppqnRatchetLength, ppqnGateLength)) - 1
    self:addEvent('noteOff', pulse, trackIndex, ppqnNoteOff)
    self:noteOn(trackIndex, pulse)

    for i = 2, ratchetCount do
        local ppqnOn = math.ceil(transport + ((i - 1) * ppqnRatchetLength))
        local ppqnOff = math.ceil(ppqnOn + math.min(ppqnRatchetLength, ppqnGateLength)) - 1

        self:addEvent('noteOn', pulse, trackIndex, ppqnOn)
        self:addEvent('noteOff', pulse, trackIndex, ppqnOff)
    end
end

function sequencer:addEvent(type, pulse, trackIndex, ppqn)
    local event = {
        type = type,
        trackIndex = trackIndex,
        pulse = pulse
    }

    if self.events[ppqn] == nil then
        self.events[ppqn] = {}
    end
    table.insert(self.events[ppqn], event)
end

function sequencer:noteOn(trackIndex, pulse)
    if DEBUG then
        print(self.lattice.transport, trackIndex, 'noteOn', pulse.midiNote, pulse.noteName, 127)
    end

    m:note_on(pulse.midiNote, 127, trackIndex)

    -- trigger on outputs 1 and 3, pitch on outputs 2 and 4
    crow.output[(trackIndex * 2) - 1].volts = 5
    crow.output[trackIndex * 2].volts = pulse.volts

    engine.noteOn(trackIndex, pulse.hz, 100)
end

function sequencer:handleEvents(transport)
    if self.events[transport] == nil then
        return
    end

    local events = self.events[transport]
    for k, event in pairs(events) do
        local pulse, type = event.pulse, event.type

        if type == 'noteOff' then
            self:noteOff(event.trackIndex, pulse)
        elseif type == 'noteOn' then
            self:noteOn(event.trackIndex, pulse)
        end

        if DEBUG then
            print(self.lattice.transport, event.trackIndex, type, pulse.midiNote, pulse.noteName, 127)
        end
    end
    self.events[transport] = nil
end

function sequencer:noteOff(trackIndex, pulse, transport)
    m:note_off(pulse.midiNote, 127, trackIndex)
    engine.noteOff(trackIndex)
    crow.output[(trackIndex * 2) - 1].volts = 0
    if DEBUG then
        print(transport or self.lattice.transport, trackIndex, 'noteOff', pulse.midiNote, pulse.noteName, 127)
    end
end

function sequencer:noteOffAll()
    for k1, events in pairs(self.events) do
        for k2, event in pairs(events) do
            if event.type == 'noteOff' then
                self:noteOff(event.trackIndex, event.pulse, k1)
            end
            self.events[k1] = nil
        end
    end

    engine.noteOffAll()
end

return sequencer
