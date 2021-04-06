lattice = include('lib/lattice')
track = include('lib/track')

local DEBUG = false

local sequencer = {}
local transposeTriggers = {"stage", "pulse", "ratchet"}
local crowGateTypes = {"gate", "trigger", "envelope"}

function sequencer:new(onPulseAdvance)
    local t = setmetatable({}, {
        __index = sequencer
    })

    t.lattice = lattice:new()
    t.tracks = {}
    t.currentTrack = 0
    t.probabilities = {}
    t.stageIndex = {}
    t.pulseCount = {}
    t.activePulseCoords = {}
    t.activePulse = {}
    t.patterns = {}
    t.eventPattern = nil
    t.events = {}

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
    self:resetStageIndex(trackIndex)
    self:resetPulseCount(trackIndex)
    self.currentTrack = trackIndex
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

function sequencer:swapTrack(trackIndex, track)
    self.tracks[trackIndex] = track
    self:setDivision(trackIndex, track.division)
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

function sequencer:toggle()
    if self.lattice.enabled then
        self:stop()
    else
        self:start()
    end
end

function sequencer:start()
    self:addEventPattern()
    self:refreshProbabilities()

    if self.lattice.transport == 0 then
        m:start()
    else
        m:continue()
    end
    
    self.lattice:start()
end

function sequencer:stop()
    self.lattice:stop()
    m:stop()
    self:noteOffAll()
    self.events = {}
end

function sequencer:reset()
    self:refreshProbabilities()
    self:noteOffAll()

    for trackIndex = 1, #self.tracks do
        self:resetStageIndex(trackIndex)
        self:resetPulseCount(trackIndex)
        self:setActivePulseCoords(trackIndex)
        self.tracks[trackIndex]:resetPitches()
    end

    if self.lattice.enabled then
        self.lattice:hard_restart()
    else
        self.lattice:reset()
    end
end

function sequencer:refreshProbability(trackIndex, stageIndex)
    if self.probabilities[trackIndex] == nil then
        self.probabilities[trackIndex] = {}
    end

    self.probabilities[trackIndex][stageIndex] = math.random()
end

function sequencer:refreshProbabilities()
    for trackIndex = 1, #self.tracks do
        for stageIndex = 1, 8 do
            self:refreshProbability(trackIndex, stageIndex)
        end
    end
end

function sequencer:resetStageIndex(trackIndex)
    local track = self:getTrack(trackIndex)
    if track.playbackOrder == 'forward' then
        self.stageIndex[trackIndex] = track.loop.start
    elseif track.playbackOrder == 'reverse' then
        self.stageIndex[trackIndex] = track.loop.stop
    elseif track.playbackOrder == 'alternate' then
        self.stageIndex[trackIndex] = track.loop.start
    end
end

function sequencer:resetPulseCount(trackIndex)
    local track = self:getTrack(trackIndex)
    self.pulseCount[trackIndex] = 1
end

function sequencer:advanceToNextPulse(trackIndex)
    self:setActivePulseCoords(trackIndex)

    local track = self:getTrack(trackIndex)
    local stageIndex = self.stageIndex[trackIndex]
    local pulseCount = self.pulseCount[trackIndex]
    local pulse = track:getPulse(trackIndex, stageIndex, pulseCount)

    if pulse == nil or stageIndex < track.loop.start or stageIndex > track.loop.stop then
        self:prepareNextPulse(trackIndex, pulse)
        self:advanceToNextPulse(trackIndex)
        return
    end

    local pulseProbability = pulse.probability or 1
    local stageProbability = self.probabilities[trackIndex][stageIndex]
    local skip = pulseProbability < stageProbability

    if not skip then
        self:playNote(trackIndex, pulse)
    end

    self.activePulse[trackIndex] = skip and nil or pulse
    self:prepareNextPulse(trackIndex, pulse)

    local transposeTrigger = self:getTransposeTrigger(trackIndex);
    if transposeTrigger == 'pulse' or transposeTrigger == 'ratchet' then
        local stage = track:getStageWithIndex(stageIndex)
        stage:accumulatePitch(trackIndex)
    end
end

