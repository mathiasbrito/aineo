--- The page of the walkthrough pane: the plan of a code walkthrough laid out
--- for a window of a given width — its title, a summary, what it covers, its
--- steps with the one on show marked, and the concepts the steps introduce —
--- and drawn into the pane's buffer. `render()` is a function of the plan,
--- the step shown and the width alone, so that the pane can lay the page out
--- again whenever the window is resized or the step moves.

local M = {}

--- The namespace of the page's highlights, made when first asked for.
local NAMESPACE = 'aineo_explain_walk_pane'

--- The columns left empty at the left of each line.
local INDENT = 1

--- The columns left empty at the right of each line.
local RIGHT_MARGIN = 2

--- The narrowest line the page lays out, whatever the window's width.
local SMALLEST_LINE_CELLS = 12

--- The widest column the names of the concepts take.
local WIDEST_NAME_CELLS = 24

--- What marks a step already shown, the step on show, and one not reached,
--- each one cell wide.
local DONE_SIGN, SHOWN_SIGN, AHEAD_SIGN = '✓', '▸', ' '

--- The width of a sign, in cells.
local SIGN_CELLS = 1

--- The bullet before each item of what the plan covers.
local BULLET = '•'

--- What ends a name or a path that was cut to fit.
local ELLIPSIS = '…'

--- The highlight group of each part of the page, and the group it is linked
--- to unless the user defines it: the step on show is tinted as the lines
--- of a walkthrough step are (`AineoWalkRange`).
---@type table<string, string>
local GROUP_LINKS = {
  AineoPaneTitle = 'Title',
  AineoPaneSection = 'Statement',
  AineoPaneBullet = 'Special',
  AineoPaneDone = 'DiagnosticOk',
  AineoPaneShown = 'AineoWalkRange',
  AineoPaneFile = 'Comment',
  AineoPaneStepRef = 'Number',
}

--- A walkthrough plan, as the walkthrough plan tool gives it, except that a
--- step's `file` is the text to show for it.
---@alias aineo.explain.PlanToShow aineo.mcp.WalkthroughPlanCall

--- The highlight of part of a line of the page.
---@class aineo.explain.PageHighlight
---@field row integer the line, from 0
---@field col integer the first byte
---@field end_col integer the byte after the last
---@field group string
---@field fills_row? boolean whether the highlight also fills the line to the window's edge

--- The page of a plan.
---@class aineo.explain.RenderedPlan
---@field lines string[]
---@field highlights aineo.explain.PageHighlight[]
---@field step_at table<integer, integer> the step each line, from 1, goes to; none for a line that goes nowhere

--- The width of `text`, in screen cells.
---
---@param text string
---@return integer
local function cells(text)
  return vim.fn.strdisplaywidth(text)
end

--- The pieces of `word`, none wider than `room` cells.
---
---@param word string
---@param room integer
---@return string[]
local function pieces_of(word, room)
  if cells(word) <= room then
    return { word }
  end
  local pieces, piece = {}, ''
  for index = 0, vim.fn.strchars(word) - 1 do
    local character = vim.fn.strcharpart(word, index, 1)
    if cells(piece .. character) > room then
      table.insert(pieces, piece)
      piece = ''
    end
    piece = piece .. character
  end
  table.insert(pieces, piece)
  return pieces
end

--- `text` broken between words into lines no wider than `room` cells, a word
--- wider than that broken too.
---
---@param text string
---@param room integer
---@return string[]
local function wrap(text, room)
  local lines, line = {}, nil
  for word in text:gmatch('%S+') do
    for _, piece in ipairs(pieces_of(word, room)) do
      if line and cells(line) + 1 + cells(piece) <= room then
        line = line .. ' ' .. piece
      else
        table.insert(lines, line)
        line = piece
      end
    end
  end
  table.insert(lines, line)
  return lines
end

