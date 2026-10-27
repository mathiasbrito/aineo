--- Proposing a fix for an issue the explain home shows: a Claude Code of its
--- own is asked for the edits of this file that fix it, and they are shown
--- as a preview (`aineo.explain.preview`) the user accepts or rejects.

local answer = require('aineo.explain.answer')
local kept = require('aineo.explain.kept')
local kinds = require('aineo.explain.kinds')
local marks = require('aineo.explain.marks')
local placement = require('aineo.explain.placement')
local preview = require('aineo.explain.preview')
local request = require('aineo.explain.request')
local runs = require('aineo.explain.runs')
local steer = require('aineo.explain.steer')

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
---@field ask_keys aineo.explain.FixAskKeys what asks a fix, as the user is told it

--- What asks a fix, each a key or a `<Plug>` mapping as the user is told it.
---@class aineo.explain.FixAskKeys
---@field plain string what asks a fix with the default prompt
---@field steered string what asks a fix with a prompt the user edits first

--- What a fix request needs once its Claude Code has ended.
---@class aineo.explain.FixAsked
---@field buffer integer
---@field window integer
---@field tick integer the buffer's `b:changedtick` when it was asked
---@field issue integer the extmark of the issue to fix
---@field issue_text string the text of the issue to fix
---@field keys? aineo.explain.FixKeys
---@field ask_keys aineo.explain.FixAskKeys
---@field lines string[] every line of the buffer, as sent
---@field key string what its answer is kept under (`aineo.explain.kept`'s `fix_key()`)
---@field steered boolean whether it was asked with a prompt the user edited

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

--- Shows `fix` in `asked.buffer` as a preview (`aineo.explain.preview`),
--- the fix of the issue `asked.issue`.
---
---@param asked aineo.explain.FixAsked
---@param fix aineo.explain.KeptFix
local function show(asked, fix)
  fixed_issues[asked.buffer] = asked.issue
  preview.show(asked.buffer, {
    window = asked.window,
    summary = fix.summary,
    edits = fix.edits,
    keys = asked.keys,
    ask_key = asked.ask_keys.plain,
    subject = { text = asked.issue_text, look = kinds.ISSUES },
    kind = kinds.FIX,
  })
end

--- Shows (`show()`) the fix the run `ended` answered for `asked`, placed in
--- the lines sent (`aineo.explain.placement`), and keeps it for those lines
--- (`aineo.explain.kept`), or tells the user, once, why nothing is shown:
--- the buffer changed while the fix was asked, which any move of its
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
  local fix = { summary = answered.summary, edits = edits, steered = asked.steered }
  kept.keep(asked.buffer, asked.key, asked.lines, fix)
  show(asked, fix)
end

--- The code the fix of `issue`, shown above `fixing.line` of
--- `fixing.buffer`, is asked for, as the buffer reads now: its file's path
--- from `folder`, the project's folder, its `'filetype'`, the issue and
--- every line.
---
---@param fixing aineo.explain.FixRequest
---@param issue aineo.explain.ShownIssue
---@param folder string
---@return aineo.explain.FixCode
local function code_of(fixing, issue, folder)
  local path = vim.api.nvim_buf_get_name(fixing.buffer)
  return {
    path = vim.fs.relpath(folder, path) or path,
    language = vim.bo[fixing.buffer].filetype,
    issue_line = fixing.line,
    issue = issue.text,
    lines = vim.api.nvim_buf_get_lines(fixing.buffer, 0, -1, false),
  }
end

--- What a fix of `issue`, shown above `fixing.line`, asked as `fixing`
--- says, is kept under, whatever its prompt (`aineo.explain.kept`'s
--- `fix_key()`).
---
---@param fixing aineo.explain.FixRequest
---@param issue aineo.explain.ShownIssue
---@return string
local function kept_key(fixing, issue)
  return kept.fix_key({
    line = fixing.line,
    issue = issue.text,
    model = fixing.model,
    effort = fixing.effort,
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
---@param steered_text? string the text the prompt starts with, as the user edited it; the default text when absent
local function start(fixing, issue, folder, steered_text)
  local buffer = fixing.buffer
  local asked = {
    buffer = buffer,
    window = fixing.window,
    tick = vim.api.nvim_buf_get_changedtick(buffer),
    issue = issue.id,
    issue_text = issue.text,
    keys = fixing.keys,
    ask_keys = fixing.ask_keys,
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false),
    key = kept_key(fixing, issue),
    steered = steered_text ~= nil,
  }
  local code = code_of(fixing, issue, folder)
  code.steer = steered_text
  local prompt = request.fix_prompt(code)
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

--- Stops the request for a fix or for code (`aineo.explain.kinds`'
--- `PROPOSALS`) that runs for `buffer` and rejects the fix or the code it
--- shows (`reject()`), both without a word: a buffer has one proposal at a
--- time.
---
---@param buffer integer
function M.replace(buffer)
  for _, kind in ipairs(kinds.PROPOSALS) do
    local running = runs.find(buffer, kind)
    if running then
      runs.stop(running)
    end
  end
  M.reject(buffer)
end

--- Asks a fix of `issue` (`start()`), in place of the request and the
--- proposal of `fixing.buffer` (`replace()`).
---
---@param fixing aineo.explain.FixRequest
---@param issue aineo.explain.ShownIssue
---@param folder string
---@param steered_text? string
local function ask(fixing, issue, folder, steered_text)
  M.replace(fixing.buffer)
  start(fixing, issue, folder, steered_text)
end

--- Shows the fix kept for `issue` asked as `fixing` says (`kept_key()`),
--- the one asked last whatever its prompt, when the buffer reads as it did
--- when it was answered, in place of the request and the proposal of
--- `fixing.buffer` (`replace()`), and tells the user, once, that it is
--- the fix kept, which prompt it was asked with, and what asks anew.
--- Returns whether one was kept.
---
---@param fixing aineo.explain.FixRequest
---@param issue aineo.explain.ShownIssue
---@return boolean
local function show_kept(fixing, issue)
  local buffer = fixing.buffer
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local key = kept_key(fixing, issue)
  local fix = kept.recall(buffer, key, lines)
  if not fix then
    return false
  end
  M.replace(buffer)
  show({
    buffer = buffer,
    window = fixing.window,
    tick = vim.api.nvim_buf_get_changedtick(buffer),
    issue = issue.id,
    issue_text = issue.text,
    keys = fixing.keys,
    ask_keys = fixing.ask_keys,
    lines = lines,
    key = key,
    steered = fix.steered,
  }, fix)
  vim.notify(
    ('aineo: the fix kept from before, asked with %s, the code unchanged (%s asks anew)'):format(
      fix.steered and 'your edited prompt' or 'the default prompt',
      fixing.ask_keys.steered
    ),
    vim.log.levels.INFO
  )
  return true
end

--- A text the user sent from the float, and the default text the float
--- was opened with.
---@class aineo.explain.SentSteer
---@field text string
---@field default string

--- `sent.text` with its first line, the head that names the issue's line,
--- replaced by the first line of `default` where it still reads as the
--- head of `sent.default`, the float's default when it opened.
---
---@param sent aineo.explain.SentSteer
---@param default string the default text for the issue's line now
---@return string
local function with_current_head(sent, default)
  local lines = vim.split(sent.text, '\n', { plain = true })
  local opened_head = vim.split(sent.default, '\n', { plain = true })[1]
  if lines[1] == opened_head then
    lines[1] = vim.split(default, '\n', { plain = true })[1]
  end
  return table.concat(lines, '\n')
end

--- Asks a fix of `issue` with the text `sent` from the float, for the line
--- the issue is shown above when it is sent (`aineo.explain.marks`'
--- `issue_line()`), the head aineo wrote brought to that line
--- (`with_current_head()`). Nothing is sent when the buffer is gone by
--- then, nor, with a word, when the issue is shown no more.
---
---@param fixing aineo.explain.FixRequest
---@param issue aineo.explain.ShownIssue
---@param folder string
---@param sent aineo.explain.SentSteer
local function ask_steered(fixing, issue, folder, sent)
  if not vim.api.nvim_buf_is_valid(fixing.buffer) then
    return
  end
  local line = marks.issue_line(fixing.buffer, issue.id)
  if not line then
    vim.notify('aineo: the issue is no longer shown', vim.log.levels.INFO)
    return
  end
  local at_send = vim.tbl_extend('force', fixing, { line = line })
  local default = request.default_fix_steer(code_of(at_send, issue, folder))
  ask(at_send, issue, folder, with_current_head(sent, default))
end

--- Asks a fix for the issue `fixing.buffer` shows above `fixing.line`
--- (`aineo.explain.marks`' `issue_at()`), running Claude Code in `folder`,
--- the project's folder (`ask()`), unless a fix of it is kept for the code
--- as it reads, which is shown at once (`show_kept()`); tells the user,
--- once, when none is shown there. A steered request, always asked anew,
--- first opens the float in which the user edits the prompt
--- (`aineo.explain.steer`), from the fix's default text or the text last
--- sent for a fix, and asks with the text sent (`ask_steered()`); nothing
--- when the user cancels.
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
  if not fixing.steered then
    if not show_kept(fixing, issue) then
      ask(fixing, issue, folder)
    end
    return
  end
  local default = request.default_fix_steer(code_of(fixing, issue, folder))
  steer.open({
    name = kinds.FIX.name,
    title = kinds.FIX.deep.title,
    steered_buffer = fixing.buffer,
    default = default,
    on_send = function(text)
      ask_steered(fixing, issue, folder, { text = text, default = default })
    end,
  })
end

--- Accepts the fix or the code written for a request that `buffer` shows
--- (`aineo.explain.preview`'s `apply()`): its edits are applied as one undo
--- step, the file is not written, and the issue a fix fixes is no longer
--- shown; the user is told, once, that the fix was applied or the code
--- written. Tells the user when `buffer` shows neither.
---
---@param buffer integer
function M.accept(buffer)
  if not preview.is_shown(buffer) then
    vim.notify('aineo: no proposal is shown in this buffer', vim.log.levels.INFO)
    return
  end
  local issue = fixed_issues[buffer]
  if preview.apply(buffer) then
    marks.remove_issue(buffer, issue)
    fixed_issues[buffer] = nil
    vim.notify(
      issue and 'aineo: fix applied (u undoes it)' or 'aineo: code written (u undoes it)',
      vim.log.levels.INFO
    )
  end
end

--- Shows the fix or the code written that `buffer` shows as the diff view,
--- or as the overlay again (`aineo.explain.preview`'s `toggle_diff()`).
---
---@param buffer integer
function M.toggle_diff(buffer)
  preview.toggle_diff(buffer)
end

--- Rejects the fix or the code written that `buffer` shows: its preview
--- goes, and nothing changes.
---
---@param buffer integer
function M.reject(buffer)
  fixed_issues[buffer] = nil
  preview.clear(buffer)
end

return M
