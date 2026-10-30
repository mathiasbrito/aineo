--- Writing code for a request the user makes in a file: a Claude Code of
--- its own is asked for the code, which is shown as a preview
--- (`aineo.explain.preview`) the user accepts or rejects, as a fix is.

local answer = require('aineo.explain.answer')
local asking = require('aineo.explain.asking')
local fix = require('aineo.explain.fix')
local kept = require('aineo.explain.kept')
local kinds = require('aineo.explain.kinds')
local placement = require('aineo.explain.placement')
local preview = require('aineo.explain.preview')
local request = require('aineo.explain.request')
local steer = require('aineo.explain.steer')

local M = {}

--- One request for code.
---@class aineo.explain.WriteRequest
---@field buffer integer the buffer of the file the code is written in
---@field window integer the window the request was made in
---@field line integer the cursor's line, from 1, which the code goes below, or in place of when it is blank, followed while the request is typed
---@field range? integer[] the first and last lines that hold the request, from 1
---@field tools boolean whether Claude Code may read the project with read-only tools
---@field whole_file? boolean whether the code may also edit other places of the file, each shown as a proposal of its own
---@field command string[] the words that run Claude Code, `claude.cmd`
---@field model string
---@field effort? string the effort Claude Code works at, as `--effort` takes it; its own default when absent
---@field timeout_ms integer how long the request may run
---@field keys? aineo.explain.FixKeys the keys the preview maps; none when absent
---@field ask_key string what asks for code again, as the user is told it
---@field brief? string[] what else Claude Code is shown, each a part of the prompt of its own
---@field title? string what the float that asks for the request says it does; as for `\w`, `\W` or `\WW` when absent

--- Where code written for a request goes: below the line asked about
--- (`below_line`) or in its place when it is blank (`in_blank_line`), for a
--- request the user typed, in place of the lines that hold the request
--- (`in_request_lines`), or wherever it belongs in the file, as the request
--- says (`anywhere`).
---@alias aineo.explain.WritePlace 'below_line'|'in_blank_line'|'in_request_lines'|'anywhere'

--- What the code is asked for: the request, and the lines that hold it,
--- which the code replaces, or the line the code goes below or in place of.
---@class aineo.explain.WriteAsk
---@field first integer the first line of the request, from 1, or the line asked about
---@field last integer the last line of the request, or the line asked about
---@field request string the request: the text the user typed, or the text of the lines that hold it
---@field place aineo.explain.WritePlace where the code goes
---@field title? string what the code is written for, in a few words, named above it in place of the request

--- What a request for code needs once its Claude Code has ended.
---@class aineo.explain.WriteAsked
---@field writing aineo.explain.WriteRequest
---@field ask aineo.explain.WriteAsk
---@field lines string[] every line of the buffer, as sent
---@field tick integer the buffer's `b:changedtick` when it was asked
---@field folder string the project's folder, Claude Code ran in

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

--- What the user is told code written for each place
--- (`aineo.explain.WritePlace`) must be when its edits are not one edit of
--- the lines asked about.
local OUT_OF_PLACE = {
  below_line = 'it must insert after the cursor’s line alone',
  in_blank_line = 'it must replace the cursor’s blank line alone',
  in_request_lines = 'it must replace the lines of the request alone',
}

--- What the user is told code that may edit the whole file, written for
--- each place (`aineo.explain.WritePlace`), lacks when none of its edits is
--- an edit of the lines asked about alone.
local ANCHOR_MISSING = {
  below_line = 'it has no edit that inserts after the cursor’s line',
  in_blank_line = 'it has no edit that replaces the cursor’s blank line',
  in_request_lines = 'it has no edit that replaces the lines of the request',
}

