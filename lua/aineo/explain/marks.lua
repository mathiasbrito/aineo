--- How the explain home shows what Claude Code answered: as virtual lines above
--- the lines it is about, in the namespace of the kind of answer
--- (`aineo.explain.Kind`).

local draw = require('aineo.explain.draw')
local kinds = require('aineo.explain.kinds')

local M = {}

--- What marks the gutter of every virtual line of a marked issue.
local MARKED_GUTTER_MARK = '✓'

--- What says, in the badge, the key that sends the marked issues, unless
--- the answer's origin gives it.
local DEFAULT_SEND_KEY = '\\s'

--- The fewest columns a virtual line's text is wrapped at, however narrow
--- the window.
local NARROWEST = 1

--- The namespace of the extmarks of `kind`, made when first asked for.
---
---@param kind aineo.explain.Kind
---@return integer
local function namespace_of(kind)
  return vim.api.nvim_create_namespace(kind.namespace)
end

--- The style of a band of `kind`, that of a marked issue when `marked`.
---
---@param kind aineo.explain.Kind
---@param marked? boolean
---@return aineo.explain.Style
local function style_of(kind, marked)
  if marked and kind.marked_groups then
    return {
      gutter_mark = MARKED_GUTTER_MARK,
      text = kind.marked_groups.text,
      gutter = kind.marked_groups.gutter,
      fill = kind.groups.fill,
    }
  end
  return {
    gutter_mark = draw.GUTTER_MARK,
    text = kind.groups.text,
    gutter = kind.groups.gutter,
    fill = kind.groups.fill,
  }
end

--- What `show_above()` shows.
---@class aineo.explain.Band
---@field kind aineo.explain.Kind
---@field line integer the line it is shown above, from 1
---@field indent string the spaces that start each row's text
---@field rows string[]
---@field geometry aineo.explain.Geometry
---@field label string shown on the first row, in the gutter
---@field marked? boolean whether it is drawn as a marked issue (`style_of()`)
---@field id? integer the extmark to set again; a new one when absent

--- Shows `band.rows` in `buffer` as virtual lines above `band.line`, each
--- starting at the window's left column and showing as `draw.row()` does,
--- in the style of the kind (`style_of()`). The line's number shows in the
--- number group of the kind. Returns the extmark's id.
---
---@param buffer integer
---@param band aineo.explain.Band
---@return integer
local function show_above(buffer, band)
  local virt_lines = {}
  local style = style_of(band.kind, band.marked)
  for number, row in ipairs(band.rows) do
    virt_lines[number] =
      draw.row(row, band.indent, band.geometry, number == 1 and band.label or '', style)
  end
  return vim.api.nvim_buf_set_extmark(
    buffer,
    namespace_of(band.kind),
    band.line - 1,
    band.kind.column,
    {
      id = band.id,
      virt_lines = virt_lines,
      virt_lines_above = true,
      virt_lines_leftcol = true,
      number_hl_group = band.kind.groups.number,
      invalidate = true,
      undo_restore = false,
      strict = false,
    }
  )
end

--- The explanations of one kind shown in one buffer, and what they were
--- placed for.
---@class aineo.explain.Placed
---@field kind aineo.explain.Kind
---@field window integer the window they were placed for
---@field textoff integer the columns before the text there, when they were placed
---@field texts table<integer, string> the text of each, by extmark id
---@field files table<integer, string> the absolute path of the file each was asked about, by extmark id
---@field marked table<integer, boolean> the extmark ids of those marked
---@field deep table<integer, boolean> the extmark ids of those that answer a deep request
---@field send_key string what the badge says sends the marked issues
---@field pending boolean whether placing them again is scheduled

--- The explanations that are shown, by the buffer and the name of their kind.
---@type table<integer, table<string, aineo.explain.Placed>>
local placed = {}

--- What is called when the explanations a buffer shows change.
---@alias aineo.explain.MarksListener fun(buffer: integer, window: integer|nil)

---@type aineo.explain.MarksListener[]
local listeners = {}

--- Calls every listener (`on_change()`) for `buffer`, with the window its
--- explanations were placed for, when it is known.
---
---@param buffer integer
---@param window? integer
local function notify(buffer, window)
  for _, listener in ipairs(listeners) do
    listener(buffer, window)
  end
end

--- Has `listener` called, with the buffer and the window its explanations
--- were placed for, after the explanations a buffer shows change: placed,
--- cleared, or lost to an edit that deleted the line they sit above.
---
---@param listener aineo.explain.MarksListener
function M.on_change(listener)
  table.insert(listeners, listener)
end

--- The line, from 1, the extmark `id` of `kind` sits above in `buffer`, or
--- `nil` when it is gone.
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@param id integer
---@return integer|nil
local function line_of(buffer, kind, id)
  local position = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace_of(kind), id, {})
  return position[1] and position[1] + 1
