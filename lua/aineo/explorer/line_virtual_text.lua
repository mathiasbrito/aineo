--- What an entry's line shows without its buffer text holding it: the guide
--- over its indent, the places before its name for Claude's mark and an
--- icon, the number of changed files after a folder's mark, the mark of
--- unsaved edits after a file's name, and at the right edge a file's
--- diagnostics and lines added and removed, when they fit. It reads a view
--- and the facts of one line, and touches no buffer.

local counts = require('aineo.explorer.counts')
local guides = require('aineo.explorer.guides')

local M = {}

--- Where a line stands among its folder's entries.
---@class aineo.explorer.LinePlace
---@field continues boolean[] for each folder above it but the root's, whether that folder has entries after it
---@field is_last boolean whether it is the last of its folder

--- What a line is, to the text it shows without holding it.
---@class aineo.explorer.LineFacts
---@field entry aineo.explorer.Entry the entry the line stands for
---@field line string
---@field columns aineo.explorer.LineColumns
---@field mark string|nil
---@field holds_changes boolean whether the line is a folder's, marked as holding changes
---@field folders_changed integer|nil the changed files below the folder, at any depth
---@field depth integer
---@field place aineo.explorer.LinePlace

--- The cells the inline virtual text of `items` takes.
---
---@param items aineo.explorer.VirtualText[]
---@return integer
local function inline_width(items)
  local width = 0
  for _, item in ipairs(items) do
    if item.position == 'inline' then
      width = width + counts.width_of(item)
    end
  end
  return width
end

--- The width of the place a mark or an icon takes before a name, the glyph
--- and a blank.
local PLACE = '  '

--- The mark of a file in the work of the session, with its blank.
local CLAUDE_MARK = '✦ '

--- The chunks before a name: the place of Claude's mark, taken while the
--- session has files in its work, then the place of an icon, taken while the
--- view has icons. A folder, a file with no mark and a file with no icon
--- leave their places blank, so that the names line up.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.explorer.VirtualChunk[]
local function name_places(view, facts)
  local chunks = {}
  local is_file = facts.entry.kind == 'file'
  if view.claude and next(view.claude) then
    local marked = is_file and view.claude[facts.entry.path]
    table.insert(chunks, marked and { text = CLAUDE_MARK, role = 'claude' } or { text = PLACE })
  end
  if view.icons then
    local icon = is_file and view.icons(facts.entry) or nil
    table.insert(
      chunks,
      icon and { text = icon.text .. ' ', group = icon.group } or { text = PLACE }
    )
  end
  return chunks
end

--- The text that follows the name of a file with unsaved edits: a blank,
--- then a dot.
local UNSAVED = ' ●'

--- The errors and warnings of the file `facts` is about, nil when none
--- are known.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.explorer.DiagnosticCount|nil
local function diagnostics_of(view, facts)
  return facts.entry.kind == 'file' and view.diagnostics and view.diagnostics[facts.entry.path]
    or nil
end

--- The lines added and removed in the file `facts` is about while the view
--- shows counts and git sees it changed, nil otherwise.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.git.LineCount|nil
local function line_counts_of(view, facts)
  return view.counts
      and facts.mark
      and facts.entry.kind == 'file'
      and view.line_counts
      and view.line_counts[facts.entry.path]
    or nil
end

--- The text a line shows without holding it under `view`: the guide over
--- its indent, the number of changed files after a folder's mark, and a
--- changed file's lines added and removed at the right edge when they fit.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.explorer.VirtualText[]
function M.virtual_text_of(view, facts)
  local items = {}
  if view.guides and facts.depth > 0 then
    table.insert(items, guides.virtual_text(facts.place.continues, facts.place.is_last))
  end
  local places = name_places(view, facts)
  if #places > 0 then
    table.insert(items, { position = 'inline', column = facts.columns.name, chunks = places })
  end
  if view.counts and facts.holds_changes and facts.folders_changed then
    table.insert(
      items,
      counts.folder_count(facts.folders_changed, facts.columns.mark_end, 'changed_folder')
    )
  end
  if view.modified and facts.entry.kind == 'file' and view.modified[facts.entry.path] then
    table.insert(items, {
      position = 'inline',
      column = facts.columns.name_end,
      chunks = { { text = UNSAVED, role = 'unsaved' } },
    })
  end
  local candidates = counts.right_edge(diagnostics_of(view, facts), line_counts_of(view, facts))
  if #candidates == 0 then
    return items
  end
  local taken = vim.api.nvim_strwidth(facts.line) + inline_width(items)
  for _, item in ipairs(candidates) do
    if counts.fits(item, taken, view.width) then
      table.insert(items, item)
      break
    end
  end
  return items
end

return M
