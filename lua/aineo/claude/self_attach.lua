--- Telling, from a terminal's screen, that Claude Code has attached the
--- terminal to a background session by itself: a `/resume` typed inside
--- Claude Code for a session that runs in Claude Code's background service
--- prints `Opening "<title>", running in the background (<short id>)` and
--- attaches. Nothing else tells aineo: the session does not show in
--- `claude agents --json` under the terminal's own process.

local M = {}

--- How many of the last lines of the terminal buffer are read for the line.
local LINES_READ = 40

--- The line, read from the screen's text with every white space removed,
--- since Claude Code breaks a line at a blank where the terminal is narrower
--- than it, dropping that blank, and a terminal row may also end on a blank
--- of its own: the title in quotes, the words, then the short id in
--- parentheses.
local LINE_PATTERN = 'Opening".-",runninginthebackground%((%x+)%)'

--- The short id of the background session the last lines of the terminal
--- `buffer` say Claude Code attached it to; the last such line's when there
--- are several. Nil when they say none.
---
---@param buffer integer a terminal buffer
---@return string?
local function attached_short_id(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, -LINES_READ - 1, -1, false)
  local text = table.concat(lines):gsub('%s', '')
  local found
  for short_id in text:gmatch(LINE_PATTERN) do
    found = short_id
  end
  return found
end

--- Calls `on_attached(short_id)` from a scheduled callback each time the
--- screen of `buffer` first says Claude Code attached the terminal to the
--- background session `short_id`: once for each id in a row, however many
--- times the line stays on the screen. Called before the terminal starts, it
--- reads the buffer at every change and stops with the buffer.
---
---@param buffer integer the buffer Claude Code's terminal runs in
---@param on_attached fun(short_id: string)
function M.watch(buffer, on_attached)
  local told
  local scheduled = false
  vim.api.nvim_buf_attach(buffer, false, {
    on_lines = function()
      if scheduled then
        return
      end
      scheduled = true
      vim.schedule(function()
        scheduled = false
        if not vim.api.nvim_buf_is_valid(buffer) then
          return
        end
        local short_id = attached_short_id(buffer)
        if short_id and short_id ~= told then
          told = short_id
          on_attached(short_id)
        end
      end)
    end,
  })
end

return M
