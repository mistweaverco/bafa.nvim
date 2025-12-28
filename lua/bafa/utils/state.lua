local Logger = require("bafa.logger")
local Types = require("bafa.types")
local M = {}

-- INFO: Requires kikao.nvim to be installed for persisting order and sorting state
-- acrros Neovim restarts.
-- See: https://github.com/mistweaverco/kikao.nvim
-- Will print warnings (if log level is set to to warn)
-- if kikao.nvim is not found when attempting to use persistence features.
local KIKAO_URL = "https://github.com/mistweaverco/kikao.nvim"

---State management for buffer operations
---@class BafaState
local state = {
  sorting = nil,
  original_buffers = {}, -- Original buffer list when menu opened
  working_buffers = {}, -- Current working buffer list (with modifications)
  display_order = {}, -- Display order including both working and deleted buffers (for UI)
  history = {}, -- History for undo/redo
  history_index = 0, -- Current position in history
}

---Returns a valid sorting string
---@param sorting BafaSorting|nil
---@returns BafaSorting
local get_valid_sorting = function(sorting)
  if sorting == nil then return Types.BafaSorting.DEFAULT end
  for _, valid_sorting in pairs(Types.BafaSorting) do
    if sorting == valid_sorting then return sorting end
  end
  return Types.BafaSorting.DEFAULT
end

---Deep copy a buffer list
---@param buffers BafaBuffer[]
---@returns BafaBuffer[]
local function copy_buffer_list(buffers)
  local copy = {}
  for _, buf in ipairs(buffers) do
    table.insert(copy, {
      name = buf.name,
      path = buf.path,
      number = buf.number,
      last_used = buf.last_used,
      is_modified = buf.is_modified,
    })
  end
  return copy
end

-- Save current working state to history
local function save_current_to_history()
  -- Remove any history after current index (when undoing and making new changes)
  if state.history_index < #state.history then
    for i = #state.history, state.history_index + 1, -1 do
      table.remove(state.history, i)
    end
  end

  table.insert(state.history, copy_buffer_list(state.working_buffers))
  state.history_index = #state.history
end

---Get persisted order from optional storage
---@param sorting BafaSorting|nil
---@returns BafaPersistedData
local function get_persisted_data(sorting)
  -- check if plugin kikao.nvim is installed
  -- and if so, get the persisted order from its storage
  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then return { buffers = {}, sorting = get_valid_sorting(sorting) } end
  ---@type BafaBuffer[]|nil
  local ordered_buffers = kikao_api.get_value({ key = "plugins.bafa.buffers" }) or {}
  ---@type BafaSorting
  local sorting_from_persisted_state = kikao_api.get_value({ key = "plugins.bafa.sorting" })
  sorting = sorting ~= nil and sorting or sorting_from_persisted_state
  -- return valid sorting, with fallback to DEFAULT
  sorting = get_valid_sorting(sorting)
  return { buffers = ordered_buffers, sorting = sorting }
end

---Apply persisted order to buffer list (matches by buffer path)
---@param buffers BafaBuffer[]
---@param sorting BafaSorting|nil
---@return BafaBuffer[]
local function apply_persisted_data(buffers, sorting)
  local persisted_data = get_persisted_data(sorting)
  ---@type BafaBuffer[]
  local persisted_order = persisted_data.buffers

  -- Create a map of buffer path to buffer
  local buffer_map = {}
  for _, buf in ipairs(buffers) do
    buffer_map[buf.path] = buf
  end

  ---Separate new buffers (not in persisted order) from existing ones
  ---@type BafaBuffer[]
  local new_buffers = {}
  ---@type table<string, boolean>
  local used_paths = {}

  for _, buf in ipairs(buffers) do
    local is_in_persisted = false
    if #persisted_order > 0 then
      for _, buf_path in ipairs(persisted_order) do
        if buf.path == buf_path then
          is_in_persisted = true
          used_paths[buf_path] = true
          break
        end
      end
    end
    if not is_in_persisted then table.insert(new_buffers, buf) end
  end

  ---Build ordered list: new buffers first, then persisted order
  ---@type BafaBuffer[]
  local ordered = {}

  -- Add new buffers first (sorted by last_used, most recent first)
  table.sort(new_buffers, function(a, b) return a.last_used > b.last_used end)
  for _, buf in ipairs(new_buffers) do
    table.insert(ordered, buf)
  end

  -- Then add buffers in persisted order
  if #persisted_order > 0 then
    for _, buf_path in ipairs(persisted_order) do
      if buffer_map[buf_path] ~= nil and used_paths[buf_path] then table.insert(ordered, buffer_map[buf_path]) end
    end
  end

  return ordered