--- Why the code of `edits`, placed in the text sent, cannot be shown for
--- `ask`, or `nil`: it must be one edit of exactly the lines `ask.first` to
--- `ask.last` (`OUT_OF_PLACE`), and, for code that goes below a line, its
--- new lines must start with that line, as it reads.
---
---@param edits aineo.explain.PlacedEdit[]
---@param ask aineo.explain.WriteAsk
---@return string|nil
local function fault_of(edits, ask)
  local edit = edits[1]
  if #edits ~= 1 or edit.first ~= ask.first or edit.last ~= ask.last then
    return OUT_OF_PLACE[ask.place]
  end
  if ask.place == 'below_line' and edit.new[1] ~= edit.old[1] then
    return 'it must keep the cursor’s line as it is'
  end
end

--- Why `edits`, the edits answered for `asked`, cannot be placed in place
--- of the blank line asked about, or `nil`: an edit names that line, but its
--- old lines are not that line, byte for byte, as it was sent. Edits
--- answered for any other place are not looked at.
---
---@param edits aineo.explain.Edit[]
---@param asked aineo.explain.WriteAsked
---@return string|nil
local function blank_line_mismatch(edits, asked)
  local ask = asked.ask
  if ask.place ~= 'in_blank_line' then
    return nil
  end
  for _, edit in ipairs(edits) do
    if
      type(edit) == 'table'
      and edit.line == ask.first
      and not vim.deep_equal(edit.old, { asked.lines[ask.first] })
    then
      return 'the edit’s old line does not match the cursor’s line exactly'
    end
  end
end

--- `edit`, the edit of the lines asked about of the code written for `ask`
--- (`fault_of()`), with the copy of the blank line it replaces that its new
--- lines start with, if any, dropped, for code that goes in place of a
--- blank line, so that the code replaces it and leaves no blank line; as it
--- is otherwise.
---
---@param edit aineo.explain.PlacedEdit
---@param ask aineo.explain.WriteAsk
---@return aineo.explain.PlacedEdit
local function in_its_place(edit, ask)
  if ask.place ~= 'in_blank_line' or edit.new[1] ~= edit.old[1] then
    return edit
  end
  return vim.tbl_extend('force', edit, { new = vim.list_slice(edit.new, 2) })
end

--- Why `answered`, the code answered for `asked`, cannot be shown, or
--- `nil`, with its edits placed in the lines sent (`aineo.explain.placement`)
--- and the edit of the lines asked about in its place (`in_its_place()`):
--- it must be one edit of those lines alone (`fault_of()`), refused too for
--- an old line that is not the blank line asked about
--- (`blank_line_mismatch()`) or by the placement, with the reason.
---
---@param asked aineo.explain.WriteAsked
---@param answered aineo.explain.Fix
---@return string|nil fault
---@return aineo.explain.KeptCode? code
local function placed_at_the_line_asked(asked, answered)
  local edits, refusal = placement.place(asked.lines, answered.edits)
  local fault = blank_line_mismatch(answered.edits, asked) or refusal or fault_of(edits, asked.ask)
  if fault then
    return fault
  end
  return nil, { summary = answered.summary, edits = { in_its_place(edits[1], asked.ask) } }
end

--- The most edits code that may edit the whole file is shown with.
local MOST_EDITS = 20

--- The index, in `edits`, placed in the order of their lines, of the edit
--- of exactly the lines `ask.first` to `ask.last`, the lines asked about;
--- `nil` when none is.
---
---@param edits aineo.explain.PlacedEdit[]
---@param ask aineo.explain.WriteAsk
---@return integer|nil
local function index_of_the_anchor(edits, ask)
  for index, edit in ipairs(edits) do
    if edit.first == ask.first and edit.last == ask.last then
      return index
    end
  end
end

