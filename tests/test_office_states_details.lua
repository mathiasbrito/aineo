local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

T['the tasks'] = MiniTest.new_set()

T['the tasks']['a TodoWrite lists its todos, the completed ones done'] = function()
  local story = office_signals.tell()

  story.started('c1', 'TodoWrite', {
    todos = {
      { content = 'Write the test', status = 'completed', activeForm = 'Writing the test' },
      { content = 'Make it pass', status = 'in_progress', activeForm = 'Making it pass' },
      { content = 'Refactor', status = 'pending', activeForm = 'Refactoring' },
    },
  })

  eq(story.details().tasks, {
    { subject = 'Write the test', done = true },
    { subject = 'Make it pass', done = false },
    { subject = 'Refactor', done = false },
  })
end

T['the tasks']['a TaskCreate adds a task, not done'] = function()
  local story = office_signals.tell()
  story.started('c1', 'TaskCreate', { subject = 'Write the test', description = 'First' })

  story.started('c2', 'TaskCreate', { subject = 'Make it pass', description = 'Then' })

  eq(story.details().tasks, {
    { subject = 'Write the test', done = false },
    { subject = 'Make it pass', done = false },
  })
end

T['the tasks']['a TaskUpdate to completed ticks the task its id names'] = function()
  local story = office_signals.tell()
  story.started('c1', 'TaskCreate', { subject = 'Write the test' })
  story.started('c2', 'TaskCreate', { subject = 'Make it pass' })

  story.started('c3', 'TaskUpdate', { taskId = '2', status = 'completed' })

  eq(story.details().tasks, {
    { subject = 'Write the test', done = false },
    { subject = 'Make it pass', done = true },
  })
end

T['the tasks']['a TaskUpdate to another status leaves the task not done'] = function()
  local story = office_signals.tell()
  story.started('c1', 'TaskCreate', { subject = 'Write the test' })

  story.started('c2', 'TaskUpdate', { taskId = '1', status = 'in_progress' })

  eq(story.details().tasks, { { subject = 'Write the test', done = false } })
end

T['the tasks']['a TaskUpdate of a task nobody made changes nothing'] = function()
  local story = office_signals.tell()
  story.started('c1', 'TaskCreate', { subject = 'Write the test' })

  story.started('c2', 'TaskUpdate', { taskId = '7', status = 'completed' })

  eq(story.details().tasks, { { subject = 'Write the test', done = false } })
end

T['the tasks']['a TaskUpdate that names no task changes nothing'] = function()
  local story = office_signals.tell()
  story.started('c1', 'TaskCreate', { subject = 'Write the test' })

  story.started('c2', 'TaskUpdate', { status = 'completed' })

  eq(story.details().tasks, { { subject = 'Write the test', done = false } })
end

T['the tasks']['are kept by each agent for itself'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })

  story.hear('tool_started', {
    agent = 'a1',
    call = 'c1',
    tool = 'TaskCreate',
    input = { subject = 'Look around' },
  })

  eq(story.details('a1').tasks, { { subject = 'Look around', done = false } })
  eq(story.details().tasks, {})
end

T['the web clue'] = MiniTest.new_set()

T['the web clue']['of a search is its query, while the search runs'] = function()
  local story = office_signals.tell()

  story.started('c1', 'WebSearch', { query = 'neovim extmarks end_row' })

  eq(story.details().web_clue, 'neovim extmarks end_row')
end

T['the web clue']['is gone once the search has its result'] = function()
  local story = office_signals.tell()
  story.started('c1', 'WebSearch', { query = 'neovim extmarks end_row' })

  story.finished('c1')

  eq(story.details().web_clue, nil)
end

T['the web clue']['of a fetch is the host of its address, not the whole of it'] = function()
  local story = office_signals.tell()

  story.started('c1', 'WebFetch', {
    url = 'https://user:secret@docs.example.com:8080/guide/page.html?token=abc#top',
    prompt = 'Summarise',
  })

  eq(story.details().web_clue, 'docs.example.com')
end

T['the web clue']['of a fetch of an address with no scheme is its host'] = function()
  local story = office_signals.tell()

  story.started('c1', 'WebFetch', { url = 'example.org/a/b' })

  eq(story.details().web_clue, 'example.org')
end

T['the web clue']['of a fetch of an address with an IPv6 host is the host in its brackets'] = function()
  local story = office_signals.tell()

  story.started('c1', 'WebFetch', { url = 'http://[::1]:8080/status' })

  eq(story.details().web_clue, '[::1]')
end

--- The addresses that give no clue: a string that is no host once the
--- address is cut where a host ends. `ESC` is a literal escape.
local HOSTILE_ADDRESSES = {
  { 'https://alice:s3cr3t/word@host.example/' },
  { 'https://user:pa#ss@example.com/x' },
  { 'https://user:pa?ss@example.com/x' },
  { 'data:,my-api-key-123456' },
  { 'data:text/plain;base64,c2VjcmV0' },
  { 'javascript:alert(document.cookie)' },
  { 'https://host.example;jsessionid=ABC123SECRET' },
  { 'https://host.example\\path?token=SECRET' },
  { 'https://host\27[31m.example/' },
  { 'https://host.example:abc/' },
  { 'https://user:pass@host.example:8080:9090/' },
  { 'about:blank' },
  { 'https:example.com/path' },
  { 'https://:8080/' },
  { 'file:///etc/passwd' },
  { 'https://' .. ('a'):rep(50000) .. '.com/' },
}

