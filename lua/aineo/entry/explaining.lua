--- What `\v`, `\V`, `\vi`, `\VI`, `\VV`, `\VVI`, `\Vf`, `\VVf`, `\w`, `\W`,
--- their `<Plug>` mappings, the keys of a fix shown, `:Aineo explain` and
--- `:Aineo write` do: hand the current buffer, a file's, to the explain home
--- (`aineo.explain`), with the Claude Code command and the settings of the
--- configuration.

local M = {}

local resolved_config = require('aineo.entry.settings').resolved

--- Whether `buffer` holds a file: it has a name and an empty `'buftype'`,
--- which none of aineo's own panes has.
---
---@param buffer integer
---@return boolean
local function holds_a_file(buffer)
  return vim.bo[buffer].buftype == '' and vim.api.nvim_buf_get_name(buffer) ~= ''
end

--- How an explanation is asked for.
---@class aineo.entry.ExplainOrder
---@field tools boolean whether Claude Code may read the project with read-only tools
---@field kind? 'explanations'|'issues' what is asked for; explanations when absent
---@field fresh? boolean whether to ask again whatever answer is kept
---@field deep? boolean whether it is a deep request: its prompt is edited first, and it runs with `explain.deep_model`, `explain.deep_effort` and `explain.deep_timeout_ms`
---@field range? integer[] the first and last lines to explain, from 1; the whole buffer when absent

--- Asks the explain home to explain the current buffer, in the current
--- window, as `order` says (`aineo.explain`'s `ask()`): with `claude.cmd`,
--- `explain.model` and `explain.timeout_ms`, or, for a deep order,
--- `explain.deep_model`, `explain.deep_effort` and `explain.deep_timeout_ms`.
---
--- Raises an error when the current buffer holds no file, and the
--- configuration's or the explain home's errors.
---
---@param order aineo.entry.ExplainOrder
function M.explain(order)
  local buffer = vim.api.nvim_get_current_buf()
  if not holds_a_file(buffer) then
    error('explaining works in the buffer of a file', 0)
  end
  local config = resolved_config()
  local settings = config.explain
  require('aineo.explain').ask({
    buffer = buffer,
    window = vim.api.nvim_get_current_win(),
    range = order.range,
    tools = order.tools,
    kind = order.kind,
    fresh = order.fresh,
    deep = order.deep and { effort = settings.deep_effort } or nil,
    command = config.claude.cmd,
    model = order.deep and settings.deep_model or settings.model,
    timeout_ms = order.deep and settings.deep_timeout_ms or settings.timeout_ms,
    send_key = config.prefix and config.prefix .. 's' or ':Aineo send',
  })
end

--- How a fix is asked for.
---@class aineo.entry.FixOrder
---@field steered boolean whether the user edits the prompt first, in a float

--- What `\Vf`, `\VVf` and their `<Plug>` mappings do: ask the explain home
--- for a fix of the issue shown for the cursor's line of the current buffer,
--- a file's (`aineo.explain`'s `propose_fix()`), with `claude.cmd`,
--- `explain.fix_model`, `explain.fix_effort` and `explain.fix_timeout_ms`;
--- while the fix is shown, the prefix followed by `Va`, `Vr` and `Vd`
--- accept it, reject it and show its diff, unless the prefix is `false`.
--- What asks a fix is told to the user as the prefix followed by `Vf` and
--- `VVf`, or, when the prefix is `false`, as their `<Plug>` mappings.
---
--- Raises an error when the current buffer holds no file, and the
--- configuration's or the explain home's errors.
---
---@param order aineo.entry.FixOrder
function M.propose_fix(order)
  local buffer = vim.api.nvim_get_current_buf()
  if not holds_a_file(buffer) then
    error('a fix is asked in the buffer of a file', 0)
  end
  local config = resolved_config()
  local settings = config.explain
  local prefix = config.prefix
  require('aineo.explain').propose_fix({
    buffer = buffer,
    window = vim.api.nvim_get_current_win(),
    line = vim.fn.line('.'),
    steered = order.steered,
    command = config.claude.cmd,
    model = settings.fix_model,
    effort = settings.fix_effort,
    timeout_ms = settings.fix_timeout_ms,
    keys = prefix and { accept = prefix .. 'Va', reject = prefix .. 'Vr', diff = prefix .. 'Vd' }
      or nil,
    ask_keys = prefix and { plain = prefix .. 'Vf', steered = prefix .. 'VVf' } or {
      plain = '<Plug>(aineo-explain-fix)',
      steered = '<Plug>(aineo-explain-fix-steered)',
    },
  })
end

--- How code is asked for.
---@class aineo.entry.WriteOrder
---@field deep boolean whether Claude Code may read the project, with `write.deep_model`, `write.deep_effort` and `write.deep_timeout_ms`; else `write.model` and `write.timeout_ms`, from the file alone
---@field range? integer[] the first and last lines that hold the request, from 1; the request is typed in a float, the code going below the cursor's line, when absent

