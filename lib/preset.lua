local preset = {}
local voice = include('lib/voice')

function preset:new()
    local t = setmetatable({}, {
        __index = preset
    })

    t.path = _path.code .. 'metrix/presets/'
    util.make_dir(t.path)

    return t
end

function preset:load(id)
    local data = tab.load(self.path .. id)

    local voices = {}
    for i = 1, #data.voices do
        local voice = voice:new(data.voices[i])
        table.insert(voices, voice)
    end

    return {
        voices = voices,
        direction = data.direction
    };
end

function preset:save(id, data)
    tab.save(data, self.path .. id)
end

function preset:exists(id)
    return util.file_exists(self.path .. id)
end

function preset:delete(id)
    if self:exists(id) then
        os.remove(self.path .. id)
    end
end

return preset
