local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

--- The four classes of commands as the plan names them, the tracker's
--- `commands` option.
local COMMANDS = {
  tests = {
    'make test',
    'make test_file',
    'npm test',
    'pytest',
    'go test',
    'cargo test',
    'busted',
    'mix test',
    'rspec',
  },
  committing = { 'git commit', 'git push', 'gh pr create' },
  searching = { 'rg', 'grep', 'git grep', 'find', 'fd', 'ag', 'ack' },
  reading = { 'cat', 'head', 'tail', 'less', 'bat', 'sed -n' },
}

--- The state of the main agent while it runs the command `command` with the
--- tool `tool`, in an office told of `commands`.
---
---@param command string|nil
---@param commands? table
---@param tool? string
---@return string|nil state
local function state_while_running(command, commands, tool)
  local story = office_signals.tell({ commands = commands })
  story.started('a', tool or 'Bash', { command = command })
  return story.state()
end

T['a command'] = MiniTest.new_set()

T['a command']['is a command run when it is of no class'] = function()
  eq(state_while_running('ls -la', COMMANDS), 'running_a_command')
end

T['a command']['is a command run when the office is told of no class'] = function()
  eq(state_while_running('make test', nil), 'running_a_command')
end

T['a command']['is a command run when the call has no command'] = function()
  eq(state_while_running(nil, COMMANDS), 'running_a_command')
end

--- The commands of a class, as {command, state}.
local CLASSED_COMMANDS = {
  { 'make test', 'running_tests' },
  { 'make test_file FILE=tests/x.lua', 'running_tests' },
  { 'npm test -- --watch', 'running_tests' },
  { 'pytest -x tests/', 'running_tests' },
  { 'go test ./...', 'running_tests' },
  { 'cargo test --release', 'running_tests' },
  { 'busted spec', 'running_tests' },
  { 'mix test', 'running_tests' },
  { 'rspec spec/models', 'running_tests' },
  { 'git commit -m message', 'committing' },
  { 'git push origin branch', 'committing' },
  { 'gh pr create --base dev', 'committing' },
  { 'rg pattern', 'searching' },
  { 'grep -rn TODO .', 'searching' },
  { 'git grep pattern', 'searching' },
  { 'find . -name x', 'searching' },
  { 'fd pattern', 'searching' },
  { 'ag pattern', 'searching' },
  { 'ack pattern', 'searching' },
  { 'cat README.md', 'reading' },
  { 'head -n 5 README.md', 'reading' },
  { 'tail -f log', 'reading' },
  { 'less README.md', 'reading' },
  { 'bat README.md', 'reading' },
  { 'sed -n 1,5p README.md', 'reading' },
}

T['a command']['is classed by the words of its class'] = MiniTest.new_set({
  parametrize = CLASSED_COMMANDS,
})

T['a command']['is classed by the words of its class'][''] = function(command, state)
  eq(state_while_running(command, COMMANDS), state)
end

T['a command']['is classed the same by the PowerShell tool'] = function()
  eq(state_while_running('make test', COMMANDS, 'PowerShell'), 'running_tests')
end

T['a command']["is not classed by a word that only contains the class's"] = function()
  eq(state_while_running('make testing', COMMANDS), 'running_a_command')
  eq(state_while_running('ripgrep pattern', COMMANDS), 'running_a_command')
  eq(state_while_running('git grepx pattern', COMMANDS), 'running_a_command')
end

T['a command']["is not classed by a word that joins the class's with an underscore"] = function()
  eq(state_while_running('make test_all', COMMANDS), 'running_a_command')
end

T['a command']["is classed when the class's words are in the middle of it"] = function()
  eq(state_while_running('sudo make test now', COMMANDS), 'running_tests')
end

T['a command']['is classed when the words of the class are spaced wider'] = function()
  eq(state_while_running('make    test', COMMANDS), 'running_tests')
end

T['a command']['is classed past a cd'] = function()
  eq(state_while_running('cd tests && make test', COMMANDS), 'running_tests')
end

