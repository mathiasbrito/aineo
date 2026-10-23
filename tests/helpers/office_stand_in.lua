--- A stand-in for the office module, for the entry suites that are about what
--- the composition root tells each tab's office, not about what the office
--- does: every office it makes keeps what it is told in `_G.office_told`.
---
--- It must take the place of `aineo.office` before the tab is opened: the
--- entry makes a tab's office as the tab opens.

local M = {}

---@class aineo.tests.OfficeTold
---@field made integer the offices made
---@field follows any[] the transcript path of each `follow_session()`, `vim.NIL` for none
---@field waits string[] the agent of each `permission_wait()`
---@field reports table[] each report `report_arrived()` was given
---@field let_go integer the `let_go()` calls
---@field settings table what the settings the office was given are, as the first office read them

--- The Lua that makes `aineo.office` the stand-in.
M.INSTALL = [[
  _G.office_told = { made = 0, follows = {}, waits = {}, reports = {}, let_go = 0 }
  package.loaded['aineo.office'] = {
    new_office = function(options)
      _G.office_told.made = _G.office_told.made + 1
      _G.office_told.settings = _G.office_told.settings or options.settings()
      return {
        follow_session = function(path)
          table.insert(_G.office_told.follows, path or vim.NIL)
        end,
        permission_wait = function(agent)
          table.insert(_G.office_told.waits, agent)
        end,
        report_arrived = function(report)
          table.insert(_G.office_told.reports, report)
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

--- What the stand-in offices were told.
---
---@param child table
---@return aineo.tests.OfficeTold
function M.told(child)
  return child.lua_get('_G.office_told')
end

return M
