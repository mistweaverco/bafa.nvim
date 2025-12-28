local M = {}

---@enum BafaSorting
M.BafaSorting = {
  DEFAULT = "last_used",
  AUTO = "last_used",
  MANUAL = "manual",
}

---@enum BafaLoggerLogLevelNames
M.BafaLoggerLogLevelNames = {
  trace = "trace",
  debug = "debug",
  info = "info",
  warn = "warn",
  error = "error",
  off = "off",
}

---@enum BafaLoggerLogLevels
M.BafaLoggerLogLevels = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
  off = vim.log.levels.OFF,
}

---@enum BafaConfigTitlesPos
M.BafaConfigTitlesPos = {
  center = "center",
  left = "left",
  right = "right",
}

---@enum BafaConfigBorder
M.BafaConfigBorder = {
  none = "none",
  single = "single",
  double = "double",
  rounded = "rounded",
  solid = "solid",
  shadow = "shadow",
}

---@enum BafaConfigStyle
M.BafaConfigStyle = {
  minimal = "minimal",
  classic = "classic",
  minimal_inset = "minimal_inset",
}

---@enum BafaConfigNotifyProvider
M.BafaConfigNotifyProvider = {
  notify = "notify",
  print = "print",
}

---@enum BafaConfigWindowPosition
M.BafaConfigWindowPosition = {
  center = "center",
  top_center = "top-center",
  bottom_center = "bottom-center",
  top_left = "top-left",
  top_right = "top-right",
  bottom_left = "bottom-left",
  bottom_right = "bottom-right",
  center_left = "center-left",
  center_right = "center-right",
}

---@class BafaPersistedData
---@field buffers BafaBuffer[]
---@field sorting BafaSorting

---@class BafaConfigNotify
---@field provider BafaConfigNotifyProvider

---@class BafaConfigIconsDiagnostics
---@field Error string
---@field Warn string
---@field Info string
---@field Hint string

---@class BafaConfigIconsSign
---@field changes string Sign character for modified/deleted buffers

---@class BafaConfigIcons
---@field diagnostics BafaConfigIconsDiagnostics
---@field sign BafaConfigIconsSign

---@class BafaConfigHlSign
---@field modified string Highlight group for modified buffer signs
---@field deleted string Highlight group for deleted buffer signs

---@class BafaConfigHl
---@field sign BafaConfigHlSign Highlight groups for signs

---@class BafaConfigUiPosition
---@field preset BafaConfigWindowPosition|nil Window position preset
---@field row number|nil Custom row position (overrides preset if set)
---@field col number|nil Custom column position (overrides preset if set)

---@class BafaConfigUi
---@field position BafaConfigUiPosition Window position configuration

---@class BafaDefaultConfig
---@field title string
---@field title_pos BafaConfigTitlesPos
---@field border BafaConfigBorder
---@field style BafaConfigStyle
---@field diagnostics boolean
---@field line_numbers boolean
---@field log_level BafaLoggerLogLevelNames
---@field notify BafaConfigNotify
---@field icons BafaConfigIcons
---@field hl BafaConfigHl Highlight groups configuration
---@field ui BafaConfigUi UI configuration

---@class BafaUserConfigHlSign
---@field modified string|nil
---@field deleted string|nil

---@class BafaUserConfigHl
---@field sign BafaUserConfigHlSign|nil

---@class BafaUserConfigUiPosition
---@field preset BafaConfigWindowPosition|nil Window position preset
---@field row number|nil Custom row position (overrides preset if set)
---@field col number|nil Custom column position (overrides preset if set)

---@class BafaUserConfigUi
---@field position BafaUserConfigUiPosition|nil Window position configuration

---@class BafaUserConfig
---@field title string|nil
---@field title_pos BafaConfigTitlesPos|nil
---@field border BafaConfigBorder|nil
---@field style BafaConfigStyle|nil
---@field diagnostics boolean|nil
---@field line_numbers boolean|nil
---@field log_level BafaLoggerLogLevelNames|nil
---@field notify BafaConfigNotify|nil
---@field icons BafaConfigIcons|nil
---@field hl BafaUserConfigHl|nil
---@field ui BafaUserConfigUi|nil

---@class BafaState
---@field sorting BafaSorting|nil
---@field original_buffers table<number, BafaBuffer>
---@field working_buffers table<number, BafaBuffer>
---@field history table<number, BafaBuffer[]>
---@field history_index number

---@class BafaBuffer
---@field name string
---@field path string
---@field number number
---@field last_used_time number
---@field last_used string
---@field is_modified boolean

return M
