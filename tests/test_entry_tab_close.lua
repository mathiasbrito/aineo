local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
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
    child.lua(END_TERMINALS)
  end
  child.stop()
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

--- The most the editor may take to handle typed keys right after a tab page
--- closed: a stop of a Claude Code that ignores its keys and the hangup takes
--- more than 12 s.
local ANSWERS_WITHIN_MS = 1500

--- A fake `claude` that ignores every key, the hangup and SIGTERM
--- (`tests/helpers/fake_claude_deaf.sh`) for the case `name`, and the
--- `claude.cmd` that runs it.
---
---@param name string
---@return { record: string, environment: table<string, string> } fake
---@return table settings the `vim.g.aineo` that makes aineo run it
local function deaf_claude(name)
  local fake = tabs.fake(name, 'deaf')
  return fake, { claude = { cmd = claude_session.deaf_fake_command() } }
end

--- Has the process group of the deaf fake `pid` killed when the case is over,
--- so that none outlives it; it runs from `MiniTest.finally()`, where an
--- error would stop the whole run rather than fail the case.
---
---@param pid integer
local function kill_deaf_after_case(pid)
  MiniTest.finally(function()
    pcall(vim.uv.kill, -pid, 'sigkill')
  end)
end

T['closing a tab'] = MiniTest.new_set()

T['closing a tab']['handles typed keys while a Claude Code that ignores its keys is stopped, and that Claude Code still ends'] = function()
  tabs.open_first_tab(child, 'close-deaf')
  local deaf, settings = deaf_claude('close-deaf-second')
  entry.use_fake(child, deaf, settings)
  child.cmd('Aineo tab new')
  local pid = claude_session.wait_for_start(deaf).pid
  kill_deaf_after_case(pid)

  child.cmd('tabclose')
  tabs.type_probe(child)

  eq(tabs.probe_answered(child, ANSWERS_WITHIN_MS), true)
  eq(claude_session.wait_for_process_end(pid), true)
end

T['closing a tab']['opens a tab made of copies while the first tab’s Claude Code still stops, refusing nothing'] = function()
  local state = tabs.use_own_state(child, 'close-first-stops')
  local deaf, settings = deaf_claude('close-first-stops-first')
  entry.use_fake(child, deaf, settings)
  child.cmd('Aineo open')
  local pid = claude_session.wait_for_start(deaf).pid
  kill_deaf_after_case(pid)
  tabs.use_next_fake(child, tabs.fake('close-first-stops-second'))
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, '2')
  local third = tabs.fake('close-first-stops-third')
  tabs.use_next_fake(child, third)
  child.cmd('1tabclose')
  child.lua('_G.entry_test_messages = {}')

  entry.command(child, 'Aineo tab new')

  eq(tabs.tab_count(child), 2)
  eq(#claude_session.wait_for_starts(third, 1), 1)
  eq(#claude_session.wait_for_starts(deaf, 1), 1)
  eq(tabs.input_name_of_tab(child, 2):match('^aineo://input%-%d+$') ~= nil, true)
  eq(entry.messages(child), {})
end

--- Opens the first tab of aineo and a second one after it in the child, for a
--- case named `name`, and waits until both Claude Codes are ready, which is
--- when each tab's entry among the running editors is written. Returns the
--- state directory and the two fakes.
---
---@param name string
---@return string state
---@return table first
---@return table second
local function open_two_tabs(name)
  local state, first = tabs.open_first_tab(child, name)
  local second = tabs.fake(name .. '-second')
  tabs.use_next_fake(child, second)
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  tabs.session_of_tab(state, child, '2')
  return state, first, second
end

--- The ways to ask for the close the cases run: the command, the `<Plug>`
--- mapping, the prefix key in Normal mode, and the twin in Terminal mode and
--- in Insert mode.
local CLOSE_WAYS = { { 'command' }, { 'plug' }, { 'prefix' }, { 'terminal' }, { 'insert' } }

--- Asks for the close of the current tab `way` says, from the mode that way
--- is pressed in: the tab just opened has the cursor in Claude's window in
--- Terminal mode.
---
---@param way string one of `CLOSE_WAYS`
local function ask_for_the_close(way)
  if way == 'terminal' then
    tabs.mode_once(child, 't')
    child.type_keys('<C-\\>Q')
  elseif way == 'insert' then
    child.cmd('Aineo input')
    child.cmd('startinsert')
    tabs.mode_once(child, 'i')
    child.type_keys('<C-\\>Q')
  elseif way == 'plug' then
    entry.press(child, '<Plug>(aineo-tab-close)')
  elseif way == 'prefix' then
    entry.press(child, '\\Q')
  else
    child.cmd('Aineo tab close')
  end
end

--- The names of the buffers of the child that are a tab's copy of a home's
--- buffer: a Report or an Input with a copy's number, a changes pane of a
--- copy's own.
local COPY_BUFFERS = [[vim.tbl_filter(function(name)
  return name:match('^aineo://report%-%d+$')
    or name:match('^aineo://input%-%d+$')
    or name:match('^aineo://copy%d+/')
end, vim.tbl_map(vim.api.nvim_buf_get_name, vim.api.nvim_list_bufs()))]]

--- Presses `keys` in the child as `entry.press()` does, without waiting for
--- them to have run: they quit the child.
---
---@param keys string
local function press_and_quit(keys)
  child.lua_notify(
    "vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(..., true, false, true), 'mx', false)",
    { keys }
  )
end

T['the close of a tab'] = MiniTest.new_set()

T['the close of a tab']['stops the current tab’s Claude Code, closes its tab page and leaves the other tab’s Claude Code running'] =
  MiniTest.new_set({ parametrize = CLOSE_WAYS })

T['the close of a tab']['stops the current tab’s Claude Code, closes its tab page and leaves the other tab’s Claude Code running']['by'] = function(
  way
)
  local _, first, second = open_two_tabs('close-way-' .. way)

  ask_for_the_close(way)

  eq(tabs.ended_how(second), 'keys')
  eq(tabs.tab_count(child), 1)
  eq(tabs.current_tab(child), 1)
  eq(child.lua_get("require('aineo.claude').session_status()"), 'ready')
  eq(claude_session.ctrl_c_count(first), 0)
end

T['the close of a tab']['lets the tab’s copies go, takes its entry off the list and saves Input’s draft'] = function()
  local state = open_two_tabs('close-lets-go')
  local second_session = tabs.entries(state, child.v.servername)['2'].session
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "typed in the second" })',
    { tabs.input_name_of_tab(child, 2) }
  )

  entry.press(child, '\\Q')
  tabs.entries_once(state, child, function(listed)
    return listed['2'] == nil
  end)

  eq(child.lua_get(COPY_BUFFERS), {})
  eq(tabs.second_tab_groups_that_exist(child), {})
  eq(tabs.keys_of(tabs.entries(state, child.v.servername)), { tabs.FIRST_TAB })
  eq(
    vim.fn.readfile(
      vim.fs.joinpath(
        state,
        'aineo',
        'drafts',
        'session-' .. vim.fn.sha256(second_session) .. '.txt'
      )
    ),
    { 'typed in the second' }
  )
