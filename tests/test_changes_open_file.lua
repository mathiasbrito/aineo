local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local children = dofile('tests/helpers/child.lua')

local child = MiniTest.new_child_neovim()

--- A second editor, holding a file open so that its swap file exists.
local other = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = function()
      child.stop()
      other.stop()
    end,
  },
})

--- The name of the changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- The Lua that begins the changes home's session in the child for the
--- directory `...` and the working branch that follows it, if any, and shows
--- the pane's two buffers there: the files buffer in the current window, the
--- commits buffer in a window below it. The home is given no layout: a
--- buffer it shows is kept in `_G.shown_diffs` and shown in a window of its
--- own at the bottom.
local BEGIN_AND_SHOW = [[
  local directory, working_branch = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    working_branch = working_branch,
    show_diff = function(diff)
      if _G.no_room then
        return nil
      end
      table.insert(_G.shown_diffs, diff)
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
  })
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return git_repo.without_against_line(
    child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
  )
end

--- Waits until the child's buffer named `name` holds `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param name string
---@param expected string[]
local function expect_lines(name, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(lines_of(name), expected)
  end, 10)
  eq(lines_of(name), expected)
end

--- Makes a repository whose base commit holds `notes.txt`, writes `files`
--- (path to lines) into its working tree, begins the session there with the
--- pane shown and waits for the files window to list `expected`. Returns the
--- top level.
---
---@param name string
---@param files table<string, string[]>
---@param expected string[] the files window's lines
---@return string top
local function pane_listing(name, files, expected)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  for path, lines in pairs(files) do
    git_repo.write(top, path, lines)
  end
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, expected)
  return top
end

--- Makes a repository whose base commit holds `notes.txt`, writes the one
--- file `name` into its working tree, begins the session there with the pane
--- shown and waits for the files window to list it on its second line.
--- Returns the top level.
---
---@param case string the case's own name
---@param name string the one file's name
---@return string top
local function pane_listing_one_file(case, name)
  local top = git_repo.create(case, { ['notes.txt'] = { 'one' } })
  git_repo.write(top, name, { 'text' })
  child.lua(BEGIN_AND_SHOW, { top })
  git_repo.wait_until('the file listed', function()
    return (lines_of(FILES)[2] or ''):find('^  %? ') ~= nil
  end)
  return top
end

--- Makes the commits window the current one and puts its cursor on line
--- `line`, as the user's keys do.
---
---@param line integer
local function go_to_commits_line(line)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })
  child.type_keys(line .. 'G')
end

--- Puts the cursor on line `line` of the files window and presses `gf`
--- there.
---
---@param line integer
local function press_gf_on(line)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { git_repo.files_window_line(line) })
  child.type_keys('gf')
end

--- The name of the buffer in the child's current window.
---
---@return string
local function current_buffer_name()
  return child.lua_get('vim.api.nvim_buf_get_name(0)')
end

--- The Lua expression giving everything the child's messages hold.
local TOLD = "vim.api.nvim_exec2('messages', { output = true }).output"

T['gf'] = MiniTest.new_set()

T['gf']['opens the file whose name holds a space, which Vim’s own gf would cut at it'] = function()
  local top = pane_listing(
    'openfile-space',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, 'has space.txt'))
end

--- The names of files whose characters Vim's own `gf`, a command line or a
--- wildcard would take for something else.
local AWKWARD_NAMES = {
  { 'an apostrophe', "it's.txt" },
  { 'a tab', 'a\tb.txt' },
  { 'a double quote', 'say "hi".txt' },
  { 'characters outside ASCII', 'café ✓.txt' },
  { 'a percent sign and a hash', '100% #1.txt' },
  { 'a bar', 'a|b.txt' },
  { 'wildcards', '[a]*?{b}.txt' },
  { 'a backslash', 'a\\b.txt' },
  { 'a line break', 'a\nb.txt' },
  { 'a leading plus', '+-x.txt' },
  { 'a backtick command', '`touch pwned`' },
}

T['gf']['opens a file whose name holds'] = MiniTest.new_set({ parametrize = AWKWARD_NAMES })

