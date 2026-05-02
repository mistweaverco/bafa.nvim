local M = {}

function M.defaults(bufnr)
  vim.cmd(string.format("autocmd BufWriteCmd <buffer=%s> lua require('bafa.ui').on_menu_save()", bufnr))
  -- replace deprecated BufModifiedSet with Optionset modified:
  -- https://github.com/mistweaverco/bafa.nvim/issues/59
  -- https://github.com/neovim/neovim/commit/443171328531e33a7caecda0b81dadd826518a58
  -- neovim 0.12+ deprecated BufModifiedSet, use Optionset modified instead
  if vim.fn.has("nvim-0.12") == 1 then -- reports 1 if nvim version is 0.12 or higher
    vim.cmd(string.format("autocmd OptionSet modified <buffer=%s> set nomodified", bufnr))
  else
    vim.cmd(string.format("autocmd BufModifiedSet <buffer=%s> set nomodified", bufnr))
  end
  vim.cmd("autocmd BufLeave <buffer> ++nested ++once silent lua require('bafa.ui').toggle()")
end

return M
