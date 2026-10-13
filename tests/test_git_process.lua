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

--- The Lua that does what `FIND_REPOSITORY` does, and also returns, as
--- `elapsed_ms`, how long the child waited for the answer.
local TIMED_FIND_REPOSITORY = [[
  local directory, options = ...
  local started = vim.uv.hrtime()
  local seen = _G.await(function(done)
    require('aineo.git').find_repository(directory, done, options)
  end)
  seen.elapsed_ms = (vim.uv.hrtime() - started) / 1e6
  return seen
]]

--- The pid a stand-in git wrote to the file `pid_file`, or nil when it
--- wrote none, as when it was stopped before it could.
---
---@param pid_file string
---@return integer|nil
local function recorded_pid(pid_file)
  local lines = vim.fn.filereadable(pid_file) == 1 and vim.fn.readfile(pid_file) or {}
  return tonumber(lines[1])
end

--- What became of the process whose pid a stand-in git wrote to the file
--- `pid_file`: `'unrecorded'` when it wrote none, else `'running'` or
--- `'gone'`.
---
---@param pid_file string
---@return 'unrecorded'|'running'|'gone'
local function recorded_process(pid_file)
  local pid = recorded_pid(pid_file)
  if not pid then
    return 'unrecorded'
  end
  return vim.uv.kill(pid, 0) == 0 and 'running' or 'gone'
end

--- Kills the process whose pid a stand-in git wrote to the file `pid_file`,
--- when it wrote one.
---
---@param pid_file string
local function kill_recorded(pid_file)
  local pid = recorded_pid(pid_file)
  if pid then
    vim.uv.kill(pid, 'sigkill')
  end
end

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

T['a git that fails']['by a signal is reported as a failure, never as an answer'] = function()
  local directory = git_repo.directory('process-signal')
  local crashing = git_repo.script('process-signal', 'git', { 'kill -SEGV $$' })

  local seen = child.lua(FIND_REPOSITORY, { directory, { executable = crashing } })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'failed',
      message = ('git was ended by signal 11: %s'):format(crashing),
    },
  })
end

T['a git that runs too long'] = MiniTest.new_set()

T['a git that runs too long']['is stopped at the limit it is given, and reported'] = function()
  local directory = git_repo.directory('process-slow')
  local pid_file = vim.fs.joinpath(directory, 'pid')
  local slow = git_repo.script(
    'process-slow',
    'git',
    { "trap '' TERM", ('echo $$ > %s'):format(pid_file), 'exec sleep 30' }
  )
  MiniTest.finally(function()
    kill_recorded(pid_file)
  end)

  local seen =
    child.lua(TIMED_FIND_REPOSITORY, { directory, { executable = slow, limit_ms = 1000 } })

  eq({
    failure = seen.failure,
    result = seen.result,
    in_time = seen.elapsed_ms < 5000,
    git = recorded_process(pid_file),
  }, {
    failure = {
      reason = 'timed_out',
      message = ('git ran past its limit of 1000 ms: %s'):format(slow),
    },
    in_time = true,
    git = 'gone',
  })
end

T['a git that runs too long']['is stopped at its limit with every process it started'] = function()
  local directory = git_repo.directory('process-descendant')
  local descendant_file = vim.fs.joinpath(directory, 'descendant')
  local starting = git_repo.script(
    'process-descendant',
    'git',
    { 'sleep 30 &', ('echo $! > %s'):format(descendant_file), 'exec sleep 30' }
  )
  MiniTest.finally(function()
    kill_recorded(descendant_file)
  end)

  local seen =
    child.lua(TIMED_FIND_REPOSITORY, { directory, { executable = starting, limit_ms = 1000 } })

  eq(
    { reason = vim.tbl_get(seen, 'failure', 'reason'), in_time = seen.elapsed_ms < 5000 },
    { reason = 'timed_out', in_time = true }
  )
  git_repo.wait_until('the process git started gone', function()
    return recorded_process(descendant_file) ~= 'running'
  end)
  eq(recorded_process(descendant_file), 'gone')
end

T['a git that runs too long']['is stopped at its limit when git ended before a process it started'] = function()
  local directory = git_repo.directory('process-stray')
  local stray_file = vim.fs.joinpath(directory, 'stray')
  local leaving = git_repo.script(
    'process-stray',
    'git',
    { 'sleep 12 >&2 &', ('echo $! > %s'):format(stray_file), 'exit 3' }
  )
  MiniTest.finally(function()
    kill_recorded(stray_file)
  end)

  local seen =
    child.lua(TIMED_FIND_REPOSITORY, { directory, { executable = leaving, limit_ms = 1000 } })

  eq({ calls = seen.calls, in_time = seen.elapsed_ms < 5000 }, { calls = 1, in_time = true })
  git_repo.wait_until('the process git started gone', function()
    return recorded_process(stray_file) ~= 'running'
  end)
  eq(recorded_process(stray_file), 'gone')
