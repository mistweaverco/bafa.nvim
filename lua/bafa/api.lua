local BufferUtils = require("bafa.utils.buffers")
local State = require("bafa.utils.state")
local Types = require("bafa.types")

---@module 'bafa.api'
local M = {}

---Return the list of buffers in the same order bafa would display.
---For AUTO/DEFAULT sorting (`last_used`), this recomputes from current buffers
---so indices track MRU changes (and `switch_to_buffer(2)` can act as a toggle).
---For MANUAL sorting, it follows the same source as the UI: `State.get_display_order()`,
---initializing state lazily if needed.
---@return BafaBuffer[]
local function get_display_buffers()
  local sorting = State.get_persisted_sorting()

  local display
  if sorting == Types.BafaSorting.MANUAL then
    display = State.get_display_order()
    if display == nil or #display == 0 then
      -- When bafa UI is not opened, state may not be initialized yet.
      -- Initialize from current buffers so the ordering matches what the UI would show.
      State.init(BufferUtils.get_buffers_as_table())
      display = State.get_display_order()
    end
  else
    -- DEFAULT/AUTO: follow current MRU order directly.
    display = BufferUtils.get_buffers_as_table()
  end

  -- Filter out invalid buffers so indices match what the UI would actually show.
  local valid = {}
  for _, buf in ipairs(display) do
    if buf and buf.number and vim.api.nvim_buf_is_valid(buf.number) then table.insert(valid, buf) end
  end
  return valid
end

---Switch the current buffer to the buffer at a given bafa-UI index (1-indexed).
---If the index is out of bounds or the target buffer is not valid, returns false.
---@param index number 1-indexed position as shown in the bafa UI.
---@return boolean ok
function M.switch_to_buffer(index)
  if type(index) ~= "number" or index < 1 then return false end

  local buffers = get_display_buffers()
  local target = buffers[index]
  if not target or not target.number or not vim.api.nvim_buf_is_valid(target.number) then return false end

  local ok = pcall(vim.api.nvim_set_current_buf, target.number)
  return ok == true
end

return M
