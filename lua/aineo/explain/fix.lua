--- Proposing a fix for an issue the explain home shows: a Claude Code of its
--- own is asked for the edits of this file that fix it, and they are shown
--- as a preview (`aineo.explain.preview`) the user accepts or rejects.

local answer = require('aineo.explain.answer')
local kinds = require('aineo.explain.kinds')
local marks = require('aineo.explain.marks')
local placement = require('aineo.explain.placement')
local preview = require('aineo.explain.preview')
local request = require('aineo.explain.request')
local runs = require('aineo.explain.runs')

local M = {}

--- The issue each preview shown fixes, by its buffer.
---@type table<integer, integer>
local fixed_issues = {}

--- One request for a fix.
---@class aineo.explain.FixRequest
---@field buffer integer the buffer of a file whose issue is fixed
---@field window integer the window the request was made in
---@field line integer the line the issue to fix is shown above, from 1
---@field steered? boolean whether the user edits the prompt first, in a float
---@field command string[] the words that run Claude Code, `claude.cmd`
---@field model string
---@field effort string the effort Claude Code works at, as `--effort` takes it
---@field timeout_ms integer how long the request may run
---@field keys? aineo.explain.FixKeys the keys the preview maps; none when absent

--- What a fix request needs once its Claude Code has ended.
---@class aineo.explain.FixAsked
---@field buffer integer
---@field window integer
---@field tick integer the buffer's `b:changedtick` when it was asked
---@field issue integer the extmark of the issue to fix
---@field lines string[] every line of the buffer, as sent

--- The fix the run `ended` of Claude Code answered (`aineo.explain.answer`'s
--- `fix_in()`), or `nil` and what went wrong (`failure_of()` for a failed
--- run).
---
---@param ended vim.SystemCompleted
---@return aineo.explain.Fix|nil fix
---@return string? problem
local function fix_of(ended)
  local failure = answer.failure_of(ended)
  if failure then
    return nil, failure
  end
  return answer.fix_in(ended.stdout)
end

--- Shows as a preview (`aineo.explain.preview`) the fix the run `ended`
--- answered for `asked`, placed in the lines sent
--- (`aineo.explain.placement`), or tells the user, once, why nothing is
--- shown: the buffer changed while the fix was asked, which any move of its
--- `b:changedtick` says; the run failed or answered no fix (`fix_of()`);
--- the answer has no edits, when its summary is told; or the fix was
--- refused, with the reason.
---
---@param asked aineo.explain.FixAsked
---@param ended vim.SystemCompleted
local function show_answer(asked, ended)
  if vim.api.nvim_buf_get_changedtick(asked.buffer) ~= asked.tick then
    vim.notify('aineo: the buffer changed while the fix was asked; ask again', vim.log.levels.WARN)
    return
  end
  local answered, problem = fix_of(ended)
  if not answered then
    vim.notify('aineo: proposing a fix failed: ' .. problem, vim.log.levels.ERROR)
    return
  end
  if #answered.edits == 0 then
    vim.notify('aineo: no fix proposed: ' .. answered.summary, vim.log.levels.INFO)
    return
  end
  local edits, refusal = placement.place(asked.lines, answered.edits)
  if not edits then
    vim.notify('aineo: the fix was refused: ' .. refusal, vim.log.levels.WARN)
    return
  end
  fixed_issues[asked.buffer] = asked.issue
  preview.show(asked.buffer, {
    window = asked.window,
    summary = answered.summary,
    edits = edits,
  })
end

--- Starts Claude Code for a fix of `issue`, shown above `fixing.line` of
--- `fixing.buffer`, from `folder`, the project's folder, with the read-only
--- tools, `fixing.model` and `fixing.effort`, showing above that line that
--- it is working until it ends, or until its timeout, which stops it and
--- tells the user.
---
--- Raises an error naming `claude.cmd` when its command cannot be run, and
--- leaves no request running then.
---
---@param fixing aineo.explain.FixRequest
---@param issue aineo.explain.ShownIssue
---@param folder string
local function start(fixing, issue, folder)
  local buffer = fixing.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  local asked = {
    buffer = buffer,
    window = fixing.window,
    tick = vim.api.nvim_buf_get_changedtick(buffer),
    issue = issue.id,
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false),
  }
  local prompt = request.fix_prompt({
    path = vim.fs.relpath(folder, path) or path,
    language = vim.bo[buffer].filetype,
    issue_line = fixing.line,
    issue = issue.text,
    lines = asked.lines,
  })
  local run = runs.begin({
    kind = kinds.FIX,
    deep = false,
    buffer = buffer,
    window = fixing.window,
    line = fixing.line,
    timeout_ms = fixing.timeout_ms,
    on_timeout = function(timed_out)
      runs.stop(timed_out)
      vim.notify(
        ('aineo: proposing a fix failed: Claude Code did not answer within %g s'):format(
          fixing.timeout_ms / 1000
        ),
        vim.log.levels.ERROR
      )
    end,
  })
  local started, process = pcall(
    vim.system,
    request.arguments(fixing.command, {
      model = fixing.model,
      tools = true,
      effort = fixing.effort,
      schema = request.FIX_SCHEMA,
    }),
    { stdin = prompt, cwd = folder, text = true },
    function(ended)
      vim.schedule(function()
        if runs.find(buffer, kinds.FIX) ~= run then
          return
        end
        runs.forget(run)
        if vim.api.nvim_buf_is_valid(buffer) then
          show_answer(asked, ended)
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

--- Asks a fix for the issue `fixing.buffer` shows above `fixing.line`
--- (`aineo.explain.marks`' `issue_at()`), running Claude Code in `folder`,
--- the project's folder; tells the user, once, when none is shown there.
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param fixing aineo.explain.FixRequest
---@param folder string
function M.propose(fixing, folder)
  local issue = marks.issue_at(fixing.buffer, fixing.line)
  if not issue then
    vim.notify('aineo: no issue on this line', vim.log.levels.INFO)
    return
  end
  start(fixing, issue, folder)
end

--- Accepts the fix `buffer` shows (`aineo.explain.preview`'s `apply()`):
--- its edits are applied as one undo step, the file is not written, and the
--- issue it fixes is no longer shown; the user is told so, once. Tells the
--- user when `buffer` shows no fix.
---
---@param buffer integer
function M.accept(buffer)
  if not preview.is_shown(buffer) then
    vim.notify('aineo: no fix is shown in this buffer', vim.log.levels.INFO)
    return
  end
  if preview.apply(buffer) then
    marks.remove_issue(buffer, fixed_issues[buffer])
    fixed_issues[buffer] = nil
    vim.notify('aineo: fix applied (u undoes it)', vim.log.levels.INFO)
  end
end

--- Rejects the fix `buffer` shows: its preview goes, and nothing changes.
---
---@param buffer integer
function M.reject(buffer)
  fixed_issues[buffer] = nil
  preview.clear(buffer)
end

return M
