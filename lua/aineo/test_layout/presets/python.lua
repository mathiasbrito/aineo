--- The test layouts of Python: pytest's, unittest's and Django's, and the
--- default — the `src/` mirror where the repository has a `src/` folder,
--- else the flat `tests/` folder.

--- What marks a repository that runs pytest.
local PYTEST_MARKERS = {
  'pytest.ini',
  '**/conftest.py',
  { file = 'pyproject.toml', holds = '[tool.pytest.ini_options]' },
  { file = 'tox.ini', holds = '[pytest]' },
  { file = 'setup.cfg', holds = '[tool:pytest]' },
}

--- pytest's default `python_files`.
local PYTEST_DISCOVER = { '**/test_*.py', '**/*_test.py' }

--- pytest's page on laying out tests.
local PYTEST_DOC = 'https://docs.pytest.org/en/stable/explanation/goodpractices.html'

return {
  presets = {
    {
      id = 'python.pytest.src-mirror',
      framework = 'pytest',
      doc = PYTEST_DOC,
      extensions = { 'py' },
      markers = PYTEST_MARKERS,
      discover = PYTEST_DISCOVER,
      rules = {
        {
          source = 'src/{pkg}/{path}/{name}.py',
          test = { 'tests/{path}/test_{name}.py', 'tests/{pkg}/{path}/test_{name}.py' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'python.pytest.flat',
      framework = 'pytest',
      doc = PYTEST_DOC,
      extensions = { 'py' },
      markers = PYTEST_MARKERS,
      discover = PYTEST_DISCOVER,
      rules = { { source = '{path}/{name}.py', test = 'tests/test_{name}.py', kind = 'unit' } },
    },
    {
      id = 'python.pytest.inline-package',
      framework = 'pytest',
      doc = PYTEST_DOC,
      extensions = { 'py' },
      markers = PYTEST_MARKERS,
      discover = PYTEST_DISCOVER,
      rules = {
        {
          source = '{pkg}/{path}/{name}.py',
          test = '{pkg}/{path}/tests/test_{name}.py',
          kind = 'unit',
        },
      },
    },
    {
      id = 'python.pytest.suffix',
      framework = 'pytest',
      doc = PYTEST_DOC,
      extensions = { 'py' },
      markers = PYTEST_MARKERS,
      discover = PYTEST_DISCOVER,
      rules = {
        {
          source = '{path}/{name}.py',
          test = { '{path}/{name}_test.py', 'tests/{path}/{name}_test.py' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'python.unittest.default',
      framework = 'unittest',
      doc = 'https://docs.python.org/3/library/unittest.html#test-discovery',
      extensions = { 'py' },
      markers = {},
      discover = { '**/test*.py' },
      companions = { '__init__.py' },
      rules = {
        {
          source = '{pkg}/{path}/{name}.py',
          test = { 'tests/test_{name}.py', '{pkg}/tests/test_{name}.py' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'python.django.app',
      framework = 'django',
      doc = 'https://docs.djangoproject.com/en/stable/topics/testing/overview/',
      extensions = { 'py' },
      markers = { 'manage.py' },
      discover = { '**/test*.py' },
      companions = { '__init__.py' },
      rules = {
        { source = '{app}/{name}.py', test = { '{app}/tests/test_{name}.py', '{app}/tests.py' } },
      },
    },
  },
  defaults = { { folder = 'src', id = 'python.pytest.src-mirror' }, { id = 'python.pytest.flat' } },
}
