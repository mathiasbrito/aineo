--- Delivery of a report to the editor, over the editor's RPC server socket,
--- with a bounded wait for the editor to confirm it.

local M = {}

--- The Lua the editor runs for each report. The report travels as its
--- argument, as data: nothing of it becomes code.
local RECEIVE_REPORT = "require('aineo.report').receive_report(...)"

--- How long the relay waits for the editor to confirm a report: 5 s, far
--- above the time a report takes to show (tens of milliseconds, even for a
--- report at the line limit), and well below the two minutes after which
--- Claude Code moves a tool call to the background. An editor waiting for
--- the user (at a hit-enter prompt, say) runs no request until the user is
--- done.
local CONFIRMATION_TIMEOUT_MS = 5000

--- The message types of msgpack-RPC (`:h rpc`), and the id of the one
--- request each connection to the editor carries.
local REQUEST, RESPONSE = 0, 1
local REQUEST_ID = 1

--- What an editor puts before an error raised in Lua when it answers a
--- request with it: the words it wraps the error in (`Lua: ` from Neovim 0.12
--- on, `Error executing lua: ` before), and the position of the Lua code that
--- raised it — `<file>.lua:<line>: `, the file's path holding no white
--- space, or for Neovim's own modules from 0.12 on `vim/<module>:<line>: ` or
--- `[string "vim/<module>"]:<line>: `. A file's position is never looked for
--- past a space, so the words of a reason before a position they name are
--- kept.
local ERROR_FRAMING = {
  '^Lua: ',
  '^Error executing lua: ',
  '^%S-%.lua:%d+: ',
  '^vim/[%w_/]+:%d+: ',
  '^%[string "vim/[^"]*"%]:%d+: ',
}

--- The reason an editor's error `text` gives: its first line, without the
--- stack traceback that may follow it and without what the editor put before
--- it (`ERROR_FRAMING`), stripped until none is left at its start — an editor
--- frames an error again after the position of the Lua that called the API
--- function which raised it. A reason that itself begins with such words
--- loses them too.
---
---@param text string
---@return string
local function editor_reason(text)
  local line = text:match('^[^\n]*')
  repeat
    local before = line
    for _, framing in ipairs(ERROR_FRAMING) do
      line = line:gsub(framing, '')
    end
  until line == before
  return line
end

--- Closes `connection` unless it is already closing.
---
---@param connection uv.uv_stream_t
local function close(connection)
  if not connection:is_closing() then
    connection:close()
  end
end

---@class aineo.mcp.Call
---@field unreachable string? why the editor could not be reached, once it is known
---@field response table? the editor's answer, `{ 1, id, error, result }`, once it came
---@field closed boolean whether the editor closed the connection

--- A reader of what the editor writes back on `connection`, taking the bytes
--- as they came (`read_start()`), a zero byte included: it keeps the answer
--- to the request in `call` and closes the connection then, and notes when
--- the editor closes it first. The connection carries one request, so the
--- one response on it is that answer; anything else the editor sends, such
--- as a notification a plugin broadcasts to every channel, is ignored.
---
---@param call aineo.mcp.Call
---@param connection uv.uv_stream_t
---@return fun(failure: string?, chunk: string?)
local function answer_reader(call, connection)
  local unpack = vim.mpack.Unpacker()
  return function(failure, chunk)
    if failure or chunk == nil then
      call.closed = true
      close(connection)
      return
    end
    local position = 1
    while position <= #chunk do
      local message, next_position = unpack(chunk, position)
      if message == nil then
        return
      end
      if message[1] == RESPONSE then
        call.response = message
        close(connection)
        return
      end
      position = next_position
    end
  end
end