T['gf']['opens a file whose name holds']['characters'] = function(_, name)
  local top = pane_listing_one_file('openfile-awkward', name)
  child.cmd('cd ' .. vim.fn.fnameescape(top))

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, name))
  eq(vim.uv.fs_stat(vim.fs.joinpath(top, 'pwned')), nil)
end

T['gf']['opens the file called [x].txt, not the x.txt a wildcard would match'] = function()
  local top = pane_listing(
    'openfile-wildcard-neighbour',
    { ['x.txt'] = { 'wrong' }, ['[x].txt'] = { 'right' } },
    { 'Files in: Session work', '  ? [x].txt', '  ? x.txt' }
  )

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, '[x].txt'))
end

T['gf']['on a deleted file opens nothing and says the file is gone'] = function()
  local top = pane_listing(
    'openfile-deleted',
    { ['notes.txt'] = { 'two' } },
    { 'Files in: Session work', '  M notes.txt' }
  )
  vim.fn.delete(vim.fs.joinpath(top, 'notes.txt'))
  expect_lines(FILES, { 'Files in: Session work', '  D notes.txt' })

  press_gf_on(2)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), 'aineo: notes.txt is gone from the working tree')
end

T['gf']['on a deleted file names it as the files window does'] = function()
  local top = git_repo.create('openfile-deleted-quoted', { ['say "hi".txt'] = { 'one' } })
  git_repo.write(top, 'say "hi".txt', { 'two' })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, { 'Files in: Session work', '  M "say \\"hi\\".txt"' })
  vim.fn.delete(vim.fs.joinpath(top, 'say "hi".txt'))
  expect_lines(FILES, { 'Files in: Session work', '  D "say \\"hi\\".txt"' })

  press_gf_on(2)

  eq(child.lua_get(TOLD), 'aineo: "say \\"hi\\".txt" is gone from the working tree')
end

--- Makes a repository whose base commit holds `notes.txt`, begins the
--- session there with the pane shown, commits `files` (path to lines, or
--- false for a file to delete) as `Add the files`, selects that commit in
--- the commits window and waits for the files window to list `listed`.
--- Returns the top level and the commit's full id.
---
---@param case string the case's own name
---@param files table<string, string[]|false>
---@param listed string[] the files window's lines after its heading
---@return string top
---@return string commit
local function pane_under_commit(case, files, listed)
  local top = git_repo.create(case, { ['notes.txt'] = { 'one' } })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  for path, lines in pairs(files) do
    if lines then
      git_repo.write(top, path, lines)
    else
      vim.fn.delete(vim.fs.joinpath(top, path))
    end
  end
  local commit = git_repo.commit_all(top, 'Add the files')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(
    COMMITS,
    { 'Uncommitted', 'Session work', git_repo.commit_line(commit, 'Add the files') }
  )
  go_to_commits_line(3)
  expect_lines(
    FILES,
    vim.list_extend({ 'Files in: ' .. git_repo.commit_line(commit, 'Add the files') }, listed)
  )
  return top, commit
end

--- Waits until the child's current buffer is not the files buffer: a key of
--- the files window has shown something in the middle column.
local function wait_for_file_shown()
  git_repo.wait_until('the file shown', function()
    return current_buffer_name() ~= FILES
  end)
end

