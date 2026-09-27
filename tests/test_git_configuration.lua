local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then calls its operation named next with that
--- repository and the arguments after the name, and returns what `_G.await`
--- saw of the second.
local ASK = [[
  local directory, operation, arguments = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    local call = { found.result }
    vim.list_extend(call, arguments)
    table.insert(call, done)
    git[operation](unpack(call))
  end)
]]

--- Sets, in the configuration of the repository at `top`, every setting of
--- a user's that changes what git prints for a diff, a list of changes or a
--- log unless the command says otherwise: colours, prefixes, an external
--- diff program and a text conversion that print their own words, no rename
--- detection, relative paths, no context, short ids, other formats, dates
--- and encodings, signatures shown, every file taken as binary, empty
--- context lines without their space, hunks joined across ten lines, files
--- in an order of the user's, and no diff for a first commit.
---
---@param name string the fixture the repository is in
---@param top string
local function make_hostile(name, top)
  local external = git_repo.script(name, 'external-diff', { 'echo EXTERNAL DIFF' })
  local textconv = git_repo.script(name, 'textconv', { 'echo CONVERTED' })
  local attributes = vim.fs.joinpath(vim.fs.dirname(top), 'attributes')
  assert(vim.fn.writefile({ '* diff=converted' }, attributes) == 0, 'cannot write ' .. attributes)
  local order = vim.fs.joinpath(vim.fs.dirname(top), 'order')
  assert(
    vim.fn.writefile({ 'sub/moved-here.txt', 'sub/b.txt' }, order) == 0,
    'cannot write ' .. order
  )
  local settings = {
    { 'color.ui', 'always' },
    { 'diff.noprefix', 'true' },
    { 'diff.mnemonicPrefix', 'true' },
    { 'diff.external', external },
    { 'core.attributesFile', attributes },
    { 'diff.converted.textconv', textconv },
    { 'diff.renames', 'false' },
    { 'diff.relative', 'true' },
    { 'diff.context', '0' },
    { 'core.abbrev', '5' },
    { 'format.pretty', 'oneline' },
    { 'log.abbrevCommit', 'true' },
    { 'log.decorate', 'full' },
    { 'log.date', 'relative' },
    { 'log.showSignature', 'true' },
    { 'i18n.logOutputEncoding', 'ISO-8859-1' },
    { 'core.bigFileThreshold', '1' },
    { 'diff.suppressBlankEmpty', 'true' },
    { 'diff.interHunkContext', '10' },
    { 'diff.orderFile', order },
    { 'log.showRoot', 'false' },
  }
  for _, setting in ipairs(settings) do
    git_repo.git(top, { 'config', setting[1], setting[2] })
  end
end

--- Commits what is staged in the repository at `top`, signed with an SSH key
--- made for the case in the fixture `name`, with `message`, at a fixed date;
--- returns the commit's full id.
---
---@param name string
---@param top string
---@param message string
---@return string commit
local function commit_signed(name, top, message)
  local key = vim.fs.joinpath(git_repo.directory(name .. '-key'), 'key')
  local made = vim.system({ 'ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', key }):wait()
  assert(made.code == 0, made.stderr)
  git_repo.git(top, {
    '-c',
    'gpg.format=ssh',
    '-c',
    'user.signingkey=' .. key,
    'commit',
    '--quiet',
    '--gpg-sign',
    '--date=2026-09-27T12:00:00+02:00',
    '--message=' .. message,
  })
  return git_repo.git(top, { 'rev-parse', 'HEAD' })
end

--- The id git gives the content of the file `path` under `top` as it is on
--- disk now.
---
---@param top string
---@param path string
---@return string
local function blob_on_disk(top, path)
  return git_repo.git(top, { 'hash-object', '--no-filters', '--', path })
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['a user’s git configuration'] = MiniTest.new_set()

