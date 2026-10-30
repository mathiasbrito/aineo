--- The test layouts of C++: the Pitchfork layout's `<name>.test.cpp` beside
--- its source, and two common conventions no documentation states —
--- `tests/<name>_test.cpp`, the default, and `<name>_test.cpp` beside its
--- source — each for `.cpp` and `.cc` sources.

--- The page Google Test's suites name their files by, which states no
--- layout of files.
local GOOGLETEST_DOC = 'https://google.github.io/googletest/primer.html'

return {
  presets = {
    {
      id = 'cpp.pitchfork.merged',
      framework = 'c++',
      doc = 'https://github.com/vector-of-bool/pitchfork',
      extensions = { 'cpp' },
      markers = { 'CMakeLists.txt' },
      discover = { '**/*.test.cpp' },
      rules = { { source = '{path}/{name}.cpp', test = '{path}/{name}.test.cpp', kind = 'unit' } },
    },
    {
      id = 'cpp.convention.tests-suffix',
      framework = 'c++',
      doc = GOOGLETEST_DOC,
      convention = true,
      extensions = { 'cpp', 'cc' },
      markers = {},
      discover = { 'tests/**/*_test.{cpp,cc}' },
      rules = {
        { source = '{path}/{name}.cpp', test = 'tests/{name}_test.cpp', kind = 'unit' },
        { source = '{path}/{name}.cc', test = 'tests/{name}_test.cc', kind = 'unit' },
      },
    },
    {
      id = 'cpp.convention.colocated-suffix',
      framework = 'c++',
      doc = GOOGLETEST_DOC,
      convention = true,
      extensions = { 'cpp', 'cc' },
      markers = {},
      discover = { '**/*_test.{cpp,cc}' },
      rules = {
        { source = '{path}/{name}.cpp', test = '{path}/{name}_test.cpp', kind = 'unit' },
        { source = '{path}/{name}.cc', test = '{path}/{name}_test.cc', kind = 'unit' },
      },
    },
  },
  defaults = { { id = 'cpp.convention.tests-suffix' } },
}
