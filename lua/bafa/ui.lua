local Logger = require("bafa.logger")
local Config = require("bafa.config")
local BufferUtils = require("bafa.utils.buffers")
local Keymaps = require("bafa.utils.keymaps")
local Autocmds = require("bafa.utils.autocmds")
local State = require("bafa.utils.state")
local UiUtils = require("bafa.utils.ui")
local Types = require("bafa.types")
local _, Devicons = pcall(require, "nvim-web-devicons")

local BAFA_NS_ID = vim.api.nvim_create_namespace("bafa.nvim")

---@type number|nil
local BAFA_WIN_ID = nil
---@type number|nil
local BAFA_BUF_ID = nil
---@type number|nil
local BAFA_DIAGNOSTIC_AUTOCMD_ID = nil
local MAIN_WINDOW_WIDTH = vim.api.nvim_win_get_width(0)

local DIAGNOSTICS_LABELS = { "Error", "Warn", "Info", "Hint" }
local DIAGNOSTICS_SIGNS = { " ", " ", " ", " " }

local function get_diagnostics(bufnr)
  local count = vim.diagnostic.count(bufnr)
  local diags = {}
  for k, v in pairs(count) do
    local defined_sign = vim.fn.sign_getdefined("DiagnosticSign" .. DIAGNOSTICS_LABELS[k])
    local sign_icon = #defined_sign ~= 0 and defined_sign[1].text or DIAGNOSTICS_SIGNS[k]
    table.insert(diags, { tostring(v) .. sign_icon, "DiagnosticSign" .. DIAGNOSTICS_LABELS[k] })
  end
  return diags
end

--- Calculate the width needed for line numbers column
---@param line_count number The number of lines
---@return number The width needed for the number column (0 if line numbers are off)
local function get_number_column_width(line_count)
  local bafa_config = Config.get()
  if not bafa_config.line_numbers then
    return 0
  end
  if line_count == 0 then
    return 0
  end
  -- Calculate digits needed for the largest line number
  local digits = math.floor(math.log10(line_count)) + 1
  -- Number column width: digits + spacing (typically 1-2 spaces)
  return digits + 2
end

--- Calculate the width needed for diagnostics icons
---@param buffers table[] Array of buffer objects
---@return number The width needed for diagnostics (0 if diagnostics are disabled)
local function get_diagnostics_width(buffers)
  local bafa_config = Config.get()
  if not bafa_config.diagnostics then
    return 0
  end

  local max_diagnostics_width = 0
  for _, buffer in ipairs(buffers) do
    if buffer and buffer.number and vim.api.nvim_buf_is_valid(buffer.number) then
      local diags = get_diagnostics(buffer.number)
      if #diags > 0 then
        -- Build the full diagnostic string as it would appear (all diagnostics concatenated)
        local full_diag_string = ""
        for _, diagnostic in ipairs(diags) do
          full_diag_string = full_diag_string .. diagnostic[1]
        end
        -- Calculate the actual display width of the concatenated diagnostics
        local total_width = vim.fn.strdisplaywidth(full_diag_string)
        if total_width > max_diagnostics_width then
          max_diagnostics_width = total_width
        end
      end
    end
  end

  -- Add padding for spacing between diagnostics and buffer name
  return max_diagnostics_width > 0 and max_diagnostics_width + 2 or 0
end

local get_buffer_icon = function(buffer)
  if Devicons == nil then
    return "", "Normal" -- fallback to default icon, when devicons is not available
  end
  local icon, icon_hl = Devicons.get_icon(buffer.name, buffer.extension, { default = true })
  return icon, icon_hl
end

--- Add highlight to the buffer icon
---@param idx number
---@param buffer table
---@return nil
local add_ft_icon_highlight = function(idx, buffer)
  if BAFA_BUF_ID == nil then
    return
  end
  local _, icon_hl_group = get_buffer_icon(buffer)
  local icon_hl = vim.api.nvim_get_hl(0, { name = icon_hl_group }).fg
  local hl_group = "BafaIcon" .. tostring(idx)
  vim.api.nvim_set_hl(0, hl_group, { fg = string.format("#%06x", icon_hl) })
  vim.api.nvim_buf_set_extmark(BAFA_BUF_ID, BAFA_NS_ID, idx - 1, 2, {
    end_col = 3,
    hl_group = hl_group,
  })
end