end

---Check if sorting is AUTO
---@param sorting BafaSorting
---@returns boolean
local is_auto_sorting = function(sorting) return sorting == Types.BafaSorting.AUTO end

---Initialize state with current buffers
---@param initial_buffers BafaBuffer[]
function M.init(initial_buffers)
  local sorting = M.get_persisted_sorting()
  -- Apply persisted order if available
  local ordered_buffers = is_auto_sorting(sorting) and initial_buffers or apply_persisted_data(initial_buffers, sorting)
  state.sorting = sorting
  state.original_buffers = copy_buffer_list(ordered_buffers)
  state.working_buffers = copy_buffer_list(ordered_buffers)
  state.display_order = copy_buffer_list(ordered_buffers) -- Display order starts same as working
  state.history = { copy_buffer_list(ordered_buffers) }
  state.history_index = 1
end

---Get working buffers
---@return BafaBuffer[]
function M.get_working_buffers() return state.working_buffers end

-- Get original buffers
function M.get_original_buffers() return state.original_buffers end

-- Check if there are pending changes
function M.has_changes()
  if #state.working_buffers ~= #state.original_buffers then return true end

  for i, buf in ipairs(state.working_buffers) do
    local orig_buf = state.original_buffers[i]
    if orig_buf == nil or buf.number ~= orig_buf.number then return true end
  end

  return false
end

-- Delete buffer at index
function M.delete_buffer_at_index(idx)
  if idx < 1 or idx > #state.working_buffers then return false end

  -- Remove from working_buffers (it stays in display_order)
  table.remove(state.working_buffers, idx)
  save_current_to_history()
  return true
end

---Move buffer up (swap with previous)
---@param idx number: Index of the buffer to move up
---@returns boolean: True if moved, false if not (e.g., at top)
function M.move_buffer_up(idx)
  if idx <= 1 or idx > #state.working_buffers then return false end

  local temp = state.working_buffers[idx]
  state.working_buffers[idx] = state.working_buffers[idx - 1]
  state.working_buffers[idx - 1] = temp
  save_current_to_history()
  return true
end

---Move buffer down (swap with next)
---@param idx number: Index of the buffer to move down
---@returns boolean: True if moved, false if not (e.g., at bottom)
function M.move_buffer_down(idx)
  if idx < 1 or idx >= #state.working_buffers then return false end

  local temp = state.working_buffers[idx]
  state.working_buffers[idx] = state.working_buffers[idx + 1]
  state.working_buffers[idx + 1] = temp
  save_current_to_history()
  return true
end

---Move a range of buffers up as a block
---When moving up, the item above the range moves to the bottom of the range
---Example: [1, 2, 3, 4] with selection [2, 3, 4] -> [2, 3, 4, 1]
---@param start_idx number: Start index of the range (1-indexed, inclusive)
---@param end_idx number: End index of the range (1-indexed, inclusive)
---@returns boolean: True if moved, false if not (e.g., at top)
function M.move_buffer_range_up(start_idx, end_idx)
  if
    start_idx <= 1
    or start_idx > #state.working_buffers
    or end_idx > #state.working_buffers
    or start_idx > end_idx
  then
    return false
  end

  -- Extract the range to move and the item above
  local range = {}
  for i = start_idx, end_idx do
    table.insert(range, state.working_buffers[i])
  end
  local item_above = state.working_buffers[start_idx - 1]

  -- Place range at new position (shifted up by 1)
  for i = 0, #range - 1 do
    state.working_buffers[start_idx - 1 + i] = range[i + 1]
  end

  -- Place item_above at the end of where the range was
  state.working_buffers[end_idx] = item_above

  save_current_to_history()
  return true
