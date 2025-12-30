local Config = require("bafa.config")

---@class bafa
local M = {}

---Toggle bafa menu
---@alias bafa.ui.toggle bafa.ui.toggle
---@return bafa
M.toggle = function(...)
  require("bafa.ui").toggle(...)
  return M
end

---Hide bafa menu
---@alias bafa.ui.hide bafa.ui.hide
---@return bafa
M.hide = function()
  require("bafa.ui").hide()
  return M
end

---Toggle sorting of bafa menu
---@alias bafa.ui.toggle_sorting bafa.ui.toggle_sorting
---@return bafa
M.toggle_sorting = function(...)
  require("bafa.ui").toggle_sorting(...)
  return M
end

---Setup bafa with user configuration
---@return bafa
M.setup = function(config)
  Config.setup(config)
  return M
end

return M
