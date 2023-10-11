local M = {}

function M.defaults(bufnr)
  vim.cmd(
    string.format(
      "autocmd BufWriteCmd <buffer=%s> lua require('bafa.ui').on_menu_save()",
      bufnr
    )
  )
  vim.cmd(
    string.format(
      "autocmd BufModifiedSet <buffer=%s> set nomodified",
      bufnr
    )
  )
  vim.cmd(
    "autocmd BufLeave <buffer> ++nested ++once silent lua require('bafa.ui').toggle()"
  )
end

return M
