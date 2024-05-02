local loop = vim.loop
local default_output = "freeze.png"

local freeze = {
	opts = {
		dir = ".",
		output = default_output,
		theme = "default",
		config = "base",
		open = false,
	},
	output = nil,
}
local stdio = { stdout = "", stderr = "" }

local freeze_path = vim.fn.exepath("freeze")
local freeze_version = "0.1.6"

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

-- Get the filename for the release (e.g. freeze_<version>_<os>_<arch>)
---@return string
local function get_freeze_filename()
	local os, arch

	local raw_os = vim.loop.os_uname().sysname
	local raw_arch = jit.arch
	local os_patterns = {
		["Windows"] = "Windows",
		["Windows_NT"] = "Windows",
		["Linux"] = "Linux",
		["Darwin"] = "Darwin",
		["BSD"] = "Freebsd",
	}

	local arch_patterns = {
		["x86"] = "i386",
		["x64"] = "x86_64",
		["arm"] = "arm7",
		["arm64"] = "arm64",
	}

	os = os_patterns[raw_os]
	arch = arch_patterns[raw_arch]

	if os == nil or arch == nil then
		vim.notify("os not supported or could not be parsed", vim.log.levels.ERROR, { title = "Freeze" })
		return ""
	end
	local filename = "freeze_" .. freeze_version .. "_" .. os .. "_" .. arch
	return filename
end

---Get the release archive file extension depending on OS
---@return string extension
local function get_archive_extension()
	local os, arch

	-- local raw_os = jit.os
	local raw_os = vim.loop.os_uname().sysname
	local raw_arch = jit.arch
	local os_patterns = {
		["Windows"] = "Windows",
		["Windows_NT"] = "Windows",
		["Linux"] = "Linux",
		["Darwin"] = "Darwin",
		["BSD"] = "Freebsd",
	}

	local arch_patterns = {
		["x86"] = "i386",
		["x64"] = "x86_64",
		["arm"] = "arm7",
		["arm64"] = "arm64",
	}

	os = os_patterns[raw_os]
	arch = arch_patterns[raw_arch]

	return (os == "Windows" and ".zip" or ".tar.gz")
end

---Get the release file for the right OS and Architecture from official release
---page, https://github.com/charmbracelet/freeze/releases, for the specified version
---@return string release_url
local function release_file_url()
	-- check pre-existence of required programs
	if vim.fn.executable("curl") == 0 or vim.fn.executable("tar") == 0 then
		vim.notify("curl and/or tar are required", vim.log.levels.ERROR, { title = "Freeze" })
		return ""
	end

	local filename = get_freeze_filename() .. get_archive_extension()

	-- create the url, filename based on os and arch
	return "https://github.com/charmbracelet/freeze/releases/download/v" .. freeze_version .. "/" .. filename
end

local function agnostic_installation()
	local release_url = release_file_url()
	if release_url == "" then
		vim.notify("could not get release file", vim.log.levels.ERROR, { title = "Freeze" })
		return
	end

	local install_path = os.getenv("HOME") .. "/.local/bin"
	local output_filename = "freeze.tar.gz"
	local download_command = { "curl", "-sL", "-o", output_filename, release_url }
	local extract_command = { "tar", "-zxf", output_filename, "-C", install_path }
	local binary_path = vim.fn.expand(table.concat({ install_path, get_freeze_filename() .. "/freeze" }, "/"))

	-- check for existing files / folders
	if vim.fn.isdirectory(install_path) == 0 then
		vim.loop.fs_mkdir(install_path, tonumber("777", 8))
	end

	if vim.fn.filereadable(binary_path) == 1 then
		local success = vim.loop.fs_unlink(binary_path)
		if not success then
			vim.notify("freeze binary could not be removed!", vim.log.levels.ERROR, { tittle = "Freeze" })
			return
		end
	end

	-- download and install the freeze binary
	local callbacks = {
		on_sterr = vim.schedule_wrap(function(_, data, _)
			local out = table.concat(data, "\n")
			onReadStdErr(out)
		end),
		on_exit = vim.schedule_wrap(function()
			vim.fn.system(extract_command)
			-- remove the archive after completion
			if vim.fn.filereadable(output_filename) == 1 then
				local success = vim.loop.fs_unlink(output_filename)
				if not success then
					vim.notify("existing archive could not be removed", vim.log.levels.ERROR, { tittle = "Freeze" })
					return
				end
			end
			loop.spawn("mv", { args = { binary_path, install_path .. "/freeze" } })
			binary_path = install_path .. "/freeze"
			freeze_path = binary_path
			freeze.setup(freeze.opts)
			loop.spawn("rm", { args = { "-rf", install_path .. "/" .. get_freeze_filename() } })
		end),
	}
	vim.fn.jobstart(download_command, callbacks)
end

---Freeze installation using `go install`
local function go_installation()
	vim.fn.jobstart({ "go", "install", "github.com/charmbracelet/freeze@latest" }, {
		on_sterr = vim.schedule_wrap(function(_, data, _)
			local out = table.concat(data, "\n")
			onReadStdErr(out)
		end),
		on_exit = vim.schedule_wrap(function()
			vim.notify(
				"go install github.com/charmbracelet/freeze@latest completed",
				vim.log.levels.INFO,
				{ title = "Freeze" }
			)
		end),
	})
end

---Freeze installation process
---
---Using `go` if it is installed, otherwise, using the release URL download
local function install_freeze()
	if vim.fn.exepath("go") ~= "" then
		go_installation()
		return
	end
	agnostic_installation()
end

local function get_executable()
	if freeze_path ~= "" then
		return freeze_path
	end
	return vim.fn.exepath("freeze")
end

--- The main function used for passing the main config to lua
---
--- This function will take your lines and the found Vim filetype and pass it
--- to `freeze --language <vim filetype> --lines <start_line>,<end_line> <file>`
--- @param start_line number the starting line to pass to freeze
--- @param end_line number the ending line to pass to freeze
function freeze.freeze(start_line, end_line)
	if get_executable() == "" then
		vim.notify("`freeze` not found!", vim.log.levels.WARN, { title = "Freeze" })
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
	if get_executable() == "" then
		vim.notify("installing `freeze` ...", vim.log.levels.INFO, { title = "Freeze" })
		install_freeze()
		return
	end
end

return freeze
