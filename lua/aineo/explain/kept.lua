--- The answers the explain home keeps in memory, so that asking again for
--- what was answered and shown, while the code is as it was, places the
--- answer again instead of starting a request. Nothing is kept on disk.

local M = {}

--- One kept answer.
---@class aineo.explain.Kept
---@field lines string[] the text of the lines it was asked about
---@field explanations aineo.explain.Explanation[]

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

--- Keeps `explanations`, the answer for the lines `lines` of `buffer`, under
--- `key`, in place of what was kept under it.
---
---@param buffer integer
---@param key string
---@param lines string[] the text of the lines asked about
---@param explanations aineo.explain.Explanation[]
function M.keep(buffer, key, lines, explanations)
  kept[buffer] = kept[buffer] or {}
  kept[buffer][key] = { lines = lines, explanations = explanations }
end

--- The answer kept for `buffer` under `key`, when the lines it was asked
--- about read `lines` still; `nil` when none is kept or the text changed, in
--- which case what was kept is dropped.
---
---@param buffer integer
---@param key string
---@param lines string[] the text of the lines now
---@return aineo.explain.Explanation[]|nil
function M.recall(buffer, key, lines)
  local answer = (kept[buffer] or {})[key]
  if answer and vim.deep_equal(answer.lines, lines) then
    return answer.explanations
  end
  if answer then
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
