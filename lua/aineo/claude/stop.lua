--- Stopping Claude Code the way a user would: by its keys, before any signal.

local M = {}

--- The byte the Ctrl-C key sends to a terminal. Written to the terminal of
--- Claude Code 2.1.281 it ended a turn, and twice in a row it exited an idle
--- prompt; whether the CLI reads its terminal raw, or the terminal turns the
--- byte into a SIGINT, was not measured.
local CTRL_C = '\3'

--- The keys the stop presses, in order, each with how long it then waits for
--- Claude Code to exit before the next, as Claude Code 2.1.281 answered them
--- in a Neovim 0.11.6 terminal:
---
--- 1. one Ctrl-C, which ends a turn in progress and leaves Claude Code idle —
---    or, at an idle prompt holding a draft, clears it and shows "Press
---    Ctrl-C again to exit"; then long enough for a turn to end: the one stop
---    measured in a turn pressed the double Ctrl-C 2.5 s later and exited, and
---    how soon a turn ends was not measured;
--- 2. and 3. a double Ctrl-C, which exits an idle Claude Code: two presses
---    0.3 s apart, well inside the gap it accepted (1.2 s was too long), then
---    long enough for it to exit, which took 1.6 and 2.5 s after the second
---    press in the two runs measured.
local KEY_PRESSES = {
  { keys = CTRL_C, then_wait_ms = 2500 },
  { keys = CTRL_C, then_wait_ms = 300 },
  { keys = CTRL_C, then_wait_ms = 4000 },
}

--- How long the stop waits for Claude Code to exit once `jobstop()` has hung
--- up its terminal. Claude Code 2.1.281 took 1.6 and 1.9 s to exit on the
--- hangup; a process that ignores it gets a SIGTERM from Neovim 0.11.6 2 s
--- after it, and one that ignores that too a SIGKILL 4 s after it. Neovim
--- quitting waits for neither, so without this wait a hung process outlives
--- the editor.
local EXIT_AFTER_HANGUP_MS = 5000

--- Blocks the editor until `has_exited()` is true or `wait_ms` has passed, and
--- returns whether it is true. A Ctrl-C pressed in the editor meanwhile, which
--- ends a plain `vim.wait()` at once, does not end this wait.
---
---@param wait_ms integer
---@param has_exited fun(): boolean
---@return boolean
local function wait_for_exit(wait_ms, has_exited)
  local deadline = assert(vim.uv.new_timer())
  local passed = false
  deadline:start(wait_ms, 0, function()
    passed = true
  end)
  repeat
    vim.wait(wait_ms, function()
      return passed or has_exited()
    end, 20)
  until passed or has_exited()
  deadline:close()
  return has_exited()
end

--- Stops the Claude Code of terminal job `job`, blocking the editor until it
--- has exited or the stop has run out: presses `KEY_PRESSES`, waiting after
--- each, and hangs the terminal up only when the keys have not ended it.
--- Returns as soon as `has_exited()` is true, and in any case within the sum
--- of its waits, 11.8 s; a Ctrl-C pressed in the editor shortens none of them.
--- Never raises: a key that cannot be sent, because the terminal has closed
--- while its exit is not yet seen, ends the pressing, and the stop goes on to
--- the hang-up and its wait — so the editor's later exit handlers still run.
---
---@param job integer the terminal job's id
---@param has_exited fun(): boolean whether Claude Code's process has ended
function M.stop_by_keys(job, has_exited)
  for _, press in ipairs(KEY_PRESSES) do
    if not pcall(vim.api.nvim_chan_send, job, press.keys) then
      break
    end
    if wait_for_exit(press.then_wait_ms, has_exited) then
      return
    end
  end
  vim.fn.jobstop(job)
  wait_for_exit(EXIT_AFTER_HANGUP_MS, has_exited)
end

return M
