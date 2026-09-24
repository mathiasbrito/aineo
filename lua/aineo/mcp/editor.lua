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

--- How `sockconnect()` dials `address`: over TCP when it is `host:port`, as
--- `--listen 127.0.0.1:6666` gives, else as a local pipe (a socket path).
---
---@param address string
---@return 'tcp'|'pipe'
local function connection_mode(address)
  return address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'
end

--- The first line of `text`: an editor's error without its stack traceback.
---
---@param text string
---@return string
local function first_line(text)
  return (text:match('^[^\n]*'))
end

---@class aineo.mcp.Call
---@field response table? the editor's answer, `{ 1, id, error, result }`, once it came
---@field closed boolean whether the editor closed the connection

--- A reader of what the editor writes back on `call`'s connection: it keeps
--- the answer to the request and closes the connection then, and notes when
--- the editor closes it first. The connection carries one request, so the
--- one response on it is that answer; anything else the editor sends, such
--- as a notification a plugin broadcasts to every channel, is ignored.
---
---@param call aineo.mcp.Call
---@return fun(channel: integer, data: string[])
local function answer_reader(call)
  local unpack = vim.mpack.Unpacker()
  return function(channel, data)
    if #data == 1 and data[1] == '' then
      call.closed = true
      return
    end
    local chunk, position = table.concat(data, '\n'), 1
    while position <= #chunk do
      local message, next_position = unpack(chunk, position)
      if message == nil then
        return
      end
      if message[1] == RESPONSE then
        call.response = message
        vim.fn.chanclose(channel)
      end
      position = next_position
    end
  end
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
  local connected, channel =
    pcall(vim.fn.sockconnect, connection_mode(address), address, { on_data = answer_reader(call) })
  if not connected then
    return 'failed', ('aineo could not reach the editor at %s: %s'):format(address, channel)
  end
  vim.fn.chansend(
    channel,
    vim.mpack.encode({ REQUEST, REQUEST_ID, 'nvim_exec_lua', { RECEIVE_REPORT, { report } } })
  )
  vim.wait(CONFIRMATION_TIMEOUT_MS, function()
    return call.response ~= nil or call.closed
  end, 10)
  if call.response == nil and not call.closed then
    return 'unconfirmed',
      ('aineo sent the report, but the editor did not confirm it within %d s:'):format(
        CONFIRMATION_TIMEOUT_MS / 1000
      ) .. ' it may be waiting for the user, at a hit-enter prompt for one.' .. ' The report will show when the editor is free; do not send it again.'
  end
  if call.response == nil then
    return 'failed', ('the editor at %s closed the connection before it answered'):format(address)
  end
  local failure = call.response[3]
  if failure ~= vim.NIL then
    return 'failed', 'the editor did not take the report: ' .. first_line(tostring(failure[2]))
  end
  return 'delivered'
end

return M
