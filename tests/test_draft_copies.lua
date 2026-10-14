local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The working directory the cases keep a draft for: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/aineo'

--- How long a case waits for the draft's delayed save, or for the child to
--- reach a state: longer than the delay.
local PATIENCE_MS = 5000

--- The functions a draft home offers as fields, as the module's own do.
local DRAFT_FUNCTIONS = {
  { 'set_draft_environment' },
  { 'keep_draft' },
  { 'follow_draft_session' },
  { 'hand_over_draft_session' },
}

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The file that keeps the draft for the Claude session `session` under the
--- state directory `state`.
---
---@param state string
---@param session string
---@return string
local function session_draft_file(state, session)
  return vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(session) .. '.txt')
end

--- Writes `text` as the whole of `file`, making its directory.
---
---@param file string
---@param text string
local function plant_draft(file, text)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  vim.fn.writefile({ text }, file, 'b')
end

--- The whole text of the file at `path`, or nil when it cannot be read.
---
---@param path string
---@return string|nil
local function read_text(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- Waits, at most `PATIENCE_MS`, until the file at `path` holds `text`, and
--- returns what it holds then.
---
---@param path string
---@param text string|nil
---@return string|nil
local function wait_for_text(path, text)
  vim.wait(PATIENCE_MS, function()
    return read_text(path) == text
  end, 20)
  return read_text(path)
end

--- Restarts the child and gives its draft home, and a draft home of its own
--- held as `_G.second`, the state directory `state` and `WORKING_DIRECTORY`.
--- Each gets a new, empty scratch buffer, `_G.first_input` and
--- `_G.second_input`, that it does not keep yet.
---
---@param state string
local function start_two_homes(state)
  children.restart(child)
  child.lua(
    [[
      local state, working_directory = ...
      local first = require('aineo.draft')
      _G.second = first.new()
      for _, home in ipairs({ first, _G.second }) do
        home.set_draft_environment({
          state_directory = state,
          working_directory = working_directory,
        })
      end
      _G.first_input = vim.api.nvim_create_buf(false, true)
      _G.second_input = vim.api.nvim_create_buf(false, true)
    ]],
    { state, WORKING_DIRECTORY }
  )
end

--- Has the module's home follow the session `first_session` and the second
--- home the session `second_session`, and each keep its Input.
---
---@param first_session string
---@param second_session string
local function follow_and_keep(first_session, second_session)
  child.lua(
    [[
      local first_session, second_session = ...
      require('aineo.draft').follow_draft_session(first_session)
      _G.second.follow_draft_session(second_session)
      require('aineo.draft').keep_draft(_G.first_input)
      _G.second.keep_draft(_G.second_input)
    ]],
    { first_session, second_session }
  )
end

--- The lines of the child's buffer `name`, a global there.
---
---@param name 'first_input'|'second_input'
---@return string[]
local function lines_of(name)
  return child.lua_get(('vim.api.nvim_buf_get_lines(_G.%s, 0, -1, true)'):format(name))
end

--- Replaces the text of the child's buffer `name`, a global there, with
--- `lines`, as a change through the API does.
---
---@param name 'first_input'|'second_input'
---@param lines string[]
local function set_lines(name, lines)
  child.lua(('vim.api.nvim_buf_set_lines(_G.%s, 0, -1, true, ...)'):format(name), { lines })
end

T['a draft home of its own'] = MiniTest.new_set()

T['a draft home of its own']['offers the per-view functions as fields'] = MiniTest.new_set({
  parametrize = DRAFT_FUNCTIONS,
})

T['a draft home of its own']['offers the per-view functions as fields']['of'] = function(name)
  children.restart(child)

  local kinds = child.lua_get(
    [[(function(name)
      local first, second = require('aineo.draft').new(), require('aineo.draft').new()
      return {
        first = type(first[name]),
        second = type(second[name]),
        shared = first[name] == second[name] or first[name] == require('aineo.draft')[name],
      }
    end)(...)]],
    { name }
  )

  eq(kinds, { first = 'function', second = 'function', shared = false })
end

T['two draft homes'] = MiniTest.new_set()

T['two draft homes']['each restore from and save to the draft file of the session they follow'] = function()
  local state = fixture.directory('draft-copies-files')
  plant_draft(session_draft_file(state, 'session-a'), 'Alpha draft')
  plant_draft(session_draft_file(state, 'session-b'), 'Beta draft')
  start_two_homes(state)

  follow_and_keep('session-a', 'session-b')
  local restored = { first = lines_of('first_input'), second = lines_of('second_input') }
  set_lines('first_input', { 'Alpha edited' })
  set_lines('second_input', { 'Beta edited' })

  eq({
    restored = restored,
    first_saved = wait_for_text(session_draft_file(state, 'session-a'), 'Alpha edited\n'),
    second_saved = wait_for_text(session_draft_file(state, 'session-b'), 'Beta edited\n'),
  }, {
    restored = { first = { 'Alpha draft' }, second = { 'Beta draft' } },
    first_saved = 'Alpha edited\n',
    second_saved = 'Beta edited\n',
  })
end

T['two draft homes']['swap only the Input of the home that follows another session'] = function()
  local state = fixture.directory('draft-copies-swap')
  plant_draft(session_draft_file(state, 'session-a'), 'Alpha draft')
  plant_draft(session_draft_file(state, 'session-b'), 'Beta draft')
  plant_draft(session_draft_file(state, 'session-c'), 'Gamma draft')
  start_two_homes(state)
  follow_and_keep('session-a', 'session-b')

  child.lua("_G.second.follow_draft_session('session-c')")

  eq({ first = lines_of('first_input'), second = lines_of('second_input') }, {
    first = { 'Alpha draft' },
    second = { 'Gamma draft' },
  })
end

T['two draft homes']['save a change pending in one Input when it is wiped, whatever the other home does'] = function()
  local state = fixture.directory('draft-copies-unload')
  start_two_homes(state)
  follow_and_keep('session-a', 'session-b')
  set_lines('first_input', { 'Typed in the first' })
  set_lines('second_input', { 'Typed in the second' })

  child.lua("_G.second.follow_draft_session('session-c'); _G.second.keep_draft(_G.second_input)")
  child.lua('vim.api.nvim_buf_delete(_G.first_input, { force = true })')

  eq({
    first = read_text(session_draft_file(state, 'session-a')),
    second_left_alone = read_text(session_draft_file(state, 'session-b')),
  }, { first = 'Typed in the first\n', second_left_alone = 'Typed in the second\n' })
end

T['two draft homes']['keep again, each in its own home, an Input shown again after it was dropped'] = function()
  local state = fixture.directory('draft-copies-shown-again')
  plant_draft(session_draft_file(state, 'session-b'), 'Beta draft')
  start_two_homes(state)
  follow_and_keep('session-a', 'session-b')
  child.cmd('bdelete! ' .. child.lua_get('_G.second_input'))

  child.lua('vim.api.nvim_win_set_buf(0, _G.second_input)')
  local restored = lines_of('second_input')
  set_lines('second_input', { 'Beta edited' })

  eq({
    restored = restored,
    saved = wait_for_text(session_draft_file(state, 'session-b'), 'Beta edited\n'),
    first_session_draft = read_text(session_draft_file(state, 'session-a')),
  }, { restored = { 'Beta draft' }, saved = 'Beta edited\n', first_session_draft = nil })
end

T['two draft homes']['each tell the user once of a draft they cannot read'] = function()
  local state = fixture.directory('draft-copies-unreadable')
  vim.fn.mkdir(session_draft_file(state, 'session-a'), 'p')
  vim.fn.mkdir(session_draft_file(state, 'session-b'), 'p')
  start_two_homes(state)
  child.lua([[
    _G.warnings = {}
    vim.notify = function(message, level)
      if level == vim.log.levels.WARN then
        table.insert(_G.warnings, message)
      end
    end
  ]])

  follow_and_keep('session-a', 'session-b')

  eq(child.lua_get('#_G.warnings'), 2)
end

--- The file that keeps the draft for `WORKING_DIRECTORY` under the state
--- directory `state`.
---
---@param state string
---@return string
local function directory_draft_file(state)
  return vim.fs.joinpath(state, 'aineo', 'drafts', vim.fn.sha256(WORKING_DIRECTORY) .. '.txt')
end

--- The file that keeps the text of the Input of the draft home labelled
--- `label` before it follows a session, under the state directory `state`.
---
---@param state string
---@param label string
---@return string
local function copy_draft_file(state, label)
  return vim.fs.joinpath(
    state,
    'aineo',
    'drafts',
    vim.fn.sha256(WORKING_DIRECTORY) .. '-' .. label .. '.txt'
  )
end

--- The environment, as a Lua table constructor run in the child, that gives
--- a home the state directory `state` and `WORKING_DIRECTORY`.
---
---@param state string
---@return string
local function environment_in(state)
  return ([[{ state_directory = %q, working_directory = %q }]]):format(state, WORKING_DIRECTORY)
end

T['two draft homes']['keep the draft under the state directory each was given'] = function()
  local state = fixture.directory('draft-copies-states')
  local other_state = fixture.directory('draft-copies-other-state')
  start_two_homes(state)
  child.lua(
    '_G.second.set_draft_environment({ state_directory = ..., working_directory = ... })',
    { other_state, WORKING_DIRECTORY }
  )
  follow_and_keep('session-a', 'session-a')

  set_lines('first_input', { 'Typed in the first' })
  set_lines('second_input', { 'Typed in the second' })

  eq({
    first = wait_for_text(session_draft_file(state, 'session-a'), 'Typed in the first\n'),
    second = wait_for_text(session_draft_file(other_state, 'session-a'), 'Typed in the second\n'),
  }, { first = 'Typed in the first\n', second = 'Typed in the second\n' })
end

T['two draft homes']["hold a claim apart: a home told a claimed session leaves the directory's draft whatever the other is told"] = function()
  local state = fixture.directory('draft-copies-claims')
  plant_draft(directory_draft_file(state), 'Directory')
  children.restart(child)
  child.lua(([[
    local first = require('aineo.draft')
    local second = first.new()
    first.follow_draft_session('session-a', { claim = true })
    second.follow_draft_session('session-b')
    first.set_draft_environment(%s)
  ]]):format(environment_in(state)))

  eq({
    directory = read_text(directory_draft_file(state)),
    claimed = read_text(session_draft_file(state, 'session-a')),
  }, { directory = 'Directory', claimed = nil })
end

T['two draft homes']["keep the text typed before the first follow out of the module's draft, and bring it back under their first follow"] = function()
  local state = fixture.directory('draft-copies-directory')
  plant_draft(directory_draft_file(state), 'Directory')
  start_two_homes(state)
  child.lua([[
    require('aineo.draft').keep_draft(_G.first_input)
    _G.second.keep_draft(_G.second_input)
  ]])
  set_lines('second_input', { 'tab 2 notes' })
  wait_for_text(copy_draft_file(state, '2'), 'tab 2 notes\n')

  child.lua("require('aineo.draft').follow_draft_session('session-a')")
  child.lua("_G.second.follow_draft_session('session-b')")

  eq({
    first_session = read_text(session_draft_file(state, 'session-a')),
    first_input = lines_of('first_input'),
    second_session = read_text(session_draft_file(state, 'session-b')),
    second_input = lines_of('second_input'),
    directory = read_text(directory_draft_file(state)),
  }, {
    first_session = 'Directory',
    first_input = { 'Directory' },
    second_session = 'tab 2 notes\n',
    second_input = { 'tab 2 notes' },
    directory = nil,
  })
end

T['two draft homes']['hold the hand-overs told before their environment apart'] = function()
  local state = fixture.directory('draft-copies-hand-overs')
  plant_draft(session_draft_file(state, 'session-x'), 'Held')
  children.restart(child)
  child.lua(([[
    local first = require('aineo.draft')
    local second = first.new()
    first.hand_over_draft_session('session-x', 'session-y')
    second.set_draft_environment(%s)
  ]]):format(environment_in(state)))

  eq({
    handed_from = read_text(session_draft_file(state, 'session-x')),
    handed_to = read_text(session_draft_file(state, 'session-y')),
  }, { handed_from = 'Held', handed_to = nil })
end

--- The expression, run in the child, that counts the autocommands waiting
--- for its `SafeState`.
local RETRIES = "#vim.api.nvim_get_autocmds({ event = 'SafeState' })"

--- Maps `X`, in the child's Normal mode, to an expression that waits for a
--- key, holding textlock until it is pressed, and presses it; waits, at
--- most `PATIENCE_MS`, until it holds.
local function begin_hold()
  child.lua([[
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      vim.fn.getcharstr()
      _G.holding = false
      return ''
    end, { expr = true })
  ]])
  child.api.nvim_input('X')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == true')
  end, 10)
