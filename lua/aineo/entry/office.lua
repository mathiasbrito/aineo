--- The office of each tab, in the composition root: makes a tab's office the
--- first time it is asked to show, hands it what it is not to reach for — the
--- layout's right side, the folders packs are in, the clock and the transcript
--- of the tab's session — and shows it.
---
--- Loading it loads no other home: `aineo.office` is required when an office
--- is first made.

local places = require('aineo.entry.places')
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
--- `projects/<folder>/<session id>.jsonl` under its configuration directory.
--- The regular file of that name in any folder there, if one exists (a named
--- pipe or a folder of that name is not one); else the file it will be in the
--- folder named after the working directory the editor started in, every
--- character of whose path but a letter or a digit is a dash, which Claude Code
--- makes at the session's first prompt. `nil` when there is no session.
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
    local stat = type == 'directory' and vim.uv.fs_stat(path)
    if stat and stat.type == 'file' then
      return path
    end
  end
  local folder = vim.fn.substitute(places.kept_places().working_directory, '[^a-zA-Z0-9]', '-', 'g')
  return vim.fs.joinpath(projects, folder, session_id .. '.jsonl')
end

--- The office of `tab`, made the first time.
---
---@param tab aineo.entry.Tab
---@return aineo.office.Office
local function office_of(tab)
  if not offices[tab] then
    offices[tab] = require('aineo.office').new_office({
      right_side = tab.homes.layout.right_column_area,
      pack_folders = vim.api.nvim_get_runtime_file('aineo-office', true),
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
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
