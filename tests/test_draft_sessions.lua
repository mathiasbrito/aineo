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

local child = MiniTest.new_child_neovim()

--- The file that keeps the draft for `WORKING_DIRECTORY` under the state
--- directory `state`.
---
---@param state string
---@return string
local function directory_draft_file(state)
  return vim.fs.joinpath(state, 'aineo', 'drafts', vim.fn.sha256(WORKING_DIRECTORY) .. '.txt')
end

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
  vim.fn.writefile(vim.split(text, '\n', { plain = true }), file, 'b')
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

--- Gives the child's draft home its environment, the state directory
--- `state` and `WORKING_DIRECTORY`, and hands it a new, empty scratch buffer
--- shown in the current window, as the layout's Input is; the buffer is
--- `_G.input` there.
---
---@param state string
local function keep_new_buffer(state)
  child.lua(
    [[
      local state, working_directory = ...
      local draft = require('aineo.draft')
      draft.set_draft_environment({ state_directory = state, working_directory = working_directory })
      _G.input = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, _G.input)
      draft.keep_draft(_G.input)
    ]],
    { state, WORKING_DIRECTORY }
  )
end

--- Tells the child's draft home to follow the Claude session `session`.
---
---@param session string
local function follow(session)
  child.lua("require('aineo.draft').follow_draft_session(...)", { session })
end

--- Replaces the text of the kept buffer, `_G.input` in the child, with
--- `lines`, as a change through the API does.
---
---@param lines string[]
local function set_input(lines)
  child.lua('vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...)', { lines })
end

--- The lines of the kept buffer, `_G.input` in the child.
---
---@return string[]
local function input_lines()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.input, 0, -1, true)')
end

--- Keeps in the child the message of every warning it gives, in
--- `_G.warnings`, rather than showing it.
local KEEP_WARNINGS = [[
  _G.warnings = {}
  vim.notify = function(message, level)
    if level == vim.log.levels.WARN then
      table.insert(_G.warnings, message)
    end
  end
]]

--- The expression, run in the child, that counts the warnings it gave that
--- a draft could not be moved.
local MOVE_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find("cannot move Input's draft", 1, true) ~= nil
end, _G.warnings)]]

--- Ways an expression mapping holds textlock while the child's main loop
--- runs, as a set's `parametrize`: the name of the hold, the Lua call that
--- waits, and the keys that end the wait. `SafeState` fires inside
--- `input()`'s wait, and Neovim refuses a change there too.
local TEXTLOCK_HOLDS = {
  { 'an expression mapping waiting for a key', 'vim.fn.getcharstr()', 'q' },
  { 'an expression mapping waiting in input()', "vim.fn.input('> ')", '<CR>' },
}

--- Maps `X`, in the child's Normal mode, to an expression that makes the
--- Lua call `wait`, holding textlock until it returns, and presses it;
--- waits, at most `PATIENCE_MS`, until it holds. `_G.holding` is true while
--- it holds.
---
---@param wait string
local function begin_hold(wait)
  child.lua(([[
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      %s
      _G.holding = false
      return ''
    end, { expr = true })
  ]]):format(wait))
  child.api.nvim_input('X')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == true')
  end, 10)
end

--- Ends the child's hold (`begin_hold()`) with `keys`, and waits, at most
--- `PATIENCE_MS`, until it has ended.
---
---@param keys string
local function end_hold(keys)
  child.api.nvim_input(keys)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == false')
  end, 10)
end

--- The expression, run in the child, that counts the autocommands waiting
--- for its `SafeState`.
local RETRIES = "#vim.api.nvim_get_autocmds({ event = 'SafeState' })"

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['following a session'] = MiniTest.new_set()

T['following a session']["puts its draft into Input in place of Input's text, and keeps the next change for it"] = function()
  local state = fixture.directory('draft-sessions-puts')
  plant_draft(session_draft_file(state, 'session-a'), 'Kept for the session\n')
  keep_new_buffer(state)
  set_input({ 'Typed before' })

  follow('session-a')
  local shown = input_lines()
  set_input({ 'Typed for the session' })

  eq({
    shown = shown,
    saved = wait_for_text(session_draft_file(state, 'session-a'), 'Typed for the session\n'),
  }, {
    shown = { 'Kept for the session' },
    saved = 'Typed for the session\n',
  })
end

T['following a session']['with no draft empties Input'] = function()
  local state = fixture.directory('draft-sessions-none')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })

  follow('session-new')

  eq(input_lines(), { '' })
end

T['following a session']['back brings back the text Input held for it'] = function()
  local state = fixture.directory('draft-sessions-back')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  wait_for_text(session_draft_file(state, 'session-a'), 'Notes for the first session\n')
  follow('session-b')

  follow('session-a')

  eq(input_lines(), { 'Notes for the first session' })