--- What `\w`, `\W`, their `<Plug>` mappings and `:Aineo write` do: ask the
--- explain home to write code in the current buffer, a file's
--- (`aineo.explain`'s `propose_write()`), for the request the lines of
--- `order.range` hold, or for one typed in a float, the code going below
--- the cursor's line; with `claude.cmd` and `write.model`, from the file
--- alone, or, for a deep order, `write.deep_model` at `write.deep_effort`
--- with the read-only tools. While the code shows, the prefix followed by
--- `Wa`, `Wr` and `Wd` accept it, reject it and show its diff, unless the
--- prefix is `false`; what asks again is told as the prefix followed by `w`
--- or `W`, or as their `<Plug>` mapping.
---
--- Raises an error when the current buffer holds no file, and the
--- configuration's or the explain home's errors.
---
---@param order aineo.entry.WriteOrder
function M.write(order)
  local buffer = vim.api.nvim_get_current_buf()
  if not holds_a_file(buffer) then
    error('code is written in the buffer of a file', 0)
  end
  local config = resolved_config()
  local settings = config.write
  local prefix = config.prefix
  local plug = order.deep and '<Plug>(aineo-write-deep)' or '<Plug>(aineo-write)'
  require('aineo.explain').propose_write({
    buffer = buffer,
    window = vim.api.nvim_get_current_win(),
    line = vim.fn.line('.'),
    range = order.range,
    tools = order.deep,
    command = config.claude.cmd,
    model = order.deep and settings.deep_model or settings.model,
    effort = order.deep and settings.deep_effort or nil,
    timeout_ms = order.deep and settings.deep_timeout_ms or settings.timeout_ms,
    keys = prefix and { accept = prefix .. 'Wa', reject = prefix .. 'Wr', diff = prefix .. 'Wd' }
      or nil,
    ask_key = prefix and prefix .. (order.deep and 'W' or 'w') or plug,
  })
end

--- What `\w` and `\W` do in Visual mode: leave Visual mode, then write code
--- for the request the lines the selection spans hold, as `write()` does
--- with `order`'s depth.
---
---@param order aineo.entry.WriteOrder
function M.write_selection(order)
  local first, last = vim.fn.line('v'), vim.fn.line('.')
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  M.write({ deep = order.deep, range = { math.min(first, last), math.max(first, last) } })
end

--- What `<Plug>(aineo-fix-accept)` does: accepts the fix the current buffer
--- shows (`aineo.explain`'s `accept_fix()`).
function M.accept_fix()
  require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())
end

--- What `<Plug>(aineo-fix-reject)` does: rejects the fix the current buffer
--- shows (`aineo.explain`'s `reject_fix()`).
function M.reject_fix()
  require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())
end

--- What `<Plug>(aineo-fix-diff)` does: shows the fix the current buffer
--- shows as the diff view, or as the overlay again (`aineo.explain`'s
--- `toggle_fix_diff()`).
function M.toggle_fix_diff()
  require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf())
end

--- What `\v`, `\V`, `\vi`, `\VI`, `\VV` and `\VVI` do in Visual mode: leave
--- Visual mode, then ask about the lines the selection spans alone, as
--- `explain()` does with `order`'s tools, kind and depth.
---
---@param order aineo.entry.ExplainOrder
function M.explain_selection(order)
  local first, last = vim.fn.line('v'), vim.fn.line('.')
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  M.explain({
    tools = order.tools,
    kind = order.kind,
    deep = order.deep,
    range = { math.min(first, last), math.max(first, last) },
  })
end

--- What `\vc`, `<Plug>(aineo-explain-clean)` and `:Aineo explain clear`
--- do: return the current buffer to how it behaved when it was opened
--- (`aineo.explain`'s `clear()`), and tell the user so, once, whether or not
--- it held anything to clean.
function M.clear_explanations()
  require('aineo.explain').clear(vim.api.nvim_get_current_buf())
  vim.notify('aineo: explanations cleaned from this buffer', vim.log.levels.INFO)
end

--- What Send does when the current buffer has issues marked (`\vm`): hands
--- `submit` one message that asks Claude Code to check them (`aineo.explain`'s
--- `issues_message()`), opened by `explain.issues_prompt`, and, once `submit`
--- says it sent, unmarks them (`clear_issue_marks()`); with no Claude Code
--- ready to take it the marks stay. Reads the explain home only when it is
--- loaded: until a request is made nothing is marked. Returns whether the
--- buffer had marked issues, in which case Send has nothing else to do.
---
---@param submit fun(message: string): boolean sends the message, telling the user why when it cannot
---@param buffer integer the buffer Send was pressed in, before any switch to aineo's tab page
---@param folder string the folder the tab's Claude Code runs in, which the paths are told from
---@return boolean
function M.send_marked_issues(submit, buffer, folder)
  local explain = package.loaded['aineo.explain']
  if not explain then
    return false
  end
  local issues = explain.marked_issues(buffer, folder)
  if #issues == 0 then
    return false
  end
  if submit(explain.issues_message(resolved_config().explain.issues_prompt, issues)) then
    explain.clear_issue_marks(buffer)
  end
  return true
end

--- What `\vm` does in Normal mode: marks the issues shown above the cursor's
--- line of the current buffer, or unmarks those marked (`aineo.explain`'s
--- `toggle_issue_marks()`).
function M.mark_issues()
  local line = vim.fn.line('.')
  require('aineo.explain').toggle_issue_marks(vim.api.nvim_get_current_buf(), line, line)
end

--- What `\vm` does in Visual mode: leaves Visual mode, then marks or unmarks
--- the issues shown above the lines the selection spans, as `mark_issues()`
--- does for one line.
function M.mark_issues_selection()
  local first, last = vim.fn.line('v'), vim.fn.line('.')
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  require('aineo.explain').toggle_issue_marks(
    vim.api.nvim_get_current_buf(),
    math.min(first, last),
    math.max(first, last)
  )
end

--- What `<Plug>(aineo-explain-next)` and `<Plug>(aineo-explain-previous)`
--- do: move the current window's cursor to the next or the previous
--- explanation or issue of its buffer, as many on as the count typed before
--- the mapping says, one without (`aineo.explain`'s `jump()`).
---
---@param way 'next'|'previous'
function M.jump(way)
  require('aineo.explain').jump(vim.api.nvim_get_current_win(), way, vim.v.count1)
end

return M