function sequencer:prepareNextPulse(trackIndex, pulse)
    local track = self:getTrack(trackIndex)
    local stageIndex = self.stageIndex[trackIndex];

    if pulse and not pulse.last then
        self.pulseCount[trackIndex] = self.pulseCount[trackIndex] + 1
    elseif track.loop.start == track.loop.stop then
        self.stageIndex[trackIndex] = track.loop.start
        self:resetPulseCount(trackIndex)
    elseif (pulse and pulse.last) or not pulse then
        self:resetPulseCount(trackIndex)

        if track.playbackOrder == 'forward' then
            self:advanceToNextStage(trackIndex, 1)

        elseif track.playbackOrder == 'reverse' then
            self:advanceToNextStage(trackIndex, -1)

        elseif track.playbackOrder == 'alternate' then
            if stageIndex == track.loop.stop then
                track.alternatePlaybackOrder = 'reverse'
            elseif stageIndex == track.loop.start then
                track.alternatePlaybackOrder = 'forward'
            end

            if track.alternatePlaybackOrder == 'forward' then
                self:advanceToNextStage(trackIndex, 1)
            elseif track.alternatePlaybackOrder == 'reverse' then
                self:advanceToNextStage(trackIndex, -1)
            end

        elseif track.playbackOrder == 'random' then
            self:advanceToNextStage(trackIndex)
        end

        local transposeTrigger = self:getTransposeTrigger(trackIndex);
        if transposeTrigger == 'stage' then
            local stage = track:getStageWithIndex(stageIndex)
            stage:accumulatePitch(trackIndex)
        end
    end
end

function sequencer:advanceToNextStage(trackIndex, amount)
    local track = self:getTrack(trackIndex)

    if track.playbackOrder == 'random' then
        local randomStage = math.random(track.loop.start, track.loop.stop)
        self.stageIndex[trackIndex] = randomStage;
    else
        self.stageIndex[trackIndex] = self.stageIndex[trackIndex] + amount;
    end

    if self.stageIndex[trackIndex] > track.loop.stop then
        self:resetStageIndex(trackIndex)
    elseif self.stageIndex[trackIndex] < track.loop.start then
        self:resetStageIndex(trackIndex)
    end

    local stageIndex = self.stageIndex[trackIndex]
    self:refreshProbability(trackIndex, stageIndex)
end

function sequencer:getTransposeTriggers()
    return transposeTriggers
end

function sequencer:getTransposeTrigger(trackIndex)
    local triggerIndex = params:get("transpose_trigger_tr_" .. trackIndex)
    local triggers = self:getTransposeTriggers()
    return triggers[triggerIndex];
end

function sequencer:setActivePulseCoords(trackIndex, x, y)
    x = x or self.stageIndex[trackIndex]
    y = y or self.pulseCount[trackIndex]

    self.activePulseCoords[trackIndex] = {
        x = x,
        y = y
    }
end

function sequencer:playNote(trackIndex, pulse)
    if pulse.gateType == 'void' then
        return
    end

    local track = self:getTrack(trackIndex)

    if pulse.gateType ~= 'rest' and not self:isMuted(trackIndex) then
        local transport = self.lattice.transport

        if pulse.ratchetCount > 1 then
            self:addRatchets(trackIndex, pulse, transport)
        else
            local ppqnPerWhole = self.lattice.ppqn * 4
            local division = self.tracks[trackIndex].division
            local ppqnPulseLength = pulse.gateLength * ppqnPerWhole * division * pulse.duration
            local ppqnNoteOff = transport + ppqnPulseLength

            self:addEvent('noteOff', pulse, trackIndex, ppqnNoteOff)
            self:noteOn(trackIndex, pulse)
        end
    end

end

function sequencer:addRatchets(trackIndex, pulse, transport)
    local ratchetCount = pulse.ratchetCount
    local ppqnPerWhole = self.lattice.ppqn * 4
    local track = self.tracks[trackIndex]
    local ppqnRatchetLength = ppqnPerWhole * track.division * pulse.duration / ratchetCount
    local ppqnPulseLength = ppqnPerWhole * track.division * pulse.duration
    local ppqnGateLength = pulse.gateLength * ppqnPulseLength
    local ppqnNoteLength = math.min(ppqnRatchetLength, ppqnGateLength);
    local transposeTrigger = self:getTransposeTrigger(trackIndex);
    local stageIndex = self.stageIndex[trackIndex]
    local stage = track:getStageWithIndex(stageIndex)

    -- play first ratchet instantly
    local ppqnNoteOff = transport + ppqnNoteLength
    self:addEvent('noteOff', pulse, trackIndex, ppqnNoteOff)
    self:noteOn(trackIndex, pulse)

    if transposeTrigger == 'ratchet' then
        stage:accumulatePitch(trackIndex)
    end

    for i = 2, ratchetCount do
        pulse = track:getPulse(trackIndex, stageIndex, pulse.pulseCount)
        local ppqnOn = math.ceil(transport + ((i - 1) * ppqnRatchetLength))
        local ppqnOff = math.ceil(ppqnOn + ppqnNoteLength)

        self:addEvent('noteOn', pulse, trackIndex, ppqnOn)
        self:addEvent('noteOff', pulse, trackIndex, ppqnOff)

        if transposeTrigger == 'ratchet' then
            stage:accumulatePitch(trackIndex)
        end
    end