T['gf']['under a commit shows the file as the commit had it, not the working tree’s file'] = function()
  local top, commit = pane_under_commit(
    'openfile-commit-filter',
    { ['has space.txt'] = { 'in the commit' } },
    { '  A has space.txt' }
  )
  git_repo.write(top, 'has space.txt', { 'in the working tree' })

  press_gf_on(2)

  wait_for_file_shown()
  eq(current_buffer_name(), 'aineo://show/' .. commit .. '/has space.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'in the commit' })
end

T['gf']['under a commit leaves the file’s buffer not modifiable'] = function()
  pane_under_commit(
    'openfile-commit-readonly',
    { ['has space.txt'] = { 'text' } },
    { '  A has space.txt' }
  )

  press_gf_on(2)

  wait_for_file_shown()
  eq(child.lua_get('vim.bo.modifiable'), false)
end

T['gf']['under a commit shows the file in the middle column through the session’s show_diff'] = function()
  pane_under_commit(
    'openfile-commit-shown',
    { ['has space.txt'] = { 'text' } },
    { '  A has space.txt' }
  )

  press_gf_on(2)

  wait_for_file_shown()
  eq(child.lua_get('#_G.shown_diffs'), 1)
  eq(child.lua_get('_G.shown_diffs[1] == vim.api.nvim_get_current_buf()'), true)
end

--- The Lua giving what the current buffer shows as virtual lines: how many
--- there are, the line the first sits under (-1 for none) and its text, and
--- the buffer's last line and its text.
local VIRTUAL_NOTES = [[(function()
  local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
  local last_row = vim.api.nvim_buf_line_count(0) - 1
  return {
    count = #marks,
    row = marks[1] and marks[1][2] or -1,
    text = marks[1] and marks[1][4].virt_lines[1][1][1] or '',
    last_row = last_row,
    last_line = vim.api.nvim_buf_get_lines(0, last_row, last_row + 1, true)[1],
  }
end)()]]

--- Commits `long.txt` of 22 000 lines, over 1 MiB, selects the commit and
--- presses `gf` on the file.
---
---@param case string
local function show_a_file_over_1_mib(case)
  local long = {}
  for number = 1, 22000 do
    long[number] = ('line %05d %s'):format(number, ('x'):rep(40))
  end
  pane_under_commit(case, { ['long.txt'] = long }, { '  A long.txt' })
  press_gf_on(2)
  wait_for_file_shown()
end

T['gf']['under a commit shows a file larger than 1 MiB cut, a virtual line under its last line saying so'] = function()
  show_a_file_over_1_mib('openfile-commit-long')

  local shown = child.lua_get(VIRTUAL_NOTES)
  eq({
    last_line_is_the_files = vim.startswith(shown.last_line, 'line '),
    row_is_the_last = shown.row == shown.last_row,
    text_is_the_note = vim.startswith(shown.text, 'aineo cut this file at 1 MiB: '),
    count = shown.count,
  }, {
    last_line_is_the_files = true,
    row_is_the_last = true,
    text_is_the_note = true,
    count = 1,
  })
end

T['gf']['under a commit tells in the note how much of the whole file is shown, by the size git gave'] = function()
  show_a_file_over_1_mib('openfile-commit-long-size')

  eq(
    child.lua_get(VIRTUAL_NOTES).text,
    'aineo cut this file at 1 MiB: 1048528 of its 1144000 bytes are shown'
  )
end

T['gf']['under a commit asks git for the bytes it shows and six more, no more of the file'] = function()
  pane_under_commit('openfile-commit-asks', { ['a.txt'] = { 'text' } }, { '  A a.txt' })
  child.lua([=[
    require('aineo.git').file_at_commit = function(_, _, _, done, _, first_bytes)
      _G.asked_for = first_bytes
      done(nil, 'text\n', 5)
    end
  ]=])

  press_gf_on(2)

  wait_for_file_shown()
  eq(child.lua_get('_G.asked_for'), 1048576 + 6)
end

T['gf']['under a commit cuts a first line whose six-byte lead stands at the bound as it would be cut whole'] = function()
  local line = ('a'):rep(1048575) .. '\252\128\128\128\128\128' .. ('a'):rep(100)
  pane_under_commit(
    'openfile-commit-six-byte-lead',
    { ['blob.bin'] = { line } },
    { '  A blob.bin' }
  )

  press_gf_on(2)

  wait_for_file_shown()
  eq({
    shown = child.lua_get('#vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]'),
    note = child.lua_get(VIRTUAL_NOTES).text,
  }, {
    shown = 1048575,
    note = 'aineo cut this file at 1 MiB: 1048575 of its 1048682 bytes are shown',
  })
end

T['gf']['under a commit cuts a first line longer than 1 MiB on a character’s edge'] = function()
  local euros = ('€'):rep(400000)
  pane_under_commit('openfile-commit-long-line', { ['wide.txt'] = { euros } }, { '  A wide.txt' })

  press_gf_on(2)

  wait_for_file_shown()
  eq({
    shown = child.lua_get('#vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]'),
    note = child.lua_get(VIRTUAL_NOTES).text,
  }, {
    shown = 1048575,
    note = 'aineo cut this file at 1 MiB: 1048575 of its 1200001 bytes are shown',
  })
end

T['gf']['under a commit writes the note of a cut file once again after :edit!'] = function()
  show_a_file_over_1_mib('openfile-commit-long-again')

  child.cmd('edit!')

  eq(child.lua_get(VIRTUAL_NOTES).count, 1)
end

--- Files whose path and content give a `'filetype'`, or none.
local FILETYPES = {
  { 'a Lua file', 'tool.lua', { 'return 1' }, 'lua' },
  { 'a script with a shebang and no extension', 'run', { '#!/bin/sh', 'true' }, 'sh' },
  { 'a file whose path gives none', 'notes.zzz', { 'text' }, '' },
}

T['gf']['under a commit gives the buffer the filetype of'] = MiniTest.new_set({
  parametrize = FILETYPES,
})

T['gf']['under a commit gives the buffer the filetype of']['the file'] = function(
  _,
  path,
  content,
  filetype
)
  pane_under_commit('openfile-commit-filetype', { [path] = content }, { '  A ' .. path })

  press_gf_on(2)

  wait_for_file_shown()
  eq(child.lua_get('vim.bo.filetype'), filetype)
end

--- Waits until the child has been told something, and returns everything
--- its messages hold.
---
---@return string
local function told_something()
  git_repo.wait_until('something told', function()
    return child.lua_get(TOLD) ~= ''
  end)
  return child.lua_get(TOLD)
end

T['gf']['under a commit on a file the commit deleted shows nothing and says it was deleted there'] = function()
  local _, commit = pane_under_commit(
    'openfile-commit-deleted',
    { ['notes.txt'] = false },
    { '  D notes.txt' }
  )

  press_gf_on(2)

  eq(told_something(), ('aineo: notes.txt was deleted in commit %s'):format(commit:sub(1, 7)))
  eq({ current_buffer_name(), child.lua_get('#_G.shown_diffs') }, { FILES, 0 })
end

T['gf']['under a commit whose object git cannot read tells git’s words once, naming the file'] = function()
  local top, commit = pane_under_commit(
    'openfile-commit-lost-object',
    { ['lost.txt'] = { 'text' } },
    { '  A lost.txt' }
  )
  local blob = git_repo.git(top, { 'rev-parse', commit .. ':lost.txt' })
  assert(
    vim.fn.delete(vim.fs.joinpath(top, '.git', 'objects', blob:sub(1, 2), blob:sub(3))) == 0,
    'the blob’s loose object deleted'
  )

  press_gf_on(2)

  eq(
    told_something(),
    ('aineo: lost.txt could not be read in commit %s: fatal: git cat-file %s: bad file'):format(
      commit:sub(1, 7),
      blob
    )
  )
end

T['gf']['under a commit whose file cannot be read tells git’s words once, naming the file'] = function()
  local _, commit = pane_under_commit(
    'openfile-commit-unreadable',
    { ['has space.txt'] = { 'text' } },
    { '  A has space.txt' }
  )
  child.lua([[
    require('aineo.git').file_at_commit = function(_, _, _, done)
      done({ reason = 'failed', message = 'broken object' })
    end
  ]])

  local told = ('aineo: has space.txt could not be read in commit %s: broken object'):format(
    commit:sub(1, 7)
  )

  MiniTest.expect.error(function()
    press_gf_on(2)
  end, told)

  eq(child.lua_get(TOLD), told)
  eq({ current_buffer_name(), child.lua_get('#_G.shown_diffs') }, { FILES, 0 })
end

T['gf']['under a commit names a failure after the file as the files window quotes it'] = function()
  local _, commit = pane_under_commit(
    'openfile-commit-quoted-told',
    { ['say "hi".txt'] = { 'text' } },
    { '  A "say \\"hi\\".txt"' }
  )
  child.lua([[
    require('aineo.git').file_at_commit = function(_, _, _, done)
      done({ reason = 'path_missing' })
    end
  ]])

  press_gf_on(2)

  eq(
    told_something(),
    ('aineo: "say \\"hi\\".txt" was deleted in commit %s'):format(commit:sub(1, 7))
  )
end

T['gf']['under a commit with no room in the middle column shows nothing and says so'] = function()
  local _, commit = pane_under_commit(
    'openfile-commit-no-room',
    { ['say "hi".txt'] = { 'text' } },
    { '  A "say \\"hi\\".txt"' }
  )
  child.lua('_G.no_room = true')

  press_gf_on(2)

  eq(
    told_something(),
    ('aineo: the middle column has no room for "say \\"hi\\".txt" in commit %s, which is not shown'):format(
      commit:sub(1, 7)
    )
  )
  local file_buffer =
    child.lua_get('vim.fn.bufnr(...)', { 'aineo://show/' .. commit .. '/"say \\"hi\\".txt"' })
  eq({ current_buffer_name(), file_buffer }, { FILES, -1 })
end

T['gf']['under a commit read while textlock holds shows the file once the editor allows it'] = function()
  pane_under_commit(
    'openfile-commit-textlock',
    { ['has space.txt'] = { 'text' } },
    { '  A has space.txt' }
  )
  child.lua([[
    require('aineo.git').file_at_commit = function(_, _, _, done)
      _G.finish = done
    end
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      vim.fn.getcharstr()
      _G.holding = false
      return ''
    end, { expr = true })
  ]])
  press_gf_on(2)
  child.api.nvim_input('X')
  git_repo.wait_until('textlock held', function()
    return child.lua_get('_G.holding == true')
  end)

  child.lua('_G.finish(nil, "in the commit\\n", 14)')
  local meanwhile = child.lua_get('#_G.shown_diffs')
  child.api.nvim_input('q')

  git_repo.wait_until('the file shown', function()
    return child.lua_get('#_G.shown_diffs') == 1
  end)
  eq(meanwhile, 0)
  eq(
    child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[1], 0, -1, true)'),
    { 'in the commit' }
  )
  eq(child.lua_get(TOLD), '')
