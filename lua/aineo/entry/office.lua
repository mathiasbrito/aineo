--- The office of each tab, in the composition root: makes a tab's office as
--- the tab's layout opens, so that it counts the user's idleness from then on,
--- hands it what it is not to reach for — the layout's right side, the folders
--- packs are in, the clock, the settings and the transcript of the tab's
--- session — and shows it when asked. It keeps the transcript path the tab's
--- `SessionStart` hooks name, tells the office the tab's permission waits,
--- the reports its Report took, each change of the session the tab shows or
--- of that session's transcript, and the end and the start of the session
--- the tab shows, and lets it go when the tab closes.
---
--- Loading it loads no other home: `aineo.office` is required when an office
--- is first made.

local places = require('aineo.entry.places')
local settings = require('aineo.entry.settings')

local M = {}

--- The office of each tab that has asked for one, by the tab.
---@type table<aineo.entry.Tab, aineo.office.Office>
local offices = setmetatable({}, { __mode = 'k' })

--- The transcript path each tab's `SessionStart` hooks named, by the tab and
--- then by session (`M.note_transcript()`).
---@type table<aineo.entry.Tab, table<string, string>>
local named_transcripts = setmetatable({}, { __mode = 'k' })

--- The transcript Claude Code writes for the session `session_id`:
--- `projects/<folder>/<session id>.jsonl` under its configuration directory
--- (`places.claude_config_directory()`). The regular file of that name in any
--- folder there, if one exists (a named pipe or a folder of that name is not
--- one); else the file it will be in the folder of the working directory the
--- editor started in (`places.folder_transcript()`), which Claude Code makes
--- at the session's first prompt. `nil` when there is no session.
---
---@param session_id string|nil
---@return string|nil path
local function transcript_found_for(session_id)
  if not session_id or not require('aineo.claude').is_session_id(session_id) then
    return nil
  end
  local projects = vim.fs.joinpath(places.claude_config_directory(), 'projects')
  for folder, type in vim.fs.dir(projects) do
    local path = vim.fs.joinpath(projects, folder, session_id .. '.jsonl')
    local stat = type == 'directory' and vim.uv.fs_stat(path)
    if stat and stat.type == 'file' then
      return path
    end
  end
  return places.folder_transcript(session_id)
end

--- The transcript of the session `tab` shows: the session its panes follow,
--- which is another than its own Claude Code's while the tab claims one, else
--- its own. The path its `SessionStart` hook named (`M.note_transcript()`),
--- else the one found by Claude Code's folder rule (`transcript_found_for()`),
--- as when the hook did not run; `nil` when there is none.
---
---@param tab aineo.entry.Tab
---@return string|nil path
local function transcript_of(tab)
  local session_id = tab.panes_session() or tab.session_id()
  local named = session_id and named_transcripts[tab] and named_transcripts[tab][session_id]
  return named or transcript_found_for(session_id)
end

--- The pack `:Aineo office pack` chose for this Neovim, which stands in
--- place of the setting `office.pack`; `nil` until it chose one.
---@type string|nil
local chosen_pack

--- Notes that Claude Code writes the transcript of the session `session_id`
--- of `tab` in `path`, as its `SessionStart` hook named it: the path the
--- office follows for that session from then on, in place of a search for it.
--- When that changes the transcript of the session the tab shows
--- (`transcript_of()`), the office is told (`M.session_changed()`), so that
--- it follows the path named.
---
---@param tab aineo.entry.Tab
---@param session_id string
---@param path string
function M.note_transcript(tab, session_id, path)
  local before = transcript_of(tab)
  named_transcripts[tab] = named_transcripts[tab] or {}
  named_transcripts[tab][session_id] = path
  if transcript_of(tab) ~= before then
    M.session_changed(tab)
  end
end

--- When, in seconds since 1970, each tab began following the session it shows:
--- its Claude Code started, or its session switched (`M.began_following()`);
--- none before the first start, and the follower then looks for no
--- continuation. It looks for the one the tab's own resume wrote from then on.
---@type table<aineo.entry.Tab, number>
local began_following_at = setmetatable({}, { __mode = 'k' })

--- Notes that `tab` begins following the session it shows now: its Claude Code
--- is about to start, or has switched session.
---
---@param tab aineo.entry.Tab
function M.began_following(tab)
  began_following_at[tab] = os.time()
end

--- The settings of the office, `office.*` of aineo's configuration
--- (`aineo.entry.settings`), read each time the office is asked for, with
--- `office.pack` replaced by the pack `M.use_pack()` chose, if it did. Raises
--- the error naming the setting that is wrong.
---
---@return aineo.office.Settings
function M.settings()
  local office_settings = settings.resolved().office
  if chosen_pack then
    return vim.tbl_extend('force', office_settings, { pack = chosen_pack })
  end
  return office_settings
end

