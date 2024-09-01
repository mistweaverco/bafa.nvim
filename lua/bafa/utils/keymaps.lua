local M = {}

local noop_keys = {
  "i",
  "I",
  "a",
  "A",
  "o",
  "O",
  "s",
  "S",
  "c",
  "C",
  "r",
  "u",
  "U",
}

function M.noop(bufnr)
  for _, key in ipairs(noop_keys) do
    vim.api.nvim_buf_set_keymap(bufnr, "n", key, "", { silent = true })
  end
end

function M.defaults(bufnr)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<Cmd>lua require('bafa.ui').toggle()<CR>", { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<ESC>", "<Cmd>lua require('bafa.ui').toggle()<CR>", { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "<Cmd>lua require('bafa.ui').select_menu_item()<CR>", {})
  vim.api.nvim_buf_set_keymap(bufnr, "n", "dd", "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>", {})
  vim.api.nvim_buf_set_keymap(bufnr, "n", "D", "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>", {})
end

return M
