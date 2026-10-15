--- The trip of a command written into Claude Code: into Terminal mode in
--- Claude's window, and the cursor back where it was.

local M = {}

--- How long a command written into Claude Code waits, after it asks for
--- Terminal mode in Claude's window, for Neovim to enter it.
local TERMINAL_MODE_PATIENCE_MS = 1000

--- Calls `callback` from a scheduled callback once Terminal mode is entered
--- in `terminal`, Claude's terminal: at once, scheduled, when it is
--- entered already; else at the next `TermEnter` in it, which must come
--- within `TERMINAL_MODE_PATIENCE_MS`. Past that time `callback` is never
--- called, `on_timeout` is, and the user is told with a warning that
--- begins `outcome`, the words of what was not done, and ends `Claude’s
--- window did not enter Terminal mode`.
---
---@param terminal integer
---@param outcome string
---@param callback fun()
---@param on_timeout fun()
local function after_entering_terminal_mode(terminal, outcome, callback, on_timeout)
  if vim.api.nvim_get_current_buf() == terminal and vim.api.nvim_get_mode().mode == 't' then
    vim.schedule(callback)
    return
  end
  local entered = false
  local autocommand = vim.api.nvim_create_autocmd('TermEnter', {
    buffer = terminal,
    once = true,
    callback = function()
      entered = true
      vim.schedule(callback)
    end,
  })
  vim.defer_fn(function()
    if not entered then
      vim.api.nvim_del_autocmd(autocommand)
      on_timeout()
      vim.notify(outcome .. 'Claude’s window did not enter Terminal mode', vim.log.levels.WARN)
    end
  end, TERMINAL_MODE_PATIENCE_MS)
end

--- Puts the cursor back where it was before a command written into Claude
--- Code moved it: in the window `origin` names, out of Terminal mode when
--- that window is Claude's and was in Normal mode, and in Insert mode when it
--- was in Insert mode. Moving to another window ends Terminal mode, and
--- Insert mode is asked for once it has ended: asked for sooner, it is lost
--- to it.
---
---@param origin { window: integer, mode: string }
local function return_to(origin)
  if origin.window == vim.api.nvim_get_current_win() and origin.mode ~= 't' then
    vim.cmd.stopinsert()
  end
  if vim.api.nvim_win_is_valid(origin.window) then
    vim.api.nvim_set_current_win(origin.window)
  end
  if vim.startswith(origin.mode, 'i') then
    vim.api.nvim_create_autocmd('ModeChanged', {
      pattern = 't:*',
      once = true,
      callback = function()
        vim.schedule(vim.cmd.startinsert)
      end,
    })
  end
end

M.after_entering_terminal_mode = after_entering_terminal_mode
M.return_to = return_to

return M
