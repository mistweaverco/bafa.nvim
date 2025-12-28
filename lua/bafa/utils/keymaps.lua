local M = {}

-- Shared options to ensure we override everything
local BASE_KEYMAP_OPTS = {
  buffer = 0,
  nowait = true,
  silent = true,
  remap = false,
}

function M.defaults(bufnr)
  local user_config = require("bafa.config").get()
  local ui = require("bafa.ui")

  ---Helper to get keymap options with description and overrides
  ---@param desc string Description for the keymap
  ---@param overrides table|nil Optional overrides for the base options
  ---@return table Keymap options
  local get_keymap_opts = function(desc, overrides)
    overrides = overrides or {}
    overrides.desc = desc
    return vim.tbl_extend("force", BASE_KEYMAP_OPTS, overrides)
  end

  --- unset all existing keymaps for the buffer
  --- that are used for jump labels or menu actions
  local jump_lablels_keys = user_config.ui.jump_labels.keys
  for _, key in ipairs(jump_lablels_keys) do
    vim.keymap.set("n", key, "<Nop>", get_keymap_opts("Unset jump label keymap"))
  end

  -- Cancel action (ESC and q)
  vim.keymap.set(
    "n",
    "<ESC>",
    function() ui.cancel_action_handler(false) end,
    get_keymap_opts("Cancel changes and close buffer menu")
  )
  vim.keymap.set(
    "n",
    "q",
    function() ui.cancel_action_handler(true) end,
    get_keymap_opts("Cancel changes and close buffer menu")
  )
  -- Select buffer (commits changes first)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "<Cmd>lua require('bafa.ui').select_menu_item()<CR>", {})
  -- Delete buffer
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

  -- Commit changes without closing (localleader + w)
  local localleader = vim.g.maplocalleader or ","
  vim.api.nvim_buf_set_keymap(
    bufnr,
    "n",
    localleader .. "w",
    "<Cmd>lua require('bafa.ui').commit_changes_and_refresh()<CR>",
    { silent = true, desc = "Commit changes and refresh UI" }
  )
  -- Commit changes and close (localleader + W)
  vim.api.nvim_buf_set_keymap(
    bufnr,
    "n",
    localleader .. "W",
    "<Cmd>lua require('bafa.ui').commit_changes_and_close()<CR>",
    { silent = true, desc = "Commit changes and close UI" }
  )

  -- Jump labels: show labels when g is pressed
  -- This allows users to press 'g' then a label key to quickly jump to a buffer
  vim.api.nvim_buf_set_keymap(
    bufnr,
    "n",
    "g",
    "<Cmd>lua require('bafa.ui').toggle_jump_labels()<CR>",
    { silent = true, nowait = false, desc = "Show jump labels" }
  )

  -- Jump label keys (only active when labels are visible)
  -- Get jump label keys from config
  local bafa_config = require("bafa.config").get()
  local ui_config = bafa_config.ui or {}
  local jump_labels_config = ui_config.jump_labels or {}
  local keys = jump_labels_config.keys or {}

  -- Remove duplicates and add uppercase variants
  local unique_keys = {}
  local seen = {}
  for _, key in ipairs(keys) do
    if not seen[key] then
      table.insert(unique_keys, key)
      seen[key] = true
    end
  end

  -- Add uppercase variants
  local all_keys = {}
  for _, key in ipairs(unique_keys) do
    table.insert(all_keys, key)
    local upper = key:upper()
    if upper ~= key and not seen[upper] then
      table.insert(all_keys, upper)
      seen[upper] = true
    end
  end

  -- Map each jump label key to select_by_jump_label
  -- The handler will check if labels are visible and pass through to normal behavior if not
  -- Skip keys that have important default functionality to avoid conflicts
  local keys_to_skip = {
    q = true, -- reject changes and close UI
    u = true, -- undo
    D = true, -- delete buffer, normal mode, visual mode
    dg = true, -- delete buffer jump label
    o = true, -- toggle sorting
    K = true, -- move buffer or selection of buffers up
    J = true, -- move buffer or selection of buffers down
  }

  for _, key in ipairs(all_keys) do
    -- Skip keys that conflict with important functionality
    if not keys_to_skip[key] then
      vim.keymap.set(
        "n",
        key,
        function() ui.select_by_jump_label(key) end,
        get_keymap_opts("Select buffer by jump label")
      )
    end
  end

  -- this should only wait for one additional keypress after gD
  -- so users can press 'gD' then a label key to delete that buffer
  vim.keymap.set(
    "n",
    "dg",
    function() ui.setup_delete_by_label() end,
    get_keymap_opts("Show jump labels and wait for label to delete buffer")
  )
end

return M
