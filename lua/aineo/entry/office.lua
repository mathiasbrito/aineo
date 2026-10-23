--- The office of each tab, in the composition root: makes a tab's office the
--- first time it is asked to show, hands it what it is not to reach for — the
--- layout's right side, the folders packs are in, the clock, the settings and
--- the transcript of the tab's session — and shows it.
---
--- Loading it loads no other home: `aineo.office` is required when an office
--- is first made.

local settings = require('aineo.entry.settings')

local M = {}

--- The office of each tab that has asked for one, by the tab.
---@type table<aineo.entry.Tab, aineo.office.Office>
local offices = setmetatable({}, { __mode = 'k' })

--- Claude Code's configuration directory: `$CLAUDE_CONFIG_DIR`, else `.claude`
--- in the user's home.
---
---@return string
local function claude_config_directory()
  local configured = vim.env.CLAUDE_CONFIG_DIR
  if configured and configured ~= '' then
    return configured
  end
  return vim.fs.joinpath(vim.uv.os_homedir(), '.claude')
end

--- The transcript Claude Code writes for the session `session_id`:
--- `projects/<folder>/<session id>.jsonl` under its configuration directory,
--- the folder being named after the session's working directory; `nil` when
--- there is no session or no such file.
---
---@param session_id string|nil
---@return string|nil path
local function transcript_of(session_id)
  if not session_id or not require('aineo.claude').is_session_id(session_id) then
    return nil
  end
  local projects = vim.fs.joinpath(claude_config_directory(), 'projects')
  for folder, type in vim.fs.dir(projects) do
    local path = vim.fs.joinpath(projects, folder, session_id .. '.jsonl')
    if type == 'directory' and vim.uv.fs_stat(path) then
      return path
    end
  end
  return nil
end

--- The settings of the office, `office.*` of aineo's configuration
--- (`aineo.entry.settings`), read each time the office is asked for. Raises
--- the error naming the setting that is wrong.
---
---@return aineo.office.Settings
function M.settings()
  return settings.resolved().office
end

--- The folders packs are in: the `aineo-office` folders of 'runtimepath'.
---
---@return string[]
function M.pack_folders()
  return vim.api.nvim_get_runtime_file('aineo-office', true)
end

--- A whole number from 1 to `count`, picked at random.
---
---@param count integer
---@return integer
local function random_pick(count)
  return math.random(count)
end

--- The office of `tab`, made the first time.
---
---@param tab aineo.entry.Tab
---@return aineo.office.Office
local function office_of(tab)
  if not offices[tab] then
    offices[tab] = require('aineo.office').new_office({
      right_side = tab.homes.layout.right_column_area,
      pack_folders = M.pack_folders(),
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
      settings = M.settings,
      random = random_pick,
      commands = settings.resolved().office.commands,
      report_tool = require('aineo.mcp').report_tool_name(),
    })
  end
  return offices[tab]
end

--- Shows the office of `tab` over the right side of its layout, following the
--- transcript of the session its Claude Code runs.
---
---@param tab aineo.entry.Tab
function M.show(tab)
  local office = office_of(tab)
  office.follow_session(transcript_of(tab.session_id()))
  office.show_now()
end

return M
