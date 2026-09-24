--- When Claude Code, running in a terminal buffer, is ready for input: while
--- its screen shows its input box, and no dialog in its place.
---
--- The screens this reads are Claude Code's own, recorded in Neovim 0.11.6
--- terminals and replayed by the suites from `tests/fixtures/claude/`:
--- 2.1.281's startup, input box, two-line draft, MCP-server approval dialog
--- and permission dialog, and 2.1.280's workspace-trust dialog.

local M = {}

--- The glyph that opens the input box's first line. A dialog's selected
--- choice carries it too (the trust dialog's `❯ No, exit`, the MCP-server
--- dialog's `❯ Continue without using this MCP server`, the permission
--- dialog's `❯ 1. Yes`), indented and between no rules.
local PROMPT = '❯'

--- The character the rules above and below the input box are drawn with.
local RULE = '─'

--- How the lines a draft continues on, under the prompt's line, begin.
local DRAFT_INDENT = '  '

--- How long the input box must have shown, unbroken, before Claude Code
--- counts as ready: the wait before input that every measured run used, with
--- Claude Code 2.1.281 taking the input sent after it; no shorter wait was
--- tried.
local SETTLE_MS = 1500

--- Whether `line` is one of the input box's rules.
---
---@param line string?
---@return boolean
local function is_rule(line)
  return line ~= nil and vim.startswith(line, RULE)
end

--- Whether `lines`, from the top of a screen down, hold Claude Code's input
--- box: a rule, the prompt's line, the lines a longer draft continues on, and
--- a rule. A dialog drawing its selected choice at the first column between
--- two rules would hold one too; no recorded dialog does.
---
---@param lines string[]
---@return boolean
local function holds_input_box(lines)
  for index = 2, #lines do
    if vim.startswith(lines[index], PROMPT) and is_rule(lines[index - 1]) then
      local below = index + 1
      while lines[below] and vim.startswith(lines[below], DRAFT_INDENT) do
        below = below + 1
      end
      if is_rule(lines[below]) then
        return true
      end
    end
  end
  return false
end

--- How many rows the terminal `buffer` has while windows show it, as Neovim
--- 0.11.6 sizes a terminal: the height of the tallest of them, in any tab
--- page. None while no window shows it, when the terminal keeps its rows.
---
---@param buffer integer a terminal buffer
---@return integer?
local function shown_rows(buffer)
  local rows = 0
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    rows = math.max(rows, vim.fn.getwininfo(window)[1].height)
  end
  return rows > 0 and rows or nil
end

--- The lines of the screen of the terminal `buffer`: its last `rows` lines,
--- which leaves out the scrollback above them.
---
---@param buffer integer a terminal buffer
---@param rows integer
---@return string[]
local function screen_lines(buffer, rows)
  return vim.api.nvim_buf_get_lines(buffer, -rows - 1, -1, false)
end

--- Watches the screen of `buffer` from the moment it is called — so it is
--- called before the terminal starts — and calls `on_change(true)` once
--- Claude Code's input box has shown for `SETTLE_MS` with no change taking it
--- away, and `on_change(false)` when a change takes it away again, as a dialog
--- does. Reads the screen again at every change of the buffer: as many of its
--- last lines as the terminal has rows (`shown_rows()`), the rows it had when
--- last shown while no window shows it, and none before a window first has —
--- so a terminal never shown is never ready.
---
---@param buffer integer the buffer Claude Code's terminal runs in
---@param on_change fun(ready: boolean)
function M.watch(buffer, on_change)
  local ready, settle, rows = false, nil, 0
  vim.api.nvim_buf_attach(buffer, false, {
    on_lines = function()
      rows = shown_rows(buffer) or rows
      if not holds_input_box(screen_lines(buffer, rows)) then
        settle = nil
        if ready then
          ready = false
          on_change(false)
        end
        return
      end
      if ready or settle then
        return
      end
      local this_settle = {}
      settle = this_settle
      vim.defer_fn(function()
        if settle == this_settle then
          settle = nil
          ready = true
          on_change(true)
        end
      end, SETTLE_MS)
    end,
  })
end

return M
