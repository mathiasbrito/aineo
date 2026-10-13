local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, with the options that follow it, and returns what
--- `_G.await` saw.
local FIND_REPOSITORY = [[
  local directory, options = ...
  return _G.await(function(done)
    require('aineo.git').find_repository(directory, done, options)
  end)
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['a repository'] = MiniTest.new_set()

T['a repository']['gives its top level, its git directories, its head commit and its branch'] = function()
  local top, base = git_repo.create('repository-main', { ['a.txt'] = { 'a' } })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq(seen.result, {
    top = top,
    git_directory = top .. '/.git',
    common_directory = top .. '/.git',
    head = base,
    branch = 'main',
  })
end

T['a repository']['before its first commit has no head commit, and is on its branch'] = function()
  local top = git_repo.create_unborn('repository-unborn')

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq({
    failure = seen.failure,
    head = vim.tbl_get(seen, 'result', 'head'),
    branch = vim.tbl_get(seen, 'result', 'branch'),
  }, { branch = 'main' })
end

T['a repository']['with a detached head is on no branch'] = function()
  local top, base = git_repo.create('repository-detached', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '--detach' })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq({
    failure = seen.failure,
    head = vim.tbl_get(seen, 'result', 'head'),
    branch = vim.tbl_get(seen, 'result', 'branch'),
  }, { head = base })
end

T['a repository']['is found from a directory below its top level'] = function()
  local top = git_repo.create('repository-below', { ['deep/er/a.txt'] = { 'a' } })

  local seen = child.lua(FIND_REPOSITORY, { top .. '/deep/er' })

  eq(vim.tbl_get(seen, 'result', 'top'), top)
end

T['a repository']['in a linked worktree has its own git directory and its main one in common'] = function()
  local top = git_repo.create('repository-linked', { ['a.txt'] = { 'a' } })
  local linked = vim.fs.joinpath(vim.fs.dirname(top), 'linked')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'side', linked })

  local seen = child.lua(FIND_REPOSITORY, { linked })

  eq(seen.result, {
    top = linked,
    git_directory = top .. '/.git/worktrees/linked',
    common_directory = top .. '/.git',
    head = git_repo.git(top, { 'rev-parse', 'HEAD' }),
    branch = 'side',
  })
end

T['an editor whose environment names another repository'] = MiniTest.new_set({
  parametrize = {
    { 'GIT_DIR', '/.git' },
    { 'GIT_WORK_TREE', '' },
  },
})

T['an editor whose environment names another repository']['still finds the repository of the directory it gives'] = function(
  variable,
  within_other
)
  local top, base = git_repo.create('repository-environment', { ['a.txt'] = { 'a' } })
  local other = git_repo.create('repository-environment-other', { ['other.txt'] = { 'other' } })
  child.lua('local name, value = ... vim.env[name] = value', { variable, other .. within_other })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq(seen.result, {
    top = top,
    git_directory = top .. '/.git',
    common_directory = top .. '/.git',
    head = base,
    branch = 'main',
  })
end

T['a repository whose path holds a newline'] = MiniTest.new_set()

T['a repository whose path holds a newline']['is reported, never taken for another'] = function()
  local directory = git_repo.directory('repository-newline')
  local enclosing = vim.fs.joinpath(directory, 'proj')
  local top = enclosing .. '\nsub'
  vim.fn.mkdir(enclosing, 'p')
  vim.fn.mkdir(top, 'p')
  git_repo.git(enclosing, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.git(top, { 'init', '--quiet', '--initial-branch=main' })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'failed',
      message = 'git gave 6 lines for the 3 paths of the repository: a path holds a newline',
    },
  })
end

T['a directory'] = MiniTest.new_set()

T['a directory']['outside every repository is told apart, in git’s words'] = function()
  local directory = git_repo.directory('repository-none')

  local seen = child.lua(FIND_REPOSITORY, { directory })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'not_a_repository',
      message = 'fatal: not a git repository (or any of the parent directories): .git',
    },
  })