end

---Move a range of buffers down as a block
---When moving down, the item below the range moves to the top of the range
---Example: [1, 2, 3, 4] with selection [1, 2, 3] -> [4, 1, 2, 3]
---@param start_idx number: Start index of the range (1-indexed, inclusive)
---@param end_idx number: End index of the range (1-indexed, inclusive)
---@returns boolean: True if moved, false if not (e.g., at bottom)
function M.move_buffer_range_down(start_idx, end_idx)
  if start_idx < 1 or end_idx >= #state.working_buffers or start_idx > end_idx then return false end

  -- Extract the range to move and the item below
  local range = {}
  for i = start_idx, end_idx do
    table.insert(range, state.working_buffers[i])
  end
  local item_below = state.working_buffers[end_idx + 1]

  -- Place item_below at the start of where the range was
  state.working_buffers[start_idx] = item_below

  -- Place range at new position (shifted down by 1)
  for i = 0, #range - 1 do
    state.working_buffers[start_idx + 1 + i] = range[i + 1]
  end

  save_current_to_history()
  return true
end

---Add buffer to list (restores a deleted buffer)
---@param buffer BafaBuffer: Buffer to add
---@returns boolean: True if added
function M.add_buffer(buffer)
  -- Buffer is already in display_order, add it back to working_buffers
  -- Insert it at the position that matches its position in display_order relative to other working buffers
  local buffer_num = buffer and buffer.number
  if not buffer_num then return false end

  -- Find the buffer's position in display_order
  local display_pos = nil
  for i, d_buf in ipairs(state.display_order) do
    if d_buf and d_buf.number == buffer_num then
      display_pos = i
      break
    end
  end

  if not display_pos then
    -- Buffer not in display_order, just append
    table.insert(state.working_buffers, buffer)
  else
    -- Count how many working buffers come before this position in display_order
    local working_before_count = 0
    local working_buffer_map = {}
    for _, w_buf in ipairs(state.working_buffers) do
      if w_buf and w_buf.number then working_buffer_map[w_buf.number] = true end
    end

    for i = 1, display_pos - 1 do
      local d_buf = state.display_order[i]
      if d_buf and d_buf.number and working_buffer_map[d_buf.number] then
        working_before_count = working_before_count + 1
      end
    end

    -- Insert at the calculated position (1-indexed)
    table.insert(state.working_buffers, working_before_count + 1, buffer)
  end

  save_current_to_history()
  return true
end

---Get buffer at index
---@param idx number: Index of the buffer to retrieve
---@returns BafaBuffer|nil Buffer at index or nil if out of bounds
function M.get_buffer_at_index(idx) return state.working_buffers[idx] end

function M.is_working_buffers_empty() return #state.working_buffers == 0 end