T['a command']['is classed past leading assignments'] = function()
  eq(state_while_running('AINEO_JOBS=2 DEBUG=1 make test', COMMANDS), 'running_tests')
end

T['a command']['is not classed by the directory a cd names'] = function()
  local commands = { reading = { 'cat' } }

  eq(state_while_running('cd cat && ls', commands), 'running_a_command')
  eq(state_while_running('cd cat', commands), 'running_a_command')
end

T['a command']['is not classed by the value of an assignment it starts with'] = function()
  local commands = { reading = { 'cat' } }

  eq(state_while_running('KIND=cat ls', commands), 'running_a_command')
end

T['a command']['starts, for a match that must start it, after the assignments'] = function()
  local commands = { tests = { { lua_pattern = '^make%s+test' } } }

  eq(state_while_running('CI=1 DEBUG=1 make test', commands), 'running_tests')
end

T['a command']['is split at each separator, so a match that must start a part sees each part'] = function()
  local commands = { tests = { { lua_pattern = '^make test' } } }

  eq(state_while_running('echo a && make test', commands), 'running_tests')
  eq(state_while_running('echo a || make test', commands), 'running_tests')
  eq(state_while_running('echo a; make test', commands), 'running_tests')
  eq(state_while_running('echo a | make test', commands), 'running_tests')
  eq(state_while_running('echo a\nmake test', commands), 'running_tests')
end

T['a command']['is not classed by the body of a heredoc, whatever words it holds'] = function()
  local commit = 'git commit -m "$(cat <<\'EOF\'\nThe whole suite ran green (make test).\nEOF\n)"'
  local pull_request =
    'gh pr create --title t --body "$(cat <<\'EOF\'\nRan pytest -k follower.\nEOF\n)"'

  eq(state_while_running(commit, COMMANDS), 'committing')
  eq(state_while_running(pull_request, COMMANDS), 'committing')
end

T['a command']['is classed by what follows the end of a heredoc'] = function()
  local command = 'cat <<EOF > notes\nmake test\nEOF\ngit push'

  eq(state_while_running(command, COMMANDS), 'committing')
end

T['a command']['is classed by the command a heredoc is fed to, not its body'] = function()
  eq(state_while_running('cat <<EOF > notes\nmake test\nEOF', COMMANDS), 'reading')
end

T['a command']['ends a heredoc at its word, quoted or not, tabs stripped by <<-'] =
  MiniTest.new_set({
    parametrize = {
      { "cat <<'EOF'\nmake test\nEOF\ngit push" },
      { 'cat <<"EOF"\nmake test\nEOF\ngit push' },
      { 'cat <<-EOF\n\tmake test\n\tEOF\ngit push' },
      { 'cat << EOF\nmake test\nEOF\ngit push' },
      { 'cat <<END_OF_TEXT\nmake test\nEND_OF_TEXT\ngit push' },
    },
  })

T['a command']['ends a heredoc at its word, quoted or not, tabs stripped by <<-'][''] = function(
  command
)
  eq(state_while_running(command, COMMANDS), 'committing')
end

T['a command']['is not classed by what follows a heredoc that never ends'] = function()
  eq(state_while_running('cat <<EOF\nmake test\n', COMMANDS), 'reading')
end

T['a command']['takes the here-string <<< and a shift as no heredoc'] = function()
  eq(state_while_running('cat <<< x\nmake test', COMMANDS), 'running_tests')
  eq(state_while_running('echo $((1<<3))\nmake test', COMMANDS), 'running_tests')
end

T['a command']['is classed by quoted text, as bash -c runs it'] = function()
  eq(state_while_running('bash -c "make test"', COMMANDS), 'running_tests')
end

T['a command']['is classed by a segment that is not its first'] = function()
  eq(state_while_running('echo starting && make test', COMMANDS), 'running_tests')
end