--- Why `answered`, code that may edit the whole file answered for `asked`,
--- cannot be shown, or `nil`, with its edits placed in the lines sent
--- (`aineo.explain.placement`), in the order of their lines, the edit of
--- the lines asked about in its place (`in_its_place()`) and its index
--- (`subject`): it may hold at most `MOST_EDITS` edits, the placement must
--- take them all, which refuses edits that share a line, and one of them,
--- wherever it stands in the answer, must be the edit of the lines asked
--- about alone (`index_of_the_anchor()`, `ANCHOR_MISSING`), checked as
--- code at the line asked alone is (`fault_of()`,
--- `blank_line_mismatch()`); with the reason.
---
---@param asked aineo.explain.WriteAsked
---@param answered aineo.explain.Fix
---@return string|nil fault
---@return aineo.explain.KeptCode? code
local function placed_in_the_whole_file(asked, answered)
  if #answered.edits > MOST_EDITS then
    return ('it holds more than %d edits'):format(MOST_EDITS)
  end
  local edits, refusal = placement.place(asked.lines, answered.edits)
  local fault = blank_line_mismatch(answered.edits, asked) or refusal
  if fault then
    return fault
  end
  local subject = index_of_the_anchor(edits, asked.ask)
  if not subject then
    return ANCHOR_MISSING[asked.ask.place]
  end
  fault = fault_of({ edits[subject] }, asked.ask)
  if fault then
    return fault
  end
  edits[subject] = in_its_place(edits[subject], asked.ask)
  return nil, { summary = answered.summary, edits = edits, subject = subject }
end

--- Why `answered`, code written wherever it belongs in the file for
--- `asked`, cannot be shown, or `nil`, with its edits placed in the lines
--- sent (`aineo.explain.placement`), in the order of their lines, the
--- first its subject: it may hold at most `MOST_EDITS` edits, and the
--- placement must take them all, which refuses edits that share a line;
--- with the reason.
---
---@param asked aineo.explain.WriteAsked
---@param answered aineo.explain.Fix
---@return string|nil fault
---@return aineo.explain.KeptCode? code
local function placed_anywhere(asked, answered)
  if #answered.edits > MOST_EDITS then
    return ('it holds more than %d edits'):format(MOST_EDITS)
  end
  local edits, refusal = placement.place(asked.lines, answered.edits)
  if refusal then
    return refusal
  end
  return nil, { summary = answered.summary, edits = edits, subject = 1 }
end

--- How the code answered for `ask`, as `writing` asks it, is placed in
--- the lines sent, or refused: wherever it belongs (`placed_anywhere()`),
--- in the whole file (`placed_in_the_whole_file()`), or at the lines asked
--- about alone (`placed_at_the_line_asked()`).
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@return fun(asked: aineo.explain.WriteAsked, answered: aineo.explain.Fix): string|nil, aineo.explain.KeptCode?
local function placement_of(writing, ask)
  if ask.place == 'anywhere' then
    return placed_anywhere
  end
  return writing.whole_file and placed_in_the_whole_file or placed_at_the_line_asked
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
    place = ask.place,
    whole_file = writing.whole_file == true,
    model = writing.model,
    effort = writing.effort,
  })
end

--- Moves to `writing.window`, when it still shows `writing.buffer`, its
--- cursor on the first line of the first of `edits`, so that code written
--- wherever it belongs is seen where it starts.
---
---@param writing aineo.explain.WriteRequest
---@param edits aineo.explain.PlacedEdit[]
local function go_to_the_first(writing, edits)
  local window = writing.window
  if
    not vim.api.nvim_win_is_valid(window) or vim.api.nvim_win_get_buf(window) ~= writing.buffer
  then
    return
  end
  vim.api.nvim_set_current_win(window)
  vim.api.nvim_win_set_cursor(window, { edits[1].first, 0 })
end

--- What written code a buffer shows was asked for: the request, where the
--- code goes, the project's folder and how many proposals it was shown
--- with, by buffer, while it shows it.
---@class aineo.explain.ShownCode
---@field writing aineo.explain.WriteRequest
---@field ask aineo.explain.WriteAsk
---@field folder string
---@field count integer

---@type table<integer, aineo.explain.ShownCode>
local shown_code = {}

