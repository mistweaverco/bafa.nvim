local M = {}

---Get the local leader key, fallback to leader if not set
---@type string
M.localleader = vim.g.maplocalleader or vim.g.mapleader

---List of reserved keys that cannot be used as jump labels
---and will be skipped when generating jump labels
---@type string[]
M.protected_jump_label_keys = {
  "g", -- used to toggle jump labels
  "d", -- this enables deleting buffers
  "v", -- used for visual mode
  "V", -- used for visual line mode
}

if M.localleader then table.insert(M.protected_jump_label_keys, M.localleader) end

return M
