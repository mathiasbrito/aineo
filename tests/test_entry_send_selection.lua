local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local send = dofile('tests/helpers/send.lua')

local eq = MiniTest.expect.equality

--- Expects `messages`, as `entry.messages()` gives them, to be one error
--- whose text holds `part`, character for character.
local contains_one_error = MiniTest.new_expectation(
  'one error containing a part',
  function(messages, part)
    return #messages == 1
      and type(messages[1].error) == 'string'
      and messages[1].error:find(part, 1, true) ~= nil
  end,
  function(messages, part)
    return string.format('Messages: %s\nPart: %s', vim.inspect(messages), vim.inspect(part))
  end
)

local child = MiniTest.new_child_neovim()

--- The fixture repository of one commit every case's child works in, made
--- once for the file (`make_the_fixture_repository()`); no case changes it.
local fixture_repository

--- Takes on the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`) in this file's own Neovim, which every child it
--- starts inherits, and makes `fixture_repository`.
local function make_the_fixture_repository()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
  fixture_repository = git_repo.create('selection-entry', { ['notes.txt'] = { 'one' } })
end

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`), so that Neovim quitting has no Claude Code
--- for aineo to stop by its keys.
local function stop_the_child()
  if child.is_running() then
    child.lua(END_TERMINALS)
  end
  child.stop()
end

--- Starts the child afresh (`stop_the_child()` first) in
--- `fixture_repository`, where Claude Code starts and whose changes the
--- changes pane lists — never the checkout's.
local function restart_in_the_fixture_repository()
  stop_the_child()
  entry.restart(child)
  child.cmd('cd ' .. vim.fn.fnameescape(fixture_repository))
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = make_the_fixture_repository,
    pre_case = restart_in_the_fixture_repository,
    post_once = stop_the_child,
  },
})

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, waits until Claude Code is ready, moves the
--- cursor to Input, fills it with `lines`, and keeps every write to Claude's
--- terminal from then on (`send.writes()`).
---
---@param name string the case's own name for its files, starting `selection-`
---@param lines string[]
local function open_ready_layout(name, lines)
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\i')
  entry.set_input(child, lines)
  send.watch_writes(child)
end

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- What a Visual Send left behind in the child: the writes to Claude's
--- terminal, Input's lines, what the user was told, and the mode.
---
---@return { writes: string[], input: string[], messages: table[], mode: string }
local function after_sending()
  return {
    writes = send.writes(child),
    input = send.input(child).lines,
    messages = entry.messages(child),
    mode = child.fn.mode(),
  }
end

--- Each door to the Visual Send, as a set's `parametrize`: its name, and the
--- keys that, typed in Visual mode, send the selection.
local DOORS = {
  { '\\s', '\\s' },
  { '<Plug>(aineo-send)', '<Plug>(aineo-send)' },
}

T['a Visual Send in Input'] = MiniTest.new_set({ parametrize = DOORS })

T['a Visual Send in Input']['sends the selection alone and removes it, by pressing'] = function(
  _,
  keys
)
  open_ready_layout('selection-entry-doors', { 'a1', 'a2', 'a3' })

  send.type_keys(child, 'ggjV' .. keys)

  eq(after_sending(), {
    writes = { paste('a2') },
    input = { 'a1', 'a3' },
    messages = {},
    mode = 'n',
  })
end

T[':Aineo send'] = MiniTest.new_set()

T[':Aineo send']['takes no range: after a Visual selection, Neovim refuses it, and nothing is sent or removed'] = function()
  open_ready_layout('selection-entry-range', { 'a1', 'a2', 'a3' })
  send.type_keys(child, 'ggjV<Esc>')

  entry.command(child, "'<,'>Aineo send")

  eq({ writes = send.writes(child), input = send.input(child).lines }, {
    writes = {},
    input = { 'a1', 'a2', 'a3' },
  })
  contains_one_error(entry.messages(child), 'E481: No range allowed')
end

--- What a Visual Send tells the user outside Input.
local NOT_IN_INPUT = {
  message = 'aineo: nothing sent — Visual Send works in Input only',
  level = vim.log.levels.WARN,
}

