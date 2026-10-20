--- Builds the git repositories the git home's suites read, each in a fixture
--- directory of its own named `git-<name>`, and runs the home in a child
--- Neovim whose git calls are as isolated as the suites' own: neither the
--- developer's global or system git configuration, nor the checkout's own
--- repository, is ever seen.

local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git = dofile('tests/helpers/git.lua')

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')

--- How long a case waits for the home to answer, or for a watch to call
--- back: far longer than any git call a case makes takes.
M.PATIENCE_MS = 20000

--- The environment every git a case starts runs with, the home's own in the
--- child included: the suites' hermetic git (`tests/helpers/git.lua`), and a
--- ceiling at the fixtures' directory, so git run in a fixture that is not a
--- repository never finds the checkout's own.
M.ENVIRONMENT = vim.tbl_extend('force', git.HERMETIC_ENVIRONMENT, {
  GIT_CEILING_DIRECTORIES = vim.fs.joinpath(CHECKOUT, '.tests', 'fixtures'),
})

--- Runs `git <args…>` in `directory` under `ENVIRONMENT` and returns how it
--- ended.
---
---@param directory string
---@param args string[]
---@return vim.SystemCompleted
function M.run(directory, args)
  return vim
    .system(vim.list_extend({ 'git' }, args), { cwd = directory, env = M.ENVIRONMENT, text = true })
    :wait()
end

--- Runs `git <args…>` in `directory` under `ENVIRONMENT` and returns its
--- output, less its last newline. Raises an error carrying git's message when
--- git fails.
---
---@param directory string
---@param args string[]
---@return string
function M.git(directory, args)
  local result = M.run(directory, args)
  assert(result.code == 0, ('git %s: %s'):format(table.concat(args, ' '), result.stderr))
  return (result.stdout:gsub('\n$', ''))
end

--- The empty directory `.tests/fixtures/git-<name>`, emptied of whatever an
--- earlier run left there.
---
---@param name string
---@return string path
function M.directory(name)
  return fixture.directory('git-' .. name)
end

--- Makes `.tests/fixtures/git-<name>/<repository>` a new repository whose
--- branch is `main`, with no commit yet.
---
---@param name string
---@param repository? string the repository's directory under the fixture, `repo` when not given
---@return string top the repository's top level
function M.create_unborn(name, repository)
  local top = vim.fs.joinpath(M.directory(name), repository or 'repo')
  vim.fn.mkdir(top, 'p')
  M.git(top, { 'init', '--quiet', '--initial-branch=main' })
  return top
end

--- Writes `lines` to the file `path` under `top`, making the directories it
--- leads through.
---
---@param top string
---@param path string
---@param lines string[]
function M.write(top, path, lines)
  local file = vim.fs.joinpath(top, path)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  assert(vim.fn.writefile(lines, file) == 0, 'cannot write ' .. file)
end

--- Stages every file under `top` and commits them with `message`; returns
--- the new commit's full id.
---
---@param top string
---@param message string
---@return string commit
function M.commit_all(top, message)
  M.git(top, { 'add', '--all' })
  M.git(top, { 'commit', '--quiet', '--allow-empty', '--message', message })
  return M.git(top, { 'rev-parse', 'HEAD' })
end

--- The author and age column (`aineo.changes.author_column`) of a commit
--- the suites' git has just made: the suites' author, `now`, and the spaces
--- that fill the column to 20 cells.
M.JUST_MADE_COLUMN = 'aineo tests now     '

--- The commits window's line for `commit`, a full id, with `column`, the
--- 20 cells of its author and age, and `subject`.
---
---@param commit string
---@param column string
---@param subject string
---@return string
function M.commit_line_of(commit, column, subject)
  return ('%s %s %s'):format(commit:sub(1, 7), column, subject)
end

--- The commits window's line for `commit`, a full id, that the suites' git
--- has just made, with `subject`.
---
---@param commit string
---@param subject string
---@return string
function M.commit_line(commit, subject)
  return M.commit_line_of(commit, M.JUST_MADE_COLUMN, subject)
end

--- Stages every file under `top` and commits them with `message`, written
--- by the author `name` at `authored_at`, seconds since the epoch; returns
--- the new commit's full id.
---
---@param top string
---@param message string
---@param name string
---@param authored_at integer
---@return string commit
function M.commit_all_authored(top, message, name, authored_at)
  M.git(top, { 'add', '--all' })
  M.git(top, {
    'commit',
    '--quiet',
    '--allow-empty',
    '--message',
    message,
    '--author',
    name .. ' <author@aineo.invalid>',
    '--date',
    authored_at .. ' +0000',
  })
  return M.git(top, { 'rev-parse', 'HEAD' })
end

