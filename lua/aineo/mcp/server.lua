--- The report server's stdio transport: one JSON-RPC message per line on
--- stdin, one answer per line on stdout, in the order the lines came.

local editor = require('aineo.mcp.editor')
local lines = require('aineo.mcp.lines')
local protocol = require('aineo.mcp.protocol')

local M = {}

--- The longest line the server reads, in bytes, its newline not counted:
--- 1 MiB, far more than a report needs, and a bound on what one message can
--- make the server hold.
local LINE_LIMIT = 1024 * 1024

--- The standard error stream's file descriptor, where the server writes
--- what it cannot answer: stdout carries MCP messages only.
local STDERR = 2

--- Runs `answer`, one line's answering; when it fails — an answer that cannot
--- be encoded, such as one to an `id` of `1e999` — writes why to stderr, and
--- nothing is answered.
---
---@param answer fun()
local function answer_safely(answer)
  local answered, failure = pcall(answer)
  if not answered then
    vim.uv.fs_write(STDERR, ('aineo relay: %s\n'):format(tostring(failure)))
  end
end

--- Serves MCP on this process's stdin and stdout until stdin closes and every
--- line read is answered, delivering each valid report to the editor at
--- `editor_address`.
---
--- Reading only queues the answers; they are given one at a time, in order,
--- outside the reading, so a delivery waiting on the editor
--- (`editor.deliver_report()`, bounded) holds up the lines after it but
--- never interleaves with them. A line longer than `LINE_LIMIT` is refused,
--- and dropped, as soon as the chunk that takes it past the limit is read
--- (`lines.new_line_reader()`). A line whose answer fails gets none; the next
--- line is answered as usual.
---
---@param editor_address string? the editor's server address
function M.serve_stdio(editor_address)
  local closed = false
  ---@type (fun())[]
  local pending = {}
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
      table.insert(pending, function()
        local answer = line ~= '' and protocol.answer_line(line, deliver_report)
        if answer then
          send(answer)
        end
      end)
    end,
    on_too_long = function()
      table.insert(pending, function()
        send(protocol.answer_line_too_long(LINE_LIMIT))
      end)
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
  while not closed or #pending > 0 do
    vim.wait(60000, function()
      return closed or #pending > 0
    end, 10)
    while #pending > 0 do
      answer_safely(table.remove(pending, 1))
    end
  end
end

return M
