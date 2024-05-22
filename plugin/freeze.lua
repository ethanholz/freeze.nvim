if vim.fn.has("nvim-0.8.0") ~= 1 then
	local current = vim.version()
	local msg = string.format(
		"[freeze.nvim] ERROR: this plugin requires at least NeoVim v0.8.0, your current version is v%s.%s.%s",
		current.major,
		current.minor,
		current.patch
	)
	vim.api.nvim_err_writeln(msg)
	return
end

-- Check if plugin is loaded
if vim.g.loaded_freeze_nvim == 1 then
	return
end
vim.g.loaded_freeze_nvim = 1
vim.api.nvim_out_write("[freeze.nvim] initialized")

local freeze = require("freeze")

vim.api.nvim_create_user_command("Freeze", function(opts)
	if opts.count > 0 then
		freeze.freeze(opts.line1, opts.line2)
	else
		freeze.freeze(1, vim.api.nvim_buf_line_count(0))
	end
end, { range = true })
vim.api.nvim_create_user_command("FreezeLine", function(_)
	local line = vim.api.nvim_win_get_cursor(0)[1]
	freeze.freeze(line, line)
end, {})
