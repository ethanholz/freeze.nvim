# freeze.nvim
A tool for using [freeze](https://github.com/charmbracelet/freeze) right from Neovim!

## Requirements
- [freeze](https://github.com/charmbracelet/freeze) must be installed and on your path

> [!note]
>
> You can check all the dependencies by running `:checkhealth freeze` on NeoVim.

## Installation
[lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "ethanholz/freeze.nvim",
    config = true,
}
```

## Usage
- `:Freeze` - Can be called on a visual selection to pass in a selection of lines.
- `:FreezeLine` - A convenience function for freezing the current line.

## Keymaps
It is recommended that you set keymaps to run these commands, no default keymaps are set for you.
An example of how you can set your keymaps can be seen below:
```lua
vim.keymap.set("v", "<leader>z", ":Freeze<cr>", {silent = true, desc = "Freeze selection"})
vim.keymap.set("n", "<leader>zl", ":FreezeLine<cr>", {silent = true, desc = "Freeze current line"})
```
