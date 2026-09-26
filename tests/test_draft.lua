local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality
local no_eq = MiniTest.expect.no_equality

--- The working directory the cases keep a draft for: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/aineo'

--- How long a case waits for the draft's delayed save: longer than the delay.
local SAVE_PATIENCE_MS = 5000

local child = MiniTest.new_child_neovim()

--- The file that keeps the draft for `WORKING_DIRECTORY` under the state
--- directory `state`.
---
---@param state string
---@return string
local function draft_file(state)
  return vim.fs.joinpath(state, 'aineo', 'drafts', vim.fn.sha256(WORKING_DIRECTORY) .. '.txt')
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

--- Waits, at most `SAVE_PATIENCE_MS`, until the file at `path` holds `text`,
--- and returns what it holds then.
---
---@param path string
---@param text string
---@return string|nil
local function wait_for_text(path, text)
  vim.wait(SAVE_PATIENCE_MS, function()
    return read_text(path) == text
  end, 20)
  return read_text(path)
end

--- The Lua that gives the draft home in an editor its environment, the
--- state directory and the working directory it is given, with the file
--- writes `_G.draft_files` when a case has set them there, and hands it a
--- new, empty scratch buffer shown in the current window, as the layout's
--- Input is; the buffer is `_G.input` there.
local KEEP_NEW_BUFFER = [[
  local state, working_directory = ...
  local draft = require('aineo.draft')
  draft.set_draft_environment({
    state_directory = state,
    working_directory = working_directory,
    files = _G.draft_files,
  })
  _G.input = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, _G.input)
  draft.keep_draft(_G.input)
]]

--- Gives the draft home in `editor`, `child` when not given, its
--- environment, the state directory `state` and `WORKING_DIRECTORY`, with the
--- file writes `_G.draft_files` when a case has set them there, and hands it
--- a new, empty scratch buffer shown in the current window, as the layout's
--- Input is; the buffer is `_G.input` there.
---
---@param state string
---@param editor? table
local function keep_new_buffer(state, editor)
  editor = editor or child
  editor.lua(KEEP_NEW_BUFFER, { state, WORKING_DIRECTORY })
end

--- Replaces the text of the kept buffer, `_G.input` in `editor`, `child`
--- when not given, with `lines`, as a change through the API does.
---
---@param lines string[]
---@param editor? table
local function set_input(lines, editor)
  editor = editor or child
  editor.lua('vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...)', { lines })
end

--- Hands the kept buffer, `_G.input` in the child, to the draft home again.
local function keep_input_again()
  child.lua("require('aineo.draft').keep_draft(_G.input)")
end

--- Deletes the kept buffer, `_G.input` in the child, with `:bdelete`, which
--- drops its text without a change.
local function delete_input()
  child.lua('vim.cmd.bdelete(_G.input)')
end

--- The lines of the kept buffer, `_G.input` in the child.
local INPUT_LINES = 'vim.api.nvim_buf_get_lines(_G.input, 0, -1, true)'

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['a change'] = MiniTest.new_set()

T['a change']['is saved shortly after, under the state directory, for the working directory'] = function()
  local state = fixture.directory('draft-saved-state')
  keep_new_buffer(state)

  set_input({ 'Refactor the parser', 'then run the tests' })

  eq(
    wait_for_text(draft_file(state), 'Refactor the parser\nthen run the tests\n'),
    'Refactor the parser\nthen run the tests\n'
  )
end

T['a change']['is saved to a file only its owner can read and write'] = function()
  local state = fixture.directory('draft-owner-only-state')
  keep_new_buffer(state)

  set_input({ 'Refactor the parser' })

  wait_for_text(draft_file(state), 'Refactor the parser\n')
  eq(vim.uv.fs_stat(draft_file(state)).mode % 512, tonumber('600', 8))
end

--- Makes the file writes of the draft home in the child, `_G.draft_files`,
--- truncate the file they are given and then fail, as a crash in the middle
--- of a write leaves it, counting their calls in `_G.failed_writes`.
local WRITES_THAT_FAIL_AFTER_TRUNCATING = [[
  _G.failed_writes = 0
  _G.draft_files = {
    write_file = function(path)
      local descriptor = assert(vim.uv.fs_open(path, 'w', tonumber('600', 8)))
      vim.uv.fs_close(descriptor)
      _G.failed_writes = _G.failed_writes + 1
      return 'EIO: the write failed after truncating'
    end,
  }
]]

