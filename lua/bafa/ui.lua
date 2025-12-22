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

local DIAGNOSTICS_LABELS = { "Error", "Warn", "Info", "Hint" }

---@class BafaDiagnosticInfo
---@field count number
---@field icon string
---@field hl_group string

---Get diagnostics for a buffer
---@param bufnr number The buffer number
---@return BafaDiagnosticInfo[] Array of diagnostics info
local function get_diagnostics(bufnr)
  local count = vim.diagnostic.count(bufnr)
  local diags = {}
  local bafa_config = Config.get()
  local icons = bafa_config.icons and bafa_config.icons.diagnostics or {}

  -- Default fallback icons
  -- These will be used if no sign is defined and no icon is set in config
  -- Matches DIAGNOSTICS_LABELS order
  local default_icons = { " ", " ", " ", " " }

  for k, v in pairs(count) do
    local label = DIAGNOSTICS_LABELS[k]
    local defined_sign = vim.fn.sign_getdefined("DiagnosticSign" .. label)
    local sign_icon

    if #defined_sign ~= 0 then
      sign_icon = defined_sign[1].text
    elseif icons[label] then
      sign_icon = icons[label]
    else
      -- Fallback to default icons if config doesn't have them
      sign_icon = default_icons[k] or " "
    end

    -- Ensure icon has a space after it for proper spacing
    if sign_icon:sub(-1) ~= " " then
      sign_icon = sign_icon .. " "
    end

    table.insert(diags, {
      count = v,
      icon = sign_icon,
      hl_group = "DiagnosticSign" .. label,
    })
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
---@return number max_diagnostics_width The width needed for diagnostics (0 if diagnostics are disabled)
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
          full_diag_string = full_diag_string .. " " .. diagnostic.count .. " " .. diagnostic.icon
        end
        -- Calculate the actual display width of the concatenated diagnostics
        local total_width = vim.fn.strdisplaywidth(full_diag_string)
        if total_width > max_diagnostics_width then
          max_diagnostics_width = total_width
        end
      end
    end
  end
  return max_diagnostics_width > 0 and max_diagnostics_width or 0
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
    hl_mode = "combine", -- Combine with visual selection instead of replacing it
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
    hl_mode = "combine", -- Combine with visual selection instead of replacing it
  })
end

---Add diagnostics icons to the buffer line
---@param idx number
---@param buffer table
---@return number count of diagnostics added
local add_diagnostics_icons = function(idx, buffer)
  if BAFA_BUF_ID == nil then
    return 0
  end
  local count_diagnostics = 0
  local diags = get_diagnostics(buffer.number)
  for _, diagnostic in ipairs(diags) do
    vim.api.nvim_buf_set_extmark(BAFA_BUF_ID, BAFA_NS_ID, idx - 1, 0, {
      virt_text = {
        { tostring(diagnostic.count), diagnostic.hl_group },
        { " ", diagnostic.hl_group },
        { diagnostic.icon, diagnostic.hl_group },
      },
      virt_text_pos = "eol", -- Position at end of line (after padding)
      hl_mode = "combine", -- Combine with visual selection instead of replacing it
    })
    count_diagnostics = count_diagnostics + 1
  end
  return count_diagnostics
end

