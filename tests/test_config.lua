local MiniTest = require('mini.test')
local config = require('aineo.config')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local DEFAULTS = {
  prefix = '\\',
  terminal_prefix = '<C-\\>',
  autostart = true,
  claude = { cmd = { 'claude' }, hide_multiplexer = true },
  layout = { report_height = 2 / 3 },
  changes = { graph_limit = 1000 },
  tabs = { padding = 2, always_show = true },
  find = { picker = 'auto' },
  explain = {
    model = 'sonnet',
    timeout_ms = 180000,
    issues_prompt = 'Some issues were found in this code, can you check and propose a fix if the issue holds:',
  },
  office = {
    pack = 'default',
    pieces = {},
    commands = {
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
    },
  },
}

local T = MiniTest.new_set()

T['resolve_config()'] = MiniTest.new_set()

T['resolve_config()']['returns the defaults, and no unknown key, when nothing is set'] = function()
  local resolved, unknown_keys = config.resolve_config(nil, nil)

  eq(resolved, DEFAULTS)
  eq(unknown_keys, {})
end

T['resolve_config()']['takes a setting from vim.g.aineo over its default'] = function()
  local resolved = config.resolve_config({ prefix = ',', layout = { report_height = 0.5 } }, nil)

  eq(
    resolved,
    vim.tbl_deep_extend('force', DEFAULTS, {
      prefix = ',',
      layout = { report_height = 0.5 },
    })
  )
end

T['resolve_config()']['takes a setting from setup() over vim.g.aineo'] = function()
  local resolved = config.resolve_config({ prefix = ',' }, { prefix = ';' })

  eq(resolved.prefix, ';')
end

T['resolve_config()']['merges the two sources setting by setting'] = function()
  local resolved = config.resolve_config(
    { layout = { report_height = 0.5 } },
    { claude = { cmd = { 'my-claude', '--verbose' } } }
  )

  eq(
    resolved,
    vim.tbl_deep_extend('force', DEFAULTS, {
      claude = { cmd = { 'my-claude', '--verbose' } },
      layout = { report_height = 0.5 },
    })
  )
end

T['resolve_config()']['keeps false as a setting, never replacing it with the default'] =
  MiniTest.new_set({
    parametrize = { { 'prefix' }, { 'terminal_prefix' }, { 'autostart' } },
  })

T['resolve_config()']['keeps false as a setting, never replacing it with the default']['from setup()'] = function(
  key
)
  local resolved = config.resolve_config({}, { [key] = false })

  eq(resolved[key], false)
end

T['resolve_config()']['keeps claude.hide_multiplexer false, never replacing it with the default'] = function()
  local from_setup = config.resolve_config({}, { claude = { hide_multiplexer = false } })
  local from_global = config.resolve_config({ claude = { hide_multiplexer = false } }, nil)

  eq({ from_setup.claude.hide_multiplexer, from_global.claude.hide_multiplexer }, { false, false })
end

T['resolve_config()']['refuses a wrong value, naming its full path'] = MiniTest.new_set({
  parametrize = {
    { { global = { prefix = true }, refusal = 'prefix: expected' } },
    { { global = { prefix = 1 }, refusal = 'prefix: expected' } },
    { { global = { terminal_prefix = true }, refusal = 'terminal_prefix: expected' } },
    { { global = { terminal_prefix = 1 }, refusal = 'terminal_prefix: expected' } },
    { { global = { autostart = 'yes' }, refusal = 'autostart: expected' } },
    { { global = { claude = { cmd = 'claude' } }, refusal = 'claude%.cmd: expected' } },
    {
      {
        global = { claude = { hide_multiplexer = 'yes' } },
        refusal = 'claude%.hide_multiplexer: expected',
      },
    },
    {
      {
        setup = { claude = { hide_multiplexer = 1 } },
        refusal = 'claude%.hide_multiplexer: expected',
      },
    },
    { { global = { claude = { cmd = {} } }, refusal = 'claude%.cmd: expected' } },
    { { global = { claude = { cmd = { 'claude', 1 } } }, refusal = 'claude%.cmd: expected' } },
    {
      {
        global = { layout = { report_height = '2/3' } },
        refusal = 'layout%.report_height: expected',
      },
    },
    {
      {
        global = { changes = { working_branch = '' } },
        refusal = 'changes%.working_branch: expected',
      },
    },
    {
      {
        global = { changes = { working_branch = false } },
        refusal = 'changes%.working_branch: expected',
      },
    },
    {
      {
        global = { changes = { working_branch = 1 } },
        refusal = 'changes%.working_branch: expected',
      },
    },
    {
      {
        global = { changes = { working_branch = { 'origin/dev' } } },
        refusal = 'changes%.working_branch: expected',
      },
    },
    {
      {
        setup = { changes = { working_branch = '' } },
        refusal = 'changes%.working_branch: expected',
      },
    },
    { { global = { changes = 'origin/dev' }, refusal = 'changes: expected' } },
    { { global = { claude = 'claude' }, refusal = 'claude: expected' } },
    { { global = { layout = 0.5 }, refusal = 'layout: expected' } },
    { { global = 'aineo', refusal = 'vim%.g%.aineo: expected' } },
    { { setup = 1, refusal = 'setup_options: expected' } },
    { { setup = { autostart = 'yes' }, refusal = 'autostart: expected' } },
    { { global = { prefix = 1 }, setup = { prefix = ',' }, refusal = 'prefix: expected' } },
  },
})

