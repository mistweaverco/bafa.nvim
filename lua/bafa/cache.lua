BAFA_CACHE = {}

local M = {}

function M.get(key)
    return BAFA_CACHE[key]
end

function M.set(key, value)
    BAFA_CACHE[key] = value
end

function M.clear()
    BAFA_CACHE = {}
end

return M
