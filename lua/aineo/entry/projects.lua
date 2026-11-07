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
--- The projects of a tab are kept for the Claude Code session it follows:
--- a resume brings them back, a fork of the session carries them, and the
--- projects begin again with the session's repository alone as the session
--- changes otherwise (`/clear`). Loading it loads no other home:
--- `aineo.projects` and `aineo.changes` are required when a tab first needs
--- them.

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
--- milliseconds. With the wait for its branches' bases (`editors.lua`'s
--- `BASE_WAIT_MS`, 3000) it keeps inside the 5 s the report server waits for
--- the editor.
local LOOKUP_WAIT_MS = 1500

--- How often, in milliseconds, the follower of the transcript looks for the
--- transcript and the subagents' folder while they are not there.
local TRANSCRIPT_POLL_MS = 2000

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
---@field edits_waiting string[] the files of edits the transcript told of whose checkouts are not looked up yet, in the order told
---@field looking_up_edit boolean whether the checkout of an edit's file is being looked up
---@field fork_of? { parent: string, child: string } the session `child` is a fork of `parent`: what carries to `child` when it is followed
---@field continued_in? string the session the transcript followed says Claude Code went on in
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
      edits_waiting = {},
      looking_up_edit = false,
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

--- The projects the tab holds, the session's among them, for keeping.
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
  require('aineo.projects').define_colours()
  local commits = chosen_home(tab, state).pane_buffers().commits
  local windows = vim.fn.win_findbuf(commits)
  state.bar_drawn = line ~= '' or #windows == 0
  for _, window in ipairs(windows) do
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
  if not home or #state.list.entries() < 2 then
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

--- The project of the repository `key` names, as the list holds it.
---
---@param state aineo.entry.TabProjects
---@param key string
---@return aineo.projects.Project|nil
local function held_project(state, key)
  return vim.iter(state.list.entries()):find(function(each)
    return each.key == key
  end)
end

--- Takes the checkout `met`, one that was just found to be there, for the
--- project of its repository when the checkout the project was first met in
--- is gone, as a worktree is when its work is done: the project keeps its
--- place, its joining and its base, and its home reads the checkout that is
--- there. Does nothing for the session's own project, for a project whose
--- checkout is there, or for a repository the tab does not hold.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param met aineo.projects.Project
local function take_live_checkout(tab, state, met)
  local held = held_project(state, met.key)
  local is_session_project = state.session_project.key == met.key
  if not held or is_session_project or held.top == met.top or vim.uv.fs_stat(held.top) then
    return
  end
  local left = chosen_home(tab, state)
  local gone = state.homes[met.key]
  state.list.retop(met.key, met.top)
  state.homes[met.key] = nil
  require('aineo.changes').retop_kept_session(
    places.kept_places().state_directory,
    require('aineo.projects').followed_id(state.id, held),
    met.top
  )
  local home = make_home(tab, state, vim.tbl_extend('force', held, { top = met.top }))
  prepare_pane(tab, home.pane_buffers())
  show_chosen_project(tab, state, left)
  keep_projects(state)
  if gone then
    gone.let_go()
  end
end

--- Looks up the checkout of the file of the oldest edit waiting
--- (`state.edits_waiting`) and takes the edit in: the project of the checkout
--- joins when it is another repository's, and a project's count is read
--- again soon; then the next edit waiting is taken. One edit at a time, so
--- that projects join in the order the edits were made, not the order git
--- answers.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
local function take_next_edit(tab, state)
  local path = table.remove(state.edits_waiting, 1)
  if not path then
    state.looking_up_edit = false
    return
  end
  state.looking_up_edit = true
  local generation = state.generation
  state.checkouts.lookup(path, function(project)
    if project and states[tab] == state and state.generation == generation and state.list then
      if not state.list.has(project.key) then
        join(tab, state, project)
      else
        take_live_checkout(tab, state, project)
      end
      recount_soon(tab, state, project.key)
    end
    if states[tab] == state then
      take_next_edit(tab, state)
    end
  end)
end

--- Takes in the edit a signal of the session's transcript tells of
--- (`take_next_edit()`), after those told before it. A signal replayed from
--- the transcript's tail as the follower starts is nothing new: the projects
--- kept for the session already hold what it told. Nor is a line stamped
--- before the tab began following the session: a fork's file may hold its
--- parent's history.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
---@param signal aineo.transcript.Signal
local function take_edit(tab, state, signal)
  local path = not signal.replayed and require('aineo.projects').edited_path(signal)
  if not path then
    return
  end
  local since = office.following_since(tab)
  if signal.at and since and signal.at < since then
    return
  end
  table.insert(state.edits_waiting, path)
  if not state.looking_up_edit then
    take_next_edit(tab, state)
  end
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

