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
--- whether in a fast event, and whether `start` had returned first.
local AWAIT = [[
  local patience = ...
  _G.await = function(start)
    local seen = { calls = 0 }
    local returned = false
    start(function(failure, result)
      seen.calls = seen.calls + 1
      seen.failure = failure
      seen.result = result
      seen.fast = vim.in_fast_event()
      seen.after_return = returned
    end)
    returned = true
    vim.wait(patience, function() return seen.calls > 0 end, 5)
    local turned = false
    vim.schedule(function() turned = true end)
    vim.wait(patience, function() return turned end, 5)
    return seen
  end
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
