local Path = require("plenary.path")

local M = {}

function M.project_key()
    return vim.loop.cwd()
end

M.get_base_path_from_file_path = function(file_path)
  local base_path = file_path:match("(.*/)")
  return base_path
end

M.get_file_name_from_file_path = function(file_path)
  local file_name = file_path:match("([^/]+)$")
  return file_name
end

M.get_normalized_path = function(item)
  return Path:new(item):make_relative(M.project_key())
end

return M
