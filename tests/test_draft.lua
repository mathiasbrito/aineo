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

--- Keeps in the child every notification it gives, as its message and level,
--- in `_G.notifications`, rather than showing it.
local KEEP_NOTIFICATIONS = [[
  _G.notifications = {}
  vim.notify = function(message, level)
    table.insert(_G.notifications, { message = message, level = level })
  end
]]

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

--- Makes the writes of the draft home in the child, `_G.draft_files`, fail
--- once the file they write to has been opened, and so emptied, as a crash
--- in the middle of a write leaves it, counting them in `_G.failed_writes`.
local WRITES_THAT_FAIL_AFTER_TRUNCATING = [[
  _G.failed_writes = 0
  _G.draft_files = {
    write = function()
      _G.failed_writes = _G.failed_writes + 1
      return nil, 'EIO: the write failed after truncating'
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
  eq(child.lua_get('_G.failed_writes') > 0, true)
  eq(read_text(draft_file(state)), 'Refactor the parser\n')
end

--- Makes the writes of the draft home in the child, `_G.draft_files`,
--- write only the first 5 bytes of the text they are given, as the kernel
--- cuts a write short when the disk or the quota runs out, and count them in
--- `_G.short_writes`.
local WRITES_CUT_SHORT = [[
  _G.short_writes = 0
  _G.draft_files = {
    write = function(descriptor, text)
      _G.short_writes = _G.short_writes + 1
      return vim.uv.fs_write(descriptor, text:sub(1, 5))
    end,
  }
]]

T['a change']['whose write is cut short leaves the previous draft and warns how much was written'] = function()
  local state = fixture.directory('draft-short-state')
  local file = fixture.write(
    'draft-short-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(KEEP_NOTIFICATIONS)
  child.lua(WRITES_CUT_SHORT)
  keep_new_buffer(state)

  set_input({ 'Rename the lexer' })

  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.short_writes') > 0
  end, 20)
  eq(child.lua_get('_G.short_writes') > 0, true)
  eq({ draft = read_text(file), notifications = child.lua_get('_G.notifications') }, {
    draft = 'Refactor the parser\n',
    notifications = {
      {
        level = vim.log.levels.WARN,
        message = ("aineo: cannot keep Input's draft in %s: wrote 5 of 17 bytes"):format(file),
      },
    },
  })
end

T['a change']['whose write is cut short leaves no file beside the draft'] = function()
  local state = fixture.directory('draft-short-leftover-state')
  local file = fixture.write(
    'draft-short-leftover-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(WRITES_CUT_SHORT)
  keep_new_buffer(state)

  set_input({ 'Rename the lexer' })

  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.short_writes') > 0
  end, 20)
  eq(child.lua_get('_G.short_writes') > 0, true)
  eq(vim.fn.glob(vim.fs.joinpath(vim.fs.dirname(file), '*'), true, true), { file })
end

T['a change']['whose file cannot replace the draft leaves no file beside it'] = function()
  local state = fixture.directory('draft-rename-fails-state')
  vim.fn.mkdir(draft_file(state), 'p')
  child.lua(KEEP_NOTIFICATIONS)
  keep_new_buffer(state)

  set_input({ 'Refactor the parser' })

  vim.wait(SAVE_PATIENCE_MS, function()
    return #child.lua_get('_G.notifications') >= 2
  end, 20)
  eq(#child.lua_get('_G.notifications'), 2)
  eq(vim.fn.glob(vim.fs.joinpath(vim.fs.dirname(draft_file(state)), '*'), true, true), {
    draft_file(state),
  })
end

--- Makes the closing of the draft home's files in the child,
--- `_G.draft_files`, close the file and then fail, as a close that reports
--- a delayed write error does, counting them in `_G.failed_closes`.
local CLOSES_THAT_FAIL = [[
  _G.failed_closes = 0
  _G.draft_files = {
    close = function(descriptor)
      vim.uv.fs_close(descriptor)
      _G.failed_closes = _G.failed_closes + 1
      return nil, 'EIO: the close failed'
    end,
  }
]]

T['a change']['whose file fails to close leaves the previous draft'] = function()
  local state = fixture.directory('draft-close-state')
  local file = fixture.write(
    'draft-close-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(CLOSES_THAT_FAIL)
  keep_new_buffer(state)

  set_input({ 'Rename the lexer' })

  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.failed_closes') > 0
  end, 20)
  eq(child.lua_get('_G.failed_closes') > 0, true)
  eq(read_text(file), 'Refactor the parser\n')
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

T['a change']['to text whose first line is blank is saved'] = function()
  local state = fixture.directory('draft-blank-first-line-state')
  keep_new_buffer(state)

  set_input({ '', 'Refactor the parser' })

  eq(wait_for_text(draft_file(state), '\nRefactor the parser\n'), '\nRefactor the parser\n')
end

T['a change']['not saved yet is saved when :bdelete drops the text'] = function()
  local state = fixture.directory('draft-bdelete-pending-state')
  keep_new_buffer(state)

  child.lua(
    "vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, { 'Refactor the parser' }); vim.cmd.bdelete(_G.input)"
  )

  eq(read_text(draft_file(state)), 'Refactor the parser\n')
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
--- then expects it to end, with exit status 0, within `QUIT_PATIENCE_MS`.
---
---@param lines string[]
local function change_input_and_quit(lines)
  child.lua_notify(
    'vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...); vim.cmd.qall()',
    { lines }
  )
  eq(vim.fn.jobwait({ child.job.id }, QUIT_PATIENCE_MS), { 0 })
end

T['quitting'] = MiniTest.new_set()

T['quitting']['saves a change the delay has not saved yet'] = function()
  local state = fixture.directory('draft-quit-pending-state')
  keep_new_buffer(state)

  change_input_and_quit({ 'Refactor the parser' })

  eq(read_text(draft_file(state)), 'Refactor the parser\n')
end

--- Gives the child's first buffer, loaded before the kept one, a `BufUnload`
--- handler that raises a Lua error, as another plugin's may.
local FAILING_EARLIER_UNLOAD = [[
  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = 1,
    callback = function()
      error('another plugin failed')
    end,
  })
]]

T['quitting']['from Lua saves a change the delay has not saved yet though an earlier BufUnload handler fails'] = function()
  local state = fixture.directory('draft-quit-failing-handler-state')
  child.lua(FAILING_EARLIER_UNLOAD)
  keep_new_buffer(state)

  child.lua_notify(
    "vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, { 'Refactor the parser' }); vim.cmd('qa!')"
  )
  eq(vim.fn.jobwait({ child.job.id }, QUIT_PATIENCE_MS), { 0 })

  eq(read_text(draft_file(state)), 'Refactor the parser\n')
end

--- The events of the draft home's autocommands for the kept buffer,
--- `_G.input` in the child, one for each autocommand, in sorted order.
local INPUT_AUTOCOMMAND_EVENTS = [[(function()
  local events = vim.tbl_map(function(autocommand)
    return autocommand.event
  end, vim.api.nvim_get_autocmds({ group = 'aineo.draft', buffer = _G.input }))
  table.sort(events)
  return events
end)()]]

T['quitting']['is watched once for a buffer handed over again once :bdelete dropped its text'] = function()
  local state = fixture.directory('draft-watched-once-state')
  keep_new_buffer(state)
  delete_input()
  child.lua('vim.api.nvim_win_set_buf(0, _G.input)')

  keep_input_again()

  eq(child.lua_get(INPUT_AUTOCOMMAND_EVENTS), { 'BufUnload', 'BufWinEnter' })
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

--- Quits `editor`, `child` when not given, with `:qall`, and expects it to
--- end, with exit status 0, within `QUIT_PATIENCE_MS`.
---
---@param editor? table
local function quit(editor)
  editor = editor or child
  editor.lua_notify('vim.cmd.qall()')
  eq(vim.fn.jobwait({ editor.job.id }, QUIT_PATIENCE_MS), { 0 })
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

T['the draft']['is not restored into a buffer whose first line is blank but holds text'] = function()
  local state = fixture.directory('draft-blank-first-line-restore-state')
  fixture.write(
    'draft-blank-first-line-restore-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua([[
    _G.input = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, { '', 'Rename the lexer' })
  ]])

  child.lua(
    [[
      local draft = require('aineo.draft')
      draft.set_draft_environment({ state_directory = ..., working_directory = select(2, ...) })
      draft.keep_draft(_G.input)
    ]],
    { state, WORKING_DIRECTORY }
  )

  eq(child.lua_get(INPUT_LINES), { '', 'Rename the lexer' })
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

