local helpers = {}

function helpers.arrayContains(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

return helpers
