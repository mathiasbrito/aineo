--- What `\v`, `\V`, their `<Plug>` mappings and `:AineoExplain` do: hand
--- the current buffer, a file's, to the explain home (`aineo.explain`), with
--- the Claude Code command and the settings of the configuration.

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
    command = config.claude.cmd,
    model = config.explain.model,
    timeout_ms = config.explain.timeout_ms,
  })
end

--- What `\v` and `\V` do in Visual mode: leave Visual mode, then explain
--- the lines the selection spans alone, as `explain()` does with `order`'s
--- tools.
---
---@param order aineo.entry.ExplainOrder
function M.explain_selection(order)
  local first, last = vim.fn.line('v'), vim.fn.line('.')
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  M.explain({ tools = order.tools, range = { math.min(first, last), math.max(first, last) } })
end

--- What `:AineoExplain clear` does: removes every explanation the current
--- buffer shows, and stops the request that runs for it
--- (`aineo.explain`'s `clear()`).
function M.clear_explanations()
  require('aineo.explain').clear(vim.api.nvim_get_current_buf())
end

return M