-- Rebuild display_order from working_buffers and original_buffers
-- Keeps deleted buffers at their positions based on reference_order if provided, otherwise original_buffers
-- @param reference_order BafaBuffer[]|nil Optional reference order to use instead of original_buffers
local function rebuild_display_order(reference_order)
  local working_buffer_map = {}
  for _, buf in ipairs(state.working_buffers) do
    if buf and buf.number then working_buffer_map[buf.number] = true end
  end

  -- Check if all buffers from original_buffers are in working_buffers
  local all_buffers_present = true
  for _, orig_buf in ipairs(state.original_buffers) do
    if orig_buf and orig_buf.number and not working_buffer_map[orig_buf.number] then
      all_buffers_present = false
      break
    end
  end

  -- Use reference_order if provided, otherwise use original_buffers
  local order_reference = reference_order or state.original_buffers

  if all_buffers_present then
    -- No deleted buffers, but we should still use the reference_order to preserve the correct order
    -- Build display_order based on reference_order, using buffers from working_buffers
    -- Create a map of buffer numbers to buffer objects from working_buffers
    local working_buffers_by_number = {}
    for _, w_buf in ipairs(state.working_buffers) do
      if w_buf and w_buf.number then working_buffers_by_number[w_buf.number] = w_buf end
    end

    local new_display_order = {}
    for _, ref_buf in ipairs(order_reference) do
      if ref_buf and ref_buf.number and working_buffers_by_number[ref_buf.number] then
        table.insert(new_display_order, working_buffers_by_number[ref_buf.number])
      end
    end
    state.display_order = new_display_order
    return
  end

  -- Start with working buffers in their current order
  local new_display_order = {}
  for _, w_buf in ipairs(state.working_buffers) do
    if w_buf and w_buf.number then table.insert(new_display_order, w_buf) end
  end

  -- Add deleted buffers at their positions based on reference order
  for _, ref_buf in ipairs(order_reference) do
    if ref_buf and ref_buf.number and not working_buffer_map[ref_buf.number] then
      if vim.api.nvim_buf_is_valid(ref_buf.number) then
        -- Find where to insert based on reference position
        local ref_pos = nil
        for i, r_buf in ipairs(order_reference) do
          if r_buf and r_buf.number == ref_buf.number then
            ref_pos = i
            break
          end
        end
        if ref_pos then
          -- Count how many working buffers come before this position in reference order
          local working_before_count = 0
          for i = 1, ref_pos - 1 do
            local prev_ref = order_reference[i]
            if prev_ref and prev_ref.number and working_buffer_map[prev_ref.number] then
              working_before_count = working_before_count + 1
            end
          end
          -- Insert at position: working_before_count + 1 (1-indexed)
          table.insert(new_display_order, working_before_count + 1, ref_buf)
        end
      end
    end
  end

  state.display_order = new_display_order
end

