local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The lines of the layout's Input, read in the child.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

local child = MiniTest.new_child_neovim()

--- Gives the child a state directory of its own, `.tests/fixtures/<name>`,
--- so that no other case's draft comes back in it, and returns the file
--- that keeps its draft for its working directory there.
---
---@param name string
---@return string
local function own_state_directory(name)
  local state = fixture.directory(name)
  child.lua('vim.env.XDG_STATE_HOME = ...', { state })
  return vim.fs.joinpath(
    state,
    'nvim',
    'aineo',
    'drafts',
    vim.fn.sha256(child.fn.getcwd()) .. '.txt'
  )
end

--- Writes `lines` as the draft file `draft`, as an earlier editor left it.
---
---@param draft string
---@param lines string[]
local function leave_draft(draft, lines)
  vim.fn.mkdir(vim.fs.dirname(draft), 'p')
  assert(vim.fn.writefile(lines, draft) == 0, 'cannot write ' .. draft)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

T[':Aineo open'] = MiniTest.new_set()

T[':Aineo open']['restores the draft into Input'] = function()
  local draft = own_state_directory('entry-draft-open-state')
  leave_draft(draft, { 'Refactor the parser', 'then run the tests' })
  entry.use_fake(child, claude_session.fake('entry-draft-open', 'ready'))

  child.cmd('Aineo open')

  eq(child.lua_get(INPUT_LINES), { 'Refactor the parser', 'then run the tests' })
end

--- How long a case waits for the draft to hold what it waits for: longer
--- than the delay after which a change is saved.
local DRAFT_PATIENCE_MS = 5000

--- The whole text of the file `draft`, or nil when it cannot be read.
---
---@param draft string
---@return string|nil
local function read_draft(draft)
  local file = io.open(draft, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- Waits, at most `DRAFT_PATIENCE_MS`, until the file `draft` holds `text`.
---
---@param draft string
---@param text string
local function wait_for_draft(draft, text)
  vim.wait(DRAFT_PATIENCE_MS, function()
    return read_draft(draft) == text
  end, 20)
end

T[':Aineo send'] = MiniTest.new_set()

T[':Aineo send']['from another window empties the draft with Input, at once'] = function()
  local draft = own_state_directory('entry-draft-send-state')
  entry.use_fake(child, claude_session.fake('entry-draft-send', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.set_input(child, { 'hello' })
  wait_for_draft(draft, 'hello\n')
  child.cmd('Aineo report')

  child.cmd('Aineo send')

  eq(read_draft(draft), '')
end

T[':Aineo open']['with a draft it cannot read opens the layout and warns once, reporting no error'] = function()
  local draft = own_state_directory('entry-draft-unreadable-state')
  leave_draft(draft, { 'Refactor the parser' })
  assert(vim.uv.fs_chmod(draft, 0))
  entry.use_fake(child, claude_session.fake('entry-draft-unreadable', 'ready'))

  child.cmd('Aineo open')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(entry.messages(child), {
    {
      level = vim.log.levels.WARN,
      message = ("aineo: cannot read Input's draft in %s: EACCES: permission denied: %s"):format(
        draft,
        draft
      ),
    },
  })
end

T[':Aineo open']['after Input was wiped brings its text back in the new Input'] = function()
  local draft = own_state_directory('entry-draft-wiped-state')
  entry.use_fake(child, claude_session.fake('entry-draft-wiped', 'ready'))
  child.cmd('Aineo open')
  entry.set_input(child, { 'Refactor the parser' })
  wait_for_draft(draft, 'Refactor the parser\n')
  child.cmd('bwipeout! aineo://input')

  child.cmd('Aineo open')

  eq(child.lua_get(INPUT_LINES), { 'Refactor the parser' })
end

T['a bare interactive start'] = MiniTest.new_set()

T['a bare interactive start']['restores the draft into the Input it opens'] = function()
  local state = fixture.directory('entry-draft-autostart-state')
  leave_draft(
    vim.fs.joinpath(state, 'nvim', 'aineo', 'drafts', vim.fn.sha256(vim.fn.getcwd()) .. '.txt'),
    { 'Refactor the parser' }
  )
  local fake = claude_session.fake('entry-draft-autostart', 'ready')
  local settings = { claude = { cmd = claude_session.fake_command() } }

  local editor = entry_editor.start(child, children.restart, {
    args = { '--cmd', 'lua vim.g.aineo = ' .. vim.inspect(settings, { newline = '', indent = '' }) },
    environment = vim.tbl_extend('force', fake.environment, { XDG_STATE_HOME = state }),
  })

  eq(entry_editor.get(editor, INPUT_LINES), { 'Refactor the parser' })
end

T['after a Send'] = MiniTest.new_set({ parametrize = { { 'o' }, { 'i' }, { 'r' }, { 'c' } } })

T['after a Send']['\\o, \\i, \\r or \\c restores nothing, not even a draft another editor wrote since'] = function(
  key
)
  local draft = own_state_directory('entry-draft-after-send-' .. key .. '-state')
  entry.use_fake(child, claude_session.fake('entry-draft-after-send-' .. key, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.set_input(child, { 'hello' })
  wait_for_draft(draft, 'hello\n')
  entry.press(child, '\\s')
  leave_draft(draft, { 'Another editor wrote this' })

  entry.press(child, '\\' .. key)

  eq(child.lua_get(INPUT_LINES), { '' })
end

T['the first \\i, \\r or \\c'] = MiniTest.new_set({ parametrize = { { 'i' }, { 'r' }, { 'c' } } })

T['the first \\i, \\r or \\c']['restores the draft into Input as it opens the layout'] = function(
  key
)
  local draft = own_state_directory('entry-draft-focus-' .. key .. '-state')
  leave_draft(draft, { 'Refactor the parser' })
  entry.use_fake(child, claude_session.fake('entry-draft-focus-' .. key, 'ready'))

  entry.press(child, '\\' .. key)

  eq(child.lua_get(INPUT_LINES), { 'Refactor the parser' })
end

return T