--- Makes every office draw the pack `name` from now on in this Neovim, in
--- place of the setting `office.pack`; an office that shows is shown again
--- with it. Nothing is kept past this Neovim. The caller has checked that the
--- pack can be used.
---
---@param name string
function M.use_pack(name)
  chosen_pack = name
  for _, office in pairs(offices) do
    office.reload()
  end
end

--- The pack the offices draw and where that comes from: the names the
--- setting `office.pack` gives, or the one pack `M.use_pack()` chose.
---
---@return string[] names
---@return boolean from_command whether `M.use_pack()` chose it
function M.pack_in_use()
  local pack = M.settings().pack
  return type(pack) == 'table' and pack or { pack }, chosen_pack ~= nil
end

--- The name of the pack the setting `office.pack` names, the first when it
--- lists several. Raises the error naming the setting that is wrong.
---
---@return string
function M.chosen_pack_name()
  local pack = M.settings().pack
  return type(pack) == 'table' and pack[1] or pack
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
      pack_folders = M.pack_folders,
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
      settings = M.settings,
      transcript = function()
        return transcript_of(tab), began_following_at[tab]
      end,
      random = random_pick,
      report_tool = require('aineo.mcp').report_tool_name(),
    })
  end
  return offices[tab]
end

--- Makes the office of `tab`, if it has none, which counts the user's
--- idleness from then on: called as the tab's layout opens in a tab page.
---
---@param tab aineo.entry.Tab
function M.watch(tab)
  office_of(tab)
end

--- Lets the office of `tab` go, if it has one, as the tab closes: its
--- countdown, window and watch end, and the tab has no office until it is
--- watched again.
---
---@param tab aineo.entry.Tab
function M.let_go(tab)
  local office = offices[tab]
  offices[tab] = nil
  if office then
    office.let_go()
  end
end

--- Shows the office of `tab` over the right side of its layout.
---
---@param tab aineo.entry.Tab
function M.show(tab)
  local office = office_of(tab)
  office.show_now()
end

--- Shows the office of `tab` over the right side of its layout as if its
--- session began now: every agent forgotten, the main agent walking in.
---
---@param tab aineo.entry.Tab
function M.reset(tab)
  office_of(tab).reset()
end

--- Previews the pack `name`, or the one the settings name, in the office of
--- `tab`, over the right side of its layout.
---
---@param tab aineo.entry.Tab
---@param name? string
function M.preview(tab, name)
  office_of(tab).preview(name)
end

--- Tells the office `tab` has, if it has one, that the agent `agent_id` of
--- the session `session_id` waits for the user to answer a permission
--- prompt: the subagent of that id, or `'main'` when `agent_id` is nil. A wait
--- of a session the tab neither runs nor shows, nor the office follows (the
--- sessions of its chain, a continuation of the tab's session among them),
--- tells nothing.
---
---@param tab aineo.entry.Tab
---@param session_id string
---@param agent_id string?
function M.take_permission_wait(tab, session_id, agent_id)
  local office = offices[tab]
  local is_of_the_tab = session_id == tab.session_id() or session_id == tab.panes_session()
  if office and (is_of_the_tab or office.follows_session(session_id)) then
    office.permission_wait(agent_id or 'main')
  end
end

--- Tells the office `tab` has, if it has one, that the session the tab shows
--- is another now (its panes follow another, a claim included): the office
--- acts out the transcript the tab names from then on (`aineo.office`'s `session_changed()`).
---
---@param tab aineo.entry.Tab
function M.session_changed(tab)
  local office = offices[tab]
  if office then
    office.session_changed()
  end
end

--- Whether `session_id` is the session `tab` shows: the one its panes follow,
--- which is another than its own Claude Code's while the tab claims one, else
--- its own.
---
---@param tab aineo.entry.Tab
---@param session_id string
---@return boolean
local function is_shown_by(tab, session_id)
  return session_id == (tab.panes_session() or tab.session_id())
end

--- Tells the office `tab` has, if it has one, that the session `session_id`
--- ended, when it is the session the tab shows: the office's main agent
--- leaves (`aineo.office`'s `session_ended()`).
---
---@param tab aineo.entry.Tab
---@param session_id string
function M.session_ended(tab, session_id)
  local office = offices[tab]
  if office and is_shown_by(tab, session_id) then
    office.session_ended()
  end
end

--- Tells the office `tab` has, if it has one, that the session `session_id`
--- started, when it is the session the tab shows: after an end, the
--- office's main agent walks in (`aineo.office`'s `session_started()`).
---
---@param tab aineo.entry.Tab
---@param session_id string
function M.session_started(tab, session_id)
  local office = offices[tab]
  if office and is_shown_by(tab, session_id) then
    office.session_started()
  end
end

--- Tells the office `tab` has, if it has one, a report the tab's Report took.
---
---@param tab aineo.entry.Tab
---@param report table the report's arguments
function M.report_arrived(tab, report)
  local office = offices[tab]
  if office then
    office.report_arrived(report)
  end
end

return M
