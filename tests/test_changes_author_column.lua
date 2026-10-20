local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local author_column = require('aineo.changes.author_column')

local MINUTE = 60
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR
local WEEK = 7 * DAY
local MONTH = 30 * DAY
local YEAR = 365 * DAY

--- The moment the ages of these cases are counted to.
local NOW = 1800000000

--- The commit of `author`, written `seconds` before `NOW`.
---
---@param author string
---@param seconds integer
---@return aineo.git.Commit
local function written_by(author, seconds)
  return { id = 'abc1234', subject = 'Subject', author = author, authored_at = NOW - seconds }
end

local T = MiniTest.new_set()

T['the age'] = MiniTest.new_set({
  parametrize = {
    { 0, 'now' },
    { 59, 'now' },
    { MINUTE, '1m' },
    { HOUR - 1, '59m' },
    { HOUR, '1h' },
    { DAY - 1, '23h' },
    { DAY, '1d' },
    { WEEK - 1, '6d' },
    { WEEK, '1w' },
    { MONTH - 1, '4w' },
    { MONTH, '1mo' },
    { YEAR - 1, '12mo' },
    { YEAR, '1y' },
    { 2 * YEAR + 5 * DAY, '2y' },
    { -30, 'now' },
  },
})

T['the age']['is the whole units since the commit was written, rounded down'] = function(
  seconds,
  expected
)
  eq(author_column.age(NOW - seconds, NOW), expected)
end

T['the column'] = MiniTest.new_set()

T['the column']['holds a short name and the age, padded on the right to 20 cells'] = function()
  local column = author_column.of(written_by('Ada', 3 * HOUR), NOW)

  eq(column, { text = 'Ada 3h' .. (' '):rep(14), name = 'Ada', age = '3h' })
end

T['the column']['keeps a name that fills what the age leaves, whole'] = function()
  local name = ('n'):rep(17)

  local column = author_column.of(written_by(name, 2 * DAY), NOW)

  eq(column, { text = name .. ' 2d', name = name, age = '2d' })
end

T['the column']['cuts a name that is a cell too long, with an ellipsis'] = function()
  local column = author_column.of(written_by(('n'):rep(18), 2 * DAY), NOW)

  eq(column, { text = ('n'):rep(16) .. '… 2d', name = ('n'):rep(16) .. '…', age = '2d' })
end

T['the column']['never cuts the age, however long, and cuts the name to what is left'] = function()
  local column = author_column.of(written_by(('n'):rep(40), 3 * MONTH), NOW)

  eq(column, { text = ('n'):rep(15) .. '… 3mo', name = ('n'):rep(15) .. '…', age = '3mo' })
end

T['the column']['cuts a name of wide characters by the cells they take, and pads what is left'] = function()
  local column = author_column.of(written_by('山田太郎山田太郎山田太郎', 10), NOW)

  eq(column.name, '山田太郎山田太…')
  eq(column.text, '山田太郎山田太… now ')
  eq(vim.fn.strdisplaywidth(column.text), 20)
end

T['the column']['keeps a name of wide characters that fits, whole'] = function()
  local column = author_column.of(written_by('山田太郎山田太郎', 10), NOW)

  eq(column.text, '山田太郎山田太郎 now')
  eq(vim.fn.strdisplaywidth(column.text), 20)
end

T['the column']['shows a control character of a name as a space'] = function()
  local column = author_column.of(written_by('Ada\tKing', 10), NOW)

  eq(column.name, 'Ada King')
  eq(vim.fn.strdisplaywidth(column.text), 20)
end

return T
