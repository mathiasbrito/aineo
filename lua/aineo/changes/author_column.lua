--- The column of a commit's line in the commits window that tells who
--- wrote the commit and how long ago: pure functions of the commit and of
--- the time they are asked at.

local M = {}

--- How many display cells the column takes.
M.WIDTH = 20

--- Where the name stands when it is cut.
local ELLIPSIS = '…'

local MINUTE = 60
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR
local WEEK = 7 * DAY
local MONTH = 30 * DAY
local YEAR = 365 * DAY

--- The units an age is told in, longest first: the seconds one takes and
--- the letters that name it.
---@type { seconds: integer, suffix: string }[]
local UNITS = {
  { seconds = YEAR, suffix = 'y' },
  { seconds = MONTH, suffix = 'mo' },
  { seconds = WEEK, suffix = 'w' },
  { seconds = DAY, suffix = 'd' },
  { seconds = HOUR, suffix = 'h' },
  { seconds = MINUTE, suffix = 'm' },
}

--- What the age of a commit written less than a minute ago, or ahead of
--- `now`, says.
local JUST_NOW = 'now'

--- How long before `now` something written at `written_at` was, in whole
--- units rounded down: `now` under a minute, then minutes, hours, days,
--- weeks, months of 30 days and years of 365 days, as `<n>m`, `<n>h`,
--- `<n>d`, `<n>w`, `<n>mo`, `<n>y`. A time ahead of `now` is `now` too.
---
---@param written_at integer seconds since the epoch
---@param now integer seconds since the epoch
---@return string
function M.age(written_at, now)
  local seconds = now - written_at
  for _, unit in ipairs(UNITS) do
    if seconds >= unit.seconds then
      return math.floor(seconds / unit.seconds) .. unit.suffix
    end
  end
  return JUST_NOW
end

--- `name` as it is at most `width` display cells wide: as it is when it
--- fits, else cut after the last character that leaves room for an
--- ellipsis, which ends it. A wide character is kept or dropped whole.
---
---@param name string
---@param width integer
---@return string
local function cut_to_width(name, width)
  if vim.fn.strdisplaywidth(name) <= width then
    return name
  end
  local room = width - vim.fn.strdisplaywidth(ELLIPSIS)
  local kept, used = {}, 0
  for _, character in ipairs(vim.fn.split(name, '\\zs')) do
    used = used + vim.fn.strdisplaywidth(character)
    if used > room then
      break
    end
    table.insert(kept, character)
  end
  return table.concat(kept) .. ELLIPSIS
end

--- A commit's column, as the commits window draws it.
---@class aineo.changes.AuthorColumn
---@field text string the name, a space, the age, then spaces up to `M.WIDTH` display cells
---@field name string the author's name as drawn: cut to fit, a control character shown as a space
---@field age string the commit's age (`M.age()`), never cut

--- The column of `commit` at the time `now`: its author's name, a space,
--- and its age (`M.age()`), padded on the right to `M.WIDTH` display cells.
--- The age is kept whole; the name is cut to what the age leaves
--- (`cut_to_width()`), and a control character of it is shown as a space.
---
---@param commit aineo.git.Commit
---@param now integer seconds since the epoch
---@return aineo.changes.AuthorColumn
function M.of(commit, now)
  local age = M.age(commit.authored_at, now)
  local room = M.WIDTH - 1 - vim.fn.strdisplaywidth(age)
  local name = cut_to_width((commit.author:gsub('%c', ' ')), room)
  local text = ('%s %s'):format(name, age)
  local padding = (' '):rep(M.WIDTH - vim.fn.strdisplaywidth(text))
  return { text = text .. padding, name = name, age = age }
end

return M
