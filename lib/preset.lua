local preset = {}
local voice = include('lib/voice')

function preset:new()
    local t = setmetatable({}, {
        __index = preset
    })

    t.path = _path.code .. 'polix/presets/'
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

return preset
