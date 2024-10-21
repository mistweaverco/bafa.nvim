local Config = require("bafa.config")
local BufferUtils = require("bafa.utils.buffers")
local Keymaps = require("bafa.utils.keymaps")
local Autocmds = require("bafa.utils.autocmds")
local _, Devicons = pcall(require, "nvim-web-devicons")

local BAFA_NS_ID = vim.api.nvim_create_namespace("bafa.nvim")

local BAFA_WIN_ID = nil
local BAFA_BUF_ID = nil

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

local get_buffer_icon = function(buffer)
  if Devicons == nil then
    return "", "Normal" -- fallback to default icon, when devicons is not available
  end
  local icon, icon_hl = Devicons.get_icon(buffer.name, buffer.extension, { default = true })
  return icon, icon_hl
end

local function close_window()
  if BAFA_WIN_ID == nil or not vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    return
  end
  vim.api.nvim_win_close(BAFA_WIN_ID, true)
  BAFA_WIN_ID = nil
  BAFA_BUF_ID = nil
end

local function create_window()
  local bafa_config = Config.get()
  local bufnr = vim.api.nvim_create_buf(false, false)

  local max_width = vim.api.nvim_win_get_width(0)
  local max_height = vim.api.nvim_win_get_height(0)
  local buffer_longest_name_width = BufferUtils.get_width_longest_buffer_name()
  local buffer_lines = BufferUtils.get_lines_buffer_names()
  -- preserve space for the icons
  local width = math.min(max_width, buffer_longest_name_width + 10)
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

  vim.wo[BAFA_WIN_ID].winhighlight = "NormalFloat:BafaBorder"

  return {
    bufnr = bufnr,
    win_id = BAFA_WIN_ID,
  }
end

local M = {}

function M.select_menu_item()
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  local selected_buffer = BufferUtils.get_buffer_by_index(selected_line_number)
  if selected_buffer == nil then
    return
  end
  close_window()
  vim.api.nvim_set_current_buf(selected_buffer.number)
end

function M.delete_menu_item()
  local choice = 1
  if BAFA_BUF_ID == nil or not vim.api.nvim_buf_is_valid(BAFA_BUF_ID) then
    return
  end
  local selected_line_number = vim.api.nvim_win_get_cursor(0)[1]
  local selected_buffer = BufferUtils.get_buffer_by_index(selected_line_number)
  if selected_buffer == nil then
    return
  end
  if vim.bo[selected_buffer.number].modified then
    choice = vim.fn.inputlist({ "Yes", "No" })
  end
  if choice ~= 1 then
    return
  end
  if selected_line_number == 1 then
    close_window()
    vim.api.nvim_buf_delete(selected_buffer.number, { force = true })
    M.toggle()
    return
  end
  vim.api.nvim_buf_delete(selected_buffer.number, { force = true })
  vim.api.nvim_buf_set_lines(BAFA_BUF_ID, selected_line_number - 1, selected_line_number, false, {})
end

function M.on_menu_save()
  print(vim.inspect("on_menu_save"))
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
  vim.api.nvim_buf_add_highlight(BAFA_BUF_ID, BAFA_NS_ID, hl_group, idx - 1, 2, 3)
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
  local hl_name = "BafaModified"
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, create = false })
  local fg = "#ffff00"
  if #hl ~= 0 then
    fg = string.format("#%06x", hl.fg)
  end
  vim.api.nvim_set_hl(0, hl_name, { fg = fg })
  vim.api.nvim_buf_add_highlight(BAFA_BUF_ID, BAFA_NS_ID, hl_name, idx - 1, 4, -1)
end

local add_diagnostics_icons = function(idx, buffer)
  if BAFA_BUF_ID == nil then
    return
  end
  local has_diagnostics = false
  local diags = get_diagnostics(buffer.number)
  for _, diagnostic in ipairs(diags) do
    vim.api.nvim_buf_set_extmark(BAFA_BUF_ID, BAFA_NS_ID, idx - 1, 0, {
      virt_text = { { diagnostic[1], diagnostic[2] } },
    })
    has_diagnostics = true
  end
  return has_diagnostics
end

function M.toggle()
  if BAFA_WIN_ID ~= nil and vim.api.nvim_win_is_valid(BAFA_WIN_ID) then
    close_window()
    return
  end

  local win_info = create_window()
  local contents = {}

  BAFA_WIN_ID = win_info.win_id
  BAFA_BUF_ID = win_info.bufnr
  local valid_buffers = BufferUtils.get_buffers_as_table()

  for idx, buffer in ipairs(valid_buffers) do
    local icon, _ = get_buffer_icon(buffer)
    contents[idx] = string.format("  %s %s", icon, buffer.name)
  end

  vim.wo[BAFA_WIN_ID].number = true
  vim.api.nvim_buf_set_name(BAFA_BUF_ID, "bafa-menu")
  vim.api.nvim_buf_set_lines(BAFA_BUF_ID, 0, #contents, false, contents)
  vim.bo[BAFA_BUF_ID].buftype = "nofile"
  vim.bo[BAFA_BUF_ID].bufhidden = "delete"

  local has_diagnostics = false

  for idx, buffer in ipairs(valid_buffers) do
    -- add highlights
    add_ft_icon_highlight(idx, buffer)
    -- add modified highlights
    add_modified_highlight(idx, buffer)
    -- add diagnostics
    if Config.get().diagnostics then
      if add_diagnostics_icons(idx, buffer) == true then
        has_diagnostics = true
      end
    end
  end

  if has_diagnostics then
    -- increase the width of the window to accommodate the diagnostics icons
    vim.api.nvim_win_set_width(BAFA_WIN_ID, vim.api.nvim_win_get_width(BAFA_WIN_ID) + 4)
  end

  Keymaps.noop(BAFA_BUF_ID)
  Keymaps.defaults(BAFA_BUF_ID)
  Autocmds.defaults(BAFA_BUF_ID)
end

return M