end

T['gf']['under a commit, then on another file before the first is read, shows the last key’s file alone'] = function()
  local _, commit = pane_under_commit(
    'openfile-commit-twice',
    { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    { '  A a.txt', '  A b.txt' }
  )
  child.lua([[
    _G.pending = {}
    require('aineo.git').file_at_commit = function(_, _, path, done)
      _G.pending[path] = done
    end
  ]])
  press_gf_on(2)
  press_gf_on(3)

  child.lua('_G.pending["b.txt"](nil, "b text\\n", 7)')
  child.lua('_G.pending["a.txt"](nil, "a text\\n", 7)')

  eq(child.lua_get('#_G.shown_diffs'), 1)
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[1])'),
    'aineo://show/' .. commit .. '/b.txt'
  )
  eq(child.lua_get('vim.fn.bufnr(...)', { 'aineo://show/' .. commit .. '/a.txt' }), -1)
end

T['gf']['under a commit of another worktree shows the file as that commit has it'] = function()
  local top = git_repo.create('openfile-worktree-commit', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(agent, 'notes.txt', { 'in the agent’s commit' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  git_repo.write(agent, 'notes.txt', { 'in the agent’s tree' })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    git_repo.commit_line(commit, 'The agent’s'),
  })
  go_to_commits_line(5)
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line(commit, 'The agent’s (worktree agent)'),
    '  M notes.txt',
  })

  press_gf_on(2)

  wait_for_file_shown()
  eq(current_buffer_name(), 'aineo://show/' .. commit .. '/notes.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'in the agent’s commit' })
end

T['gf']['under a commit of another worktree reads it in that worktree’s repository'] = function()
  local top = git_repo.create('openfile-worktree-clone', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  vim.fn.delete(agent, 'rf')
  git_repo.git(vim.fs.dirname(top), { 'clone', '--quiet', '--branch', 'main', top, agent })
  git_repo.git(agent, { 'switch', '--quiet', '--create', 'agent' })
  git_repo.write(agent, 'notes.txt', { 'in the clone’s commit' })
  local commit = git_repo.commit_all(agent, 'Clone')
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    git_repo.commit_line(commit, 'Clone'),
  })
  go_to_commits_line(5)
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line(commit, 'Clone (worktree agent)'),
    '  M notes.txt',
  })

  press_gf_on(2)

  wait_for_file_shown()
  eq(current_buffer_name(), 'aineo://show/' .. commit .. '/notes.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'in the clone’s commit' })
end

T['gf']['under Uncommitted opens the working tree’s file, as before'] = function()
  local top = pane_listing(
    'openfile-uncommitted',
    { ['notes.txt'] = { 'two' } },
    { 'Files in: Session work', '  M notes.txt' }
  )
  go_to_commits_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', '  M notes.txt' })

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, 'notes.txt'))
end

