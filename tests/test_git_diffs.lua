local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the diff there, from the base that follows it
--- (`vim.NIL` for none), of the change after that, and returns what
--- `_G.await` saw of the second.
local FILE_DIFF = [[
  local directory, base, change = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.file_diff(found.result, base ~= vim.NIL and base or nil, change, done)
  end)
]]

--- The id git gives the content of the file `path` under `top` as it is on
--- disk now.
---
---@param top string
---@param path string
---@return string
local function blob_on_disk(top, path)
  return git_repo.git(top, { 'hash-object', '--', path })
end

--- The lines of the unified diff `diff` after its four header lines, or nil
--- when there is no diff.
---
---@param diff string|nil
---@return string[]|nil
local function after_the_header(diff)
  if not diff then
    return nil
  end
  return vim.list_slice(vim.split(diff, '\n'), 5)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['a file’s diff'] = MiniTest.new_set()

T['a file’s diff']['runs from the base to the working tree, committed or not'] = function()
  local top, base = git_repo.create('diffs-modified', { ['a.txt'] = { 'one', 'two', 'three' } })
  git_repo.write(top, 'a.txt', { 'one', 'two, committed', 'three' })
  git_repo.commit_all(top, 'Change two')
  git_repo.write(top, 'a.txt', { 'one', 'two, committed', 'three, not staged' })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'a.txt', kind = 'modified' } })

  eq(
    seen.result,
    table.concat({
      'diff --git a/a.txt b/a.txt',
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':a.txt' }),
        blob_on_disk(top, 'a.txt')
      ),
      '--- a/a.txt',
      '+++ b/a.txt',
      '@@ -1,3 +1,3 @@',
      ' one',
      '-two',
      '-three',
      '+two, committed',
      '+three, not staged',
      '',
    }, '\n')
  )
end

T['a file’s diff']['shows an untracked file wholly added'] = function()
  local top, base = git_repo.create('diffs-untracked', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'sub/new.txt', { 'new', 'file' })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'sub/new.txt', kind = 'untracked' } })

  eq(
    seen.result,
    table.concat({
      'diff --git a/sub/new.txt b/sub/new.txt',
      'new file mode 100644',
      ('index %s..%s'):format(('0'):rep(40), blob_on_disk(top, 'sub/new.txt')),
      '--- /dev/null',
      '+++ b/sub/new.txt',
      '@@ -0,0 +1,2 @@',
      '+new',
      '+file',
      '',
    }, '\n')
  )
end

T['a file’s diff']['of an untracked file git cannot read is reported, in git’s words'] = function()
  local top, base = git_repo.create('diffs-untracked-gone', { ['a.txt'] = { 'a' } })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'gone.txt', kind = 'untracked' } })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = { reason = 'failed', message = "error: Could not access 'gone.txt'", code = 1 },
  })
end

T['a file’s diff']['shows a deleted file wholly removed'] = function()
  local top, base = git_repo.create('diffs-deleted', { ['gone.txt'] = { 'gone' } })
  local blob = git_repo.git(top, { 'rev-parse', base .. ':gone.txt' })
  assert(vim.uv.fs_unlink(top .. '/gone.txt'))

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'gone.txt', kind = 'deleted' } })

  eq(
    seen.result,
    table.concat({
      'diff --git a/gone.txt b/gone.txt',
      'deleted file mode 100644',
      ('index %s..%s'):format(blob, ('0'):rep(40)),
      '--- a/gone.txt',
      '+++ /dev/null',
      '@@ -1 +0,0 @@',
      '-gone',
      '',
    }, '\n')
  )
end

T['a file’s diff']['shows a renamed file as the rename, from its old path'] = function()
  local top, base = git_repo.create('diffs-renamed', { ['old name.txt'] = { 'kept' } })
  git_repo.git(top, { 'mv', 'old name.txt', 'new name.txt' })

  local seen = child.lua(FILE_DIFF, {
    top,
    base,
    { path = 'new name.txt', kind = 'renamed', old_path = 'old name.txt' },
  })

  eq(
    seen.result,
    table.concat({
      'diff --git a/old name.txt b/new name.txt',
      'similarity index 100%',
      'rename from old name.txt',
      'rename to new name.txt',
      '',
    }, '\n')
  )