--- Shows `code`, written for `ask`, in `writing.buffer` as a preview
--- (`aineo.explain.preview`), in place of the proposal it shows, and
--- remembers what it was asked for (`shown_code`), the request named at the top of the edit of
--- the lines asked about (`shortened()`), or, for code written wherever
--- it belongs, what it is written for, the cursor moved to its first edit
--- first (`go_to_the_first()`); each edit a proposal of its own for code
--- that may edit the whole file.
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@param code aineo.explain.KeptCode
---@param folder string the project's folder, which a refinement runs in
local function show(writing, ask, code, folder)
  fix.replace(writing.buffer)
  shown_code[writing.buffer] =
    { writing = writing, ask = ask, folder = folder, count = #code.edits }
  if ask.place == 'anywhere' then
    go_to_the_first(writing, code.edits)
  end
  preview.show(writing.buffer, {
    window = writing.window,
    summary = code.summary,
    edits = code.edits,
    separate = writing.whole_file,
    subject_index = code.subject,
    keys = writing.keys,
    ask_key = writing.ask_key,
    subject = { text = shortened(ask.title or ask.request), look = kinds.WRITE },
    kind = kinds.WRITE,
  })
end

--- Shows (`show()`) the code the run `ended` answered for `asked`, placed in
--- the lines sent, and keeps it for those lines (`aineo.explain.kept`), or
--- tells the user, once, why nothing is shown: the buffer changed while the
--- code was asked, which any move of its `b:changedtick` says; the run
--- failed or answered no code (`code_of()`); the answer has no edits, when
--- its summary is told; or the code was refused, with the reason
--- (`placement_of()`).
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
  local fault, code = placement_of(writing, asked.ask)(asked, answered)
  if fault then
    vim.notify('aineo: the written code was refused: ' .. fault, vim.log.levels.WARN)
    return
  end
  kept.keep(writing.buffer, kept_key(writing, asked.ask), asked.lines, code)
  show(writing, asked.ask, code, asked.folder)
end

--- Starts Claude Code for the code `ask` asks for in `writing.buffer`,
--- from `folder`, the project's folder, showing above the line `ask.first`
--- that it is working (`aineo.explain.asking`) until it ends, then the
--- code it answered
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
    folder = folder,
  }
  local prompt = request.write_prompt({
    path = vim.fs.relpath(folder, path) or path,
    language = vim.bo[buffer].filetype,
    first = ask.first,
    last = ask.last,
    request = ask.place ~= 'in_request_lines' and ask.request or nil,
    blank = ask.place == 'in_blank_line',
    whole_file = writing.whole_file,
    anywhere = ask.place == 'anywhere',
    brief = writing.brief,
    lines = asked.lines,
  })
  asking.start({
    kind = kinds.WRITE,
    deep = writing.tools,
    buffer = buffer,
    window = writing.window,
    line = ask.first,
    timeout_ms = writing.timeout_ms,
    doing = 'writing code',
    arguments = request.arguments(writing.command, {
      model = writing.model,
      tools = writing.tools,
      effort = writing.effort,
      schema = request.FIX_SCHEMA,
    }),
    prompt = prompt,
    folder = folder,
    on_end = function(ended)
      show_answer(asked, ended)
    end,
  })
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
---@param folder string
---@return boolean
local function show_kept(writing, ask, folder)
  local lines = vim.api.nvim_buf_get_lines(writing.buffer, 0, -1, false)
  local code = kept.recall(writing.buffer, kept_key(writing, ask), lines)
  if not code then
    return false
  end
  show(writing, ask, code, folder)
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
  if not show_kept(writing, ask, folder) then
    start(writing, ask, folder)
  end
end

--- Shows the code kept for `ask` (`show_kept()`), else asks for it,
--- running Claude Code in `folder`, the project's folder (`ask_for()`).
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param writing aineo.explain.WriteRequest
---@param ask aineo.explain.WriteAsk
---@param folder string
function M.ask(writing, ask, folder)
  ask_for(writing, ask, folder)
end

--- The namespace of the extmarks that follow the lines requests typed in
--- the float are asked about. They draw nothing.
local ANCHOR = vim.api.nvim_create_namespace('aineo_explain_write_anchor')