end

--- An explanation to show.
---@class aineo.explain.Shown
---@field kind aineo.explain.Kind
---@field line integer from 1
---@field text string
---@field marked? boolean whether it shows as a marked issue
---@field deep? boolean whether it answers a deep request, which its label says
---@field id? integer the extmark to set again; a new one when absent

--- Shows the explanation `shown` in `buffer` as virtual lines above its
--- line, indented as that line but by half the window's text width at most,
--- each row starting with `draw.MARK`, and the text wrapped (`draw.wrapped()`) at the
--- text width of `geometry` less that indent, in the look of its kind.
--- Returns the extmark's id.
---
---@param buffer integer
---@param shown aineo.explain.Shown
---@param geometry aineo.explain.Geometry
---@return integer
local function show_explanation(buffer, shown, geometry)
  local width = geometry.width - geometry.textoff
  local indent = draw.indent_of(buffer, shown.line, math.floor(width / 2))
  local room = math.max(width - #indent - vim.fn.strdisplaywidth(draw.MARK), NARROWEST)
  return show_above(buffer, {
    id = shown.id,
    kind = shown.kind,
    line = shown.line,
    indent = indent,
    rows = draw.wrapped(shown.text, room),
    geometry = geometry,
    label = shown.deep and shown.kind.deep.label or shown.kind.label,
    marked = shown.marked,
  })
end

--- Shows again, as the same extmarks, the explanations `record` holds for
--- `buffer`, for the geometry of the window they were placed for now, and
--- forgets those whose extmark is gone.
---
---@param buffer integer
---@param record aineo.explain.Placed
local function place_again(buffer, record)
  record.pending = false
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  local geometry = draw.geometry_of(buffer, record.window)
  record.textoff = geometry.textoff
  for id, text in pairs(record.texts) do
    local line = line_of(buffer, record.kind, id)
    if line then
      show_explanation(buffer, {
        kind = record.kind,
        line = line,
        text = text,
        marked = record.marked[id],
        deep = record.deep[id],
        id = id,
      }, geometry)
    else
      record.texts[id] = nil
      record.files[id] = nil
      record.marked[id] = nil
      record.deep[id] = nil
    end
  end
end

--- Forgets the explanations of `record` whose extmark is gone, which an edit
--- that deleted their line or a clear of lines took, and, when the event loop
--- has turned, tells the listeners (`on_change()`) if it forgot any, whoever
--- it was that noticed: a reader of the marks, a redraw of the badge or the
--- watch of the edits. Returns whether it forgot any.
---
---@param buffer integer
---@param record aineo.explain.Placed
---@return boolean
local function forget_lost(buffer, record)
  local forgot = false
  for id in pairs(record.texts) do
    if not line_of(buffer, record.kind, id) then
      record.texts[id] = nil
      record.files[id] = nil
      record.marked[id] = nil
      record.deep[id] = nil
      forgot = true
    end
  end
  if forgot then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buffer) then
        notify(buffer, record.window)
      end
    end)
  end
  return forgot
end

--- Whether any record of `buffer` still holds an explanation.
---
---@param buffer integer
---@return boolean
local function holds_any(buffer)
  for _, record in pairs(placed[buffer] or {}) do
    if next(record.texts) then
      return true
    end
  end
  return false
end

--- Has the explanations of `buffer` that an edit lost forgotten
--- (`forget_lost()`) when the event loop has turned: the extmarks of an edit
--- are settled by then, and a buffer's text cannot change inside the
--- callback that sees the edit.
---
---@param buffer integer
local function settle_after_edit(buffer)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buffer) then
      return
    end
    for _, record in pairs(placed[buffer] or {}) do
      forget_lost(buffer, record)
    end
  end)
end

--- The buffers whose edits are watched.
---@type table<integer, boolean>
local watched = {}

--- Has `settle_after_edit()` called after each edit of `buffer`, until it
--- holds no explanation, when the watch ends.
---
---@param buffer integer
local function watch_edits(buffer)
  if watched[buffer] then
    return
  end
  watched[buffer] = true
  vim.api.nvim_buf_attach(buffer, false, {
    on_lines = function()
      settle_after_edit(buffer)
      return not holds_any(buffer)
    end,
    on_detach = function()
      watched[buffer] = nil
    end,
  })
end

--- What the explanations of one answer were asked for.
---@class aineo.explain.Origin
---@field window integer the window they were asked in
---@field file string the absolute path of the file they were asked about
---@field send_key? string what the user presses to send the issues once marked; `\s` when absent
---@field deep? boolean whether they answer a deep request, which their label says

