stds.nvim = {
  read_globals = { "jit" },
}

std = "lua51+nvim"

read_globals = {
  "vim",
  "describe",
  "it",
  "before_each",
  "after_each",
  "assert",
}

globals = {
  "_G",
  "stds",
  "std",
  "globals",
  "read_globals",
  "vim.g",
  "vim.b",
  "vim.w",
  "vim.o",
  "vim.bo",
  "vim.wo",
  "vim.go",
  "vim.env",
  "vim.opt",
}
