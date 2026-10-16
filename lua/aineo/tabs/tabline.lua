--- The format of the tab line, in the language of 'statusline'.

local highlights = require('aineo.tabs.highlights')
local titles = require('aineo.tabs.titles')

local M = {}

--- One tab page's place in the line.
---
---@class aineo.tabs.TabLineEntry
---@field number integer the tab page's place, which a click on its title goes to
---@field name string the whole name as `strtrans()` shows it, which the line may cut (`titles.cut()`)
---@field indicator string|nil what the tab page's activity says, which is never cut
---@field current boolean whether it is the current tab page

--- One tab page's title in the line, its name cut or whole.
---
---@class aineo.tabs.TabLineTitle
---@field number integer
---@field text string
---@field current boolean

--- `text` as a 'statusline' format shows it written, `%` doubled.
---
---@param text string
---@return string
local function literal(text)
  return (text:gsub('%%', '%%%%'))
end

--- The 'statusline' format of one title, in a click region of its tab page,
--- with `padding` spaces either side.
---
---@param entry aineo.tabs.TabLineTitle
---@param padding integer
---@return string
local function format_of(entry, padding)
  local group = entry.current and highlights.GROUPS.current or highlights.GROUPS.other
  local margin = (' '):rep(padding)
  return ('%%#%s#%%%dT%s%s%s'):format(group, entry.number, margin, literal(entry.text), margin)
end

--- The display cells `entry` takes in the line: its title and `padding`
--- spaces either side.
---
---@param entry aineo.tabs.TabLineTitle
---@param padding integer
---@return integer
local function width_of(entry, padding)
  return vim.api.nvim_strwidth(entry.text) + 2 * padding
end

--- The places, as `first, last`, of the longest run of `entries` that holds
--- the current entry and fits `columns` cells, widened to the left first and
--- then to the right. A current entry wider than `columns` is a run of its
--- own.
---
---@param entries aineo.tabs.TabLineTitle[]
---@param columns integer
---@param padding integer
---@return integer first
---@return integer last
local function run_around_current(entries, columns, padding)
  local current = 1
  for index, entry in ipairs(entries) do
    if entry.current then
      current = index
    end
  end
  local first, last, used = current, current, width_of(entries[current], padding)
  while first > 1 and used + width_of(entries[first - 1], padding) <= columns do
    first = first - 1
    used = used + width_of(entries[first], padding)
  end
  while last < #entries and used + width_of(entries[last + 1], padding) <= columns do
    last = last + 1
    used = used + width_of(entries[last], padding)
  end
  return first, last
end

--- The titles of `entries`, each name cut to at most `cap` display cells.
---
---@param entries aineo.tabs.TabLineEntry[]
---@param cap number
---@return aineo.tabs.TabLineTitle[]
local function titles_cut_to(entries, cap)
  return vim.tbl_map(function(entry)
    return {
      number = entry.number,
      text = titles.title_of(entry.number, titles.cut(entry.name, cap), entry.indicator),
      current = entry.current,
    }
  end, entries)
end

--- The display cells the line takes when `drawn` are all drawn, with
--- `padding` spaces either side of each.
---
---@param drawn aineo.tabs.TabLineTitle[]
---@param padding integer
---@return integer
local function width_of_all(drawn, padding)
  local width = 0
  for _, title in ipairs(drawn) do
    width = width + width_of(title, padding)
  end
  return width
end

--- The cap to cut the names of `entries` to, so that their titles fit
--- `columns` cells: `math.huge` when they fit with every name whole, else the
--- widest cap at which they fit, no narrower than `titles.SHORTEST_CUT_CELLS`
--- (which is the cap when they fit at no cap).
---
---@param entries aineo.tabs.TabLineEntry[]
---@param columns integer
---@param padding integer
---@return number
local function cap_that_fits(entries, columns, padding)
  local function fits(cap)
    return width_of_all(titles_cut_to(entries, cap), padding) <= columns
  end
  if fits(math.huge) then
    return math.huge
  end
  local fitting = titles.SHORTEST_CUT_CELLS
  if not fits(fitting) then
    return fitting
  end
  local overflowing = 0
  for _, entry in ipairs(entries) do
    overflowing = math.max(overflowing, vim.api.nvim_strwidth(entry.name))
  end
  while overflowing - fitting > 1 do
    local middle = math.floor((fitting + overflowing) / 2)
    if fits(middle) then
      fitting = middle
    else
      overflowing = middle
    end
  end
  return fitting
end

--- The format that draws `entries` side by side, then fills the rest of the
--- line. Every name is whole while the titles fit `columns` cells. When they
--- do not, each name wider than one cap is cut to it (`titles.cut()`), the
--- cap the widest at which they fit and no narrower than
--- `titles.SHORTEST_CUT_CELLS`; the number, the indicator and the padding are
--- never cut. When they do not fit even then, only whole titles are drawn, so
--- that each begins with its number: a run of them that holds the current one.
---
---@param entries aineo.tabs.TabLineEntry[] at least one
---@param columns integer the width of the line
---@param padding integer the spaces either side of every title
---@return string
function M.format(entries, columns, padding)
  local drawn = titles_cut_to(entries, cap_that_fits(entries, columns, padding))
  local first, last = run_around_current(drawn, columns, padding)
  local formats = vim.tbl_map(function(entry)
    return format_of(entry, padding)
  end, vim.list_slice(drawn, first, last))
  return table.concat(formats) .. ('%%#%s#%%T'):format(highlights.GROUPS.fill)
end

return M