T['the web clue']['of a fetch is none for an address that holds no host'] = MiniTest.new_set({
  parametrize = HOSTILE_ADDRESSES,
})

T['the web clue']['of a fetch is none for an address that holds no host'][''] = function(address)
  local story = office_signals.tell()

  story.started('c1', 'WebFetch', { url = address })

  eq(story.details().web_clue, nil)
end

--- The addresses that give a host, and the host.
local LEGIT_ADDRESSES = {
  { 'https://example.com', 'example.com' },
  { 'https://user:pass@example.com:8080/path?q=secret#frag', 'example.com' },
  { 'http://[::1]:8080/', '[::1]' },
  { 'http://[2001:db8::1]/x', '[2001:db8::1]' },
  { 'https://例え.jp/パス', '例え.jp' },
  { 'https://xn--r8jz45g.jp/', 'xn--r8jz45g.jp' },
  { 'ftp://u:p@ftp.example:21/file', 'ftp.example' },
  { 'localhost:3000/app', 'localhost' },
}

T['the web clue']['of a fetch keeps a host of the shape of one'] = MiniTest.new_set({
  parametrize = LEGIT_ADDRESSES,
})

T['the web clue']['of a fetch keeps a host of the shape of one'][''] = function(address, host)
  local story = office_signals.tell()

  story.started('c1', 'WebFetch', { url = address })

  eq(story.details().web_clue, host)
end

T['the web clue']['is none for a call that looks nothing up'] = function()
  local story = office_signals.tell()

  story.started('c1', 'Read', { file_path = '/project/README.md' })

  eq(story.details().web_clue, nil)
end

T['the verdict of a test run'] = MiniTest.new_set()

local TESTS_COMMANDS = { tests = { 'make test' } }

T['the verdict of a test run']['is passed, and when, once a run that did not fail has its result'] = function()
  local story = office_signals.tell({ commands = TESTS_COMMANDS })
  story.started('c1', 'Bash', { command = 'make test' })

  story.finished('c1', false)

  eq(story.details().test_verdict, { passed = true, at = 2 * office_signals.PAUSE })
end

T['the verdict of a test run']['is failed once a run that failed has its result'] = function()
  local story = office_signals.tell({ commands = TESTS_COMMANDS })
  story.started('c1', 'Bash', { command = 'make test' })

  story.finished('c1', true)

  eq(story.details().test_verdict, { passed = false, at = 2 * office_signals.PAUSE })
end

T['the verdict of a test run']['is gone when the agent starts another run'] = function()
  local story = office_signals.tell({ commands = TESTS_COMMANDS })
  story.started('c1', 'Bash', { command = 'make test' })
  story.finished('c1', false)

  story.started('c2', 'Bash', { command = 'make test' })

  eq(story.details().test_verdict, nil)
end

T['the verdict of a test run']['is none for a command that is no test run'] = function()
  local story = office_signals.tell({ commands = TESTS_COMMANDS })
  story.started('c1', 'Bash', { command = 'ls' })

  story.finished('c1', true)

  eq(story.details().test_verdict, nil)
end

T['the verdict of a test run']['is none for a result read from the past'] = function()
  local story = office_signals.tell({ commands = TESTS_COMMANDS })
  story.hear_replayed(
    'tool_started',
    { call = 'c1', tool = 'Bash', input = { command = 'make test' } }
  )

  story.hear_replayed('tool_finished', { call = 'c1', failed = false })

  eq(story.details().test_verdict, nil)
end

T['the report'] = MiniTest.new_set()

local REPORT_TOOL = 'mcp__aineo__report'

T['the report']['is told when, once the agent calls the report tool'] = function()
  local story = office_signals.tell({ report_tool = REPORT_TOOL })

  story.started('c1', REPORT_TOOL, { status = 'done', summary = 'All green' })

  eq(story.details().reported_at, office_signals.PAUSE)
end

T['the report']['is told still when the call has its result'] = function()
  local story = office_signals.tell({ report_tool = REPORT_TOOL })
  story.started('c1', REPORT_TOOL, { status = 'done', summary = 'All green' })

  story.finished('c1')

  eq(story.details().reported_at, office_signals.PAUSE)
end

T['the report']['is none for a call of another tool'] = function()
  local story = office_signals.tell({ report_tool = REPORT_TOOL })

  story.started('c1', 'Bash', { command = 'ls' })

  eq(story.details().reported_at, nil)
end

T['the report']['is none for a call read from the past'] = function()
  local story = office_signals.tell({ report_tool = REPORT_TOOL })

  story.hear_replayed('tool_started', { call = 'c1', tool = REPORT_TOOL, input = {} })

  eq(story.details().reported_at, nil)
end

return T
