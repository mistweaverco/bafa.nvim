local M = {}

local ORIGINAL_CURSORS = vim.opt.guicursor
local CURSOR_LINE_HL = vim.api.nvim_get_hl(0, { name = "CursorLine", link = true })
local BETTER_WHITESPACE_HL = vim.api.nvim_get_hl(0, { name = "ExtraWhitespace", link = true })
local CURSOR_LINE_BG = CURSOR_LINE_HL.bg or "NONE"

vim.api.nvim_set_hl(0, "BafaHiddenCursor", {
  bg = CURSOR_LINE_BG,
  fg = CURSOR_LINE_BG,
  blend = 100,
})

vim.api.nvim_set_hl(0, "BafaHiddenWhitespace", {
  bg = "NONE",
  fg = "NONE",
})

--- Apply patches to modify UI settings
function M.apply_patches()
  -- Set hidden cursor style
  vim.opt.guicursor = "n-v:block-BafaHiddenCursor"
  -- Override vim-better-whitespace highlight to be
  -- invisible (we add padding spaces intentionally)
  vim.api.nvim_set_hl(0, "ExtraWhitespace", { link = "BafaHiddenWhitespace", force = true })
end

---Revert patches to restore original settings
function M.revert_patches()
  -- Restore original cursor style
  vim.opt.guicursor = ORIGINAL_CURSORS
  -- Restore original vim-better-whitespace highlight
  vim.api.nvim_set_hl(0, "ExtraWhitespace", vim.tbl_deep_extend("force", {}, BETTER_WHITESPACE_HL))
end

--- Enable cursorline for a window
---@param winid number Window ID
function M.enable_cursorline(winid) vim.wo[winid].cursorline = true end

return M
