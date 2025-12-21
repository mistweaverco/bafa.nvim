local M = {}

local ORIGINAL_CURSORS = vim.opt.guicursor
local ORIGINAL_CURSORLINE = vim.opt.cursorline
local CURSOR_LINE_HL = vim.api.nvim_get_hl(0, { name = "CursorLine", link = true })
local CURSOR_LINE_BG = CURSOR_LINE_HL.bg or "NONE"

vim.api.nvim_set_hl(0, "BafaHiddenCursor", {
  bg = CURSOR_LINE_BG,
  fg = CURSOR_LINE_BG,
  blend = 100,
})

function M.hide_cursor()
  vim.opt.guicursor = "n:block-BafaHiddenCursor"
end

function M.enable_cursorline(winid)
  vim.wo[winid].cursorline = true
end

function M.show_cursor()
  vim.opt.guicursor = ORIGINAL_CURSORS
end

return M
