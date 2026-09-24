--- Lines out of the chunks a channel reads: what arrives after the last
--- newline waits for the rest of its line, up to a limit.

local M = {}

---@class aineo.mcp.LineReaderOptions
---@field limit integer the longest line kept, in bytes, its newline not counted
---@field on_line fun(line: string) takes each line once its newline has arrived
---@field on_too_long fun() told as soon as a line grows past `limit`

--- A reader that takes what a channel callback receives — a list of strings
--- whose first item continues the last line of the call before, and whose
--- last item is the start of a line still to be completed (`:h
--- channel-lines`) — and hands `on_line` each line once its newline has
--- arrived, without the newline. A line that grows past `limit` is dropped
--- and `on_too_long` told at once, before its newline arrives; the rest of
--- that line, up to its newline, is dropped as it arrives.
---
---@param options aineo.mcp.LineReaderOptions
---@return fun(data: string[])
function M.new_line_reader(options)
  local partial = ''
  local dropping = false
  return function(data)
    for index, piece in ipairs(data) do
      if index > 1 then
        if not dropping then
          options.on_line(partial)
        end
        partial, dropping = '', false
      end
      if not dropping then
        partial = partial .. piece
      end
      if #partial > options.limit then
        options.on_too_long()
        partial, dropping = '', true
      end
    end
  end
end

return M
