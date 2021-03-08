local Voice = {}

local gateTypes = {
    [1] = 'hold',
    [2] = 'multiple',
    [3] = 'single',
    [4] = 'rest'
}

function Voice:new(args)
    local t = setmetatable({}, {
        __index = Voice
    })

    t.loop = args.loop or {
        start = 1,
        stop = 8
    }

    local steps = {};
    for i = 1, 8 do
        steps[i] = {
            pulses = i,
            ratchets = 1,
            gateType = gateTypes[2],
            note = i,
            octave = 0
        }
    end
    t.steps = steps

    return t
end

function Voice:setLoop(start, stop)
    self.loop.start = start or 1
    self.loop.stop = stop or 8
end

function Voice:setPulses(step, pulseCount)
    self.steps[step].pulses = pulseCount
end

function Voice:setGateType(step, gateType)
    self.steps[step].gateType = gateType
end

function Voice:setNote(step, note)
    self.steps[step].note = note
end

function Voice:setOctave(step, octave)
    self.steps[step].octave = octave
end

return Voice
