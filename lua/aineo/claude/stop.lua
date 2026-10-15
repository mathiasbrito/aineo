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
--- hangup; a process that ignores it gets a SIGTERM from Neovim 0.12.5 2 s
--- after it, and one that ignores that too a SIGKILL 4 s after it. Neovim
--- quitting waits for neither, so without this wait a hung process outlives
--- the editor.
local EXIT_AFTER_HANGUP_MS = 5000

--- The byte the Ctrl+Z key sends to a terminal. Written to a Claude Code
--- attached to a background session in a Neovim 0.12.5 terminal, it detached
--- and exited 0, and the session ran on.
local CTRL_Z = '\26'

--- How long a detach waits for the attached Claude Code to exit before it
--- hangs the terminal up: 4 s, as long as the wait after the second press of
--- a double Ctrl-C (`KEY_PRESSES`), which exceeds the longest exit measured
--- after it (2.5 s). The exit after Ctrl+Z was seen, not timed.
local DETACH_WAIT_MS = 4000

--- The keys each way of stopping presses, in order (`KEY_PRESSES`): a Claude
--- Code attached to a background session is detached with Ctrl+Z alone and
--- never given Ctrl-C, which in an attached terminal cancels the session's
--- running turn.
local PRESSES_BY_WAY = {
  keys = KEY_PRESSES,
  detach = { { keys = CTRL_Z, then_wait_ms = DETACH_WAIT_MS } },
}

--- One Claude Code to stop: the terminal job it runs in, whether its process
--- has ended, and the way to stop it (`PRESSES_BY_WAY`).
---@alias aineo.claude.Stop { job: integer, has_exited: fun(): boolean, way: 'keys'|'detach' }

--- Where the stop of one Claude Code stands: the next key it presses
--- (`PRESSES_BY_WAY`), when it next acts, by `now_ms()`, and whether it has
--- hung the terminal up, after which its next act is the end of its wait.
---@alias aineo.claude.StopProgress { stop: aineo.claude.Stop, next_press: integer, act_at: number, hung_up: boolean }

--- The time now in milliseconds, from a clock that only runs forward.
---
---@return number
local function now_ms()
  return vim.uv.hrtime() / 1e6
end

--- Whether the stop `progress` stands for is over: its Claude Code has
--- exited, or its terminal is hung up and the wait after the hangup has run
--- out.
---
---@param progress aineo.claude.StopProgress
---@param now number
---@return boolean
local function is_over(progress, now)
  return progress.stop.has_exited() or (progress.hung_up and now >= progress.act_at)
end

--- Takes the next step of the stop `progress` stands for, at `now`: presses
--- its way's next key and sets how long to wait for the exit, or, when it has
--- pressed them all, or a key cannot be sent because the terminal has closed
--- while its exit is not yet seen, hangs the terminal up (`jobstop()`) and
--- sets how long to wait for the exit then (`EXIT_AFTER_HANGUP_MS`).
---
---@param progress aineo.claude.StopProgress
---@param now number
local function take_next_step(progress, now)
  local press = PRESSES_BY_WAY[progress.stop.way][progress.next_press]
  if press and pcall(vim.api.nvim_chan_send, progress.stop.job, press.keys) then
    progress.next_press = progress.next_press + 1
    progress.act_at = now + press.then_wait_ms
    return
  end
  vim.fn.jobstop(progress.stop.job)
  progress.hung_up = true
  progress.act_at = now + EXIT_AFTER_HANGUP_MS
end

--- Blocks the editor until some Claude Code of `unfinished` has exited or
--- `wait_ms` has passed. A Ctrl-C pressed in the editor meanwhile, which ends
--- a plain `vim.wait()` at once, ends only this call, which the stop then
--- makes again.
---
---@param unfinished aineo.claude.StopProgress[]
---@param wait_ms number
local function wait_for_an_exit(unfinished, wait_ms)
  vim.wait(math.max(wait_ms, 1), function()
    return vim.iter(unfinished):any(function(progress)
      return progress.stop.has_exited()
    end)
  end, 20)
end

--- Stops several Claude Codes together, blocking the editor until each has
--- exited or its stop has run out. Each follows its way's keys with the
--- waits of a stop of its own (`PRESSES_BY_WAY`): every key is pressed to
--- every Claude Code that has not exited when its turn comes, and the waits
--- run side by side, so that the whole takes the time of the longest stop,
--- not the sum — 11.8 s at worst for `keys`, 9 s for `detach`. A Claude Code
--- that has exited is pressed no more keys; one whose terminal has closed
--- while its exit is not yet seen is hung up at once. A Ctrl-C pressed in the
--- editor shortens none of the waits. Never raises. Stops nothing for an
--- empty list.
---
---@param stops aineo.claude.Stop[]
function M.stop_together(stops)
  ---@type aineo.claude.StopProgress[]
  local progresses = vim.tbl_map(function(stop)
    return { stop = stop, next_press = 1, act_at = 0, hung_up = false }
  end, stops)
  while true do
    local now = now_ms()
    local unfinished = vim.tbl_filter(function(progress)
      return not is_over(progress, now)
    end, progresses)
    if #unfinished == 0 then
      return
    end
    for _, progress in ipairs(unfinished) do
      if not progress.hung_up and now >= progress.act_at then
        take_next_step(progress, now)
      end
    end
    local next_act_at = math.huge
    for _, progress in ipairs(unfinished) do
      next_act_at = math.min(next_act_at, progress.act_at)
    end
    wait_for_an_exit(unfinished, next_act_at - now_ms())
  end
end

--- Stops the Claude Code of terminal job `job`, blocking the editor until it
--- has exited or the stop has run out: presses `KEY_PRESSES`, waiting after
--- each, and hangs the terminal up only when the keys have not ended it.
--- Returns as soon as `has_exited()` is true, and in any case within the sum
--- of its waits, 11.8 s; a Ctrl-C pressed in the editor shortens none of
--- them. Never raises: a key that cannot be sent, because the terminal has
--- closed while its exit is not yet seen, ends the pressing, and the stop goes
--- on to the hang-up and its wait — so the editor's later exit handlers still
--- run. Presses no key when `has_exited()` is true already. The one-job case
--- of `M.stop_together()`.
---
---@param job integer the terminal job's id
---@param has_exited fun(): boolean whether Claude Code's process has ended
function M.stop_by_keys(job, has_exited)
  M.stop_together({ { job = job, has_exited = has_exited, way = 'keys' } })
end

--- Detaches the Claude Code of terminal job `job` from the background
--- session it is attached to, blocking the editor until it has exited or the
--- detach has run out: presses Ctrl+Z, which leaves the session running, and
--- never Ctrl-C, which in an attached terminal cancels the session's running
--- turn; waits `DETACH_WAIT_MS` and, when the terminal has not ended, hangs it
--- up as `stop_by_keys()` does. Returns as soon as `has_exited()` is true,
--- and in any case within `DETACH_WAIT_MS` and `EXIT_AFTER_HANGUP_MS`. Never
--- raises: a key that cannot be sent goes straight to the hang-up, and none is
--- sent when `has_exited()` is true already. The one-job case of
--- `M.stop_together()`.
---
---@param job integer the terminal job's id
---@param has_exited fun(): boolean whether Claude Code's process has ended
function M.detach(job, has_exited)
  M.stop_together({ { job = job, has_exited = has_exited, way = 'detach' } })
end

return M
