--- Runs a user's editor with a real UI — Neovim's TUI in a pseudo-terminal,
--- 80×24 — whose report home has a fixed clock, so that a test can put it
--- where a headless child never goes: waiting at a hit-enter prompt. The test
--- types into it and asks it questions over its server socket.

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local MINIMAL_INIT = vim.fs.joinpath(CHECKOUT, 'scripts', 'minimal_init.lua')

--- How long the helper waits for the editor to listen, or to reach a mode.
local WAIT_MS = 5000

--- The Device Status Report query (`CSI 5 n`) Neovim's TUI writes to its
--- terminal as it starts, and the answer of a terminal in good order
--- (`CSI 0 n`).
local STATUS_QUERY, STATUS_ANSWER = '\27[5n', '\27[0n'

---@type integer[]
local running = {}

---@class aineo.test.TuiEditor
---@field job integer the editor's job
---@field address string the editor's server address
---@field channel integer the test's RPC channel to the editor
---@field server_pid integer the process of the editor's server, apart from its TUI
local TuiEditor = {}
TuiEditor.__index = TuiEditor

--- Types `keys` into the editor's terminal, as the user would.
---
---@param keys string
function TuiEditor:type(keys)
  vim.fn.chansend(self.job, keys)
end

--- Whether the editor comes to wait at a hit-enter prompt within the usual
--- wait. Asks with `nvim_get_mode()`, which the editor answers while it waits.
---
---@return boolean
function TuiEditor:waits_at_hit_enter()
  return vim.wait(WAIT_MS, function()
    return vim.rpcrequest(self.channel, 'nvim_get_mode').mode == 'r'
  end, 20)
end

--- The lines of the editor's Report buffer, once they equal `expected` or the
--- usual wait is over: the editor may still be handling a report when asked.
---
---@param expected string[]
---@return string[]
function TuiEditor:report_lines(expected)
  local lines
  vim.wait(WAIT_MS, function()
    lines = vim.rpcrequest(
      self.channel,
      'nvim_exec_lua',
      [[return vim.api.nvim_buf_get_lines(require('aineo.report').report_buffer(), 0, -1, false)]],
      {}
    )
    return vim.deep_equal(lines, expected)
  end, 20)
  return lines
end

--- Kills the editor at once (SIGKILL): it can answer nothing more. The TUI
--- is a client process of its own, whose exit lets the editor finish its
--- work, so the process killed is the editor's server.
function TuiEditor:kill()
  vim.uv.kill(self.server_pid, 'sigkill')
  vim.fn.jobwait({ self.job }, WAIT_MS)
end

--- Stops the editor. Asked to quit, an editor at a hit-enter prompt still
--- runs the requests it holds before it exits.
function TuiEditor:stop()
  vim.fn.jobstop(self.job)
  vim.fn.jobwait({ self.job }, WAIT_MS)
end

--- Waits until the editor on `channel` has finished starting (`VimEnter`),
--- so that its init has put the checkout on `'runtimepath'`: while it
--- starts, the editor may serve requests from inside a wait of its own.
---
---@param channel integer
local function wait_for_startup(channel)
  vim.wait(WAIT_MS, function()
    return vim.rpcrequest(channel, 'nvim_get_vvar', 'vim_did_enter') == 1
  end, 20)
end

--- The editor's `on_stdout` handler: answers each status query in the
--- output `data` of its TUI's `job`, as the user's terminal would, so that
--- the editor does not wait for an answer and then warn that none came.
---
---@param job integer
---@param data string[]
local function answer_status_queries(job, data)
  local _, queries = table.concat(data, '\n'):gsub(vim.pesc(STATUS_QUERY), '')
  for _ = 1, queries do
    vim.fn.chansend(job, STATUS_ANSWER)
  end
end

--- Starts an editor with a UI, the suites' minimal init and a report home
--- whose clock always says `time`, and the state and working directories.
---
---@param environment { time: string, state_directory: string, working_directory: string }
---@return aineo.test.TuiEditor
function M.start(environment)
  local address = vim.fn.tempname() .. '.sock'
  local job = vim.fn.jobstart(
    { vim.v.progpath, '--clean', '-n', '-u', MINIMAL_INIT, '--listen', address },
    { pty = true, width = 80, height = 24, on_stdout = answer_status_queries }
  )
  table.insert(running, job)
  vim.wait(WAIT_MS, function()
    return vim.uv.fs_stat(address) ~= nil
  end, 20)
  local editor = setmetatable({
    job = job,
    address = address,
    channel = vim.fn.sockconnect('pipe', address, { rpc = true }),
  }, TuiEditor)
  wait_for_startup(editor.channel)
  editor.server_pid = vim.rpcrequest(editor.channel, 'nvim_call_function', 'getpid', {})
  vim.rpcrequest(
    editor.channel,
    'nvim_exec_lua',
    [[
      local environment = ...
      require('aineo.report').set_report_environment({
        clock = function()
          return environment.time
        end,
        state_directory = environment.state_directory,
        working_directory = environment.working_directory,
      })
    ]],
    { environment }
  )
  return editor
end

--- Stops every editor `start()` started that is still running.
function M.stop_all()
  for _, job in ipairs(running) do
    vim.fn.jobstop(job)
  end
  running = {}
end

return M
