local M = {}

M.defaults = {
  title = "Bafa",
  title_pos = "center",
  relative = "editor",
  border = "rounded",
  style = "minimal",
  diagnostics = true,
  -- nil means use WarningMsg, or set to a highlight group name like "WarningMsg" or "DiffText"
  modified_hl = nil,
}

M.options = M.defaults

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
end

M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

M.get = function()
  return M.options
end

return M
