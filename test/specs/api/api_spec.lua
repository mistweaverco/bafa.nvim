local tbl = require("bafa.utils.table")

local TEST_FILE_NAMES = { "testfile1.txt", "testfile2.txt", "testfile3.txt", "testfile4.txt" }

local function setup_buffers_for_test()
  vim.opt.swapfile = false
  vim.cmd("silent! %bwipeout!")
  for _, filename in ipairs(TEST_FILE_NAMES) do
    vim.cmd("edit " .. filename)
  end
end

local function current_filename()
  local full = vim.api.nvim_buf_get_name(0)
  return vim.fn.fnamemodify(full, ":t")
end

local function bufnr_for_filename(filename)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if vim.fn.fnamemodify(name, ":t") == filename then return bufnr end
    end
  end
  return nil
end

describe("API tests", function()
  before_each(function()
    setup_buffers_for_test()
    -- Ensure we start from a clean bafa state each time.
    package.loaded["bafa.api"] = nil
    package.loaded["bafa.utils.state"] = nil
  end)

  it("switches to the buffer at the given UI index (1-indexed)", function()
    -- After setup, the most recently used buffer is testfile4.txt, and the UI order is reversed.
    local reversed = tbl.reverse(TEST_FILE_NAMES)

    assert.are_equals("testfile4.txt", current_filename())

    local ok = require("bafa.api").switch_to_buffer(2)
    assert.is_true(ok)
    assert.are_equals(reversed[2], current_filename())

    ok = require("bafa.api").switch_to_buffer(4)
    assert.is_true(ok)
    assert.are_equals(reversed[4], current_filename())
  end)

  it("returns false for out-of-range indices", function()
    local api = require("bafa.api")
    assert.is_false(api.switch_to_buffer(0))
    assert.is_false(api.switch_to_buffer(-1))
    assert.is_false(api.switch_to_buffer(999))
  end)

  it("can alternate between the two most recent buffers by repeatedly selecting index 2", function()
    local api = require("bafa.api")

    assert.are_equals("testfile4.txt", current_filename())

    local ok = api.switch_to_buffer(2)
    assert.is_true(ok)
    assert.are_equals("testfile3.txt", current_filename())

    ok = api.switch_to_buffer(2)
    assert.is_true(ok)
    assert.are_equals("testfile4.txt", current_filename())
  end)

  it("skips wiped/deleted buffers when computing UI indices", function()
    -- Wipe out the third file's buffer; it should disappear from the UI list and indices should shift.
    local bufnr = bufnr_for_filename("testfile3.txt")
    assert.is_not_nil(bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })

    -- Remaining UI order should be: 4, 2, 1
    local api = require("bafa.api")
    local ok = api.switch_to_buffer(2)
    assert.is_true(ok)
    assert.are_equals("testfile2.txt", current_filename())
  end)
end)

