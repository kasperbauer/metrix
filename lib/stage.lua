local stage = {}

local gateTypes = {'hold', 'multiple', 'single', 'rest'}
local gateLengths = {1, 0.75, 0.5, 0.1}
local probabilities = {1, 0.75, 0.5, 0.25}
local transpositionDirections = {'up', 'down'}

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
    t.slide = args.slide or false
    t.accent = args.accent or false

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
            self.octave = math.lowerRandom(0, 3)
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
        if name == 'slide' then
            self.slide = math.random() > 0.5
        end
        if name == 'accent' then
            self.accent = math.random() > 0.5
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

function stage:accumulatePitch(trackIndex)
    local direction = self:getAccumulationDirection(trackIndex)
    local pitch = self.accumulatedPitch + self.transpose
    if direction == "down" then
        pitch = self.accumulatedPitch - self.transpose
    end

    local transposeLimit = params:get("transpose_limit_tr_" .. trackIndex)
    if pitch > self.pitch + transposeLimit or pitch < self.pitch - transposeLimit then
        self:resetPitch()
    else
        self.accumulatedPitch = pitch
    end
end

function stage:getTranspositionDirections()
    return transpositionDirections;
end

function stage:getAccumulationDirection(trackIndex)
    local directionIndex = params:get("transpose_direction_tr_" .. trackIndex)
    return transpositionDirections[directionIndex]
end

function stage:getGateTypeSymbol()
    local short = ':'

    if self.gateType == 'single' then
        short = '.'
    elseif self.gateType == 'hold' then
        short = '|'
    elseif self.gateType == 'rest' then
        short = '-'
    end

    return short;
end

return stage
