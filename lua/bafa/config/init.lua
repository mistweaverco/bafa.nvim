local M = {}
local Types = require("bafa.types")

---Get normalized config
---@param cfg BafaUserConfig
---@return BafaDefaultConfig
M.get_normalized_config = function(cfg)
  local defaults = M.config_defaults
  for key, value in pairs(cfg) do
    if value == nil then
      defaults[key] = nil
    elseif type(value) == "table" then
      M.get_normalized_config(value)
    end
  end
  return defaults
end

---@type string
M.plugin_name = "bafa.nvim"

---@type BafaDefaultConfig
M.config_defaults = {
  title = "Bafa",
  title_pos = "center",
  relative = "editor",
  border = "rounded",
  style = "minimal",
  diagnostics = true,
  modified_hl = "WarningMsg",
  line_numbers = false,
  log_level = Types.BafaLoggerLogLevelNames.error,
  notify = {
    provider = Types.BafaConfigNotifyProvider.nvim_notify,
  },
}

---@type BafaDefaultConfig
M.user_config = M.config_defaults

---Setup configuration
---@param config BafaUserConfig|nil
M.setup = function(config)
  local normalized_config = M.get_normalized_config(config or {})
  M.user_config = vim.tbl_deep_extend("force", M.config_defaults, normalized_config)
end

---Set configuration options
---Sets a partial config, merging with existing options, overriding existing keys
---@param config BafaUserConfig|nil
M.set = function(config)
  local normalized_config = M.get_normalized_config(config or {})
  M.user_config = vim.tbl_deep_extend("force", M.options, normalized_config)
end

M.get = function()
  return M.user_config
end

return M
