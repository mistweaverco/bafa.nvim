local M = {}

---Get the local leader key, fallback to leader if not set
---@type string
M.localleader = vim.g.maplocalleader or vim.g.mapleader

---List of reserved keys that cannot be used as jump labels
---@type string[]
M.protected_jump_label_keys = {
  "J", -- move down
  "K", -- move up
  "u", -- undo
  "g", -- used to toggle jump labels
  "d", -- this enables deleting buffers
  "V", -- line visual mode
  "v", -- visual mode
}

if M.localleader then table.insert(M.protected_jump_label_keys, M.localleader) end

return M
