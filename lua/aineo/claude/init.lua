--- aineo's Claude session home, `require('aineo.claude')`: Claude Code's
--- interactive CLI running in a terminal buffer.

local arguments = require('aineo.claude.arguments')
local readiness = require('aineo.claude.readiness')
local stop = require('aineo.claude.stop')

local M = {}

--- What the session runs Claude Code with. The composition root assembles it
--- from the configuration and from the homes that own each value.
---@class aineo.claude.Settings
---@field cmd string[] the command that runs Claude Code, as `claude.cmd`
---@field cwd string the directory Claude Code runs in, which must exist and be enterable: the editor's working directory
---@field mcp_servers table<string, table> the MCP servers Claude Code starts, by name, each in its `--mcp-config` server format
---@field allowed_tools string[] the tools Claude Code may call without asking the user
---@field instructions string the text appended to Claude Code's system prompt

--- The variables Claude Code's process gets on top of the editor's own, which
--- it inherits unchanged: `AINEO_CHILD` tells aineo, should Claude Code start a
--- Neovim, that it runs inside aineo's own session.
local CHILD_ENVIRONMENT = { AINEO_CHILD = '1' }

--- The one Claude Code session, once one has started: its terminal buffer and
--- job, whether Claude Code is ready for input now and, once its process has
--- ended, the process's exit code.
---@type { buffer: integer, job: integer, ready: boolean?, exit_code: integer? }?
local session

--- Whether a session's Claude Code process has not ended yet — whatever
--- became of its terminal.
---
---@return boolean
local function is_process_alive()
  return session ~= nil and session.exit_code == nil
end

--- Whether a session's Claude Code is running: its process has not ended and
--- its terminal has not been wiped, which hangs the process up.
---
---@return boolean
local function is_running()
  return is_process_alive() and vim.api.nvim_buf_is_valid(session.buffer)
end

--- Makes quitting Neovim stop Claude Code by its keys first
--- (`stop.stop_by_keys()`) while its process has not ended, so that none
--- outlives the editor — also when its terminal was wiped just before, and
--- the stop can only wait for the hangup to end it. Registering it again
--- replaces it.
local function stop_on_quit()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('aineo.claude', {}),
    desc = 'Stop Claude Code by its keys before Neovim quits',
    callback = function()
      if is_process_alive() then
        stop.stop_by_keys(session.job, function()
          return not is_process_alive()
        end)
      end
    end,
  })
end

--- Puts `replacement` in every window that shows `buffer`, then wipes
--- `buffer` — in that order, since wiping a buffer closes the windows that
--- still show it. Does nothing to a `buffer` already wiped.
---
---@param buffer integer the terminal of a Claude Code that has exited
---@param replacement integer
local function replace_terminal(buffer, replacement)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    vim.api.nvim_win_set_buf(window, replacement)
  end
  vim.api.nvim_buf_delete(buffer, { force = true })
end

--- Whether `value` is a list of strings — of at least `least` of them.
---
---@param value any
---@param least integer
---@return boolean
local function is_word_list(value, least)
  return vim.islist(value)
    and #value >= least
    and vim.iter(value):all(function(word)
      return type(word) == 'string'
    end)
end

--- Raises an error naming the first setting of `settings` whose value is not
--- of its kind, or, for `cwd`, not a directory that exists and can be
--- entered. One that cannot be entered is refused here because Neovim 0.11.6
--- does not refuse it: its terminal job then runs a copy of the editor in
--- place of the command.
---
---@param settings aineo.claude.Settings
local function validate_settings(settings)
  vim.validate('settings.cmd', settings.cmd, function(value)
    return is_word_list(value, 1)
  end, 'a list of at least one string')
  vim.validate('settings.cwd', settings.cwd, function(value)
    return type(value) == 'string'
      and vim.fn.isdirectory(value) == 1
      and vim.uv.fs_access(value, 'X') == true
  end, 'a directory that exists and can be entered')
  vim.validate('settings.mcp_servers', settings.mcp_servers, 'table')
  vim.validate('settings.allowed_tools', settings.allowed_tools, function(value)
    return is_word_list(value, 0)
  end, 'a list of strings')
  vim.validate('settings.instructions', settings.instructions, 'string')
