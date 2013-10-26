if table.copy == nil then
    -- http://lua-users.org/wiki/CopyTable
    table.copy = function(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in pairs(orig) do
                copy[orig_key] = orig_value
            end
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end
end
if table.merge == nil then
    table.merge = function(...)
        local tables = {...}
        local result = {}
        for i,table in ipairs(tables) do
            for k,v in pairs(table) do result[k] = v end
        end
        return result
    end
end

return table.merge