--- Makes a repository on `main` whose base commit holds `a.txt`, with a
--- branch `dev` that holds two commits main lacks, each changing `a.txt`:
--- what landed in the working branch `dev`. Begins the session there with
--- `dev` the working branch, shows the pane and waits for the commits window
--- to list what landed. Returns the commits' full ids, the older first.
---
---@param case string the case's own name
---@param file? string the file's name, `a.txt` when not given
---@return string first
---@return string second
local function pane_with_landed(case, file)
  file = file or 'a.txt'
  local top = git_repo.create(case, { [file] = { 'one' } })
  git_repo.git(top, { 'switch', '--quiet', '--create', 'dev' })
  git_repo.write(top, file, { 'first' })
  local first = git_repo.commit_all(top, 'Land first')
  git_repo.write(top, file, { 'second' })
  local second = git_repo.commit_all(top, 'Land second')
  git_repo.git(top, { 'switch', '--quiet', 'main' })
  child.lua(BEGIN_AND_SHOW, { top, 'dev' })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in dev',
    git_repo.commit_line(second, 'Land second'),
    git_repo.commit_line(first, 'Land first'),
  })
  return first, second
end

T['gf']['under Landed shows the file as the working branch’s commit has it'] = function()
  local _, second = pane_with_landed('openfile-landed-heading')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M a.txt' })

  press_gf_on(2)

  wait_for_file_shown()
  eq(current_buffer_name(), 'aineo://show/' .. second .. '/a.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'second' })
end

T['gf']['under a landed commit shows the file as that commit has it'] = function()
  local first = pane_with_landed('openfile-landed-commit')
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: ' .. git_repo.commit_line(first, 'Land first'), '  M a.txt' })

  press_gf_on(2)

  wait_for_file_shown()
  eq(current_buffer_name(), 'aineo://show/' .. first .. '/a.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)'), { 'first' })
