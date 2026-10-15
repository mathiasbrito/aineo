local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Codes it runs, if any, have ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- Sessions of the form Claude Code gives, for the tabs of a list.
local FIRST = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
local SECOND = 'bbbbbbbb-bbbb-4bbb-9bbb-bbbbbbbbbbbb'
local THIRD = 'cccccccc-cccc-4ccc-accc-cccccccccccc'

--- The short id of a session that runs in Claude Code's background service.
local SHORT_ID = 'a1b2c3d4'

--- The words of `argv` that follow `flag`, for each of the starts of `fake`
--- among its first `count`, once it has started that many times, in the
--- order of the words.
---
---@param fake { record: string }
---@param count integer
---@param flag string
---@return string[]
local function sorted_words_after(fake, count, flag)
  local words = {}
  for _, start in ipairs(claude_session.wait_for_starts(fake, count)) do
    vim.list_extend(words, claude_session.words_after(start.argv, flag))
  end
  table.sort(words)
  return words
end

--- Gives the child the state directory of the case `name`, keeps `list` as
--- the folder's tabs and `kept` as the session kept for the folder in it,
--- and makes aineo run a fake `claude` for the case, in `fake_options.mode`
--- (`ready` by default) with `fake_options.environment` on top.
---
---@param name string
---@param list { sessions: string[], current: integer }
---@param kept string
---@param fake_options? { mode: string?, environment: table<string, string>? }
---@return string state
---@return string folder
---@return { record: string, environment: table<string, string> } fake
local function reopening_setup(name, list, kept, fake_options)
  fake_options = fake_options or {}
  local state = tabs.use_own_state(child, name)
  local folder = child.fn.getcwd()
  tabs.keep_tab_list(state, folder, list)
  tabs.keep_session_id(state, folder, kept)
  local fake = tabs.fake(name, fake_options.mode, fake_options.environment)
  entry.use_fake(child, fake)
  return state, folder, fake
end

--- The session each of the tabs numbered by `keys` keeps among the running
--- editors, once its Claude Code is ready.
---
---@param state string
---@param keys string[]
---@return string[]
local function sessions_of_tabs(state, keys)
  return vim.tbl_map(function(key)
    return tabs.session_of_tab(state, child, key)
  end, keys)
end

--- A fake `claude` that ignores every key, the hangup and SIGTERM
--- (`tests/helpers/fake_claude_deaf.sh`) for the case `name`, and the
--- `claude.cmd` that runs it.
---
---@param name string
---@return { record: string, environment: table<string, string> } fake
---@return table settings the `vim.g.aineo` that makes aineo run it
local function deaf_claude(name)
  return tabs.fake(name, 'deaf'), { claude = { cmd = claude_session.deaf_fake_command() } }
end

--- Has the process group of the deaf fake `pid` killed when the case is over,
--- so that none outlives it.
---
---@param pid integer
local function kill_deaf_after_case(pid)
  MiniTest.finally(function()
    pcall(vim.uv.kill, -pid, 'sigkill')
  end)
end

T['the folder’s list'] = MiniTest.new_set()

T['the folder’s list']['is kept as tabs open and close, and a closed tab is no longer in it'] = function()
  local state = tabs.open_first_tab(child, 'reopen-keeps')
  local folder = child.fn.getcwd()
  local first = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  tabs.use_next_fake(child, tabs.fake('reopen-keeps-second'))
  child.cmd('Aineo tab new')
  local second = tabs.session_of_tab(state, child, '2')
  local opened = tabs.kept_tab_list_once(state, folder, function(list)
    return list ~= nil and #list.sessions == 2
  end)

  child.cmd('tabclose')

  local closed = tabs.kept_tab_list_once(state, folder, function(list)
    return list ~= nil and #list.sessions == 1
  end)
  eq(opened, { sessions = { first, second }, current = 2 })
  eq(closed, { sessions = { first }, current = 1 })
end

T['the folder’s list']['is kept as a tab opens, before its Claude Code is ready'] = function()
  local state = tabs.open_first_tab(child, 'reopen-keeps-unready')
  local folder = child.fn.getcwd()
  local first = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  local unready = tabs.fake('reopen-keeps-unready-second', 'exit')
  tabs.use_next_fake(child, unready)

  child.cmd('Aineo tab new')

  local list = tabs.kept_tab_list_once(state, folder, function(kept)
    return kept ~= nil and #kept.sessions == 2
  end)
  eq(list, { sessions = { first, tabs.new_id_of_start(unready, 1) }, current = 2 })
end

