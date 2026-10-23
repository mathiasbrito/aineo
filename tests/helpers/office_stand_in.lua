--- A stand-in for the office module, for the entry suites that are about what
--- the composition root tells each tab's office, not about what the office
--- does: every office it makes keeps what it is told in `_G.office_told`.
---
--- It must take the place of `aineo.office` before the tab is opened: the
--- entry makes a tab's office as the tab opens.

local M = {}

---@class aineo.tests.OfficeTold
---@field made integer the offices made
---@field waits string[] the agent of each `permission_wait()`
---@field reports table[] each report `report_arrived()` was given
---@field let_go integer the `let_go()` calls
---@field session_changed integer the `session_changed()` calls
---@field settings table what the settings the office was given are, as the first office read them

--- The Lua that makes `aineo.office` the stand-in.
M.INSTALL = [[
  _G.office_told = { made = 0, waits = {}, reports = {}, let_go = 0, session_changed = 0 }
  package.loaded['aineo.office'] = {
    new_office = function(options)
      _G.office_told.made = _G.office_told.made + 1
      _G.office_options = options
      _G.office_told.settings = _G.office_told.settings or options.settings()
      return {
        permission_wait = function(agent)
          table.insert(_G.office_told.waits, agent)
        end,
        report_arrived = function(report)
          table.insert(_G.office_told.reports, report)
        end,
        session_changed = function()
          _G.office_told.session_changed = _G.office_told.session_changed + 1
        end,
        follows_session = function()
          return false
        end,
        show_now = function() end,
        let_go = function()
          _G.office_told.let_go = _G.office_told.let_go + 1
        end,
      }
    end,
  }
]]

--- Makes `aineo.office` the stand-in in `child`.
---
---@param child table
function M.install(child)
  child.lua(M.INSTALL)
end

--- What the transcript option of the last stand-in office gives now: the
--- path of the transcript, and when the tab began following its session.
---
---@param child table
---@return string|nil path
---@return number|nil since
function M.transcript_asked(child)
  local asked = child.lua_get('{ _G.office_options.transcript() }')
  return asked[1], asked[2]
end

--- What the stand-in offices were told.
---
---@param child table
---@return aineo.tests.OfficeTold
function M.told(child)
  return child.lua_get('_G.office_told')
end

return M