T['resolve_config()']['refuses a wrong value, naming its full path']['from either source'] = function(
  case
)
  expect.error(function()
    config.resolve_config(case.global, case.setup)
  end, case.refusal)
end

T['resolve_config()']['refuses an empty prefix, which would map the keys it prefixes themselves'] = function()
  expect.error(function()
    config.resolve_config({ prefix = '' }, nil)
  end, 'prefix: expected a non%-empty string, or false')
end

T['resolve_config()']['refuses an empty terminal prefix, which would map the keys it prefixes themselves'] = function()
  expect.error(function()
    config.resolve_config({ terminal_prefix = '' }, nil)
  end, 'terminal_prefix: expected a non%-empty string, or false')
end

T['resolve_config()']['refuses a report height not strictly between 0 and 1'] = MiniTest.new_set({
  parametrize = { { 0 }, { 1 }, { 1.5 }, { -0.25 } },
})

T['resolve_config()']['refuses a report height not strictly between 0 and 1']['as layout.report_height'] = function(
  height
)
  expect.error(function()
    config.resolve_config({ layout = { report_height = height } }, nil)
  end, 'layout%.report_height: expected')
end

T['resolve_config()']['takes the padding of the tab titles from either source, 2 by default'] = function()
  local from_global = config.resolve_config({ tabs = { padding = 0 } }, nil)
  local from_setup = config.resolve_config({ tabs = { padding = 0 } }, { tabs = { padding = 4 } })
  local widest = config.resolve_config({ tabs = { padding = 8 } }, nil)

  eq(from_global.tabs.padding, 0)
  eq(from_setup.tabs.padding, 4)
  eq(widest.tabs.padding, 8)
  eq(config.resolve_config(nil, nil).tabs.padding, 2)
end

T['resolve_config()']['refuses a padding that is not a whole number from 0 to 8'] =
  MiniTest.new_set({
    parametrize = { { -1 }, { 1.5 }, { '2' }, { false }, { 9 }, { math.huge } },
  })

T['resolve_config()']['refuses a padding that is not a whole number from 0 to 8']['as tabs.padding'] = function(
  padding
)
  expect.error(function()
    config.resolve_config({ tabs = { padding = padding } }, nil)
  end, 'tabs%.padding: expected a whole number from 0 to 8')
end

T['resolve_config()']['takes whether the tab line always shows from either source, true by default'] = function()
  local from_global = config.resolve_config({ tabs = { always_show = false } }, nil)
  local from_setup = config.resolve_config(
    { tabs = { always_show = false } },
    { tabs = { always_show = true } }
  )

  eq(from_global.tabs.always_show, false)
  eq(from_setup.tabs.always_show, true)
  eq(config.resolve_config(nil, nil).tabs.always_show, true)
end

T['resolve_config()']['refuses an always_show that is not a boolean'] = MiniTest.new_set({
  parametrize = { { 1 }, { 'true' }, { {} } },
})

T['resolve_config()']['refuses an always_show that is not a boolean']['as tabs.always_show'] = function(
  always_show
)
  expect.error(function()
    config.resolve_config({ tabs = { always_show = always_show } }, nil)
  end, 'tabs%.always_show: expected boolean')
