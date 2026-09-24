--- Stopping Claude Code the way a user would: by its keys, before any signal.

local M = {}

--- The byte the Ctrl-C key sends to a terminal. Claude Code reads its terminal
--- in raw mode, so it receives the byte, not a SIGINT.
local CTRL_C = '\3'

--- The keys the stop presses, in order, each with how long it then waits for
--- Claude Code to exit before the next:
---
--- 1. one Ctrl-C, which ends a turn in progress and leaves Claude Code idle —
---    or, at an idle prompt, asks for a second press; then long enough for a
---    turn to end, which it had after 2.5 s, and for that request to lapse;
--- 2. and 3. a double Ctrl-C, which exits an idle Claude Code: two presses
---    0.3 s apart, well inside the gap Claude Code accepts (1.2 s was too
---    long), then long enough for it to exit, which took 1.6 to 2.5 s after the
---    second press.
local KEY_PRESSES = {
  { keys = CTRL_C, then_wait_ms = 2500 },
  { keys = CTRL_C, then_wait_ms = 300 },
  { keys = CTRL_C, then_wait_ms = 4000 },
}

--- How long the stop waits for Claude Code to exit once `jobstop()` has hung
--- up its terminal. Claude Code took 1.6 to 1.9 s to exit; a process that
--- ignores the hangup gets a SIGTERM from Neovim 2 s after it, and one that
--- ignores that too a SIGKILL 4 s after it. Neovim quitting waits for neither,
--- so without this wait a hung process outlives the editor.
local EXIT_AFTER_HANGUP_MS = 5000

--- Stops the Claude Code of terminal job `job`, blocking the editor until it
--- has exited or the stop has run out: presses `KEY_PRESSES`, waiting after
--- each, and hangs the terminal up only when the keys have not ended it.
--- Returns as soon as `has_exited()` is true, and in any case within the sum
--- of its waits, 11.8 s.
---
---@param job integer the terminal job's id
---@param has_exited fun(): boolean whether Claude Code's process has ended
function M.stop_by_keys(job, has_exited)
  for _, press in ipairs(KEY_PRESSES) do
    vim.api.nvim_chan_send(job, press.keys)
    if vim.wait(press.then_wait_ms, has_exited, 20) then
      return
    end
  end
  vim.fn.jobstop(job)
  vim.wait(EXIT_AFTER_HANGUP_MS, has_exited, 20)
end

return M