end

--- Runs `command` as a terminal job in the new, empty `buffer` and returns the
--- job's id. When `jobstart()` cannot run it, wipes `buffer` and raises an error
--- naming the command: `jobstart()`'s own, or, when `:silent!` has silenced
--- that and `jobstart()` has returned 0 or -1 instead, one of its own.
---
---@param buffer integer
---@param command string[]
---@param options table `jobstart()`'s options, `term = true` among them
---@return integer job
local function run_in_terminal(buffer, command, options)
  local started, job = pcall(vim.api.nvim_buf_call, buffer, function()
    return vim.fn.jobstart(command, options)
  end)
  if not started or job <= 0 then
    vim.api.nvim_buf_delete(buffer, { force = true })
    error(started and ('jobstart() cannot run ' .. command[1]) or job, 0)
  end
  return job
end

--- Runs Claude Code with `settings` in a new terminal buffer, and returns the
--- session that tracks it: its buffer and job, whether it is ready, and its
--- exit code once it has exited.
---
---@param settings aineo.claude.Settings
---@return { buffer: integer, job: integer, ready: boolean?, exit_code: integer? }
local function launch(settings)
  local command =
    vim.list_extend(vim.list_slice(settings.cmd), arguments.claude_arguments(settings))
  local launched = { buffer = vim.api.nvim_create_buf(false, true) }
  readiness.watch(launched.buffer, function(ready)
    launched.ready = ready
  end)
  launched.job = run_in_terminal(launched.buffer, command, {
    term = true,
    cwd = settings.cwd,
    env = CHILD_ENVIRONMENT,
    on_exit = function(_, exit_code)
      launched.exit_code = exit_code
    end,
  })
  return launched
end

--- Starts Claude Code in a new terminal buffer and returns that buffer. While
--- a session runs it starts nothing and returns that session's buffer: one
--- Claude Code at a time. Once it has exited, it starts a new one, whose
--- terminal takes the old one's place in every window that showed it.
--- Quitting Neovim stops a running Claude Code by its keys first.
---
--- Show a new buffer in a window before Claude Code draws its first screen:
--- its terminal takes its size from the first window that shows it, and until
--- then has the rows of a hidden window — 5, at 80 columns, in Neovim 0.11.6 —
--- where Claude Code's prompt does not fit. Shown in the same tick, or from a
--- `vim.schedule()` callback, the process saw the window's size.
---
--- A session whose terminal has been wiped counts as ended, since the wipe
--- hangs its Claude Code up: a start then launches a new one.
---
--- Raises an error naming the setting that is malformed — for `cwd`, a
--- directory that does not exist or cannot be entered — or, when `jobstart()`
--- cannot run the command, an error naming the command; either way it starts
--- nothing and leaves the session as it was. A command that `jobstart()`
--- starts but the system then cannot execute — a script whose interpreter is
--- missing — raises nothing: its session reports `'exited'` with 122, the
--- code Neovim 0.11.6's terminal job exits with then.
---
---@param settings aineo.claude.Settings
---@return integer buffer the terminal buffer Claude Code runs in
function M.start_session(settings)
  validate_settings(settings)
  if is_running() then
    return session.buffer
  end
  local previous = session
  session = launch(settings)
  stop_on_quit()
  if previous then
    replace_terminal(previous.buffer, session.buffer)
  end
  return session.buffer
end

--- Where the session stands: `'ready'` while Claude Code's input box is on
--- its screen, once it has shown for a moment (`readiness.watch()`);
--- `'starting'` while it is not — as Claude Code starts, and again while a
--- dialog takes its place; and `'exited'` once the session has ended, as
--- `start_session()` counts it: from the moment its terminal is wiped, which
--- hangs Claude Code up, and once its process has ended, with the exit code
--- from then on. Nothing before a session has started.
---
---@return string? state
---@return integer? exit_code
function M.session_status()
  if not session then
    return nil
  end
  if not is_running() then
    return 'exited', session.exit_code
  end
  if session.ready then
    return 'ready'
  end
  return 'starting'
end

return M