T['the folder’s list']['is kept when a tab’s session changes'] = function()
  local state = tabs.open_first_tab(child, 'reopen-keeps-switch')
  local folder = child.fn.getcwd()
  local before = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  claude_session.press_keys(child, tabs.claude_terminal_of_tab(child, 1), '/clear\r')

  local after = tabs.kept_tab_list_once(state, folder, function(list)
    return list ~= nil and list.sessions[1] ~= before
  end)

  eq(#after.sessions, 1)
  eq(after.sessions[1], claude_session.followed_session_id(child))
  MiniTest.expect.no_equality(after.sessions[1], before)
end

T['the folder’s list']['is kept in the order of the tab pages, not of the tabs’ opening'] = function()
  local state = tabs.open_first_tab(child, 'reopen-keeps-order')
  local folder = child.fn.getcwd()
  local first = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  tabs.use_next_fake(child, tabs.fake('reopen-keeps-order-second'))
  child.cmd('Aineo tab new')
  local second = tabs.session_of_tab(state, child, '2')
  child.cmd('tabmove 0')
  tabs.use_next_fake(child, tabs.fake('reopen-keeps-order-third'))

  child.cmd('Aineo tab new')

  local third = tabs.session_of_tab(state, child, '3')
  local list = tabs.kept_tab_list_once(state, folder, function(kept)
    return kept ~= nil and #kept.sessions == 3
  end)
  eq(list, { sessions = { second, third, first }, current = 2 })
end

T['the folder’s list']['is kept at quit with the tab current then, before the Claude Codes are stopped'] = function()
  local state = tabs.use_own_state(child, 'reopen-quit')
  local folder = child.fn.getcwd()
  local deaf, settings = deaf_claude('reopen-quit-first')
  entry.use_fake(child, deaf, settings)
  child.cmd('Aineo open')
  local first_pid = claude_session.wait_for_start(deaf).pid
  kill_deaf_after_case(first_pid)
  local second_deaf, second_settings = deaf_claude('reopen-quit-second')
  entry.use_fake(child, second_deaf, second_settings)
  child.cmd('Aineo tab new')
  kill_deaf_after_case(claude_session.wait_for_start(second_deaf).pid)
  tabs.kept_tab_list_once(state, folder, function(list)
    return list ~= nil and #list.sessions == 2
  end)
  child.cmd('1tabnext')

  claude_session.quit(child)

  local list = tabs.kept_tab_list_once(state, folder, function(kept)
    return kept ~= nil and kept.current == 1
  end)
  eq(list.current, 1)
  eq(#list.sessions, 2)
  eq(vim.uv.kill(first_pid, 0), 0)
end

T['the folder’s list']['is kept at quit with the aineo tab used last when the current tab page is none of aineo’s'] = function()
  local state = tabs.open_first_tab(child, 'reopen-quit-last-used')
  local folder = child.fn.getcwd()
  local first = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  tabs.use_next_fake(child, tabs.fake('reopen-quit-last-used-second'))
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, '2')
  child.cmd('1tabnext')
  claude_session.press_keys(child, tabs.claude_terminal_of_tab(child, 1), '/clear\r')
  local cleared = tabs.kept_tab_list_once(state, folder, function(list)
    return list ~= nil and list.sessions[1] ~= first
  end)
  child.cmd('2tabnext')
  child.cmd('tablast | tabnew')

  claude_session.quit(child)

  local list = tabs.kept_tab_list_once(state, folder, function(kept)
    return kept ~= nil and kept.current == 2
  end)
  eq(cleared.current, 1)
  eq(list.current, 2)
  eq(#list.sessions, 2)
end

T['the first open'] = MiniTest.new_set()

T['the first open']['reopens every tab of the list in its order, each on its session, with the tab at the list’s place current'] = function()
  local _, _, fake =
    reopening_setup('reopen-all', { sessions = { THIRD, FIRST, SECOND }, current = 2 }, SECOND)

  entry.press(child, '\\o')

  eq(tabs.resumed_in_tabs(child, fake, { 1, 2, 3 }), { THIRD, FIRST, SECOND })
  eq(tabs.tab_count(child), 3)
  eq(tabs.current_tab(child), 2)
end

T['the first open']['starts every tab’s Claude Code at once, each listing the folder’s sessions as a resuming start does'] = function()
  local state = tabs.use_own_state(child, 'reopen-at-once')
  local folder = child.fn.getcwd()
  tabs.keep_tab_list(state, folder, { sessions = { FIRST, SECOND, THIRD }, current = 1 })
  tabs.keep_session_id(state, folder, FIRST)
  local fake = tabs.fake('reopen-at-once')
  local gate = claude_session.list_gate('reopen-at-once')
  entry.use_fake(child, fake, { claude = { cmd = gate.cmd } })

  child.cmd('Aineo open')

  local all_listing = vim.wait(tabs.PATIENCE_MS, function()
    return gate.lists_started() == 3
  end, 20)
  gate.open()
  eq(all_listing, true)
  eq(sorted_words_after(fake, 3, '--resume'), { FIRST, SECOND, THIRD })
end

--- How the state holds the folder's tabs in each case of the fallback.
local FALLBACK_STATES = {
  ['no list'] = function() end,
  ['a file that is no list'] = function(state, folder)
    vim.fn.mkdir(vim.fs.dirname(tabs.tab_list_file(state, folder)), 'p')
    vim.fn.writefile({ 'not a list' }, tabs.tab_list_file(state, folder))
  end,
  ['a list without the kept session'] = function(state, folder)
    tabs.keep_tab_list(state, folder, { sessions = { FIRST, SECOND }, current = 2 })
  end,
}

T['the first open']['opens one tab on the kept session when no usable list holds it'] =
  MiniTest.new_set({
    parametrize = {
      { 'no list' },
      { 'a file that is no list' },
      { 'a list without the kept session' },
    },
  })

T['the first open']['opens one tab on the kept session when no usable list holds it'][1] = function(
  kind
)
  local state = tabs.use_own_state(child, 'reopen-fallback')
  local folder = child.fn.getcwd()
  tabs.keep_session_id(state, folder, THIRD)
  FALLBACK_STATES[kind](state, folder)
  local fake = tabs.fake('reopen-fallback')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  eq(sorted_words_after(fake, 1, '--resume'), { THIRD })
  eq(sessions_of_tabs(state, { tabs.FIRST_TAB }), { THIRD })
  eq(tabs.tab_count(child), 1)
end

T['the first open']['reopens nothing at a later \\o, when no tab is left'] = function()
  local state, folder, fake =
    reopening_setup('reopen-once', { sessions = { FIRST, SECOND }, current = 1 }, FIRST)
  child.cmd('Aineo open')
  eq(tabs.tab_count(child), 2)
  eq(#claude_session.wait_for_starts(fake, 2), 2)
  child.cmd('tablast | tabnew')
  child.cmd('1tabclose')
  child.cmd('1tabclose')
  tabs.keep_tab_list(state, folder, { sessions = { FIRST, SECOND }, current = 1 })

  entry.press(child, '\\o')

  eq(#claude_session.wait_for_starts(fake, 3), 3)
  vim.wait(1500)
  eq(#claude_session.wait_for_starts(fake, 4), 3)
  eq(tabs.tab_count(child), 1)
end

T['the first open']['keeps the list once, when the last tab has opened, not as each opens'] = function()
  local state, folder, fake = reopening_setup(
    'reopen-keeps-once',
    { sessions = { FIRST, SECOND, THIRD }, current = 1 },
    FIRST
  )
  child.lua([[
    _G.reopen_keeps = {}
    local tabs = require('aineo.tabs')
    local keep_tabs = tabs.keep_tabs
    tabs.keep_tabs = function(state, folder, list)
      table.insert(_G.reopen_keeps, #list.sessions)
      return keep_tabs(state, folder, list)
    end
  ]])

  child.cmd('Aineo open')

  eq(child.lua_get('_G.reopen_keeps'), { 3 })
  eq(tabs.kept_tab_list(state, folder), { sessions = { FIRST, SECOND, THIRD }, current = 1 })
  eq(#claude_session.wait_for_starts(fake, 3), 3)
end

T['the first open']['reopens nothing when an aineo tab is open already, whatever the list holds'] = function()
  local state = tabs.use_own_state(child, 'reopen-open-already')
  local folder = child.fn.getcwd()
  local fake = tabs.fake('reopen-open-already')
  entry.use_fake(child, fake)
  child.cmd('Aineo tab new')
  eq(#claude_session.wait_for_starts(fake, 1), 1)
  tabs.keep_tab_list(state, folder, { sessions = { FIRST, SECOND }, current = 1 })
  tabs.keep_session_id(state, folder, FIRST)

  child.cmd('Aineo open')

  eq(tabs.tab_count(child), 1)
  eq(#claude_session.wait_for_starts(fake, 2), 1)
end

T['the first open']['replaces a session Claude Code has no conversation for by a new session in its tab, handing over its draft, and keeps that in the list'] = function()
  local conversations = fixture.directory('reopen-dead-conversations')
  vim.fn.writefile({}, vim.fs.joinpath(conversations, FIRST))
  local state, folder, fake = reopening_setup(
    'reopen-dead',
    { sessions = { FIRST, SECOND }, current = 1 },
    FIRST,
    { mode = 'exit', environment = { AINEO_FAKE_CLAUDE_CONVERSATIONS = conversations } }
  )
  local dead_draft =
    vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(SECOND) .. '.txt')
  vim.fn.mkdir(vim.fs.dirname(dead_draft), 'p')
  vim.fn.writefile({ 'Refactor the parser' }, dead_draft)

  child.cmd('Aineo open')

  local list = tabs.kept_tab_list_once(state, folder, function(kept)
    return kept ~= nil and kept.sessions[2] ~= SECOND
  end)
  local replaced = list.sessions[2]
  local new_draft =
    vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(replaced) .. '.txt')
  vim.wait(tabs.PATIENCE_MS, function()
    return vim.fn.filereadable(new_draft) == 1
  end, 20)
  MiniTest.expect.no_equality(replaced, SECOND)
  eq(list, { sessions = { FIRST, replaced }, current = 1 })
  eq(sorted_words_after(fake, 3, '--session-id'), { replaced })
  eq(vim.fn.readfile(new_draft), { 'Refactor the parser' })
  eq(vim.uv.fs_stat(dead_draft), nil)
end

T['the first open']['attaches the tab whose session runs in Claude Code’s background service'] = function()
  local listing = vim.fs.joinpath(fixture.directory('reopen-attach-listing'), 'agents.json')
  vim.fn.writefile({
    vim.json.encode({
      {
        id = SHORT_ID,
        cwd = child.fn.getcwd(),
        kind = 'background',
        startedAt = 1790000200000,
        sessionId = SECOND,
        name = 'tests',
        state = 'working',
        pid = 4100,
        status = 'busy',
      },
    }),
  }, listing)
  local _, _, fake = reopening_setup(
    'reopen-attach',
    { sessions = { FIRST, SECOND }, current = 1 },
    FIRST,
    { environment = { AINEO_FAKE_CLAUDE_AGENTS = listing } }
  )

  child.cmd('Aineo open')

  eq(tabs.resumed_in_tabs(child, fake, { 1, 2 }), { FIRST, 'attach' })
  eq(tabs.start_arguments_in_tab(child, fake, 2), { 'attach', SHORT_ID })
  eq(tabs.tab_count(child), 2)
end

--- Starts an editor in a terminal of the child as a user starts `nvim`, with
--- aineo set to run `fake` as Claude and the state home `home` for the
--- editor, and returns it once it has settled.
---
---@param fake { environment: table<string, string> }
---@param home string
---@param args? string[] more start arguments
---@return aineo.test.Editor
local function start_editor(fake, home, args)
  local settings = { autostart = true, claude = { cmd = claude_session.fake_command() } }
  return entry_editor.start(child, children.restart, {
    args = vim.list_extend(
      { '--cmd', 'lua vim.g.aineo = ' .. vim.inspect(settings, { newline = '', indent = '' }) },
      args or {}
    ),
    environment = vim.tbl_extend('force', fake.environment, { XDG_STATE_HOME = home }),
  })
end

--- The number of tab pages the editor has.
local TAB_PAGES = '#vim.api.nvim_list_tabpages()'

T['the autostart'] = MiniTest.new_set()

T['the autostart']['reopens the tabs of the list'] = function()
  local home = fixture.directory('reopen-autostart-state')
  local folder = vim.uv.cwd()
  local state = vim.fs.joinpath(home, 'nvim')
  tabs.keep_tab_list(state, folder, { sessions = { FIRST, SECOND }, current = 1 })
  tabs.keep_session_id(state, folder, SECOND)
  local fake = tabs.fake('reopen-autostart')

  local editor = start_editor(fake, home)

  vim.wait(tabs.PATIENCE_MS, function()
    return entry_editor.get(editor, TAB_PAGES) == 2
  end, 50)
  eq(entry_editor.get(editor, TAB_PAGES), 2)
  eq(sorted_words_after(fake, 2, '--resume'), { FIRST, SECOND })
end

T['the autostart']['reopens nothing, then or at a later \\o, in an editor a session plugin restored'] = function()
  local home = fixture.directory('reopen-restored-state')
  local folder = vim.uv.cwd()
  local state = vim.fs.joinpath(home, 'nvim')
  tabs.keep_tab_list(state, folder, { sessions = { FIRST, SECOND }, current = 1 })
  tabs.keep_session_id(state, folder, SECOND)
  local fake = tabs.fake('reopen-restored')

  local editor = start_editor(fake, home, {
    '--cmd',
    'let g:entry_session_file = '
      .. vim.fn.string(vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'entry', 'session.vim')),
    '--cmd',
    'set runtimepath+='
      .. vim.fs.joinpath(vim.uv.cwd(), 'tests', 'fixtures', 'entry', 'session_restore'),
  })
  eq(entry_editor.get(editor, TAB_PAGES), 1)
  entry_editor.request(editor, "vim.cmd('Aineo open')")

  vim.wait(tabs.PATIENCE_MS, function()
    return #claude_session.wait_for_starts(fake, 1) >= 1
  end, 50)
  eq(entry_editor.get(editor, TAB_PAGES), 1)
  eq(sorted_words_after(fake, 1, '--resume'), { SECOND })
end

return T
