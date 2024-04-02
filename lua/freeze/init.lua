local loop = vim.loop
local freeze = {}
local output = { stdout = "", stderr = "" }

---The callback for reading stdout.
---@param err any the possible err we received
---@param data any the possible data we received in stdout
local function onReadStdOut(err, data)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
	end
	if data then
		output.stdout = output.stdout .. data
	end
end

---The callback for reading stderr.
---@param err any the possible err we received
---@param data any the possible data we received in stderr
local function onReadStdErr(err, data)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
	end
	if data then
		output.stderr = output.stderr .. data
	end
end

---The function called on exit of from the event loop
---@param stdout any the stdout pipe used by vim.loop
---@param stderr any the stderr pipe used by vim.loop
---@return function cb the wrapped schedule function callback
local function onExit(stdout, stderr)
	return vim.schedule_wrap(function(code, _)
		if code == 0 then
			vim.notify("Successfully frozen 🍦", vim.log.levels.INFO, { title = "Freeze" })
		else
			vim.notify(output.stdout, vim.log.levels.ERROR, { title = "Freeze" })
		end
		stdout:read_stop()
		stderr:read_stop()
		stdout:close()
		stderr:close()
	end)
end

--- The main function used for passing the main config to lua
---
--- This function will take your lines and the found Vim filetype and pass it
--- to `freeze --language <vim filetype> --lines <start_line>,<end_line> <file>`
--- @param start_line number the starting line to pass to freeze
--- @param end_line number the ending line to pass to freeze
function freeze.freeze(start_line, end_line)
	if vim.fn.executable("freeze") ~= 1 then
		vim.notify("`freeze` not found!", vim.log.levels.WARN, { title = "Freeze" })
		return
	end
	local language = vim.api.nvim_buf_get_option(0, "filetype")
	local file = vim.api.nvim_buf_get_name(0)
	local stdout = loop.new_pipe(false)
	local stderr = loop.new_pipe(false)
	local handle = loop.spawn("freeze", {
		args = { "--language", language, "--lines", start_line .. "," .. end_line, file },
		stdio = { nil, stdout, stderr },
	}, onExit(stdout, stderr))
	if not handle then
		vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
	end
	loop.read_start(stdout, onReadStdOut)
	loop.read_start(stderr, onReadStdErr)
end

--- Setup function for enabling both user commands.
--- Sets up :Freeze for freezing a selection and :FreezeLine
--- to freeze a single line.
function freeze.setup()
	vim.api.nvim_create_user_command("Freeze", function(opts)
		if opts.count > 0 then
			freeze.freeze(opts.line1, opts.line2)
		else
			freeze.freeze(1, vim.api.nvim_buf_line_count(0))
		end
	end, { range = true })
	vim.api.nvim_create_user_command("FreezeLine", function(opts)
		local line = vim.api.nvim_win_get_cursor(0)[1]
		freeze.freeze(line, line)
	end, {})
end

return freeze