--- Marks the line `line`, from 1, of `buffer` as the line a request is asked
--- about: the mark follows the line as lines are added or deleted around
--- it, and is invalidated when the line itself is deleted. Returns its id.
---
---@param buffer integer
---@param line integer
---@return integer
local function mark_anchor(buffer, line)
  return vim.api.nvim_buf_set_extmark(buffer, ANCHOR, line - 1, 0, { invalidate = true })
end

--- The line, from 1, where the mark `anchor` of `buffer` stands now, and
--- removes the mark; `nil` when the line it marked is gone.
---
---@param buffer integer
---@param anchor integer
---@return integer|nil
local function take_anchor(buffer, anchor)
  local mark = vim.api.nvim_buf_get_extmark_by_id(buffer, ANCHOR, anchor, { details = true })
  vim.api.nvim_buf_del_extmark(buffer, ANCHOR, anchor)
  if not mark[1] or mark[3].invalid then
    return nil
  end
  return mark[1] + 1
end

--- What a blank line is, as a pattern: spaces and tabs alone, or nothing,
--- as Vim's `\s` counts white space.
local BLANK = '^[ \t]*$'

--- Asks for code for `text`, the request the user sent from the float,
--- below the line the mark `anchor` follows, where it stands now
--- (`take_anchor()`, `ask_for()`), or in its place when it is blank, empty
--- or spaces and tabs alone (`BLANK`). Nothing is asked when the buffer is gone by then,
--- nor, with a word, when that line was deleted.
---
---@param writing aineo.explain.WriteRequest
---@param folder string
---@param anchor integer
---@param text string
local function ask_typed(writing, folder, anchor, text)
  if not vim.api.nvim_buf_is_valid(writing.buffer) then
    return
  end
  local line = take_anchor(writing.buffer, anchor)
  if not line then
    vim.notify('aineo: the line asked about is gone', vim.log.levels.WARN)
    return
  end
  local anchor_text = vim.api.nvim_buf_get_lines(writing.buffer, line - 1, line, true)[1]
  local place = anchor_text:match(BLANK) and 'in_blank_line' or 'below_line'
  ask_for(writing, { first = line, last = line, request = text, place = place }, folder)
end

--- What the float in which the user types a request says it does, when
--- Claude Code works from the file alone.
local PLAIN_TITLE = 'Write code'

--- What the float in which the user types a request says it does, when
--- the code may edit the whole file.
local WHOLE_FILE_TITLE = 'Write code that may change the whole file'

--- What the float in which the user types the request `writing` asks says
--- it does: `writing.title` when given, else `WHOLE_FILE_TITLE`, the title
--- of a request that reads the project, or `PLAIN_TITLE`.
---
---@param writing aineo.explain.WriteRequest
---@return string
local function title_of(writing)
  if writing.title then
    return writing.title
  end
  if writing.whole_file then
    return WHOLE_FILE_TITLE
  end
  return writing.tools and kinds.WRITE.deep.title or PLAIN_TITLE
end