--- Stages every file under `top` and commits them with `message`, written
--- and committed by the author `name` at `at`, seconds since the epoch, so
--- that git orders the commit by that time; returns the new commit's full
--- id.
---
---@param top string
---@param message string
---@param name string
---@param at integer
---@return string commit
function M.commit_all_dated(top, message, name, at)
  local environment = vim.tbl_extend('force', M.ENVIRONMENT, {
    GIT_COMMITTER_DATE = at .. ' +0000',
  })
  local function run(args)
    local result = vim
      .system(vim.list_extend({ 'git' }, args), { cwd = top, env = environment, text = true })
      :wait()
    assert(result.code == 0, ('git %s: %s'):format(table.concat(args, ' '), result.stderr))
    return (result.stdout:gsub('\n$', ''))
  end
  run({ 'add', '--all' })
  run({
    'commit',
    '--quiet',
    '--allow-empty',
    '--message',
    message,
    '--author',
    name .. ' <author@aineo.invalid>',
    '--date',
    at .. ' +0000',
  })
  return run({ 'rev-parse', 'HEAD' })
end

--- The commits of a repository `M.create_graph()` made, by their subjects'
--- first word, each a full id.
---@class aineo.tests.GraphCommits
---@field begin string `Begin`, on `main`, the first commit
---@field side string `Side work`, on the branch `side`, from `Begin`
---@field main string `Main work`, on `main`, after `Begin`
---@field merge string `Merge side`, `main`'s head, merging `side`
---@field other string `Other work`, on the branch `other` and tagged `v1`, after `Main work`

--- The time the first commit of `M.create_graph()` is written at; each
--- later one is a minute after the one before.
M.GRAPH_STARTS_AT = 1500000000

--- Makes `.tests/fixtures/git-<name>/repo` a repository with two branches
--- beside `main` and a merge: `Begin` by Ada; `Side work` by Bartholomew on
--- `side`, holding `side.txt`; `Main work` by Ada on `main`, holding
--- `main.txt`; `Merge side`, `side` merged into `main` by Ada; and
--- `Other work` by Carol on `other`, from `Main work`, tagged `v1`, holding
--- `other.txt` and `more.txt`. `main` is checked out, at `Merge side`.
---
---@param name string
---@return string top the repository's top level
---@return aineo.tests.GraphCommits commits
function M.create_graph(name)
  local top = M.create_unborn(name)
  local at = M.GRAPH_STARTS_AT
  local commits = {}
  M.write(top, 'a.txt', { 'one' })
  commits.begin = M.commit_all_dated(top, 'Begin', 'Ada', at)
  M.git(top, { 'checkout', '--quiet', '-b', 'side' })
  M.write(top, 'side.txt', { 'side' })
  commits.side = M.commit_all_dated(top, 'Side work', 'Bartholomew', at + 60)
  M.git(top, { 'checkout', '--quiet', 'main' })
  M.write(top, 'main.txt', { 'main' })
  commits.main = M.commit_all_dated(top, 'Main work', 'Ada', at + 120)
  M.git(top, { 'merge', '--quiet', '--no-ff', '--no-commit', 'side' })
  commits.merge = M.commit_all_dated(top, 'Merge side', 'Ada', at + 180)
  M.git(top, { 'checkout', '--quiet', '-b', 'other', commits.main })
  M.write(top, 'other.txt', { 'other' })
  M.write(top, 'more.txt', { 'more' })
  commits.other = M.commit_all_dated(top, 'Other work', 'Carol', at + 240)
  M.git(top, { 'tag', 'v1' })
  M.git(top, { 'checkout', '--quiet', 'main' })
  return top, commits
end

--- How git tells the age of `commit`, a full id of the repository `top`,
--- now: `%ar`, as `git log --date=relative` writes it.
---
---@param top string
---@param commit string
---@return string
function M.relative_age(top, commit)
  return M.git(top, { 'log', '-1', '--format=%ar', commit })
end

--- Makes `.tests/fixtures/git-<name>/repo` a repository whose one commit,
--- `base`, holds `files` (path to lines).
---
---@param name string
---@param files table<string, string[]>
---@return string top the repository's top level
---@return string base the commit's full id
function M.create(name, files)
  local top = M.create_unborn(name)
  for path, lines in pairs(files) do
    M.write(top, path, lines)
  end
  return top, M.commit_all(top, 'base')
end