T['a user’s git configuration']['does not change the files changed since a base'] = function()
  local top, base = git_repo.create('configuration-changes', {
    ['sub/moved.txt'] = { 'moved' },
    ['sub/changed.txt'] = { 'changed' },
  })
  git_repo.git(top, { 'mv', 'sub/moved.txt', 'sub/moved-here.txt' })
  git_repo.write(top, 'sub/changed.txt', { 'changed, again' })
  make_hostile('configuration-changes', top)

  local seen = child.lua(ASK, { top .. '/sub', 'changed_files', { base } })

  eq(seen.result, {
    { path = 'sub/changed.txt', kind = 'modified' },
    { path = 'sub/moved-here.txt', kind = 'renamed', old_path = 'sub/moved.txt' },
  })
end

T['a user’s git configuration']['that asks for copies does not change the files changed since a base'] = function()
  local top, base =
    git_repo.create('configuration-copies', { ['a.txt'] = { 'one', 'two', 'three' } })
  git_repo.write(top, 'a.txt', { 'one', 'two', 'three', 'four' })
  git_repo.write(top, 'copy.txt', { 'one', 'two', 'three' })
  git_repo.git(top, { 'add', 'a.txt', 'copy.txt' })
  git_repo.git(top, { 'config', 'diff.renames', 'copies' })

  local seen = child.lua(ASK, { top, 'changed_files', { base } })

  eq(seen.result, {
    { path = 'a.txt', kind = 'modified' },
    { path = 'copy.txt', kind = 'added' },
  })
end

T['a user’s git configuration']['does not change a file’s diff'] = function()
  local lines = { '1', '', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15' }
  local top, base = git_repo.create('configuration-file', { ['sub/a.txt'] = lines })
  lines[3], lines[13] = 'three', 'thirteen'
  git_repo.write(top, 'sub/a.txt', lines)
  make_hostile('configuration-file', top)

  local seen = child.lua(
    ASK,
    { top .. '/sub', 'file_diff', { base, { path = 'sub/a.txt', kind = 'modified' } } }
  )

  eq(
    seen.result,
    table.concat({
      'diff --git a/sub/a.txt b/sub/a.txt',
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':sub/a.txt' }),
        blob_on_disk(top, 'sub/a.txt')
      ),
      '--- a/sub/a.txt',
      '+++ b/sub/a.txt',
      '@@ -1,6 +1,6 @@',
      ' 1',
      ' ',
      '-3',
      '+three',
      ' 4',
      ' 5',
      ' 6',
      '@@ -10,6 +10,6 @@',
      ' 10',
      ' 11',
      ' 12',
      '-13',
      '+thirteen',
      ' 14',
      ' 15',
      '',
    }, '\n')
  )
end

T['a user’s git configuration']['does not change a renamed file’s diff'] = function()
  local top, base = git_repo.create('configuration-renamed', { ['old.txt'] = { 'kept' } })
  git_repo.git(top, { 'mv', 'old.txt', 'new.txt' })
  make_hostile('configuration-renamed', top)

  local seen = child.lua(ASK, {
    top,
    'file_diff',
    { base, { path = 'new.txt', kind = 'renamed', old_path = 'old.txt' } },
  })

  eq(
    seen.result,
    table.concat({
      'diff --git a/old.txt b/new.txt',
      'similarity index 100%',
      'rename from old.txt',
      'rename to new.txt',
      '',
    }, '\n')
  )
end

T['a user’s git configuration']['does not change an untracked file’s diff'] = function()
  local top, base = git_repo.create('configuration-untracked', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'sub/new.txt', { 'new' })
  make_hostile('configuration-untracked', top)

  local seen = child.lua(
    ASK,
    { top .. '/sub', 'file_diff', { base, { path = 'sub/new.txt', kind = 'untracked' } } }
  )

  eq(
    seen.result,
    table.concat({
      'diff --git a/sub/new.txt b/sub/new.txt',
      'new file mode 100644',
      ('index %s..%s'):format(('0'):rep(40), blob_on_disk(top, 'sub/new.txt')),
      '--- /dev/null',
      '+++ b/sub/new.txt',
      '@@ -0,0 +1 @@',
      '+new',
      '',
    }, '\n')
  )
