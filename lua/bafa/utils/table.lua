local M = {}

---Check if a table contains a value
---@param tbl table The table to search
---@param val any The value to search for
---@return boolean True if the value is found, false otherwise
M.contains = function(tbl, val)
  for _, v in ipairs(tbl) do
    if v == val then return true end
  end
  return false
end

---Get the index of a value in a table
---@param tbl table The table to search
---@param val any The value to search for
M.index_of = function(tbl, val)
  for i, v in ipairs(tbl) do
    if v == val then return i end
  end
  return nil
end

return M
