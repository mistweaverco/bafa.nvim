local Types = require("bafa.types")
local Config = require("bafa.config")
local M = {}

local is_table = function(value)
  return type(value) == "table"
end

--- Format log message from multiple arguments
--- @param ... any Multiple arguments to format into a log message
--- @return string Formatted log message
local get_log_message = function(...)
  local args = { ... }
  local message = table.concat(
    vim.tbl_map(function(arg)
      if is_table(arg) then
        return vim.inspect(arg)
      else
        return tostring(arg)
      end
    end, args),
    " "
  )
  return message
end

--- Determine if a message should be logged based on its level
--- @param level BafaLoggerLogLevels The log level of the message
local function should_log(level)
  if level == nil then
    M.error("Invalid log level: " .. tostring(level))
    return false
  end
  local conf = Config.get()
  return conf.log_level ~= nil and level >= Types.BafaLoggerLogLevels[conf.log_level]
end

--- Print log message to console
--- @param ... any Multiple arguments to log
--- @return nil
local logger_print = function(level, ...)
  print("[" .. Config.plugin_name .. "] [" .. level .. "] " .. get_log_message(...))
end

--- Log a message at info level
--- @param ... any Multiple arguments to log
--- @deprecated Use M.info instead
--- @return nil
M.log = function(...)
  if not should_log(Types.BafaLoggerLogLevels.info) then
    return
  end
  logger_print(Types.BafaLoggerLogLevelNames.info, ...)
end

--- Log a message at info level
--- @param ... any Multiple arguments to log
--- @return nil
M.info = function(...)
  if not should_log(Types.BafaLoggerLogLevels.info) then
    return
  end
  logger_print(Types.BafaLoggerLogLevelNames.info, ...)
end

--- Log a message at warn level
--- @param ... any Multiple arguments to log
--- @return nil
M.warn = function(...)
  if not should_log(Types.BafaLoggerLogLevels.warn) then
    return
  end
  logger_print(Types.BafaLoggerLogLevelNames.warn, ...)
end

--- Log a message at error level
--- @param ... any Multiple arguments to log
--- @return nil
M.error = function(...)
  if not should_log(Types.BafaLoggerLogLevels.error) then
    return
  end
  logger_print(Types.BafaLoggerLogLevelNames.error, ...)
end

--- Log a message at debug level
--- @param ... any Multiple arguments to log
--- @return nil
M.debug = function(...)
  if not should_log(Types.BafaLoggerLogLevels.debug) then
    return
  end
  logger_print(Types.BafaLoggerLogLevelNames.debug, ...)
end

--- Generic notification function
--- @param message string The notification message
--- @param level BafaLoggerLogLevels The log level ("error", "warn", "info", "debug")
M.notify = function(message, level)
  local conf = Config.get()
  if conf.notify.provider == "print" then
    print("[" .. Config.plugin_name .. "] [" .. level .. "] " .. message)
    return
  end
  vim.notify(
    message,
    Types.BafaLoggerLogLevels[level] or Types.BafaLoggerLogLevels.info,
    { title = Config.plugin_name }
  )
end

return M
