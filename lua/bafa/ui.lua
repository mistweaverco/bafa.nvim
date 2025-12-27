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

-- Sign names for bafa
local BAFA_SIGN_MODIFIED = "BafaModified"
local BAFA_SIGN_DELETED = "BafaDeleted"

---Get highlight group with fallback chain
---@param config_hl string|nil The configured highlight group
---@param fallbacks string[] Array of fallback highlight groups to try
---@param create_fallback string|nil Optional name for a fallback highlight to create if none exist
---@param create_fallback_color string|nil Optional color for the fallback highlight
---@return string The highlight group to use
local function get_hl_with_fallback(config_hl, fallbacks, create_fallback, create_fallback_color)
  -- If config specifies a highlight group, check if it exists
  if config_hl and vim.fn.hlexists(config_hl) == 1 then
    return config_hl
  end

  -- Try fallbacks in order
  for _, fallback_hl in ipairs(fallbacks) do
    if vim.fn.hlexists(fallback_hl) == 1 then
      return fallback_hl
    end
  end

  -- Last resort: create a fallback highlight if specified
  if create_fallback and create_fallback_color then
    vim.api.nvim_set_hl(0, create_fallback, { fg = create_fallback_color })
    return create_fallback
  end

  -- Return the first fallback as default (even if it doesn't exist)
  return fallbacks[1] or config_hl or "Normal"
end

---Initialize signs for bafa
---Defines signs for modified and deleted states using configurable highlight groups
local function init_signs()
  -- Get sign text from config, default to "┃"
  local bafa_config = Config.get()
  local icons_config = bafa_config.icons or {}
  local sign_config = icons_config.sign or {}
  local sign_text = sign_config.changes or "┃"

  -- Get highlight groups from config with fallbacks
  local hl_config = bafa_config.hl or {}
  local sign_hl_config = hl_config.sign or {}

  -- Get modified sign highlight
  local modified_sign_hl =
    get_hl_with_fallback(sign_hl_config.modified, { "GitSignsChange", "DiffChange" }, "BafaModifiedSign", "#fabd2f")

  -- Get deleted sign highlight
  local deleted_sign_hl =
    get_hl_with_fallback(sign_hl_config.deleted, { "GitSignsDelete", "DiffDelete" }, "BafaDeletedSign", "#fb4934")

  -- Define sign for modified buffers
  vim.fn.sign_define(BAFA_SIGN_MODIFIED, {
    text = sign_text,
    texthl = modified_sign_hl,
    numhl = "",
    linehl = "",
  })

  -- Define sign for deleted buffers
  vim.fn.sign_define(BAFA_SIGN_DELETED, {
    text = sign_text,
    texthl = deleted_sign_hl,
    numhl = "",
    linehl = "",
  })
end

---Check if a buffer is marked for deletion
---A buffer is marked for deletion if it's in original_buffers but not in working_buffers
---@param buffer table The buffer to check
---@return boolean True if buffer is marked for deletion
local function is_buffer_marked_for_deletion(buffer)
  if not buffer or not buffer.number then
    return false
  end

  local original_buffers = State.get_original_buffers()
  local working_buffers = State.get_working_buffers()

  -- Create a set of working buffer numbers for quick lookup
  local working_numbers = {}
  for _, buf in ipairs(working_buffers) do
    if buf and buf.number then
      working_numbers[buf.number] = true
    end
  end

  -- Check if this buffer is in original but not in working
  for _, orig_buf in ipairs(original_buffers) do
    if orig_buf and orig_buf.number == buffer.number then
      -- Found in original, check if it's missing from working
      return not working_numbers[buffer.number]
    end
  end

  return false
end

---Check if a buffer is modified (has unsaved changes)
---@param buffer table The buffer to check
---@return boolean True if buffer is modified
local function is_buffer_modified(buffer)
  if not buffer or not buffer.number or not vim.api.nvim_buf_is_valid(buffer.number) then
    return false
  end

  local success, is_modified = pcall(function()
    return vim.bo[buffer.number].modified
  end)

  return success and is_modified or false
end

---Place signs for a buffer line
---Shows sign(s) colored based on buffer state (modified and/or marked for deletion)
---Can show both signs if buffer is both modified and marked for deletion
---@param idx number Line index (1-indexed)
---@param buffer table The buffer to check
local function update_buffer_sign(idx, buffer)
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end

  if not buffer or not buffer.number then
    return
  end

  local is_deleted = is_buffer_marked_for_deletion(buffer)
  local is_mod = is_buffer_modified(buffer)

  -- Use unique IDs for each sign type to allow both to be placed on the same line
  -- ID format: line_number * 10 + sign_type_offset (1 for deleted, 2 for modified)
  local deleted_sign_id = idx * 10 + 1
  local modified_sign_id = idx * 10 + 2

  -- Place deleted sign if marked for deletion
  if is_deleted then
    vim.fn.sign_place(deleted_sign_id, "bafa", BAFA_SIGN_DELETED, BAFA_BUF_ID, { lnum = idx, priority = 10 })
  end

  -- Place modified sign if modified (can be shown alongside deleted sign)
  if is_mod then
    vim.fn.sign_place(modified_sign_id, "bafa", BAFA_SIGN_MODIFIED, BAFA_BUF_ID, { lnum = idx, priority = 11 })
  end
end

---@class BafaDiagnosticInfo
---@field count number
---@field icon string
---@field hl_group string

---Get diagnostics for a buffer
---@param bufnr number The buffer number
---@return BafaDiagnosticInfo[] Array of diagnostics info
local function get_diagnostics(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local success, count = pcall(vim.diagnostic.count, bufnr)
  if not success or not count then
    return {}
  end
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

--- Calculate the width needed for signs column
---Accounts for the maximum number of signs needed (0, 1, or 2)
---Neovim reserves: 0 columns for no signs, 2 columns for 1 sign, 4 columns for 2 signs
---@param max_signs number Maximum number of signs needed (0, 1, or 2)
---@return number The width needed for the signs column
local function get_sign_column_width(max_signs)
  if max_signs == 0 then
    return 0
  elseif max_signs == 1 then
    -- Neovim reserves 2 columns for 1 sign (1 for sign + 1 for spacing)
    return 2
  else
    -- Neovim reserves 4 columns for 2 signs (2 for signs + 2 for spacing)
    return 4
  end
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
      local success, diags = pcall(get_diagnostics, buffer.number)
      if success and diags and #diags > 0 then
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
  if not buffer or not buffer.name then
    return "", "Normal"
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
  if not buffer or not buffer.number or not vim.api.nvim_buf_is_valid(buffer.number) then
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

---Add diagnostics icons to the buffer line
---@param idx number
---@param buffer table
---@return number count of diagnostics added
local add_diagnostics_icons = function(idx, buffer)
  if BAFA_BUF_ID == nil then
    return 0
  end
  if not buffer or not buffer.number or not vim.api.nvim_buf_is_valid(buffer.number) then
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

  -- Clear signs before closing
  if BAFA_BUF_ID ~= nil and vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    vim.fn.sign_unplace("bafa", { buffer = BAFA_BUF_ID })
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

  -- Clear existing signs
  if BAFA_BUF_ID ~= nil and vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    vim.fn.sign_unplace("bafa", { buffer = BAFA_BUF_ID })
  end

  local working_buffers = State.get_working_buffers()

  -- Remove invalid buffers from state (buffers that were removed externally)
  -- Do this in reverse order to maintain correct indices
  for i = #working_buffers, 1, -1 do
    local buffer = working_buffers[i]
    if not buffer or not buffer.number or not vim.api.nvim_buf_is_valid(buffer.number) then
      State.delete_buffer_at_index(i)
    end
  end

  -- Use display_order from state (includes both working and deleted buffers in moved order)
  local display_buffers = State.get_display_order()

  -- Filter out invalid buffers from display_order
  local valid_display_buffers = {}
  for _, buf in ipairs(display_buffers) do
    if buf and buf.number and vim.api.nvim_buf_is_valid(buf.number) then
      table.insert(valid_display_buffers, buf)
    end
  end
  display_buffers = valid_display_buffers

  local contents = {}
  local bafa_config = Config.get()

  -- First pass: determine maximum number of signs needed and build lines
  local max_signs_needed = 0
  local max_display_width = 0
  local line_display_widths = {}

  for idx, buffer in ipairs(display_buffers) do
    -- Count signs needed for this buffer
    if buffer and buffer.number and vim.api.nvim_buf_is_valid(buffer.number) then
      -- Check actual buffer modified state (not cached)
      local success, is_modified = pcall(function()
        return vim.bo[buffer.number].modified
      end)
      if success then
        buffer.is_modified = is_modified
      end

      local sign_count = 0
      if is_buffer_marked_for_deletion(buffer) then
        sign_count = sign_count + 1
      end
      if is_buffer_modified(buffer) then
        sign_count = sign_count + 1
      end
      if sign_count > max_signs_needed then
        max_signs_needed = sign_count
      end
    end
    -- Skip invalid buffers (shouldn't happen after filtering, but safety check)
    if buffer and buffer.number and vim.api.nvim_buf_is_valid(buffer.number) then
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
  end

  -- Second pass: pad lines to match maximum width
  for idx, buffer in ipairs(display_buffers) do
    -- Skip invalid buffers (shouldn't happen after filtering, but safety check)
    if buffer and buffer.number and vim.api.nvim_buf_is_valid(buffer.number) then
      local icon, _ = get_buffer_icon(buffer)
      local base_line = string.format("  %s %s", icon, buffer.name)
      local current_width = line_display_widths[idx] or 0
      local padding_needed = max_display_width - current_width

      -- Pad with spaces to match maximum width
      if padding_needed > 0 then
        contents[idx] = base_line .. string.rep(" ", padding_needed)
      else
        contents[idx] = base_line
      end
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
  for _, buffer in ipairs(display_buffers) do
    -- Skip invalid buffers (shouldn't happen after filtering, but safety check)
    if buffer and buffer.number and vim.api.nvim_buf_is_valid(buffer.number) then
      local buffer_name_length = string.len(buffer.name)
      local total_length = buffer_name_length + get_diagnostics_width({ buffer })
      if total_length > longest_buffer_name then
        longest_buffer_name = total_length
      end
    end
  end

  -- Set signcolumn based on maximum signs needed (calculated in first pass above)
  -- This must be done before calculating window width so the sign column space is properly reserved
  if BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    if max_signs_needed == 0 then
      vim.wo[BAFA_WIN_ID].signcolumn = "no"
    elseif max_signs_needed == 1 then
      vim.wo[BAFA_WIN_ID].signcolumn = "yes:1"
    else
      vim.wo[BAFA_WIN_ID].signcolumn = "yes:2"
    end
  end

  for idx, buffer in ipairs(display_buffers) do
    -- Skip invalid buffers (shouldn't happen after filtering, but safety check)
    if buffer and buffer.number and vim.api.nvim_buf_is_valid(buffer.number) then
      -- Update the cached is_modified state from the actual buffer
      local success, is_modified = pcall(function()
        return vim.bo[buffer.number].modified
      end)
      if success then
        buffer.is_modified = is_modified
      end
      -- add highlights
      add_ft_icon_highlight(idx, buffer)
      -- add signs (gitsigns-like UX)
      update_buffer_sign(idx, buffer)
      -- add diagnostics
      if Config.get().diagnostics then
        add_diagnostics_icons(idx, buffer)
      end
      -- Visual selection highlighting is handled by Neovim's built-in visual mode
    end
  end

  -- Update window width and height if needed, and re-center
  local number_column_width = get_number_column_width(#display_buffers)
  -- Calculate sign column width based on actual number of signs needed (0, 1, or 2)
  -- This ensures the window width accounts for the reserved sign column space
  local sign_column_width = get_sign_column_width(max_signs_needed)
  local base_width = longest_buffer_name + 6 -- space for icon and padding
  base_width = base_width + number_column_width -- add number column width if enabled
  base_width = base_width + sign_column_width -- add sign column width (0, 1, or 2 signs worth of space)

  -- Get parent window dimensions based on relative setting
  local max_width = vim.o.columns
  local max_height = vim.o.lines

  -- Calculate needed dimensions, ensuring they don't exceed parent window
  local needed_width = math.min(max_width, base_width)
  local needed_height = math.min(max_height, #display_buffers)

  -- Ensure dimensions don't exceed parent window (safety check)
  needed_width = math.min(needed_width, max_width)
  needed_height = math.min(needed_height, max_height)

  -- Update window dimensions
  -- Get current dimensions after signcolumn has been set (it may have changed the layout)
  local current_width = vim.api.nvim_win_get_width(BAFA_WIN_ID)
  local current_height = vim.api.nvim_win_get_height(BAFA_WIN_ID)

  local width_changed = false
  local height_changed = false

  -- Always update width if it differs (accounting for sign column changes)
  if math.abs(needed_width - current_width) > 0 then
    vim.api.nvim_win_set_width(BAFA_WIN_ID, needed_width)
    width_changed = true
  end

  if needed_height ~= current_height then
    vim.api.nvim_win_set_height(BAFA_WIN_ID, needed_height)
    height_changed = true
  end

  -- Re-center the window after size changes (only if relative is "editor")
  -- Always re-center if dimensions changed to ensure proper positioning
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
  -- Calculate width: buffer name + number column (if enabled) + sign column + diagnostics (if enabled) + icon spacing
  -- For initial window creation, we assume max 2 signs might be needed
  local number_column_width = get_number_column_width(buffer_lines)
  local sign_column_width = get_sign_column_width(2) -- Assume max 2 signs for initial sizing
  local diagnostics_width = get_diagnostics_width(buffers)
  local width =
    math.min(max_width, buffer_longest_name_width + 4 + number_column_width + sign_column_width + diagnostics_width)
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

---Get buffer at display index (accounting for both working and deleted buffers)
---@param display_idx number Display line index (1-indexed)
---@return table|nil The buffer at the display index, or nil if out of bounds
local function get_buffer_at_display_index(display_idx)
  -- Use display_order from state (includes both working and deleted buffers in moved order)
  local display_buffers = State.get_display_order()

  -- Filter out invalid buffers
  local valid_display_buffers = {}
  for _, buf in ipairs(display_buffers) do
    if buf and buf.number and vim.api.nvim_buf_is_valid(buf.number) then
      table.insert(valid_display_buffers, buf)
    end
  end

  return valid_display_buffers[display_idx]
end

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
  local selected_buffer = get_buffer_at_display_index(selected_line_number)
  if selected_buffer == nil or not selected_buffer.number then
    return
  end

  -- If the selected buffer is marked for deletion, restore it first
  if is_buffer_marked_for_deletion(selected_buffer) then
    State.add_buffer(selected_buffer)
    refresh_ui()
    -- After restoring, the buffer is now in working_buffers, so we can proceed
    -- But we need to get the updated position since the list changed
    local working_buffers = State.get_working_buffers()
    for idx, buf in ipairs(working_buffers) do
      if buf and buf.number == selected_buffer.number then
        selected_line_number = idx
        break
      end
    end
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

  -- Create a map of working buffer numbers to their indices for quick lookup
  local working_buffer_map = {}
  for i, buf in ipairs(working_buffers) do
    if buf and buf.number then
      working_buffer_map[buf.number] = i
    end
  end

  -- Use display_order from state (includes both working and deleted buffers)
  local display_buffers = State.get_display_order()

  -- Filter out invalid buffers to ensure correct indexing
  local valid_display_buffers = {}
  for _, buf in ipairs(display_buffers) do
    if buf and buf.number and vim.api.nvim_buf_is_valid(buf.number) then
      table.insert(valid_display_buffers, buf)
    end
  end

  -- Convert display indices to working buffer indices
  -- Toggle behavior: if buffer is already marked for deletion, restore it; otherwise delete it
  local working_indices_to_delete = {}
  local restored_count = 0
  for _, display_idx in ipairs(selected_indices) do
    -- Ensure index is within bounds of valid display buffers
    if display_idx >= 1 and display_idx <= #valid_display_buffers then
      -- Use valid_display_buffers for indexing
      local buffer = valid_display_buffers[display_idx]
      if buffer and buffer.number then
        -- Check if buffer is already marked for deletion
        if is_buffer_marked_for_deletion(buffer) then
          -- Buffer is already marked for deletion, restore it (toggle off)
          State.add_buffer(buffer)
          restored_count = restored_count + 1
        elseif working_buffer_map[buffer.number] then
          -- Buffer is in working list, add its working index for deletion (toggle on)
          table.insert(working_indices_to_delete, working_buffer_map[buffer.number])
        end
      end
    end
  end

  -- Delete buffers in reverse order to maintain correct indices
  table.sort(working_indices_to_delete, function(a, b)
    return a > b
  end)

  local deleted_count = 0
  for _, working_idx in ipairs(working_indices_to_delete) do
    if State.delete_buffer_at_index(working_idx) then
      deleted_count = deleted_count + 1
    end
  end

  if deleted_count > 0 or restored_count > 0 then
    refresh_ui()

    -- Update cursor position if needed
    -- Get display buffers to find the correct line number
    local new_working_buffers = State.get_working_buffers()
    local new_original_buffers = State.get_original_buffers()

    -- Build display buffers to get correct line count
    local new_working_buffer_map = {}
    for _, buf in ipairs(new_working_buffers) do
      if buf and buf.number then
        new_working_buffer_map[buf.number] = true
      end
    end

    local new_display_count = 0
    for _, orig_buf in ipairs(new_original_buffers) do
      if orig_buf and orig_buf.number then
        if new_working_buffer_map[orig_buf.number] or vim.api.nvim_buf_is_valid(orig_buf.number) then
          new_display_count = new_display_count + 1
        end
      end
    end

    if new_display_count > 0 and BAFA_WIN_ID ~= nil then
      -- Keep cursor at the same display line if possible, or move to last line
      local max_line = math.max(unpack(selected_indices))
      local new_cursor_line = math.min(max_line, new_display_count)
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

  -- Get selection indices (these are display indices)
  local selected_indices = get_selected_indices()
  local moved = false
  local new_cursor_line

  if was_in_visual_mode and #selected_indices > 1 then
    -- Move range as a block in display order
    local start_display_idx = math.min(unpack(selected_indices))
    local end_display_idx = math.max(unpack(selected_indices))
    local range_size = end_display_idx - start_display_idx + 1

    if State.move_range_in_display_order(start_display_idx, end_display_idx, "up") then
      -- Calculate new selection positions (moved up by 1)
      local new_start_display_idx = math.max(1, start_display_idx - 1)
      local new_end_display_idx = new_start_display_idx + range_size - 1

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
          vim.fn.setpos("'<", { BAFA_BUF_ID, new_start_display_idx, 1, 0 })
          vim.fn.setpos("'>", { BAFA_BUF_ID, new_end_display_idx, 1, 0 })
          -- Set cursor to start of selection
          vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_start_display_idx, 0 })
          -- Re-enter visual mode
          vim.cmd("normal! gv")
        end
      end)
      return -- Early return since refresh_ui is called above
    end
  else
    -- Single buffer move in display order
    local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]

    if State.move_in_display_order(selected_line_number, "up") then
      moved = true
      new_cursor_line = math.max(1, selected_line_number - 1)
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

  -- Get selection indices (these are display indices)
  local selected_indices = get_selected_indices()
  local moved = false
  local new_cursor_line

  if was_in_visual_mode and #selected_indices > 1 then
    -- Move range as a block in display order
    local start_display_idx = math.min(unpack(selected_indices))
    local end_display_idx = math.max(unpack(selected_indices))
    local range_size = end_display_idx - start_display_idx + 1

    if State.move_range_in_display_order(start_display_idx, end_display_idx, "down") then
      -- Calculate new selection positions (moved down by 1)
      local display_order = State.get_display_order()
      local max_display_idx = #display_order
      local new_start_display_idx = math.min(max_display_idx, start_display_idx + 1)
      local new_end_display_idx = math.min(max_display_idx, new_start_display_idx + range_size - 1)

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
          vim.fn.setpos("'<", { BAFA_BUF_ID, new_start_display_idx, 1, 0 })
          vim.fn.setpos("'>", { BAFA_BUF_ID, new_end_display_idx, 1, 0 })
          -- Set cursor to start of selection
          vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_start_display_idx, 0 })
          -- Re-enter visual mode
          vim.cmd("normal! gv")
        end
      end)
      return -- Early return since refresh_ui is called above
    end
  else
    -- Single buffer move in display order
    local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
    if selected_line_number == nil then
      return
    end

    local display_order = State.get_display_order()
    if State.move_in_display_order(selected_line_number, "down") then
      moved = true
      new_cursor_line = math.min(#display_order, selected_line_number + 1)
    end
  end

  if moved then
    refresh_ui()
    if new_cursor_line and BAFA_WIN_ID ~= nil then
      vim.api.nvim_win_set_cursor(BAFA_WIN_ID, { new_cursor_line, 0 })
    end
  end
end

---Commit changes (Enter key)
---Deletes buffers that were removed from the list and saves the order
---@returns nil
---Commit changes (deletes buffers, saves order)
---@param on_complete function|nil Optional callback to call after commit completes
function M.commit_changes(on_complete)
  if not State.has_changes() then
    if on_complete then
      on_complete()
    end
    return
  end

  local working_buffers = State.get_working_buffers()

  -- Delete buffers that were removed from the list
  local original_buffers = State.get_original_buffers()
  -- Use paths for comparison since buffer numbers can change
  local working_paths = {}
  for _, buf in ipairs(working_buffers) do
    if buf and buf.path and buf.path ~= "" then
      working_paths[buf.path] = buf
    end
  end

  local buffers_to_delete = {}
  for _, buf in ipairs(original_buffers) do
    if buf and buf.path and buf.path ~= "" then
      if not working_paths[buf.path] then
        -- Buffer was removed from working list, mark it for deletion
        -- Find the current buffer with this path (buffer number might have changed)
        local current_buf = nil
        local all_buffers = vim.api.nvim_list_bufs()
        for _, bufnr in ipairs(all_buffers) do
          if vim.api.nvim_buf_is_valid(bufnr) then
            local success, buffer_name = pcall(vim.api.nvim_buf_get_name, bufnr)
            if success and buffer_name == buf.path then
              current_buf = {
                number = bufnr,
                path = buf.path,
                name = buf.name,
              }
              break
            end
          end
        end
        -- If we found a current buffer with this path, add it to deletion list
        -- Otherwise, use the original buffer info (it might have been deleted already)
        if current_buf then
          table.insert(buffers_to_delete, current_buf)
        elseif buf.number and vim.api.nvim_buf_is_valid(buf.number) then
          table.insert(buffers_to_delete, buf)
        end
      end
    end
  end

  -- Check if any buffers to delete are modified and ask for confirmation
  local modified_buffers = {}
  for _, buf in ipairs(buffers_to_delete) do
    if vim.api.nvim_buf_is_valid(buf.number) then
      local success, is_modified = pcall(function()
        return vim.bo[buf.number].modified
      end)
      if success and is_modified then
        table.insert(modified_buffers, buf)
      end
    end
  end

  if #modified_buffers > 0 then
    local prompt_message
    if #modified_buffers == 1 then
      prompt_message = string.format("%s has unsaved changes, really delete?", modified_buffers[1].name or "unknown")
    else
      prompt_message = string.format("%d buffers have unsaved changes, really delete?", #modified_buffers)
    end

    vim.ui.select({ "No", "Yes" }, {
      prompt = prompt_message,
    }, function(choice)
      if choice ~= "Yes" then
        -- User cancelled or chose No, restore all buffers that were to be deleted
        for _, buf in ipairs(buffers_to_delete) do
          State.add_buffer(buf)
        end
        if on_complete then
          on_complete()
        end
        return
      end

      -- User confirmed, delete all buffers that were removed from the list
      -- First, check all windows and switch away from buffers that will be deleted
      local deleted_paths = {}
      for _, buf in ipairs(buffers_to_delete) do
        if buf and buf.path then
          deleted_paths[buf.path] = buf
        end
      end

      -- Find a buffer to switch to that's not being deleted
      local switch_to_buf = nil
      for _, buf in ipairs(working_buffers) do
        if buf and buf.path and buf.path ~= "" and not deleted_paths[buf.path] then
          -- Find the current buffer with this path
          local all_buffers = vim.api.nvim_list_bufs()
          for _, bufnr in ipairs(all_buffers) do
            if vim.api.nvim_buf_is_valid(bufnr) then
              local success, buffer_name = pcall(vim.api.nvim_buf_get_name, bufnr)
              if success and buffer_name == buf.path then
                switch_to_buf = bufnr
                break
              end
            end
          end
          if switch_to_buf then
            break
          end
        end
      end

      -- Close bafa window only if all buffers are being deleted (no buffer to switch to)
      if not switch_to_buf and BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
        close_window()
        -- Ensure the window is fully closed before proceeding
        BAFA_WIN_ID = nil
        BAFA_BUF_ID = nil
      end

      -- Check all windows and switch any that are displaying buffers to be deleted
      local all_windows = vim.api.nvim_list_wins()
      for _, win_id in ipairs(all_windows) do
        if vim.api.nvim_win_is_valid(win_id) then
          local win_buf = vim.api.nvim_win_get_buf(win_id)
          local win_buf_will_be_deleted = false
          for _, buf in ipairs(buffers_to_delete) do
            if buf.number == win_buf then
              win_buf_will_be_deleted = true
              break
            end
          end

          if win_buf_will_be_deleted then
            if switch_to_buf and vim.api.nvim_buf_is_valid(switch_to_buf) then
              -- Switch to a buffer that's not being deleted
              pcall(vim.api.nvim_win_set_buf, win_id, switch_to_buf)
            else
              -- All buffers are being deleted, force delete the current buffer in this window
              pcall(vim.api.nvim_buf_delete, win_buf, { force = true })
            end
          end
        end
      end

      -- Now delete all buffers (nvim_buf_delete with force=true will handle any remaining issues)
      for _, buf in ipairs(buffers_to_delete) do
        if buf.number and vim.api.nvim_buf_is_valid(buf.number) then
          pcall(vim.api.nvim_buf_delete, buf.number, { force = true })
        end
      end

      -- Refresh state with actual buffers after commit (order will be applied in init)
      -- Use vim.schedule to ensure buffers are fully deleted before getting the list
      vim.schedule(function()
        local new_buffers = BufferUtils.get_buffers_as_table()
        -- Filter out any buffers that were supposed to be deleted (in case they're still in the list)
        local deleted_paths_async = {}
        for _, buf in ipairs(buffers_to_delete) do
          if buf and buf.path then
            deleted_paths_async[buf.path] = true
          end
        end
        local filtered_buffers = {}
        for _, buf in ipairs(new_buffers) do
          if buf and buf.path and not deleted_paths_async[buf.path] then
            table.insert(filtered_buffers, buf)
          end
        end
        State.init(filtered_buffers)

        -- Save the order AFTER state is refreshed with the correct buffers
        -- This ensures deleted buffers are not in the persisted order
        State.save_order()

        if on_complete then
          on_complete()
        end
      end)
    end)
    return
  end

  -- No modified buffers, proceed with deletion
  -- First, check all windows and switch away from buffers that will be deleted
  local deleted_paths = {}
  for _, buf in ipairs(buffers_to_delete) do
    if buf and buf.path then
      deleted_paths[buf.path] = buf
    end
  end

  -- Find a buffer to switch to that's not being deleted
  local switch_to_buf = nil
  for _, buf in ipairs(working_buffers) do
    if buf and buf.path and buf.path ~= "" and not deleted_paths[buf.path] then
      -- Find the current buffer with this path
      local all_buffers = vim.api.nvim_list_bufs()
      for _, bufnr in ipairs(all_buffers) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          local success, buffer_name = pcall(vim.api.nvim_buf_get_name, bufnr)
          if success and buffer_name == buf.path then
            switch_to_buf = bufnr
            break
          end
        end
      end
      if switch_to_buf then
        break
      end
    end
  end

  -- Close bafa window only if all buffers are being deleted (no buffer to switch to)
  if not switch_to_buf and BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    close_window()
    -- Ensure the window is fully closed before proceeding
    BAFA_WIN_ID = nil
    BAFA_BUF_ID = nil
  end

  -- Check all windows and switch any that are displaying buffers to be deleted
  local all_windows = vim.api.nvim_list_wins()
  for _, win_id in ipairs(all_windows) do
    if vim.api.nvim_win_is_valid(win_id) then
      local win_buf = vim.api.nvim_win_get_buf(win_id)
      local win_buf_will_be_deleted = false
      for _, buf in ipairs(buffers_to_delete) do
        if buf.number == win_buf then
          win_buf_will_be_deleted = true
          break
        end
      end

      if win_buf_will_be_deleted then
        if switch_to_buf and vim.api.nvim_buf_is_valid(switch_to_buf) then
          -- Switch to a buffer that's not being deleted
          pcall(vim.api.nvim_win_set_buf, win_id, switch_to_buf)
        else
          -- All buffers are being deleted, force delete the current buffer in this window
          pcall(vim.api.nvim_buf_delete, win_buf, { force = true })
        end
      end
    end
  end

  -- Now delete all buffers (nvim_buf_delete with force=true will handle any remaining issues)
  for _, buf in ipairs(buffers_to_delete) do
    if buf.number and vim.api.nvim_buf_is_valid(buf.number) then
      pcall(vim.api.nvim_buf_delete, buf.number, { force = true })
    end
  end

  -- Refresh state with actual buffers after commit (order will be applied in init)
  -- Use vim.schedule to ensure buffers are fully deleted before getting the list
  vim.schedule(function()
    local new_buffers = BufferUtils.get_buffers_as_table()
    -- Filter out any buffers that were supposed to be deleted (in case they're still in the list)
    local deleted_paths_async = {}
    for _, buf in ipairs(buffers_to_delete) do
      if buf and buf.path then
        deleted_paths_async[buf.path] = true
      end
    end
    local filtered_buffers = {}
    for _, buf in ipairs(new_buffers) do
      if buf and buf.path and not deleted_paths_async[buf.path] then
        table.insert(filtered_buffers, buf)
      end
    end
    State.init(filtered_buffers)

    -- Save the order AFTER state is refreshed with the correct buffers
    -- This ensures deleted buffers are not in the persisted order
    State.save_order()

    if on_complete then
      on_complete()
    end
  end)
end

---Commit changes and refresh UI without closing
---Commits changes (deletes buffers, saves order) and refreshes the UI
---@returns nil
function M.commit_changes_and_refresh()
  M.commit_changes(function()
    -- Refresh UI to reflect the committed state
    refresh_ui()
  end)
end

---Commit changes and close UI
---Commits changes (deletes buffers, saves order), refreshes the UI, and closes the window
---@returns nil
function M.commit_changes_and_close()
  M.commit_changes(function()
    -- Refresh UI to reflect the committed state
    refresh_ui()
    -- Close the window
    close_window()
    -- Restore cursor when closing the window
    UiUtils.revert_patches()
  end)
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

  -- Initialize signs for gitsigns-like UX
  init_signs()

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
