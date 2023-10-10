local buffer_utils = require('bafa.utils.buffers')
local table_utils = require('bafa.utils.tables')

local M = {}

BAFA_CONFIG = {
  title = "Bafa",
  title_pos = "center",
  relative = "editor",
  border = "rounded",
  style = "minimal",
}

M.setup = function(config)
  config = config or {}
  BAFA_CONFIG = table_utils.merge_tables(BAFA_CONFIG, config)
end

M.get_config = function()
  return BAFA_CONFIG
end

return M
