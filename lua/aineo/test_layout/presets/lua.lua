--- The test layouts of Lua: busted's `spec/` mirror, plenary.nvim's
--- `tests/` mirror and mini.test's flat `tests/` folder — each framework's
--- file pattern is documented, the folders of the first two are common
--- use — and the default: busted's where the repository has a `spec/`
--- folder, else plenary.nvim's.
---
--- mini.test's rules name a source's test by the folders below the
--- plugin's (`lua/<plugin>/`) joined with `_`: `lua/kit/layout.lua` gives
--- `tests/test_layout.lua`, `lua/kit/finder/ranker.lua` gives
--- `tests/test_finder_ranker.lua`, and a folder's `init.lua` the folders
--- alone, `lua/kit/finder/init.lua` giving `tests/test_finder.lua`. A rule
--- whose `{path}` may stand for no folder follows the rule of one folder
--- fewer, which gives the test file in that case, and an `init.lua` rule
--- comes before the rules of any file, which also match it. The first
--- rule's test template matches every flat test file and binds no `{name}`,
--- so no source is found from a test file.

return {
  presets = {
    {
      id = 'lua.busted.spec-mirror',
      framework = 'busted',
      doc = 'https://lunarmodules.github.io/busted/',
      convention = true,
      extensions = { 'lua' },
      markers = { '.busted', { file = '*.rockspec', holds = 'busted' } },
      discover = { 'spec/**/*_spec.lua' },
      rules = {
        { source = 'lua/{path}/{name}.lua', test = 'spec/{path}/{name}_spec.lua', kind = 'unit' },
        { source = 'src/{path}/{name}.lua', test = 'spec/{path}/{name}_spec.lua', kind = 'unit' },
      },
    },
    {
      id = 'lua.plenary.spec-mirror',
      framework = 'plenary',
      doc = 'https://github.com/nvim-lua/plenary.nvim',
      convention = true,
      extensions = { 'lua' },
      markers = {
        { file = 'Makefile', holds = 'PlenaryBustedDirectory' },
        { file = '**/minimal_init.lua', holds = 'PlenaryBustedDirectory' },
      },
      discover = { 'tests/**/*_spec.lua' },
      rules = {
        { source = 'lua/{path}/{name}.lua', test = 'tests/{path}/{name}_spec.lua', kind = 'unit' },
      },
    },
    {
      id = 'lua.mini-test.flat',
      framework = 'mini.test',
      doc = 'https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md',
      extensions = { 'lua' },
      markers = {
        'tests/**/test_*.lua',
        { file = '**/minimal_init.lua', holds = 'mini.test' },
        { file = 'Makefile', holds = 'mini.test' },
      },
      discover = { 'tests/**/test_*.lua' },
      rules = {
        { source = 'lua/{pkg}/{dir}/init.lua', test = 'tests/test_{dir}.lua', kind = 'unit' },
        {
          source = 'lua/{pkg}/{dir}/{path}/init.lua',
          test = 'tests/test_{dir}_{path|_}.lua',
          kind = 'unit',
        },
        {
          source = 'lua/{pkg}/{dir}/{name}.lua',
          test = 'tests/test_{dir}_{name}.lua',
          kind = 'unit',
        },
        {
          source = 'lua/{pkg}/{dir}/{path}/{name}.lua',
          test = 'tests/test_{dir}_{path|_}_{name}.lua',
          kind = 'unit',
        },
        { source = 'lua/{pkg}/{name}.lua', test = 'tests/test_{name}.lua', kind = 'unit' },
      },
    },
  },
  defaults = {
    { folder = 'spec', id = 'lua.busted.spec-mirror' },
    { id = 'lua.plenary.spec-mirror' },
  },
}
