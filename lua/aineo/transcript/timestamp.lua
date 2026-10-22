--- The timestamps of a transcript's lines, as seconds. Pure.
---
--- Claude Code stamps a line with an ISO 8601 time in UTC, such as
--- `2026-01-01T00:00:30.509Z`.

local M = {}

local PATTERN = '^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)(%.?%d*)Z$'

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400

--- The days from 1970-01-01 to the given day of the proleptic Gregorian
--- calendar.
---
---@param year integer
---@param month integer 1 to 12
---@param day integer 1 to 31
---@return integer days
local function days_since_1970(year, month, day)
  local shifted_year = month <= 2 and year - 1 or year
  local era = math.floor(shifted_year / 400)
  local year_of_era = shifted_year - era * 400
  local month_from_march = month > 2 and month - 3 or month + 9
  local day_of_year = math.floor((153 * month_from_march + 2) / 5) + day - 1
  local day_of_era = year_of_era * 365
    + math.floor(year_of_era / 4)
    - math.floor(year_of_era / 100)
    + day_of_year
  return era * 146097 + day_of_era - 719468
end

--- Whether the numbers name a time of day and a day of a month.
---
---@param month integer
---@param day integer
---@param hour integer
---@param minute integer
---@param second integer
---@return boolean
local function is_calendar_time(month, day, hour, minute, second)
  return month >= 1
    and month <= 12
    and day >= 1
    and day <= 31
    and hour <= 23
    and minute <= 59
    and second <= 60
end

--- The seconds since 1970-01-01T00:00:00Z that `timestamp` names; `nil` when
--- it is not a string of the form `YYYY-MM-DDTHH:MM:SS[.fraction]Z`.
---
---@param timestamp any
---@return number|nil seconds
function M.seconds_of(timestamp)
  if type(timestamp) ~= 'string' then
    return nil
  end
  local year, month, day, hour, minute, second, fraction = timestamp:match(PATTERN)
  if not year then
    return nil
  end
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
  if not is_calendar_time(month, day, hour, minute, second) then
    return nil
  end
  if fraction ~= '' and fraction:sub(1, 1) ~= '.' then
    return nil
  end
  local fraction_of_second = fraction ~= '' and tonumber('0' .. fraction) or 0
  return days_since_1970(year, month, day) * SECONDS_PER_DAY
    + hour * SECONDS_PER_HOUR
    + minute * SECONDS_PER_MINUTE
    + second
    + fraction_of_second
end

return M
