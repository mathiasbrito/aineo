--- The answers the explain home keeps in memory, explanations, issues, fixes
--- and code written for a request, so that asking again for what was
--- answered and shown, while the code is as it was, shows the answer again
--- instead of starting a request. Nothing is kept on disk.

local M = {}

--- One kept answer.
---@class aineo.explain.Kept
---@field lines string[] the text of the lines it was asked about
---@field answer aineo.explain.Explanation[]|aineo.explain.KeptFix|aineo.explain.KeptCode

--- A fix kept: its summary and its edits, placed in the lines it was asked
--- about, and whether it was asked with a prompt the user edited.
---@class aineo.explain.KeptFix
---@field summary string
---@field edits aineo.explain.PlacedEdit[]
---@field steered boolean

--- Code kept: its summary and its one edit, placed in the lines it was
--- asked for.
---@class aineo.explain.KeptCode
---@field summary string
---@field edits aineo.explain.PlacedEdit[]

--- The kept answers, by the buffer they are for and their key (`key()`).
---@type table<integer, table<string, aineo.explain.Kept>>
local kept = {}

--- What a deep request is asked with, which tells its answer from another's.
---@class aineo.explain.DeepAsk
---@field model string
---@field effort string
---@field steer string the prompt's text, as the user edited it

--- The key an answer is kept under: what was asked for, with or without
--- tools, which lines, and, for a deep request, its model, effort and prompt
--- text.
---
---@param kind aineo.explain.Kind
---@param tools boolean
---@param range integer[]|nil the first and last line asked about; the whole buffer when absent
---@param deep? aineo.explain.DeepAsk
---@return string
function M.key(kind, tools, range, deep)
  return ('%s %s %s%s'):format(
    kind.name,
    tools and 'tools' or 'code',
    range and (range[1] .. '-' .. range[2]) or 'all',
    deep and ' deep ' .. vim.json.encode({ deep.model, deep.effort, deep.steer }) or ''
  )
end

--- What a fix is asked for, which tells its answer from another's.
---@class aineo.explain.FixAsk
---@field line integer the line the issue is shown above, from 1
---@field issue string the issue's text
---@field model string
---@field effort string

--- The key a fix is kept under: the issue it fixes, on its line, and the
--- model and effort it is asked with, whatever its prompt, so that the fix
--- asked last for an issue is the one kept.
---
---@param asking aineo.explain.FixAsk
---@return string
function M.fix_key(asking)
  return 'fix ' .. vim.json.encode({ asking.line, asking.issue, asking.model, asking.effort })
end

--- What code is written for, which tells its answer from another's.
---@class aineo.explain.WriteKeyed
---@field first integer the first line of the request, or the line the code goes below, from 1
---@field last integer the last line of the request, or the line the code goes below
---@field request string the request's text
---@field below boolean whether the code goes below the line, else in place of the request's lines
---@field model string
---@field effort? string

--- The key code written for a request is kept under: the request, its
--- lines, whether the code goes below them or in their place, and the
--- model and effort it is asked with.
---
---@param asking aineo.explain.WriteKeyed
---@return string
function M.write_key(asking)
  return 'write '
    .. vim.json.encode({
      asking.first,
      asking.last,
      asking.request,
      asking.below,
      asking.model,
      asking.effort or vim.NIL,
    })
end

--- Keeps `answer`, the answer for the lines `lines` of `buffer`, under
--- `key`, in place of what was kept under it.
---
---@param buffer integer
---@param key string
---@param lines string[] the text of the lines asked about
---@param answer aineo.explain.Explanation[]|aineo.explain.KeptFix|aineo.explain.KeptCode
function M.keep(buffer, key, lines, answer)
  kept[buffer] = kept[buffer] or {}
  kept[buffer][key] = { lines = lines, answer = answer }
end

--- The answer kept for `buffer` under `key`, when the lines it was asked
--- about read `lines` still; `nil` when none is kept or the text changed, in
--- which case what was kept is dropped.
---
---@param buffer integer
---@param key string
---@param lines string[] the text of the lines now
---@return aineo.explain.Explanation[]|aineo.explain.KeptFix|aineo.explain.KeptCode|nil
function M.recall(buffer, key, lines)
  local found = (kept[buffer] or {})[key]
  if found and vim.deep_equal(found.lines, lines) then
    return found.answer
  end
  if found then
    kept[buffer][key] = nil
  end
end

--- Drops every answer kept for `buffer`.
---
---@param buffer integer
function M.forget(buffer)
  kept[buffer] = nil
end

return M
