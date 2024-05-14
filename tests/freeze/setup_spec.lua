local loop = vim.loop
local api = vim.api
local buf = nil
local win = nil
local delay = 5000

local function create_buffer()
	local width = vim.o.columns
	local height = vim.o.lines
	local height_ratio = 0.7
	local width_ratio = 0.7
	local win_height = math.ceil(height * height_ratio)
	local win_width = math.ceil(width * width_ratio)
	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - win_width) / 2)
	local win_opts = {
		style = "minimal",
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		border = "none",
	}
	vim.loop.chdir(vim.env.PWD .. "/tests/mocks")
	buf = api.nvim_create_buf(false, true)
	win = api.nvim_open_win(buf, true, win_opts)

	api.nvim_win_set_option(win, "winblend", 0)
	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "filetype", "typescript")
	api.nvim_buf_set_name(buf, "testing.ts")

	return buf
end

local function get_image_path()
	return vim.loop.fs_stat(vim.env.PWD .. "/freeze.png")
end

describe("[freeze.nvim tests]", function()
	local default_opts = {
		dir = vim.env.PWD,
		output = "freeze.png",
		theme = "default",
		config = "base",
		open = false,
	}
	local freeze = require("freeze")
	local same = assert.are.same
	before_each(function()
		freeze.setup(default_opts)
	end)
	describe("sets", function()
		it("autocommands", function()
			vim.cmd("runtime lua/freeze.lua")
			freeze.setup()
			local user_commands = api.nvim_get_commands({})
			assert.are.not_same(nil, user_commands.Freeze)
			assert.are.not_same(nil, user_commands.FreezeLine)
		end)

		it("up with default config", function()
			local expected = {
				dir = vim.env.PWD,
				output = "freeze.png",
				theme = "default",
				config = "base",
				open = false,
			}
			local actual = require("freeze")
			freeze.setup()
			same(expected, actual.opts)
		end)

		it("up with custom config", function()
			local opts = {
				dir = "/tmp/freeze_images",
				theme = "rose-pine-moon",
			}
			freeze.setup(opts)
			local actual = freeze.opts
			local expected = vim.tbl_deep_extend("force", {}, actual, opts or {})
			same(expected.dir, actual.dir)
			same("/tmp/freeze_images", actual.dir)
			same(expected.theme, expected.theme)
			same("rose-pine-moon", actual.theme)
			same(expected, actual)
		end)
	end)

	describe("freezes", function()
		-- Change directory to original and close opened windows
		before_each(function()
			loop.chdir(vim.env.PWD)
			if win ~= nil and buf ~= nil then
				api.nvim_win_close(win, true)
				win = nil
			end
			os.remove(vim.env.PWD .. "/freeze.png")
		end)

		-- Change directory to original and remove created image
		after_each(function()
			loop.chdir(vim.env.PWD)
			os.remove(vim.env.PWD .. "/freeze.png")
		end)

		it("an entire file", function()
			local buffer = create_buffer()

			freeze.setup()
			api.nvim_buf_call(buffer, freeze.freeze)

			-- waits `delay` time and if founds the image it stops
			if vim.wait(delay, function()
				return get_image_path() ~= nil
			end) then
				local actual = get_image_path()
				assert.are.not_same(nil, actual)
			end
		end)

		it("a range of a file", function()
			local buffer = create_buffer()

			freeze.setup()
			api.nvim_buf_call(buffer, function()
				freeze.freeze(1, 2)
			end)

			if vim.wait(delay, function()
				return get_image_path() ~= nil
			end) then
				local actual = get_image_path()
				assert.are.not_same(nil, actual)
			end
		end)

		it("a line of a file", function()
			local buffer = create_buffer()

			freeze.setup()
			api.nvim_buf_call(buffer, function()
				if win ~= nil then
					api.nvim_win_set_cursor(win, { 1, 2 })
					local row_col = api.nvim_win_get_cursor(win)
					local line = row_col[2]
					freeze.freeze(line, line)
				else
					api.nvim_err_writeln("window is nil")
				end
			end)

			if vim.wait(delay, function()
				return get_image_path() ~= nil
			end) then
				local actual = get_image_path()
				assert.are.not_same(nil, actual)
			end
		end)
	end)
end)
