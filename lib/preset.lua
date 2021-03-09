local preset = {}

function preset.load(presetIndex)
    local file = assert(io.open(_path.code .. 'polix/presets/' .. presetIndex .. '.json', 'r'))
    local jsonContent = file:read('*all')
    file:close()

    local data = json.parse(jsonContent)
    return data;
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