--- Shows each of `explanations` in `buffer` as virtual lines above its line
--- (`show_explanation()`) for a window showing it (`draw.geometry_of()`), and
--- keeps them to show again when that window's gutter changes
--- (`keep_aligned()`). Tells the listeners (`on_change()`).
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@param explanations aineo.explain.Explanation[]
---@param origin aineo.explain.Origin where and for what they were asked
function M.place(buffer, kind, explanations, origin)
  local window, file = origin.window, origin.file
  local geometry = draw.geometry_of(buffer, window)
  placed[buffer] = placed[buffer] or {}
  local record = placed[buffer][kind.name]
  if record and record.textoff ~= geometry.textoff then
    record.window = window
    place_again(buffer, record)
  end
  record = record
    or { kind = kind, texts = {}, files = {}, marked = {}, deep = {}, pending = false }
  record.window, record.textoff = window, geometry.textoff
  record.send_key = origin.send_key or DEFAULT_SEND_KEY
  placed[buffer][kind.name] = record
  for _, explanation in ipairs(explanations) do
    local id = show_explanation(buffer, {
      kind = kind,
      line = explanation.line,
      text = explanation.text,
      deep = origin.deep,
    }, geometry)
    record.texts[id] = explanation.text
    record.files[id] = file
    record.deep[id] = origin.deep
  end
  watch_edits(buffer)
  notify(buffer, window)
end

--- The lines, from 1, that `buffer` shows an explanation above, of any
--- kind, each once, in order. A line that says a request is working is none.
---
---@param buffer integer
---@return integer[]
function M.lines(buffer)
  local seen, lines = {}, {}
  for _, record in pairs(placed[buffer] or {}) do
    forget_lost(buffer, record)
    for id in pairs(record.texts) do
      local line = line_of(buffer, record.kind, id)
      if line and not seen[line] then
        seen[line] = true
        table.insert(lines, line)
      end
    end
  end
  table.sort(lines)
  return lines
end

--- The record of the issues `buffer` shows, if any.
---
---@param buffer integer
---@return aineo.explain.Placed|nil
local function issues_of(buffer)
  return (placed[buffer] or {})[kinds.ISSUES.name]
end

--- Marks each issue `buffer` shows above the lines from `first` to `last`
--- that is not marked, and unmarks each that is, showing them again in the
--- look that says so. An explanation is never marked. Tells the listeners
--- (`on_change()`) when it marked or unmarked any. Returns how many issues
--- lie above those lines.
---
---@param buffer integer
---@param first integer from 1
---@param last integer from 1
---@return integer
function M.toggle_issue_marks(buffer, first, last)
  local record = issues_of(buffer)
  if not record then
    return 0
  end
  local found = 0
  for id in pairs(record.texts) do
    local line = line_of(buffer, record.kind, id)
    if line and line >= first and line <= last then
      found = found + 1
      record.marked[id] = not record.marked[id] or nil
    end
  end
  if found > 0 then
    place_again(buffer, record)
    notify(buffer, record.window)
  end
  return found
end

--- The issues `buffer` shows that are marked, each with the line it is above,
--- its text and the file its request was made for, in the order of the
--- lines, then of the answer.
---
---@param buffer integer
---@return { line: integer, text: string, file: string }[]
function M.marked_issues(buffer)
  local record = issues_of(buffer)
  local found = {}
  if not record then
    return found
  end
  forget_lost(buffer, record)
  for id in pairs(record.marked) do
    table.insert(found, {
      id = id,
      line = line_of(buffer, record.kind, id),
      text = record.texts[id],
      file = record.files[id],
    })
  end
  table.sort(found, function(a, b)
    return a.line < b.line or (a.line == b.line and a.id < b.id)
  end)
  return vim.tbl_map(function(issue)
    return { line = issue.line, text = issue.text, file = issue.file }
  end, found)
end

--- An issue a buffer shows.
---@class aineo.explain.ShownIssue
---@field id integer its extmark
---@field text string

--- The issue `buffer` shows above `line`, from 1: the marked one when one
--- is, else the first the answer gave; `nil` when none is shown there.
---
---@param buffer integer
---@param line integer
---@return aineo.explain.ShownIssue|nil
function M.issue_at(buffer, line)
  local record = issues_of(buffer)
  if not record then
    return nil
  end
  local ids = vim.tbl_keys(record.texts)
  table.sort(ids)
  local first, first_marked
  for _, id in ipairs(ids) do
    if line_of(buffer, record.kind, id) == line then
      first = first or id
      first_marked = first_marked or (record.marked[id] and id)
    end
  end
  local chosen = first_marked or first
  return chosen and { id = chosen, text = record.texts[chosen] }
end