T['a change']['whose write fails after truncating leaves the previous draft'] = function()
  local state = fixture.directory('draft-torn-state')
  fixture.write(
    'draft-torn-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(WRITES_THAT_FAIL_AFTER_TRUNCATING)
  keep_new_buffer(state)

  set_input({ 'Rename the lexer' })

  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.failed_writes') > 0
  end, 20)
  eq(read_text(draft_file(state)), 'Refactor the parser\n')
end

T['a change']['to a draft that is a symbolic link is saved in the file it leads to, the link kept'] = function()
  local state = fixture.directory('draft-link-state')
  local linked = fixture.write('draft-link-elsewhere/draft.txt', {})
  vim.fn.mkdir(vim.fs.dirname(draft_file(state)), 'p')
  assert(vim.uv.fs_symlink(linked, draft_file(state)))
  keep_new_buffer(state)

  set_input({ 'Refactor the parser' })

  eq(wait_for_text(linked, 'Refactor the parser\n'), 'Refactor the parser\n')
  eq(vim.uv.fs_lstat(draft_file(state)).type, 'link')
end

--- Makes the directory making of the draft home in the child,
--- `_G.draft_files`, fail its first call, as a `mkdir()` fails when another
--- editor makes the directory at the same moment, and make the directory from
--- then on.
local MAKING_THAT_LOSES_A_RACE_ONCE = [[
  local raced = false
  _G.draft_files = {
    make_directory = function(path)
      if not raced then
        raced = true
        return 'E739: Cannot create directory: another editor made it'
      end
      vim.fn.mkdir(path, 'p')
    end,
  }
]]

T['a change']['is saved though making its directory loses a race with another editor'] = function()
  local state = fixture.directory('draft-mkdir-race-state')
  child.lua(MAKING_THAT_LOSES_A_RACE_ONCE)
  keep_new_buffer(state)

  set_input({ 'Refactor the parser' })

  eq(wait_for_text(draft_file(state), 'Refactor the parser\n'), 'Refactor the parser\n')
end

T['a change']['that empties the buffer empties the draft at once'] = function()
  local state = fixture.directory('draft-emptied-state')
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')

  set_input({})

  eq(read_text(draft_file(state)), '')
end

--- How long a case waits for the child to end once it quits.
local QUIT_PATIENCE_MS = 10000

--- Makes in the child the change `lines` to the kept buffer, `_G.input`, and
--- quits it with `:qall` in the same tick, before the delayed save can run,
--- then waits until it has ended.
---
---@param lines string[]
local function change_input_and_quit(lines)
  child.lua_notify(
    'vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...); vim.cmd.qall()',
    { lines }
  )
  vim.fn.jobwait({ child.job.id }, QUIT_PATIENCE_MS)
end

T['quitting'] = MiniTest.new_set()

T['quitting']['saves a change the delay has not saved yet'] = function()
  local state = fixture.directory('draft-quit-pending-state')
  keep_new_buffer(state)

  change_input_and_quit({ 'Refactor the parser' })

  eq(read_text(draft_file(state)), 'Refactor the parser\n')
end

--- How many autocommands of the draft home the kept buffer, `_G.input` in
--- the child, has.
local INPUT_AUTOCOMMAND_COUNT =
  "#vim.api.nvim_get_autocmds({ group = 'aineo.draft', buffer = _G.input })"

T['quitting']['is watched once for a buffer handed over again once :bdelete dropped its text'] = function()
  local state = fixture.directory('draft-watched-once-state')
  keep_new_buffer(state)
  delete_input()
  child.lua('vim.api.nvim_win_set_buf(0, _G.input)')

  keep_input_again()

  eq(child.lua_get(INPUT_AUTOCOMMAND_COUNT), 1)
end

T['quitting']['with a change pending writes the draft alone'] = function()
  local state = fixture.directory('draft-quit-one-file-state')
  keep_new_buffer(state)

  change_input_and_quit({ 'Refactor the parser' })

  eq(vim.fn.glob(vim.fs.joinpath(state, '**', '*'), true, true), {
    vim.fs.joinpath(state, 'aineo'),
    vim.fs.dirname(draft_file(state)),
    draft_file(state),
  })
end

--- Quits `editor`, `child` when not given, with `:qall` and waits until it
--- has ended.
---
---@param editor? table
local function quit(editor)
  editor = editor or child
  editor.lua_notify('vim.cmd.qall()')
  vim.fn.jobwait({ editor.job.id }, QUIT_PATIENCE_MS)
