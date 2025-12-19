local M = {}

-- State management for buffer operations
local state = {
  original_buffers = {}, -- Original buffer list when menu opened
  working_buffers = {}, -- Current working buffer list (with modifications)
  history = {}, -- History for undo/redo
  history_index = 0, -- Current position in history
}

-- Deep copy a buffer list
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

--- Get persisted order from optional storage
-- Note: Requires kikao.nvim to be installed for persistence
-- See: https://github.com/mistweaverco/kikao.nvim
local function get_persisted_order()
  -- check if plugin kikao.nvim is installed
  -- and if so, get the persisted order from its storage
  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    return {}
  end
  -- this will return nil if no value is stored
  -- otherwise, it should be a table of buffer paths
  -- like: { "/path/to/buf1", "/path/to/buf2", ... }
  local order = kikao_api.get_value({ key = "buffer_order" })
  if order == nil or type(order) ~= "table" then
    return {}
  end
  return order
end

-- Apply persisted order to buffer list (matches by buffer path)
local function apply_persisted_order(buffers)
  local persisted_order = get_persisted_order()

  -- Create a map of buffer path to buffer
  local buffer_map = {}
  for _, buf in ipairs(buffers) do
    buffer_map[buf.path] = buf
  end

  -- Separate new buffers (not in persisted order) from existing ones
  local new_buffers = {}
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

  -- Build ordered list: new buffers first, then persisted order
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

-- Initialize state with current buffers
function M.init(initial_buffers)
  -- Apply persisted order if available
  local ordered_buffers = apply_persisted_order(initial_buffers)
  state.original_buffers = copy_buffer_list(ordered_buffers)
  state.working_buffers = copy_buffer_list(ordered_buffers)
  state.history = { copy_buffer_list(ordered_buffers) }
  state.history_index = 1
end

-- Get working buffers
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

-- Move buffer up (swap with previous)
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

-- Move buffer down (swap with next)
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

-- Add buffer to list (adds to end)
function M.add_buffer(buffer)
  table.insert(state.working_buffers, buffer)
  save_current_to_history()
  return true
end

-- Get buffer at index
function M.get_buffer_at_index(idx)
  return state.working_buffers[idx]
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

-- Get buffers to add (buffers not in current list)
function M.get_available_buffers(all_buffers)
  local working_numbers = {}
  for _, buf in ipairs(state.working_buffers) do
    working_numbers[buf.number] = true
  end

  local available = {}
  for _, buf in ipairs(all_buffers) do
    if not working_numbers[buf.number] then
      table.insert(available, buf)
    end
  end

  return available
end

-- Save current order as persisted order
-- Stores buffer paths instead of numbers since numbers change between sessions
-- Note: Requires kikao.nvim to be installed for persistence
-- See: https://github.com/mistweaverco/kikao.nvim
function M.save_order()
  local order = {}
  for _, buf in ipairs(state.working_buffers) do
    -- Only save valid buffers with paths (skip unnamed buffers)
    if vim.api.nvim_buf_is_valid(buf.number) and buf.path ~= "" then
      table.insert(order, buf.path)
    end
  end
  -- check if plugin kikao.nvim is installed
  -- and if so, save the persisted order to its storage
  local kikao_ok, kikao_api = pcall(require, "kikao.api")
  if not kikao_ok then
    return
  end
  kikao_api.set_value({ key = "buffer_order", value = order })
end

return M