--- What a Visual Send outside Input left behind in the child: the current
--- buffer's lines, what the user was told, and the mode.
---
---@return { lines: string[], messages: table[], mode: string }
local function after_refusal_outside_input()
  return {
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false),
    messages = entry.messages(child),
    mode = child.fn.mode(),
  }
end

T['\\s in Visual mode outside Input'] = MiniTest.new_set()

T['\\s in Visual mode outside Input']['sends and removes nothing in another buffer, saying once that it works in Input'] = function()
  open_ready_layout('selection-entry-outside', { 'Input’s text' })
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'a file’s text' })

  send.type_keys(child, 'ggV\\s')

  eq({
    writes = send.writes(child),
    input = send.input(child).lines,
    here = after_refusal_outside_input(),
  }, {
    writes = {},
    input = { 'Input’s text' },
    here = { lines = { 'a file’s text' }, messages = { NOT_IN_INPUT }, mode = 'n' },
  })
end

T['\\s in Visual mode outside Input']['removes nothing with no Input at all, saying once that it works in Input'] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'a file’s text' })

  send.type_keys(child, 'ggV\\s')

  eq(after_refusal_outside_input(), {
    lines = { 'a file’s text' },
    messages = { NOT_IN_INPUT },
    mode = 'n',
  })
end

--- What one `u` typed in Input left behind in the child, after the keys
--- `keys` were typed from Input: Input's lines, and the writes to Claude's
--- terminal since `open_ready_layout()`.
---
---@param keys string typed from Input; they end with the cursor in Input
---@return { input: string[], writes: string[] }
local function after_u_following(keys)
  send.type_keys(child, keys)
  send.type_keys(child, 'u')
  return { input = send.input(child).lines, writes = send.writes(child) }
end

--- Where a whole-Input Send is typed, as a set's `parametrize`: its name,
--- and the keys typed from Input that send it and come back to Input.
local SENDS_ELSEWHERE = {
  { 'from the Report’s window', '\\r\\s\\i' },
  { 'while the changes pane hides Input', '\\pc\\s\\pa\\i' },
}

T['u in Input'] = MiniTest.new_set()

T['u in Input']['brings back a whole-Input Send’s text, writing nothing, after a Send typed'] =
  MiniTest.new_set({ parametrize = SENDS_ELSEWHERE })

T['u in Input']['brings back a whole-Input Send’s text, writing nothing, after a Send typed']['so'] = function(
  _,
  keys
)
  child.o.undolevels = 1000
  open_ready_layout('selection-entry-undo-elsewhere', { 'first line', 'second line' })

  eq(after_u_following(keys), {
    input = { 'first line', 'second line' },
    writes = { paste('first line\nsecond line') },
  })
end

--- Gives the child a state directory of its own, `.tests/fixtures/<name>`,
--- and leaves `lines` there as the draft an earlier editor kept for the
--- child's working directory.
---
---@param name string
---@param lines string[]
local function leave_draft(name, lines)
  local state = fixture.directory(name)
  child.lua('vim.env.XDG_STATE_HOME = ...', { state })
  local draft =
    vim.fs.joinpath(state, 'nvim', 'aineo', 'drafts', vim.fn.sha256(child.fn.getcwd()) .. '.txt')
  vim.fn.mkdir(vim.fs.dirname(draft), 'p')
  assert(vim.fn.writefile(lines, draft) == 0, 'cannot write ' .. draft)
end

T['u in Input']['after the draft was restored, brings back the sent text, and stops there'] = function()
  child.o.undolevels = 1000
  leave_draft('selection-entry-undo-draft-state', { 'draft one', 'draft two' })
  entry.use_fake(child, claude_session.fake('selection-entry-undo-draft', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  send.type_keys(child, '\\i')
  send.watch_writes(child)

  local after_u = after_u_following('\\s')
  send.type_keys(child, 'u')

  eq({ after_u = after_u, after_u_u = send.input(child).lines }, {
    after_u = {
      input = { 'draft one', 'draft two' },
      writes = { paste('draft one\ndraft two') },
    },
    after_u_u = { 'draft one', 'draft two' },
  })
end

return T
