--- The report server's stdio transport: one JSON-RPC message per line on
--- stdin, one answer per line on stdout.

local editor = require('aineo.mcp.editor')
local lines = require('aineo.mcp.lines')
local protocol = require('aineo.mcp.protocol')

local M = {}

--- The longest line the server reads, in bytes, its newline not counted:
--- 1 MiB, far more than a report needs, and a bound on what one message can
--- make the server hold.
local LINE_LIMIT = 1024 * 1024

--- Serves MCP on this process's stdin and stdout until stdin closes,
--- delivering each valid report to the editor at `editor_address`. A line
--- longer than `LINE_LIMIT` is answered, and dropped, as soon as the chunk
--- that takes it past the limit is read (`lines.new_line_reader()`).
---
---@param editor_address string? the editor's server address
function M.serve_stdio(editor_address)
  local closed = false
  local stdio
  local function send(answer)
    vim.fn.chansend(stdio, vim.json.encode(answer) .. '\n')
  end
  local function deliver_report(report)
    return editor.deliver_report(editor_address, report)
  end
  local read_lines = lines.new_line_reader({
    limit = LINE_LIMIT,
    on_line = function(line)
      local answer = line ~= '' and protocol.answer_line(line, deliver_report)
      if answer then
        send(answer)
      end
    end,
    on_too_long = function()
      send(protocol.answer_line_too_long(LINE_LIMIT))
    end,
  })
  stdio = vim.fn.stdioopen({
    on_stdin = function(_, data)
      if #data == 1 and data[1] == '' then
        closed = true
        return
      end
      read_lines(data)
    end,
  })
  while not closed do
    vim.wait(60000, function()
      return closed
    end, 50)
  end
end

return M
