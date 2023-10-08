local popup = require('plenary.popup')
local buffer_utils = require('bafa.utils.buffers')

Bafa_win_id = nil
Bafa_bufh = nil

local function close_window()
  vim.api.nvim_win_close(Bafa_win_id, true)
  Bafa_win_id = nil
  Bafa_bufh = nil
end

local function create_window()
  local width = 60
  local height = 10
  local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  local bufnr = vim.api.nvim_create_buf(false, false)

  local Bafa_win_id, win = popup.create(bufnr, {
    title = "Bafa",
    highlight = "BafaWindow",
    line = math.floor(((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    minwidth = width,
    minheight = height,
    borderchars = borderchars,
  })

  vim.api.nvim_win_set_option(
    win.border.win_id,
    "winhl",
    "Normal:BafaBorder"
  )

  return {
    bufnr = bufnr,
    win_id = Bafa_win_id,
  }
end

local M = {}

function M.select_menu_item()
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
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
    Bafa_bufh,
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
  if Bafa_win_id ~= nil and vim.api.nvim_win_is_valid(Bafa_win_id) then
    close_window()
    return
  end

  local win_info = create_window()
  local contents = {}

  Bafa_win_id = win_info.win_id
  Bafa_bufh = win_info.bufnr
  local valid_buffers = buffer_utils.get_buffers_as_table()

  for idx, buffer in ipairs(valid_buffers) do
    local is_modified = buffer.is_modified and "[+] " or ""
    contents[idx] = string.format("%s%s", is_modified, buffer.name)
  end

  vim.api.nvim_win_set_option(Bafa_win_id, "number", true)
  vim.api.nvim_buf_set_name(Bafa_bufh, "bafa-menu")
  vim.api.nvim_buf_set_lines(Bafa_bufh, 0, #contents, false, contents)
  vim.api.nvim_buf_set_option(Bafa_bufh, "filetype", "bafa")
  vim.api.nvim_buf_set_option(Bafa_bufh, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(Bafa_bufh, "bufhidden", "delete")
  vim.api.nvim_buf_set_keymap(
    Bafa_bufh,
    "n",
    "q",
    "<Cmd>lua require('bafa.ui').toggle()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    Bafa_bufh,
    "n",
    "<ESC>",
    "<Cmd>lua require('bafa.ui').toggle()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    Bafa_bufh,
    "n",
    "<CR>",
    "<Cmd>lua require('bafa.ui').select_menu_item()<CR>",
    {}
  )
  vim.api.nvim_buf_set_keymap(
    Bafa_bufh,
    "n",
    "dd",
    "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>",
    {}
  )
  vim.api.nvim_buf_set_keymap(
    Bafa_bufh,
    "n",
    "D",
    "<Cmd>lua require('bafa.ui').delete_menu_item()<CR>",
    {}
  )
  vim.cmd(
    string.format(
      "autocmd BufWriteCmd <buffer=%s> lua require('bafa.ui').on_menu_save()",
      Bafa_bufh
    )
  )
  vim.cmd(
    string.format(
      "autocmd BufModifiedSet <buffer=%s> set nomodified",
      Bafa_bufh
    )
  )
  vim.cmd(
    "autocmd BufLeave <buffer> ++nested ++once silent lua require('bafa.ui').toggle()"
  )
end

return M
