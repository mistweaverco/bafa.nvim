local Keys = require("bafa.utils.keys")
local Modes = require("bafa.utils.modes")
local TableUtils = require("bafa.utils.table")

local M = {}

-- Shared options to ensure we override everything
local BASE_KEYMAP_OPTS = {
  buffer = 0,
  nowait = true,
  silent = true,
  remap = false,
}

function M.defaults()
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

  -- Commit changes without closing (localleader + w)
  vim.keymap.set(
    "n",
    Keys.localleader .. "w",
    function() ui.commit_changes_and_refresh() end,
    get_keymap_opts("Commit changes and refresh UI")
  )
  -- Commit changes and close (localleader + W)
  vim.keymap.set(
    "n",
    Keys.localleader .. "W",
    function() ui.commit_changes_and_close() end,
    get_keymap_opts("Commit changes and close UI")
  )

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
  vim.keymap.set("n", "<CR>", function() ui.select_menu_item() end, get_keymap_opts("Select highlighted buffer"))

  -- Force normal visual mode to be linewise
  vim.keymap.set("n", "v", function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("V", true, false, true), "n", false)
    ui.hide_jump_labels()
  end, get_keymap_opts("Enter linewise visual mode", { nowait = true, noremap = false }))
  -- Exit visual mode, when in visual mode and 'v' is pressed
  vim.keymap.set(
    "v",
    "v",
    function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false) end,
    get_keymap_opts("Exit visual mode", { nowait = true, noremap = false })
  )

  -- Disable jump labels when visual mode is entered
  vim.keymap.set("n", "V", function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("V", true, false, true), "n", false)
    ui.hide_jump_labels()
  end, get_keymap_opts("Disable jump labels on visual mode exit", { nowait = true, noremap = false }))

  -- Delete buffer
  vim.keymap.set({ "n", "v" }, "d", function() ui.delete_menu_item() end, get_keymap_opts("Delete selected buffer"))
  -- Move buffer up (swap with previous)
  vim.keymap.set({ "n", "v" }, "K", function() ui.move_buffer_up() end, get_keymap_opts("Move selected buffer up"))
  -- Move buffer down (swap with next)
  vim.keymap.set({ "n", "v" }, "J", function() ui.move_buffer_down() end, get_keymap_opts("Move selected buffer down"))
  -- Toggle sorting
  vim.keymap.set("n", "o", function() ui.toggle_sorting() end, get_keymap_opts("Toggle buffer sorting"))
  -- Undo
  vim.keymap.set("n", "u", function() ui.undo() end, get_keymap_opts("Undo last change"))
  -- Redo
  vim.keymap.set("n", "<C-r>", function() ui.redo() end, get_keymap_opts("Redo last undone change"))

  -- Jump labels: show labels when g is pressed
  -- This allows users to press 'g' then a label key to quickly jump to a buffer
  vim.keymap.set("n", "g", function() ui.toggle_jump_labels() end, get_keymap_opts("Show jump labels"))

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
    -- skip protected keys
    if not TableUtils.contains(Keys.protected_jump_label_keys, key) then table.insert(all_keys, key) end
    local upper = key:upper()
    if not TableUtils.contains(Keys.protected_jump_label_keys, upper) and not seen[upper] then
      table.insert(all_keys, upper)
      seen[upper] = true
    end
  end

  for _, key in ipairs(all_keys) do
    vim.keymap.set(
      "n",
      key,
      function() ui.select_by_jump_label(key) end,
      get_keymap_opts("Select buffer by jump label " .. key, { nowait = false, noremap = false })
    )
  end
end

return M
