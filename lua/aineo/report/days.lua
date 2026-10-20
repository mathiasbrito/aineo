--- The days of the Report: which day a report arrived on, and what the
--- separator that starts a day reads. Everything here is a function of the
--- times it is given, as `YYYY-MM-DDTHH:MM:SS` local times; none reads a clock.

local M = {}

--- The names of the days of the week, from Sunday, and of the months, in
--- English whatever the locale.
local WEEKDAY_NAMES = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }
local MONTH_NAMES =
  { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }

--- The hour a day is read at when it is turned into a date: noon, which no
--- change of the clock for daylight saving moves into another day.
local NOON = 12

--- Matches a time as a record keeps it, capturing its year, month and day.
local TIME_PATTERN = '^(%d%d%d%d)%-(%d%d)%-(%d%d)T%d%d:%d%d:%d%d$'

--- The day of a time, `YYYY-MM-DD`, or nil when `time` is no such time.
---
---@param time string
---@return string?
function M.day_of(time)
  local year, month, day = time:match(TIME_PATTERN)
  if not year then
    return nil
  end
  return ('%s-%s-%s'):format(year, month, day)
end

--- The year, month and day, as numbers, of the day `day`, `YYYY-MM-DD`.
---
---@param day string
---@return integer year
---@return integer month
---@return integer date
local function numbers_of(day)
  local year, month, date = day:match('^(%d+)-(%d+)-(%d+)$')
  return tonumber(year), tonumber(month), tonumber(date)
end

--- The moment, in seconds, `day` is at noon.
---
---@param day string
---@param days_later integer? how many days after `day` the moment is; none when absent
---@return integer
local function noon_of(day, days_later)
  local year, month, date = numbers_of(day)
  return os.time({ year = year, month = month, day = date + (days_later or 0), hour = NOON })
end

--- What a separator reads for the day `day`, `YYYY-MM-DD`, as named at `now`,
--- a time as `day_of()` reads it: `Today` for the day of `now`, `Yesterday`
--- for the day before it, else the weekday, date and month, `Mon 19 Oct`,
--- with the year, `Sun 19 Oct 2025`, when it is not the year of `now`. When
--- `now` holds no day, no day is today or yesterday, and the year shows.
---
---@param day string
---@param now string
---@return string
function M.label_of_day(day, now)
  local today = M.day_of(now)
  if day == today then
    return 'Today'
  end
  if today and os.date('%Y-%m-%d', noon_of(today, -1)) == day then
    return 'Yesterday'
  end
  local year, month, date = numbers_of(day)
  local weekday = os.date('*t', noon_of(day)).wday
  local label = ('%s %d %s'):format(WEEKDAY_NAMES[weekday], date, MONTH_NAMES[month])
  if today and numbers_of(today) == year then
    return label
  end
  return ('%s %d'):format(label, year)
end

--- How many seconds from `now`, a time as `day_of()` reads it, to the next
--- midnight, or nil when `now` holds no day.
---
---@param now string
---@return integer?
function M.seconds_until_midnight(now)
  local day = M.day_of(now)
  if not day then
    return nil
  end
  local year, month, date = numbers_of(day)
  local hour, minute, second = now:match('T(%d%d):(%d%d):(%d%d)$')
  local moment = os.time({
    year = year,
    month = month,
    day = date,
    hour = tonumber(hour),
    min = tonumber(minute),
    sec = tonumber(second),
  })
  return os.time({ year = year, month = month, day = date + 1, hour = 0 }) - moment
end

--- The line that starts a day under the name `label`.
---
---@param label string
---@return string
function M.separator_text(label)
  return ('── %s ──'):format(label)
end

return M
