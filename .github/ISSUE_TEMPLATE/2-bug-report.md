---
name: Bug report
about: Create a report to help us improve
title: "bug(plugin): "
labels: bug
type: bug
assignees:
  - gorillamoe

---

Please provide a clear and concise description of what the bug is.

Ideally you can provide an isolated example to help us reproduce the issue.

You can use the following template:

```lua
vim.o.termguicolors = true
vim.opt.swapfile = false
vim.opt.shada = ""
vim.opt.rtp = {
  vim.env.VIMRUNTIME,
  vim.fn.getcwd(),
}
vim.cmd("runtime! plugin/bafa.nvim")
require("bafa").setup({
  -- your config here
})

-- Steps to reproduce
-- e.g.

-- Your code that triggers the bug here
```

Save it as `minimal_repro.lua`
in a clone of the repository.

Then run it with `nvim -u minimal_repro.lua`.

This helps us understand the exact issue in an isolated environment.

Attach the `minimal_repro.lua` file to this issue report.
