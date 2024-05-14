local loop = vim.loop
local default_output = "freeze.png"

local freeze = {
	opts = {
		dir = vim.env.PWD,
		output = default_output,
		theme = "default",
		config = "base",
		open = false,
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
	if freeze.opts.open and freeze.output ~= nil then
		freeze.open(freeze.output)
		freeze.output = nil
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
		stdio.stderr = stdio.stderr .. data
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
--- @param start_line number|nil the starting line to pass to freeze
--- @param end_line number|nil the ending line to pass to freeze
function freeze.freeze(start_line, end_line)
	if vim.fn.executable("freeze") ~= 1 then
		vim.notify("`freeze` not found!", vim.log.levels.WARN, { title = "Freeze" })
		return
	end
	start_line = start_line or 1
	end_line = end_line or vim.api.nvim_buf_line_count(0)

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
			"--theme",
			freeze.opts.theme,
			file,
		},
		stdio = { nil, stdout, stderr },
	}, onExit(stdout, stderr))
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
		vim.notify("`open` not found!", vim.log.levels.WARN, { title = "Freeze" })
		return
	end

	local stdout = loop.new_pipe(false)
	local stderr = loop.new_pipe(false)
	local handle = loop.spawn("open", {
		args = {
			filename,
		},
		stdio = { nil, stdout, stderr },
	}, onExit(stdout, stderr))
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
	freeze.opts = vim.tbl_extend("force", {}, freeze.opts, plugin_opts or {})
	vim.api.nvim_create_user_command("Freeze", function(opts)
		if opts.count > 0 then
			freeze.freeze(opts.line1, opts.line2)
		else
			freeze.freeze()
		end
	end, { range = true })
	vim.api.nvim_create_user_command("FreezeLine", function(_)
		local line = vim.api.nvim_win_get_cursor(0)[1]
		freeze.freeze(line, line)
	end, {})
end

return freeze
