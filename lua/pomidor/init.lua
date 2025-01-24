-- plugin/pomodoro.lua
local api = vim.api
local timer = vim.loop.new_timer()
local notify = require("notify")
local Path = require("plenary.path") -- Added dependency for file operations

-- State management
local M = {
	active_timer = nil,
	remaining_time = 0,
	timer_label = "",
	is_running = false,
	history = {},
	history_file = nil,
}

-- Initialize history file path
local function init_history_file()
	local config_dir = vim.fn.stdpath("data")
	M.history_file = Path:new(config_dir .. "/pomidor_history.json")

	-- Create directory if it doesn't exist
	Path:new(config_dir):mkdir({ parents = true, exists_ok = true })

	-- Create history file if it doesn't exist
	if not M.history_file:exists() then
		M.history_file:write("[]", "w")
	end
end

-- Load history from file
local function load_history()
	if not M.history_file then
		init_history_file()
	end

	local content = M.history_file:read()
	M.history = vim.json.decode(content) or {}
end

-- Save history to file
local function save_history()
	if not M.history_file then
		init_history_file()
	end

	local content = vim.json.encode(M.history)
	M.history_file:write(content, "w")
end

-- Add completed session to history
local function add_to_history(duration, label, completed)
	local session = {
		date = os.date("%Y-%m-%d"),
		time = os.date("%H:%M"),
		duration = duration,
		label = label,
		completed = completed,
	}

	table.insert(M.history, session)
	save_history()
end

-- Format time for display
local function format_time(seconds)
	local minutes = math.floor(seconds / 60)
	local remaining_seconds = seconds % 60
	return string.format("%02d:%02d", minutes, remaining_seconds)
end

-- Update status line
local function update_status()
	if M.is_running then
		vim.o.statusline = string.format("🍅 %s: %s", M.timer_label, format_time(M.remaining_time))
	end
end

-- Timer tick function
local function tick()
	if M.remaining_time > 0 then
		M.remaining_time = M.remaining_time - 1
		update_status()
	else
		M.is_running = false
		timer:stop()
		-- Add completed session to history
		add_to_history(M.initial_duration, M.timer_label, true)
		notify("🍅 Timer Complete!", "info", {
			title = M.timer_label,
			timeout = 10000,
		})
		vim.o.statusline = ""
	end
end

-- Start a new timer
function M.start_timer(minutes, label)
	if M.is_running then
		-- Add interrupted session to history
		add_to_history(M.initial_duration, M.timer_label, false)
		timer:stop()
	end

	M.remaining_time = minutes * 60
	M.initial_duration = minutes
	M.timer_label = label or "Pomidor"
	M.is_running = true

	timer:start(0, 1000, vim.schedule_wrap(tick))
	update_status()
end

-- Stop the current timer
function M.stop_timer()
	if M.is_running then
		timer:stop()
		M.is_running = false
		-- Add stopped session to history
		add_to_history(M.initial_duration, M.timer_label, false)
		vim.o.statusline = ""
	end
end

-- Display session history in a new buffer
function M.show_history()
	-- Create new buffer
	local buf = api.nvim_create_buf(false, true)

	-- Set buffer options using vim.bo
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true

	-- Format history data
	local lines = { "🍅 Pomidor Session History", "" }
	local date_groups = {}

	-- Group sessions by date
	for _, session in ipairs(M.history) do
		if not date_groups[session.date] then
			date_groups[session.date] = {}
		end
		table.insert(date_groups[session.date], session)
	end

	-- Sort dates and format output
	local dates = vim.tbl_keys(date_groups)
	table.sort(dates, function(a, b)
		return a > b
	end)

	for _, date in ipairs(dates) do
		table.insert(lines, "📅 " .. date)
		for _, session in ipairs(date_groups[date]) do
			local status = session.completed and "✅" or "⏹️"
			table.insert(
				lines,
				string.format("  %s %s - %d minutes: %s", status, session.time, session.duration, session.label)
			)
		end
		table.insert(lines, "")
	end

	-- Set buffer contents
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- Open in new window
	api.nvim_command("vsplit")
	local win = api.nvim_get_current_win()
	api.nvim_win_set_buf(win, buf)
end

-- Pause/Resume the timer
function M.toggle_timer()
	if not M.is_running then
		if M.remaining_time > 0 then
			M.is_running = true
			timer:start(0, 1000, vim.schedule_wrap(tick))
			update_status()
		end
	else
		timer:stop()
		M.is_running = false
	end
end

-- Set up commands
local function setup()
	-- Load existing history
	load_history()

	-- Create user commands
	api.nvim_create_user_command("PomidorStart", function(opts)
		local args = vim.split(opts.args, " ")
		local minutes = tonumber(args[1])
		local label = table.concat({ unpack(args, 2) }, " ")
		if minutes then
			M.start_timer(minutes, label)
		else
			print("Usage: PomidorStart <minutes> [label]")
		end
	end, {
		nargs = "+",
		desc = "Start a pomidor timer",
	})

	api.nvim_create_user_command("PomidorStop", function()
		M.stop_timer()
	end, {
		desc = "Stop the current pomidor timer",
	})

	api.nvim_create_user_command("PomidorToggle", function()
		M.toggle_timer()
	end, {
		desc = "Pause/Resume the current pomidor timer",
	})

	api.nvim_create_user_command("PomidorHistory", function()
		M.show_history()
	end, {
		desc = "Show pomidor session history",
	})
end

return {
	setup = setup,
	start_timer = M.start_timer,
	stop_timer = M.stop_timer,
	toggle_timer = M.toggle_timer,
	show_history = M.show_history,
}
