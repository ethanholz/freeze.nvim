local freeze = {}

function freeze.freeze(start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	-- Escape our input for the shell
	local input = table.concat(lines, "\n"):gsub('"', '\\"')
	local language = vim.api.nvim_buf_get_option(0, "filetype")
	local command = string.format('echo "%s" | freeze --language %s', input, language)
	local job_opts = {
		on_exit = function(_, code)
			if code == 0 then
				vim.notify("Successfully frozen 🍦", vim.log.levels.INFO, { title = "Freeze" })
			else
				vim.notify("Failed to freeze", vim.log.levels.ERROR, { title = "Freeze" })
			end
		end,
	}
	vim.fn.jobstart(command, job_opts)
end

function freeze.setup()
	vim.api.nvim_create_user_command("Freeze", function(opts)
		freeze.freeze(opts.line1, opts.line2)
	end, { range = "%" })
end

return freeze
