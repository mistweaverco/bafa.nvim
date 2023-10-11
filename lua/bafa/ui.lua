local bafa = require('bafa')
local buffer_utils = require('bafa.utils.buffers')
local constants = require('bafa.constants')
local keymaps = require('bafa.utils.keymaps')
local autocmds = require('bafa.utils.autocmds')

BAFA_NS_ID = vim.api.nvim_create_namespace('bafa.nvim')

BAFA_WIN_ID = nil
BAFA_BUF_ID = nil

local function close_window()
  vim.api.nvim_win_close(BAFA_WIN_ID, true)
  BAFA_WIN_ID = nil
  BAFA_BUF_ID = nil
end

local function create_window()
  local bafa_config = bafa.get_config()
  local bufnr = vim.api.nvim_create_buf(false, false)

  local max_width = vim.api.nvim_win_get_width(0)
  local max_height = vim.api.nvim_win_get_height(0)
  local buffer_longest_name_width = buffer_utils.get_width_longest_buffer_name()
  local buffer_lines = buffer_utils.get_lines_buffer_names()
  local width = math.min(max_width, buffer_longest_name_width + 10)
  local height = math.min(max_height, buffer_lines + 2)

  BAFA_WIN_ID = vim.api.nvim_open_win(
    bufnr,
    true,
    {
      title = bafa_config.title,
      title_pos = bafa_config.title_pos,
      relative = bafa_config.relative,
      border = bafa_config.border,
      width = bafa_config.width or width,
      height = bafa_config.height or height,
      row = math.floor(((vim.o.lines - (bafa_config.height or height)) / 2) - 1),
      col = math.floor((vim.o.columns - (bafa_config.width or width)) / 2),
      style = bafa_config.style,
    }
  )

  vim.api.nvim_win_set_option(BAFA_WIN_ID, "winhighlight", "NormalFloat:BafaBorder")

  return {
    bufnr = bufnr,
    win_id = BAFA_WIN_ID,
  }
end

local M = {}

function M.select_menu_item() local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  local selected_buffer = buffer_utils.get_buffer_by_index(selected_line_number)
  if selected_buffer == nil then
    return
  end
  close_window()
  vim.api.nvim_set_current_buf(selected_buffer.number)
end

function M.delete_menu_item()
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  if selected_line_number == 1 then
    print("Cannot delete active buffer!")
    return
  end
  local selected_buffer = buffer_utils.get_buffer_by_index(selected_line_number)
  if selected_buffer == nil then
    return
  end
  if vim.api.nvim_buf_get_option(selected_buffer.number, "modified") then
    print("Buffer is modified, save manually before deleting!")
    return
  end
  vim.api.nvim_buf_delete(selected_buffer.number, { force = true })
  vim.api.nvim_buf_set_lines(
    BAFA_BUF_ID,
    selected_line_number - 1,
    selected_line_number,
    false,
    {}
  )
end

function M.on_menu_save()
  print(vim.inspect("on_menu_save"))
end

function M.toggle()
  if BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    close_window()
    return
  end

  local modified_lines = {}
  local win_info = create_window()
  local contents = {}

  BAFA_WIN_ID = win_info.win_id
  BAFA_BUF_ID = win_info.bufnr
  local valid_buffers = buffer_utils.get_buffers_as_table()

  for idx, buffer in ipairs(valid_buffers) do
    if buffer.is_modified then
      table.insert(modified_lines, idx)
    end
    contents[idx] = string.format("%s", buffer.name)
  end

  vim.api.nvim_win_set_option(BAFA_WIN_ID, "number", true)
  vim.api.nvim_buf_set_name(BAFA_BUF_ID, "bafa-menu")
  vim.api.nvim_buf_set_lines(BAFA_BUF_ID, 0, #contents, false, contents)
  vim.api.nvim_buf_set_option(BAFA_BUF_ID, "filetype", "bafa")
  vim.api.nvim_buf_set_option(BAFA_BUF_ID, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(BAFA_BUF_ID, "bufhidden", "delete")

  for _, line_number in ipairs(modified_lines) do
    vim.api.nvim_buf_set_extmark(BAFA_BUF_ID, BAFA_NS_ID, line_number - 1, 0, {
      virt_text = { { constants.icons.modified } },
    })
  end

  keymaps.noop(BAFA_BUF_ID)
  keymaps.defaults(BAFA_BUF_ID)
  autocmds.defaults(BAFA_BUF_ID)

end

return M