end

T['gf']['under a commit, then on another file before the first is read, tells nothing of the first read’s failure'] = function()
  pane_under_commit(
    'openfile-commit-twice-failed',
    { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } },
    { '  A a.txt', '  A b.txt' }
  )
  child.lua([[
    _G.pending = {}
    require('aineo.git').file_at_commit = function(_, _, path, done)
      _G.pending[path] = done
    end
  ]])
  press_gf_on(2)
  press_gf_on(3)

  child.lua('_G.pending["a.txt"]({ reason = "failed", message = "late" })')
  child.lua('_G.pending["b.txt"](nil, "b text\\n", 7)')

  eq({ child.lua_get(TOLD), child.lua_get('#_G.shown_diffs') }, { '', 1 })
end

T['gf']['on the working tree’s file, after l before its diff was read, leaves the file shown alone'] = function()
  local top = pane_listing(
    'openfile-after-l',
    { ['notes.txt'] = { 'two' } },
    { 'Files in: Session work', '  M notes.txt' }
  )
  child.lua([[
    require('aineo.git').file_diff = function(_, _, _, done)
      _G.finish = done
    end
  ]])
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.type_keys('l')
  git_repo.wait_until('the diff asked for', function()
    return child.lua_get('_G.finish ~= nil')
  end)
  press_gf_on(2)

  child.lua('_G.finish(nil, "diff --git a/notes.txt b/notes.txt\\n-one\\n+two\\n")')

  eq({ current_buffer_name(), child.lua_get('#_G.shown_diffs') }, {
    vim.fs.joinpath(top, 'notes.txt'),
    0,
  })