end

T['a git that runs too long']['is stopped at the home’s own limit when it is given none'] = function()
  local directory = git_repo.directory('process-default-limit')
  local slow = git_repo.script('process-default-limit', 'git', { 'exec sleep 60' })

  local seen = child.lua(FIND_REPOSITORY, { directory, { executable = slow } })

  eq(seen.failure, {
    reason = 'timed_out',
    message = ('git ran past its limit of 10000 ms: %s'):format(slow),
  })
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
  local writing =
    git_repo.script('process-left-slow', 'git', { ': > "$GIT_INDEX_FILE.lock"', 'exec sleep 30' })
  local found = child.lua(FIND_REPOSITORY, { top })
  local before = child.lua(LEFT_OPEN)

  local seen = child.lua(
    [[
    local found, base, options = ...
    return _G.await(function(done)
      require('aineo.git').file_diff(found, base, { path = 'a.txt', kind = 'modified' }, done, options)
    end)
  ]],
    { found.result, base, { executable = writing, limit_ms = 500 } }
  )

  eq(
    { reason = vim.tbl_get(seen, 'failure', 'reason'), left = child.lua(LEFT_OPEN) },
    { reason = 'timed_out', left = before }
  )
end

T['a git that prints more than is asked for'] = MiniTest.new_set()

--- The size the stand-in git's listing gives its one file, far above the
--- bytes the cases ask for.
local LISTED_SIZE = 1000000

--- Writes a stand-in for git that lists one file, `big.txt`, of
--- `LISTED_SIZE` bytes for `ls-tree`, and runs `lines` for anything else
--- (`cat-file`).
---
---@param name string
---@param lines string[]
---@return string path
local function stand_in_listing_a_big_file(name, lines)
  local listing = ("printf '100644 blob 0123456789abcdef0123456789abcdef01234567 %%7d\\t%%s\\0' %d big.txt"):format(
    LISTED_SIZE
  )
  return git_repo.script(
    name,
    'git',
    vim.list_extend({
      'for argument in "$@"; do',
      '  if [ "$argument" = ls-tree ]; then',
      '    ' .. listing,
      '    exit 0',
      '  fi',
      'done',
    }, lines)
  )
end

--- Reads `big.txt` through `stand_in` asking for `first_bytes` bytes of it,
--- in a repository the child can find, under `limit_ms` if given.
---
---@param name string
---@param stand_in string
---@param first_bytes integer
---@param limit_ms integer|nil
local function read_big_file(name, stand_in, first_bytes, limit_ms)
  local top, base = git_repo.create(name .. '-repository', { ['a.txt'] = { 'a' } })
  local options = { executable = stand_in, limit_ms = limit_ms }
  return child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'big.txt', options, first_bytes })
end

T['a git that prints more than is asked for']['is stopped once the bytes asked for have come, with every process it started'] = function()
  local directory = git_repo.directory('process-bound')
  local pid_file = vim.fs.joinpath(directory, 'pid')
  local printing = stand_in_listing_a_big_file('process-bound', {
    ('echo $$ > %s'):format(pid_file),
    "head -c 200000 /dev/zero | tr '\\0' x",
    'exec sleep 30',
  })
  MiniTest.finally(function()
    kill_recorded(pid_file)
  end)

  local seen = read_big_file('process-bound', printing, 50000)

  eq({
    failure = seen.failure,
    text = seen.result,
    size = seen.size,
    in_time = seen.elapsed_ms < 5000,
    git = recorded_process(pid_file),
  }, {
    text = ('x'):rep(50000),
    size = LISTED_SIZE,
    in_time = true,
    git = 'gone',
  })
end

T['a git that prints more than is asked for']['is stopped with a process it started that holds its output'] = function()
  local directory = git_repo.directory('process-bound-group')
  local descendant_file = vim.fs.joinpath(directory, 'descendant')
  local printing = stand_in_listing_a_big_file('process-bound-group', {
    'sleep 30 &',
    ('echo $! > %s'):format(descendant_file),
    "head -c 200000 /dev/zero | tr '\\0' x",
    'exec sleep 30',
  })
  MiniTest.finally(function()
    kill_recorded(descendant_file)
  end)

  local seen = read_big_file('process-bound-group', printing, 50000)

  eq({ failure = seen.failure, text = seen.result, in_time = seen.elapsed_ms < 5000 }, {
    text = ('x'):rep(50000),
    in_time = true,
  })
  git_repo.wait_until('the process git started gone', function()
    return recorded_process(descendant_file) ~= 'running'
  end)
  eq(recorded_process(descendant_file), 'gone')
