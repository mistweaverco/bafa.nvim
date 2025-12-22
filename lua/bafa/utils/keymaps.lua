local M = {}

function M.defaults(bufnr)
  -- Close window
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<Cmd>lua require('bafa.ui').toggle()<CR>", { silent = true })
  -- Reject changes and close on Escape
  vim.api.nvim_buf_set_keymap(
    bufnr,
    "n",
    "<ESC>",
    "<Cmd>lua require('bafa.ui').reject_changes() require('bafa.ui').toggle()<CR>",
    { silent = true }
  )
  -- Select buffer (commits changes first)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "<Cmd>lua require('bafa.ui').select_menu_item()<CR>", {})
  -- Delete buffer
  vim.api.nvim_buf_set_keymap(bufnr, "n", "dd", "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>", {})
  vim.api.nvim_buf_set_keymap(bufnr, "n", "D", "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>", {})
  -- Move buffer up (swap with previous)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<Cmd>lua require('bafa.ui').move_buffer_up()<CR>", { silent = true })
  -- Move buffer down (swap with next)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "J", "<Cmd>lua require('bafa.ui').move_buffer_down()<CR>", { silent = true })
  -- Toggle sorting
  vim.api.nvim_buf_set_keymap(bufnr, "n", "o", "<Cmd>lua require('bafa.ui').toggle_sorting()<CR>", { silent = true })
  -- Undo
  vim.api.nvim_buf_set_keymap(bufnr, "n", "u", "<Cmd>lua require('bafa.ui').undo()<CR>", { silent = true })
  -- Redo
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-r>", "<Cmd>lua require('bafa.ui').redo()<CR>", { silent = true })

  -- Force normal visual mode to be linewise
  vim.api.nvim_buf_set_keymap(bufnr, "n", "v", "V", { silent = true })

  -- Visual mode: delete selected buffers (d and D work in visual mode)
  vim.api.nvim_buf_set_keymap(bufnr, "v", "d", "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>", {})
  vim.api.nvim_buf_set_keymap(bufnr, "v", "D", "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>", {})
  -- Visual mode: move selected buffers up/down (K and J work in visual mode)
  vim.api.nvim_buf_set_keymap(bufnr, "v", "K", "<Cmd>lua require('bafa.ui').move_buffer_up()<CR>", { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, "v", "J", "<Cmd>lua require('bafa.ui').move_buffer_down()<CR>", { silent = true })
end

return M