end

T['resolve_config()']['takes the picker of the file finder from either source, auto by default'] = function()
  local from_global = config.resolve_config({ find = { picker = 'telescope' } }, nil)
  local from_setup = config.resolve_config(
    { find = { picker = 'telescope' } },
    { find = { picker = 'fzf-lua' } }
  )

  eq(from_global.find.picker, 'telescope')
  eq(from_setup.find.picker, 'fzf-lua')
  eq(config.resolve_config(nil, nil).find.picker, 'auto')
end

T['resolve_config()']['takes each picker the file finder knows'] = MiniTest.new_set({
  parametrize = { { 'auto' }, { 'snacks' }, { 'fzf-lua' }, { 'telescope' }, { 'mini.pick' } },
})

T['resolve_config()']['takes each picker the file finder knows']['as find.picker'] = function(
  picker
)
  eq(config.resolve_config({ find = { picker = picker } }, nil).find.picker, picker)
end

T['resolve_config()']['refuses a picker the file finder does not know'] = MiniTest.new_set({
  parametrize = { { 'ctrlp' }, { '' }, { false }, { 1 }, { {} } },
})

T['resolve_config()']['refuses a picker the file finder does not know']['as find.picker'] = function(
  picker
)
  expect.error(function()
    config.resolve_config({ find = { picker = picker } }, nil)
  end, 'find%.picker: expected one of auto, snacks, fzf%-lua, telescope, mini%.pick')
end

T['resolve_config()']['takes the working branch of the changes pane from either source, none by default'] = function()
  local from_global = config.resolve_config({ changes = { working_branch = 'origin/dev' } }, nil)
  local from_setup = config.resolve_config(
    { changes = { working_branch = 'origin/dev' } },
    { changes = { working_branch = 'dev' } }
  )

  eq(from_global.changes, { working_branch = 'origin/dev', graph_limit = 1000 })
  eq(from_setup.changes, { working_branch = 'dev', graph_limit = 1000 })
  eq(config.resolve_config(nil, nil).changes.working_branch, nil)
end

T['resolve_config()']['takes the commit graph’s limit from either source, 1000 by default'] = function()
  local from_global = config.resolve_config({ changes = { graph_limit = 50 } }, nil)
  local from_setup = config.resolve_config(
    { changes = { graph_limit = 50 } },
    { changes = { graph_limit = 1 } }
  )

  eq(from_global.changes.graph_limit, 50)
  eq(from_setup.changes.graph_limit, 1)
  eq(config.resolve_config(nil, nil).changes.graph_limit, 1000)
end

T['resolve_config()']['refuses a graph limit that is not a whole number of at least 1'] =
  MiniTest.new_set({
    parametrize = { { 0 }, { -5 }, { 2.5 }, { '100' }, { false }, { math.huge } },
  })

T['resolve_config()']['refuses a graph limit that is not a whole number of at least 1']['as changes.graph_limit'] = function(
  limit
)
  expect.error(function()
    config.resolve_config({ changes = { graph_limit = limit } }, nil)
  end, 'changes%.graph_limit: expected a whole number of at least 1')
end

T['resolve_config()']['takes the model that explains code from either source, sonnet by default'] = function()
  local from_global = config.resolve_config({ explain = { model = 'opus' } }, nil)
  local from_setup = config.resolve_config(
    { explain = { model = 'opus' } },
    { explain = { model = 'haiku' } }
  )

  eq(from_global.explain.model, 'opus')
  eq(from_setup.explain.model, 'haiku')
  eq(config.resolve_config(nil, nil).explain.model, 'sonnet')
end

T['resolve_config()']['refuses a model that is not a non-empty string'] = MiniTest.new_set({
  parametrize = { { '' }, { 5 }, { false }, { { 'sonnet' } } },
})

T['resolve_config()']['refuses a model that is not a non-empty string']['as explain.model'] = function(
  model
)
  expect.error(function()
    config.resolve_config({ explain = { model = model } }, nil)
  end, 'explain%.model: expected a non%-empty string naming a model')
end

