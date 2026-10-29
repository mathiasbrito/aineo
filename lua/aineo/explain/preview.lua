--- The preview of a proposed fix, or of code written for a request: an
--- overlay on the buffer, which stays untouched until it is accepted. The
--- old lines of each edit are hidden and its new lines drawn as virtual
--- lines in their place.

local draw = require('aineo.explain.draw')
local kinds = require('aineo.explain.kinds')

local M = {}

--- The namespace of the marks that track each edit's old lines.
local RANGES = vim.api.nvim_create_namespace('aineo_explain_fix_preview')

--- The namespace of the marks that draw the preview, made again at each
--- drawing.
local DRAWN = vim.api.nvim_create_namespace('aineo_explain_fix_drawn')

--- The 'conceallevel' that hides the old lines, at least.
local CONCEALING = 2

--- An edit as the preview shows it.
---@class aineo.explain.ShownEdit
---@field mark integer the extmark spanning its old lines, from the start of the first to the start of the line after the last
---@field old string[]
---@field new string[]
---@field why string
---@field stale? boolean whether its old lines no longer stand in the buffer, as when it was last drawn, for an edit that is a proposal of its own
---@field diff? boolean whether it shows as the diff view, for an edit that is a proposal of its own

--- The options of a window that hide a preview's old lines, as they were.
---@class aineo.explain.ConcealOptions
---@field conceallevel integer
---@field concealcursor string

--- A preview shown in a buffer.
---@class aineo.explain.Preview
---@field buffer integer
---@field window integer the window the fix was asked in
---@field summary string
---@field keys? aineo.explain.FixKeys the keys to map for it; none when absent
---@field mapped table<string, boolean> the actions it mapped a key for in its buffer
---@field diff boolean whether it shows as the diff view
---@field edits aineo.explain.ShownEdit[] in the order of their lines
---@field separate boolean whether each edit is a proposal of its own, decided apart from the others
---@field subject_edit? aineo.explain.ShownEdit the edit its subject is shown above, until it is decided
---@field chosen? aineo.explain.ShownEdit the edit last moved to (`jump()`), until it is decided
---@field saved table<integer, aineo.explain.ConcealOptions> the options of each window it set, before it set them
---@field set table<integer, aineo.explain.ConcealOptions> the options it set in each window
---@field modifiable boolean the buffer's 'modifiable' before it, which it turns off while shown
---@field ask_key string what asks the fix or the code again, as the user is told it
---@field subject aineo.explain.Subject what it is proposed for
---@field kind aineo.explain.Kind what it is, a fix or written code, which names it in its head row and its messages
---@field stale boolean whether its edits no longer stand in the buffer, as when it was last drawn
---@field first_row integer the line, from 0, its first edit started on when it was last drawn
---@field lead_line? integer the line, from 1, above which its first row was drawn when it was last drawn, as Neovim's filler lines of that line; `nil` when it was drawn after the buffer's last line
---@field redraw_pending? boolean whether a drawing again is scheduled (`redraw_lost()`)

--- The keys a preview maps in its buffer, each a left-hand side as
--- `vim.keymap.set()` takes it; those of a preview whose edits are
--- proposals of their own (`separate`) are mapped for it alone.
---@class aineo.explain.FixKeys
---@field accept string
---@field reject string
---@field diff string
---@field accept_all? string
---@field reject_all? string
---@field next? string
---@field previous? string

--- The preview each buffer shows.
---@type table<integer, aineo.explain.Preview>
local previews = {}

--- The style the fix's rows are drawn in.
---@type aineo.explain.Style
local FIX_STYLE = {
  gutter_mark = draw.GUTTER_MARK,
  text = kinds.FIX.groups.text,
  gutter = kinds.FIX.groups.gutter,
  fill = kinds.FIX.groups.fill,
}

--- What a proposal is made for, shown at the top of its overlay: its text
--- and the look it is drawn in, whose label names it in the gutter.
---@class aineo.explain.Subject
---@field text string
---@field look aineo.explain.Look

--- The style the subject of a proposal is drawn in at the top of its
--- overlay: the band of its look.
---
---@param subject aineo.explain.Subject
---@return aineo.explain.Style
local function subject_style(subject)
  return {
    gutter_mark = draw.GUTTER_MARK,
    text = subject.look.groups.text,
    gutter = subject.look.groups.gutter,
    fill = subject.look.groups.fill,
  }
end

--- The style the fix explanation's rows are drawn in.
---@type aineo.explain.Style
local WHY_STYLE = {
  gutter_mark = draw.GUTTER_MARK,
  text = kinds.FIX_WHY.groups.text,
  gutter = kinds.FIX_WHY.groups.gutter,
  fill = kinds.FIX_WHY.groups.fill,
}

--- The virtual line that shows `text`, a new line of an edit, after the
--- gutter of a window whose text starts `textoff` columns in, padded to its
--- width.
---
---@param text string
---@param geometry aineo.explain.Geometry
---@return table[] chunks
local function new_line_row(text, geometry)
  local chunks = draw.gutter(geometry.textoff, '', FIX_STYLE)
  local padding = geometry.width - geometry.textoff - vim.fn.strdisplaywidth(text)
  table.insert(chunks, { text .. (' '):rep(math.max(padding, 0)), FIX_STYLE.text })
  return chunks
end