end

T['a file’s diff']['names a file with other letters unquoted'] = function()
  local top, base = git_repo.create('diffs-letters', { ['ünï.txt'] = { 'before' } })
  git_repo.write(top, 'ünï.txt', { 'after' })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'ünï.txt', kind = 'modified' } })

  eq(vim.list_slice(vim.split(seen.result, '\n'), 1, 4), {
    'diff --git a/ünï.txt b/ünï.txt',
    ('index %s..%s 100644'):format(
      git_repo.git(top, { 'rev-parse', base .. ':ünï.txt' }),
      blob_on_disk(top, 'ünï.txt')
    ),
    '--- a/ünï.txt',
    '+++ b/ünï.txt',
  })
end

T['a file named like a pattern'] = MiniTest.new_set({
  parametrize = { { ':x.txt' }, { '*.txt' } },
})

T['a file named like a pattern']['has a diff of its own, not of the files the pattern names'] = function(
  name
)
  local top, base = git_repo.create('diffs-pattern', { [name] = { 'before' }, ['x.txt'] = { 'x' } })
  git_repo.write(top, name, { 'after' })
  git_repo.write(top, 'x.txt', { 'x, changed' })

  local seen = child.lua(FILE_DIFF, { top, base, { path = name, kind = 'modified' } })

  eq(
    seen.result,
    table.concat({
      ('diff --git a/%s b/%s'):format(name, name),
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':' .. name }),
        blob_on_disk(top, name)
      ),
      '--- a/' .. name,
      '+++ b/' .. name,
      '@@ -1 +1 @@',
      '-before',
      '+after',
      '',
    }, '\n')
  )
end

T['a file’s diff']['keeps three lines of context whatever the editor’s GIT_DIFF_OPTS says'] = function()
  local top, base = git_repo.create('diffs-diff-opts', { ['a.txt'] = { '1', '2', '3' } })
  git_repo.write(top, 'a.txt', { '1', 'two', '3' })
  child.lua('vim.env.GIT_DIFF_OPTS = "--unified=0"')

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'a.txt', kind = 'modified' } })

  eq(
    vim.list_slice(vim.split(seen.result, '\n'), 5),
    { '@@ -1,3 +1,3 @@', ' 1', '-2', '+two', ' 3', '' }
  )
end

T['an editor whose environment sets a global pathspec setting'] = MiniTest.new_set({
  parametrize = { { 'GIT_ICASE_PATHSPECS' }, { 'GIT_GLOB_PATHSPECS' } },
})

T['an editor whose environment sets a global pathspec setting']['still gets a file’s diff'] = function(
  name
)
  local top, base = git_repo.create('diffs-pathspecs', { ['a.txt'] = { '1', '2', '3' } })
  git_repo.write(top, 'a.txt', { '1', 'two', '3' })
  child.lua('vim.env[...] = "1"', { name })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'a.txt', kind = 'modified' } })

  eq({
    failure = seen.failure,
    hunk = after_the_header(seen.result),
  }, { hunk = { '@@ -1,3 +1,3 @@', ' 1', '-2', '+two', ' 3', '' } })
end

T['a file’s diff']['is text whatever attribute source the editor’s environment names'] = function()
  local top, base = git_repo.create(
    'diffs-attr-source',
    { ['a.txt'] = { '1', '2', '3' }, ['.gitattributes'] = { '* -diff' } }
  )
  git_repo.git(top, { 'rm', '--quiet', '.gitattributes' })
  git_repo.write(top, 'a.txt', { '1', 'two', '3' })
  child.lua('vim.env.GIT_ATTR_SOURCE = ...', { base })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'a.txt', kind = 'modified' } })

  eq({
    failure = seen.failure,
    hunk = after_the_header(seen.result),
  }, { hunk = { '@@ -1,3 +1,3 @@', ' 1', '-2', '+two', ' 3', '' } })
end