end

--- The Lua that reads `big.txt` through the stand-in git in `...` (the
--- repository's directory, its commit, the stand-in, the bytes asked for and
--- the limit), in a child whose main loop is held for 1.5 s once the read of
--- the file has started, so that its limit has run out, and the bytes asked
--- for have come, before either is seen.
local READ_WHILE_THE_EDITOR_IS_BUSY = [[
  local directory, commit, stand_in, first_bytes, limit_ms = ...
  local system = vim.system
  vim.system = function(command, ...)
    local process = system(command, ...)
    if vim.list_contains(command, 'cat-file') then
      vim.schedule(function()
        vim.uv.sleep(1500)
      end)
    end
    return process
  end
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.file_at_commit(found.result, commit, 'big.txt', done, { executable = stand_in, limit_ms = limit_ms }, first_bytes)
  end)
]]

T['a git that prints more than is asked for']['is answered, not timed out, when its limit runs out as the bytes asked for come'] = function()
  local printing = stand_in_listing_a_big_file('process-bound-and-limit', {
    "head -c 200000 /dev/zero | tr '\\0' x",
    'exec sleep 30',
  })
  local top, base = git_repo.create('process-bound-and-limit-repository', { ['a.txt'] = { 'a' } })

  local seen = child.lua(READ_WHILE_THE_EDITOR_IS_BUSY, { top, base, printing, 50000, 500 })

  eq({ failure = seen.failure, text = seen.result }, { text = ('x'):rep(50000) })
end

T['a git that prints more than is asked for']['gives exactly the bytes asked for when they come in pieces'] = function()
  local printing = stand_in_listing_a_big_file('process-bound-pieces', {
    'for piece in 1 2 3 4 5; do',
    "  head -c 4000 /dev/zero | tr '\\0' x",
    '  sleep 0.1',
    'done',
    'exec sleep 30',
  })

  local seen = read_big_file('process-bound-pieces', printing, 10000)

  eq({ failure = seen.failure, text = seen.result }, { text = ('x'):rep(10000) })
end

T['a git that prints more than is asked for']['is answered as it is without a bound when it ends before reaching it'] = function()
  local short = stand_in_listing_a_big_file('process-bound-short', { "printf 'short'" })

  local seen = read_big_file('process-bound-short', short, 50000)

  eq({ failure = seen.failure, text = seen.result }, { text = 'short' })
end

T['a git that prints more than is asked for']['ended by a signal before reaching the bound is a failure, never an answer'] = function()
  local crashing = stand_in_listing_a_big_file('process-bound-signal', {
    "printf 'some'",
    'kill -KILL $$',
  })

  local seen = read_big_file('process-bound-signal', crashing, 50000)

  eq({ failure = seen.failure, text = seen.result }, {
    failure = {
      reason = 'failed',
      message = ('git was ended by signal 9: %s'):format(crashing),
    },
  })
end

T['a git that prints more than is asked for']['running past its limit before reaching the bound is timed out, never an answer'] = function()
  local stalled = stand_in_listing_a_big_file('process-bound-slow', {
    "printf 'some'",
    'exec sleep 30',
  })

  local seen = read_big_file('process-bound-slow', stalled, 50000, 1000)

  eq({ failure = seen.failure, text = seen.result }, {
    failure = {
      reason = 'timed_out',
      message = ('git ran past its limit of 1000 ms: %s'):format(stalled),
    },
  })
end

T['a git that prints more than is asked for']['leaves no process, handle, timer or file behind'] = function()
  local printing = stand_in_listing_a_big_file('process-bound-left', {
    "head -c 200000 /dev/zero | tr '\\0' x",
    'exec sleep 30',
  })
  local top, base = git_repo.create('process-bound-left-repository', { ['a.txt'] = { 'a' } })
  local options = { executable = printing }
  child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'big.txt', options, 1000 })
  local before = child.lua(LEFT_OPEN)

  local seen = child.lua(git_repo.FILE_AT_COMMIT, { top, base, 'big.txt', options, 1000 })

  eq({ text = seen.result, left = child.lua(LEFT_OPEN) }, { text = ('x'):rep(1000), left = before })
end

return T