T['resolve_config()']['takes how long code is explained at most from either source, 180000 ms by default'] = function()
  local from_global = config.resolve_config({ explain = { timeout_ms = 1000 } }, nil)
  local from_setup = config.resolve_config(
    { explain = { timeout_ms = 1000 } },
    { explain = { timeout_ms = 1 } }
  )

  eq(from_global.explain.timeout_ms, 1000)
  eq(from_setup.explain.timeout_ms, 1)
  eq(config.resolve_config(nil, nil).explain.timeout_ms, 180000)
end

T['resolve_config()']['refuses a timeout that is not a whole number of milliseconds of at least 1'] =
  MiniTest.new_set({
    parametrize = { { 0 }, { -5 }, { 2.5 }, { '100' }, { false }, { math.huge } },
  })

T['resolve_config()']['refuses a timeout that is not a whole number of milliseconds of at least 1']['as explain.timeout_ms'] = function(
  timeout
)
  expect.error(function()
    config.resolve_config({ explain = { timeout_ms = timeout } }, nil)
  end, 'explain%.timeout_ms: expected a whole number of milliseconds of at least 1')
end

T['resolve_config()']['takes the prompt that sends marked issues from either source, a request to check them by default'] = function()
  local from_global = config.resolve_config({ explain = { issues_prompt = 'Check these:' } }, nil)
  local from_setup = config.resolve_config(
    { explain = { issues_prompt = 'Check these:' } },
    { explain = { issues_prompt = 'Fix these:' } }
  )

  eq(from_global.explain.issues_prompt, 'Check these:')
  eq(from_setup.explain.issues_prompt, 'Fix these:')
  eq(
    config.resolve_config(nil, nil).explain.issues_prompt,
    'Some issues were found in this code, can you check and propose a fix if the issue holds:'
  )
end

T['resolve_config()']['refuses an issues prompt that is not a non-empty string'] =
  MiniTest.new_set({
    parametrize = { { '' }, { 5 }, { false }, { { 'Check' } } },
  })

T['resolve_config()']['refuses an issues prompt that is not a non-empty string']['as explain.issues_prompt'] = function(
  prompt
)
  expect.error(function()
    config.resolve_config({ explain = { issues_prompt = prompt } }, nil)
  end, 'explain%.issues_prompt: expected a non%-empty string')
end

T['resolve_config()']['returns a key no setting knows, rather than refusing it'] = function()
  local resolved, unknown_keys = config.resolve_config({ prefx = ',' }, nil)

  eq(resolved, DEFAULTS)
  eq(unknown_keys, { 'prefx' })
end

T['resolve_config()']['names an unknown key inside a section by its full path'] = function()
  local _, unknown_keys = config.resolve_config({ claude = { command = { 'my-claude' } } }, nil)

  eq(unknown_keys, { 'claude.command' })
end

T['resolve_config()']['returns a dotted top-level key as unknown, never as its setting'] = function()
  local resolved, unknown_keys = config.resolve_config({ ['layout.report_height'] = 5 }, nil)

  eq(resolved, DEFAULTS)
  eq(unknown_keys, { 'layout.report_height' })
end

T['resolve_config()']['returns an unknown key of the setup() options too'] = function()
  local _, unknown_keys = config.resolve_config(nil, { autostrat = false })

  eq(unknown_keys, { 'autostrat' })
end

T['resolve_config()']["takes the classes of commands from either source, the plan's four by default"] = function()
  local from_global =
    config.resolve_config({ office = { commands = { tests = { 'just check' } } } }, nil)
  local from_setup = config.resolve_config(
    { office = { commands = { tests = { 'just check' } } } },
    { office = { commands = { reading = { 'cat' } } } }
  )

  eq(from_global.office.commands, { tests = { 'just check' } })
  eq(from_setup.office.commands, { reading = { 'cat' } })
  eq(config.resolve_config(nil, nil).office, DEFAULTS.office)
end

T['resolve_config()']['takes a class of commands that has no match, and one with a glob and a Lua pattern'] = function()
  local commands = {
    tests = {},
    reading = { 'cat *.md', { lua_pattern = '^less%s' } },
  }

  local resolved = config.resolve_config({ office = { commands = commands } }, nil)

  eq(resolved.office.commands, commands)
end

T['resolve_config()']['refuses classes of commands that are not a table of lists of matches'] =
  MiniTest.new_set({
    parametrize = {
      { 'make test' },
      { { 'make test' } },
      { { building = { 'make' } } },
      { { tests = 'make test' } },
      { { tests = { '' } } },
      { { tests = { 5 } } },
      { { tests = { {} } } },
      { { tests = { { lua_pattern = 5 } } } },
      { { tests = { { lua_pattern = '[' } } } },
      { { tests = { { lua_pattern = '^make', glob = 'x' } } } },
      { false },
    },
  })

