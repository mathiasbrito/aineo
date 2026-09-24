--- Delivery of a report to the editor, over the editor's RPC server socket.

local M = {}

--- The Lua the editor runs for each report. The report travels as its
--- argument, as data: nothing of it becomes code.
local RECEIVE_REPORT = "require('aineo.report').receive_report(...)"

--- The first line of `text`: an editor's error without its stack traceback.
---
---@param text string
---@return string
local function first_line(text)
  return (text:match('^[^\n]*'))
end

--- Hands `report` to the report home of the editor listening at `address`,
--- which shows it in its Report (`require('aineo.report').receive_report()`),
--- and says whether it arrived: not when there is no address, when the
--- editor cannot be reached, or when it does not take the report — then with
--- the first line of the reason the editor gave.
---
---@param address string? the editor's server address
---@param report table a valid report
---@return boolean delivered
---@return string? failure why it was not delivered
function M.deliver_report(address, report)
  if address == nil then
    return false, 'aineo has no editor address to deliver the report to'
  end
  local connected, channel = pcall(vim.fn.sockconnect, 'pipe', address, { rpc = true })
  if not connected then
    return false, ('aineo could not reach the editor at %s: %s'):format(address, channel)
  end
  local delivered, failure =
    pcall(vim.rpcrequest, channel, 'nvim_exec_lua', RECEIVE_REPORT, { report })
  vim.fn.chanclose(channel)
  if not delivered then
    return false, 'the editor did not take the report: ' .. first_line(tostring(failure))
  end
  return true
end

return M