--- Asks a Claude Code of its own, run in `folder`, the project's folder, to
--- write code for the request that the lines of `writing.range` hold, or
--- shows the code kept for it (`ask_for()`); tells the user, once, and asks
--- nothing when they hold white space alone. With no `writing.range`,
--- marks the line `writing.line` (`mark_anchor()`), then opens an empty
--- float in which the user types the request (`aineo.explain.steer`),
--- remembering nothing of it, and asks for the request sent below that
--- line where it stands then, or in its place when it is blank
--- (`ask_typed()`); nothing when the user cancels.
---
--- Raises an error naming `claude.cmd` when its command cannot be run; for
--- a request sent from the float, the float tells it to the user instead.
---
---@param writing aineo.explain.WriteRequest
---@param folder string
function M.propose(writing, folder)
  if not writing.range then
    local anchor = mark_anchor(writing.buffer, writing.line)
    steer.open({
      title = title_of(writing),
      steered_buffer = writing.buffer,
      on_send = function(text)
        ask_typed(writing, folder, anchor, text)
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
  ask_for(
    writing,
    { first = first, last = last, request = text, place = 'in_request_lines' },
    folder
  )
end

--- Forgets what the written code `buffer` showed was asked for, so that
--- nothing refines it.
---
---@param buffer integer
function M.forget(buffer)
  shown_code[buffer] = nil
end

--- What the float in which the user types how to change written code
--- says it does.
local REFINE_TITLE = 'Refine the written code'

--- The part of a prompt that asks for `left`, the proposals of written
--- code left to decide, to be changed as `instructions`, the user's, say:
--- each edit, the lines it spans now, its old lines and its new, then the
--- instructions.
---
---@param left aineo.explain.PlacedEdit[]
---@param instructions string
---@return string
local function refinement_part(left, instructions)
  local lines = {
    'The code proposed before, not decided yet, is to be changed as the user’s instructions say.'
      .. ' It proposed these edits:',
  }
  for _, edit in ipairs(left) do
    table.insert(lines, '')
    table.insert(lines, ('Lines %d to %d, replacing:'):format(edit.first, edit.last))
    vim.list_extend(lines, edit.old)
    table.insert(lines, 'with:')
    vim.list_extend(lines, edit.new)
  end
  vim.list_extend(lines, {
    '',
    "The user's instructions: " .. instructions,
    'Answer anew with the changed code, in place of the code proposed before.',
  })
  return table.concat(lines, '\n')
end

--- What the code `shown` was asked for is asked again as, once some of its
--- proposals were decided and its lines asked about may be gone: code
--- written wherever it belongs, the change of the code proposed, which
--- the instructions say, named as it was.
---
---@param shown aineo.explain.ShownCode
---@param left aineo.explain.PlacedEdit[]
---@return aineo.explain.WriteAsk
local function ask_with_some_decided(shown, left)
  local buffer = shown.writing.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  local language = vim.bo[buffer].filetype
  return {
    first = left[1].first,
    last = left[1].first,
    place = 'anywhere',
    request = ('Change the code proposed before in the file %s (language: %s), as the instructions below say.'):format(
      vim.fs.relpath(shown.folder, path) or path,
      language ~= '' and language or 'unknown'
    ),
    title = shown.ask.title or shown.ask.request,
  }
end

--- Asks again for the code `buffer` shows, written for a request, with
--- `instructions`, the user's, and the proposals left to decide
--- (`refinement_part()`); its answer is shown in place of them
--- (`show_answer()`), placed as the request first asked when none was
--- decided, else wherever it belongs (`ask_with_some_decided()`). Nothing
--- is asked when the buffer no longer shows that code.
---
---@param buffer integer
---@param instructions string
local function refine_with(buffer, instructions)
  local shown = shown_code[buffer]
  local left = preview.left(buffer)
  if not shown or preview.shown(buffer) ~= kinds.WRITE or #left == 0 then
    return
  end
  local ask = #left == shown.count and shown.ask or ask_with_some_decided(shown, left)
  local brief = vim.deepcopy(shown.writing.brief or {})
  table.insert(brief, refinement_part(left, instructions))
  start(vim.tbl_extend('force', shown.writing, { brief = brief }), ask, shown.folder)
end

--- Opens the float in which the user types how to change the written code
--- `buffer` shows (`aineo.explain.steer`), and asks again with what the
--- user sends (`refine_with()`); tells the user, once, when the buffer
--- shows no written code.
---
---@param buffer integer
function M.refine(buffer)
  if not shown_code[buffer] or preview.shown(buffer) ~= kinds.WRITE then
    vim.notify('aineo: no written code is shown here to refine', vim.log.levels.INFO)
    return
  end
  steer.open({
    title = REFINE_TITLE,
    steered_buffer = buffer,
    on_send = function(text)
      refine_with(buffer, text)
    end,
  })
end

return M
