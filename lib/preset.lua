local preset = {}
local voice = include('lib/voice')

function preset.load(presetIndex)
    local file = assert(io.open(_path.code .. 'polix/presets/' .. presetIndex .. '.json', 'r'))
    local jsonContent = file:read('*all')
    file:close()

    local data = json.parse(jsonContent)
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

function preset.save(presetIndex, data)
    local jsonContent = json.stringify(data)

    local file = assert(io.open(_path.code .. 'polix/presets/' .. presetIndex .. '.json', 'w'))
    file:write(jsonContent)
    file:close()
end

function preset.readDirectory()
    local dir = io.popen('ls ' .. _path.code .. 'polix/presets/')
    local existingPresets = {}
    for name in dir:lines() do
        local presetNumber = name:gsub(".json", "")
        table.insert(existingPresets, tonumber(presetNumber))
    end

    return existingPresets
end

return preset
