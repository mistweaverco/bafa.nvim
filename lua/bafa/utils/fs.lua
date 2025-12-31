---@module 'bafa.utils.file'
local M = {}

M.path_separator = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"

---Checks if a file or directory exists at the given path.
---@param path string
---@return boolean
M.exists = function(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil
end

---Joins multiple path segments into a single path string.
---@param ... string
---@return string
M.join_paths = function(...)
  local paths = { ... }
  return table.concat(paths, M.path_separator)
end

return M
