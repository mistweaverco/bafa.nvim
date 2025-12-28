local M = {}

M.is_in_visual_mode = function()
  local mode = vim.fn.mode()
  vim.notify("Current mode: " .. mode, vim.log.levels.DEBUG)
  return mode == "v" or mode == "vs" or mode == "V" or mode == "Vs" or mode == "CTRL-V" or mode == "CTRL-Vs"
end

return M
