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
  history = {}, -- History for undo/redo
  history_index = 0, -- Current position in history
}

---Returns a valid sorting string
---@param sorting BafaSorting|nil
---@returns BafaSorting
local get_valid_sorting = function(sorting)
  if sorting == nil then
    return Types.BafaSorting.DEFAULT
  end
  for _, valid_sorting in pairs(Types.BafaSorting) do
    if sorting == valid_sorting then
      return sorting
    end
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
  if not kikao_ok then
    return { buffers = {}, sorting = get_valid_sorting(sorting) }
  end
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
    if not is_in_persisted then
      table.insert(new_buffers, buf)
    end
  end

  ---Build ordered list: new buffers first, then persisted order
  ---@type BafaBuffer[]
  local ordered = {}

  -- Add new buffers first (sorted by last_used, most recent first)
  table.sort(new_buffers, function(a, b)
    return a.last_used > b.last_used
  end)
  for _, buf in ipairs(new_buffers) do
    table.insert(ordered, buf)
  end

  -- Then add buffers in persisted order
  if #persisted_order > 0 then
    for _, buf_path in ipairs(persisted_order) do
      if buffer_map[buf_path] ~= nil and used_paths[buf_path] then
        table.insert(ordered, buffer_map[buf_path])
      end
    end
  end

  return ordered
end

---Check if sorting is AUTO
---@param sorting BafaSorting
---@returns boolean
local is_auto_sorting = function(sorting)
  return sorting == Types.BafaSorting.AUTO
end

---Initialize state with current buffers
---@param initial_buffers BafaBuffer[]
function M.init(initial_buffers)
  local sorting = M.get_persisted_sorting()
  -- Apply persisted order if available
  local ordered_buffers = is_auto_sorting(sorting) and initial_buffers or apply_persisted_data(initial_buffers)
  state.sorting = sorting
  state.original_buffers = copy_buffer_list(ordered_buffers)
  state.working_buffers = copy_buffer_list(ordered_buffers)
  state.history = { copy_buffer_list(ordered_buffers) }
  state.history_index = 1
end

---Get working buffers
---@return BafaBuffer[]
function M.get_working_buffers()
  return state.working_buffers
end

-- Get original buffers
function M.get_original_buffers()
  return state.original_buffers
end

-- Check if there are pending changes
function M.has_changes()
  if #state.working_buffers ~= #state.original_buffers then
    return true
  end

  for i, buf in ipairs(state.working_buffers) do
    local orig_buf = state.original_buffers[i]
    if orig_buf == nil or buf.number ~= orig_buf.number then
      return true
    end
  end

  return false
end

-- Delete buffer at index
function M.delete_buffer_at_index(idx)
  if idx < 1 or idx > #state.working_buffers then
    return false
  end

  table.remove(state.working_buffers, idx)
  save_current_to_history()
  return true
end

---Move buffer up (swap with previous)
---@param idx number: Index of the buffer to move up
---@returns boolean: True if moved, false if not (e.g., at top)
function M.move_buffer_up(idx)
  if idx <= 1 or idx > #state.working_buffers then
    return false
  end

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
  if idx < 1 or idx >= #state.working_buffers then
    return false
  end

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
  if start_idx < 1 or end_idx >= #state.working_buffers or start_idx > end_idx then
    return false
  end

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

---Add buffer to list
---@param buffer BafaBuffer: Buffer to add
---@returns boolean: True if added
function M.add_buffer(buffer)
  table.insert(state.working_buffers, buffer)
  save_current_to_history()
  return true
end

---Get buffer at index
---@param idx number: Index of the buffer to retrieve
---@returns BafaBuffer|nil Buffer at index or nil if out of bounds
function M.get_buffer_at_index(idx)
  return state.working_buffers[idx]
end

function M.is_working_buffers_empty()
  return #state.working_buffers == 0
end

-- Undo last change
function M.undo()
  if state.history_index <= 1 then
    return false
  end

  state.history_index = state.history_index - 1
  state.working_buffers = copy_buffer_list(state.history[state.history_index])
  return true
end

-- Redo last undone change
function M.redo()
  if state.history_index >= #state.history then
    return false
  end

  state.history_index = state.history_index + 1
  state.working_buffers = copy_buffer_list(state.history[state.history_index])
  return true
end

-- Reset to original state (reject changes)
function M.reset()
  state.working_buffers = copy_buffer_list(state.original_buffers)
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
    -- Only save valid buffers with paths (skip unnamed buffers)
    if vim.api.nvim_buf_is_valid(buf.number) and buf.path ~= "" then
      table.insert(ordererd_buffers, buf.path)
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
  kikao_api.set_value({ key = "plugins.bafa.sorting", value = M.get_persisted_sorting() })
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

---Set persisted sorting method
---If kikao.nvim is not installed, only updates in-memory state
---@param sorting BafaSorting|nil
---@returns nil
function M.set_persisted_sorting(sorting)
  state.sorting = get_valid_sorting(sorting)
  M.save_order()
  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    Logger.warn("kikao.nvim not found, can only persist sorting in volatile state (in-memory)", "See: " .. KIKAO_URL)
    return
  end
  kikao_api.set_value({ key = "plugins.bafa.sorting", value = state.sorting })
end

---Save cursor line position (only in manual mode)
---@param cursor_line number|nil The cursor line to save (1-indexed)
---@returns nil
function M.save_cursor_line(cursor_line)
  -- Only save in manual mode
  if M.get_persisted_sorting() ~= Types.BafaSorting.MANUAL then
    return
  end

  if cursor_line == nil or cursor_line < 1 then
    return
  end

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
  if M.get_persisted_sorting() ~= Types.BafaSorting.MANUAL then
    return nil
  end

  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    return nil
  end

  local cursor_line = kikao_api.get_value({ key = "plugins.bafa.cursor_line" })
  if cursor_line == nil or type(cursor_line) ~= "number" then
    return nil
  end

  -- Bounds checking
  if max_line ~= nil then
    if cursor_line < 1 or cursor_line > max_line then
      return nil
    end
  end

  return cursor_line
end

return M
