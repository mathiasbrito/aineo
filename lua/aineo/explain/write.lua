--- Writing code for a request the user makes in a file: a Claude Code of
--- its own is asked for the code, which is shown as a preview
--- (`aineo.explain.preview`) the user accepts or rejects, as a fix is.

local answer = require('aineo.explain.answer')
local fix = require('aineo.explain.fix')
local kept = require('aineo.explain.kept')
local kinds = require('aineo.explain.kinds')
local placement = require('aineo.explain.placement')
local preview = require('aineo.explain.preview')
local request = require('aineo.explain.request')
local runs = require('aineo.explain.runs')
local steer = require('aineo.explain.steer')

local M = {}

--- One request for code.
---@class aineo.explain.WriteRequest
---@field buffer integer the buffer of the file the code is written in
---@field window integer the window the request was made in
---@field line integer the cursor's line, from 1
---@field range? integer[] the first and last lines that hold the request, from 1
---@field tools boolean whether Claude Code may read the project with read-only tools
---@field command string[] the words that run Claude Code, `claude.cmd`
---@field model string
---@field effort? string the effort Claude Code works at, as `--effort` takes it; its own default when absent
---@field timeout_ms integer how long the request may run
---@field keys? aineo.explain.FixKeys the keys the preview maps; none when absent
---@field ask_key string what asks for code again, as the user is told it

--- What the code is asked for: the request, and the lines that hold it,
--- which the code replaces, or the line the code goes below.
---@class aineo.explain.WriteAsk
---@field first integer the first line of the request, from 1, or the line the code goes below
---@field last integer the last line of the request, or the line the code goes below
---@field request string the request: the text the user typed, or the text of the lines that hold it
---@field below boolean whether the code goes below the line `first`, for a request the user typed; else it replaces the lines that hold the request

--- What a request for code needs once its Claude Code has ended.
---@class aineo.explain.WriteAsked
---@field writing aineo.explain.WriteRequest
---@field ask aineo.explain.WriteAsk
---@field lines string[] every line of the buffer, as sent
---@field tick integer the buffer's `b:changedtick` when it was asked

