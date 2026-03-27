local buffers = require("bafa.utils.buffers")
local tbl = require("bafa.utils.table")

local TEST_FILE_NAMES = { "testfile1.txt", "testfile2.txt", "testfile3.txt", "testfile4.txt" }
local setupBuffersForTest = function()
  vim.opt.swapfile = false
  vim.cmd("silent! %bwipeout!")
  for _, filename in ipairs(TEST_FILE_NAMES) do
    vim.cmd("edit " .. filename)
  end
end

describe("UI tests", function()
  before_each(function() setupBuffersForTest() end)
  after_each(function() package.loaded["nvim-web-devicons"] = nil end)

  it("opens the buffer list floating window", function()
    require("bafa").toggle()

    local wins = vim.api.nvim_list_wins()

    -- there should be window: main + floating bafa UI
    assert.are_equals(#wins, 2)

    -- last window should be floating
    local float_win = wins[#wins]
    local config = vim.api.nvim_win_get_config(float_win)
    assert.are_equals(config.relative, "editor")
  end)

  it("setting up buffers works as expected", function() assert.are_equals(4, #vim.api.nvim_list_bufs()) end)

  it("shows all buffers in the correct order", function()
    require("bafa").toggle()
    local win = buffers.get_window_by_bufname("bafa-menu")
    if not win then
      error("Could not find bafa-menu window")
      return
    end
    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local reversed_test_file_names = tbl.reverse(TEST_FILE_NAMES)

    assert.are_equals(#TEST_FILE_NAMES, #lines, "Number of lines in buffer does not match number of test files")

    for idx, filename in ipairs(reversed_test_file_names) do
      -- remove icon and trailing spaces
      local name_without_icon = lines[idx]:gsub("^%s*%S+%s+", ""):gsub("%s+$", "")
      assert.are_equals(
        filename,
        name_without_icon,
        string.format("Expected line %d to be '%s' but got '%s'", idx, filename, name_without_icon)
      )
    end
  end)

  it("does not error when devicons highlight has no fg (link or empty)", function()
    -- Simulate nvim-web-devicons returning a highlight group that has no explicit `fg`.
    package.loaded["nvim-web-devicons"] = {
      get_icon = function() return "", "DevIconNoFg" end,
    }

    -- Create a group with no fg by linking it to another group.
    vim.api.nvim_set_hl(0, "DevIconTarget", { fg = 0x00FF00 })
    vim.api.nvim_set_hl(0, "DevIconNoFg", { link = "DevIconTarget" })

    local ok, err = pcall(function() require("bafa").toggle() end)

    assert.is_true(ok, err)
  end)

  it("applies devicons icon and highlight group when icon exists", function()
    package.loaded["nvim-web-devicons"] = {
      get_icon = function() return "X", "DevIconExisting" end,
    }

    vim.api.nvim_set_hl(0, "DevIconExisting", { fg = 0xFF00FF })

    require("bafa").toggle()

    local win = buffers.get_window_by_bufname("bafa-menu")

    if win == nil then
      error("Could not find bafa-menu window")
      return
    end

    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_true(#lines > 0)

    -- Icon should be the first non-space token on each UI line.
    local first_icon = lines[1]:match("^%s*(%S+)%s+")
    assert.are_equals("X", first_icon)

    local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })

    local found = false
    for _, mark in ipairs(extmarks) do
      local details = mark[4]
      if details and details.hl_group == "DevIconExisting" then
        found = true
        break
      end
    end

    assert.is_true(found, "Expected at least one icon extmark using DevIconExisting highlight")
  end)
end)
