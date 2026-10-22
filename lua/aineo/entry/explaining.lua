--- What `\v`, `\V`, `\vi`, `\VI`, their `<Plug>` mappings and `:Aineo explain`
--- do: hand the current buffer, a file's, to the explain home
--- (`aineo.explain`), with the Claude Code command and the settings of the
--- configuration.

local M = {}

--- aineo's configuration, resolved from `vim.g.aineo` and the options
--- `require('aineo').setup()` recorded (`aineo.config`'s `resolve_config()`).
--- Raises its error naming the setting that is wrong.
---
---@return table
local function resolved_config()
  local config = require('aineo.config')
  return (config.resolve_config(vim.g.aineo, config.recorded_setup_options()))
end

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
---@field range? integer[] the first and last lines to explain, from 1; the whole buffer when absent

--- Asks the explain home to explain the current buffer, in the current
--- window, as `order` says (`aineo.explain`'s `ask()`): with `claude.cmd`,
--- `explain.model` and `explain.timeout_ms`.
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
  require('aineo.explain').ask({
    buffer = buffer,
    window = vim.api.nvim_get_current_win(),
    range = order.range,
    tools = order.tools,
    kind = order.kind,
    fresh = order.fresh,
    command = config.claude.cmd,
    model = config.explain.model,
    timeout_ms = config.explain.timeout_ms,
  })
end

--- What `\v`, `\V`, `\vi` and `\VI` do in Visual mode: leave Visual mode,
--- then ask about the lines the selection spans alone, as `explain()` does
--- with `order`'s tools and kind.
---
---@param order aineo.entry.ExplainOrder
function M.explain_selection(order)
  local first, last = vim.fn.line('v'), vim.fn.line('.')
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  M.explain({
    tools = order.tools,
    kind = order.kind,
    range = { math.min(first, last), math.max(first, last) },
  })
end

--- What `:Aineo explain clear` does: removes every explanation and every
--- issue the current buffer shows, and stops the request that runs for it
--- (`aineo.explain`'s `clear()`).
function M.clear_explanations()
  require('aineo.explain').clear(vim.api.nvim_get_current_buf())
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
---@return boolean
function M.send_marked_issues(submit)
  local explain = package.loaded['aineo.explain']
  if not explain then
    return false
  end
  local buffer = vim.api.nvim_get_current_buf()
  local issues = explain.marked_issues(buffer)
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