T['a file’s diff']['keeps the carriage returns of lines that now end in them'] = function()
  local top, base = git_repo.create('diffs-crlf', { ['a.txt'] = { 'one', 'two' } })
  git_repo.write(top, 'a.txt', { 'one\r', 'two\r' })

  local seen = child.lua(FILE_DIFF, { top, base, { path = 'a.txt', kind = 'modified' } })

  eq(
    seen.result,
    table.concat({
      'diff --git a/a.txt b/a.txt',
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':a.txt' }),
        blob_on_disk(top, 'a.txt')
      ),
      '--- a/a.txt',
      '+++ b/a.txt',
      '@@ -1,2 +1,2 @@',
      '-one',
      '-two',
      '+one\r',
      '+two\r',
      '',
    }, '\n')
  )
end

T['a file’s diff']['shows a committed file wholly added when there is no base'] = function()
  local top = git_repo.create_unborn('diffs-no-base')
  git_repo.write(top, 'first.txt', { 'first' })
  git_repo.commit_all(top, 'First')

  local seen = child.lua(FILE_DIFF, { top, vim.NIL, { path = 'first.txt', kind = 'added' } })

  eq(
    seen.result,
    table.concat({
      'diff --git a/first.txt b/first.txt',
      'new file mode 100644',
      ('index %s..%s'):format(('0'):rep(40), blob_on_disk(top, 'first.txt')),
      '--- /dev/null',
      '+++ b/first.txt',
      '@@ -0,0 +1 @@',
      '+first',
      '',
    }, '\n')
  )
end

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the diff there of the commit that follows it,
--- and returns what `_G.await` saw of the second.
local COMMIT_DIFF = [[
  local directory, commit = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.commit_diff(found.result, commit, done)
  end)
]]

T['a commit’s diff'] = MiniTest.new_set()

T['a commit’s diff']['comes with its header, as git show gives it'] = function()
  local top, base = git_repo.create('diffs-commit', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, changed' })
  git_repo.git(top, { 'add', 'a.txt' })
  git_repo.git(top, {
    'commit',
    '--quiet',
    '--date=2026-09-27T12:00:00+02:00',
    '--message=Change a',
    '--message=Because it had to.',
  })
  local commit = git_repo.git(top, { 'rev-parse', 'HEAD' })

  local seen = child.lua(COMMIT_DIFF, { top, commit })

  eq(
    seen.result,
    table.concat({
      'commit ' .. commit,
      'Author: aineo tests <tests@aineo.invalid>',
      'Date:   Sun Sep 27 12:00:00 2026 +0200',
      '',
      '    Change a',
      '    ',
      '    Because it had to.',
      '',
      'diff --git a/a.txt b/a.txt',
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':a.txt' }),
        blob_on_disk(top, 'a.txt')
      ),
      '--- a/a.txt',
      '+++ b/a.txt',
      '@@ -1 +1 @@',
      '-a',
      '+a, changed',
      '',
    }, '\n')
  )
end

T['a commit’s diff']['of a commit named like an option is refused, and writes nothing'] = function()
  local top = git_repo.create('diffs-commit-option', { ['a.txt'] = { 'a' } })
  local written = vim.fs.joinpath(vim.fs.dirname(top), 'written')

  local seen = child.lua(COMMIT_DIFF, { top, '--output=' .. written })

  eq({
    reason = vim.tbl_get(seen, 'failure', 'reason'),
    beside = vim.fn.readdir(vim.fs.dirname(top)),
  }, { reason = 'failed', beside = { 'repo' } })
end

T['a file’s diff']['from a base named like an option is refused, and writes nothing'] = function()
  local top = git_repo.create('diffs-file-option', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, changed' })
  local written = vim.fs.joinpath(vim.fs.dirname(top), 'written')

  local seen =
    child.lua(FILE_DIFF, { top, '--output=' .. written, { path = 'a.txt', kind = 'modified' } })

  eq({
    reason = vim.tbl_get(seen, 'failure', 'reason'),
    beside = vim.fn.readdir(vim.fs.dirname(top)),
  }, { reason = 'failed', beside = { 'repo' } })
end

return T
