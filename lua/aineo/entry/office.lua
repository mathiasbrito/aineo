--- The office of each tab, in the composition root: makes a tab's office the
--- first time it is asked to show, hands it what it is not to reach for — the
--- layout's right side, the folders packs are in, the clock and the transcript
--- of the tab's session — and shows it. It keeps the transcript path the
--- tab's `SessionStart` hooks name, and tells the office the tab's
--- permission waits.
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

--- The transcript path each tab's `SessionStart` hooks named, by the tab and
--- then by session (`M.note_transcript()`).
---@type table<aineo.entry.Tab, table<string, string>>
local named_transcripts = setmetatable({}, { __mode = 'k' })

--- Notes that Claude Code writes the transcript of the session `session_id`
--- of `tab` in `path`, as its `SessionStart` hook named it: the path the
--- office follows for that session from then on, in place of a search for it.
---
---@param tab aineo.entry.Tab
---@param session_id string
---@param path string
function M.note_transcript(tab, session_id, path)
  named_transcripts[tab] = named_transcripts[tab] or {}
  named_transcripts[tab][session_id] = path
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
local function transcript_found_for(session_id)
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

--- The transcript of the session `tab` runs: the path its `SessionStart` hook
--- named (`M.note_transcript()`), else the one found by Claude Code's folder
--- rule (`transcript_found_for()`), as when the hook did not run; `nil` when
--- there is none.
---
---@param tab aineo.entry.Tab
---@return string|nil path
local function transcript_of(tab)
  local session_id = tab.session_id()
  local named = session_id and named_transcripts[tab] and named_transcripts[tab][session_id]
  return named or transcript_found_for(session_id)
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
  office.follow_session(transcript_of(tab))
  office.show_now()
end

--- Tells the office `tab` has, if it has made one, that the agent `agent_id`
--- of the session `session_id` waits for the user to answer a permission
--- prompt: the subagent of that id, or `'main'` when `agent_id` is nil. A
--- wait of a session the tab does not run, and one for a tab that has made
--- no office, tell nothing, nor does an office that takes no waits.
---
---@param tab aineo.entry.Tab
---@param session_id string
---@param agent_id string?
function M.take_permission_wait(tab, session_id, agent_id)
  local office = offices[tab]
  if office and office.permission_wait and session_id == tab.session_id() then
    office.permission_wait(agent_id or 'main')
  end
end

return M
