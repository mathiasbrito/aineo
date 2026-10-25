--- aineo's explain home, `require('aineo.explain')`: asks a Claude Code of
--- its own, started for one request and never kept, to explain the code of a
--- buffer, or of some of its lines, or to find its potential issues.

local answer = require('aineo.explain.answer')
local fix = require('aineo.explain.fix')
local kinds = require('aineo.explain.kinds')
local jump = require('aineo.explain.jump')
local kept = require('aineo.explain.kept')
local look = require('aineo.explain.look')
local marks = require('aineo.explain.marks')
local message = require('aineo.explain.message')
local request = require('aineo.explain.request')
local runs = require('aineo.explain.runs')
local steer = require('aineo.explain.steer')

local M = {}

look.keep_defined(kinds.LOOKS)
marks.keep_aligned()
marks.on_change(function(buffer, window)
  jump.sync_keys(buffer)
  if window then
    runs.refresh_badge(window)
  end
  for _, shown_in in ipairs(vim.api.nvim_buf_is_valid(buffer) and vim.fn.win_findbuf(buffer) or {}) do
    runs.refresh_badge(shown_in)
  end
end)

--- What makes a request deep.
---@class aineo.explain.Deep
---@field effort string the effort Claude Code works at, as `--effort` takes it
---@field steer? string the text the prompt starts with, as the user edited it; asked of the user, in a float, when absent

--- One request to explain code.
---@class aineo.explain.Request
---@field buffer integer the buffer whose code is explained, a file's
---@field window integer the window the request was made in
---@field range? integer[] the first and last lines to explain, from 1; every line when absent
---@field tools boolean whether Claude Code may read the project with read-only tools
---@field kind? 'explanations'|'issues' what to ask for; explanations when absent
---@field fresh? boolean whether to ask again whatever answer is kept for the same request
---@field deep? aineo.explain.Deep set for a deep request, which `tools` and `model` describe as any other
---@field command string[] the words that run Claude Code, `claude.cmd`
---@field model string the model that explains
---@field timeout_ms integer how long the request may run
---@field send_key? string what the user presses to send marked issues, said in the badge; `\s` when absent

--- The nearest folder that exists among the folders holding `path`: its
--- own, else the first of its parents, which a file not written yet may lack.
---
---@param path string a file's absolute path
---@return string
local function nearest_existing_folder(path)
  local folder = vim.fs.dirname(path)
  while not vim.uv.fs_stat(folder) do
    local parent = vim.fs.dirname(folder)
    if parent == folder then
      break
    end
    folder = parent
  end
  return folder
end

--- The folder Claude Code runs in for the file at `path`: the top level of
--- the git repository holding it, else the nearest folder of the file that
--- exists (`nearest_existing_folder()`).
---
---@param path string the file's absolute path
---@return string
local function project_folder(path)
  return vim.fs.root(path, '.git') or nearest_existing_folder(path)
end

