local M = {}

M.get_base_path_from_file_path = function(file_path)
  local base_path = file_path:match("(.*/)")
  return base_path
end

M.get_file_name_from_file_path = function(file_path)
  local file_name = file_path:match("([^/]+)$")
  return file_name
end

M.get_normalized_path = function(item)
  local current_working_directory = vim.fn.getcwd()
  local relative_path = item:gsub(current_working_directory, ""):sub(2)
  return relative_path
end

return M
