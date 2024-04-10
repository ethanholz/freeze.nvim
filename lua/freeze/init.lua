local loop = vim.loop
local default_output = "freeze.png"

local freeze = {
	opts = {
		output = default_output,
		dir = "."
		config = "base",
	},
	output = nil,
}

local stdio = { stdout = "", stderr = "" }

---The callback for reading stdout.
---@param err any the possible err we received
---@param data any the possible data we received in stdout
local function onReadStdOut(err, data)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
	end
	if data then
		stdio.stdout = stdio.stdout .. data
	end

	if freeze.output == nil then
		return
	end

	if freeze.opts.action == "open" then
		freeze.open(freeze.output)
	end

	if freeze.opts.action == "copy" then
		freeze.copy(freeze.output)
	end

	freeze.output = nil
end

---The callback for reading stderr.
---@param err any the possible err we received
---@param data any the possible data we received in stderr
local function onReadStdErr(err, data)
	if err then
		vim.notify(err, vim.log.levels.ERROR, { title = "Freeze" })
	end
	if data then
		stdio.stderr = stdio.stderr .. data
	end
end

---The function called on exit of from the event loop
---@param message string the success message to render
---@param stdout any the stdout pipe used by vim.loop
---@param stderr any the stderr pipe used by vim.loop
---@return function cb the wrapped schedule function callback
local function onExit(message, stdout, stderr)
	return vim.schedule_wrap(function(code, _)
		if code == 0 then
			vim.notify(message, vim.log.levels.INFO, { title = "Freeze" })
		else
			vim.notify(stdio.stdout, vim.log.levels.ERROR, { title = "Freeze" })
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
		vim.schedule(function()
			vim.notify("`freeze` not found!", vim.log.levels.WARN, { title = "Freeze" })
		end)
		return
	end

	local language = vim.api.nvim_buf_get_option(0, "filetype")
	local file = vim.api.nvim_buf_get_name(0)
	local config = freeze.opts.config
	local dir = freeze.opts.dir
	local stdout = loop.new_pipe(false)
	local stderr = loop.new_pipe(false)
	local output = freeze.opts.output

	if freeze.opts.output ~= default_output then
		local timestamp = os.date("%Y%m%d%H%M%S")
		local filename = file:match("^.+/(.+)$") or file

		output = output:gsub("{timestamp}", timestamp)
		output = output:gsub("{filename}", filename)
		output = output:gsub("{start_line}", start_line)
		output = output:gsub("{end_line}", end_line)
	end

	freeze.output = dir .. "/" .. output

	local handle = loop.spawn("freeze", {
		args = {
			"--output",
			freeze.output,
			"--language",
			language,
			"--lines",
			start_line .. "," .. end_line,
			"--config",
			config,
			file,
		},
		stdio = { nil, stdout, stderr },
	}, onExit("Successfully frozen 🍦 to " .. freeze.output, stdout, stderr))
	if not handle then
		vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
	end
	if stdout ~= nil then
		loop.read_start(stdout, onReadStdOut)
	end
	if stderr ~= nil then
		loop.read_start(stderr, onReadStdErr)
	end
end

--- Opens the last created image in macOS using `open`.
--- @param filename string the filename to open
function freeze.open(filename)
	if vim.fn.executable("open") ~= 1 then
		vim.schedule(function()
			vim.notify("`open` not found!", vim.log.levels.WARN, { title = "Freeze" })
		end)
		return
	end

	local stdout = loop.new_pipe(false)
	local stderr = loop.new_pipe(false)
	local handle = loop.spawn("open", {
		args = {
			filename,
		},
		stdio = { nil, stdout, stderr },
	}, onExit("Opened file using `open`", stdout, stderr))
	if not handle then
		vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
	end
	if stdout ~= nil then
		loop.read_start(stdout, onReadStdOut)
	end
	if stderr ~= nil then
		loop.read_start(stderr, onReadStdErr)
	end
end

--- Copy the last created image in macOS using `open`.
--- @param filename string the filename to open
function freeze.copy(filename)
	if vim.fn.executable("copy") ~= 1 then
		vim.schedule(function()
			vim.notify("`copy` not found!", vim.log.levels.WARN, { title = "Freeze" })
			vim.notify("Consider adding the following script on your path:", vim.log.levels.WARN, { title = "Freeze" })
			vim.notify("", vim.log.levels.WARN, { title = "Freeze" })
			vim.notify("```bash", vim.log.levels.WARN, { title = "Freeze" })
			vim.notify("#!/usr/bin/env bash", vim.log.levels.WARN, { title = "Freeze" })
			vim.notify("", vim.log.levels.WARN, { title = "Freeze" })
			vim.notify(
				"osascript -e{'on run{a}','set the clipboard to posix file a',end} \"$(greadlink -f -- \"$1\")\"; ",
				vim.log.levels.WARN,
				{ title = "Freeze" }
			)
			vim.notify("```", vim.log.levels.WARN, { title = "Freeze" })
		end)
		return
	end

	local stdout = loop.new_pipe(false)
	local stderr = loop.new_pipe(false)
	local handle = loop.spawn("copy", {
		args = {
			filename,
		},
		stdio = { nil, stdout, stderr },
	}, onExit("Copy frozen frame to the clipboard", stdout, stderr))
	if not handle then
		vim.notify("Failed to spawn freeze", vim.log.levels.ERROR, { title = "Freeze" })
	end
	if stdout ~= nil then
		loop.read_start(stdout, onReadStdOut)
	end
	if stderr ~= nil then
		loop.read_start(stderr, onReadStdErr)
	end
end

--- Setup function for enabling both user commands.
--- Sets up :Freeze for freezing a selection and :FreezeLine
--- to freeze a single line.
function freeze.setup(plugin_opts)
	for k, v in pairs(plugin_opts) do
		freeze.opts[k] = v
	end
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
end

return freeze
