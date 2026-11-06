--- What aineo does for the projects of a tab, in the composition root: the
--- repositories its Claude Code's session works in. The session's own
--- repository is the first project and the changes pane is its pane; another
--- repository joins the tab when the session's transcript shows an edit of a
--- file in a checkout of it, or when an agent reports work in one
--- (`aineo.projects`). Each project has a changes home of its own
--- (`aineo.changes`'s `new()`), its pane shown in the changes pane's windows
--- in place of the others', with a line of tabs over the commits window,
--- `<Tab>` and `<S-Tab>` choosing a project and `X` closing one.
---
--- The projects of a tab are kept for the Claude Code session it follows,
--- and begin again with the session's repository alone as the session
--- changes. Loading it loads no other home: `aineo.projects` and
--- `aineo.changes` are required when a tab first needs them.

local office = require('aineo.entry.office')
local places = require('aineo.entry.places')
local settings = require('aineo.entry.settings')
local tellers = require('aineo.entry.tellers')

local M = {}

--- The key that chooses the next project, in both windows of the pane.
local NEXT_KEY = '<Tab>'

--- The key that chooses the previous project.
local PREVIOUS_KEY = '<S-Tab>'

--- The key that closes the chosen project.
local CLOSE_KEY = 'X'

--- What the base of a project other than the session's is called on the
--- Against line and in the bars of diffs.
local BASE_WORDS = 'first touched'

--- How long after an edit of a project's file, in milliseconds, its count of
--- files is read again.
local RECOUNT_DELAY_MS = 700

--- How long a report waits for the checkout of its folder to be found, in
--- milliseconds.
local LOOKUP_WAIT_MS = 1500

--- The state of one tab's projects.
---@class aineo.entry.TabProjects
---@field looking boolean whether the session's repository was asked for
---@field session_project? aineo.projects.Project the repository of `directory`, once found; nil while git looks and when there is none
---@field id? string the Claude Code session the tab's panes follow
---@field list? aineo.projects.List the projects, once the session's repository is found and a session followed
---@field homes table<string, aineo.changes.Home> the changes home of each project but the session's, by project key
---@field counts table<string, integer> the files of each project's *Session work*, as last read, by project key
---@field recounting table<string, uv.uv_timer_t> the timers that read a project's count again, by project key
---@field checkouts aineo.projects.Checkouts
---@field follower? aineo.transcript.Follower the follower of the session's transcript
---@field full_told boolean whether the user was told the tab holds as many projects as it can
---@field bar_drawn boolean whether a line of tabs was drawn and not yet cleared
---@field listens_to_session_home boolean whether the session's home was asked to tell of the changes it sees
---@field generation integer what tells the answers asked for before the list was last built from the ones asked for since

--- The state of each tab that has a project to follow.
---@type table<aineo.entry.Tab, aineo.entry.TabProjects>
local states = setmetatable({}, { __mode = 'k' })

--- The tab's state, made the first time.
---
---@param tab aineo.entry.Tab
---@return aineo.entry.TabProjects
local function state_of(tab)
  if not states[tab] then
    states[tab] = {
      looking = false,
      homes = {},
      counts = {},
      recounting = {},
      checkouts = require('aineo.projects').new_checkouts(function(folder, done)
        require('aineo.git').find_repository(folder, done)
      end),
      full_told = false,
      bar_drawn = false,
      listens_to_session_home = false,
      generation = 0,
    }
  end
  return states[tab]
end

--- The time now, in milliseconds since the epoch.
---
---@return integer
local function now_ms()
  local seconds, microseconds = vim.uv.gettimeofday()
  return seconds * 1000 + math.floor(microseconds / 1000)
end

--- The changes home of the project `key` names: the tab's own for the
--- session's repository, else the one made for the project.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param key string
---@return aineo.changes.Home|nil
local function home_of(tab, state, key)
  if state.session_project and state.session_project.key == key then
    return tab.homes.changes
  end
  return state.homes[key]
end

--- The changes home of the project that is chosen.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@return aineo.changes.Home
local function chosen_home(tab, state)
  return home_of(tab, state, state.list.chosen().key) or tab.homes.changes
end

--- The projects other than the session's, for keeping.
---
---@param state aineo.entry.TabProjects
---@return aineo.projects.Project[]
local function projects_to_keep(state)
  return state.list.entries()
end

--- Keeps the tab's projects for the session it follows, telling the user
--- when that fails.
---
---@param state aineo.entry.TabProjects
local function keep_projects(state)
  local failure = require('aineo.projects').keep(
    places.kept_places().state_directory,
    state.id,
    projects_to_keep(state)
  )
  if failure then
    vim.notify('aineo: cannot keep the projects of this session: ' .. failure, vim.log.levels.WARN)
  end
end

--- Draws the line of tabs over the commits window of the pane shown, and
--- clears it once the tab holds one project again.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
local function draw_tab_line(tab, state)
  if not state.list then
    return
  end
  local entries = state.list.entries()
  local line = require('aineo.projects').tab_line(entries, state.list.chosen().key, state.counts)
  if line == '' and not state.bar_drawn then
    return
  end
  state.bar_drawn = line ~= ''
  require('aineo.projects').define_colours()
  local commits = chosen_home(tab, state).pane_buffers().commits
  for _, window in ipairs(vim.fn.win_findbuf(commits)) do
    vim.api.nvim_set_option_value('winbar', line, { scope = 'local', win = window })
  end
end

--- Reads again the count of the files of *Session work* of the project `key`
--- names, and draws the line of tabs once it is read.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param key string
local function recount(tab, state, key)
  local home = home_of(tab, state, key)
  if not home then
    return
  end
  local generation = state.generation
  home.count_session_work(function(count)
    if states[tab] ~= state or state.generation ~= generation or count == nil then
      return
    end
    state.counts[key] = count
    draw_tab_line(tab, state)
  end)
end

--- Reads again the count of every project, as the tab's projects change.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
local function recount_all(tab, state)
  for _, project in ipairs(state.list.entries()) do
    recount(tab, state, project.key)
  end
end

--- Reads again the count of the project `key` names after `RECOUNT_DELAY_MS`,
--- once for the edits that come before it is over: the file an edit names is
--- written a moment after the call is seen.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param key string
local function recount_soon(tab, state, key)
  local pending = state.recounting[key]
  if pending then
    pending:stop()
  else
    pending = vim.uv.new_timer()
    state.recounting[key] = pending
  end
  pending:start(
    RECOUNT_DELAY_MS,
    0,
    vim.schedule_wrap(function()
      if states[tab] == state and state.list then
        recount(tab, state, key)
      end
    end)
  )
end

--- Stops and closes every timer that reads a count again.
---
---@param state aineo.entry.TabProjects
local function stop_recounting(state)
  for key, timer in pairs(state.recounting) do
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    state.recounting[key] = nil
  end
end

--- Shows the pane of the home of the project that is chosen in the changes
--- pane's windows, in place of the pane they show, and stops the watch of
--- the home that left; the home that enters starts its own as its buffers
--- enter the windows (`aineo.changes`).
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param left aineo.changes.Home the home whose pane was shown
local function show_chosen_project(tab, state, left)
  local home = chosen_home(tab, state)
  tab.homes.layout.replace_changes_pane(home.pane_buffers())
  if home ~= left then
    left.stop_watching()
  end
  draw_tab_line(tab, state)
  if #state.list.entries() > 1 then
    recount_all(tab, state)
  end
end

--- Chooses the project `move` picks and shows its pane.
---
---@param tab aineo.entry.Tab
---@param move fun(list: aineo.projects.List)
local function choose(tab, move)
  local state = states[tab]
  if not (state and state.list) then
    return
  end
  local left = chosen_home(tab, state)
  move(state.list)
  show_chosen_project(tab, state, left)
end

--- The name the user knows a project by: its checkout folder's name.
---
---@param project aineo.projects.Project
---@return string
local function name_of(project)
  local name = vim.fs.basename(project.top)
  return name == '' and project.top or name
end

--- Closes the chosen project unless it is the session's: its pane gives way
--- to the previous project's, and its home is let go.
---
---@param tab aineo.entry.Tab
local function close_chosen(tab)
  local state = states[tab]
  if not (state and state.list) then
    return
  end
  local closing = state.list.chosen()
  local home = home_of(tab, state, closing.key)
  if not state.list.close(closing.key) then
    vim.notify(
      "aineo: the session's own project stays; close another with " .. CLOSE_KEY,
      vim.log.levels.INFO
    )
    return
  end
  state.homes[closing.key], state.counts[closing.key] = nil, nil
  show_chosen_project(tab, state, home)
  keep_projects(state)
  home.let_go()
end

--- Maps the keys that choose and close projects in `pane`'s two buffers, and
--- has the line of tabs drawn whenever the commits buffer enters a window.
---
---@param tab aineo.entry.Tab
---@param pane { files: integer, commits: integer }
local function prepare_pane(tab, pane)
  for _, buffer in ipairs({ pane.files, pane.commits }) do
    local function map(lhs, action, description)
      vim.keymap.set('n', lhs, action, { buffer = buffer, nowait = true, desc = description })
    end
    map(NEXT_KEY, function()
      choose(tab, function(list)
        list.choose_next()
      end)
    end, 'aineo: show the next project')
    map(PREVIOUS_KEY, function()
      choose(tab, function(list)
        list.choose_previous()
      end)
    end, 'aineo: show the previous project')
    map(CLOSE_KEY, function()
      close_chosen(tab)
    end, 'aineo: close the project shown')
  end
  if not vim.b[pane.commits].aineo_projects_prepared then
    vim.b[pane.commits].aineo_projects_prepared = true
    vim.api.nvim_create_autocmd('BufWinEnter', {
      buffer = pane.commits,
      desc = 'aineo: draw the line of project tabs',
      callback = function()
        local state = states[tab]
        if state then
          draw_tab_line(tab, state)
        end
      end,
    })
  end
end

--- Makes the changes home of `project`: its session is the Claude Code
--- session's, its base `HEAD` now.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param project aineo.projects.Project
---@return aineo.changes.Home
local function make_home(tab, state, project)
  local config = settings.resolved()
  local home = require('aineo.changes').new()
  home.follow_changes_session({
    id = require('aineo.projects').followed_id(state.id, project),
    state_directory = places.kept_places().state_directory,
  })
  home.begin_session({
    directory = project.top,
    show_diff = function(diff)
      return tab.homes.layout.show_diff(diff)
    end,
    working_branch = config.changes.working_branch,
    graph_limit = config.changes.graph_limit,
    edit_file_key = config.prefix and config.prefix .. '<CR>' or nil,
    show_changes_pane = function()
      tab.show_pane('changes')
    end,
    base_words = BASE_WORDS,
  })
  home.on_repository_change(function()
    if states[tab] == state and state.list then
      recount(tab, state, project.key)
    end
  end)
  state.homes[project.key] = home
  return home
end

--- Tells the user a project joined, naming the key of the changes pane.
---
---@param tab aineo.entry.Tab
---@param project aineo.projects.Project
---@param cause 'edited'|'reported'
local function tell_joined(tab, project, cause)
  local prefix = settings.resolved().prefix
  local where = prefix and prefix .. 'g' or ':Aineo pane changes'
  local what = cause == 'edited' and 'Claude Code changed ' or 'reported work in '
  tellers.for_tab(tab)(("aineo: %s%s; it's now a tab in %s"):format(what, name_of(project), where))
end

--- Takes the project into the tab: its home is made and its tab joins the
--- line, the chosen project and the view unchanged. Tells the user, once for
--- a tab that cannot hold more, why nothing joins.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param met aineo.projects.Project the project, as a checkout of it was met
---@param quiet? boolean tell the user nothing of its joining
---@return aineo.changes.Home|nil home the project's home; nil when it did not join and has none
local function join(tab, state, met, quiet)
  local project = { key = met.key, top = met.top, joined = now_ms() }
  local answer = state.list.join(project)
  if answer == 'known' then
    return home_of(tab, state, project.key)
  end
  if answer == 'full' then
    if not state.full_told then
      state.full_told = true
      vim.notify(
        ('aineo: this tab holds %d projects already; close one with %s in the changes pane'):format(
          require('aineo.projects').MOST,
          CLOSE_KEY
        ),
        vim.log.levels.WARN
      )
    end
    return nil
  end
  local home = make_home(tab, state, project)
  prepare_pane(tab, home.pane_buffers())
  prepare_pane(tab, tab.homes.changes.pane_buffers())
  keep_projects(state)
  draw_tab_line(tab, state)
  recount_all(tab, state)
  if not quiet then
    tell_joined(tab, project, 'edited')
  end
  return home
end

--- Takes in the edit a signal of the session's transcript tells of: the
--- project of the checkout the file is in joins when it is another
--- repository's, and a project's count is read again soon. A signal replayed
--- from the transcript's tail as the follower starts is nothing new: the
--- projects kept for the session already hold what it told.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param signal aineo.transcript.Signal
local function take_edit(tab, state, signal)
  local path = not signal.replayed and require('aineo.projects').edited_path(signal)
  if not path then
    return
  end
  local generation = state.generation
  state.checkouts.lookup(path, function(project)
    if not (project and states[tab] == state and state.generation == generation and state.list) then
      return
    end
    if not state.list.has(project.key) then
      join(tab, state, project)
    end
    recount_soon(tab, state, project.key)
  end)
end

--- Stops following the session's transcript, when one is followed.
---
---@param state aineo.entry.TabProjects
local function stop_following_transcript(state)
  if state.follower then
    state.follower.stop()
    state.follower = nil
  end
end

--- Follows the transcript of the session the tab's panes follow, and takes
--- in the edits it tells of (`take_edit()`), in place of the transcript
--- followed before.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
local function follow_transcript(tab, state)
  stop_following_transcript(state)
  local path = state.id and office.transcript_for_session(tab, state.id)
  if not path then
    return
  end
  state.follower = require('aineo.transcript').follow({
    path = path,
    since = office.following_since(tab),
    on_signal = function(signal)
      if states[tab] == state and state.list then
        take_edit(tab, state, signal)
      end
    end,
  })
end

--- Lets the homes of the projects but the session's go, and forgets what was
--- read of them.
---
---@param state aineo.entry.TabProjects
local function let_homes_go(state)
  for key, home in pairs(state.homes) do
    state.homes[key] = nil
    home.let_go()
  end
  state.counts = {}
  stop_recounting(state)
end

--- Builds the tab's projects for the session the panes follow: the session's
--- repository first, then those kept for the session, each with a home of
--- its own, the session's chosen and its pane shown; follows the session's
--- transcript from then on.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
local function rebuild(tab, state)
  if not (state.session_project and state.id) then
    return
  end
  state.generation = state.generation + 1
  if state.list and state.list.chosen().key ~= state.session_project.key then
    tab.homes.layout.replace_changes_pane(tab.homes.changes.pane_buffers())
  end
  let_homes_go(state)
  local kept = require('aineo.projects').read_kept(places.kept_places().state_directory, state.id)
  state.list = require('aineo.projects').new_list(state.session_project, kept)
  state.full_told = false
  for _, project in ipairs(state.list.entries()) do
    if project.key ~= state.session_project.key then
      make_home(tab, state, project)
    end
  end
  if not state.listens_to_session_home then
    state.listens_to_session_home = true
    tab.homes.changes.on_repository_change(function()
      if states[tab] == state and state.list then
        recount(tab, state, state.session_project.key)
      end
    end)
  end
  for _, project in ipairs(state.list.entries()) do
    prepare_pane(tab, home_of(tab, state, project.key).pane_buffers())
  end
  show_chosen_project(tab, state, tab.homes.changes)
  follow_transcript(tab, state)
end

--- Tells the tab's projects the folder its Claude Code started in, whose
--- repository is the first project; looks for it, off the main loop. Heeds
--- the first call alone.
---
---@param tab aineo.entry.Tab
---@param directory string
function M.began(tab, directory)
  local state = state_of(tab)
  if state.looking or state.session_project then
    return
  end
  state.looking = true
  require('aineo.git').find_repository(directory, function(failure, repository)
    if states[tab] ~= state or failure or not repository then
      return
    end
    state.session_project = { key = repository.common_directory, top = repository.top }
    rebuild(tab, state)
  end)
end

--- Tells the tab's projects the Claude Code session its panes follow is
--- `id`: the projects kept for it are the tab's from then on, the session's
--- repository alone when none were kept. Does nothing for the session
--- followed already.
---
---@param tab aineo.entry.Tab
---@param id string
function M.follow_session(tab, id)
  local state = state_of(tab)
  if state.id == id then
    return
  end
  state.id = id
  rebuild(tab, state)
end

--- Tells the tab's projects the transcript of the session was named, so that
--- it is followed where the name says.
---
---@param tab aineo.entry.Tab
function M.transcript_named(tab)
  local state = states[tab]
  if state and state.list then
    follow_transcript(tab, state)
  end
end

--- Hands what is kept for the session `from` over to `to`, which took its
--- place: the projects kept, and the base and saves of each project's home
--- when the tab followed `from`, which it follows as `to` from then on.
---
---@param tab aineo.entry.Tab
---@param from string
---@param to string
function M.hand_over(tab, from, to)
  local state = states[tab]
  local state_directory = places.kept_places().state_directory
  if not (state and state.list and state.id == from) then
    require('aineo.projects').move_kept(state_directory, from, to)
    return
  end
  local projects = require('aineo.projects')
  for key, home in pairs(state.homes) do
    local project = vim.iter(state.list.entries()):find(function(each)
      return each.key == key
    end)
    home.hand_over_changes_session({
      from = projects.followed_id(from, project),
      to = projects.followed_id(to, project),
      state_directory = state_directory,
    })
  end
  projects.move_kept(state_directory, from, to)
  state.id = to
end

--- The pane the layout shows in the changes pane for `tab`: the buffers of
--- the chosen project's home, read again while they are shown.
---
---@param tab aineo.entry.Tab
---@return aineo.layout.ChangesPane
function M.pane_of(tab)
  local state = states[tab]
  local home = state and state.list and chosen_home(tab, state) or tab.homes.changes
  home.refresh_shown_pane()
  local pane = home.pane_buffers()
  if state and state.list then
    prepare_pane(tab, pane)
  end
  return pane
end

--- The folders of the tab's projects, and of the worktrees reported in them,
--- whose files a walkthrough may show.
---
---@param tab aineo.entry.Tab
---@return string[]
function M.folders(tab)
  local state = states[tab]
  if not (state and state.list) then
    return {}
  end
  local folders = {}
  for _, project in ipairs(state.list.entries()) do
    table.insert(folders, project.top)
    local home = home_of(tab, state, project.key)
    if home then
      vim.list_extend(folders, home.reported_worktree_tops())
    end
  end
  return folders
end

--- The name of the project of the tab the checkout at `root` belongs to when
--- it is not the session's; nil for the session's own, for a checkout of a
--- repository that is no project of the tab, and when the checkout is not
--- found in time (`LOOKUP_WAIT_MS`).
---
---@param tab aineo.entry.Tab
---@param root string the top of a checkout
---@return string|nil
function M.name_of_root(tab, root)
  local state = states[tab]
  if not (state and state.list) then
    return nil
  end
  local answered, found = false, nil
  state.checkouts.lookup_folder(root, function(project)
    answered, found = true, project
  end)
  vim.wait(LOOKUP_WAIT_MS, function()
    return answered
  end, 5)
  if not found or found.key == state.session_project.key then
    return nil
  end
  local listed = vim.iter(state.list.entries()):find(function(each)
    return each.key == found.key
  end)
  return listed and name_of(listed) or nil
end

--- The changes home a report of the worktree `work` names goes to: the
--- session's, unless the worktree is a checkout of another repository and
--- the report lists a branch, when it is that repository's project's, which
--- joins the tab if it has not, or the reason the report is refused when the
--- tab cannot hold one more. Waits for the checkout of the worktree's
--- folder to be found, at most `LOOKUP_WAIT_MS`; a folder that is no checkout
--- of any repository, and one whose checkout is not found in time, are the
--- session's.
---
---@param tab aineo.entry.Tab
---@param work aineo.changes.ReportedWork
---@return aineo.changes.Home|nil home nil when the report is refused
---@return string|nil refusal why the report is refused, in words for the agent
function M.home_for_report(tab, work)
  local state = states[tab]
  if not (state and state.list) or #work.branches == 0 then
    return tab.homes.changes
  end
  local answered, project = false, nil
  state.checkouts.lookup_folder(work.worktree, function(found)
    answered, project = true, found
  end)
  vim.wait(LOOKUP_WAIT_MS, function()
    return answered
  end, 5)
  if not project or project.key == state.session_project.key then
    return tab.homes.changes
  end
  local known = state.list.has(project.key)
  local home = join(tab, state, project, true)
  if not home then
    return nil,
      ('this tab holds %d projects already; the user closes one in the changes pane'):format(
        require('aineo.projects').MOST
      )
  end
  if not known then
    tell_joined(tab, project, 'reported')
  end
  return home
end

--- Lets the tab's projects go as the tab closes: the transcript is no longer
--- followed, the homes are let go and no timer is left.
---
---@param tab aineo.entry.Tab
function M.let_go(tab)
  local state = states[tab]
  if not state then
    return
  end
  states[tab] = nil
  stop_following_transcript(state)
  let_homes_go(state)
end

return M
