--- How the explain home shows what Claude Code answered: as virtual lines above
--- the lines it is about, in the namespace of the kind of answer
--- (`aineo.explain.Kind`).

local kinds = require('aineo.explain.kinds')

local M = {}

--- What starts the text of every virtual line, after the line's indent.
local MARK = '┊ '

--- What marks the gutter of every virtual line, and of every virtual line
--- of a marked issue.
local GUTTER_MARK = '▎'
local MARKED_GUTTER_MARK = '✓'

--- The fewest characters of a label worth showing in the gutter.
local SHORTEST_LABEL = 2

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

--- The bytes of the longest start of `word` no wider than `width` display
--- columns, and at least its first character. Walks the characters of that
--- start alone, so that a long word costs its length, not its length per row.
---
---@param word string
---@param width integer
---@return integer
local function fitting_bytes(word, width)
  local bytes, used = 0, 0
  while bytes < #word do
    local character = word:sub(bytes + 1, bytes + 1 + vim.str_utf_end(word, bytes + 1))
    local wide = vim.fn.strdisplaywidth(character)
    if used + wide > width and bytes > 0 then
      break
    end
    bytes = bytes + #character
    used = used + wide
  end
  return bytes
end

--- `text` broken into rows no wider than `width` display columns: between
--- words, a word wider than `width` cut into rows of its own, and a new row
--- at each line break.
---
---@param text string
---@param width integer
---@return string[]
local function wrapped(text, width)
  local rows = {}
  for _, paragraph in ipairs(vim.split(text, '\n', { plain = true })) do
    local row = ''
    for word in paragraph:gmatch('%S+') do
      while vim.fn.strdisplaywidth(word) > width do
        if row ~= '' then
          table.insert(rows, row)
          row = ''
        end
        local cut = fitting_bytes(word, width)
        table.insert(rows, word:sub(1, cut))
        word = word:sub(cut + 1)
      end
      local longer = row == '' and word or row .. ' ' .. word
      if vim.fn.strdisplaywidth(longer) <= width then
        row = longer
      else
        table.insert(rows, row)
        row = word
      end
    end
    table.insert(rows, row)
  end
  return rows
end

--- Where a window shows a buffer's text: its width, and the columns before
--- the text that its number, sign and fold columns take.
---@class aineo.explain.Geometry
---@field width integer the window's columns
---@field textoff integer the columns before the text

--- The geometry of a window showing `buffer`: `window`'s when it still shows
--- `buffer`, else the first such window's, else the screen's, with no
--- columns before the text, when none shows it.
---
---@param buffer integer
---@param window integer
---@return aineo.explain.Geometry
local function geometry_of(buffer, window)
  if not (vim.api.nvim_win_is_valid(window) and vim.api.nvim_win_get_buf(window) == buffer) then
    window = vim.fn.bufwinid(buffer)
  end
  local info = vim.fn.getwininfo(window)[1]
  if not info then
    return { width = vim.o.columns, textoff = 0 }
  end
  return { width = info.width, textoff = info.textoff }
end

--- The indent of `line` of `buffer`, from 1, as the spaces that fill it, at
--- most `most` of them.
---
---@param buffer integer
---@param line integer
---@param most? integer no limit when absent
---@return string
local function indent_of(buffer, line, most)
  local indent = vim.api.nvim_buf_call(buffer, function()
    return vim.fn.indent(line)
  end)
  return (' '):rep(math.min(indent, most or indent))
end

--- How a band is drawn: the character that marks its gutter and the
--- highlight groups of its text, gutter and the columns the gutter fills.
---@class aineo.explain.Style
---@field gutter_mark string
---@field text string
---@field gutter string
---@field fill string

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
    gutter_mark = GUTTER_MARK,
    text = kind.groups.text,
    gutter = kind.groups.gutter,
    fill = kind.groups.fill,
  }
end