end

T['the close of a tab']['of a tab attached to a background session presses Ctrl+Z alone, so that the session runs on'] = function()
  local _, first = tabs.open_first_tab(child, 'close-attached')
  local second = tabs.fake('close-attached-second')
  local listing = vim.fs.joinpath(vim.fs.dirname(second.record), 'agents.json')
  second.environment.AINEO_FAKE_CLAUDE_AGENTS = listing
  assert(vim.fn.writefile({
    vim.json.encode({
      {
        id = 'a1b2c3d4',
        cwd = child.fn.getcwd(),
        kind = 'background',
        startedAt = 1790000200000,
        sessionId = '22222222-2222-4222-8222-222222222222',
        name = 'tests',
        state = 'working',
        pid = 4100,
        status = 'busy',
      },
    }),
  }, listing) == 0, 'cannot write ' .. listing)
  tabs.use_next_fake(child, second)
  child.lua([[
    vim.ui.select = function(items, _, on_choice)
      vim.schedule(function()
        on_choice(items[1], 1)
      end)
    end
  ]])
  entry.press(child, '\\S')
  vim.wait(tabs.PATIENCE_MS, function()
    return tabs.tab_count(child) == 2
  end, 20)
  eq(claude_session.start_arguments(second, 1), { 'attach', 'a1b2c3d4' })

  entry.press(child, '\\Q')

  eq(tabs.ended_how(second), 'detach')
  eq(claude_session.ctrl_c_count(second), 0)
  eq(claude_session.ctrl_c_count(first), 0)
  eq(tabs.tab_count(child), 1)
end

T['closing a tab']['is left to the quit when Neovim quits while the tab’s Claude Code still stops'] = function()
  local _, first, second = open_two_tabs('close-then-quit')

  child.cmd('tabclose')
  claude_session.quit(child)

  eq(tabs.ended_how(second), 'keys')
  eq(tabs.ended_how(first), 'keys')
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)
  child.stop()
end

T['the close of the last tab of aineo'] = MiniTest.new_set()

T['the close of the last tab of aineo']['quits Neovim as :qa does, which stops the Claude Code as quitting stops it'] = function()
  local _, first = tabs.open_first_tab(child, 'close-last')

  press_and_quit('\\Q')

  eq(tabs.ended_how(first), 'keys')
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)
  child.stop()
end

T['the close of the last tab of aineo']['quits Neovim from a plain tab page next to it, when no other tab of aineo remains'] = function()
  local _, first = tabs.open_first_tab(child, 'close-last-other')
  child.cmd('tabnew')
  child.cmd('tabfirst')

  press_and_quit('\\Q')
  eq(tabs.ended_how(first), 'keys')
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)
  child.stop()
end

T['the close of the last tab of aineo']['stops nothing and quits nothing while a buffer has unsaved changes'] = function()
  local _, first = tabs.open_first_tab(child, 'close-last-modified')
  child.cmd('tabnew')
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, true, { "unsaved" })')
  child.cmd('tabfirst')

  entry.press(child, '\\Q')
  vim.wait(500)

  eq(child.is_running(), true)
  eq(child.lua_get("require('aineo.claude').session_status()"), 'ready')
  eq(claude_session.ctrl_c_count(first), 0)
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)[1] ~= nil'), true)
  eq(
    vim.iter(entry.messages(child)):any(function(told)
      return told.message ~= nil and told.message:find('E37', 1, true) ~= nil
    end),
    true
  )
end

T['the close from a tab page that is not aineo’s'] = MiniTest.new_set()

T['the close from a tab page that is not aineo’s']['closes nothing and says this tab holds no Claude Code session'] = function()
  open_two_tabs('close-plain')
  child.cmd('tabnew')
  child.lua('_G.entry_test_messages = {}')

  entry.press(child, '\\Q')

  eq(entry.messages(child), {
    {
      message = 'aineo: this tab holds no Claude Code session',
      level = vim.log.levels.WARN,
    },
  })
  eq(tabs.tab_count(child), 3)
  eq(tabs.current_tab(child), 3)
  eq(child.lua_get("require('aineo.claude').session_status()"), 'ready')
end

return T