T['a command']['is classed by a segment after each of the separators'] = function()
  eq(state_while_running('echo a || make test', COMMANDS), 'running_tests')
  eq(state_while_running('echo a; make test', COMMANDS), 'running_tests')
  eq(state_while_running('echo a | make test', COMMANDS), 'running_tests')
  eq(state_while_running('echo a\nmake test', COMMANDS), 'running_tests')
end

T['a command']['is a command run when only cd segments are in it'] = function()
  eq(state_while_running('cd tests && cd ..', COMMANDS), 'running_a_command')
end

T['a command']['takes the first class in order, tests before committing before searching before reading'] = function()
  eq(state_while_running('cat file | git commit -m x', COMMANDS), 'committing')
  eq(state_while_running('cat file | grep x', COMMANDS), 'searching')
  eq(state_while_running('git commit -m x && make test', COMMANDS), 'running_tests')
  eq(state_while_running('grep x && git push', COMMANDS), 'committing')
end

T['a command']['is a background job when the call runs in the background, whatever its class'] = function()
  local story = office_signals.tell({ commands = COMMANDS })

  story.started('a', 'Bash', { command = 'make test', run_in_background = true })

  eq(story.state(), 'background_job')
end

T['a command']['is classed when the call does not run in the background'] = function()
  local story = office_signals.tell({ commands = COMMANDS })

  story.started('a', 'Bash', { command = 'make test', run_in_background = false })

  eq(story.state(), 'running_tests')
end

T['a command']["is classed by the commands the office is told of, not the plan's"] = function()
  local commands = { tests = { 'just check' } }

  eq(state_while_running('just check', commands), 'running_tests')
  eq(state_while_running('make test', commands), 'running_a_command')
end

T['a match'] = MiniTest.new_set()

T['a match']['with a * is a glob over the whole segment'] = function()
  local commands = { reading = { 'cat *.md' } }

  eq(state_while_running('cat README.md', commands), 'reading')
  eq(state_while_running('cat docs/guide.md', commands), 'reading')
  eq(state_while_running('cat README.md extra', commands), 'running_a_command')
  eq(state_while_running('cat notes.txt', commands), 'running_a_command')
end

T['a match']['with a ? is a glob that takes any one character'] = function()
  local commands = { tests = { 'make t?st' } }

  eq(state_while_running('make test', commands), 'running_tests')
  eq(state_while_running('make toast', commands), 'running_a_command')
end

T['a match']['with a glob reads every other character as itself'] = function()
  local commands = { reading = { 'cat a.b*' } }

  eq(state_while_running('cat a.bc', commands), 'reading')
  eq(state_while_running('cat axbc', commands), 'running_a_command')
end

T['a match']['with a lua_pattern is a Lua pattern found in the segment'] = function()
  local commands = { tests = { { lua_pattern = '^make%s+test' } } }

  eq(state_while_running('make   test now', commands), 'running_tests')
  eq(state_while_running('sudo make test', commands), 'running_a_command')
end

T['a match']['with a lua_pattern Lua cannot read matches nothing'] = function()
  local commands = { tests = { { lua_pattern = '[' } } }

  eq(state_while_running('make test', commands), 'running_a_command')
end

T['a match']['with a lua_pattern that is no string matches nothing'] = function()
  local commands = { tests = { { lua_pattern = 5 } } }

  eq(state_while_running('make test', commands), 'running_a_command')
end