--- Removes the issue `id` `buffer` shows, marked or not, and tells the
--- listeners (`on_change()`); nothing when it is shown no more.
---
---@param buffer integer
---@param id integer
function M.remove_issue(buffer, id)
  local record = issues_of(buffer)
  if not record or not record.texts[id] then
    return
  end
  record.texts[id] = nil
  record.files[id] = nil
  record.marked[id] = nil
  record.deep[id] = nil
  M.remove(buffer, record.kind, id)
  notify(buffer, record.window)
end

--- Unmarks every issue `buffer` shows, which stay shown, and tells the
--- listeners (`on_change()`) when any was marked.
---
---@param buffer integer
function M.clear_issue_marks(buffer)
  local record = issues_of(buffer)
  if not record or next(record.marked) == nil then
    return
  end
  record.marked = {}
  place_again(buffer, record)
  notify(buffer, record.window)
end

--- How many issues `buffer` shows that are marked, and the key the badge
--- says sends them.
---
---@param buffer integer
---@return integer count
---@return string|nil send_key nothing when none is marked
function M.marked_summary(buffer)
  local record = issues_of(buffer)
  if not record or not vim.api.nvim_buf_is_valid(buffer) then
    return 0
  end
  forget_lost(buffer, record)
  local count = vim.tbl_count(record.marked)
  return count, count > 0 and record.send_key or nil
end

--- Forgets what was placed in `buffer`, which is gone, and tells the
--- listeners (`on_change()`).
---
---@param buffer integer
function M.forget(buffer)
  local records = placed[buffer] or {}
  placed[buffer] = nil
  for _, record in pairs(records) do
    notify(buffer, record.window)
  end
end

--- Has the explanations that are shown placed again, as the same extmarks,
--- when the window they were placed for shows the buffer with another
--- number, sign or fold column than when they were placed. A decoration
--- provider notices at each redraw and schedules the placing, as extmarks
--- cannot change while redrawing. Called again, it leaves the provider it
--- made.
function M.keep_aligned()
  vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace('aineo_explain_align'), {
    on_win = function(_, _, buffer)
      for _, record in pairs(placed[buffer] or {}) do
        if
          not record.pending and draw.geometry_of(buffer, record.window).textoff ~= record.textoff
        then
          record.pending = true
          vim.schedule(function()
            place_again(buffer, record)
          end)
        end
      end
    end,
  })
end

--- Shows in `buffer`, above `line`, from 1, and indented as it, in the look
--- of `kind` with no label, the virtual line that says a request is
--- working, `text`. Returns its id, for `update_progress()` and `remove()`.
---
---@param buffer integer
---@param window integer the window the request was made in
---@param kind aineo.explain.Kind
---@param line integer
---@param text string
---@return integer
function M.show_progress(buffer, window, kind, line, text)
  return show_above(buffer, {
    kind = kind,
    line = line,
    indent = draw.indent_of(buffer, line),
    rows = { text },
    geometry = draw.geometry_of(buffer, window),
    label = '',
  })
end

--- Changes the text of the virtual line `id` that `show_progress()` showed
--- to `text`, where the line it is above is now; nothing when it is gone.
---
---@param buffer integer
---@param window integer the window the request was made in
---@param kind aineo.explain.Kind
---@param id integer
---@param text string
function M.update_progress(buffer, window, kind, id, text)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  local position = vim.api.nvim_buf_get_extmark_by_id(buffer, namespace_of(kind), id, {})
  if #position == 0 then
    return
  end
  local line = position[1] + 1
  show_above(buffer, {
    id = id,
    kind = kind,
    line = line,
    indent = draw.indent_of(buffer, line),
    rows = { text },
    geometry = draw.geometry_of(buffer, window),
    label = '',
  })
end

--- Whether `buffer` shows any virtual line of `kind`.
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@return boolean
function M.is_showing(buffer, kind)
  return #vim.api.nvim_buf_get_extmarks(buffer, namespace_of(kind), 0, -1, { limit = 1 }) > 0
end

--- Removes every virtual line of `kind` from `buffer`, or those above the
--- lines from `first` to `last`, from 1, when they are given. Tells the
--- listeners (`on_change()`) when the buffer showed explanations of `kind`.
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@param first? integer
---@param last? integer
function M.clear(buffer, kind, first, last)
  local record = (placed[buffer] or {})[kind.name]
  if not first and record then
    placed[buffer][kind.name] = nil
  end
  vim.api.nvim_buf_clear_namespace(buffer, namespace_of(kind), first and first - 1 or 0, last or -1)
  if record then
    notify(buffer, record.window)
  end
end

--- Removes the virtual lines of the extmark `id` of `kind` from `buffer`,
--- unless the buffer is gone.
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@param id integer
function M.remove(buffer, kind, id)
  if vim.api.nvim_buf_is_valid(buffer) then
    vim.api.nvim_buf_del_extmark(buffer, namespace_of(kind), id)
  end
end

return M