--- Colors the buffer name if it is modified
---@param idx number
---@param buffer table
local add_modified_highlight = function(idx, buffer)
  if BAFA_BUF_ID == nil then
    return
  end
  if not buffer.is_modified then
    return
  end
  local bafa_config = Config.get()
  local hl_name = bafa_config.modified_hl or "WarningMsg"

  -- If using a custom highlight group name, ensure it exists or create BafaModified
  if bafa_config.modified_hl then
    local hl = vim.api.nvim_get_hl(0, { name = hl_name, create = false })
    if #hl == 0 then
      -- If the specified highlight group doesn't exist, fallback to WarningMsg
      hl_name = "WarningMsg"
    end
  end

  -- Use extmark to highlight from column 4 to end of line
  vim.api.nvim_buf_set_extmark(BAFA_BUF_ID, BAFA_NS_ID, idx - 1, 4, {
    hl_group = hl_name,
  })
end

---Add diagnostics icons to the buffer line
---@param idx number
---@param buffer table
---@return number count of diagnostics added
local add_diagnostics_icons = function(idx, buffer)
  if BAFA_BUF_ID == nil then
    return
  end
  local count_diagnostics = 0
  local diags = get_diagnostics(buffer.number)
  for _, diagnostic in ipairs(diags) do
    vim.api.nvim_buf_set_extmark(BAFA_BUF_ID, BAFA_NS_ID, idx - 1, 0, {
      virt_text = { { diagnostic[1], diagnostic[2] } },
    })
    count_diagnostics = count_diagnostics + 1
  end
  return count_diagnostics
end

local function close_window()
  if BAFA_WIN_ID == nil or not vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    return
  end
  vim.api.nvim_win_close(BAFA_WIN_ID, true)
  BAFA_WIN_ID = nil
  BAFA_BUF_ID = nil

  -- Clean up diagnostic autocmd
  if BAFA_DIAGNOSTIC_AUTOCMD_ID ~= nil then
    vim.api.nvim_del_autocmd(BAFA_DIAGNOSTIC_AUTOCMD_ID)
    BAFA_DIAGNOSTIC_AUTOCMD_ID = nil
  end
end

