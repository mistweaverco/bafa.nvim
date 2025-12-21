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

---@class BafaConfigIcons
---@field diagnostics BafaConfigIconsDiagnostics

---@class BafaDefaultConfig
---@field title string
---@field title_pos BafaConfigTitlesPos
---@field border BafaConfigBorder
---@field style BafaConfigStyle
---@field diagnostics boolean
---@field modified_hl string
---@field line_numbers boolean
---@field log_level BafaLoggerLogLevelNames
---@field notify BafaConfigNotify
---@field icons BafaConfigIcons

---@class BafaUserConfig
---@field title string|nil
---@field title_pos BafaConfigTitlesPos|nil
---@field border BafaConfigBorder|nil
---@field style BafaConfigStyle|nil
---@field diagnostics boolean|nil
---@field modified_hl string|nil
---@field line_numbers boolean|nil
---@field log_level BafaLoggerLogLevelNames|nil
---@field notify BafaConfigNotify|nil
---@field icons BafaConfigIcons|nil

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
