-- http://tex.stackexchange.com/a/48241
local separator = package.config:sub(1,1)
local function getPath(...)
    local elements = {...}
    return table.concat(elements, separator)
end
return getPath