T['resolve_config()']['refuses classes of commands that are not a table of lists of matches']['as office.commands'] = function(
  commands
)
  expect.error(function()
    config.resolve_config({ office = { commands = commands } }, nil)
  end, 'office%.commands: expected')
end

--- Lua patterns the setting refuses: Lua cannot read them whole, or they hold
--- more than one repetition (`*`, `+`, `-`) and could take seconds.
local REFUSED_PATTERNS = {
  { '[' },
  { 'a[' },
  { 'test[' },
  { 'make [' },
  { '[^' },
  { '[a-' },
  { 'a%' },
  { 'test%' },
  { 'a%b' },
  { 'a%bx' },
  { 'a%f' },
  { 'a%fx' },
  { 'a%f[' },
  { 'test(' },
  { 'te(st' },
  { 'test)' },
  { '(a))' },
  { 'a%1' },
  { '(a)%2' },
  { '(a%1)' },
  { '%0' },
  { '.-.-x' },
  { '^a.*b.*c' },
  { '%d+%.%d+' },
  { 'a*b+' },
}

T['resolve_config()']['refuses a Lua pattern of the commands that Lua cannot read whole, or that repeats twice'] =
  MiniTest.new_set({
    parametrize = REFUSED_PATTERNS,
  })

T['resolve_config()']['refuses a Lua pattern of the commands that Lua cannot read whole, or that repeats twice']['as office.commands'] = function(
  pattern
)
  expect.error(function()
    config.resolve_config(
      { office = { commands = { tests = { { lua_pattern = pattern } } } } },
      nil
    )
  end, 'office%.commands: expected')
end

--- Lua patterns the setting takes.
local ACCEPTED_PATTERNS = {
  { '^make%s+test' },
  { 'make test$' },
  { '^cat%s[%w_-]+' },
  { '[]]' },
  { '[^]]' },
  { '[%]]' },
  { '%[x%]' },
  { '(%w+)' },
  { '()' },
  { '(a)%1' },
  { '%b()' },
  { '%f[%w]make' },
  { 'a?' },
  { '%a?x' },
  { '[%w_]?x' },
  { '[%w%-]*' },
  { '$a' },
  { 'a$b' },
  { '*a' },
  { '+' },
}

T['resolve_config()']['takes a Lua pattern of the commands that Lua reads whole and that repeats once at most'] =
  MiniTest.new_set({
    parametrize = ACCEPTED_PATTERNS,
  })

T['resolve_config()']['takes a Lua pattern of the commands that Lua reads whole and that repeats once at most']['as office.commands'] = function(
  pattern
)
  local commands = { tests = { { lua_pattern = pattern } } }

  local resolved = config.resolve_config({ office = { commands = commands } }, nil)

  eq(resolved.office.commands, commands)
end

T['resolve_config()']['says what is wrong with a Lua pattern of the commands'] = function()
  expect.error(function()
    config.resolve_config(
      { office = { commands = { tests = { { lua_pattern = 'test%' } } } } },
      nil
    )
  end, 'office%.commands: expected.*the pattern ends with')
  expect.error(function()
    config.resolve_config(
      { office = { commands = { tests = { { lua_pattern = '.-.-x' } } } } },
      nil
    )
  end, 'office%.commands: expected.*repeat')
end

T['lua_pattern_problem()'] = MiniTest.new_set()

--- Lua patterns with more than one repetition item (`*`, `+`, `-` and `?`),
--- the second of which makes the cost grow with the text, or exponentially.
local PATTERNS_THAT_REPEAT_TWICE = {
  { '.-.-x' },
  { 'a?b?' },
  { 'a?b?c?d?' },
  { '.?.?x' },
  { '%s+%d+' },
  { '%a*%a*%a*' },
  { '[%w_]+[%w_]?' },
  { 'x*(y+)' },
  { ('.?'):rep(24) .. 'x' },
}

T['lua_pattern_problem()']['says what is wrong with a pattern that repeats twice, whichever the items'] =
  MiniTest.new_set({
    parametrize = PATTERNS_THAT_REPEAT_TWICE,
  })