--- What names `action` of `preview` to the user: the key it mapped for it
--- in its buffer, or the `<Plug>` mapping of its kind
--- (`aineo.explain.kinds`' `plugs`) when it mapped none for it, the key
--- being the user's or none being given.
---
---@param preview aineo.explain.Preview
---@param action aineo.explain.Action
---@return string
local function named_key(preview, action)
  return preview.mapped[action] and preview.keys[action] or preview.kind.plugs[action]
end

--- What a head row of `preview` says of the decision: that its buffer is
--- read-only until it is accepted or rejected, while its 'modifiable' is
--- off, and what accepts it, rejects it and shows its diff (`named_key()`);
--- for what is `stale`, what its kind says when the code under it changed
--- (`aineo.explain.kinds`' `changed`), what rejects it and what asks again.
---
---@param preview aineo.explain.Preview
---@param stale boolean
---@return string
local function decision_text(preview, stale)
  if stale then
    return ('%s · %s rejects · %s asks again'):format(
      preview.kind.changed,
      named_key(preview, 'reject'),
      preview.ask_key
    )
  end
  local keys = (
    vim.bo[preview.buffer].modifiable and '%s accepts · %s rejects'
    or 'read-only until %s accepts or %s rejects'
  ):format(named_key(preview, 'accept'), named_key(preview, 'reject'))
  return ('%s · %s shows the diff'):format(keys, named_key(preview, 'diff'))
end

--- What the head row of `preview` says (`decision_text()`); for a preview
--- whose edits are proposals of their own, what the head row of its edit
--- `index` says: its kind's label and its place among them (`write 2/3`),
--- the decision, then, but for a stale edit, what moves to the next and the
--- previous one and what accepts and rejects them all.
---
---@param preview aineo.explain.Preview
---@param index integer
---@return string
local function head_text(preview, index)
  if not preview.separate then
    return decision_text(preview, preview.stale)
  end
  local edit = preview.edits[index]
  local text = ('%s %d/%d · %s'):format(
    preview.kind.label,
    index,
    #preview.edits,
    decision_text(preview, edit.stale == true)
  )
  if edit.stale then
    return text
  end
  return ('%s · %s %s move · %s accepts all · %s rejects all'):format(
    text,
    named_key(preview, 'next'),
    named_key(preview, 'previous'),
    named_key(preview, 'accept_all'),
    named_key(preview, 'reject_all')
  )
end

--- `texts`, each wrapped at the text width of `geometry`, as rows of a band
--- in `style`, `label` in the gutter of the first.
---
---@param texts string[]
---@param geometry aineo.explain.Geometry
---@param label string
---@param style aineo.explain.Style
---@return table[][]
local function band_rows(texts, geometry, label, style)
  local width = math.max(geometry.width - geometry.textoff - vim.fn.strdisplaywidth(draw.MARK), 1)
  local wrapped = {}
  for _, text in ipairs(texts) do
    vim.list_extend(wrapped, draw.wrapped(text, width))
  end
  local rows = {}
  for number, text in ipairs(wrapped) do
    rows[number] = draw.row(text, '', geometry, number == 1 and label or '', style)
  end
  return rows
end

--- The first and last line, from 0, of each edit of `preview` now, read
--- from the extmark that spans its old lines, in the order of the edits;
--- `nil` when an extmark is gone, as when another plugin clears every
--- namespace of the buffer.
---
---@param preview aineo.explain.Preview
---@return { first: integer, last: integer }[]|nil
local function spans_of(preview)
  local spans = {}
  for index, edit in ipairs(preview.edits) do
    local mark = vim.api.nvim_buf_get_extmark_by_id(preview.buffer, RANGES, edit.mark, {
      details = true,
    })
    if not mark[1] then
      return nil
    end
    spans[index] = { first = mark[1], last = mark[3].end_row - 1 }
  end
  return spans
end

--- The lines of `buffer` that `span` spans, from 0.
---
---@param buffer integer
---@param span { first: integer, last: integer }
---@return string[]
local function lines_of(buffer, span)
  return vim.api.nvim_buf_get_lines(buffer, span.first, span.last + 1, false)
end

--- Whether the edits of `preview` still stand at `spans`, the lines each
--- spans now (`spans_of()`): every edit's old lines are, byte for byte and
--- in number, the lines it spans, and the edits stand in the order they
--- were placed in, none sharing a line with the next.
---
---@param preview aineo.explain.Preview
---@param spans { first: integer, last: integer }[]
---@return boolean
local function stands(preview, spans)
  for index, span in ipairs(spans) do
    if not vim.deep_equal(lines_of(preview.buffer, span), preview.edits[index].old) then
      return false
    end
    if index > 1 and span.first <= spans[index - 1].last then
      return false
    end
  end
  return true
end

--- The lines each edit of `preview` spans now (`spans_of()`), when its
--- edits still stand there (`stands()`); `nil` when they do not, or when an
--- extmark is gone.
---
---@param preview aineo.explain.Preview
---@return { first: integer, last: integer }[]|nil
local function standing_spans(preview)
  local spans = spans_of(preview)
  return spans and stands(preview, spans) and spans or nil
end

--- Whether `preview` is stale: an extmark of its edits is gone, or its
--- edits no longer stand at `spans`, the lines each spans now (`stands()`).
---
---@param preview aineo.explain.Preview
---@param spans { first: integer, last: integer }[]|nil `spans_of(preview)`
---@return boolean
local function is_stale(preview, spans)
  return not (spans and stands(preview, spans))
end

--- The head row of `preview`, or of its edit `index` (`head_text()`), as a
--- band labelled with its kind's label, in a window of `geometry`
--- (`band_rows()`).
---
---@param preview aineo.explain.Preview
---@param index integer
---@param geometry aineo.explain.Geometry
---@return table[][]
local function head_rows(preview, index, geometry)
  return band_rows({ head_text(preview, index) }, geometry, preview.kind.label, FIX_STYLE)
end

--- The virtual lines drawn before the new lines of the edit `index` of
--- `preview` in a window of `geometry` (`band_rows()`): for the first edit,
--- or for each when its edits are proposals of their own, the head
--- (`head_rows()`); then the edit's fix explanation (`aineo.explain.kinds`'
--- `FIX_WHY`), the summary first, then the edit's why, labelled `why`.
---
---@param preview aineo.explain.Preview
---@param index integer
---@param geometry aineo.explain.Geometry
---@return table[][]
local function lead_rows(preview, index, geometry)
  local rows = {}
  if index == 1 or preview.separate then
    rows = head_rows(preview, index, geometry)
  end
  local why = { preview.summary, preview.edits[index].why }
  return vim.list_extend(rows, band_rows(why, geometry, kinds.FIX_WHY.label, WHY_STYLE))
end

--- The virtual lines that show the new lines of `edit` in a window of
--- `geometry` (`new_line_row()`).
---
---@param edit aineo.explain.ShownEdit
---@param geometry aineo.explain.Geometry
---@return table[][]
local function new_rows(edit, geometry)
  return vim.tbl_map(function(line)
    return new_line_row(line, geometry)
  end, edit.new)
end

--- The places of a buffer where virtual lines are drawn, each below or above
--- a line, with the rows drawn there, in the order they were added. One
--- extmark draws every row of a place: Neovim draws the virtual lines of
--- several extmarks at one place in no order it promises.
---@class aineo.explain.Places
---@field order string[] the keys of the places, in the order first added
---@field rows table<string, { row: integer, above: boolean, rows: table[][] }>
---@field lead? string the key of the place whose first rows are brought into view; the place first added when absent

--- Adds `rows` to what is drawn below line `row`, from 0, or above it, and
--- returns the key of that place.
---
---@param places aineo.explain.Places
---@param row integer
---@param above boolean
---@param rows table[][]
---@return string
local function add_rows(places, row, above, rows)
  local key = row .. (above and 'above' or 'below')
  if not places.rows[key] then
    places.rows[key] = { row = row, above = above, rows = {} }
    table.insert(places.order, key)
  end
  vim.list_extend(places.rows[key].rows, rows)
  return key
end

--- The column the extmarks that draw a preview's rows are set at: after
--- those of the answers (`aineo.explain.kinds`), which a line's virtual
--- lines above it then show before.
local AFTER_ANSWERS_COLUMN = 2

--- Draws every place of `places` in `buffer`, one extmark each.
---
---@param buffer integer
---@param places aineo.explain.Places
local function draw_places(buffer, places)
  for _, key in ipairs(places.order) do
    local place = places.rows[key]
    vim.api.nvim_buf_set_extmark(buffer, DRAWN, place.row, AFTER_ANSWERS_COLUMN, {
      virt_lines = place.rows,
      virt_lines_above = place.above,
      virt_lines_leftcol = true,
      strict = false,
    })
  end
end

--- The buffer's first line, from 0. Neovim shows the virtual lines above it
--- only in a window scrolled up to them, which a window showing the buffer
--- from its top is not.
local FIRST_ROW = 0

--- Adds `rows` to what is drawn above line `row`, from 0, or below it when
--- it is the first line (`FIRST_ROW`), whose rows above are not seen.
---
---@param places aineo.explain.Places
---@param row integer
---@param rows table[][]
---@return string key the key of the place
local function add_rows_above_or_first(places, row, rows)
  return add_rows(places, row, row ~= FIRST_ROW, rows)
end

--- Adds to `places` the edit `index` of `preview`, spanning the lines of
--- `span`, as the diff view shows it: its old lines stay, struck through
--- (`AineoFixOld`), its head and explanation (`lead_rows()`) above them,
--- after what the answers show above its first line, and its new lines
--- below them, or after its explanation when no line is left in `span`, as
--- in a stale preview whose old lines were deleted. An edit that starts on
--- the buffer's first line (`FIRST_ROW`) has its head and explanation
--- below its old lines instead, before its new lines, where they are seen.
--- Returns the key of the place its head and explanation are drawn at.
---
---@param preview aineo.explain.Preview
---@param index integer
---@param span { first: integer, last: integer }
---@param geometry aineo.explain.Geometry
---@param places aineo.explain.Places
---@return string
local function add_diff(preview, index, span, geometry, places)
  vim.api.nvim_buf_set_extmark(preview.buffer, DRAWN, span.first, 0, {
    end_row = span.last + 1,
    end_col = 0,
    hl_group = kinds.FIX.struck.group,
    strict = false,
  })
  local lead = lead_rows(preview, index, geometry)
  local new = new_rows(preview.edits[index], geometry)
  if span.last < span.first then
    return add_rows_above_or_first(places, span.first, vim.list_extend(lead, new))
  elseif span.first == FIRST_ROW then
    return add_rows(places, span.last, false, vim.list_extend(lead, new))
  end
  local key = add_rows(places, span.first, true, lead)
  add_rows(places, span.last, false, new)
  return key
end

--- The edits `indexes` of a preview grouped in blocks of edits that touch,
--- one ending on the line before the next starts, each block the indexes of
--- its edits and the lines it spans, from 0.
---
---@param spans { first: integer, last: integer }[] the lines of each edit, in order
---@param indexes integer[] the edits to group, in order
---@return { indexes: integer[], first: integer, last: integer }[]
local function blocks_of(spans, indexes)
  local blocks = {}
  for _, index in ipairs(indexes) do
    local span = spans[index]
    local block = blocks[#blocks]
    if block and span.first == block.last + 1 then
      table.insert(block.indexes, index)
      block.last = span.last
    else
      table.insert(blocks, { indexes = { index }, first = span.first, last = span.last })
    end
  end
  return blocks
end

--- Adds to `places` the edits of `block` as the overlay shows them: their
--- old lines hidden, which hides what is shown above them, the issue a
--- fix fixes among it, and their rows — first, for the edit its subject is
--- shown above (`subject_edit`), the preview's subject in its look, labelled as the look is (the issue's
--- text, labelled `issue`, or the request code is written for); then each
--- edit's head and explanation (`lead_rows()`), then its new lines — below
--- the line before the block, else above the line after it. A block that spans the whole buffer has no
--- line to hang them on and shows as the diff view does (`add_diff()`).
--- Returns the key of the place the rows of its first edit are drawn at.
---
---@param preview aineo.explain.Preview
---@param block { indexes: integer[], first: integer, last: integer }
---@param spans { first: integer, last: integer }[]
---@param geometry aineo.explain.Geometry
---@param places aineo.explain.Places
---@return string
local function add_overlay(preview, block, spans, geometry, places)
  local buffer = preview.buffer
  local line_count = vim.api.nvim_buf_line_count(buffer)
  if block.first == 0 and block.last == line_count - 1 then
    local keys = vim.tbl_map(function(index)
      return add_diff(preview, index, spans[index], geometry, places)
    end, block.indexes)
    return keys[1]
  end
  local rows = {}
  for _, index in ipairs(block.indexes) do
    if preview.edits[index] == preview.subject_edit then
      local subject = preview.subject
      vim.list_extend(
        rows,
        band_rows({ subject.text }, geometry, subject.look.label, subject_style(subject))
      )
    end
    vim.list_extend(rows, lead_rows(preview, index, geometry))
    vim.list_extend(rows, new_rows(preview.edits[index], geometry))
  end
  vim.api.nvim_buf_set_extmark(buffer, DRAWN, block.first, 0, {
    end_row = block.last,
    end_col = #vim.api.nvim_buf_get_lines(buffer, block.last, block.last + 1, true)[1],
    conceal_lines = '',
  })
  if block.first > 0 then
    return add_rows(places, block.first - 1, false, rows)
  end
  return add_rows(places, block.last + 1, true, rows)
end

--- The line, from 1, whose filler lines, the virtual lines Neovim draws
--- above it, start with the first rows of `places` (its `lead`, else the
--- place first added): the line a place above a line hangs on, or the line
--- after the one a place below a line hangs on; `nil` when that is past the
--- last of the buffer's `line_count` lines.
---
---@param places aineo.explain.Places
---@param line_count integer
---@return integer|nil
local function lead_line_of(places, line_count)
  local place = places.rows[places.lead or places.order[1]]
  local line = place.row + (place.above and 1 or 2)
  return line <= line_count and line or nil
end

--- Adds to `places` the edits of `preview`, proposals of their own, each
--- spanning the lines of `spans`, marking each stale when its old lines no
--- longer stand there, and not when they stand again: a stale one, or one
--- shown as the diff view (`diff`), as the diff view does (`add_diff()`),
--- the others as the overlay does, in blocks of those that touch
--- (`add_overlay()`). The place of the edit its subject is shown above
--- (`subject_edit`), the edit asked at the cursor, is the lead of `places`,
--- the one brought into view.
---
---@param preview aineo.explain.Preview
---@param spans { first: integer, last: integer }[]
---@param geometry aineo.explain.Geometry
---@param places aineo.explain.Places
local function add_proposals(preview, spans, geometry, places)
  local overlaid = {}
  for index, span in ipairs(spans) do
    local edit = preview.edits[index]
    edit.stale = not vim.deep_equal(lines_of(preview.buffer, span), edit.old)
    if edit.stale or edit.diff then
      local key = add_diff(preview, index, span, geometry, places)
      places.lead = edit == preview.subject_edit and key or places.lead
    else
      table.insert(overlaid, index)
    end
  end
  for _, block in ipairs(blocks_of(spans, overlaid)) do
    local key = add_overlay(preview, block, spans, geometry, places)
    local holds_the_subject = vim.iter(block.indexes):any(function(index)
      return preview.edits[index] == preview.subject_edit
    end)
    places.lead = holds_the_subject and key or places.lead
  end
end

--- Draws `preview` as it shows now, marking it stale when its edits no
--- longer stand (`stands()`), and not when they stand again: the overlay,
--- its edits' old lines hidden and their rows in their place
--- (`add_overlay()`), or the diff view (`add_diff()`), which a stale preview
--- always shows, so that the code as it reads now is seen; each edit as a
--- proposal of its own, stale or not, when they are (`add_proposals()`).
--- When an extmark of its edits is gone, it is stale, every edit with it,
--- and only its head row is drawn, above the line its first edit last
--- started on, or below it when that is the buffer's first line
--- (`add_rows_above_or_first()`).
---
---@param preview aineo.explain.Preview
local function render(preview)
  local buffer = preview.buffer
  vim.api.nvim_buf_clear_namespace(buffer, DRAWN, 0, -1)
  local geometry = draw.geometry_of(buffer, preview.window)
  local spans = spans_of(preview)
  preview.stale = is_stale(preview, spans)
  local places = { order = {}, rows = {} }
  if not spans then
    for _, edit in ipairs(preview.edits) do
      edit.stale = true
    end
    local row = math.min(preview.first_row, vim.api.nvim_buf_line_count(buffer) - 1)
    add_rows_above_or_first(places, row, head_rows(preview, 1, geometry))
  elseif preview.separate then
    preview.first_row = spans[1].first
    add_proposals(preview, spans, geometry, places)
  elseif preview.diff or preview.stale then
    preview.first_row = spans[1].first
    for index, span in ipairs(spans) do
      add_diff(preview, index, span, geometry, places)
    end
  else
    preview.first_row = spans[1].first
    for _, block in ipairs(blocks_of(spans, vim.fn.range(1, #spans))) do
      add_overlay(preview, block, spans, geometry, places)
    end
  end
  draw_places(buffer, places)
  preview.lead_line = lead_line_of(places, vim.api.nvim_buf_line_count(buffer))
end

--- The namespace of the decoration provider that notices a preview's
--- drawing lost (`redraw_lost()`).
local REDRAW = vim.api.nvim_create_namespace('aineo_explain_fix_redraw')

--- Whether `preview` is no longer drawn as it stands: nothing of it is
--- drawn, or it is drawn as standing while its edits' extmarks are gone, as
--- when another plugin clears namespaces, which changes no line.
---
---@param preview aineo.explain.Preview
---@return boolean
local function drawing_lost(preview)
  local drawn = #vim.api.nvim_buf_get_extmarks(preview.buffer, DRAWN, 0, -1, { limit = 1 }) > 0
  return not (drawn and (preview.stale or spans_of(preview)))
end

--- Draws again (`render()`), once the event loop has turned, the preview of
--- `buffer` when a window showing it is redrawn and its drawing was lost
--- (`drawing_lost()`); once for each loss. As a decoration provider's
--- `on_win`, it returns `false`: it draws nothing in that redraw.
---
---@param buffer integer
---@return boolean
local function redraw_lost(_, _, buffer)
  local preview = previews[buffer]
  if preview and not preview.redraw_pending and drawing_lost(preview) then
    preview.redraw_pending = true
    vim.schedule(function()
      preview.redraw_pending = nil
      if previews[buffer] == preview and vim.api.nvim_buf_is_loaded(buffer) then
        render(preview)
      end
    end)
  end
  return false
end

--- Has the windows' redraws checked for a lost drawing (`redraw_lost()`)
--- while `watching`, and not otherwise: while a fix shows, and only then.
---
---@param watching boolean
local function watch_drawings(watching)
  vim.api.nvim_set_decoration_provider(REDRAW, watching and { on_win = redraw_lost } or {})
end

--- Whether the first of the filler lines of `line`, from 1, is on the
--- screen of `window`: `line` is below the window's top line and the rows
--- before that filler line fit in the window's height, or `line` is its top
--- line and the window shows every filler line of it ('topfill').
---
---@param window integer
---@param line integer
---@return boolean
local function lead_row_seen(window, line)
  local view = vim.api.nvim_win_call(window, vim.fn.winsaveview)
  local function height_of(first, last)
    return vim.api.nvim_win_text_height(window, { start_row = first - 1, end_row = last - 1 })
  end
  if view.topline > line then
    return false
  end
  if view.topline == line then
    return view.topfill >= height_of(line, line).fill
  end
  local unseen_above_top = height_of(view.topline, view.topline).fill - view.topfill
  local rows_before = height_of(view.topline, line - 1).all - unseen_above_top
  return rows_before < vim.api.nvim_win_get_height(window)
end

--- Brings the first row of `preview` into view in every window that shows
--- its buffer and does not show that row (`lead_row_seen()`): the window
--- shows the line it was drawn above at its top, with every filler line of
--- it ('topfill'), as far as Neovim keeps the cursor's line on the screen;
--- the cursor stays where it is. When Neovim, keeping the cursor's line on
--- the screen (`line('w0')`), moves that line from the top and the row is
--- still not shown, as for a cursor far from the preview, the window's view
--- is given back as it was. A window that shows that row is left as it is,
--- and so is every window of a preview drawn after the buffer's last line,
--- which follows that line.
---
---@param preview aineo.explain.Preview
local function bring_into_view(preview)
  local line = preview.lead_line
  if not line then
    return
  end
  for _, window in ipairs(vim.fn.win_findbuf(preview.buffer)) do
    if not lead_row_seen(window, line) then
      vim.api.nvim_win_call(window, function()
        local before = vim.fn.winsaveview()
        vim.fn.winrestview({
          topline = line,
          topfill = vim.api.nvim_win_text_height(window, {
            start_row = line - 1,
            end_row = line - 1,
          }).fill,
        })
        if vim.fn.line('w0') ~= line and not lead_row_seen(window, line) then
          vim.fn.winrestview(before)
        end
      end)
    end
  end
end

--- The options of `window` that hide old lines, its own for the buffer it
--- shows, as `:setlocal` sees them.
---
---@param window integer
---@return aineo.explain.ConcealOptions
local function conceal_options_of(window)
  local scope = { win = window, scope = 'local' }
  return {
    conceallevel = vim.api.nvim_get_option_value('conceallevel', scope),
    concealcursor = vim.api.nvim_get_option_value('concealcursor', scope),
  }
end

--- Sets `options` as `window`'s own for the buffer it shows, as `:setlocal`
--- does, so that another buffer the window comes to show keeps its own.
---
---@param window integer
---@param options aineo.explain.ConcealOptions
local function set_conceal_options(window, options)
  local scope = { win = window, scope = 'local' }
  vim.api.nvim_set_option_value('conceallevel', options.conceallevel, scope)
  vim.api.nvim_set_option_value('concealcursor', options.concealcursor, scope)
end

--- Has `window` hide `preview`'s old lines: a 'conceallevel' of at least
--- `CONCEALING`, and an `n` in 'concealcursor' so that they are hidden in
--- Normal mode on the cursor's line too. Keeps `before` as the options to
--- give it back, once for each window.
---
---@param preview aineo.explain.Preview
---@param window integer
---@param before aineo.explain.ConcealOptions
local function conceal_in(preview, window, before)
  if preview.saved[window] then
    return
  end
  preview.saved[window] = before
  local options = conceal_options_of(window)
  local cursor = options.concealcursor
  preview.set[window] = {
    conceallevel = math.max(options.conceallevel, CONCEALING),
    concealcursor = cursor:find('n', 1, true) and cursor or cursor .. 'n',
  }
  set_conceal_options(window, preview.set[window])
end

--- Has every window that shows `preview`'s buffer hide its old lines
--- (`conceal_in()`), each keeping its own options to get back.
---
---@param preview aineo.explain.Preview
local function conceal_in_windows(preview)
  for _, window in ipairs(vim.fn.win_findbuf(preview.buffer)) do
    conceal_in(preview, window, conceal_options_of(window))
  end
end

--- The options the buffer of `preview` had, before it, in a window: the
--- window the fix was asked in, else another it hid the old lines in, else
--- `window`'s own.
---
---@param preview aineo.explain.Preview
---@param window integer
---@return aineo.explain.ConcealOptions
local function buffer_options(preview, window)
  local _, any_saved = next(preview.saved)
  return preview.saved[preview.window] or any_saved or conceal_options_of(window)
end

--- What a buffer's fix that went left behind in the windows that showed it
--- and showed another buffer when it went: Neovim keeps, for each window
--- and buffer, the options the window had when the buffer left it, so such
--- a window, and a window that takes its options from it, would come back
--- to the buffer with the options the fix set.
---@class aineo.explain.LeftBehind
---@field windows table<integer, aineo.explain.ConcealOptions> each window that left, with the options it had before the fix
---@field set aineo.explain.ConcealOptions[] the options the fix set in them
---@field base aineo.explain.ConcealOptions the options the buffer had where the fix was asked

--- What each buffer's fixes left behind (`aineo.explain.LeftBehind`), by
--- buffer, while a window it lists has not come back.
---@type table<integer, aineo.explain.LeftBehind>
local left_behind = {}

--- Gives every window whose options `preview` set, and that still shows its
--- buffer, the options it had; a window gone is passed over, and one that
--- shows another buffer, whose own options are not touched, is left behind
--- (`left_behind`), with those an earlier fix left behind, to get its
--- options back when it comes back.
---
---@param preview aineo.explain.Preview
local function restore_windows(preview)
  local behind = left_behind[preview.buffer]
    or { windows = {}, set = {}, base = buffer_options(preview, preview.window) }
  for window, options in pairs(preview.saved) do
    if vim.api.nvim_win_is_valid(window) then
      if vim.api.nvim_win_get_buf(window) == preview.buffer then
        set_conceal_options(window, options)
      else
        behind.windows[window] = options
        table.insert(behind.set, preview.set[window])
      end
    end
  end
  left_behind[preview.buffer] = next(behind.windows) and behind or nil
end

--- Gives the current window, which starts showing a buffer whose fix went
--- while windows that showed it showed another (`left_behind`), the options
--- it had there before the fix when it is one of them; else, when it shows
--- the buffer with options a fix set, as a window takes them from another,
--- the options the buffer had. Forgets the buffer once every window it
--- left behind came back.
---
---@param window integer
---@param buffer integer
local function restore_left_behind(window, buffer)
  local behind = left_behind[buffer]
  if behind.windows[window] then
    set_conceal_options(window, behind.windows[window])
    behind.windows[window] = nil
  elseif
    vim.iter(behind.set):any(function(set)
      return vim.deep_equal(set, conceal_options_of(window))
    end)
  then
    set_conceal_options(window, behind.base)
  end
  if not next(behind.windows) then
    left_behind[buffer] = nil
  end
end

--- Has the current window hide the old lines of the preview its buffer
--- shows, if any, when it starts showing it: it gets back the options the
--- buffer had (`buffer_options()`), as a window would that came to show the
--- buffer without the preview. With no preview shown, gives back what a fix
--- that went left behind there (`restore_left_behind()`).
local function conceal_in_current_window()
  local window = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_win_get_buf(window)
  local preview = previews[buffer]
  if preview then
    conceal_in(preview, window, buffer_options(preview, window))
  elseif left_behind[buffer] then
    restore_left_behind(window, buffer)
  end
end

vim.api.nvim_create_autocmd({ 'WinNew', 'BufWinEnter' }, {
  group = vim.api.nvim_create_augroup('aineo_explain_fix_preview', {}),
  desc = 'aineo: hide the old lines of a fix in a window that comes to show them',
  callback = conceal_in_current_window,
})

--- Gives a window that closes while it shows a preview's buffer the
--- options it had there before the preview, before Neovim keeps them for
--- the buffer and a later window takes them; `WinClosed` runs before that.
---
---@param window integer
local function restore_closing_window(window)
  for _, preview in pairs(previews) do
    local before = preview.saved[window]
    if
      before
      and vim.api.nvim_win_is_valid(window)
      and vim.api.nvim_win_get_buf(window) == preview.buffer
    then
      set_conceal_options(window, before)
      preview.saved[window] = nil
    end
  end
end

vim.api.nvim_create_autocmd('OptionSet', {
  group = 'aineo_explain_fix_preview',
  pattern = 'modifiable',
  desc = "aineo: say in a fix's head row whether its buffer is read-only",
  callback = function()
    local preview = previews[vim.api.nvim_get_current_buf()]
    if preview then
      render(preview)
    end
  end,
})

vim.api.nvim_create_autocmd('WinClosed', {
  group = 'aineo_explain_fix_preview',
  desc = 'aineo: give a window that closes while a fix shows its options back',
  callback = function(event)
    restore_closing_window(tonumber(event.match))
  end,
})

vim.api.nvim_create_autocmd('BufDelete', {
  group = 'aineo_explain_fix_preview',
  desc = 'aineo: remove the fix of a buffer deleted, which it does not come back with',
  callback = function(event)
    M.clear(event.buf)
  end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
  group = 'aineo_explain_fix_preview',
  desc = 'aineo: forget what a fix left behind in the windows of a buffer wiped out',
  callback = function(event)
    left_behind[event.buf] = nil
  end,
})

--- The `desc` of the keys a preview maps, which tells them from the user's.
local KEYS_DESCRIPTION = 'aineo: a key of the proposal shown'

--- What a key of a preview does to it, or to the edit chosen when its
--- edits are proposals of their own.
---@alias aineo.explain.Action 'accept'|'reject'|'diff'|'accept_all'|'reject_all'|'next'|'previous'

--- The actions of a preview's keys.
---@type aineo.explain.Action[]
local ACTIONS = { 'accept', 'reject', 'diff' }

--- The actions of the keys of a preview whose edits are proposals of their
--- own: `ACTIONS`, then those that act on them all and move between them.
---@type aineo.explain.Action[]
local SEPARATE_ACTIONS =
  { 'accept', 'reject', 'diff', 'accept_all', 'reject_all', 'next', 'previous' }

--- Each key of `preview` (`aineo.explain.FixKeys`) with its action and the
--- `<Plug>` mapping of its kind it is mapped to (`aineo.explain.kinds`'
--- `plugs`): those of `ACTIONS`, or of `SEPARATE_ACTIONS` for a preview
--- whose edits are proposals of their own, each that `preview.keys` gives.
---
---@param preview aineo.explain.Preview
---@return { action: string, key: string, plug: string }[]
local function key_mappings(preview)
  local found = {}
  for _, action in ipairs(preview.separate and SEPARATE_ACTIONS or ACTIONS) do
    if preview.keys[action] then
      table.insert(found, {
        action = action,
        key = preview.keys[action],
        plug = preview.kind.plugs[action],
      })
    end
  end
  return found
end

--- Maps in Normal mode, for `preview`'s buffer alone, each of its keys to
--- the `<Plug>` mapping that does what it says, but a key already mapped
--- there, locally or globally: the user's. Records in `preview.mapped` the
--- actions it mapped a key for.
---
---@param preview aineo.explain.Preview
local function map_keys(preview)
  if not preview.keys then
    return
  end
  for _, mapping in ipairs(key_mappings(preview)) do
    local taken = vim.api.nvim_buf_call(preview.buffer, function()
      return next(vim.fn.maparg(mapping.key, 'n', false, true)) ~= nil
    end)
    if not taken then
      vim.keymap.set('n', mapping.key, mapping.plug, {
        buffer = preview.buffer,
        remap = true,
        desc = KEYS_DESCRIPTION,
      })
      preview.mapped[mapping.action] = true
    end
  end
end

--- Removes the keys `map_keys()` mapped for `preview`'s buffer, told by
--- their `desc`: a key the user mapped stays.
---
---@param preview aineo.explain.Preview
local function unmap_keys(preview)
  if not preview.keys or not vim.api.nvim_buf_is_valid(preview.buffer) then
    return
  end
  for _, mapping in ipairs(key_mappings(preview)) do
    local ours = vim.api.nvim_buf_call(preview.buffer, function()
      local found = vim.fn.maparg(mapping.key, 'n', false, true)
      return found.buffer == 1 and found.desc == KEYS_DESCRIPTION
    end)
    if ours then
      vim.keymap.del('n', mapping.key, { buffer = preview.buffer })
    end
  end
end

--- Removes the preview `buffer` shows, if any, leaving the buffer as it
--- reads, its 'modifiable' and every window's options as they were before
--- it.
---
---@param buffer integer
function M.clear(buffer)
  local preview = previews[buffer]
  if not preview then
    return
  end
  previews[buffer] = nil
  restore_windows(preview)
  unmap_keys(preview)
  if vim.api.nvim_buf_is_valid(buffer) then
    vim.bo[buffer].modifiable = preview.modifiable
    vim.api.nvim_buf_clear_namespace(buffer, DRAWN, 0, -1)
    vim.api.nvim_buf_clear_namespace(buffer, RANGES, 0, -1)
  end
  if not next(previews) then
    watch_drawings(false)
  end
end

--- Whether `buffer` shows a preview.
---
---@param buffer integer
---@return boolean
function M.is_shown(buffer)
  return previews[buffer] ~= nil
end

--- The kind of the preview `buffer` shows (`aineo.explain.kinds`' `FIX` or
--- `WRITE`), and what accepts it, rejects it and shows its diff, as its
--- head row names them (`named_key()`); `nil` when it shows none.
---
---@param buffer integer
---@return aineo.explain.Kind|nil kind
---@return aineo.explain.FixKeys|nil keys
function M.shown(buffer)
  local preview = previews[buffer]
  if not preview then
    return nil
  end
  return preview.kind,
    {
      accept = named_key(preview, 'accept'),
      reject = named_key(preview, 'reject'),
      diff = named_key(preview, 'diff'),
    }
end

--- Whether the new lines of `edit` start with its old lines, unchanged: it
--- then only adds lines after them.
---
---@param edit aineo.explain.ShownEdit
---@return boolean
local function keeps_its_old_lines(edit)
  return #edit.new >= #edit.old and vim.deep_equal(vim.list_slice(edit.new, 1, #edit.old), edit.old)
end

--- Applies `edit`, spanning the lines of `span` in `buffer`: an edit that
--- keeps its old lines (`keeps_its_old_lines()`) inserts the rest of its
--- new lines after them, leaving them, their marks and their extmarks
--- untouched; any other replaces its old lines by its new lines.
---
---@param buffer integer
---@param edit aineo.explain.ShownEdit
---@param span { first: integer, last: integer }
local function apply_edit(buffer, edit, span)
  if keeps_its_old_lines(edit) then
    local added = vim.list_slice(edit.new, #edit.old + 1)
    vim.api.nvim_buf_set_lines(buffer, span.last + 1, span.last + 1, true, added)
    return
  end
  vim.api.nvim_buf_set_lines(buffer, span.first, span.last + 1, true, edit.new)
end

--- The index in `preview.edits` of the edit chosen: the one whose lines,
--- `spans`, hold the line `line`, from 1, when it is given; else the one
--- last moved to (`chosen`); `nil` when none is.
---
---@param preview aineo.explain.Preview
---@param spans { first: integer, last: integer }[]
---@param line? integer
---@return integer|nil
local function chosen_index(preview, spans, line)
  for index, span in ipairs(spans) do
    if line and line - 1 >= span.first and line - 1 <= span.last then
      return index
    end
  end
  for index, edit in ipairs(preview.edits) do
    if edit == preview.chosen then
      return index
    end
  end
end

--- The index of the edit of `preview` the line `line` chooses
--- (`chosen_index()`), with the lines each edit spans now (`spans_of()`);
--- `nil` when none is chosen, and the user is told, once, how to choose
--- one, or when an extmark of its edits is gone, and the preview is drawn
--- again (`render()`), stale, and the user told so.
---
---@param preview aineo.explain.Preview
---@param line? integer
---@return integer|nil index
---@return { first: integer, last: integer }[]? spans
local function choose(preview, line)
  local spans = spans_of(preview)
  if not spans then
    render(preview)
    vim.notify(('aineo: %s; ask again'):format(preview.kind.changed), vim.log.levels.WARN)
    return nil
  end
  local index = chosen_index(preview, spans, line)
  if not index then
    vim.notify(
      ('aineo: no %s is chosen: put the cursor on its lines, or move to it with %s or %s'):format(
        preview.kind.shown,
        named_key(preview, 'next'),
        named_key(preview, 'previous')
      ),
      vim.log.levels.INFO
    )
  end
  return index, spans
end

--- Removes the edits of `indexes` from `preview`, decided: their extmarks
--- go, and, when they were the last, the preview (`clear()`); else the
--- preview is drawn again without them (`render()`).
---
---@param preview aineo.explain.Preview
---@param indexes integer[]
local function remove_edits(preview, indexes)
  local decided = {}
  for _, index in ipairs(indexes) do
    decided[preview.edits[index]] = true
  end
  for _, edit in ipairs(vim.tbl_keys(decided)) do
    vim.api.nvim_buf_del_extmark(preview.buffer, RANGES, edit.mark)
  end
  preview.edits = vim.tbl_filter(function(edit)
    return not decided[edit]
  end, preview.edits)
  if decided[preview.chosen] then
    preview.chosen = nil
  end
  if decided[preview.subject_edit] then
    preview.subject_edit = nil
  end
  if #preview.edits == 0 then
    M.clear(preview.buffer)
  else
    render(preview)
  end
end

--- Applies the edits `indexes` of `preview`, spanning the lines of `spans`
--- (`apply_edit()`), the edit lowest in the buffer first, as one undo step,
--- 'modifiable' on while it does, writes nothing and removes them
--- (`remove_edits()`).
---
---@param preview aineo.explain.Preview
---@param indexes integer[]
---@param spans { first: integer, last: integer }[]
local function apply_edits(preview, indexes, spans)
  local lowest_first = vim.list_slice(indexes)
  table.sort(lowest_first, function(a, b)
    return spans[a].first > spans[b].first
  end)
  vim.bo[preview.buffer].modifiable = true
  for _, index in ipairs(lowest_first) do
    apply_edit(preview.buffer, preview.edits[index], spans[index])
  end
  vim.bo[preview.buffer].modifiable = false
  remove_edits(preview, indexes)
end

--- Applies the edit of `preview` the line `line` chooses (`choose()`), when
--- it still stands, as one undo step, and removes it (`apply_edits()`);
--- else leaves the buffer as it is, draws the preview again, and tells the
--- user, once, that it is stale. Returns whether it applied it.
---
---@param preview aineo.explain.Preview
---@param line? integer
---@return boolean
local function apply_chosen(preview, line)
  local index, spans = choose(preview, line)
  if not index then
    return false
  end
  local edit = preview.edits[index]
  local span = spans[index]
  if not vim.deep_equal(lines_of(preview.buffer, span), edit.old) then
    render(preview)
    vim.notify(('aineo: %s; ask again'):format(preview.kind.changed), vim.log.levels.WARN)
    return false
  end
  apply_edits(preview, { index }, spans)
  return true
end

--- Applies every edit of the preview `buffer` shows, which must be shown
--- (`is_shown()`): as `apply()` does, for a preview whose edits are not
--- proposals of their own; else each that still stands, as one undo step,
--- removing them (`apply_edits()`), and leaving the stale ones shown. When
--- none stands, or an extmark of its edits is gone, the buffer is left as
--- it is, the preview drawn again (`render()`), and the user told, once,
--- that it is stale. Returns whether it applied an edit.
---
---@param buffer integer
---@return boolean
function M.apply_all(buffer)
  local preview = previews[buffer]
  if not preview.separate then
    return M.apply(buffer)
  end
  local spans = spans_of(preview)
  local standing = {}
  for index, span in ipairs(spans or {}) do
    if vim.deep_equal(lines_of(buffer, span), preview.edits[index].old) then
      table.insert(standing, index)
    end
  end
  if #standing == 0 then
    render(preview)
    vim.notify(('aineo: %s; ask again'):format(preview.kind.changed), vim.log.levels.WARN)
    return false
  end
  apply_edits(preview, standing, spans)
  return true
end

--- The index in `spans`, the lines of the edits of a preview in the order
--- of their lines, of the edit `way` of the line `line`, from 0: the first
--- that starts after it, or the last that starts before it, wrapping
--- around to the first or the last.
---
---@param spans { first: integer, last: integer }[]
---@param line integer
---@param way 'next'|'previous'
---@return integer
local function index_toward(spans, line, way)
  if way == 'next' then
    for index, span in ipairs(spans) do
      if span.first > line then
        return index
      end
    end
    return 1
  end
  for index = #spans, 1, -1 do
    if spans[index].first < line then
      return index
    end
  end
  return #spans
end

--- Moves the cursor of `window` to the first line of the edit, `way` of
--- its line, of the preview its buffer shows, when the edits of that
--- preview are proposals of their own (`index_toward()`), and has that edit
--- chosen (`chosen`); nothing otherwise, nor when an extmark of its edits
--- is gone.
---
---@param window integer
---@param way 'next'|'previous'
function M.jump(window, way)
  local preview = previews[vim.api.nvim_win_get_buf(window)]
  local spans = preview and preview.separate and spans_of(preview)
  if not spans then
    return
  end
  local line = vim.api.nvim_win_get_cursor(window)[1] - 1
  local index = index_toward(spans, line, way)
  preview.chosen = preview.edits[index]
  vim.api.nvim_win_set_cursor(window, { spans[index].first + 1, 0 })
end

--- Removes the preview `buffer` shows (`clear()`), or, when its edits are
--- proposals of their own, the one the line `line`, from 1, chooses
--- (`choose()`), leaving the buffer as it reads (`remove_edits()`); nothing
--- when it shows none.
---
---@param buffer integer
---@param line? integer the cursor's line
function M.drop(buffer, line)
  local preview = previews[buffer]
  if not preview then
    return
  end
  if not preview.separate then
    M.clear(buffer)
    return
  end
  local index = choose(preview, line)
  if index then
    remove_edits(preview, { index })
  end
end

--- Applies the preview `buffer` shows, which must be shown (`is_shown()`),
--- or, when its edits are proposals of their own, the one the line `line`,
--- from 1, chooses (`apply_chosen()`). Every edit of any other preview is
--- applied when they still stand (`standing_spans()`), each
--- (`apply_edit()`), the edit lowest in the buffer first, as one undo step,
--- 'modifiable' on while they are, nothing written and the preview removed
--- (`clear()`), which gives the buffer its 'modifiable' back; else the
--- buffer is left as it is, the preview drawn again (`render()`), marked
--- stale, and the user told, once. Returns whether it applied an edit.
---
---@param buffer integer
---@param line? integer the cursor's line
---@return boolean
function M.apply(buffer, line)
  local preview = previews[buffer]
  if preview.separate then
    return apply_chosen(preview, line)
  end
  local spans = standing_spans(preview)
  if not spans then
    render(preview)
    vim.notify(('aineo: %s; ask again'):format(preview.kind.changed), vim.log.levels.WARN)
    return false
  end
  local lowest_first = {}
  for index in ipairs(spans) do
    lowest_first[index] = index
  end
  table.sort(lowest_first, function(a, b)
    return spans[a].first > spans[b].first
  end)
  vim.bo[buffer].modifiable = true
  for _, index in ipairs(lowest_first) do
    apply_edit(buffer, preview.edits[index], spans[index])
  end
  M.clear(buffer)
  return true
end

--- Watches the changes of `preview`'s buffer while it shows `preview`,
--- which only a decision removes: after a change, when the event loop has
--- turned and the change is whole, it is drawn again (`render()`), moved
--- along with its extmarks, and marked stale when its edits no longer
--- stand, or no longer so when they stand again. A reload, which detaches
--- the watch, is watched again and drawn again the same way. The buffer
--- unloaded or wiped out removes it without a word, as its deletion does
--- (the `BufDelete` autocommand).
---
---@param preview aineo.explain.Preview
local function watch_edits(preview)
  vim.api.nvim_buf_attach(preview.buffer, false, {
    on_lines = function()
      if previews[preview.buffer] ~= preview then
        return true
      end
      vim.schedule(function()
        if previews[preview.buffer] == preview and vim.api.nvim_buf_is_loaded(preview.buffer) then
          render(preview)
        end
      end)
    end,
    on_detach = function()
      vim.schedule(function()
        if previews[preview.buffer] ~= preview then
          return
        end
        if vim.api.nvim_buf_is_loaded(preview.buffer) then
          watch_edits(preview)
          render(preview)
        else
          M.clear(preview.buffer)
        end
      end)
    end,
  })
end

--- Shows the preview `buffer` shows as the diff view, its old lines struck
--- through above its new lines, or as the overlay again, brought into
--- view in a window that does not show its first row
--- (`bring_into_view()`); nothing when `buffer` shows none. When its edits
--- are proposals of their own, only the one the line `line`, from 1,
--- chooses (`choose()`) is shown so, or as the overlay again. A stale
--- preview (`is_stale()`), or a stale proposal, always shown as the diff
--- view, is left so, and the user is told, once, what rejects it and what
--- asks again.
---
---@param buffer integer
---@param line? integer the cursor's line
function M.toggle_diff(buffer, line)
  local preview = previews[buffer]
  if not preview then
    return
  end
  local toggled = preview
  local stale = is_stale(preview, spans_of(preview))
  if preview.separate then
    local index = choose(preview, line)
    if not index then
      return
    end
    toggled = preview.edits[index]
    stale = toggled.stale
  end
  if stale then
    vim.notify(
      ('aineo: %s: %s rejects, %s asks again'):format(
        preview.kind.stale,
        named_key(preview, 'reject'),
        preview.ask_key
      ),
      vim.log.levels.INFO
    )
    return
  end
  toggled.diff = not toggled.diff
  render(preview)
  bring_into_view(preview)
end

--- What a preview is shown with.
---@class aineo.explain.PreviewOrder
---@field window integer the window the fix was asked in
---@field summary string the whole fix in one sentence
---@field edits aineo.explain.PlacedEdit[] placed in the buffer's text as it reads, in the order of their lines
---@field keys? aineo.explain.FixKeys the keys that accept, reject and show the diff
---@field ask_key string what asks the fix or the code again, as the user is told it
---@field kind aineo.explain.Kind what it is: `kinds.FIX` or `kinds.WRITE`, which name it in its head row and its messages
---@field subject aineo.explain.Subject what it is proposed for: the issue a fix fixes, in the issue look, or the request code is written for
---@field separate? boolean whether each edit is a proposal of its own, decided apart from the others
---@field subject_index? integer the index in `edits` of the edit the subject is shown above; the first when absent

--- Shows the edits of `order` in `buffer` as a preview: the buffer is not
--- changed, and cannot be while it is shown, its 'modifiable' off; each
--- edit's old lines are hidden in every window showing it and its new lines
--- drawn in their place, brought into view in a window that does not show
--- its first row (`bring_into_view()`). Later scrolling is left alone.
---
---@param buffer integer
---@param order aineo.explain.PreviewOrder
function M.show(buffer, order)
  local preview = {
    buffer = buffer,
    window = order.window,
    summary = order.summary,
    keys = order.keys,
    mapped = {},
    diff = false,
    edits = {},
    saved = {},
    set = {},
    modifiable = vim.bo[buffer].modifiable,
    ask_key = order.ask_key,
    subject = order.subject,
    kind = order.kind,
    separate = order.separate == true,
    stale = false,
    first_row = order.edits[1].first - 1,
  }
  for _, edit in ipairs(order.edits) do
    table.insert(preview.edits, {
      mark = vim.api.nvim_buf_set_extmark(buffer, RANGES, edit.first - 1, 0, {
        end_row = edit.last,
        end_col = 0,
      }),
      old = edit.old,
      new = edit.new,
      why = edit.why,
    })
  end
  preview.subject_edit = preview.edits[order.subject_index or 1]
  previews[buffer] = preview
  watch_drawings(true)
  vim.bo[buffer].modifiable = false
  conceal_in_windows(preview)
  map_keys(preview)
  render(preview)
  bring_into_view(preview)
  watch_edits(preview)
end

return M
