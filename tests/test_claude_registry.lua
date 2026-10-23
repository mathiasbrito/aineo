local MiniTest = require('mini.test')
local claude = require('aineo.claude')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- Session ids of the form Claude Code gives.
local SESSION = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'

--- This Neovim's pid: a process that runs while the case does.
local PID = vim.fn.getpid()

--- When the process `pid` started, as Claude Code 2.1.310 writes it in
--- `procStart`: what `ps -o lstart=` prints for it in UTC (measured on the
--- host on 2026-10-24: ten running entries of ten matched).
---
---@param pid integer
---@return string
local function process_start(pid)
  local printed = vim
    .system({ 'ps', '-p', tostring(pid), '-o', 'lstart=' }, { env = { TZ = 'UTC' }, text = true })
    :wait().stdout
  return vim.trim(printed)
end

--- Writes `entry`, as JSON, as the registry file `name` of the Claude Code
--- configuration directory `config`.
---
---@param config string
---@param name string
---@param entry table
local function register(config, name, entry)
  local folder = vim.fs.joinpath(config, 'sessions')
  vim.fn.mkdir(folder, 'p')
  vim.fn.writefile({ vim.json.encode(entry) }, vim.fs.joinpath(folder, name))
end

T['a session in Claude Code’s registry'] = MiniTest.new_set()

T['a session in Claude Code’s registry']['is open while a process whose start matches runs it'] = function()
  local config = fixture.directory('claude-registry-open')
  register(config, PID .. '.json', {
    pid = PID,
    sessionId = SESSION,
    procStart = process_start(PID),
    status = 'idle',
    cwd = '/projects/alpha',
  })

  eq(claude.is_session_registered(config, SESSION), true)
end

T['a session in Claude Code’s registry']['is not open once the process that ran it has ended'] = function()
  local config = fixture.directory('claude-registry-ended')
  local ended = vim.system({ 'true' })
  ended:wait()
  register(config, ended.pid .. '.json', {
    pid = ended.pid,
    sessionId = SESSION,
    procStart = 'Fri Oct 23 17:56:31 2026',
    status = 'idle',
  })

  eq(claude.is_session_registered(config, SESSION), false)
end

T['a session in Claude Code’s registry']['is not open when the pid runs another process, which started at another time'] = function()
  local config = fixture.directory('claude-registry-reused')
  register(config, PID .. '.json', {
    pid = PID,
    sessionId = SESSION,
    procStart = 'Thu Jan  1 00:00:00 1970',
    status = 'idle',
  })

  eq(claude.is_session_registered(config, SESSION), false)
end

T['a session in Claude Code’s registry']['is not open when the entry names no start, nor by a file other than a pid’s JSON'] = function()
  local config = fixture.directory('claude-registry-no-start')
  local started = process_start(PID)
  register(config, PID .. '.json', { pid = PID, sessionId = SESSION, status = 'idle' })
  register(config, PID .. '.key', { pid = PID, sessionId = SESSION, procStart = started })
  register(config, 'not-a-pid.json', { pid = PID, sessionId = SESSION, procStart = started })
  register(config, '1.json', { pid = tostring(PID), sessionId = SESSION, procStart = started })

  eq(claude.is_session_registered(config, SESSION), false)
end

T['a session in Claude Code’s registry']['is not open, and raises nothing, where ps cannot be run'] = function()
  local config = fixture.directory('claude-registry-no-ps')
  register(
    config,
    PID .. '.json',
    { pid = PID, sessionId = SESSION, procStart = process_start(PID) }
  )
  local path = vim.env.PATH
  MiniTest.finally(function()
    vim.env.PATH = path
  end)
  vim.env.PATH = fixture.directory('claude-registry-no-ps-path')

  local outcome = { pcall(claude.is_session_registered, config, SESSION) }

  vim.env.PATH = path
  eq(outcome, { true, false })
end

T['a session in Claude Code’s registry']['is read past an entry that is no JSON, and with no registry at all'] = function()
  local config = fixture.directory('claude-registry-misshapen')
  local none = fixture.directory('claude-registry-none')
  vim.fn.mkdir(vim.fs.joinpath(config, 'sessions'), 'p')
  vim.fn.writefile({ '{ not json' }, vim.fs.joinpath(config, 'sessions', '1.json'))
  vim.fn.writefile({ '7' }, vim.fs.joinpath(config, 'sessions', '2.json'))
  register(
    config,
    PID .. '.json',
    { pid = PID, sessionId = SESSION, procStart = process_start(PID) }
  )

  eq({
    misshapen = { pcall(claude.is_session_registered, config, SESSION) },
    none = { pcall(claude.is_session_registered, none, SESSION) },
  }, { misshapen = { true, true }, none = { true, false } })
end

return T
