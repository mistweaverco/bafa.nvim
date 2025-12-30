vim.o.termguicolors = true
vim.opt.swapfile = false
vim.opt.shada = ""
vim.opt.rtp = {
  vim.env.VIMRUNTIME,
  vim.fn.getcwd(),
}
vim.cmd("runtime! plugin/bafa.vim")
local fs = require("lua.bafa.utils.fs")
local git = require("bafa.utils.git")
local plenary_path = fs.join_paths(vim.fn.getcwd(), "test", "tmp", "plugins", "plenary.nvim")
if not fs.exists(plenary_path) then git.clone_sync(git.plenary_repo_url, plenary_path) end
vim.opt.rtp:append(plenary_path)
vim.cmd("runtime! plugin/plenary.vim")
_G.TEST = true