--- Defined below, with the follower it starts.
---@type fun(tab: aineo.entry.Tab, state: aineo.entry.TabProjects)
local follow_transcript

--- Follows the transcript of the session the tab's panes follow, and takes
--- in the edits it tells of (`take_edit()`), in place of the transcript
--- followed before; when the transcript says Claude Code went on in another
--- session, it follows that one, as the office does. Looks for a transcript
--- that is not there yet no oftener than every `TRANSCRIPT_POLL_MS`.
---
---@param tab aineo.entry.Tab
---@param state aineo.entry.TabProjects
function follow_transcript(tab, state)
  stop_following_transcript(state)
  local path = state.id and office.transcript_for_session(tab, state.id)
  if not path then
    return
  end
  state.follower = require('aineo.transcript').follow({
    path = path,
    since = office.following_since(tab),
    poll_ms = TRANSCRIPT_POLL_MS,
    on_signal = function(signal)
      if signal.kind == 'session_continued' then
        state.continued_in = signal.session
        if not signal.replayed then
          vim.schedule(function()
            if states[tab] == state and state.list then
              follow_transcript(tab, state)
            end
          end)
        end
        return
      end
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
  state.edits_waiting = {}
  state.continued_in = nil
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

--- Copies the projects kept for the session `from`, and each one's base and
--- view, to the session `to`, where `to` has none kept.
---
---@param from string
---@param to string
local function carry_projects(from, to)
  local projects = require('aineo.projects')
  local state_directory = places.kept_places().state_directory
  local kept = projects.read_kept(state_directory, from)
  if not kept or projects.read_kept(state_directory, to) then
    return
  end
  projects.keep(state_directory, to, kept)
  for _, project in ipairs(kept) do
    require('aineo.changes').copy_kept_session(
      state_directory,
      projects.followed_id(from, project),
      projects.followed_id(to, project)
    )
  end
end

--- Tells the tab's projects the Claude Code session its panes follow is
--- `id`: the projects kept for it are the tab's from then on, the session's
--- repository alone when none were kept. A session provably the same
--- conversation as the one followed before carries that one's projects and
--- their bases, when it has none kept: one that `fork_of()` named, or one the
--- transcript followed says Claude Code went on in. Any other carries
--- nothing. Does nothing for the session followed already.
---
---@param tab aineo.entry.Tab
---@param id string
function M.follow_session(tab, id)
  local state = state_of(tab)
  if state.id == id then
    return
  end
  local fork = state.fork_of
  local parent = fork and fork.child == id and fork.parent
    or state.continued_in == id and state.id
    or nil
  if fork and fork.child == id then
    state.fork_of = nil
  end
  if parent and parent ~= id then
    carry_projects(parent, id)
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
--- place: the projects kept, and the base, the saves and the view of each
--- project, whether or not the tab follows `from`; a tab that follows `from`
--- follows `to` from then on.
---
---@param tab aineo.entry.Tab
---@param from string
---@param to string
function M.hand_over(tab, from, to)
  local state = states[tab]
  local state_directory = places.kept_places().state_directory
  local projects = require('aineo.projects')
  if not (state and state.list and state.id == from) then
    for _, project in ipairs(projects.read_kept(state_directory, from) or {}) do
      require('aineo.changes').move_kept_session(
        state_directory,
        projects.followed_id(from, project),
        projects.followed_id(to, project)
      )
    end
    projects.move_kept(state_directory, from, to)
    return
  end
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

--- The changes home of the project that is chosen in `tab`, the tab's own
--- home while the tab holds one project.
---
---@param tab aineo.entry.Tab
---@return aineo.changes.Home
function M.chosen_changes(tab)
  local state = states[tab]
  return state and state.list and chosen_home(tab, state) or tab.homes.changes
end

--- Tells the tab's projects that the session `child` is a fork of `parent`:
--- once the panes follow `child`, the projects kept for `parent`, and each
--- one's base, are the fork's too, as a resume's are, when it has none of
--- its own. No other session followed carries them.
---
---@param tab aineo.entry.Tab
---@param parent string
---@param child string
function M.fork_of(tab, parent, child)
  state_of(tab).fork_of = { parent = parent, child = child }
end

--- Closes the diffs the tab's projects showed: those of every project's
--- home that shows one, not only the project shown. When none shows one, the
--- project shown tells the user there is none to close.
---
---@param tab aineo.entry.Tab
function M.close_shown_diff(tab)
  local state = states[tab]
  local homes = { M.chosen_changes(tab) }
  if state and state.list then
    for _, project in ipairs(state.list.entries()) do
      table.insert(homes, home_of(tab, state, project.key))
    end
  end
  local closed = false
  for _, home in ipairs(homes) do
    if home.has_shown_diff() then
      home.close_shown_diff()
      closed = true
    end
  end
  if not closed then
    homes[1].close_shown_diff()
  end
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

--- The main checkout of the repository whose common git directory is `key`:
--- the folder above `.git`; nil for a bare repository, which has none.
---
---@param key string
---@return string|nil
local function main_checkout_of(key)
  if vim.fs.basename(key) == '.git' then
    return vim.fs.dirname(key)
  end
  return nil
end

--- The folders of the tab's projects, whose files a walkthrough may show:
--- each project's checkout, the main checkout of its repository, and the
--- worktrees reported in it that git still lists.
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
    local main = main_checkout_of(project.key)
    if main then
      table.insert(folders, main)
    end
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
  local entries = state.list.entries()
  local names = require('aineo.projects').names(entries)
  for position, each in ipairs(entries) do
    if each.key == found.key then
      return names[position]
    end
  end
  return nil
end

--- The changes home a report of the worktree `work` names goes to: the
--- session's, unless the worktree's folder is there and is the top of a
--- checkout of another repository. The report of a project the tab holds goes
--- to that project's home, whatever branches it lists, a checkout that is
--- there taking the place of one that is gone. The report of a repository the
--- tab does not hold, listing a branch, makes it a project, joining the tab;
--- listing none it goes to the session's home, with a note that no project
--- joined, which the agent is told and is no refusal. A report of a folder
--- inside a checkout of another repository, not its top, is refused saying
--- the top is needed when it lists a branch, and taken with the same note as
--- any report of no branch when it lists none; one that would make the tab
--- hold more projects than it can is refused. The checkout is the one `work.found` carries when
--- `resolve_reported_work()` found it, else it is looked up, at most
--- `LOOKUP_WAIT_MS`, asking git afresh; a folder that is not there, one that
--- is no checkout of any repository, and one whose checkout is not found in
--- time, are the session's.
---
---@param tab aineo.entry.Tab
---@param work aineo.changes.ReportedWork
---@return aineo.changes.Home|nil home nil when the report is refused
---@return string|nil refusal why the report is refused, in words for the agent
---@return string|nil note what the agent is told besides that the report was taken
function M.home_for_report(tab, work)
  local state = states[tab]
  if not (state and state.list) then
    return tab.homes.changes
  end
  local answered, project, enclosing = false, nil, nil
  if work.found ~= nil then
    answered = true
    if work.found then
      local met = { key = work.found.common_directory, top = work.found.top }
      if work.found.top == vim.uv.fs_realpath(work.worktree) then
        project = met
      else
        enclosing = met
      end
    end
  else
    state.checkouts.lookup_checkout(work.worktree, function(found, inside)
      answered, project, enclosing = true, found, inside
    end)
  end
  vim.wait(LOOKUP_WAIT_MS, function()
    return answered
  end, 5)
  if not project then
    if enclosing and enclosing.key ~= state.session_project.key then
      if #work.branches == 0 then
        return tab.homes.changes,
          nil,
          ('no project joined: a report needs a branch to join one; report the top of %s'):format(
            enclosing.top
          )
      end
      return nil,
        ("worktree: %s is inside the checkout %s of another repository; report the checkout's top folder"):format(
          work.worktree,
          enclosing.top
        )
    end
    return tab.homes.changes
  end
  if project.key == state.session_project.key then
    return tab.homes.changes
  end
  if state.list.has(project.key) then
    take_live_checkout(tab, state, project)
    return home_of(tab, state, project.key)
  end
  if #work.branches == 0 then
    return tab.homes.changes,
      nil,
      ('no project joined: a report needs a branch to join one; list the branch checked out in %s'):format(
        work.worktree
      )
  end
  local home = join(tab, state, project, true)
  if not home then
    return nil,
      ('this tab holds %d projects already; the user closes one in the changes pane'):format(
        require('aineo.projects').MOST
      )
  end
  tell_joined(tab, project, 'reported')
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