-- Refresh the UI from state
local function refresh_ui()
  if BAFA_WIN_ID == nil or not vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    return
  end
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end

  -- Clear existing highlights and extmarks
  vim.api.nvim_buf_clear_namespace(BAFA_BUF_ID, BAFA_NS_ID, 0, -1)

  local working_buffers = State.get_working_buffers()
  local contents = {}

  for idx, buffer in ipairs(working_buffers) do
    local icon, _ = get_buffer_icon(buffer)
    contents[idx] = string.format("  %s %s", icon, buffer.name)
  end

  --- Safely set buffer lines
  --- This is necessary to avoid errors when the buffer is modified externally,
  --- or we are trying to set lines in a non-modifiable buffer.
  pcall(vim.api.nvim_buf_set_lines, BAFA_BUF_ID, 0, -1, false, contents)

  -- Calculate longest buffer name for width calculation
  local longest_buffer_name = 0
  for _, buffer in ipairs(working_buffers) do
    local buffer_name_length = string.len(buffer.name)
    if buffer_name_length > longest_buffer_name then
      longest_buffer_name = buffer_name_length
    end
  end

  for idx, buffer in ipairs(working_buffers) do
    -- add highlights
    add_ft_icon_highlight(idx, buffer)
    -- add modified highlights
    add_modified_highlight(idx, buffer)
    -- add diagnostics
    if Config.get().diagnostics then
      add_diagnostics_icons(idx, buffer)
    end
  end

  -- Update window width if needed
  local bafa_config = Config.get()
  local number_column_width = get_number_column_width(#working_buffers)
  local diagnostics_width = get_diagnostics_width(working_buffers)
  local base_width = longest_buffer_name + 4 -- space for 2 spaces, icon and a space
  base_width = base_width + number_column_width -- add number column width if enabled
  base_width = base_width + diagnostics_width -- add diagnostics width if enabled
  local needed_width = math.min(MAIN_WINDOW_WIDTH, base_width)
  -- Only update width if it's not manually set in config
  if bafa_config.width == nil then
    local current_width = vim.api.nvim_win_get_width(BAFA_WIN_ID)
    if needed_width ~= current_width then
      vim.api.nvim_win_set_width(BAFA_WIN_ID, needed_width)
    end
  end

  -- Update window height if needed
  local max_height = vim.api.nvim_win_get_height(0)
  local needed_height = #working_buffers + 2
  local new_height = math.min(needed_height, max_height)
  -- Only update height if it's not manually set in config
  if bafa_config.height == nil then
    local current_height = vim.api.nvim_win_get_height(BAFA_WIN_ID)
    if new_height ~= current_height then
      vim.api.nvim_win_set_height(BAFA_WIN_ID, new_height)
    end
  end
end

local function create_window()
  local bafa_config = Config.get()
  local bufnr = vim.api.nvim_create_buf(false, false)

  local max_width = vim.api.nvim_win_get_width(0)
  local max_height = vim.api.nvim_win_get_height(0)
  local buffer_longest_name_width = BufferUtils.get_width_longest_buffer_name()
  local buffer_lines = BufferUtils.get_lines_buffer_names()
  -- Get buffers for diagnostics width calculation
  local buffers = BufferUtils.get_buffers_as_table()
  -- Calculate width: buffer name + number column (if enabled) + diagnostics (if enabled) + icon spacing
  local number_column_width = get_number_column_width(buffer_lines)
  local diagnostics_width = get_diagnostics_width(buffers)
  local width = math.min(max_width, buffer_longest_name_width + 4 + number_column_width + diagnostics_width)
  local height = math.min(max_height, buffer_lines + 2)

  BAFA_WIN_ID = vim.api.nvim_open_win(bufnr, true, {
    title = bafa_config.title,
    title_pos = bafa_config.title_pos,
    relative = bafa_config.relative,
    border = bafa_config.border,
    width = bafa_config.width or width,
    height = bafa_config.height or height,
    row = math.floor(((vim.o.lines - (bafa_config.height or height)) / 2) - 1),
    col = math.floor((vim.o.columns - (bafa_config.width or width)) / 2),
    style = bafa_config.style,
  })

  -- NormalFloat will be used by default for floating windows, respecting user's theme

  return {
    bufnr = bufnr,
    win_id = BAFA_WIN_ID,
  }
end

local M = {}

function M.select_menu_item()
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  local selected_buffer = State.get_buffer_at_index(selected_line_number)
  if selected_buffer == nil then
    return
  end

  -- Commit changes before selecting
  M.commit_changes()
  close_window()
  if vim.api.nvim_buf_is_valid(selected_buffer.number) then
    pcall(vim.api.nvim_set_current_buf, selected_buffer.number)
  end
end

---Delete buffer (dd key or D key in normal mode)
---@returns nil
function M.delete_menu_item()
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end

  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  local selected_buffer = State.get_buffer_at_index(selected_line_number)
  if selected_buffer == nil then
    return
  end

  -- Check if buffer is modified and ask for confirmation
  if vim.api.nvim_buf_is_valid(selected_buffer.number) and vim.bo[selected_buffer.number].modified then
    local choice = vim.fn.inputlist({ "Buffer is modified. Delete anyway?", "Yes", "No" })
    if choice ~= 1 then
      return
    end
  end

  -- Remove from state (this caches the deletion)
  if State.delete_buffer_at_index(selected_line_number) then
    refresh_ui()
    -- Move cursor if we deleted the last item
    local working_buffers = State.get_working_buffers()
    if selected_line_number > #working_buffers and #working_buffers > 0 then
      vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { #working_buffers, 0 })
    end
  end
end

---Move buffer up (K key - visual up means line moves up)
---@returns nil
function M.move_buffer_up()
  if BAFA_WIN_ID == nil or not vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    return
  end
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end

  --- Ensure sorting is manual when moving
  M.toggle_sorting(Types.BafaSorting.MANUAL)
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  if State.move_buffer_up(selected_line_number) then
    refresh_ui()
    vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { selected_line_number - 1, 0 })
  end
end

---Move buffer down (J key - visual down means line moves down)
---@returns nil
function M.move_buffer_down()
  if BAFA_WIN_ID == nil or not vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    return
  end
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end

  --- Ensure sorting is manual when moving
  M.toggle_sorting(Types.BafaSorting.MANUAL)
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  if selected_line_number == nil then
    return
  end
  if State.move_buffer_down(selected_line_number) then
    refresh_ui()
    vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { selected_line_number + 1, 0 })
  end
end

