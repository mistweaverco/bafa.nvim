local M = {}

function M.defaults(bufnr)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function() require("bafa.ui").on_menu_save() end,
  })
  -- Use OptionSet modified instead of BufModifiedSet for neovim 0.12 and above
  -- https://github.com/mistweaverco/bafa.nvim/issues/59
  -- https://github.com/neovim/neovim/commit/443171328531e33a7caecda0b81dadd826518a58
  -- neovim 0.12+ deprecated BufModifiedSet, use Optionset modified instead
  local event = vim.fn.has("nvim-0.12") == 1 and "OptionSet" or "BufModifiedSet"
  local opts = { buffer = bufnr }
  vim.api.nvim_create_autocmd(
    event,
    vim.tbl_extend("force", opts, {
      command = "set nomodified",
    })
  )
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    nested = true,
    once = true,
    callback = function() require("bafa.ui").toggle() end,
  })
end

return M