--- `text` cut to `room` cells, an ellipsis in place of what is left out:
--- at its end for a name, at its start for a path, whose end says most.
---
---@param text string
---@param room integer
---@param keep 'start'|'end' the part of `text` that is kept
---@return string
local function cut(text, room, keep)
  if cells(text) <= room then
    return text
  end
  local total = vim.fn.strchars(text)
  for kept = total - 1, 0, -1 do
    local candidate = keep == 'start' and (vim.fn.strcharpart(text, 0, kept) .. ELLIPSIS)
      or (ELLIPSIS .. vim.fn.strcharpart(text, total - kept))
    if cells(candidate) <= room then
      return candidate
    end
  end
  return ELLIPSIS
end

--- A page being laid out.
---@class aineo.explain.Page : aineo.explain.RenderedPlan
---@field shown? integer the number of the step on show

--- Adds a line to `page`.
---
---@param page aineo.explain.Page
---@param text string
---@param options? { group?: string, step?: integer, fills_row?: boolean } `group` highlights the whole line, `step` the step the line goes to
---@return integer row the line's row, from 0
local function append(page, text, options)
  options = options or {}
  table.insert(page.lines, text)
  local row = #page.lines - 1
  if options.group then
    table.insert(page.highlights, {
      row = row,
      col = 0,
      end_col = #text,
      group = options.group,
      fills_row = options.fills_row,
    })
  end
  if options.step then
    page.step_at[#page.lines] = options.step
  end
  return row
end

--- Highlights bytes `col` up to `end_col` of the line at `row` of `page`.
---
---@param page aineo.explain.Page
---@param row integer
---@param col integer
---@param end_col integer
---@param group string
local function highlight(page, row, col, end_col, group)
  table.insert(page.highlights, { row = row, col = col, end_col = end_col, group = group })
end

--- Adds a section's heading, after a blank line.
---
---@param page aineo.explain.Page
---@param name string
local function add_section(page, name)
  append(page, '')
  append(page, ' ' .. name, { group = 'AineoPaneSection' })
end

--- Adds what the plan covers, one bulleted item at a time, a wrapped item
--- under its own words.
---
---@param page aineo.explain.Page
---@param covers string[]
---@param line_cells integer
local function add_covers(page, covers, line_cells)
  add_section(page, 'Covers')
  local bullet_start = #' '
  local bullet_end = bullet_start + #BULLET
  for _, item in ipairs(covers) do
    for index, text in ipairs(wrap(item, line_cells - INDENT - 2)) do
      local row = append(page, index == 1 and (' ' .. BULLET .. ' ' .. text) or ('   ' .. text))
      if index == 1 then
        highlight(page, row, bullet_start, bullet_end, 'AineoPaneBullet')
      end
    end
  end
end

--- The sign before step `number`, given the step on show.
---
---@param number integer
---@param shown? integer
---@return string
local function sign_of(number, shown)
  if shown and number < shown then
    return DONE_SIGN
  end
  return number == shown and SHOWN_SIGN or AHEAD_SIGN
end

--- Adds the steps: for each, its sign, number and title, the title wrapped
--- under its own words, then its file on a line of its own.
---
---@param page aineo.explain.Page
---@param steps { title: string, file: string }[]
---@param line_cells integer
local function add_steps(page, steps, line_cells)
  add_section(page, 'Steps')
  local number_cells = #tostring(#steps)
  local title_column = INDENT + SIGN_CELLS + 1 + number_cells + 2
  local sign_start = INDENT
  for number, step in ipairs(steps) do
    local sign = sign_of(number, page.shown)
    local is_on_show = number == page.shown
    for index, text in ipairs(wrap(step.title, line_cells - title_column)) do
      local head = index == 1 and (' %s %' .. number_cells .. 'd  %s'):format(sign, number, text)
        or (' '):rep(title_column) .. text
      local row = append(page, head, {
        group = is_on_show and 'AineoPaneShown' or nil,
        fills_row = is_on_show or nil,
        step = number,
      })
      if index == 1 and sign == DONE_SIGN then
        highlight(page, row, sign_start, sign_start + #DONE_SIGN, 'AineoPaneDone')
      end
    end
    local file = cut(step.file, line_cells - title_column - 1, 'end')
    append(page, (' '):rep(title_column + 1) .. file, { group = 'AineoPaneFile', step = number })
  end
end

--- The concepts the steps introduce, each with the number of the step that
--- introduces it, in the order of the plan.
---
---@param steps { introduces: string[] }[]
---@return { name: string, step: integer }[]
local function concepts_of(steps)
  local concepts = {}
  for number, step in ipairs(steps) do
    for _, name in ipairs(step.introduces) do
      table.insert(concepts, { name = name, step = number })
    end
  end
  return concepts
end

--- Adds the concepts, each beside its step, the step numbers in a column
--- and the concepts of steps not reached yet dimmed. Adds nothing when no
--- step introduces one.
---
---@param page aineo.explain.Page
---@param steps { introduces: string[] }[]
---@param line_cells integer
local function add_concepts(page, steps, line_cells)
  local concepts = concepts_of(steps)
  if #concepts == 0 then
    return
  end
  add_section(page, 'Introduced')
  local reference_cells = #'  step ' + #tostring(#steps)
  local name_cells = math.min(
    math.max(unpack(vim.tbl_map(function(concept)
      return cells(concept.name)
    end, concepts))),
    WIDEST_NAME_CELLS,
    line_cells - INDENT - reference_cells
  )
  for _, concept in ipairs(concepts) do
    local name = cut(concept.name, name_cells, 'start')
    local reference = 'step ' .. concept.step
    local text = ' ' .. name .. (' '):rep(name_cells - cells(name)) .. '  ' .. reference
    local is_ahead = concept.step > (page.shown or 0)
    local row =
      append(page, text, { group = is_ahead and 'AineoPaneFile' or nil, step = concept.step })
    highlight(page, row, #text - #reference, #text, 'AineoPaneStepRef')
  end
end

--- The page of `plan` for a window `width` cells wide, `shown` the number of
--- the step on show, if one is: the steps before it marked done, it marked
--- and tinted to the window's edge, a step's file dimmed on a line under its
--- title. A line is as wide as the window less a margin, and no narrower than
--- twelve cells; the summary, the items of what the plan covers and the step
--- titles are wrapped to it, and a path too long for it is cut at its start.
--- The concepts the steps introduce, when any do, come last, each beside its
--- step, those of steps not reached yet dimmed.
---
--- The page also tells, for each line of a step or a concept, the step it
--- goes to (`step_at`).
---
---@param plan aineo.explain.PlanToShow
---@param shown? integer
---@param width integer
---@return aineo.explain.RenderedPlan
function M.render(plan, shown, width)
  local line_cells = math.max(width - RIGHT_MARGIN, SMALLEST_LINE_CELLS)
  local page = { lines = {}, highlights = {}, step_at = {}, shown = shown }
  for _, text in ipairs(wrap(plan.title, line_cells - INDENT)) do
    append(page, ' ' .. text, { group = 'AineoPaneTitle' })
  end
  append(page, '')
  for _, text in ipairs(wrap(plan.summary, line_cells - INDENT)) do
    append(page, ' ' .. text)
  end
  add_covers(page, plan.covers, line_cells)
  add_steps(page, plan.steps, line_cells)
  add_concepts(page, plan.steps, line_cells)
  return { lines = page.lines, highlights = page.highlights, step_at = page.step_at }
end

--- Defines the page's highlight groups as links, which a definition of the
--- user's, made before or after, replaces.
local function define_groups()
  for group, target in pairs(GROUP_LINKS) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

--- Draws `rendered` in `buffer`, in place of what it held: its lines, and
--- its highlights as extmarks, a row's fill running to the window's edge.
--- The buffer is left unmodifiable.
---
---@param buffer integer
---@param rendered aineo.explain.RenderedPlan
function M.draw(buffer, rendered)
  define_groups()
  local namespace = vim.api.nvim_create_namespace(NAMESPACE)
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, rendered.lines)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  for _, mark in ipairs(rendered.highlights) do
    vim.api.nvim_buf_set_extmark(buffer, namespace, mark.row, mark.col, {
      end_col = mark.end_col,
      hl_group = mark.group,
      hl_eol = mark.fills_row,
    })
  end
end

return M
