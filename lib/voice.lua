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
            pulses = {},
            gateType = gateTypes[2],
            note = i,
            octave = 0
        }

        for j = 1, 8 do
            steps[i].pulses[j] = false
        end

        for k = 1, i do
            steps[i].pulses[k] = true
        end
    end
    t.steps = steps

    return t
end

function Voice:setLoop(start, stop)
    self.loop.start = start or 1
    self.loop.stop = stop or 8
end

function Voice:setStepLength(step, length)
    pulses = self.steps[step].pulses
    for i = 1, 8 do
        if (i <= length) then
            pulses[i] = true
        else
            pulses[i] = false
        end
    end
    self.steps[step].pulses = pulses
end

function Voice:setGateType(step, gateType)
    self.steps[step].gateType = gateType or 'single'
end

function Voice:getGateTypes()
    return gateTypes
end

return Voice
