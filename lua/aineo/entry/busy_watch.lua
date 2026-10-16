--- The watch on whether the Claude Code on a terminal is busy: a tab's way of
--- hearing that it starts or stops being, which `aineo.claude` keeps in
--- `b:aineo_session_busy`, and that its terminal is unloaded or wiped, which
--- changes no variable.

local errors = require('aineo.entry.errors')

local M = {}

--- Calls `tell(busy)` whenever the Claude Code on `terminal` starts or stops
--- being busy, and with `false` when `terminal` is unloaded or wiped: wiping
--- a buffer changes none of its variables, so a watcher on the variable alone
--- would leave a wiped busy terminal busy. The wipe is heard as the buffer's
--- detach (`nvim_buf_attach()`'s `on_detach`), not as `BufWipeout`, which
--- Neovim 0.12.5 does not run for a wipe inside another autocommand that is
--- not nested, such as a `TermClose` handler of the user's, nor under
--- `:noautocmd`. The same call, `tell(false)`, comes from an exit
--- (`aineo.claude` marks the terminal not busy). Once for each terminal:
--- called again for one it watches, it adds nothing. An error that `tell`
--- raises is told to the user once (`aineo.entry.errors`).
---
--- The variable's watcher is a dictionary watcher added from Vimscript, which
--- alone can name a buffer's own `b:` dictionary, as `aineo.claude` watches
--- the terminal's title.
---
---@param terminal integer
---@param tell fun(busy: boolean)
function M.tell_when_busy_changes(terminal, tell)
  if vim.b[terminal].aineo_busy_watched then
    return
  end
  vim.b[terminal].aineo_busy_watched = true
  local function tell_once_raised(busy)
    errors.run(function()
      tell(busy)
    end)
  end
  vim.api.nvim_buf_call(terminal, function()
    vim.b.aineo_busy_watcher = function(_, _, change)
      tell_once_raised(change.new == true)
    end
    vim.cmd([[call dictwatcheradd(b:, 'aineo_session_busy', b:aineo_busy_watcher)]])
    vim.cmd.unlet('b:aineo_busy_watcher')
  end)
  vim.api.nvim_buf_attach(terminal, false, {
    on_detach = function()
      tell_once_raised(false)
    end,
  })
end

return M
