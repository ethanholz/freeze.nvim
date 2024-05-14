-- if vim.fn.has("nvim-0.8.0") ~= 1 then
--   vim.api.nvim_err_writeln("[freeze] plugin requires at least NeoVim 0.8.0.")
--   return
-- end

-- Check if plugin is loaded
if vim.g.loaded_freeze_nvim == 1 then
  return
end
vim.g.loaded_freeze_nvim = 1
vim.api.nvim_out_write("[freeze] initialized")
