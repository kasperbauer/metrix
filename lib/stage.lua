local stage = {}

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

function stage:new(args)
    local t = setmetatable({}, {
        __index = stage
    })

    args = args or {}

    t.pulseCount = args.pulseCount or 1
    t.ratchetCount = args.ratchetCount or 1
    t.gateType = args.gateType or gateTypes[2]
    t.gateLength = args.gateLength or gateLengths[1]
    t.pitch = args.pitch or 1
    t.octave = args.octave or 0
    t.probability = args.probability or probabilities[1]
    t.transpose = args.transpose or 0
    t.accumulatedPitch = args.accumulatedPitch or 1
    t.slide = math.random(0, 1) == 1
    t.accent = math.random(0, 1) == 1

    return t
end

function stage:setParam(paramName, value)
    self[paramName] = value

    if paramName == 'transpose' and value == 0 then
        self:resetPitch()
    end
end

function stage:toggleParam(paramName)
    self[paramName] = not self[paramName]
end

function stage:randomize(paramNames)
    for i, name in ipairs(paramNames) do
        if name == 'pulseCount' then
            self.pulseCount = math.lowerRandom(1, 8)
        end
        if name == 'pitch' then
            self.pitch = math.random(1, 8)
        end
        if name == 'octave' then
            self.octave = math.random(0, 3)
        end
        if name == 'gateType' then
            self.gateType = gateTypes[math.random(1, 4)]
        end
        if name == 'gateLength' then
            self.gateLength = gateLengths[math.random(1, 4)]
        end
        if name == 'ratchetCount' then
            self.ratchetCount = math.lowerRandom(1, 8, 4)
        end
        if name == 'probability' then
            self.probability = probabilities[math.random(1, 4)]
        end
        if name == 'transpose' then
            self.transpose = math.lowerRandom(0, 7, 4)
        end
    end
end

function stage:getGateTypes()
    return gateTypes
end

function stage:getGateLengths()
    return gateLengths
end

function stage:getProbabilities()
    return probabilities
end

function stage:resetPitch()
    self.accumulatedPitch = self.pitch
end

function stage:setAccumulatedPitch(pitch)
    self.accumulatedPitch = pitch
end

function stage:accumulatePitch(trackIndex)
    local pitch = self.accumulatedPitch + self.transpose
    local transposeLimit = params:get("transpose_limit_tr_" .. trackIndex)
    if (pitch > self.pitch + transposeLimit) then
        self:resetPitch()
    else
        self.accumulatedPitch = pitch
    end
end

return stage
