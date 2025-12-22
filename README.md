<div align="center">

![Bafa Logo](logo.svg)

# bafa.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/bafa.nvim?style=for-the-badge)](https://github.com/mistweaverco/bafa.nvim/releases/latest)

[Requirements](#requirements) • [Install](#install) • [Usage](#usage)

<p></p>

A minimal BufExplorer alternative for lazy people for your favorite editor.

Bafa is swahili for "buffer."

It allows you to quickly switch between buffers and delete them.

<p></p>

![demo](demo.png)

<p></p>

</div>

## Requirements

- [Neovim](https://github.com/neovim/neovim) (tested with 0.9.0)

> [!TIP]
> You need to install a patched nerd-font for
> having the icons displayed correctly.
> You can find some patched fonts on the [Nerd Fonts](https://www.nerdfonts.com/) website.
> You should also consider installing [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
> for having the correct icons based on the filetye in the buffer list.

## Install

Please use release tags when installing the plugin to ensure
compatibility and stability.

The `main` branch may contain breaking changes
and isn't guaranteed to be stable.

### Lazy.nvim

See: [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'mistweaverco/bafa.nvim',
  version = 'v3.4.0',
  opts = {}
},
```

> [!IMPORTANT]
> `opts` needs to be at least an empty table `{}` and
> can't be completely omitted.

### Packer.nvim

See: [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'mistweaverco/bafa.nvim',
  tag = 'v3.4.0',
  config = function()
    require('bafa').setup({})
  end
})
```

> [!IMPORTANT]
> `setup` call needs to have at least an empty table `{}` and
> can't be completely omitted.

### Neovim built-in package manager

```lua
vim.pack.add({
  src = 'https://github.com/mistweaverco/bafa.nvim.git',
  version = 'v3.4.0',
})
require('bafa').setup({})
```

> [!IMPORTANT]
> `setup` call needs to have at least an empty table `{}` and
> can't be completely omitted.


### Configuration options

```lua
return {
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
