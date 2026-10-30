--- Starting a Claude Code of its own for one request about a buffer, shown
--- as working above a line of it until it ends or outlasts its time.

local runs = require('aineo.explain.runs')

local M = {}

--- One request to start.
---@class aineo.explain.Asking
---@field kind aineo.explain.Kind the kind of request, one of which runs for a buffer at once
---@field deep boolean whether it reads the project, which its working line says
---@field buffer integer the buffer it is about
---@field window integer the window it was made in
---@field line integer the line, from 1, it shows it is working above
---@field timeout_ms integer how long it may run
---@field doing string what it does, as the user is told it failed: `writing code`
---@field arguments string[] the words that start Claude Code
---@field prompt string what Claude Code reads
---@field folder string the folder it runs in
---@field on_end fun(ended: vim.SystemCompleted) called once it ended, when its buffer is still valid and no other request of its kind replaced it

--- Starts Claude Code for `asking`, showing above `asking.line` that it is
--- working until it ends, then calls `asking.on_end`, or until its
--- timeout, which stops it and tells the user what failed.
---
--- Raises an error naming `claude.cmd` when its command cannot be run, and
--- leaves no request running then.
---
---@param asking aineo.explain.Asking
function M.start(asking)
  local buffer = asking.buffer
  local run = runs.begin({
    kind = asking.kind,
    deep = asking.deep,
    buffer = buffer,
    window = asking.window,
    line = asking.line,
    timeout_ms = asking.timeout_ms,
    on_timeout = function(timed_out)
      runs.stop(timed_out)
      vim.notify(
        ('aineo: %s failed: Claude Code did not answer within %g s'):format(
          asking.doing,
          asking.timeout_ms / 1000
        ),
        vim.log.levels.ERROR
      )
    end,
  })
  local started, process = pcall(
    vim.system,
    asking.arguments,
    { stdin = asking.prompt, cwd = asking.folder, text = true },
    function(ended)
      vim.schedule(function()
        if runs.find(buffer, asking.kind) ~= run then
          return
        end
        runs.forget(run)
        if vim.api.nvim_buf_is_valid(buffer) then
          asking.on_end(ended)
        end
      end)
    end
  )
  if not started then
    runs.forget(run)
    error('claude.cmd cannot be run: ' .. tostring(process):gsub('^%S+:%d+: ', ''), 0)
  end
  run.process = process
end

return M