--- Waits, at most `SAVE_PATIENCE_MS`, until the kept buffer, `_G.input` in
--- the child, holds `lines`.
---
---@param lines string[]
local function wait_for_input(lines)
  vim.wait(SAVE_PATIENCE_MS, function()
    return vim.deep_equal(child.lua_get(INPUT_LINES), lines)
  end, 20)
end

T['the draft']['is restored once :edit! dropped the text, and a later change is saved'] = function()
  local state = fixture.directory('draft-after-edit-state')
  local file = fixture.write(
    'draft-after-edit-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  keep_new_buffer(state)
  child.lua("vim.api.nvim_buf_set_name(_G.input, 'aineo://input')")
  child.cmd('edit!')
  wait_for_input({ 'Refactor the parser' })
  local input_after_edit = child.lua_get(INPUT_LINES)

  set_input({ 'Rename the lexer' })

  eq(
    { input_after_edit = input_after_edit, draft = wait_for_text(file, 'Rename the lexer\n') },
    { input_after_edit = { 'Refactor the parser' }, draft = 'Rename the lexer\n' }
  )
end

T['the draft']['put into a buffer is not taken out again by an undo'] = function()
  local state = fixture.directory('draft-undo-state')
  local file = fixture.write(
    'draft-undo-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  keep_new_buffer(state)

  child.cmd('normal! u')

  eq(
    { input = child.lua_get(INPUT_LINES), draft = read_text(file) },
    { input = { 'Refactor the parser' }, draft = 'Refactor the parser\n' }
  )
end

T['the draft']['put into a buffer leaves the changes made after it undoable'] = function()
  local state = fixture.directory('draft-undo-later-state')
  fixture.write(
    'draft-undo-later-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  keep_new_buffer(state)
  set_input({ 'Rename the lexer' })

  child.cmd('normal! u')

  eq(child.lua_get(INPUT_LINES), { 'Refactor the parser' })
end

T['the draft']['lets the buffer be wiped, and raises nothing then'] = function()
  local state = fixture.directory('draft-wiped-state')
  keep_new_buffer(state)
  set_input({ 'Refactor the parser' })
  wait_for_text(draft_file(state), 'Refactor the parser\n')

  local wiped = child.lua_get('pcall(vim.cmd.bwipeout, _G.input)')

  eq({
    wiped = wiped,
    valid = child.lua_get('vim.api.nvim_buf_is_valid(_G.input)'),
    error = child.lua_get('vim.v.errmsg'),
  }, { wiped = true, valid = false, error = '' })
end

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

--- Makes the child's `_G.input` a new, empty scratch buffer that is not
--- 'modifiable', as every buffer is in a Neovim started with `-M`, shown in
--- the current window.
local NEW_UNMODIFIABLE_BUFFER = [[
  _G.input = vim.api.nvim_create_buf(false, true)
  vim.bo[_G.input].modifiable = false
  vim.api.nvim_win_set_buf(0, _G.input)
]]

--- Gives the draft home in the child its environment, the state directory
--- and the working directory it is given, and hands it `_G.input`; says
--- whether the hand-off raised nothing.
local KEEP_INPUT = [[
  local state, working_directory = ...
  local draft = require('aineo.draft')
  draft.set_draft_environment({ state_directory = state, working_directory = working_directory })
  return pcall(draft.keep_draft, _G.input)
]]

--- Makes the child's `_G.input` a new, empty scratch buffer with an
--- 'undolevels' of its own, 7, shown in the current window.
local NEW_BUFFER_WITH_ITS_OWN_UNDOLEVELS = [[
  _G.input = vim.api.nvim_create_buf(false, true)
  vim.bo[_G.input].undolevels = 7
  vim.api.nvim_win_set_buf(0, _G.input)
]]

T['the draft']["put into a buffer leaves the buffer's own 'undolevels' as they were"] = function()
  local state = fixture.directory('draft-undolevels-state')
  fixture.write(
    'draft-undolevels-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(NEW_BUFFER_WITH_ITS_OWN_UNDOLEVELS)

  child.lua(KEEP_INPUT, { state, WORKING_DIRECTORY })

  eq({
    input = child.lua_get(INPUT_LINES),
    undolevels = child.lua_get('vim.bo[_G.input].undolevels'),
  }, { input = { 'Refactor the parser' }, undolevels = 7 })
end

T['a buffer that is not modifiable'] = MiniTest.new_set()

T['a buffer that is not modifiable']['is told once as a warning that the draft cannot be put in, and raises nothing'] = function()
  local state = fixture.directory('draft-unmodifiable-state')
  local file = fixture.write(
    'draft-unmodifiable-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(KEEP_NOTIFICATIONS)
  child.lua(NEW_UNMODIFIABLE_BUFFER)

  local raised_nothing = child.lua(KEEP_INPUT, { state, WORKING_DIRECTORY })

  eq(raised_nothing, true)
  eq(child.lua_get('_G.notifications'), {
    {
      level = vim.log.levels.WARN,
      message = ("aineo: cannot put Input's draft in %s into Input: Buffer is not 'modifiable'"):format(
        file
      ),
    },
  })
end

T['a buffer that is not modifiable']['is kept, so a change once it is made modifiable is saved'] = function()
  local state = fixture.directory('draft-made-modifiable-state')
  local file = fixture.write(
    'draft-made-modifiable-state/aineo/drafts/' .. vim.fs.basename(draft_file(state)),
    { 'Refactor the parser' }
  )
  child.lua(KEEP_NOTIFICATIONS)
  child.lua(NEW_UNMODIFIABLE_BUFFER)
  child.lua(KEEP_INPUT, { state, WORKING_DIRECTORY })
  child.lua('vim.bo[_G.input].modifiable = true')

  set_input({ 'Rename the lexer' })

  eq(wait_for_text(file, 'Rename the lexer\n'), 'Rename the lexer\n')
end

T['a draft that cannot be written'] = MiniTest.new_set()

--- Empties the kept buffer, `_G.input` in the child, as a change through the
--- API does, and says whether the change raised nothing.
local EMPTY_INPUT = 'pcall(vim.api.nvim_buf_set_lines, _G.input, 0, -1, true, {})'

--- Makes the directory making of the draft home in the child,
--- `_G.draft_files`, fail every time, counting its tries in
--- `_G.failed_makings`.
local MAKING_THAT_FAILS = [[
  _G.failed_makings = 0
  _G.draft_files = {
    make_directory = function()
      _G.failed_makings = _G.failed_makings + 1
      return 'E739: Cannot create directory: the disk is full'
    end,
  }
]]

T['a draft that cannot be written']['is told once Insert mode is left, not while typing'] = function()
  local state = fixture.directory('draft-unwritable-insert-state')
  child.lua(KEEP_NOTIFICATIONS)
  child.lua(MAKING_THAT_FAILS)
  keep_new_buffer(state)
  child.type_keys('i', 'Refactor the parser')
  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.failed_makings') > 0
  end, 20)
  local while_typing = child.lua_get('_G.notifications')

  child.type_keys('<Esc>')

  eq({ while_typing = while_typing, once_left = child.lua_get('_G.notifications') }, {
    while_typing = {},
    once_left = {
      {
        level = vim.log.levels.WARN,
        message = ("aineo: cannot keep Input's draft in %s: E739: Cannot create directory: the disk is full"):format(
          draft_file(state)
        ),
      },
    },
  })
end

--- Makes the child write every notification it gives, as its level and
--- message on a line of their own, to the file given, which outlives it.
local NOTIFICATIONS_KEPT_IN = [[
  local file_path = ...
  vim.notify = function(message, level)
    local file = assert(io.open(file_path, 'a'))
    file:write(level .. ' ' .. message .. '\n')
    file:close()
  end
]]

T['a draft that cannot be written']['with a change pending is told as a warning as Neovim quits'] = function()
  local state = fixture.directory('draft-unwritable-told-at-quit-state')
  local told = vim.fs.joinpath(state, 'told')
  child.lua(NOTIFICATIONS_KEPT_IN, { told })
  keep_new_buffer(state)
  local drafts = fixture.write('draft-unwritable-told-at-quit-state/aineo/drafts', {})

  change_input_and_quit({ 'Refactor the parser' })

  eq(
    read_text(told),
    ("%d aineo: cannot keep Input's draft in %s: E739: Cannot create directory %s: file already exists\n"):format(
      vim.log.levels.WARN,
      draft_file(state),
      drafts
    )
  )
end

T['a draft that cannot be written']['is told once Insert mode is left with <C-c>, before a quit'] = function()
  local state = fixture.directory('draft-unwritable-ctrl-c-state')
  local told = vim.fs.joinpath(state, 'told')
  child.lua(NOTIFICATIONS_KEPT_IN, { told })
  child.lua(MAKING_THAT_FAILS)
  keep_new_buffer(state)
  child.type_keys('i', 'Refactor the parser')
  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.failed_makings') > 0
  end, 20)
  child.type_keys('<C-c>')

  quit()

  eq(
    read_text(told),
    ("%d aineo: cannot keep Input's draft in %s: E739: Cannot create directory: the disk is full\n"):format(
      vim.log.levels.WARN,
      draft_file(state)
    )
  )
end

--- Opens in the child, beside the kept buffer, a terminal running `cat`, as
--- Claude's terminal runs beside Input, and enters Terminal mode in it.
local TERMINAL_BESIDE_INPUT = [[
  vim.cmd('rightbelow vsplit | enew')
  vim.fn.jobstart({ 'cat' }, { term = true })
  vim.cmd.startinsert()
]]

T['a draft that cannot be written']['is told once Terminal mode is left, not while typing in a terminal'] = function()
  local state = fixture.directory('draft-unwritable-terminal-state')
  child.lua(KEEP_NOTIFICATIONS)
  child.lua(MAKING_THAT_FAILS)
  keep_new_buffer(state)
  child.lua(TERMINAL_BESIDE_INPUT)
  vim.wait(SAVE_PATIENCE_MS, function()
    return child.api.nvim_get_mode().mode == 't'
  end, 20)
  set_input({ 'Refactor the parser' })
  vim.wait(SAVE_PATIENCE_MS, function()
    return child.lua_get('_G.failed_makings') > 0
  end, 20)
  local while_in_terminal = child.lua_get('#_G.notifications')

  child.type_keys([[<C-\><C-n>]])

  eq({ while_in_terminal = while_in_terminal, once_left = child.lua_get('#_G.notifications') }, {
    while_in_terminal = 0,
    once_left = 1,
  })
end

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

--- Makes the directory making of the draft home in an editor,
--- `_G.draft_files`, make directories as the default does, keeping a mark
--- for each try in the file given, which outlives the editor.
local MAKING_COUNTED_IN = [[
  local marker = ...
  _G.draft_files = {
    make_directory = function(path)
      local file = assert(io.open(marker, 'a'))
      file:write('x')
      file:close()
      local made, failure = pcall(vim.fn.mkdir, path, 'p')
      if not made then
        return (tostring(failure):gsub('^Vim:', ''))
      end
    end,
  }
]]

T['a draft that cannot be written']['with a change pending tries the save at quit and lets an editor with a screen quit at once'] = function()
  local state = fixture.directory('draft-unwritable-quit-state')
  local marker = vim.fs.joinpath(state, 'tries')
  local editor = entry_editor.start(child, children.restart)
  entry_editor.request(editor, MAKING_COUNTED_IN, { marker })
  entry_editor.request(editor, KEEP_NEW_BUFFER, { state, WORKING_DIRECTORY })
  fixture.write('draft-unwritable-quit-state/aineo/drafts', {})

  vim.rpcnotify(
    editor.channel,
    'nvim_exec_lua',
    'vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...); vim.cmd.qall()',
    { { 'Refactor the parser' } }
  )

  eq(child.lua_get('vim.fn.jobwait({ vim.bo.channel }, ...)', { QUIT_PATIENCE_MS }), { 0 })
  no_eq(read_text(marker), nil)
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

--- Makes the file opening of the draft home in an editor, `_G.draft_files`,
--- open as the default does, keeping every path it opens in
--- `_G.written_paths`.
local WRITES_KEEPING_THEIR_PATHS = [[
  _G.written_paths = {}
  _G.draft_files = {
    open_file = function(path)
      table.insert(_G.written_paths, path)
      return vim.uv.fs_open(path, 'w', tonumber('600', 8))
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

  local child_path = child.lua_get('_G.written_paths[1]')
  local other_path = other.lua_get('_G.written_paths[1]')
  eq({ type(child_path), type(other_path) }, { 'string', 'string' })
  no_eq(child_path, other_path)
end

return T
