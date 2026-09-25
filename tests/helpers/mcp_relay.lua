--- Runs a stdio MCP server the way Claude Code does — a process with piped
--- standard streams — and talks to it line by line. `start_relay()` runs the
--- report relay with the command `require('aineo.mcp').mcp_servers()`
--- describes; `start()` runs any command.

local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')

local M = {}

--- How long a test waits for a line, or for the process to exit, before it
--- fails.
local WAIT_MS = 10000

---@type vim.SystemObj[]
local running = {}

---@class aineo.test.Relay
---@field process vim.SystemObj
---@field lines string[] the complete lines the process wrote to stdout
---@field read integer how many of `lines` the test has read
---@field partial string what the process wrote after its last newline
---@field errors string[] what the process wrote to stderr
local Relay = {}
Relay.__index = Relay

--- Writes `text` to the process's stdin as it is: no newline is added.
---
---@param text string
function Relay:write(text)
  self.process:write(text)
end

--- Writes `line` and a newline to the process's stdin.
---
---@param line string
function Relay:send(line)
  self.process:write(line .. '\n')
end

--- The next `count` lines the process writes to stdout, waiting for them up
--- to `milliseconds` (the usual wait when not given); fewer when they do not
--- come in time, and then what the process wrote to stderr is added to the
--- test's notes.
---
---@param count integer
---@param milliseconds? integer
---@return string[]
function Relay:next_lines(count, milliseconds)
  local arrived = vim.wait(milliseconds or WAIT_MS, function()
    return #self.lines >= self.read + count
  end, 10)
  if not arrived then
    MiniTest.add_note(
      ('%d of %d line(s) came; stderr: %s'):format(
        #self.lines - self.read,
        count,
        table.concat(self.errors)
      )
    )
  end
  local next_lines = vim.list_slice(self.lines, self.read + 1, self.read + count)
  self.read = self.read + #next_lines
  return next_lines
end

--- The next line the process writes to stdout, or nil when none comes within
--- `milliseconds` (the usual wait when not given).
---
---@param milliseconds? integer
---@return string?
function Relay:next_line(milliseconds)
  return self:next_lines(1, milliseconds)[1]
end

--- Whether the raw `line` holds `text` as it is; false when there is no line.
---
---@param line string?
---@param text string
---@return boolean
function M.holds(line, text)
  return line ~= nil and line:find(text, 1, true) ~= nil
end

--- `line` decoded from JSON: an empty table when there is no line, and
--- `{ unreadable = line }` when it is not JSON, so that a test reading a
--- field of a missing or broken answer fails on its assertion.
---
---@param line string?
---@return table
function M.decoded(line)
  local read, value = pcall(vim.json.decode, line or '{}')
  return read and value or { unreadable = line }
end

--- Whether the process writes `text` to stderr within the usual wait.
---
---@param text string
---@return boolean
function Relay:writes_to_stderr(text)
  return vim.wait(WAIT_MS, function()
    return table.concat(self.errors):find(text, 1, true) ~= nil
  end, 10)
end

--- Whether the process writes nothing to stdout within `milliseconds`.
---
---@param milliseconds integer
---@return boolean
function Relay:is_silent_for(milliseconds)
  return not vim.wait(milliseconds, function()
    return #self.lines > self.read or self.partial ~= ''
  end, 10)
end

--- Closes the process's stdin and waits for it to exit.
---
---@return vim.SystemCompleted
function Relay:close()
  self.process:write(nil)
  return self.process:wait(WAIT_MS)
end

--- Starts `command` with `env` added to this process's environment.
---
---@param command string[]
---@param env? table<string, string>
---@return aineo.test.Relay
function M.start(command, env)
  local relay = setmetatable({ lines = {}, read = 0, partial = '', errors = {} }, Relay)
  relay.process = vim.system(command, {
    stdin = true,
    env = env,
    stdout = function(_, data)
      if not data then
        return
      end
      local pieces = vim.split(relay.partial .. data, '\n', { plain = true })
      relay.partial = table.remove(pieces)
      vim.list_extend(relay.lines, pieces)
    end,
    stderr = function(_, data)
      table.insert(relay.errors, data or '')
    end,
  })
  table.insert(running, relay.process)
  return relay
end

--- Starts the report relay as Claude Code would: with the command and
--- arguments `require('aineo.mcp').mcp_servers()` gives, run by this Neovim's
--- own program, and `env` added to this process's environment (the entry's
--- own `env` is not used: each test names the editor address it wants).
---
---@param env? table<string, string>
---@return aineo.test.Relay
function M.start_relay(env)
  local entry = mcp.mcp_servers('', vim.v.progpath).aineo
  return M.start(vim.list_extend({ entry.command }, entry.args), env)
end

--- Stops every process `start()` started that is still running.
function M.stop_all()
  for _, process in ipairs(running) do
    if not process:is_closing() then
      process:kill('sigkill')
    end
  end
  running = {}
end

return M