--- The code the run `ended` of Claude Code answered, in the shape of a fix
--- (`aineo.explain.answer`'s `fix_in()`), or `nil` and what went wrong
--- (`failure_of()` for a failed run).
---
---@param ended vim.SystemCompleted
---@return aineo.explain.Fix|nil code
---@return string? problem
local function code_of(ended)
  local failure = answer.failure_of(ended)
  if failure then
    return nil, failure
  end
  return answer.fix_in(ended.stdout)
end

--- The most characters the request takes in the row that names it.
local MOST_REQUEST_CHARACTERS = 60

--- `text`, a request, on one line: each run of white space one space, none
--- at its ends, and, past `MOST_REQUEST_CHARACTERS`, cut to one fewer and
--- followed by an ellipsis.
---
---@param text string
---@return string
local function shortened(text)
  local one_line = vim.trim((text:gsub('%s+', ' ')))
  if vim.fn.strchars(one_line) <= MOST_REQUEST_CHARACTERS then
    return one_line
  end
  return vim.fn.strcharpart(one_line, 0, MOST_REQUEST_CHARACTERS - 1) .. '…'
end

--- Why the code of `edits`, placed in the text sent, cannot be shown for
--- `ask`, or `nil`: it must be one edit of exactly the lines `ask.first` to
--- `ask.last`, and, for code that goes below a line, its new lines must
--- start with that line, as it reads.
---
---@param edits aineo.explain.PlacedEdit[]
---@param ask aineo.explain.WriteAsk
---@return string|nil
local function fault_of(edits, ask)
  local edit = edits[1]
  if #edits ~= 1 or edit.first ~= ask.first or edit.last ~= ask.last then
    return ask.below and 'it must insert after the cursor’s line alone'
      or 'it must replace the lines of the request alone'
  end
  if ask.below and edit.new[1] ~= edit.old[1] then
    return 'it must keep the cursor’s line as it is'
  end
end

--- What the code written for `ask`, as `writing` asks it, is kept under
--- (`aineo.explain.kept`'s `write_key()`).
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@return string
local function kept_key(writing, ask)
  return kept.write_key({
    first = ask.first,
    last = ask.last,
    request = ask.request,
    model = writing.model,
    effort = writing.effort,
  })
end

--- Shows `code`, written for `ask`, in `writing.buffer` as a preview
--- (`aineo.explain.preview`), the request named at its top (`shortened()`).
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@param code aineo.explain.KeptCode
local function show(writing, ask, code)
  preview.show(writing.buffer, {
    window = writing.window,
    summary = code.summary,
    edits = code.edits,
    keys = writing.keys,
    ask_key = writing.ask_key,
    subject = { text = shortened(ask.request), look = kinds.WRITE },
  })
end

--- Shows (`show()`) the code the run `ended` answered for `asked`, placed in
--- the lines sent (`aineo.explain.placement`), and keeps it for those lines
--- (`aineo.explain.kept`), or tells the user, once, why nothing is shown:
--- the buffer changed while the code was asked, which any move of its
--- `b:changedtick` says; the run failed or answered no code (`code_of()`);
--- the answer has no edits, when its summary is told; or the code was
--- refused, by the placement or for its lines (`fault_of()`), with the
--- reason.
---
---@param asked aineo.explain.WriteAsked
---@param ended vim.SystemCompleted
local function show_answer(asked, ended)
  local writing = asked.writing
  if vim.api.nvim_buf_get_changedtick(writing.buffer) ~= asked.tick then
    vim.notify(
      'aineo: the buffer changed while the code was written; ask again',
      vim.log.levels.WARN
    )
    return
  end
  local answered, problem = code_of(ended)
  if not answered then
    vim.notify('aineo: writing code failed: ' .. problem, vim.log.levels.ERROR)
    return
  end
  if #answered.edits == 0 then
    vim.notify('aineo: no code written: ' .. answered.summary, vim.log.levels.INFO)
    return
  end
  local edits, refusal = placement.place(asked.lines, answered.edits)
  local fault = refusal or fault_of(edits, asked.ask)
  if fault then
    vim.notify('aineo: the written code was refused: ' .. fault, vim.log.levels.WARN)
    return
  end
  local code = { summary = answered.summary, edits = edits }
  kept.keep(writing.buffer, kept_key(writing, asked.ask), asked.lines, code)
  show(writing, asked.ask, code)
end

--- Starts Claude Code for the code `ask` asks for in `writing.buffer`,
--- from `folder`, the project's folder, showing above the line `ask.first`
--- that it is working until it ends, then the code it answered
--- (`show_answer()`, unless the buffer is gone by then), or until its
--- timeout, which stops it and tells the user.
---
--- Raises an error naming `claude.cmd` when its command cannot be run, and
--- leaves no request running then.
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@param folder string
local function start(writing, ask, folder)
  local buffer = writing.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  local asked = {
    writing = writing,
    ask = ask,
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false),
    tick = vim.api.nvim_buf_get_changedtick(buffer),
  }
  local prompt = request.write_prompt({
    path = vim.fs.relpath(folder, path) or path,
    language = vim.bo[buffer].filetype,
    first = ask.first,
    last = ask.last,
    request = ask.below and ask.request or nil,
    lines = asked.lines,
  })
  local run = runs.begin({
    kind = kinds.WRITE,
    deep = writing.tools,
    buffer = buffer,
    window = writing.window,
    line = ask.first,
    timeout_ms = writing.timeout_ms,
    on_timeout = function(timed_out)
      runs.stop(timed_out)
      vim.notify(
        ('aineo: writing code failed: Claude Code did not answer within %g s'):format(
          writing.timeout_ms / 1000
        ),
        vim.log.levels.ERROR
      )
    end,
  })
  local started, process = pcall(
    vim.system,
    request.arguments(writing.command, {
      model = writing.model,
      tools = writing.tools,
      effort = writing.effort,
      schema = request.FIX_SCHEMA,
    }),
    { stdin = prompt, cwd = folder, text = true },
    function(ended)
      vim.schedule(function()
        if runs.find(buffer, kinds.WRITE) ~= run then
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

--- What the user is told when the code kept for a request is shown again.
local KEPT_MESSAGE = 'aineo: the code written before for this request, the file unchanged'
  .. ' (change the request to ask anew)'

--- Shows the code kept for `ask`, as `writing` asks it (`kept_key()`), when
--- the buffer reads as it did when it was answered, and tells the user,
--- once, that it is the code kept and what asks anew. Returns whether one
--- was kept.
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@return boolean
local function show_kept(writing, ask)
  local lines = vim.api.nvim_buf_get_lines(writing.buffer, 0, -1, false)
  local code = kept.recall(writing.buffer, kept_key(writing, ask), lines)
  if not code then
    return false
  end
  show(writing, ask, code)
  vim.notify(KEPT_MESSAGE, vim.log.levels.INFO)
  return true
end

--- Shows the code kept for `ask` (`show_kept()`), else asks for it
--- (`start()`), in place of the request for a fix or for code that runs
--- for `writing.buffer` and of the fix or the code it shows
--- (`aineo.explain.fix`'s `replace()`).
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@param folder string
local function ask_for(writing, ask, folder)
  fix.replace(writing.buffer)
  if not show_kept(writing, ask) then
    start(writing, ask, folder)
  end
end

--- Asks for code for `text`, the request the user sent from the float,
--- below the line `writing.line` (`ask_for()`). Nothing is asked when the
--- buffer is gone by then, nor, with a word, when it no longer has that
--- line.
---
---@param writing aineo.explain.WriteRequest
---@param folder string
---@param text string
local function ask_typed(writing, folder, text)
  if not vim.api.nvim_buf_is_valid(writing.buffer) then
    return
  end
  if writing.line > vim.api.nvim_buf_line_count(writing.buffer) then
    vim.notify('aineo: the cursor’s line is no longer in the buffer', vim.log.levels.WARN)
    return
  end
  ask_for(
    writing,
    { first = writing.line, last = writing.line, request = text, below = true },
    folder
  )
end

--- What the float in which the user types a request says it does, when
--- Claude Code works from the file alone.
local PLAIN_TITLE = 'Write code'

--- Asks a Claude Code of its own, run in `folder`, the project's folder, to
--- write code for the request that the lines of `writing.range` hold, or
--- shows the code kept for it (`ask_for()`); tells the user, once, and asks
--- nothing when they hold white space alone. With no `writing.range`,
--- first opens an empty float in which the user types the request
--- (`aineo.explain.steer`), remembering nothing of it, and asks for the
--- request sent (`ask_typed()`); nothing when the user cancels.
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param writing aineo.explain.WriteRequest
---@param folder string
function M.propose(writing, folder)
  if not writing.range then
    steer.open({
      title = writing.tools and kinds.WRITE.deep.title or PLAIN_TITLE,
      steered_buffer = writing.buffer,
      on_send = function(text)
        ask_typed(writing, folder, text)
      end,
    })
    return
  end
  local first, last = writing.range[1], writing.range[2]
  local text =
    table.concat(vim.api.nvim_buf_get_lines(writing.buffer, first - 1, last, false), '\n')
  if vim.trim(text) == '' then
    vim.notify(
      'aineo: the selected lines are blank: there is no request to write code for',
      vim.log.levels.WARN
    )
    return
  end
  ask_for(writing, { first = first, last = last, request = text, below = false }, folder)
end

return M