end

T['a user’s git configuration']['does not change the commits since a base'] = function()
  local top, base = git_repo.create('configuration-commits', { ['a.txt'] = { 'a' } })
  make_hostile('configuration-commits', top)
  git_repo.write(top, 'a.txt', { 'a, changed' })
  git_repo.git(top, { 'add', 'a.txt' })
  local signed = commit_signed('configuration-commits', top, 'Café, signed')

  local seen = child.lua(ASK, { top, 'commits_since', { base } })

  eq(seen.result, {
    commits = { { id = signed, subject = 'Café, signed' } },
    base_is_ancestor = true,
  })
end

T['a user’s git configuration']['does not change a commit’s diff'] = function()
  local top, base = git_repo.create(
    'configuration-commit',
    { ['sub/a.txt'] = { '1', '2', '3', '4', '5' }, ['sub/b.txt'] = { 'b' } }
  )
  make_hostile('configuration-commit', top)
  git_repo.write(top, 'sub/a.txt', { '1', '2', 'three', '4', '5' })
  git_repo.write(top, 'sub/b.txt', { 'b, changed' })
  git_repo.git(top, { 'add', 'sub/a.txt', 'sub/b.txt' })
  local signed = commit_signed('configuration-commit', top, 'Café, signed')
  git_repo.git(top, { 'notes', 'add', '--message=A note of the user’s', signed })

  local seen = child.lua(ASK, { top .. '/sub', 'commit_diff', { signed } })

  eq(
    seen.result,
    table.concat({
      'commit ' .. signed,
      'Author: aineo tests <tests@aineo.invalid>',
      'Date:   Sun Sep 27 12:00:00 2026 +0200',
      '',
      '    Café, signed',
      '',
      'diff --git a/sub/a.txt b/sub/a.txt',
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':sub/a.txt' }),
        blob_on_disk(top, 'sub/a.txt')
      ),
      '--- a/sub/a.txt',
      '+++ b/sub/a.txt',
      '@@ -1,5 +1,5 @@',
      ' 1',
      ' 2',
      '-3',
      '+three',
      ' 4',
      ' 5',
      'diff --git a/sub/b.txt b/sub/b.txt',
      ('index %s..%s 100644'):format(
        git_repo.git(top, { 'rev-parse', base .. ':sub/b.txt' }),
        blob_on_disk(top, 'sub/b.txt')
      ),
      '--- a/sub/b.txt',
      '+++ b/sub/b.txt',
      '@@ -1 +1 @@',
      '-b',
      '+b, changed',
      '',
    }, '\n')
  )
end

T['a user’s git configuration']['does not change the diff of a repository’s first commit'] = function()
  local top, base = git_repo.create('configuration-root', { ['a.txt'] = { 'a' } })
  make_hostile('configuration-root', top)

  local seen = child.lua(ASK, { top, 'commit_diff', { base } })

  eq(vim.list_slice(vim.split(seen.result, '\n'), 7), {
    'diff --git a/a.txt b/a.txt',
    'new file mode 100644',
    ('index %s..%s'):format(('0'):rep(40), blob_on_disk(top, 'a.txt')),
    '--- /dev/null',
    '+++ b/a.txt',
    '@@ -0,0 +1 @@',
    '+a',
    '',
  })
end

T['a user’s git configuration']['that asks for a file system monitor starts no daemon'] = function()
  local top, base = git_repo.create('configuration-fsmonitor', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, changed' })
  git_repo.git(top, { 'config', 'core.fsmonitor', 'true' })
  MiniTest.finally(function()
    git_repo.run(top, { 'fsmonitor--daemon', 'stop' })
  end)

  child.lua(ASK, { top, 'changed_files', { base } })

  eq(
    git_repo.run(top, { 'fsmonitor--daemon', 'status' }).stdout,
    "fsmonitor-daemon is not watching '" .. top .. "'\n"
  )
end

return T