--- The explanations of the lines from `first` to `last` that the run `ended`
--- of Claude Code answered (`aineo.explain.answer`), or `nil` and what went
--- wrong (`aineo.explain.answer`'s `failure_of()` for a failed run).
---
---@param ended vim.SystemCompleted
---@param first integer
---@param last integer
---@return aineo.explain.Explanation[]|nil explanations
---@return string? problem
local function explanations_of(ended, first, last)
  local failure = answer.failure_of(ended)
  if failure then
    return nil, failure
  end
  return answer.explanations_in(ended.stdout, first, last)
end

--- What a request needs once its Claude Code has ended: the buffer and
--- window it was made in, the file's path from the project, the lines asked
--- for, the buffer's `b:changedtick` when it was asked, and the buffer's
--- text it sent.
---@class aineo.explain.Asked
---@field kind aineo.explain.Kind
---@field buffer integer
---@field window integer
---@field path string
---@field file string the file's absolute path
---@field send_key? string
---@field deep boolean whether it is a deep request
---@field first integer
---@field last integer
---@field key string what the answer is kept under (`aineo.explain.kept`'s `key()`)
---@field tick integer
---@field lines string[] every line of the buffer, as sent

--- Shows what the run `ended` answered for `asked` in place of what its kind
--- showed above its lines, or tells the user, once, why nothing is shown:
--- the buffer's text changed meanwhile — a write moves `b:changedtick` and
--- leaves the text as it was sent, which changes nothing — or the run failed
--- (`explanations_of()`).
---
---@param asked aineo.explain.Asked
---@param ended vim.SystemCompleted
local function show_answer(asked, ended)
  if
    vim.api.nvim_buf_get_changedtick(asked.buffer) ~= asked.tick
    and not vim.deep_equal(vim.api.nvim_buf_get_lines(asked.buffer, 0, -1, false), asked.lines)
  then
    vim.notify(
      ('aineo: %s changed while it was explained: nothing is shown; ask again'):format(asked.path),
      vim.log.levels.WARN
    )
    return
  end
  local explanations, problem = explanations_of(ended, asked.first, asked.last)
  if not explanations then
    vim.notify('aineo: explaining failed: ' .. problem, vim.log.levels.ERROR)
    return
  end
  marks.clear(asked.buffer, asked.kind, asked.first, asked.last)
  marks.place(asked.buffer, asked.kind, explanations, {
    window = asked.window,
    file = asked.file,
    send_key = asked.send_key,
    deep = asked.deep,
  })
  kept.keep(
    asked.buffer,
    asked.key,
    vim.list_slice(asked.lines, asked.first, asked.last),
    explanations
  )
  if #explanations == 0 and asked.kind == kinds.ISSUES then
    vim.notify('aineo: no potential issues found', vim.log.levels.INFO)
  end
end

--- The key the answer to `explaining`, of `kind`, is kept under
--- (`aineo.explain.kept`'s `key()`).
---
---@param explaining aineo.explain.Request
---@param kind aineo.explain.Kind
---@return string
local function kept_key(explaining, kind)
  local deep = explaining.deep
  return kept.key(
    kind,
    explaining.tools,
    explaining.range,
    deep and { model = explaining.model, effort = deep.effort, steer = deep.steer }
  )
end

--- The code `explaining` asks about, as the buffer reads now: its file's
--- path from the project's folder, its `'filetype'`, the lines asked for, a
--- deep request's steer when it has one, and every line.
---
---@param explaining aineo.explain.Request
---@param kind aineo.explain.Kind
---@return aineo.explain.Code
local function code_of(explaining, kind)
  local buffer = explaining.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local range = explaining.range or { 1, #lines }
  return {
    path = vim.fs.relpath(project_folder(path), path),
    language = vim.bo[buffer].filetype,
    first = range[1],
    last = range[2],
    kind = kind.name,
    lines = lines,
    steer = explaining.deep and explaining.deep.steer,
  }
end

--- Starts Claude Code for `explaining`, showing that it is working above the
--- first line asked for until it ends (`show_answer()`, unless the buffer is
--- gone by then), or until its timeout, which stops it and tells the user.
---
--- Raises an error naming `claude.cmd` when its command cannot be run, and
--- leaves no request running then.
---
---@param explaining aineo.explain.Request
local function start(explaining)
  local buffer = explaining.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  local folder = project_folder(path)
  local kind = kinds.named(explaining.kind)
  local code = code_of(explaining, kind)
  local asked = {
    kind = kind,
    buffer = buffer,
    window = explaining.window,
    path = code.path,
    file = path,
    send_key = explaining.send_key,
    deep = explaining.deep ~= nil,
    first = code.first,
    last = code.last,
    key = kept_key(explaining, kind),
    tick = vim.api.nvim_buf_get_changedtick(buffer),
    lines = code.lines,
  }
  local prompt = request.prompt(code)
  local run = runs.begin({
    kind = kind,
    deep = asked.deep,
    buffer = buffer,
    window = asked.window,
    line = asked.first,
    timeout_ms = explaining.timeout_ms,
    on_timeout = function(timed_out)
      runs.stop(timed_out)
      vim.notify(
        ('aineo: explaining failed: Claude Code did not answer within %g s'):format(
          explaining.timeout_ms / 1000
        ),
        vim.log.levels.ERROR
      )
    end,
  })
  local started, process = pcall(
    vim.system,
    request.arguments(explaining.command, {
      model = explaining.model,
      tools = explaining.tools,
      effort = explaining.deep and explaining.deep.effort,
    }),
    { stdin = prompt, cwd = folder, text = true },
    function(ended)
      vim.schedule(function()
        if runs.find(buffer, kind) ~= run then
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

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('aineo_explain', {}),
  desc = 'aineo: stop the Claude Code of every request that runs',
  callback = runs.stop_all,
})

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinNew' }, {
  group = 'aineo_explain',
  desc = 'aineo: say the marked issues of the buffer a window shows in its badge',
  callback = function()
    for _, window in ipairs(vim.fn.win_findbuf(vim.api.nvim_get_current_buf())) do
      runs.refresh_badge(window)
    end
  end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
  group = 'aineo_explain',
  desc = 'aineo: stop the Claude Code of the requests for a buffer wiped out',
  callback = function(event)
    runs.stop_all_of(event.buf)
    kept.forget(event.buf)
    marks.forget(event.buf)
  end,
})

--- The words that ask again for the request `explaining` of `kind`, after
--- `:Aineo explain`, each followed by a space.
---
---@param explaining aineo.explain.Request
---@param kind aineo.explain.Kind
---@return string
local function words_that_ask_again(explaining, kind)
  return ('%s%snew '):format(
    kind == kinds.ISSUES and 'issues ' or '',
    explaining.tools and 'tools ' or ''
  )
end

--- Places the answer kept for `explaining`, of `kind`, in place of what its
--- kind showed above the lines asked about, and tells the user, once, that
--- it is the earlier answer and what asks again. Returns whether an answer
--- was kept for it and the lines asked about read as they did.
---
---@param explaining aineo.explain.Request
---@param kind aineo.explain.Kind
---@return boolean
local function place_kept(explaining, kind)
  local buffer = explaining.buffer
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local range = explaining.range or { 1, #lines }
  local key = kept_key(explaining, kind)
  local explanations = kept.recall(buffer, key, vim.list_slice(lines, range[1], range[2]))
  if not explanations then
    return false
  end
  marks.clear(buffer, kind, range[1], range[2])
  marks.place(buffer, kind, explanations, {
    window = explaining.window,
    file = vim.api.nvim_buf_get_name(buffer),
    send_key = explaining.send_key,
    deep = explaining.deep ~= nil,
  })
  vim.notify(
    explaining.deep
        and 'aineo: the earlier answer, the code and the prompt unchanged (change the prompt to ask again)'
      or ('aineo: the earlier answer, the code unchanged (:Aineo explain %sasks again)'):format(
        words_that_ask_again(explaining, kind)
      ),
    vim.log.levels.INFO
  )
  return true
end

--- Opens the float in which the user edits the prompt of the deep request
--- `explaining`, of `kind` (`aineo.explain.steer`), starting from the default
--- text for the lines asked about (`aineo.explain.request`'s
--- `default_steer()`), and asks again with the text the user sends. Asks
--- nothing when the user cancels, when the buffer is gone by then, or, with
--- a word to the user, when the buffer no longer has the lines asked about.
---
---@param explaining aineo.explain.Request
---@param kind aineo.explain.Kind
local function steer_then_ask(explaining, kind)
  steer.open({
    name = kind.name,
    title = kind.deep.title,
    default = request.default_steer(code_of(explaining, kind)),
    on_send = function(text)
      local buffer = explaining.buffer
      if not vim.api.nvim_buf_is_valid(buffer) then
        return
      end
      local range = explaining.range
      if range and range[2] > vim.api.nvim_buf_line_count(buffer) then
        vim.notify('aineo: the selected lines are no longer in the buffer', vim.log.levels.WARN)
        return
      end
      M.ask(vim.tbl_deep_extend('force', explaining, { deep = { steer = text } }))
    end,
  })
end

--- Explains the code of `explaining.buffer`, its whole text or the lines of
--- `explaining.range`, or looks for its potential issues when
--- `explaining.kind` says so. A buffer has one request of each kind at once:
--- asked while a request of its own kind runs for that buffer, it stops that
--- request alone and says so; asked for the whole buffer while it shows what
--- its kind shows, it clears that alone. The Claude Code of every request
--- that runs is stopped when Neovim quits. An answer that was shown is kept
--- in memory (`aineo.explain.kept`): a request for the same kind, tools and
--- lines while their text reads as it did places that answer again and starts
--- no request. `explaining.fresh` asks again whatever is kept or shown.
---
--- A deep request (`explaining.deep`) with no `steer` first opens the float in
--- which the user edits its prompt (`steer_then_ask()`) and asks again with
--- the text sent; it never clears what its kind shows, and its answer is kept
--- under a key that holds the text, the model and the effort.
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param explaining aineo.explain.Request
function M.ask(explaining)
  local buffer = explaining.buffer
  local kind = kinds.named(explaining.kind)
  local running = runs.find(buffer, kind)
  if running then
    runs.stop(running)
    vim.notify('aineo: explaining stopped', vim.log.levels.INFO)
    return
  end
  if explaining.deep and not explaining.deep.steer then
    steer_then_ask(explaining, kind)
    return
  end
  if explaining.fresh then
    start(explaining)
    return
  end
  if not explaining.deep and not explaining.range and marks.is_showing(buffer, kind) then
    marks.clear(buffer, kind)
    return
  end
  if not place_kept(explaining, kind) then
    start(explaining)
  end
end

--- Removes every explanation and every issue `buffer` shows, and stops the
--- requests that run for it, if any, without a word.
---
---@param buffer integer
function M.clear(buffer)
  runs.stop_all_of(buffer)
  for _, kind in ipairs(kinds.ALL) do
    marks.clear(buffer, kind)
  end
end

--- Marks the issues `buffer` shows above the lines from `first` to `last`,
--- from 1, and unmarks those already marked (`aineo.explain.marks`'s
--- `toggle_issue_marks()`); tells the user, once, when none lies above them.
--- An explanation is never marked.
---
---@param buffer integer
---@param first integer
---@param last integer
function M.toggle_issue_marks(buffer, first, last)
  if marks.toggle_issue_marks(buffer, first, last) == 0 then
    vim.notify(
      first == last and 'aineo: no issue on this line' or 'aineo: no issue on the selected lines',
      vim.log.levels.INFO
    )
  end
end

--- The issues `buffer` shows that are marked, in the order of their lines,
--- each with the path of the file its request was made for — from `folder`
--- when the file lies inside it, else absolute — the line it starts at now
--- and its text.
---
---@param buffer integer
---@param folder string the folder the paths are told from
---@return aineo.explain.MarkedIssue[]
function M.marked_issues(buffer, folder)
  return vim.tbl_map(function(issue)
    return {
      path = vim.fs.relpath(folder, issue.file) or issue.file,
      line = issue.line,
      text = issue.text,
    }
  end, marks.marked_issues(buffer))
end

--- The message that asks Claude Code, after `prompt`, to check `issues`
--- (`aineo.explain.message`'s `of_issues()`).
---
---@param prompt string
---@param issues aineo.explain.MarkedIssue[]
---@return string
function M.issues_message(prompt, issues)
  return message.of_issues(prompt, issues)
end

--- Unmarks every issue `buffer` shows; they stay shown.
---
---@param buffer integer
function M.clear_issue_marks(buffer)
  marks.clear_issue_marks(buffer)
end

--- Asks a Claude Code of its own for a fix of the issue `fixing.buffer`
--- shows above `fixing.line`, and shows the fix as a preview to accept or
--- reject (`aineo.explain.fix`'s `propose()`), running Claude Code in the
--- project's folder of the buffer's file (`project_folder()`).
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param fixing aineo.explain.FixRequest
function M.propose_fix(fixing)
  fix.propose(fixing, project_folder(vim.api.nvim_buf_get_name(fixing.buffer)))
end

--- Accepts the fix `buffer` shows: its edits are applied as one undo step,
--- and the file is not written (`aineo.explain.fix`'s `accept()`).
---
---@param buffer integer
function M.accept_fix(buffer)
  fix.accept(buffer)
end

--- Shows the fix `buffer` shows as the diff view, its old lines struck
--- through above its new lines, or as the overlay again
--- (`aineo.explain.fix`'s `toggle_diff()`).
---
---@param buffer integer
function M.toggle_fix_diff(buffer)
  fix.toggle_diff(buffer)
end

--- Rejects the fix `buffer` shows, if any: its preview goes and the buffer
--- stays as it reads (`aineo.explain.fix`'s `reject()`).
---
---@param buffer integer
function M.reject_fix(buffer)
  fix.reject(buffer)
end

--- Moves the cursor of `window` to the line of the next or the previous
--- explanation or issue of its buffer, `count` of them on, wrapping around
--- (`aineo.explain.jump`'s `go()`), or tells the user there is none.
---
---@param window integer
---@param way 'next'|'previous'
---@param count integer at least 1
function M.jump(window, way, count)
  jump.go(window, way, count)
end

return M
