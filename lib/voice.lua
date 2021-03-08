local Voice = {}

function Voice:new(loop)
  local t = setmetatable({}, { __index = Voice })

    t.loop = loop or {
        start = 1,
        stop = 8
    }

    return t
end

function Voice:setLoop(start, stop)
    self.loop.start = start or 1
    self.loop.stop = stop or 8
end

return Voice