end

T['gf']['under a commit names the buffer after the file as the files window quotes it'] = function()
  local _, commit = pane_under_commit(
    'openfile-commit-quoted',
    { ['say "hi".txt'] = { 'text' } },
    { '  A "say \\"hi\\".txt"' }
  )

  press_gf_on(2)

  wait_for_file_shown()
  eq(current_buffer_name(), 'aineo://show/' .. commit .. '/"say \\"hi\\".txt"')
end

T['gf']['under Landed, once the working branch names no commit, shows nothing and says why'] = function()
  pane_with_landed('openfile-landed-gone', 'say "hi".txt')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M "say \\"hi\\".txt"' })
  child.lua([[
    local landed = require('aineo.changes.landed')
    landed.read = function(_, done)
      done({ name = 'dev', names_no_commit = true })
    end
    require('aineo.changes').refresh_shown_pane()
    vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://changes-files'))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
  ]])

  child.lua("vim.fn.maparg('gf', 'n', false, true).callback()")

  eq(child.lua_get(TOLD), 'aineo: "say \\"hi\\".txt" could not be read: dev names no commit')
  eq(child.lua_get('#_G.shown_diffs'), 0)
end

T['gf']['on a link whose target is missing opens the link, which is in the working tree'] = function()
  local top = pane_listing(
    'openfile-dangling',
    {},
    { 'Files in: Session work', 'No files changed on this session' }
  )
  assert(vim.uv.fs_symlink('missing-target.txt', vim.fs.joinpath(top, 'link.txt')))
  expect_lines(FILES, { 'Files in: Session work', '  ? link.txt' })

  press_gf_on(2)

  eq(current_buffer_name(), vim.fs.joinpath(top, 'link.txt'))
  eq(child.lua_get(TOLD), '')
end

T['gf']['on a directory’s line, a nested repository’s, opens nothing and says it is a directory'] = function()
  local top = git_repo.create('openfile-directory', { ['notes.txt'] = { 'one' } })
  git_repo.git(top, { 'init', '--quiet', 'nested' })
  git_repo.write(top, 'nested/inner.txt', { 'text' })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, { 'Files in: Session work', '  ? nested/' })

  MiniTest.expect.no_error(function()
    press_gf_on(2)
  end)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), 'aineo: nested/ is a directory, not a file')
end

T['gf']['that :edit refuses is told once, not raised as an error of the plugin'] = function()
  pane_listing(
    'openfile-refused',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )
  child.lua('vim.wo[vim.fn.bufwinid(...)].winfixbuf = true', { FILES })

  MiniTest.expect.error(function()
    press_gf_on(2)
  end, 'aineo: has space.txt could not be opened: Vim:E1513')

  eq(current_buffer_name(), FILES)
end

T['gf']['that the user abandons at the swap file’s prompt is dropped, as Vim’s own gf drops it'] = function()
  local top = pane_listing(
    'openfile-abandoned',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )
  children.restart(other)
  other.o.updatecount = 200
  other.lua('vim.cmd.edit(vim.fn.fnameescape(...))', { vim.fs.joinpath(top, 'has space.txt') })
  child.o.updatecount = 200
  child.lua([[
    vim.api.nvim_create_autocmd('SwapExists', {
      callback = function()
        vim.v.swapchoice = 'a'
      end,
    })
  ]])

  MiniTest.expect.no_error(function()
    press_gf_on(2)
  end)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD):find('could not be opened', 1, true), nil)
