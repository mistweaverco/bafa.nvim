# bafa.nvim

Minimal BufExplorer alternative.

## Requirements

- [Neovim](https://github.com/neovim/neovim) (tested with 0.9.0)

## Installation

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
    config = function()
      require('bafa').setup({
        width = 60,
        height = 10,
        title = "Bafa",
        title_pos = "center",
        relative = "editor",
        border = "rounded",
        style = "minimal",
      })
    end,
  },
})

```

## Public methods

### `require('bafa.ui').toggle()`

Opens up a floating window with your buffers.

Press enter to select a buffer or press `dd` or `D` to delete a buffer.

![](bafa.gif)