end

T['quitting']['after a restore writes nothing'] = function()
  local state = fixture.directory('draft-quit-restored-state')
  local file_name = 'draft-quit-restored-state/aineo/drafts/' .. vim.fs.basename(draft_file(state))
  fixture.write(file_name, { 'Refactor the parser' })
  keep_new_buffer(state)
  fixture.write(file_name, { 'Another editor wrote this' })

  quit()

  eq(read_text(draft_file(state)), 'Another editor wrote this\n')
end

T['quitting']['after the delay has saved the change writes nothing'] = function()
  local state = fixture.directory('draft-quit-saved-state')
  local file_name = 'draft-quit-saved-state/aineo/drafts/' .. vim.fs.basename(draft_file(state))
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')
  fixture.write(file_name, { 'Another editor wrote this' })

  quit()

  eq(read_text(draft_file(state)), 'Another editor wrote this\n')
end

T['quitting']['once :bdelete dropped the text keeps the saved draft'] = function()
  local state = fixture.directory('draft-quit-deleted-state')
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')
  delete_input()

  quit()

  eq(read_text(draft_file(state)), 'Refactor the parser\n')
end

T['the draft'] = MiniTest.new_set()

T['the draft']['is restored into an empty buffer handed over the first time'] = function()
  local state = fixture.directory('draft-restored-state')
  fixture.write('draft-restored-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)), {
    'Refactor the parser',
    'then run the tests',
  })

  keep_new_buffer(state)

  eq(child.lua_get(INPUT_LINES), { 'Refactor the parser', 'then run the tests' })
end

T['the draft']['is not restored into a buffer that holds text'] = function()
  local state = fixture.directory('draft-not-over-text-state')
  fixture.write(
    'draft-not-over-text-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua([[
    _G.input = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, { 'Rename the lexer' })
  ]])

  child.lua(
    [[
      local draft = require('aineo.draft')
      draft.set_draft_environment({ state_directory = ..., working_directory = select(2, ...) })
      draft.keep_draft(_G.input)
    ]],
    { state, WORKING_DIRECTORY }
  )

  eq(child.lua_get(INPUT_LINES), { 'Rename the lexer' })
end

T['the draft']['is not restored into a buffer handed over again, emptied by a change'] = function()
  local state = fixture.directory('draft-handed-again-state')
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  set_input({})
  fixture.write(
    'draft-handed-again-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Another editor wrote this' }
  )

  keep_input_again()

  eq(child.lua_get(INPUT_LINES), { '' })
end

T['the draft']['is restored into a buffer handed over again once :bdelete dropped its text'] = function()
  local state = fixture.directory('draft-after-bdelete-state')
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')
  delete_input()
  child.lua('vim.api.nvim_win_set_buf(0, _G.input)')

  keep_input_again()

  eq(child.lua_get(INPUT_LINES), { 'Refactor the parser' })
end

--- Keeps in the child every notification it gives, as its message and level,
--- in `_G.notifications`, rather than showing it.
local KEEP_NOTIFICATIONS = [[
  _G.notifications = {}
  vim.notify = function(message, level)
    table.insert(_G.notifications, { message = message, level = level })
  end
]]

--- Hands the draft home in the child a new, empty scratch buffer, as
--- `keep_new_buffer()` does once the environment is given, and says whether
--- the hand-off raised nothing.
local KEEP_ANOTHER_NEW_BUFFER = [[pcall(function()
  _G.input = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, _G.input)
  require('aineo.draft').keep_draft(_G.input)
end)]]

T['a draft that cannot be read'] = MiniTest.new_set()