end

T['gf']['on another worktree’s file opens nothing, not the editor’s file of that name, and says so'] = function()
  local top = git_repo.create('openfile-other-worktree', { ['notes.txt'] = { 'one' } })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(top, 'same.txt', { 'mine' })
  git_repo.write(agent, 'same.txt', { 'theirs' })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  ? same.txt' })

  press_gf_on(2)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), "aineo: the changes pane opens no other worktree's file")
end

--- The lines of a files window that list no file, by what they are: the
--- line of the files window, the commits window's line to select first, and
--- the files window's lines then.
local LINES_LISTING_NO_FILE = {
  {
    'the line naming the filter',
    1,
    2,
    { 'Files in: Session work', 'No files changed on this session' },
  },
  { 'a note', 2, 2, { 'Files in: Session work', 'No files changed on this session' } },
  {
    'the line naming another worktree’s change',
    1,
    4,
    { 'Files in: Worktree agent (agent)', 'No files changed in this worktree' },
  },
  {
    'a note under another worktree’s change',
    2,
    4,
    { 'Files in: Worktree agent (agent)', 'No files changed in this worktree' },
  },
}

T['gf']['on a line listing no file'] = MiniTest.new_set({ parametrize = LINES_LISTING_NO_FILE })

T['gf']['on a line listing no file']['opens nothing and says nothing'] = function(
  _,
  line,
  commits_line,
  listed
)
  local top = git_repo.create('openfile-no-file', { ['notes.txt'] = { 'one' } })
  git_repo.git(
    top,
    { 'worktree', 'add', '--quiet', '-b', 'agent', vim.fs.joinpath(vim.fs.dirname(top), 'agent') }
  )
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  go_to_commits_line(commits_line)
  expect_lines(FILES, listed)

  MiniTest.expect.no_error(function()
    press_gf_on(line)
  end)

  eq(current_buffer_name(), FILES)
  eq(child.lua_get(TOLD), '')
end

T['gf']['in the files buffer made anew opens the file as before'] = function()
  local top = pane_listing(
    'openfile-anew',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )
  child.lua(
    [[
    vim.cmd('new')
    vim.cmd('bwipeout! ' .. vim.fn.bufnr(...))
    local pane = require('aineo.changes').pane_buffers()
    vim.api.nvim_win_set_buf(0, pane.files)
  ]],
    { FILES }
  )
  expect_lines(FILES, { 'Files in: Session work', '  ? has space.txt' })

  MiniTest.expect.no_error(function()
    press_gf_on(2)
  end)

  eq(current_buffer_name(), vim.fs.joinpath(top, 'has space.txt'))
end

T['gf']['in any other buffer stays Vim’s own'] = function()
  local top = pane_listing(
    'openfile-other-buffer',
    { ['has space.txt'] = { 'text' } },
    { 'Files in: Session work', '  ? has space.txt' }
  )
  local notes = vim.fs.joinpath(top, 'notes.txt')
  child.cmd('new')
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, true, { ... })', { notes })

  child.type_keys('gf')

  eq(current_buffer_name(), notes)
end

T['gf']['in the commits buffer stays Vim’s own'] = function()
  pane_listing(
    'openfile-commits',
    {},
    { 'Files in: Session work', 'No files changed on this session' }
  )
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { 'aineo://changes-commits' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')

  MiniTest.expect.error(function()
    child.type_keys('gf')
  end, 'E447')
end

T['gf']['in a diff buffer stays Vim’s own'] = function()
  pane_listing(
    'openfile-diff',
    { ['notes.txt'] = { 'two' } },
    { 'Files in: Session work', '  M notes.txt' }
  )
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 0 })')
  child.type_keys('<CR>')
  git_repo.wait_until('the diff shown', function()
    return child.lua_get('#_G.shown_diffs') == 1
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.shown_diffs[1]))')
  child.lua('vim.api.nvim_win_set_cursor(0, { 1, 0 })')

  MiniTest.expect.error(function()
    child.type_keys('gf')
  end, 'E447')
end

return T