end

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then calls its operation named next with that repository
--- and the arguments after the name, and returns what `_G.await` saw of the
--- second.
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

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then, from a timer's callback — a fast event — for the
--- read `operation` names, one of those that name a commit or two, with
--- `commit` as the commit; returns what `_G.await` saw of the second, whether
--- `done` ran before the call returned, and what the call raised, if it did.
local READ_FROM_A_FAST_EVENT = [[
  local directory, operation, commit = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end).result
  local change = { path = 'a.txt', kind = 'added' }
  local reads = {
    resolve_commit = function(done)
      git.resolve_commit(found, 'main', done)
    end,
    remote_default_branch = function(done)
      git.remote_default_branch(found, done)
    end,
    file_at_commit = function(done)
      git.file_at_commit(found, commit, 'a.txt', done)
    end,
    commits_between = function(done)
      git.commits_between(found, nil, commit, done)
    end,
    files_between = function(done)
      git.files_between(found, nil, commit, done)
    end,
    diff_between = function(done)
      git.diff_between(found, nil, commit, done)
    end,
    file_diff_between = function(done)
      git.file_diff_between(found, nil, commit, change, done)
    end,
    file_diff_straight = function(done)
      git.file_diff_straight(found, nil, commit, change, done)
    end,
  }
  local raised, answered_early
  local seen = _G.await(function(done)
    local timer = assert(vim.uv.new_timer())
    timer:start(0, 0, function()
      timer:close()
      local returned = false
      local called, error_message = pcall(reads[operation], function(...)
        answered_early = not returned
        done(...)
      end)
      returned = true
      raised = not called and tostring(error_message) or nil
    end)
  end)
  return {
    calls = seen.calls,
    in_fast_event = seen.fast,
    answered_early = answered_early,
    failure = seen.failure,
    raised = raised,
  }
]]

T['a read of commits'] = MiniTest.new_set({
  parametrize = {
    { 'resolve_commit' },
    { 'remote_default_branch' },
    { 'file_at_commit' },
    { 'commits_between' },
    { 'files_between' },
    { 'diff_between' },
    { 'file_diff_between' },
    { 'file_diff_straight' },
  },
})

T['a read of commits']['asked from a fast event answers once, later, on the main loop, and raises nothing'] = function(
  operation
)
  local top, base = git_repo.create('reads-fast-event', { ['a.txt'] = { 'a' } })

  local seen = child.lua(READ_FROM_A_FAST_EVENT, { top, operation, base })

  eq(seen, { calls = 1, in_fast_event = false, answered_early = false })
end

T['a commit named'] = MiniTest.new_set()

T['a commit named by a name git reads'] = MiniTest.new_set({
  parametrize = { { 'main' }, { 'refs/heads/main' }, { 'HEAD' } },
})

T['a commit named by a name git reads']['is the commit the name gives, by its full id'] = function(
  name
)
  local top, base = git_repo.create('resolve-name', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'resolve_commit', { name } })

  eq({ failure = seen.failure, result = seen.result }, { result = base })
end

T['a commit named']['by an annotated tag is the commit it tags, not the tag'] = function()
  local top, base = git_repo.create('resolve-tag', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'tag', '--annotate', '--message=Tagged', 'release' })

  local seen = child.lua(ASK, { top, 'resolve_commit', { 'release' } })

  eq({ failure = seen.failure, result = seen.result }, { result = base })
end

T['a commit named']['by a name that names none is no commit, not a failure'] = function()
  local top = git_repo.create('resolve-none', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'resolve_commit', { 'origin/nosuch' } })

  eq({ failure = seen.failure, result = seen.result, calls = seen.calls }, { calls = 1 })
end

T['a commit named']['like an option is a name, never an option that makes git fail'] = function()
  local top = git_repo.create('resolve-option', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'resolve_commit', { '--path-format=x' } })

  eq({ failure = seen.failure, result = seen.result, calls = seen.calls }, { calls = 1 })
end

T['a commit named by something that is not one commit'] = MiniTest.new_set({
  parametrize = { { '^main' }, { 'old..main' }, { 'main..old' }, { 'old...main' } },
})

T['a commit named by something that is not one commit']['is no commit'] = function(name)
  local top = git_repo.create('resolve-range', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'old' })
  git_repo.write(top, 'a.txt', { 'a, again' })
  git_repo.commit_all(top, 'Main moves on')

  local seen = child.lua(ASK, { top, 'resolve_commit', { name } })

  eq({ failure = seen.failure, result = seen.result, calls = seen.calls }, { calls = 1 })
end

T['a commit named by a remote-tracking branch or a full id'] = MiniTest.new_set({
  parametrize = { { 'origin/main' }, { 'refs/remotes/origin/main' } },
})

T['a commit named by a remote-tracking branch or a full id']['is the commit it names'] = function(
  name
)
  local source, base = git_repo.create('resolve-remote', { ['a.txt'] = { 'a' } })
  local clone = vim.fs.joinpath(vim.fs.dirname(source), 'clone')
  git_repo.git(source, { 'clone', '--quiet', source, clone })

  local seen = child.lua(ASK, { clone, 'resolve_commit', { name } })

  eq({ failure = seen.failure, result = seen.result }, { result = base })