--- The chunks that fill the columns before the text, `textoff` of them: the
--- style's mark, then spaces, and `label` right-aligned with a space after
--- it, cut to the cells left by the mark and that space, and left out when
--- fewer than `SHORTEST_LABEL` fit; the mark and the label in the style's
--- gutter group and the spaces in its fill group; none when there are no
--- such columns.
---
---@param textoff integer
---@param label string
---@param style aineo.explain.Style
---@return table[] chunks
local function gutter_chunks(textoff, label, style)
  if textoff == 0 then
    return {}
  end
  local mark_width = vim.fn.strdisplaywidth(style.gutter_mark)
  local room = textoff - mark_width - 1
  label = room >= SHORTEST_LABEL and label:sub(1, room) or ''
  local chunks = { { style.gutter_mark, style.gutter } }
  local spaces = textoff - mark_width - (label == '' and 0 or #label + 1)
  if spaces > 0 then
    table.insert(chunks, { (' '):rep(spaces), style.fill })
  end
  if label ~= '' then
    table.insert(chunks, { label, style.gutter })
    table.insert(chunks, { ' ', style.fill })
  end
  return chunks
end

--- The virtual line that shows `row`: the gutter (`gutter_chunks()`, with
--- `label`), `indent` unhighlighted, then `MARK` and `row` padded with
--- spaces to the end of the window, in the text group of `style`.
---
---@param row string
---@param indent string
---@param geometry aineo.explain.Geometry
---@param label string
---@param style aineo.explain.Style
---@return table[] chunks
local function band_row(row, indent, geometry, label, style)
  local body = MARK .. row
  local padding = geometry.width - geometry.textoff - #indent - vim.fn.strdisplaywidth(body)
  local chunks = gutter_chunks(geometry.textoff, label, style)
  if indent ~= '' then
    table.insert(chunks, { indent })
  end
  table.insert(chunks, { body .. (' '):rep(math.max(padding, 0)), style.text })
  return chunks
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
--- starting at the window's left column and showing as `band_row()` does,
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
      band_row(row, band.indent, band.geometry, number == 1 and band.label or '', style)
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
---@field id? integer the extmark to set again; a new one when absent

--- Shows the explanation `shown` in `buffer` as virtual lines above its
--- line, indented as that line but by half the window's text width at most,
--- each row starting with `MARK`, and the text wrapped (`wrapped()`) at the
--- text width of `geometry` less that indent, in the look of its kind.
--- Returns the extmark's id.
---
---@param buffer integer
---@param shown aineo.explain.Shown
---@param geometry aineo.explain.Geometry
---@return integer
local function show_explanation(buffer, shown, geometry)
  local width = geometry.width - geometry.textoff
  local indent = indent_of(buffer, shown.line, math.floor(width / 2))
  local room = math.max(width - #indent - vim.fn.strdisplaywidth(MARK), NARROWEST)
  return show_above(buffer, {
    id = shown.id,
    kind = shown.kind,
    line = shown.line,
    indent = indent,
    rows = wrapped(shown.text, room),
    geometry = geometry,
    label = shown.kind.label,
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
  local geometry = geometry_of(buffer, record.window)
  record.textoff = geometry.textoff
  for id, text in pairs(record.texts) do
    local line = line_of(buffer, record.kind, id)
    if line then
      show_explanation(buffer, {
        kind = record.kind,
        line = line,
        text = text,
        marked = record.marked[id],
        id = id,
      }, geometry)
    else
      record.texts[id] = nil
      record.files[id] = nil
      record.marked[id] = nil
    end
  end
end

--- Forgets the explanations of `record` whose extmark is gone, which an edit
--- that deleted their line or a clear of lines took. Returns whether it
--- forgot any.
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
      forgot = true
    end
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

--- Tells the listeners (`on_change()`) of `buffer` that an edit lost
--- explanations, if it did, when the event loop has turned: the extmarks of
--- an edit are settled by then, and a buffer's text cannot change inside
--- the callback that sees the edit.
---
---@param buffer integer
local function settle_after_edit(buffer)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buffer) then
      return
    end
    for _, record in pairs(placed[buffer] or {}) do
      if forget_lost(buffer, record) then
        notify(buffer, record.window)
      end
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

--- Shows each of `explanations` in `buffer` as virtual lines above its line
--- (`show_explanation()`) for a window showing it (`geometry_of()`), and
--- keeps them to show again when that window's gutter changes
--- (`keep_aligned()`). Tells the listeners (`on_change()`).
---
---@param buffer integer
---@param window integer the window the explanations were asked in
---@param kind aineo.explain.Kind
---@param explanations aineo.explain.Explanation[]
---@param file string the absolute path of the file they were asked about
function M.place(buffer, window, kind, explanations, file)
  local geometry = geometry_of(buffer, window)
  placed[buffer] = placed[buffer] or {}
  local record = placed[buffer][kind.name]
  if record and record.textoff ~= geometry.textoff then
    record.window = window
    place_again(buffer, record)
  end
  record = record or { kind = kind, texts = {}, files = {}, marked = {}, pending = false }
  record.window, record.textoff = window, geometry.textoff
  placed[buffer][kind.name] = record
  for _, explanation in ipairs(explanations) do
    local id = show_explanation(buffer, {
      kind = kind,
      line = explanation.line,
      text = explanation.text,
    }, geometry)
    record.texts[id] = explanation.text
    record.files[id] = file
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

--- How many issues are marked among those placed for `window`, in any buffer.
---
---@param window integer
---@return integer
function M.marked_count(window)
  local count = 0
  for buffer, records in pairs(placed) do
    local record = records[kinds.ISSUES.name]
    if record and record.window == window and vim.api.nvim_buf_is_valid(buffer) then
      forget_lost(buffer, record)
      count = count + vim.tbl_count(record.marked)
    end
  end
  return count
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
        if not record.pending and geometry_of(buffer, record.window).textoff ~= record.textoff then
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
    indent = indent_of(buffer, line),
    rows = { text },
    geometry = geometry_of(buffer, window),
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
    indent = indent_of(buffer, line),
    rows = { text },
    geometry = geometry_of(buffer, window),
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