-- Undo last change
function M.undo()
  if state.history_index <= 1 then return false end

  -- Get the history entry we're restoring to
  local previous_history = state.history[state.history_index - 1]

  -- Check if this is a deletion/add operation (count changed) or move/sort (count same)
  local current_count = #state.working_buffers
  local previous_count = #previous_history
  local is_deletion_or_add = (current_count ~= previous_count)

  if is_deletion_or_add then
    -- For deletion/add operations: preserve display_order positions, just update which buffers are working
    local current_display_order = copy_buffer_list(state.display_order)

    state.history_index = state.history_index - 1
    state.working_buffers = copy_buffer_list(previous_history)

    -- Build a map of working buffers by number (from restored working_buffers)
    local working_buffers_by_number = {}
    for _, w_buf in ipairs(state.working_buffers) do
      if w_buf and w_buf.number then working_buffers_by_number[w_buf.number] = w_buf end
    end

    -- Build a map of which buffers are now working
    local working_buffer_map = {}
    for _, buf in ipairs(state.working_buffers) do
      if buf and buf.number then working_buffer_map[buf.number] = true end
    end

    -- Rebuild display_order preserving the order from current_display_order
    -- but using buffer objects from working_buffers for buffers that are now working
    local new_display_order = {}
    for _, disp_buf in ipairs(current_display_order) do
      if disp_buf and disp_buf.number then
        if working_buffer_map[disp_buf.number] then
          -- Buffer is now working, use the object from working_buffers
          table.insert(new_display_order, working_buffers_by_number[disp_buf.number])
        else
          -- Buffer is still deleted, keep it as is (but only if it's valid)
          if vim.api.nvim_buf_is_valid(disp_buf.number) then table.insert(new_display_order, disp_buf) end
        end
      end
    end

    state.display_order = new_display_order
  else
    -- For move/sort operations: restore order from history entry
    state.history_index = state.history_index - 1
    state.working_buffers = copy_buffer_list(previous_history)

    -- Use rebuild_display_order with the history entry as reference to restore the order
    rebuild_display_order(previous_history)
  end

  return true
end

-- Redo last undone change
function M.redo()
  if state.history_index >= #state.history then return false end

  -- Get the history entry we're restoring to
  local next_history = state.history[state.history_index + 1]

  -- Check if this is a deletion/add operation (count changed) or move/sort (count same)
  local current_count = #state.working_buffers
  local next_count = #next_history
  local is_deletion_or_add = (current_count ~= next_count)

  if is_deletion_or_add then
    -- For deletion/add operations: preserve display_order positions, just update which buffers are working
    local current_display_order = copy_buffer_list(state.display_order)

    state.history_index = state.history_index + 1
    state.working_buffers = copy_buffer_list(next_history)

    -- Build a map of working buffers by number (from restored working_buffers)
    local working_buffers_by_number = {}
    for _, w_buf in ipairs(state.working_buffers) do
      if w_buf and w_buf.number then working_buffers_by_number[w_buf.number] = w_buf end
    end

    -- Build a map of which buffers are now working
    local working_buffer_map = {}
    for _, buf in ipairs(state.working_buffers) do
      if buf and buf.number then working_buffer_map[buf.number] = true end
    end

    -- Rebuild display_order preserving the order from current_display_order
    -- but using buffer objects from working_buffers for buffers that are now working
    local new_display_order = {}
    for _, disp_buf in ipairs(current_display_order) do
      if disp_buf and disp_buf.number then
        if working_buffer_map[disp_buf.number] then
          -- Buffer is now working, use the object from working_buffers
          table.insert(new_display_order, working_buffers_by_number[disp_buf.number])
        else
          -- Buffer is still deleted, keep it as is (but only if it's valid)
          if vim.api.nvim_buf_is_valid(disp_buf.number) then table.insert(new_display_order, disp_buf) end
        end
      end
    end

    state.display_order = new_display_order
  else
    -- For move/sort operations: restore order from history entry
    state.history_index = state.history_index + 1
    state.working_buffers = copy_buffer_list(next_history)

    -- Use rebuild_display_order with the history entry as reference to restore the order
    rebuild_display_order(next_history)
  end

  return true
end

-- Reset to original state (reject changes)
function M.reset()
  state.working_buffers = copy_buffer_list(state.original_buffers)
  state.display_order = copy_buffer_list(state.original_buffers)
  state.history = { copy_buffer_list(state.original_buffers) }
  state.history_index = 1
end

---Save current order as persisted order
---Stores buffer paths instead of numbers since numbers change between sessions
---@returns nil
function M.save_order()
  ---@type BafaBuffer[]
  local ordererd_buffers = {}
  for _, buf in ipairs(state.working_buffers) do
    -- Only save valid buffers with paths (skip unnamed buffers and invalid buffers)
    -- Double-check that the buffer still exists in Neovim before saving
    if buf and buf.path and buf.path ~= "" then
      -- Check if buffer number is valid, or if we can find the buffer by path
      local should_save = false
      if buf.number and vim.api.nvim_buf_is_valid(buf.number) then
        -- Verify the buffer path matches (in case buffer number was reused)
        local success, buffer_name = pcall(vim.api.nvim_buf_get_name, buf.number)
        if success and buffer_name == buf.path then should_save = true end
      else
        -- Buffer number is invalid, check if any current buffer has this path
        local current_buffers = vim.api.nvim_list_bufs()
        for _, bufnr in ipairs(current_buffers) do
          if vim.api.nvim_buf_is_valid(bufnr) then
            local success, buffer_name = pcall(vim.api.nvim_buf_get_name, bufnr)
            if success and buffer_name == buf.path then
              should_save = true
              break
            end
          end
        end
      end
      if should_save then table.insert(ordererd_buffers, buf.path) end
    end
  end
  -- check if plugin kikao.nvim is installed
  -- and if so, save the persisted order to its storage
  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    Logger.warn("kikao.nvim not found, can only persist order in volatile state (in-memory)", "See: " .. KIKAO_URL)
    return
  end
  kikao_api.set_value({ key = "plugins.bafa.buffers", value = ordererd_buffers })
  -- Use state.sorting directly if set, otherwise get persisted sorting
  local sorting_to_save = state.sorting
  if sorting_to_save == nil then sorting_to_save = M.get_persisted_sorting() end
  kikao_api.set_value({ key = "plugins.bafa.sorting", value = sorting_to_save })
end

---Get persisted sorting method
---If kikao.nvim is not installed, returns in-memory state or DEFAULT
---@returns BafaSorting
function M.get_persisted_sorting()
  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    Logger.warn("kikao.nvim not found, returning from volatile state (in-memory) or DEFAULT", "See: " .. KIKAO_URL)
    return Types.BafaSorting.DEFAULT
  end
  local sorting = kikao_api.get_value({ key = "plugins.bafa.sorting" })
  return state.sorting or get_valid_sorting(sorting)
end

---Update buffer order based on new sorting mode
---@param new_sorting BafaSorting The new sorting mode
---@param current_buffers BafaBuffer[]|nil Optional current buffers to reorder. If nil and switching to AUTO, function returns without updating.
---@returns boolean True if buffers were updated
local function update_buffers_for_sorting(new_sorting, current_buffers)
  local old_sorting = state.sorting
  local switching_to_auto = is_auto_sorting(new_sorting) and not is_auto_sorting(old_sorting)
  local switching_to_manual = not is_auto_sorting(new_sorting) and is_auto_sorting(old_sorting)

  -- If switching to AUTO and we have current buffers, sort them by last_used
  if switching_to_auto and current_buffers then
    -- Create a map of current state buffers by path to preserve which buffers are in the list
    local state_buffer_map = {}
    for _, buf in ipairs(state.working_buffers) do
      if buf and buf.path then state_buffer_map[buf.path] = true end
    end

    -- Filter fresh buffers to only include those currently in state, then sort by last_used
    local buffers_to_sort = {}
    for _, buf in ipairs(current_buffers) do
      if buf and buf.path and state_buffer_map[buf.path] then table.insert(buffers_to_sort, buf) end
    end

    -- Sort by last_used (most recent first)
    table.sort(buffers_to_sort, function(a, b) return (a.last_used or 0) > (b.last_used or 0) end)

    -- Update state with sorted buffers
    state.original_buffers = copy_buffer_list(buffers_to_sort)
    state.working_buffers = copy_buffer_list(buffers_to_sort)
    state.display_order = copy_buffer_list(buffers_to_sort)
    state.history = { copy_buffer_list(buffers_to_sort) }
    state.history_index = 1
    return true
  end

  -- If switching to MANUAL, keep current order (it will be saved in save_order)
  -- No need to update buffers here
  return false
end

---Set persisted sorting method
---If kikao.nvim is not installed, only updates in-memory state
---@param sorting BafaSorting|nil
---@param current_buffers BafaBuffer[]|nil Optional current buffers to reorder when switching sorting modes
---@returns nil
function M.set_persisted_sorting(sorting, current_buffers)
  local old_sorting = state.sorting
  state.sorting = get_valid_sorting(sorting)

  -- Update buffer order if switching modes and we have current buffers
  local buffers_updated = update_buffers_for_sorting(state.sorting, current_buffers)

  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    Logger.warn("kikao.nvim not found, can only persist sorting in volatile state (in-memory)", "See: " .. KIKAO_URL)
    return
  end
  -- Save sorting to kikao immediately
  kikao_api.set_value({ key = "plugins.bafa.sorting", value = state.sorting })
  -- Save order (this will save the current buffer order)
  M.save_order()
end

---Save cursor line position (only in manual mode)
---@param cursor_line number|nil The cursor line to save (1-indexed)
---@returns nil
function M.save_cursor_line(cursor_line)
  -- Only save in manual mode
  if M.get_persisted_sorting() ~= Types.BafaSorting.MANUAL then return end

  if cursor_line == nil or cursor_line < 1 then return end

  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    Logger.warn(
      "kikao.nvim not found, can only persist cursor line in volatile state (in-memory)",
      "See: " .. KIKAO_URL
    )
    return
  end
  kikao_api.set_value({ key = "plugins.bafa.cursor_line", value = cursor_line })
end

---Get persisted cursor line position (only in manual mode)
---If kikao.nvim is not installed, returns nil
---@param max_line number|nil Maximum valid line number (for bounds checking)
---@returns number|nil The cursor line (1-indexed) or nil if not set or out of bounds
function M.get_persisted_cursor_line(max_line)
  -- Only restore in manual mode
  if M.get_persisted_sorting() ~= Types.BafaSorting.MANUAL then return nil end

  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then return nil end

  local cursor_line = kikao_api.get_value({ key = "plugins.bafa.cursor_line" })
  if cursor_line == nil or type(cursor_line) ~= "number" then return nil end

  -- Bounds checking
  if max_line ~= nil then
    if cursor_line < 1 or cursor_line > max_line then return nil end
  end

  return cursor_line
end

---Get display order (includes both working and deleted buffers)
---@return BafaBuffer[]
function M.get_display_order() return state.display_order end

---Sync working_buffers order to match display_order (only for buffers that are in working_buffers)
local function sync_working_buffers_from_display_order()
  -- Create a map of buffer numbers to their buffers in working_buffers
  local working_buffer_map = {}
  for _, buf in ipairs(state.working_buffers) do
    if buf and buf.number then working_buffer_map[buf.number] = buf end
  end

  -- Rebuild working_buffers in display_order order
  local new_working_buffers = {}
  for _, d_buf in ipairs(state.display_order) do
    if d_buf and d_buf.number and working_buffer_map[d_buf.number] then
      table.insert(new_working_buffers, working_buffer_map[d_buf.number])
    end
  end

  state.working_buffers = new_working_buffers
end

---Move buffer in display order (works for both working and deleted buffers)
---@param display_idx number Display index (1-indexed)
---@param direction string "up" or "down"
---@return boolean True if moved
function M.move_in_display_order(display_idx, direction)
  if direction == "up" then
    if display_idx <= 1 or display_idx > #state.display_order then return false end
    local temp = state.display_order[display_idx]
    state.display_order[display_idx] = state.display_order[display_idx - 1]
    state.display_order[display_idx - 1] = temp
    -- Sync working_buffers order to match display_order for working buffers
    sync_working_buffers_from_display_order()
    save_current_to_history()
    return true
  elseif direction == "down" then
    if display_idx < 1 or display_idx >= #state.display_order then return false end
    local temp = state.display_order[display_idx]
    state.display_order[display_idx] = state.display_order[display_idx + 1]
    state.display_order[display_idx + 1] = temp
    -- Sync working_buffers order to match display_order for working buffers
    sync_working_buffers_from_display_order()
    save_current_to_history()
    return true
  end
  return false
end

---Move a range of buffers in display order
---@param start_display_idx number Start display index (1-indexed)
---@param end_display_idx number End display index (1-indexed)
---@param direction string "up" or "down"
---@return boolean True if moved
function M.move_range_in_display_order(start_display_idx, end_display_idx, direction)
  if direction == "up" then
    if
      start_display_idx <= 1
      or start_display_idx > #state.display_order
      or end_display_idx > #state.display_order
      or start_display_idx > end_display_idx
    then
      return false
    end
    local range = {}
    for i = start_display_idx, end_display_idx do
      table.insert(range, state.display_order[i])
    end
    local item_above = state.display_order[start_display_idx - 1]

    for i = 0, #range - 1 do
      state.display_order[start_display_idx - 1 + i] = range[i + 1]
    end
    state.display_order[end_display_idx] = item_above

    -- Sync working_buffers order to match display_order
    sync_working_buffers_from_display_order()
    save_current_to_history()
    return true
  elseif direction == "down" then
    if start_display_idx < 1 or end_display_idx >= #state.display_order or start_display_idx > end_display_idx then
      return false
    end
    local range = {}
    for i = start_display_idx, end_display_idx do
      table.insert(range, state.display_order[i])
    end
    local item_below = state.display_order[end_display_idx + 1]

    state.display_order[start_display_idx] = item_below
    for i = 0, #range - 1 do
      state.display_order[start_display_idx + 1 + i] = range[i + 1]
    end

    -- Sync working_buffers order to match display_order
    sync_working_buffers_from_display_order()
    save_current_to_history()
    return true
  end
  return false
end

return M