---Commit changes (Enter key)
---Deletes buffers that were removed from the list and saves the order
---@returns nil
function M.commit_changes()
  if not State.has_changes() then
    return
  end

  local working_buffers = State.get_working_buffers()

  -- Delete buffers that were removed from the list
  local original_buffers = State.get_original_buffers()
  local working_numbers = {}
  for _, buf in ipairs(working_buffers) do
    working_numbers[buf.number] = true
  end

  local buffers_to_keep = {}
  for _, buf in ipairs(original_buffers) do
    if not working_numbers[buf.number] then
      if vim.api.nvim_buf_is_valid(buf.number) then
        -- Check if modified before deleting
        local should_delete = true
        if vim.bo[buf.number].modified then
          local choice = vim.fn.inputlist({
            string.format('Buffer "%s" is modified. Delete anyway?', buf.name),
            "Yes",
            "No",
          })
          if choice ~= 1 then
            should_delete = false
          end
        end
        if should_delete then
          vim.api.nvim_buf_delete(buf.number, { force = true })
        else
          -- Re-add to working list if user chose not to delete
          table.insert(buffers_to_keep, buf)
        end
      end
    end
  end

  -- Re-add buffers that user chose to keep
  for _, buf in ipairs(buffers_to_keep) do
    State.add_buffer(buf)
  end

  -- Save the order before refreshing state
  State.save_order()

  -- Refresh state with actual buffers after commit (order will be applied in init)
  local new_buffers = BufferUtils.get_buffers_as_table()
  State.init(new_buffers)
end

---Reject changes (Escape key in normal mode)
---Resets state to original buffers
---@returns nil
function M.reject_changes()
  State.reset()
  refresh_ui()
end

---Undo
---Undoes last change
---@returns nil
function M.undo()
  if State.undo() then
    refresh_ui()
  end
end

---Redo
--.Redoes last undone change
--@returns nil
function M.redo()
  if State.redo() then
    refresh_ui()
  end
end

---Refresh UI
---Refreshes the UI from state
---@returns nil
function M.refresh_ui()
  refresh_ui()
end

---Toggle sorting mode
---@param sorting BafaSorting|nil Optional sorting mode to set (manual/auto). If nil, toggles between modes.
---@returns nil
function M.toggle_sorting(sorting)
  local current_sorting_mode = State.get_persisted_sorting()
  if current_sorting_mode == Types.BafaSorting.AUTO and (sorting == nil or sorting == Types.BafaSorting.MANUAL) then
    Logger.notify("Sorting set to: " .. Types.BafaSorting.MANUAL, Logger.INFO)
    State.set_persisted_sorting(Types.BafaSorting.MANUAL)
  elseif current_sorting_mode == Types.BafaSorting.MANUAL and (sorting == nil or sorting == Types.BafaSorting.AUTO) then
    Logger.notify("Sorting set to: " .. Types.BafaSorting.AUTO, Logger.INFO)
    State.set_persisted_sorting(Types.BafaSorting.AUTO)
  else
    Logger.debug("Sorting mode unchanged: " .. current_sorting_mode)
  end
  refresh_ui()
end

---Toggle bafa menu
---@returns nil
function M.toggle()
  if BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    close_window()
    -- Restore cursor when closing the window
    UiUtils.show_cursor()
    return
  end

  -- Before creating the window, hide the cursor
  UiUtils.hide_cursor()

  local win_info = create_window()
  -- Enable cursorline for, otherwise, without a cursor, the user can't see the selection
  UiUtils.enable_cursorline(win_info.win_id)
  BAFA_WIN_ID = win_info.win_id
  BAFA_BUF_ID = win_info.bufnr

  -- Initialize state with current buffers
  local valid_buffers = BufferUtils.get_buffers_as_table()
  State.init(valid_buffers)

  -- Set line numbers based on config
  local bafa_config = Config.get()
  vim.wo[BAFA_WIN_ID].number = bafa_config.line_numbers or false
  vim.api.nvim_buf_set_name(BAFA_BUF_ID, "bafa-menu")
  vim.bo[BAFA_BUF_ID].buftype = "nofile"
  vim.bo[BAFA_BUF_ID].bufhidden = "delete"

  -- Refresh UI from state
  refresh_ui()

  Keymaps.noop(win_info.bufnr)
  Keymaps.defaults(win_info.bufnr)
  Autocmds.defaults(win_info.bufnr)

  -- Set up diagnostic autocmd to refresh UI when diagnostics change
  if Config.get().diagnostics then
    BAFA_DIAGNOSTIC_AUTOCMD_ID = vim.api.nvim_create_autocmd("DiagnosticChanged", {
      callback = function()
        -- Only refresh if window is still open
        if BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
          refresh_ui()
        end
      end,
      desc = "Refresh bafa UI when diagnostics change",
    })
  end
end

return M