end

T['a commit named by a full id'] = MiniTest.new_set()

T['a commit named by a full id']['is the commit it names'] = function()
  local top, base = git_repo.create('resolve-full-id', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'resolve_commit', { base } })

  eq({ failure = seen.failure, result = seen.result }, { result = base })
end

T['a file at a commit'] = MiniTest.new_set()

T['a file at a commit']['is the text the commit has, not the working tree’s'] = function()
  local top, base = git_repo.create('content-commit', { ['a.txt'] = { 'as committed' } })
  git_repo.write(top, 'a.txt', { 'changed since' })

  local seen = child.lua(ASK, { top, 'file_at_commit', { base, 'a.txt' } })

  eq({ failure = seen.failure, result = seen.result }, { result = 'as committed\n' })
end

T['a file at a commit']['gives the file’s size in bytes beside its text'] = function()
  local top, base = git_repo.create('content-size', { ['a.txt'] = { 'as committed' } })

  local seen = child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'a.txt' })

  eq({ failure = seen.failure, text = seen.result, size = seen.size }, {
    text = 'as committed\n',
    size = 13,
  })
end

--- The lines `line 00001 xxxx…` to `line <count>`, each 50 bytes with its
--- line break, and the text they make.
---
---@param count integer
---@return string[] lines
---@return string text
local function numbered_lines(count)
  local lines = {}
  for number = 1, count do
    lines[number] = ('line %05d %s'):format(number, ('x'):rep(38))
  end
  return lines, table.concat(lines, '\n') .. '\n'
end

T['a file at a commit']['larger than the bytes asked for gives exactly its first bytes and its whole size'] = function()
  local lines, whole = numbered_lines(6000)
  local top, base = git_repo.create('content-first-bytes', { ['big.txt'] = lines })

  local seen = child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'big.txt', {}, 100000 })

  eq({ failure = seen.failure, text = seen.result, size = seen.size }, {
    text = whole:sub(1, 100000),
    size = 300000,
  })
end

T['a file at a commit']['asked for no bytes gives a large file whole, with its size'] = function()
  local lines, whole = numbered_lines(6000)
  local top, base = git_repo.create('content-no-bound', { ['big.txt'] = lines })

  local seen = child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'big.txt' })

  eq({ failure = seen.failure, text = seen.result, size = seen.size }, {
    text = whole,
    size = 300000,
  })
end

T['a file at a commit']['no larger than the bytes asked for gives its whole text'] =
  MiniTest.new_set({
    parametrize = { { 13 }, { 14 }, { 1000000 } },
  })

T['a file at a commit']['no larger than the bytes asked for gives its whole text']['and its size'] = function(
  first_bytes
)
  local top, base = git_repo.create('content-no-larger', { ['a.txt'] = { 'as committed' } })

  local seen = child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'a.txt', {}, first_bytes })

  eq({ failure = seen.failure, text = seen.result, size = seen.size }, {
    text = 'as committed\n',
    size = 13,
  })
end

T['a file at a commit']['is exactly what git printed: carriage returns, a missing last newline, NUL bytes'] = function()
  local top = git_repo.create_unborn('content-bytes')
  local exact = 'one\r\ntwo\0three\r\nlast line without a newline'
  local file = assert(io.open(vim.fs.joinpath(top, 'bytes.bin'), 'wb'))
  file:write(exact)
  file:close()
  local commit = git_repo.commit_all(top, 'Bytes')

  local seen = child.lua(ASK, { top, 'file_at_commit', { commit, 'bytes.bin' } })

  eq({ failure = seen.failure, result = seen.result }, { result = exact })
end

T['a file at a commit']['named like a pattern or an option is that file, not the files a pattern names'] = function()
  local top = git_repo.create_unborn('content-names')
  git_repo.write(top, '-dash [x]*.txt', { 'the one' })
  git_repo.write(top, 'x1.txt', { 'a pattern’s match' })
  local commit = git_repo.commit_all(top, 'Names')

  local seen = child.lua(ASK, { top, 'file_at_commit', { commit, '-dash [x]*.txt' } })

  eq({ failure = seen.failure, result = seen.result }, { result = 'the one\n' })
end

T['a file at a commit']['the commit does not have is told apart from any other failure'] = function()
  local top, base = git_repo.create('content-missing', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'file_at_commit', { base, 'deleted-later.txt' } })

  eq({ reason = vim.tbl_get(seen, 'failure', 'reason'), result = seen.result }, {
    reason = 'path_missing',
  })
end

