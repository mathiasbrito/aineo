--- How the explain home shows what Claude Code answered: as virtual lines above
--- the lines it is about, in the namespace of the kind of answer
--- (`aineo.explain.Kind`).

local M = {}

--- What starts the text of every virtual line, after the line's indent.
local MARK = '┊ '

--- What marks the gutter of every virtual line.
local GUTTER_MARK = '▎'

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

--- The chunks that fill the columns before the text, `textoff` of them: `▎`,
--- then spaces, and `label` right-aligned with a space after it, cut to the
--- cells left by `▎` and that space, and left out when fewer than
--- `SHORTEST_LABEL` fit; the `▎` and the label in the gutter group
--- of `kind` and the spaces in its fill group; none when there are no such
--- columns.
---
---@param textoff integer
---@param label string
---@param kind aineo.explain.Kind
---@return table[] chunks
local function gutter_chunks(textoff, label, kind)
  if textoff == 0 then
    return {}
  end
  local mark_width = vim.fn.strdisplaywidth(GUTTER_MARK)
  local room = textoff - mark_width - 1
  label = room >= SHORTEST_LABEL and label:sub(1, room) or ''
  local chunks = { { GUTTER_MARK, kind.groups.gutter } }
  local spaces = textoff - mark_width - (label == '' and 0 or #label + 1)
  if spaces > 0 then
    table.insert(chunks, { (' '):rep(spaces), kind.groups.fill })
  end
  if label ~= '' then
    table.insert(chunks, { label, kind.groups.gutter })
    table.insert(chunks, { ' ', kind.groups.fill })
  end
  return chunks
end

--- The virtual line that shows `row`: the gutter (`gutter_chunks()`, with
--- `label`), `indent` unhighlighted, then `MARK` and `row` padded with
--- spaces to the end of the window, in the text group of `kind`.
---
---@param row string
---@param indent string
---@param geometry aineo.explain.Geometry
---@param label string
---@param kind aineo.explain.Kind
---@return table[] chunks
local function band_row(row, indent, geometry, label, kind)
  local body = MARK .. row
  local padding = geometry.width - geometry.textoff - #indent - vim.fn.strdisplaywidth(body)
  local chunks = gutter_chunks(geometry.textoff, label, kind)
  if indent ~= '' then
    table.insert(chunks, { indent })
  end
  table.insert(chunks, { body .. (' '):rep(math.max(padding, 0)), kind.groups.text })
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
---@field id? integer the extmark to set again; a new one when absent

--- Shows `band.rows` in `buffer` as virtual lines above `band.line`, each
--- starting at the window's left column and showing as `band_row()` does.
--- The line's number shows in the number group of the kind. Returns the
--- extmark's id.
---
---@param buffer integer
---@param band aineo.explain.Band
---@return integer
local function show_above(buffer, band)
  local virt_lines = {}
  for number, row in ipairs(band.rows) do
    virt_lines[number] =
      band_row(row, band.indent, band.geometry, number == 1 and band.label or '', band.kind)
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

--- Shows each of `explanations` in `buffer` as virtual lines above its
--- line, indented as that line but by half the window's text width at most,
--- each starting with `MARK`, and the text wrapped (`wrapped()`) at the text
--- width of a window showing it (`geometry_of()`) less that indent, in the
--- look of `kind`.
---
---@param buffer integer
---@param window integer the window the explanations were asked in
---@param kind aineo.explain.Kind
---@param explanations aineo.explain.Explanation[]
function M.place(buffer, window, kind, explanations)
  local geometry = geometry_of(buffer, window)
  local width = geometry.width - geometry.textoff
  for _, explanation in ipairs(explanations) do
    local indent = indent_of(buffer, explanation.line, math.floor(width / 2))
    local room = math.max(width - #indent - vim.fn.strdisplaywidth(MARK), NARROWEST)
    show_above(buffer, {
      kind = kind,
      line = explanation.line,
      indent = indent,
      rows = wrapped(explanation.text, room),
      geometry = geometry,
      label = kind.label,
    })
  end
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
--- lines from `first` to `last`, from 1, when they are given.
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@param first? integer
---@param last? integer
function M.clear(buffer, kind, first, last)
  vim.api.nvim_buf_clear_namespace(buffer, namespace_of(kind), first and first - 1 or 0, last or -1)
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
