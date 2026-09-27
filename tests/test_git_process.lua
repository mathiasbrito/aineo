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

T['a git that cannot run'] = MiniTest.new_set()

T['a git that cannot run']['is reported, in the words it could not start with'] = function()
  local directory = git_repo.directory('process-missing')
  local missing = vim.fs.joinpath(directory, 'no-such-git')

  local seen = child.lua(FIND_REPOSITORY, { directory, { executable = missing } })

  eq({ failure = seen.failure, result = seen.result, raised = seen.raised }, {
    failure = {
      reason = 'no_git',
      message = ("ENOENT: no such file or directory (cmd): '%s'"):format(missing),
    },
  })
end

T['an operation'] = MiniTest.new_set({
  parametrize = { { {} }, { { executable = '/nonexistent/aineo-no-such-git' } } },
})

T['an operation']['returns at once, and calls back once, on the main loop'] = function(options)
  local directory = git_repo.create('process-once', { ['a.txt'] = { 'a' } })

  local seen = child.lua(FIND_REPOSITORY, { directory, options })

  eq(
    { calls = seen.calls, fast = seen.fast, after_return = seen.after_return },
    { calls = 1, fast = false, after_return = true }
  )
end

T['a git that fails'] = MiniTest.new_set()

T['a git that fails']['is reported with its exit code, in its own words'] = function()
  local directory = git_repo.directory('process-fails')
  local failing =
    git_repo.script('process-fails', 'git', { "echo 'cannot read the index' >&2", 'exit 3' })

  local seen = child.lua(FIND_REPOSITORY, { directory, { executable = failing } })

  eq(
    { failure = seen.failure, result = seen.result },
    { failure = { reason = 'failed', message = 'cannot read the index', code = 3 } }
  )
end

T['a git that runs too long'] = MiniTest.new_set()

T['a git that runs too long']['is stopped at the limit it is given, and reported'] = function()
  local directory = git_repo.directory('process-slow')
  local pid_file = vim.fs.joinpath(directory, 'pid')
  local slow =
    git_repo.script('process-slow', 'git', { ('echo $$ > %s'):format(pid_file), 'exec sleep 30' })

  local seen = child.lua(FIND_REPOSITORY, { directory, { executable = slow, limit_ms = 1000 } })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'timed_out',
      message = ('git ran past its limit of 1000 ms: %s'):format(slow),
    },
  })
  eq(vim.uv.kill(tonumber(vim.fn.readfile(pid_file)[1]), 0), nil)
end

T['a git that runs too long']['is stopped at the home’s own limit when it is given none'] = function()
  local directory = git_repo.directory('process-default-limit')
  local slow = git_repo.script('process-default-limit', 'git', { 'exec sleep 60' })

  local seen = child.lua(FIND_REPOSITORY, { directory, { executable = slow } })

  eq(vim.tbl_get(seen, 'failure', 'reason'), 'timed_out')
end

--- The Lua that returns what the child holds that an operation could leave
--- behind: how many of its event loop's handles of each type are open, and
--- the files in its temporary directory.
local LEFT_OPEN = [[
  local handles = {}
  vim.uv.walk(function(handle)
    local type = handle:get_type()
    handles[type] = (handles[type] or 0) + (handle:is_closing() and 0 or 1)
  end)
  return { handles = handles, temporary = vim.fn.readdir(vim.fn.fnamemodify(vim.fn.tempname(), ':h')) }
]]

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the files changed there since the base that
--- follows it, with the options after that, and returns what `_G.await` saw
--- of the second.
local CHANGED_FILES = [[
  local directory, base, options = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.changed_files(found.result, base, done, options)
  end)
]]

T['an operation that ended'] = MiniTest.new_set()

T['an operation that ended']['leaves no process, handle, timer or file behind'] = function()
  local top, base = git_repo.create('process-left', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, changed' })
  local before = child.lua(LEFT_OPEN)

  child.lua(CHANGED_FILES, { top, base })

  eq(child.lua(LEFT_OPEN), before)
end

T['an operation that ended']['by running past its limit leaves no process, handle, timer or file behind'] = function()
  local top, base = git_repo.create('process-left-slow', { ['a.txt'] = { 'a' } })
  local slow = git_repo.script('process-left-slow', 'git', { 'exec sleep 30' })
  local found = child.lua(FIND_REPOSITORY, { top })
  local before = child.lua(LEFT_OPEN)

  child.lua(
    [[
    local found, base, options = ...
    return _G.await(function(done)
      require('aineo.git').file_diff(found, base, { path = 'a.txt', kind = 'modified' }, done, options)
    end)
  ]],
    { found.result, base, { executable = slow, limit_ms = 500 } }
  )

  eq(child.lua(LEFT_OPEN), before)
end

return T
