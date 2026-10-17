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
  changes = {},
  tabs = { padding = 2, always_show = true },
  find = { picker = 'auto' },
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

  eq(from_global.changes, { working_branch = 'origin/dev' })
  eq(from_setup.changes, { working_branch = 'dev' })
  eq(config.resolve_config(nil, nil).changes.working_branch, nil)
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
