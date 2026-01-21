local M = {}
local Types = require("bafa.types")

---Get normalized config
---@param cfg BafaUserConfig
---@return BafaDefaultConfig
M.get_normalized_config = function(cfg) return vim.tbl_deep_extend("force", M.config_defaults, cfg or {}) end

---@type string
M.plugin_name = "bafa.nvim"

---@type string
M.ui_buffer_ft = "bafa"

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
        "z", "x", "c", "n", "m", ",", ".",
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
    sort = {
      method = Types.BafaSorting.DEFAULT, -- Sorting method
      focus_alternate_buffer = false, -- If true, cursor defaults to second buffer when opening menu
    },
    render = {
      custom_format_buffer_line = nil, -- Custom buffer line format function, default is nil
    },
  },
}

---@type BafaDefaultConfig
M.user_config = M.config_defaults

---Normalize sorting method string aliases to enum values
---@param method string|BafaSorting|nil
---@return BafaSorting
local function normalize_sort_method(method)
  if method == nil then return Types.BafaSorting.DEFAULT end
  -- Handle string aliases
  if type(method) == "string" then
    if method == "auto" then return Types.BafaSorting.AUTO end
    if method == "manual" then return Types.BafaSorting.MANUAL end
    -- If it's already a valid enum value string, return it
    for _, valid_sorting in pairs(Types.BafaSorting) do
      if method == valid_sorting then return method end
    end
  end
  -- If it's already an enum value, return it
  for _, valid_sorting in pairs(Types.BafaSorting) do
    if method == valid_sorting then return method end
  end
  return Types.BafaSorting.DEFAULT
end

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

  -- Normalize sort method if present
  if migrated.ui and migrated.ui.sort and migrated.ui.sort.method then
    migrated.ui.sort.method = normalize_sort_method(migrated.ui.sort.method)
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
