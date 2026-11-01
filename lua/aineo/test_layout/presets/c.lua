--- The test layouts of C: Ceedling's `test/test_<name>.c`, the default,
--- and a common convention no documentation states, `tests/test_<name>.c`.

return {
  presets = {
    {
      id = 'c.ceedling.unity',
      framework = 'ceedling',
      doc = 'https://www.throwtheswitch.org/ceedling',
      extensions = { 'c' },
      markers = { 'project.yml' },
      discover = { 'test/**/test_*.c' },
      rules = { { source = 'src/{name}.c', test = 'test/test_{name}.c', kind = 'unit' } },
    },
    {
      id = 'c.convention.tests-prefix',
      framework = 'c',
      doc = 'https://cmake.org/cmake/help/latest/command/add_test.html',
      convention = true,
      extensions = { 'c' },
      markers = {},
      discover = { 'tests/**/test_*.c' },
      rules = { { source = '{path}/{name}.c', test = 'tests/test_{name}.c', kind = 'unit' } },
    },
  },
  defaults = { { id = 'c.ceedling.unity' } },
}