local function close_window()
  if BAFA_WIN_ID == nil or not vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    return
  end

  -- Save cursor line position (only in manual mode)
  local cursor_pos = vim.api.nvim_win_get_cursor(BAFA_WIN_ID)
  if cursor_pos and cursor_pos[1] then
    State.save_cursor_line(cursor_pos[1])
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
  local bafa_config = Config.get()

  -- First pass: build lines and calculate maximum display width
  local max_display_width = 0
  local line_display_widths = {}

  for idx, buffer in ipairs(working_buffers) do
    local icon, _ = get_buffer_icon(buffer)
    local base_line = string.format("  %s %s", icon, buffer.name)
    local base_width = vim.fn.strdisplaywidth(base_line)

    local diagnostics_width = 0
    if bafa_config.diagnostics then
      diagnostics_width = get_diagnostics_width({ buffer })
    end

    -- Total display width for this line (base + diagnostics)
    local total_width = base_width + diagnostics_width
    line_display_widths[idx] = total_width
    if total_width > max_display_width then
      max_display_width = total_width
    end
  end

  -- Second pass: pad lines to match maximum width
  for idx, buffer in ipairs(working_buffers) do
    local icon, _ = get_buffer_icon(buffer)
    local base_line = string.format("  %s %s", icon, buffer.name)
    local current_width = line_display_widths[idx]
    local padding_needed = max_display_width - current_width

    -- Pad with spaces to match maximum width
    if padding_needed > 0 then
      contents[idx] = base_line .. string.rep(" ", padding_needed)
    else
      contents[idx] = base_line
    end
  end

  -- Briefly make buffer modifiable to set lines
  vim.bo[BAFA_BUF_ID].modifiable = true
  --- This is necessary to avoid errors when the buffer is modified externally
  pcall(vim.api.nvim_buf_set_lines, BAFA_BUF_ID, 0, -1, false, contents)
  -- Set buffer back to non-modifiable
  vim.bo[BAFA_BUF_ID].modifiable = false

  -- Calculate longest buffer name for width calculation
  local longest_buffer_name = 0
  for _, buffer in ipairs(working_buffers) do
    local buffer_name_length = string.len(buffer.name)
    local total_length = buffer_name_length + get_diagnostics_width({ buffer })
    if total_length > longest_buffer_name then
      longest_buffer_name = total_length
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
    -- Visual selection highlighting is handled by Neovim's built-in visual mode
  end

  -- Update window width and height if needed, and re-center
  local number_column_width = get_number_column_width(#working_buffers)
  local base_width = longest_buffer_name + 6 -- space for icon and padding
  base_width = base_width + number_column_width -- add number column width if enabled

  -- Get parent window dimensions based on relative setting
  local max_width = vim.o.columns
  local max_height = vim.o.lines

  -- Calculate needed dimensions, ensuring they don't exceed parent window
  local needed_width = math.min(max_width, base_width)
  local needed_height = math.min(max_height, #working_buffers)

  -- Ensure dimensions don't exceed parent window (safety check)
  needed_width = math.min(needed_width, max_width)
  needed_height = math.min(needed_height, max_height)

  -- Update window dimensions if not manually set in config
  local width_changed = false
  local height_changed = false
  local current_width = vim.api.nvim_win_get_width(BAFA_WIN_ID)
  if needed_width ~= current_width then
    vim.api.nvim_win_set_width(BAFA_WIN_ID, needed_width)
    width_changed = true
  end

  local current_height = vim.api.nvim_win_get_height(BAFA_WIN_ID)
  if needed_height ~= current_height then
    vim.api.nvim_win_set_height(BAFA_WIN_ID, needed_height)
    height_changed = true
  end

  -- Re-center the window after size changes (only if relative is "editor")
  if width_changed or height_changed then
    local final_width = needed_width
    local final_height = needed_height
    local row = math.floor((max_height - final_height) / 2) - 1
    local col = math.floor((max_width - final_width) / 2)

    vim.api.nvim_win_set_config(BAFA_WIN_ID, {
      relative = "editor",
      row = row,
      col = col,
    })
  end
end

local function create_window()
  local bafa_config = Config.get()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].modifiable = false

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
    ---@type BafaConfigTitlesPos
    title_pos = bafa_config.title_pos,
    relative = "editor",
    ---@type BafaConfigBorder
    border = bafa_config.border,
    width = width,
    height = height,
    row = math.floor(((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    ---@type BafaConfigStyle
    style = bafa_config.style,
  })

  return {
    bufnr = bufnr,
    win_id = BAFA_WIN_ID,
  }
end

local M = {}

function M.select_menu_item()
  -- check if working buffers are empty
  -- if so, commit and close
  -- otherwiese the currently open buffer will remain open
  -- and you never can empty the buffer list
  if State.is_working_buffers_empty() then
    -- force close current open buffer
    vim.api.nvim_buf_delete(0, { force = true })
    M.commit_changes()
    close_window()
    return
  end

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

---Get selected buffer indices (either visual selection or single cursor position)
---@return number[] Array of selected line indices (1-indexed)
local function get_selected_indices()
  local indices = {}
  local mode = vim.fn.mode()

  -- Check if we're in visual mode (v, V, or Ctrl-v)
  if mode:match("[vV]") then
    -- Get visual selection range while still in visual mode
    -- Use line("v") for the start of visual selection and line(".") for current position
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    local working_buffers = State.get_working_buffers()

    -- Ensure valid range
    start_line = math.max(1, math.min(start_line, #working_buffers))
    end_line = math.max(1, math.min(end_line, #working_buffers))

    -- Get all lines in selection
    local min_line = math.min(start_line, end_line)
    local max_line = math.max(start_line, end_line)

    for i = min_line, max_line do
      table.insert(indices, i)
    end
  else
    -- Normal mode: just the current line
    local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
    if selected_line_number >= 1 then
      table.insert(indices, selected_line_number)
    end
  end

  return indices
end

---Delete buffer (dd key or D key in normal mode)
---Deletes selected buffers in visual mode, or single buffer in normal mode
---@returns nil
function M.delete_menu_item()
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end

  -- Get selection before exiting visual mode (if in visual mode)
  local was_in_visual_mode = false
  local mode = vim.fn.mode()
  if mode:match("[vV]") then
    was_in_visual_mode = true
  end

  local selected_indices = get_selected_indices()

  -- Exit visual mode if we were in it (before processing deletion)
  if was_in_visual_mode then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  end

  if #selected_indices == 0 then
    return
  end

  local working_buffers = State.get_working_buffers()

  -- Check if any buffers are modified and ask for confirmation
  local modified_buffers = {}
  for _, idx in ipairs(selected_indices) do
    local buffer = working_buffers[idx]
    if buffer and vim.api.nvim_buf_is_valid(buffer.number) and vim.bo[buffer.number].modified then
      table.insert(modified_buffers, buffer.name)
    end
  end

  if #modified_buffers > 0 then
    local message = string.format("%d buffer(s) are modified. Delete anyway?", #modified_buffers)
    if #modified_buffers == 1 then
      message = string.format('Buffer "%s" is modified. Delete anyway?', modified_buffers[1])
    end
    local choice = vim.fn.inputlist({ message, "Yes", "No" })
    if choice ~= 1 then
      return
    end
  end

  -- Delete buffers in reverse order to maintain correct indices
  table.sort(selected_indices, function(a, b)
    return a > b
  end)

  local deleted_count = 0
  for _, idx in ipairs(selected_indices) do
    if State.delete_buffer_at_index(idx) then
      deleted_count = deleted_count + 1
    end
  end

  if deleted_count > 0 then
    refresh_ui()

    -- Move cursor if we deleted the last item(s)
    local new_working_buffers = State.get_working_buffers()
    if #new_working_buffers > 0 and BAFA_WIN_ID ~= nil then
      local max_line = math.max(unpack(selected_indices))
      local new_cursor_line = math.min(max_line, #new_working_buffers)
      vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_cursor_line, 0 })
    end
  end
end

---Move buffer up (K key - visual up means line moves up)
---Supports visual selection: moves selected range as a block
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

  local mode = vim.fn.mode()
  local was_in_visual_mode = mode:match("[vV]")

  -- Get selection indices
  local selected_indices = get_selected_indices()
  local moved = false
  local new_cursor_line

  if was_in_visual_mode and #selected_indices > 1 then
    -- Move range as a block
    local start_idx = math.min(unpack(selected_indices))
    local end_idx = math.max(unpack(selected_indices))
    local range_size = end_idx - start_idx + 1

    if State.move_buffer_range_up(start_idx, end_idx) then
      -- Calculate new selection positions (moved up by 1)
      local new_start_idx = math.max(1, start_idx - 1)
      local new_end_idx = new_start_idx + range_size - 1

      -- Refresh UI first to update buffer contents
      refresh_ui()

      -- Restore visual selection at new positions
      -- Use a deferred callback to ensure UI is refreshed first
      vim.schedule(function()
        if
          BAFA_WIN_ID ~= nil
          and vim.api.nvim_win_is_valid(BAFA_WIN_ID)
          and BAFA_BUF_ID ~= nil
          and vim.api.nvim_buf_is_valid(BAFA_BUF_ID)
        then
          -- Set visual selection marks (bufnum, lnum, col, off)
          vim.fn.setpos("'<", { BAFA_BUF_ID, new_start_idx, 1, 0 })
          vim.fn.setpos("'>", { BAFA_BUF_ID, new_end_idx, 1, 0 })
          -- Set cursor to start of selection
          vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_start_idx, 0 })
          -- Re-enter visual mode
          vim.cmd("normal! gv")
        end
      end)
      return -- Early return since refresh_ui is called above
    end
  else
    -- Single buffer move
    local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
    if State.move_buffer_up(selected_line_number) then
      moved = true
      new_cursor_line = selected_line_number - 1
    end
  end

  if moved then
    refresh_ui()
    if new_cursor_line and BAFA_WIN_ID ~= nil then
      vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_cursor_line, 0 })
    end
  end
end

---Move buffer down (J key - visual down means line moves down)
---Supports visual selection: moves selected range as a block
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

  local mode = vim.fn.mode()
  local was_in_visual_mode = mode:match("[vV]")

  -- Get selection indices
  local selected_indices = get_selected_indices()
  local moved = false
  local new_cursor_line

  if was_in_visual_mode and #selected_indices > 1 then
    -- Move range as a block
    local start_idx = math.min(unpack(selected_indices))
    local end_idx = math.max(unpack(selected_indices))
    local range_size = end_idx - start_idx + 1

    if State.move_buffer_range_down(start_idx, end_idx) then
      -- Calculate new selection positions (moved down by 1)
      local new_start_idx = start_idx + 1
      local new_end_idx = new_start_idx + range_size - 1

      -- Refresh UI first to update buffer contents
      refresh_ui()

      -- Restore visual selection at new positions
      -- Use a deferred callback to ensure UI is refreshed first
      vim.schedule(function()
        if
          BAFA_WIN_ID ~= nil
          and vim.api.nvim_win_is_valid(BAFA_WIN_ID)
          and BAFA_BUF_ID ~= nil
          and vim.api.nvim_buf_is_valid(BAFA_BUF_ID)
        then
          local working_buffers = State.get_working_buffers()
          -- Clamp to valid range
          new_end_idx = math.min(new_end_idx, #working_buffers)
          -- Set visual selection marks (bufnum, lnum, col, off)
          vim.fn.setpos("'<", { BAFA_BUF_ID, new_start_idx, 1, 0 })
          vim.fn.setpos("'>", { BAFA_BUF_ID, new_end_idx, 1, 0 })
          -- Set cursor to start of selection
          vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_start_idx, 0 })
          -- Re-enter visual mode
          vim.cmd("normal! gv")
        end
      end)
      return -- Early return since refresh_ui is called above
    end
  else
    -- Single buffer move
    local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
    if selected_line_number == nil then
      return
    end
    if State.move_buffer_down(selected_line_number) then
      moved = true
      new_cursor_line = selected_line_number + 1
    end
  end

  if moved then
    refresh_ui()
    if new_cursor_line and BAFA_WIN_ID ~= nil then
      local working_buffers = State.get_working_buffers()
      new_cursor_line = math.min(new_cursor_line, #working_buffers)
      vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_cursor_line, 0 })
    end
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
    UiUtils.revert_patches()
    return
  end

  -- Before creating the window, hide the cursor
  UiUtils.apply_patches()

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

  -- Restore cursor line position (only in manual mode, with bounds checking)
  local working_buffers = State.get_working_buffers()
  local max_line = #working_buffers
  if max_line > 0 then
    local saved_cursor_line = State.get_persisted_cursor_line(max_line)
    if saved_cursor_line ~= nil and BAFA_WIN_ID ~= nil then
      vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { saved_cursor_line, 0 })
    end
  end

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