T['lua_pattern_problem()']['says what is wrong with a pattern that repeats twice, whichever the items']['pattern'] = function(
  pattern
)
  eq(type(config.lua_pattern_problem(pattern)), 'string')
end

T['lua_pattern_problem()']['says nothing of a pattern Lua reads whole that repeats once at most'] = function()
  eq(config.lua_pattern_problem('^make%s+test'), nil)
end

T['lua_pattern_problem()']['says what is wrong with a pattern Lua cannot read'] = function()
  eq(type(config.lua_pattern_problem('test%')), 'string')
end

T['lua_pattern_problem()']['says what is wrong with a pattern that repeats twice'] = function()
  eq(type(config.lua_pattern_problem('.-.-x')), 'string')
end

T['resolve_config()']['takes the office’s pack from either source, the default pack by default'] = function()
  local from_global = config.resolve_config({ office = { pack = 'harbour' } }, nil)
  local from_setup = config.resolve_config(
    { office = { pack = 'harbour' } },
    { office = { pack = { 'harbour', 'default' } } }
  )

  eq(from_global.office.pack, 'harbour')
  eq(from_setup.office.pack, { 'harbour', 'default' })
  eq(config.resolve_config(nil, nil).office.pack, 'default')
end

T['resolve_config()']['refuses an office pack that is no name and no list of names'] =
  MiniTest.new_set({
    parametrize = {
      { '' },
      { {} },
      { { '' } },
      { { 1 } },
      { 5 },
      { false },
      { 'a/b' },
      { '../x' },
      { 'a b' },
      { { 'ok', 'a/b' } },
    },
  })

T['resolve_config()']['refuses an office pack that is no name and no list of names']['as office.pack'] = function(
  pack
)
  expect.error(function()
    config.resolve_config({ office = { pack = pack } }, nil)
  end, 'office%.pack: expected a name of letters, digits, _ and %-, or a list of names')
end

T['resolve_config()']['takes the art files of the office’s pieces from either source, none by default'] = function()
  local from_global =
    config.resolve_config({ office = { pieces = { desk = '/my/desk.txt' } } }, nil)
  local from_setup = config.resolve_config(
    { office = { pieces = { desk = '/my/desk.txt' } } },
    { office = { pieces = { door = '/my/door.txt' } } }
  )

  eq(from_global.office.pieces, { desk = '/my/desk.txt' })
  eq(from_setup.office.pieces, { door = '/my/door.txt' })
  eq(config.resolve_config(nil, nil).office.pieces, {})
end

T['resolve_config()']['refuses office pieces that are no table of names and files'] =
  MiniTest.new_set({
    parametrize = {
      { 'desk.txt' },
      { { 'desk.txt' } },
      { { desk = 5 } },
      { { desk = '' } },
      { false },
    },
  })

T['resolve_config()']['refuses office pieces that are no table of names and files']['as office.pieces'] = function(
  pieces
)
  expect.error(function()
    config.resolve_config({ office = { pieces = pieces } }, nil)
  end, 'office%.pieces: expected a table of piece names and art files')
end

T['resolve_config()']['lists an office key no setting knows'] = function()
  local _, unknown_keys = config.resolve_config({ office = { packs = 'x', pack = 'default' } }, nil)

  eq(unknown_keys, { 'office.packs' })
end

T['resolve_config()']['lists each unknown key once, in sorted order'] = function()
  local _, unknown_keys = config.resolve_config(
    { zeta = 1, alpha = 1, mu = 1, delta = 1, omega = 1 },
    { alpha = 2, beta = 2 }
  )

  eq(unknown_keys, { 'alpha', 'beta', 'delta', 'mu', 'omega', 'zeta' })
end

T['resolve_config()']['shares no table with the sources'] = function()
  local setup_options = { claude = { cmd = { 'my-claude' } } }
  local resolved = config.resolve_config(nil, setup_options)

  resolved.claude.cmd[1] = 'changed by a caller'

  eq(setup_options.claude.cmd, { 'my-claude' })
end

T['resolve_config()']['shares no table with the defaults between resolutions'] = function()
  local first = config.resolve_config(nil, nil)
  first.claude.cmd[1] = 'changed by a caller'

  local second = config.resolve_config(nil, nil)

  eq(second.claude.cmd, { 'claude' })
end

return T