end

--- Ends the child's hold (`begin_hold()`) and waits, at most `PATIENCE_MS`,
--- until it has ended.
local function end_hold()
  child.api.nvim_input('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == false')
  end, 10)
end

T['two draft homes']["keep the retries of their swaps apart: clearing the module's group leaves the other home's retry to land"] = function()
  local state = fixture.directory('draft-copies-retries')
  for session, draft in pairs({ a = 'Alpha', b = 'Beta', c = 'Gamma', d = 'Delta' }) do
    plant_draft(session_draft_file(state, 'session-' .. session), draft)
  end
  start_two_homes(state)
  follow_and_keep('session-a', 'session-c')
  begin_hold()
  child.lua("require('aineo.draft').follow_draft_session('session-b')")
  child.lua("_G.second.follow_draft_session('session-d')")
  local waiting = child.lua_get(RETRIES)

  child.cmd('autocmd! aineo.draft')
  end_hold()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({ waiting = waiting, first = lines_of('first_input'), second = lines_of('second_input') }, {
    waiting = 2,
    first = { 'Alpha' },
    second = { 'Delta' },
  })
end

T['two draft homes']['leave a swap held under textlock to the home that asked for it, though one buffer is kept by both'] = function()
  local state = fixture.directory('draft-copies-one-buffer')
  for session, draft in pairs({ a = 'Alpha', b = 'Beta', c = 'Gamma', d = 'Delta' }) do
    plant_draft(session_draft_file(state, 'session-' .. session), draft)
  end
  start_two_homes(state)
  child.lua([[
    require('aineo.draft').follow_draft_session('session-a')
    _G.second.follow_draft_session('session-c')
    require('aineo.draft').keep_draft(_G.first_input)
    _G.second.keep_draft(_G.first_input)
  ]])
  begin_hold()
  child.lua("require('aineo.draft').follow_draft_session('session-b')")
  child.lua("_G.second.follow_draft_session('session-d')")
  local waiting = child.lua_get(RETRIES)

  end_hold()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({ waiting = waiting, input = lines_of('first_input') }, { waiting = 2, input = { 'Delta' } })