end

T['following a session']['saves a change not saved yet as the draft of the session followed until then'] = function()
  local state = fixture.directory('draft-sessions-pending')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed a moment ago' })

  follow('session-b')

  eq({
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, {
    first = 'Typed a moment ago\n',
    second = '',
  })
end

T['following a session']['puts its draft in as no change of the user: no undo takes it out, and no other session keeps it'] = function()
  local state = fixture.directory('draft-sessions-no-change')
  plant_draft(session_draft_file(state, 'session-a'), 'Kept for the first session\n')
  keep_new_buffer(state)
  set_input({ 'Typed before any session' })
  follow('session-a')
  child.cmd('normal! u')
  local undone_after_first = input_lines()

  follow('session-b')
  child.cmd('normal! u')

  eq({
    undone_after_first = undone_after_first,
    undone_after_second = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
  }, {
    undone_after_first = { 'Kept for the first session' },
    undone_after_second = { '' },
    first = 'Kept for the first session\n',
  })
end

T['following a session']["already followed leaves Input's text, cursor and undo as they were"] = function()
  local state = fixture.directory('draft-sessions-same')
  keep_new_buffer(state)
  follow('session-a')
  child.cmd('normal! iTyped for the session')
  child.api.nvim_win_set_cursor(0, { 1, 6 })

  follow('session-a')
  local after_follow = { lines = input_lines(), cursor = child.api.nvim_win_get_cursor(0) }
  child.cmd('normal! u')

  eq({ after_follow = after_follow, undone = input_lines() }, {
    after_follow = { lines = { 'Typed for the session' }, cursor = { 1, 6 } },
    undone = { '' },
  })
end

T["the working directory's draft"] = MiniTest.new_set()

T["the working directory's draft"]['becomes the first session followed'] = function()
  local state = fixture.directory('draft-sessions-moved')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  keep_new_buffer(state)

  follow('session-a')

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'From the directory' },
    directory = nil,
    session = 'From the directory\n',
  })
end

T["the working directory's draft"]['is left as it is when the session has a draft, which is shown'] = function()
  local state = fixture.directory('draft-sessions-both')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  plant_draft(session_draft_file(state, 'session-a'), 'From the session\n')
  keep_new_buffer(state)

  follow('session-a')

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'From the session' },
    directory = 'From the directory\n',
    session = 'From the session\n',
  })
end

T["the working directory's draft"]['planted again is not moved at a later follow'] = function()
  local state = fixture.directory('draft-sessions-later')
  keep_new_buffer(state)
  follow('session-a')
  plant_draft(directory_draft_file(state), 'Written by an older aineo\n')

  follow('session-b')

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
  }, {
    shown = { '' },
    directory = 'Written by an older aineo\n',
  })
end

T["the working directory's draft"]['that cannot be moved is told once, and the session keeps its own'] = function()
  local state = fixture.directory('draft-sessions-unmovable')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  local drafts = vim.fs.dirname(directory_draft_file(state))
  vim.uv.fs_chmod(drafts, tonumber('500', 8))
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(drafts, tonumber('700', 8))

  set_input({ 'Typed for the session' })

  eq({
    moves = child.lua_get(MOVE_WARNINGS),
    saved = wait_for_text(session_draft_file(state, 'session-a'), 'Typed for the session\n'),
    directory = read_text(directory_draft_file(state)),
  }, {
    moves = 1,
    saved = 'Typed for the session\n',
    directory = 'From the directory\n',
  })
end

T['a session told before the environment'] = MiniTest.new_set()

T['a session told before the environment']["is held: once it comes, the directory's draft moves to it, and Input is given its draft"] = function()
  local state = fixture.directory('draft-sessions-held')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  follow('session-a')

  keep_new_buffer(state)

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'From the directory' },
    directory = nil,
    session = 'From the directory\n',
  })
end

T['a follow refused while textlock holds'] = MiniTest.new_set({ parametrize = TEXTLOCK_HOLDS })

T['a follow refused while textlock holds']["puts the session's draft into Input once the hold ends, with no retry left, under"] = function(
  _,
  wait,
  release
)
  local state = fixture.directory('draft-sessions-textlock')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  child.lua(KEEP_WARNINGS)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold(wait)

  follow('session-b')
  local meanwhile = {
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    retries = child.lua_get(RETRIES),
  }
  end_hold(release)

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  eq({
    meanwhile = meanwhile,
    shown = input_lines(),
    retries = child.lua_get(RETRIES),
    warnings = child.lua_get('_G.warnings'),
  }, {
    meanwhile = {
      shown = { 'Typed for the first session' },
      first = 'Typed for the first session\n',
      retries = 1,
    },
    shown = { 'Kept for the second session' },
    retries = 0,
    warnings = {},
  })
end

return T
