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
  log_level = Types.BafaLoggerLogLevelNames.error,
  notify = {
    provider = Types.BafaConfigNotifyProvider.vim_notify,
  },
  ui = {
    jump_labels = {
      always_visible = false,
    -- Keep the keys aligned in a grid for better visibility
    -- stylua: ignore
      keys = {
        "a", "s", "d", "f", "j", "k", "l", ";",
        "q", "w", "e", "r", "u", "i", "o", "p",
        "z", "x", "c", "v", "n", "m", ",", ".",
      },
    },
    diagnostics = true,
    line_numbers = false,
    title = {
      text = "🦥",
      pos = Types.BafaConfigUiTitlePos.center,
    },
    border = Types.BafaConfigUiBorder.rounded,
    style = Types.BafaConfigUiStyle.minimal,
    position = {
      preset = Types.BafaConfigWindowPosition.center,
      row = nil, -- Custom row position (overrides preset if set), also supports a function that returns a number
      col = nil, -- Custom column position (overrides preset if set), also supports a function that returns a number
    },
    icons = {
      diagnostics = {
        Error = "", -- Icon for error diagnostics
        Warn = "", -- Icon for warning diagnostics
        Info = "", -- Icon for info diagnostics
        Hint = "", -- Icon for hint diagnostics
      },
      sign = {
        changes = "┃", -- Sign character for modified/deleted buffers (gitsigns-like UX)
      },
    },
    hl = {
      sign = {
        modified = "GitSignsChange", -- Highlight group for modified buffer signs (fallback: DiffChange)
        deleted = "GitSignsDelete", -- Highlight group for deleted buffer signs (fallback: DiffDelete)
      },
    },
  },
}

---@type BafaDefaultConfig
M.user_config = M.config_defaults

---Migrate deprecated config fields to new structure
---@param config BafaUserConfig
---@return BafaUserConfig Migrated config
local function migrate_config(config)
  if not config or type(config) ~= "table" then return config or {} end

  local migrated = vim.deepcopy(config)

  -- Migrate deprecated top-level fields to ui.*
  if migrated.title ~= nil and (not migrated.ui or not migrated.ui.title) then
    if not migrated.ui then migrated.ui = {} end
    if not migrated.ui.title then migrated.ui.title = {} end
    if migrated.ui.title.text == nil then migrated.ui.title.text = migrated.title end
  end

  if migrated.title_pos ~= nil and (not migrated.ui or not migrated.ui.title) then
    if not migrated.ui then migrated.ui = {} end
    if not migrated.ui.title then migrated.ui.title = {} end
    if migrated.ui.title.pos == nil then migrated.ui.title.pos = migrated.title_pos end
  end

  if migrated.border ~= nil and (not migrated.ui or migrated.ui.border == nil) then
    if not migrated.ui then migrated.ui = {} end
    if migrated.ui.border == nil then migrated.ui.border = migrated.border end
  end

  if migrated.style ~= nil and (not migrated.ui or migrated.ui.style == nil) then
    if not migrated.ui then migrated.ui = {} end
    if migrated.ui.style == nil then migrated.ui.style = migrated.style end
  end

  if migrated.diagnostics ~= nil and (not migrated.ui or migrated.ui.diagnostics == nil) then
    if not migrated.ui then migrated.ui = {} end
    if migrated.ui.diagnostics == nil then migrated.ui.diagnostics = migrated.diagnostics end
  end

  if migrated.line_numbers ~= nil and (not migrated.ui or migrated.ui.line_numbers == nil) then
    if not migrated.ui then migrated.ui = {} end
    if migrated.ui.line_numbers == nil then migrated.ui.line_numbers = migrated.line_numbers end
  end

  if migrated.icons ~= nil and (not migrated.ui or migrated.ui.icons == nil) then
    if not migrated.ui then migrated.ui = {} end
    if migrated.ui.icons == nil then migrated.ui.icons = migrated.icons end
  end

  if migrated.hl ~= nil and (not migrated.ui or migrated.ui.hl == nil) then
    if not migrated.ui then migrated.ui = {} end
    if migrated.ui.hl == nil then migrated.ui.hl = migrated.hl end
  end

  return migrated
end

---Setup configuration
---@param config BafaUserConfig|nil
M.setup = function(config)
  -- Migrate deprecated config fields to new structure
  local migrated_config = migrate_config(config or {})
  -- Merge user config with defaults using deep extend
  -- This properly handles nested tables like ui.position
  M.user_config = vim.tbl_deep_extend("force", M.config_defaults, migrated_config)
end

---Set configuration options
---Sets a partial config, merging with existing options, overriding existing keys
---@param config BafaUserConfig|nil
M.set = function(config)
  local migrated_config = migrate_config(config or {})
  local normalized_config = M.get_normalized_config(migrated_config)
  M.user_config = vim.tbl_deep_extend("force", M.user_config, normalized_config)
end

M.get = function() return M.user_config end

return M
