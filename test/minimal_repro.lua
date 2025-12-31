vim.o.termguicolors = true
vim.opt.swapfile = false
vim.opt.shada = ""
vim.opt.rtp = {
  vim.env.VIMRUNTIME,
  vim.fn.getcwd(),
}
vim.cmd("runtime! plugin/bafa.vim")
require("bafa").setup()
