local buffers = require("bafa.utils.buffers")
local tbl = require("bafa.utils.table")

local TEST_FILE_NAMES = { "testfile1.txt", "testfile2.txt", "testfile3.txt", "testfile4.txt" }
local setupBuffersForTest = function()
  vim.cmd("silent! %bwipeout!")
  for _, filename in ipairs(TEST_FILE_NAMES) do
    vim.cmd("edit " .. filename)
  end
end

describe("UI tests", function()
  before_each(function() setupBuffersForTest() end)

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
      local name_without_icon = lines[idx]:gsub("^%s*%S+%s+", "")
      assert.are_equals(
        filename,
        name_without_icon,
        string.format("Expected line %d to be '%s' but got '%s'", idx, filename, name_without_icon)
      )
    end
  end)
end)
