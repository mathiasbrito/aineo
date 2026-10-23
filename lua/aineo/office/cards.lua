--- The report cards of the office: a line of text for each report that came in,
--- drawn over the bottom right corner of the scene, the newest at the bottom,
--- above the status list. The reports that came in are kept until the user
--- enters the right side.

local text_module = require('aineo.office.text')

local M = {}

--- The most cards drawn at once; the older reports are counted in a line
--- above them.
local MOST_CARDS_DRAWN = 3

--- The empty cells kept between a card and the edges of the office.
local MARGIN_CELLS = 1

--- The dot a card opens with, and what stands in its place while it blinks.
local DOT = '●'
local DOT_HIDDEN = ' '

--- The words that join the parts of a card.
local SEPARATOR = ' · '

--- How long the dot of a report that cannot go on shows, and then hides, in
--- seconds.
local BLINK_SECONDS = 0.5

--- The statuses whose dot blinks.
local BLINKING_STATUSES = { blocked = true, failed = true }

--- The colour of each status of a report, as the highlight group that draws
--- its card.
local STATUS_GROUPS = {
  done = 'AineoOfficeCardDone',
  started = 'AineoOfficeCardProgress',
  progress = 'AineoOfficeCardProgress',
  blocked = 'AineoOfficeCardProblem',
  failed = 'AineoOfficeCardProblem',
}

--- The group of the line that counts the cards not drawn.
local MORE_GROUP = 'AineoOfficeCardMore'

--- The groups the cards use, each linked to the group a colorscheme already
--- colours the same meaning with; `default` leaves a link of the user's own
--- alone.
local GROUP_LINKS = {
  AineoOfficeCardDone = 'DiagnosticOk',
  AineoOfficeCardProgress = 'DiagnosticInfo',
  AineoOfficeCardProblem = 'DiagnosticError',
  [MORE_GROUP] = 'Comment',
}

---@class aineo.office.Report
---@field status string `started`, `progress`, `blocked`, `done` or `failed`
---@field summary string what the report says, in a few words
---@field task? string

---@class aineo.office.CardOverlayOptions
---@field width integer the cells of a row of the picture
---@field now number the time in seconds, from any origin, that only grows

---@class aineo.office.Cards
---@field add fun(report: aineo.office.Report) keeps a report to draw as a card
---@field clear fun() forgets every report kept
---@field overlay fun(picture: aineo.office_scene.Picture, options: aineo.office.CardOverlayOptions): aineo.office_scene.Picture the picture with the cards drawn over it

--- Makes the highlight groups of the cards, unless the user or a colorscheme
--- made them. Remade after a colorscheme clears them.
function M.define_groups()
  for group, link in pairs(GROUP_LINKS) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

--- `report` as the text of its card, opening with `dot`, at most `cells`
--- cells wide.
---
---@param report aineo.office.Report
---@param dot string
---@param cells integer
---@return string
local function card_text(report, dot, cells)
  local text = dot .. ' ' .. report.status .. SEPARATOR .. text_module.on_one_line(report.summary)
  return text_module.cut_to_cells(text, cells)
end

--- Whether the dot of `report` shows at `now`: always, but for a report that
--- cannot go on, whose dot shows for a half second and then hides for one.
---
---@param report aineo.office.Report
---@param now number
---@return boolean
local function dot_shows(report, now)
  return not BLINKING_STATUSES[report.status] or math.floor(now / BLINK_SECONDS) % 2 == 0
end

--- The text and group of each line drawn over the scene, from the top: a line
--- that counts the reports kept but not drawn, then a card for each of the
--- newest.
---
---@param reports aineo.office.Report[] oldest first
---@param options aineo.office.CardOverlayOptions
---@return { text: string, group: string }[]
local function lines_of(reports, options)
  local drawn_from = math.max(1, #reports - MOST_CARDS_DRAWN + 1)
  local lines = {}
  if drawn_from > 1 then
    table.insert(lines, { text = ('+%d more'):format(drawn_from - 1), group = MORE_GROUP })
  end
  local cells = options.width - 2 * MARGIN_CELLS
  for index = drawn_from, #reports do
    local report = reports[index]
    local dot = dot_shows(report, options.now) and DOT or DOT_HIDDEN
    table.insert(lines, {
      text = card_text(report, dot, cells),
      group = STATUS_GROUPS[report.status] or MORE_GROUP,
    })
  end
  return lines
end

--- The cards of an office, none yet.
---
---@return aineo.office.Cards
function M.new_cards()
  ---@type aineo.office.Report[]
  local reports = {}

  local cards = {}

  function cards.add(report)
    table.insert(reports, report)
  end

  function cards.clear()
    reports = {}
  end

  function cards.overlay(picture, options)
    if #reports == 0 then
      return picture
    end
    local lines = lines_of(reports, options)
    local bottom = #picture.rows - (picture.status_list_height or 0)
    local rows = vim.list_slice(picture.rows)
    for offset, line in ipairs(lines) do
      local index = bottom - #lines + offset
      local cells = vim.fn.strdisplaywidth(line.text)
      if index >= 1 and cells + 2 * MARGIN_CELLS <= options.width then
        local first = options.width - MARGIN_CELLS - cells
        rows[index] = text_module.put_over(rows[index], first, cells, line.text, line.group)
      end
    end
    return vim.tbl_extend('force', picture, { rows = rows })
  end

  return cards
end

return M
