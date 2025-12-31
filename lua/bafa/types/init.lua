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

---@enum BafaConfigUiTitlePos
M.BafaConfigUiTitlePos = {
  center = "center",
  left = "left",
  right = "right",
}

---@enum BafaConfigUiBorder
M.BafaConfigUiBorder = {
  none = "none",
  single = "single",
  double = "double",
  rounded = "rounded",
  solid = "solid",
  shadow = "shadow",
}

---@enum BafaConfigUiStyle
M.BafaConfigUiStyle = {
  minimal = "minimal",
  classic = "classic",
  minimal_inset = "minimal_inset",
}

---@enum BafaConfigNotifyProvider
M.BafaConfigNotifyProvider = {
  vim_notify = "vim.notify",
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

---@enum BafaDiagnosticType
M.BafaDiagnosticType = {
  Error = "Error",
  Warn = "Warn",
  Info = "Info",
  Hint = "Hint",
}

---@class BafaUiBufferLine
---@field number number Buffer number in Neovim
---@field line_number number Line number in the UI
---@field name string Buffer name, including path
---@field is_modified boolean If true, buffer has unsaved changes
---@field last_used string Human-readable last used time
---@field diagnostics table<BafaDiagnosticType, number>|nil Diagnostics counts by type (e.g., { Error = 2, Warn = 1 }), nil if diagnostics are disabled

---@class BafaUiToggleOptions
---@field with_jump_labels boolean|nil If true, shows jump labels when opening the menu

---@class BafaPersistedData
---@field buffers BafaBuffer[]
---@field sorting BafaSorting

---@class BafaConfigNotify
---@field provider BafaConfigNotifyProvider|string Notification provider

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

---@class BafaConfigUiJumpLabels
---@field always_visible boolean Always show jump-labels for quick navigation
---@field keys string[] Keys to use for jump-labels in order of preference

---@class BafaConfigUiPosition
---@field preset BafaConfigWindowPosition|nil Window position preset
---@field row number|function|nil Custom row position (overrides preset if set), also supports a function that returns a number
---@field col number|function|nil Custom column position (overrides preset if set), also supports a function that returns a number

---@class BafaConfigUiTitle
---@field text string Title text
---@field pos BafaConfigUiTitlePos Title position

---@class BafaConfigUiSort
---@field method BafaSorting Sorting method
---@field focus_alternate_buffer boolean If true, cursor defaults to second buffer (second most recently used) when opening menu

---@class BafaConfigUiRender
---@field custom_format_buffer_line fun(buffer_line: BafaUiBufferLine): string|nil Custom buffer name format function. If provided, this function will be called for each buffer to format only the buffer name/content. The plugin handles padding, icons, and diagnostics. Should return a string for the buffer name/content, or nil to use default formatting.

---@class BafaConfigUi
---@field jump_labels BafaConfigUiJumpLabels Jump-labels configuration
---@field diagnostics boolean Show diagnostics in the UI
---@field line_numbers boolean Show line numbers in the UI
---@field title BafaConfigUiTitle Title configuration
---@field border BafaConfigUiBorder Floating window border configuration
---@field style BafaConfigUiStyle Floating window style configuration
---@field position BafaConfigUiPosition Window position configuration
---@field icons BafaConfigIcons Icons configuration
---@field hl BafaConfigHl Highlight groups configuration
---@field sort BafaConfigUiSort Sort configuration
---@field render BafaConfigUiRender Render configuration

---@class BafaDefaultConfig
---@field log_level BafaLoggerLogLevelNames
---@field notify BafaConfigNotify
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

---@class BafaUserConfigUiJumpLabels
---@field always_visible boolean|nil Always show jump-labels for quick navigation
---@field keys string[]|nil Keys to use for jump-labels in order of preference

---@class BafaUserConfigUiTitle
---@field text string|nil Title text
---@field pos BafaConfigUiTitlePos|nil Title position

---@class BafaUserConfigUiSort
---@field method BafaSorting|nil Sorting method, defaults to BafaSorting.DEFAULT
---@field focus_alternate_buffer boolean|nil If true, cursor defaults to second buffer (second most recently used) when opening menu

---@class BafaUserConfigUiRender
---@field custom_format_buffer_line fun(buffer_line: BafaUiBufferLine): string|nil|nil Custom buffer name format function. If provided, this function will be called for each buffer to format only the buffer name/content. The plugin handles padding, icons, and diagnostics. Should return a string for the buffer name/content, or nil to use default formatting.

---@class BafaUserConfigUi
---@field jump_labels BafaUserConfigUiJumpLabels|nil Jump-labels configuration
---@field diagnostics boolean|nil Show diagnostics in the UI
---@field line_numbers boolean|nil Show line numbers in the UI
---@field title BafaUserConfigUiTitle|nil Title configuration
---@field border BafaConfigUiBorder|nil Floating window border configuration
---@field style BafaConfigUiStyle|nil Floating window style configuration
---@field position BafaUserConfigUiPosition|nil Window position configuration
---@field icons BafaConfigIcons|nil Icons configuration
---@field hl BafaUserConfigHl|nil Highlight groups configuration
---@field sort BafaUserConfigUiSort|nil Sort configuration
---@field render BafaUserConfigUiRender|nil Render configuration

---@class BafaUserConfig
---@field title string|nil @deprecated Use ui.title.text instead
---@field title_pos BafaConfigUiTitlePos|nil @deprecated Use ui.title.pos instead
---@field border BafaConfigUiBorder|nil @deprecated Use ui.border instead
---@field style BafaConfigUiStyle|nil @deprecated Use ui.style instead
---@field diagnostics boolean|nil @deprecated Use ui.diagnostics instead
---@field line_numbers boolean|nil @deprecated Use ui.line_numbers instead
---@field log_level BafaLoggerLogLevelNames|nil
---@field notify BafaConfigNotify|nil
---@field icons BafaConfigIcons|nil @deprecated Use ui.icons instead
---@field hl BafaUserConfigHl|nil @deprecated Use ui.hl instead
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