--- `connection` once it has started connecting, as `started` and `failure`
--- say (what libuv's `connect()` returned); else nil and why not, and
--- `connection` is closed.
---
---@param connection uv.uv_stream_t
---@param started any
---@param failure string?
---@return uv.uv_stream_t? connection
---@return string? failure
local function connecting(connection, started, failure)
  if not started then
    close(connection)
    return nil, failure
  end
  return connection
end

--- Starts connecting to the editor at `address`, and calls `on_connect`
--- once connected, or with why not. The connection is over TCP when
--- `address` is `host:port`, as `--listen 127.0.0.1:6666` gives, to the
--- first address `host` resolves to (the one an editor listening on a host
--- name listens on), and else over a local pipe (a socket path).
---
---@param address string
---@param on_connect fun(failure: string?)
---@return uv.uv_stream_t? connection
---@return string? failure why connecting could not start
local function connect(address, on_connect)
  local host, port = address:match('^([^/]+):(%d+)$')
  if not host then
    local pipe = assert(vim.uv.new_pipe(false))
    return connecting(pipe, pipe:connect(address, on_connect))
  end
  local resolved, resolve_failure = vim.uv.getaddrinfo(host, port, { socktype = 'stream' })
  if not resolved then
    return nil, resolve_failure
  end
  local tcp = assert(vim.uv.new_tcp())
  return connecting(tcp, tcp:connect(resolved[1].addr, tonumber(port), on_connect))
end

--- Asks the editor on `connection` to receive `report`, and reads its answer
--- into `call` (`answer_reader()`).
---
---@param connection uv.uv_stream_t
---@param report table
---@param call aineo.mcp.Call
local function request_report(connection, report, call)
  connection:read_start(answer_reader(call, connection))
  connection:write(
    vim.mpack.encode({ REQUEST, REQUEST_ID, 'nvim_exec_lua', { RECEIVE_REPORT, { report } } })
  )
end

--- How the delivery `call` to the editor at `address` went, in the terms of
--- `deliver_report()`.
---
---@param call aineo.mcp.Call
---@param address string
---@return 'delivered'|'unconfirmed'|'failed' outcome
---@return string? explanation
local function outcome(call, address)
  if call.unreachable then
    return 'failed',
      ('aineo could not reach the editor at %s: %s'):format(address, call.unreachable)
  end
  if call.response then
    local failure = call.response[3]
    if failure ~= vim.NIL then
      return 'failed', 'the editor did not take the report: ' .. editor_reason(tostring(failure[2]))
    end
    return 'delivered'
  end
  if call.closed then
    return 'failed', ('the editor at %s closed the connection before it answered'):format(address)
  end
  return 'unconfirmed',
    ('aineo sent the report, but the editor did not confirm it within %d s:'):format(
      CONFIRMATION_TIMEOUT_MS / 1000
    ) .. ' it may be waiting for the user, at a hit-enter prompt for one.' .. ' The report is sent, not confirmed; do not send it again.'
end

--- Hands `report` to the report home of the editor listening at `address`,
--- which shows it in its Report (`require('aineo.report').receive_report()`),
--- and says how it went:
---
--- - `'delivered'` when the editor confirmed it;
--- - `'unconfirmed'` when the editor did not answer within
---   `CONFIRMATION_TIMEOUT_MS`: the request stays with the editor, which runs
---   it when it is free, and the connection stays open until it answers;
--- - `'failed'` when there is no address, the editor cannot be reached,
---   closes the connection before answering, or does not take the report —
---   then with the first line of the reason it gave.
---
--- The second result says it in words, for Claude.
---
---@param address string? the editor's server address
---@param report table a valid report
---@return 'delivered'|'unconfirmed'|'failed' outcome
---@return string? explanation
function M.deliver_report(address, report)
  if address == nil then
    return 'failed', 'aineo has no editor address to deliver the report to'
  end
  local call = { closed = false }
  local connection, failure
  connection, failure = connect(address, function(connect_failure)
    if connect_failure then
      call.unreachable = connect_failure
      close(connection)
    else
      request_report(connection, report, call)
    end
  end)
  if not connection then
    call.unreachable = failure
    return outcome(call, address)
  end
  vim.wait(CONFIRMATION_TIMEOUT_MS, function()
    return call.unreachable ~= nil or call.response ~= nil or call.closed
  end, 10)
  return outcome(call, address)
end

return M