T['a match']['reads a command up to its 4096th byte and no further'] = function()
  local up_to_the_limit = string.rep('x', 4096 - #' && make test') .. ' && make test'
  local one_byte_further = 'x' .. up_to_the_limit

  eq(#up_to_the_limit, 4096)
  eq(state_while_running(up_to_the_limit, COMMANDS), 'running_tests')
  eq(state_while_running(one_byte_further, COMMANDS), 'running_a_command')
end

T['a match']['with a Lua pattern reads a command up to its 1024th byte and no further'] = function()
  local commands = { tests = { { lua_pattern = 'make test' } } }
  local up_to_the_limit = string.rep('x', 1024 - #'make test') .. 'make test'
  local one_byte_further = 'x' .. up_to_the_limit

  eq(#up_to_the_limit, 1024)
  eq(state_while_running(up_to_the_limit, commands), 'running_tests')
  eq(state_while_running(one_byte_further, commands), 'running_a_command')
end

T['a match']['with a Lua pattern that repeats twice matches nothing'] = function()
  local commands = { tests = { { lua_pattern = 'make.*test.*now' } } }

  eq(state_while_running('make a test right now', commands), 'running_a_command')
end

T['a match']['with a Lua pattern that repeats once matches'] = function()
  local commands = { tests = { { lua_pattern = 'make.*test' } } }

  eq(state_while_running('make a test right now', commands), 'running_tests')
end

T['a match']['with a Lua pattern Lua reads as a plain text of its own is no problem'] = function()
  local commands = { tests = { { lua_pattern = '[%w_-]+ test' } } }

  eq(state_while_running('make test', commands), 'running_tests')
end

T['a match']['with a glob takes ? for one character, not one byte'] = function()
  local commands = { reading = { 'cat caf?.md' } }

  eq(state_while_running('cat café.md', commands), 'reading')
  eq(state_while_running('cat cafe.md', commands), 'reading')
  eq(state_while_running('cat cafee.md', commands), 'running_a_command')
end

T['a match']['with a glob takes * for any run of characters, none included'] = function()
  local commands = { reading = { 'cat *.md', 'cat a*b*c' } }

  eq(state_while_running('cat .md', commands), 'reading')
  eq(state_while_running('cat aXbYc', commands), 'reading')
  eq(state_while_running('cat abc', commands), 'reading')
  eq(state_while_running('cat aXbY', commands), 'running_a_command')
  eq(state_while_running('cat a**b', commands), 'running_a_command')
end

T['a match']['with a glob keeps the characters of a Lua pattern as themselves'] = function()
  local commands = { reading = { 'cat [x]*', 'cat %d*', 'cat (a)*' } }

  eq(state_while_running('cat [x]1', commands), 'reading')
  eq(state_while_running('cat %d1', commands), 'reading')
  eq(state_while_running('cat (a)1', commands), 'reading')
  eq(state_while_running('cat x', commands), 'running_a_command')
  eq(state_while_running('cat 5', commands), 'running_a_command')
end

--- How long, in milliseconds, the office takes to hear a call of `command`
--- when it is told of `commands`.
---
---@param command string
---@param commands table
---@return number milliseconds
local function milliseconds_to_hear(command, commands)
  local story = office_signals.tell({ commands = commands })
  local start = vim.uv.hrtime()
  story.started('a', 'Bash', { command = command })
  return (vim.uv.hrtime() - start) / 1e6
end

--- The slowest time, in milliseconds, a command of 4096 bytes may take to be
--- heard.
local MOST_MILLISECONDS = 50

T['a match']['with a glob of many stars on a command of 4096 bytes is heard within 50 ms'] = function()
  local commands = { reading = { '*a*a*a*a*b', '* * * *x' } }

  eq(milliseconds_to_hear(string.rep('a', 4096), commands) < MOST_MILLISECONDS, true)
  eq(milliseconds_to_hear(string.rep('w ', 2048), commands) < MOST_MILLISECONDS, true)
end

T['a match']['with a Lua pattern that repeats once on a command of 4096 bytes is heard within 50 ms'] = function()
  local commands = {
    reading = {
      { lua_pattern = '[%w_]-x' },
      { lua_pattern = '.*x' },
      { lua_pattern = '%a*x' },
      { lua_pattern = 'a+x' },
    },
  }

  eq(milliseconds_to_hear(string.rep('a', 4096), commands) < MOST_MILLISECONDS, true)
end

T['a match']['with a Lua pattern that repeats twice on a command of 4096 bytes is heard within 50 ms'] = function()
  local commands = { reading = { { lua_pattern = '.-.-x' }, { lua_pattern = '.*a.*a.*b' } } }

  eq(milliseconds_to_hear(string.rep('a', 4096), commands) < MOST_MILLISECONDS, true)
end

return T