T['a file at a commit']['that is a directory there is a failure, not a missing file'] = function()
  local top, base = git_repo.create('content-directory', { ['dir/a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'file_at_commit', { base, 'dir' } })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = { reason = 'failed', message = ('dir is a tree in %s, not a file'):format(base) },
  })
end

T['a file at a commit']['gets its own text, and a missing path none, beside a top-level file named --'] = function()
  local top = git_repo.create_unborn('content-dashdash')
  git_repo.write(top, '--', { 'the file named --' })
  git_repo.write(top, 'a.txt', { 'a' })
  git_repo.write(top, 'dir/b.txt', { 'b' })
  local commit = git_repo.commit_all(top, 'A file named --')

  local answers = {}
  for _, path in ipairs({ 'a.txt', 'dir/b.txt', '--', 'gone.txt' }) do
    local seen = child.lua(ASK, { top, 'file_at_commit', { commit, path } })
    answers[path] = seen.result or vim.tbl_get(seen, 'failure', 'reason')
  end

  eq(answers, {
    ['a.txt'] = 'a\n',
    ['dir/b.txt'] = 'b\n',
    ['--'] = 'the file named --\n',
    ['gone.txt'] = 'path_missing',
  })
end

T['a file at a commit']['named by a path git would normalise is not that path'] = function()
  local top = git_repo.create_unborn('content-normalised')
  git_repo.write(top, '.gitignore', { 'ignored' })
  git_repo.write(top, 'dir/a.txt', { 'inner a' })
  git_repo.write(top, 'README.md', { 'readme' })
  local commit = git_repo.commit_all(top, 'Files')

  local answers = {}
  for _, path in ipairs({ '.', 'dir/', './README.md', 'dir/../README.md' }) do
    local seen = child.lua(ASK, { top, 'file_at_commit', { commit, path } })
    answers[path] = seen.result or vim.tbl_get(seen, 'failure', 'reason')
  end

  eq(answers, {
    ['.'] = 'path_missing',
    ['dir/'] = 'path_missing',
    ['./README.md'] = 'path_missing',
    ['dir/../README.md'] = 'path_missing',
  })
end

T['a file at a commit']['that is a submodule there is a failure, not a missing file'] = function()
  local library = git_repo.create('content-submodule-library', { ['library.txt'] = { 'library' } })
  local top = git_repo.create('content-submodule', { ['a.txt'] = { 'a' } })
  git_repo.git(
    top,
    { '-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', library, 'library' }
  )
  local commit = git_repo.commit_all(top, 'Add the library')

  local seen = child.lua(ASK, { top, 'file_at_commit', { commit, 'library' } })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'failed',
      message = ('library is a commit in %s, not a file'):format(commit),
    },
  })
end

T['a file at a commit']['that is a link is the link’s target'] = function()
  local top = git_repo.create_unborn('content-link')
  git_repo.write(top, 'target.txt', { 'target' })
  assert(vim.uv.fs_symlink('target.txt', vim.fs.joinpath(top, 'link')))
  local commit = git_repo.commit_all(top, 'A link')

  local seen = child.lua(ASK, { top, 'file_at_commit', { commit, 'link' } })

  eq({ failure = seen.failure, result = seen.result }, { result = 'target.txt' })
end

T['a file at a commit']['of a commit the repository does not have is a failure, not a missing file'] = function()
  local top = git_repo.create('content-no-commit', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'file_at_commit', { string.rep('0', 40), 'a.txt' } })

  eq({ reason = vim.tbl_get(seen, 'failure', 'reason'), result = seen.result }, {
    reason = 'failed',
  })
end

T['the remote’s default branch'] = MiniTest.new_set()

T['the remote’s default branch']['is the short name of the branch origin/HEAD points at, not the one checked out'] = function()
  local source = git_repo.create('default-branch-source', { ['a.txt'] = { 'a' } })
  local clone = vim.fs.joinpath(vim.fs.dirname(source), 'clone')
  git_repo.git(source, { 'clone', '--quiet', source, clone })
  git_repo.git(clone, { 'checkout', '--quiet', '-b', 'feature' })

  local seen = child.lua(ASK, { clone, 'remote_default_branch', {} })

  eq({ failure = seen.failure, result = seen.result }, { result = 'origin/main' })
end

T['the remote’s default branch']['is none for a repository without origin/HEAD, whatever branch is checked out'] = function()
  local top = git_repo.create('default-branch-none', { ['a.txt'] = { 'a' } })

  local seen = child.lua(ASK, { top, 'remote_default_branch', {} })

  eq({ failure = seen.failure, result = seen.result, calls = seen.calls }, { calls = 1 })
end

return T
