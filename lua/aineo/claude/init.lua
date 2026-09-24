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
---@field cwd string the directory Claude Code runs in: the editor's working directory
---@field mcp_servers table<string, table> the MCP servers Claude Code starts, by name, each in its `--mcp-config` server format
---@field allowed_tools string[] the tools Claude Code may call without asking the user
---@field instructions string the text appended to Claude Code's system prompt

--- The variables Claude Code's process gets on top of the editor's own, which
--- it inherits unchanged: `AINEO_CHILD` tells aineo, should Claude Code start a
--- Neovim, that it runs inside aineo's own session.
local CHILD_ENVIRONMENT = { AINEO_CHILD = '1' }

--- The one Claude Code session, once one has started: its terminal buffer and
--- job, whether Claude Code has become ready and, once its process has ended,
--- the process's exit code.
---@type { buffer: integer, job: integer, ready: boolean?, exit_code: integer? }?
local session

--- Whether a session's Claude Code is running.
---
---@return boolean
local function is_running()
  return session ~= nil and session.exit_code == nil
end

--- Makes quitting Neovim stop a running Claude Code by its keys first
--- (`stop.stop_by_keys()`), so that none outlives the editor. Registering it
--- again replaces it.
local function stop_on_quit()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('aineo.claude', {}),
    desc = 'Stop Claude Code by its keys before Neovim quits',
    callback = function()
      if is_running() then
        stop.stop_by_keys(session.job, function()
          return not is_running()
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
--- of its kind.
---
---@param settings aineo.claude.Settings
local function validate_settings(settings)
  vim.validate('settings.cmd', settings.cmd, function(value)
    return is_word_list(value, 1)
  end, 'a list of at least one string')
  vim.validate('settings.cwd', settings.cwd, 'string')
  vim.validate('settings.mcp_servers', settings.mcp_servers, 'table')
  vim.validate('settings.allowed_tools', settings.allowed_tools, function(value)
    return is_word_list(value, 0)
  end, 'a list of strings')
  vim.validate('settings.instructions', settings.instructions, 'string')
end

--- Runs `command` as a terminal job in the new, empty `buffer` and returns the
--- job's id. When the command cannot run, wipes `buffer` and raises
--- `jobstart()`'s error, which names the command.
---
---@param buffer integer
---@param command string[]
---@param options table `jobstart()`'s options, `term = true` among them
---@return integer job
local function run_in_terminal(buffer, command, options)
  local started, job = pcall(vim.api.nvim_buf_call, buffer, function()
    return vim.fn.jobstart(command, options)
  end)
  if not started then
    vim.api.nvim_buf_delete(buffer, { force = true })
    error(job, 0)
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
  readiness.when_ready(launched.buffer, function()
    launched.ready = true
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
--- Show a new buffer in a window at once: its terminal takes its size from
--- the first window that shows it, and until then has the few rows of a
--- hidden window, where Claude Code's prompt does not fit.
---
--- Raises an error naming the setting that is malformed, or, when the command
--- cannot run, `jobstart()`'s error naming it; either way it starts nothing
--- and leaves the session as it was.
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

--- Where the session stands: `'starting'` until Claude Code is ready for
--- input, then `'ready'`, and `'exited'` with the exit code once its process
--- has ended; nothing before a session has started.
---
---@return string? state
---@return integer? exit_code
function M.session_status()
  if not session then
    return nil
  end
  if session.exit_code then
    return 'exited', session.exit_code
  end
  if session.ready then
    return 'ready'
  end
  return 'starting'
end

return M
