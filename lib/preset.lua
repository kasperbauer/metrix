local preset = {}
local track = include('lib/track')

function preset:new()
    local t = setmetatable({}, {
        __index = preset
    })

    t.path = _path.code .. 'metrix/presets/'
    t.current = nil
    util.make_dir(t.path)

    return t
end

function preset:load(id)
    if not self:exists(id) then
        return false
    end

    local data = tab.load(self.path .. id)

    local tracks = {}
    for i = 1, #data.tracks do
        local track = track:new(data.tracks[i])
        table.insert(tracks, track)
    end

    self.current = id

    return {
        tracks = tracks
    };
end

function preset:save(id, data)
    tab.save(data, self.path .. id)
    self.current = id
end

function preset:exists(id)
    return util.file_exists(self.path .. id)
end

function preset:delete(id)
    if self:exists(id) then
        os.remove(self.path .. id)
        self.current = nil
    end
end

return preset
