<div align="center">

![Bafa Logo](logo.svg)

# bafa.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/bafa.nvim?style=for-the-badge)](https://github.com/mistweaverco/bafa.nvim/releases/latest)

[Requirements](#requirements) • [Install](#install) • [Usage](#usage)

<p></p>

A minimal BufExplorer alternative for lazy people for your favorite editor.

Bafa is swahili for "buffer".

It allows you to quickly switch between buffers and delete them.

<p></p>

![demo](demo.png)

<p></p>

</div>

## Requirements

- [Neovim](https://github.com/neovim/neovim) (tested with 0.9.0)

> [!TIP]
> For having fancy icons, you need to install a patched font.
> You can find some patched fonts in the [Nerd Fonts](https://www.nerdfonts.com/) website.
> Also you should consider installing [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
> for having the correct icons based on the ft in the buffer list.

## Install

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

### Simple configuration

```lua
require('lazy').setup({
  -- Buffer management
  { 'mistweaverco/bafa.nvim' },
})
```
### Advanced configuration

```lua
require('lazy').setup({
  -- Buffer management
  {
    'mistweaverco/bafa.nvim',
    opts = {
      title = "Bafa",
      title_pos = "center",
      border = "rounded",
      style = "minimal",
      diagnostics = true, -- Show diagnostics in the buffer list
      line_numbers = false, -- Show line numbers in the buffer list
      icons = {
        diagnostics = {
          Error = "",   -- Icon for error diagnostics
          Warn = "",    -- Icon for warning diagnostics
          Info = "",    -- Icon for info diagnostics
          Hint = "",    -- Icon for hint diagnostics
        },
      },
      -- or "ErrorMsg", "WarningMsg", etc. -- Falls back to WarningMsg if the specified highlight group doesn't exist
      modified_hl = "DiffChanged",
      notify = {
        provider = "notify", -- "notify" or "print"
      },
    }
  },
})

```

## Usage

### `require('bafa.ui').toggle()`

Opens up a floating window with your buffers.

The buffers are ordered by last usage time by default.

Press enter to select a buffer or press `dd` or `D` to delete a buffer.

Press `K` or `J` to move a buffer up or down the list.
Once you move a buffer, the new order will be kept
until you enable ordering by last usage time again (by pressing `o`).

For persistent changes between sessions, consider using
[kikao.nvim](https://github.com/mistweaverco/kikao.nvim).

Press `q` or `<ESC>` to close the window,
without commiting any UI changes.