end

T['a draft home of its own']['keeps its group when the module is loaded again before it keeps an Input'] = function()
  local state = fixture.directory('draft-copies-reload')
  children.restart(child)
  child.lua(
    [[
      local state, working_directory = ...
      _G.old = require('aineo.draft').new()
      package.loaded['aineo.draft'] = nil
      _G.newer = require('aineo.draft').new()
      for _, home in ipairs({ _G.old, _G.newer }) do
        home.set_draft_environment({
          state_directory = state,
          working_directory = working_directory,
        })
      end
      _G.first_input = vim.api.nvim_create_buf(false, true)
      _G.second_input = vim.api.nvim_create_buf(false, true)
      _G.old.follow_draft_session('session-a')
      _G.newer.follow_draft_session('session-b')
      _G.old.keep_draft(_G.first_input)
      _G.newer.keep_draft(_G.second_input)
    ]],
    { state, WORKING_DIRECTORY }
  )
  set_lines('first_input', { 'Typed in the old' })
  set_lines('second_input', { 'Typed in the newer' })

  child.cmd('doautocmd QuitPre')

  eq({
    old = read_text(session_draft_file(state, 'session-a')),
    newer = read_text(session_draft_file(state, 'session-b')),
  }, { old = 'Typed in the old\n', newer = 'Typed in the newer\n' })
end

T['two draft homes']['save the change pending in each Input as Neovim starts to quit'] = function()
  local state = fixture.directory('draft-copies-quit')
  start_two_homes(state)
  follow_and_keep('session-a', 'session-b')
  set_lines('first_input', { 'Typed in the first' })
  set_lines('second_input', { 'Typed in the second' })

  child.cmd('doautocmd QuitPre')

  eq({
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, { first = 'Typed in the first\n', second = 'Typed in the second\n' })
end

return T