end

function sequencer:addEvent(type, pulse, trackIndex, ppqn)
    local event = {
        type = type,
        trackIndex = trackIndex,
        pulse = pulse
    }

    -- offset for not interfering with next noteOn event
    if type == 'noteOff' then
        ppqn = ppqn - 2
    end

    ppqn = math.floor(ppqn)

    if self.events[ppqn] == nil then
        self.events[ppqn] = {}
    end

    table.insert(self.events[ppqn], event)
end

function sequencer:noteOn(trackIndex, pulse)
    if self:shouldSendToOutput(trackIndex, 'midi') then
        local midiCh = params:get('midi_ch_tr_' .. trackIndex)
        m:note_on(pulse.midiNote, 100, midiCh)
    end

    if self:shouldSendToOutput(trackIndex, 'crow') then
        -- output 2/4: pitch
        crow.output[trackIndex * 2].slew = pulse.slideAmount
        crow.output[trackIndex * 2].volts = pulse.volts

        -- output 1/3: gates / triggers
        -- https://vcvrack.com/manual/VoltageStandards
        local crowGateTypeIndex = params:get("crow_gate_type_tr_" .. trackIndex)

        if crowGateTypeIndex == 1 then -- gate
            crow.output[(trackIndex * 2) - 1].volts = 10
        elseif crowGateTypeIndex == 2 then -- trigger
            crow.output[(trackIndex * 2) - 1]("{to(10,0),to(0,0.002)}")
        elseif crowGateTypeIndex == 3 then -- envelope
            local a, s, r = params:get("crow_attack_tr_" .. trackIndex), params:get("crow_sustain_tr_" .. trackIndex),
                params:get("crow_release_tr_" .. trackIndex)
            crow.output[(trackIndex * 2) - 1]("{to(5," .. a .. "),to(5," .. s .. "),to(0," .. r .. ")}")
        end
    end

    if self:shouldSendToOutput(trackIndex, 'audio') then
        engine.glide(pulse.slideAmount)
        engine.noteOn(trackIndex, pulse.hz, 1)
    end

    if DEBUG then
        print(self.lattice.transport, 'noteOn', pulse.midiNote, pulse.noteName)
    end
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
    end
    self.events[transport] = nil
end

function sequencer:noteOff(trackIndex, pulse, transport)
    local midiCh = params:get('midi_ch_tr_' .. trackIndex)
    if self:shouldSendToOutput(trackIndex, 'midi') then
        m:note_off(pulse.midiNote, 127, midiCh)
    end

    if self:shouldSendToOutput(trackIndex, 'crow') then
        local crowGateTypeIndex = params:get("crow_gate_type_tr_" .. trackIndex)
        if crowGateTypeIndex == 1 then
            crow.output[(trackIndex * 2) - 1].volts = 0
        end
    end

    if self:shouldSendToOutput(trackIndex, 'audio') then
        engine.noteOff(trackIndex)
    end

    if DEBUG then
        print(transport or self.lattice.transport, 'noteOff', pulse.midiNote, pulse.noteName)
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

function sequencer:toggleTrack(trackIndex)
    if self:isMuted(trackIndex) then
        params:set("mute_tr_" .. trackIndex, 0)
    else
        params:set("mute_tr_" .. trackIndex, 1)
    end
end

function sequencer:getCrowGateTypes()
    return crowGateTypes
end

function sequencer:getCrowGateType(index)
    return crowGateTypes[index]
end

function sequencer:shouldSendToOutput(trackIndex, type) -- type: audio, midi, crow
    return params:get("output_" .. type .. "_tr_" .. trackIndex) == 1
end

function sequencer:isMuted(trackIndex)
    return params:get("mute_tr_" .. trackIndex) == 1
end

function sequencer:setDivision(trackIndex, division)
    local track = self:getTrack(trackIndex)
    local pattern = self:getPattern(trackIndex)
    track:setDivision(division)
    pattern:set_division(division)

    if not self.lattice.enabled then
        self.lattice:reset()
    end
end

return sequencer