--- Makes `.tests/fixtures/git-<name>/repo` hold one commit, `base`, on
--- `main`, with a remote `origin` whose branch `dev` is `base` too, and
--- `.tests/fixtures/git-<name>/landing`, a clone of that remote on `dev`,
--- where the work that lands in the remote is made (`M.land_in_remote()`).
--- The base holds `files` (path to lines), `a.txt` with one line when not
--- given.
---
---@param name string
---@param files? table<string, string[]>
---@return string top the repository's top level
---@return string base the commit's full id
---@return string clone the clone's top level
function M.create_with_remote(name, files)
  local top, base = M.create(name, files or { ['a.txt'] = { 'one' } })
  local directory = vim.fs.dirname(top)
  local remote = vim.fs.joinpath(directory, 'remote.git')
  M.git(directory, { 'init', '--quiet', '--bare', '--initial-branch=main', remote })
  M.git(top, { 'remote', 'add', 'origin', remote })
  M.git(top, { 'push', '--quiet', 'origin', 'main:dev' })
  local clone = vim.fs.joinpath(directory, 'landing')
  M.git(directory, { 'clone', '--quiet', '--branch', 'dev', remote, clone })
  return top, base, clone
end

--- Lands a commit in the remote's `dev`: `clone`, as `M.create_with_remote()`
--- made it, commits `files` (path to lines) with `message` and pushes it.
--- The repository `top` has not fetched it yet (`M.fetch_remote()`).
---
---@param clone string
---@param files table<string, string[]>
---@param message string
---@return string commit the commit's full id
function M.land_in_remote(clone, files, message)
  for path, lines in pairs(files) do
    M.write(clone, path, lines)
  end
  local commit = M.commit_all(clone, message)
  M.git(clone, { 'push', '--quiet', 'origin', 'dev' })
  return commit
end

--- Fetches the remote `origin` into the repository `top`, as any program of
--- the user's does.
---
---@param top string
function M.fetch_remote(top)
  M.git(top, { 'fetch', '--quiet', 'origin' })
end

--- Writes the executable shell script `.tests/fixtures/git-<name>/<file>`
--- with `lines` after its `#!/bin/sh` line: a stand-in for git, or a program
--- a git setting names.
---
---@param name string
---@param file string
---@param lines string[]
---@return string path
function M.script(name, file, lines)
  local path =
    fixture.write(('git-%s/%s'):format(name, file), vim.list_extend({ '#!/bin/sh' }, lines))
  assert(vim.uv.fs_chmod(path, tonumber('755', 8)))
  return path
end

--- The Lua that waits, in the child, for one git home operation: `_G.await(start)`
--- calls `start(done)` and waits for `done`, then for one more turn of the
--- main loop, and returns what it saw — how many times `done` ran, with what,
--- whether in a fast event, whether `start` had returned first, and what
--- `start` raised, if it did.
local AWAIT = [[
  local patience = ...
  _G.await = function(start)
    local seen = { calls = 0 }
    local returned = false
    local started, raised = pcall(start, function(failure, result)
      seen.calls = seen.calls + 1
      seen.failure = failure
      seen.result = result
      seen.fast = vim.in_fast_event()
      seen.after_return = returned
    end)
    returned = true
    seen.raised = not started and tostring(raised) or nil
    vim.wait(patience, function() return seen.calls > 0 or seen.raised ~= nil end, 5)
    local turned = false
    vim.schedule(function() turned = true end)
    vim.wait(patience, function() return turned end, 5)
    return seen
  end
]]

--- The Lua that reads, in the child, a file at a commit: `...` is the
--- repository's directory, the commit, the path, the git options and the
--- number of bytes asked for, the last two optional. It returns what
--- `_G.await` saw, with the third value `done` was given as `size`, and as
--- `elapsed_ms` how long the child waited for the answer.
M.FILE_AT_COMMIT = [[
  local directory, commit, path, options, first_bytes = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  local size = nil
  local started = vim.uv.hrtime()
  local seen = _G.await(function(done)
    git.file_at_commit(found.result, commit, path, function(failure, text, whole_size)
      size = whole_size
      done(failure, text)
    end, options, first_bytes)
  end)
  seen.size = size
  seen.elapsed_ms = (vim.uv.hrtime() - started) / 1e6
  return seen
]]

--- Starts `child` afresh with the suites' minimal init, gives its
--- environment `ENVIRONMENT`, so the git calls the home makes there are
--- isolated too, and defines `_G.await` there (`AWAIT`).
---
---@param child table a child from `MiniTest.new_child_neovim()`
function M.start_editor(child)
  children.restart(child)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { M.ENVIRONMENT })
  child.lua(AWAIT, { M.PATIENCE_MS })
end

--- Waits, at most `PATIENCE_MS`, until `condition()` holds, and fails the
--- case with `description` when it never does.
---
---@param description string
---@param condition fun(): boolean
function M.wait_until(description, condition)
  if not vim.wait(M.PATIENCE_MS, condition, 10) then
    MiniTest.expect.equality(description, 'what happened in time')
  end
end

return M