T['a draft that cannot be read']['is told once as a warning, restores nothing and raises nothing'] = function()
  local state = fixture.directory('draft-unreadable-state')
  local file = fixture.write(
    'draft-unreadable-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  assert(vim.uv.fs_chmod(file, 0))
  child.lua(KEEP_NOTIFICATIONS)
  keep_new_buffer(state)

  local raised_nothing = child.lua_get(KEEP_ANOTHER_NEW_BUFFER)

  eq(raised_nothing, true)
  eq(child.lua_get(INPUT_LINES), { '' })
  eq(child.lua_get('_G.notifications'), {
    {
      level = vim.log.levels.WARN,
      message = ("aineo: cannot read Input's draft in %s: EACCES: permission denied: %s"):format(
        file,
        file
      ),
    },
  })
end

T['a draft that cannot be read']['once opened is told as a warning and restores nothing'] = function()
  local state = fixture.directory('draft-directory-state')
  vim.fn.mkdir(draft_file(state), 'p')
  child.lua(KEEP_NOTIFICATIONS)

  keep_new_buffer(state)

  eq(child.lua_get(INPUT_LINES), { '' })
  eq(child.lua_get('_G.notifications'), {
    {
      level = vim.log.levels.WARN,
      message = ("aineo: cannot read Input's draft in %s: EISDIR: illegal operation on a directory"):format(
        draft_file(state)
      ),
    },
  })
end

T['a draft that cannot be written'] = MiniTest.new_set()

--- Empties the kept buffer, `_G.input` in the child, as a change through the
--- API does, and says whether the change raised nothing.
local EMPTY_INPUT = 'pcall(vim.api.nvim_buf_set_lines, _G.input, 0, -1, true, {})'

T['a draft that cannot be written']['is told once as a warning and raises nothing into the typing'] = function()
  local state = fixture.directory('draft-unwritable-state')
  child.lua(KEEP_NOTIFICATIONS)
  keep_new_buffer(state)
  local drafts = fixture.write('draft-unwritable-state/aineo/drafts', {})
  set_input({ 'Refactor the parser' })
  vim.wait(SAVE_PATIENCE_MS, function()
    return #child.lua_get('_G.notifications') > 0
  end, 20)

  local raised_nothing = child.lua_get(EMPTY_INPUT)

  eq(raised_nothing, true)
  eq(child.lua_get('_G.notifications'), {
    {
      level = vim.log.levels.WARN,
      message = ("aineo: cannot keep Input's draft in %s: E739: Cannot create directory %s: file already exists"):format(
        draft_file(state),
        drafts
      ),
    },
  })
end

T['a draft that cannot be written']['with a change pending lets an editor with a screen quit at once'] = function()
  local state = fixture.directory('draft-unwritable-quit-state')
  local editor = entry_editor.start(child, children.restart)
  entry_editor.request(editor, KEEP_NEW_BUFFER, { state, WORKING_DIRECTORY })
  fixture.write('draft-unwritable-quit-state/aineo/drafts', {})

  vim.rpcnotify(
    editor.channel,
    'nvim_exec_lua',
    'vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...); vim.cmd.qall()',
    { { 'Refactor the parser' } }
  )

  eq(child.lua_get('vim.fn.jobwait({ vim.bo.channel }, ...)', { QUIT_PATIENCE_MS }), { 0 })
end

--- A second editor, beside `child`, in the same working directory.
local other = MiniTest.new_child_neovim()

T['two editors in one working directory'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(other)
    end,
    post_once = other.stop,
  },
})

T['two editors in one working directory']['share one draft, the last change winning though the older editor quits last'] = function()
  local state = fixture.directory('draft-two-editors-state')
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')
  keep_new_buffer(state, other)
  set_input({ 'Rename the lexer' }, other)
  wait_for_text(draft_file(state), 'Rename the lexer\n')

  quit(other)
  quit()

  eq(read_text(draft_file(state)), 'Rename the lexer\n')
end

--- Makes the file writes of the draft home in an editor, `_G.draft_files`,
--- write as the default does, keeping every path they write in
--- `_G.written_paths`.
local WRITES_KEEPING_THEIR_PATHS = [[
  _G.written_paths = {}
  _G.draft_files = {
    write_file = function(path, text)
      table.insert(_G.written_paths, path)
      local descriptor = assert(vim.uv.fs_open(path, 'w', tonumber('600', 8)))
      vim.uv.fs_write(descriptor, text)
      vim.uv.fs_close(descriptor)
    end,
  }
]]

T['two editors in one working directory']['never write through the same file'] = function()
  local state = fixture.directory('draft-two-editors-paths-state')
  child.lua(WRITES_KEEPING_THEIR_PATHS)
  other.lua(WRITES_KEEPING_THEIR_PATHS)
  keep_new_buffer(state)
  keep_new_buffer(state, other)

  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')
  set_input({ 'Rename the lexer' }, other)
  wait_for_text(draft_file(state), 'Rename the lexer\n')

  no_eq(child.lua_get('_G.written_paths[1]'), other.lua_get('_G.written_paths[1]'))
end

return T
