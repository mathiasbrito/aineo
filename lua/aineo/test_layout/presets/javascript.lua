--- The test layouts of JavaScript and TypeScript: Jest's, Vitest's,
--- Angular's, Mocha's, the Node test runner's, Deno's and Bun's, and
--- Playwright's and Cypress's end-to-end folders; the default is a test
--- beside its source, `<name>.test.<ext>`.

--- The extensions of the sources the presets are for.
local SCRIPTS = { 'js', 'jsx', 'mjs', 'cjs', 'ts', 'tsx', 'mts', 'cts' }

--- The extensions a discovery glob names, in brace form.
local SCRIPT_GLOB = '{js,jsx,mjs,cjs,ts,tsx,mts,cts}'

--- Jest's default `testMatch`.
local JEST_DISCOVER = {
  '**/__tests__/**/*.' .. SCRIPT_GLOB,
  '**/*.{test,spec}.' .. SCRIPT_GLOB,
}

--- What marks a repository that runs Jest.
local JEST_MARKERS =
  { 'jest.config.*', '**/jest.config.*', { file = '**/package.json', holds = '"jest"' } }

--- Jest's page on its configuration.
local JEST_DOC = 'https://jestjs.io/docs/configuration'

--- What marks a repository that runs Vitest.
local VITEST_MARKERS = {
  'vitest.config.*',
  '**/vitest.config.*',
  { file = '**/package.json', holds = '"vitest"' },
}

return {
  presets = {
    {
      id = 'js.jest.colocated',
      framework = 'jest',
      doc = JEST_DOC,
      extensions = SCRIPTS,
      markers = JEST_MARKERS,
      discover = JEST_DISCOVER,
      rules = {
        {
          source = '{path}/{name}.{ext}',
          test = { '{path}/{name}.test.{ext}', '{path}/{name}.spec.{ext}' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.jest.dunder-tests',
      framework = 'jest',
      doc = JEST_DOC,
      extensions = SCRIPTS,
      markers = JEST_MARKERS,
      discover = JEST_DISCOVER,
      rules = {
        {
          source = '{path}/{name}.{ext}',
          test = { '{path}/__tests__/{name}.{ext}', '{path}/__tests__/{name}.test.{ext}' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.jest.root-tests',
      framework = 'jest',
      doc = JEST_DOC,
      extensions = SCRIPTS,
      markers = JEST_MARKERS,
      discover = JEST_DISCOVER,
      rules = {
        {
          source = 'src/{path}/{name}.{ext}',
          test = 'tests/{path}/{name}.test.{ext}',
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.vitest.colocated',
      framework = 'vitest',
      doc = 'https://vitest.dev/config/include',
      extensions = SCRIPTS,
      markers = VITEST_MARKERS,
      discover = { '**/*.{test,spec}.' .. SCRIPT_GLOB },
      rules = {
        {
          source = '{path}/{name}.{ext}',
          test = { '{path}/{name}.test.{ext}', '{path}/{name}.spec.{ext}' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.angular.spec-beside',
      framework = 'angular',
      doc = 'https://angular.dev/guide/testing',
      extensions = { 'ts' },
      markers = { 'angular.json', '**/angular.json' },
      discover = { '**/*.spec.ts', '**/*.test.ts' },
      rules = {
        {
          source = 'src/app/{path}/{name}.ts',
          test = 'src/app/{path}/{name}.spec.ts',
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.mocha.test-dir',
      framework = 'mocha',
      doc = 'https://mochajs.org/running/test-globs/',
      extensions = SCRIPTS,
      markers = { '.mocharc.*', '**/.mocharc.*', { file = '**/package.json', holds = '"mocha"' } },
      discover = { 'test/**/*.' .. SCRIPT_GLOB },
      rules = {
        {
          source = 'src/{path}/{name}.{ext}',
          test = {
            'test/{path}/{name}.{ext}',
            'test/{path}/{name}.spec.{ext}',
            'test/{path}/{name}.test.{ext}',
          },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.node-test.colocated',
      framework = 'node:test',
      doc = 'https://nodejs.org/api/test.html',
      extensions = SCRIPTS,
      markers = { { file = '**/package.json', holds = 'node --test' } },
      discover = {
        '**/*.test.' .. SCRIPT_GLOB,
        '**/*-test.' .. SCRIPT_GLOB,
        '**/*_test.' .. SCRIPT_GLOB,
        '**/test-*.' .. SCRIPT_GLOB,
        '**/test/**/*.' .. SCRIPT_GLOB,
      },
      rules = {
        {
          source = '{path}/{name}.{ext}',
          test = {
            '{path}/{name}.test.{ext}',
            '{path}/{name}-test.{ext}',
            '{path}/{name}_test.{ext}',
          },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.deno.colocated',
      framework = 'deno',
      doc = 'https://docs.deno.com/runtime/fundamentals/testing/',
      extensions = SCRIPTS,
      markers = { 'deno.json', 'deno.jsonc', 'deno.lock' },
      discover = {
        '**/*{_,.}test.' .. SCRIPT_GLOB,
        '**/test.' .. SCRIPT_GLOB,
        '**/__tests__/**/*.' .. SCRIPT_GLOB,
      },
      rules = {
        {
          source = '{path}/{name}.{ext}',
          test = { '{path}/{name}_test.{ext}', '{path}/{name}.test.{ext}' },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.bun.colocated',
      framework = 'bun',
      doc = 'https://bun.com/docs/test/discovery',
      extensions = SCRIPTS,
      markers = { 'bunfig.toml', 'bun.lock', 'bun.lockb' },
      discover = { '**/*{.,_}{test,spec}.' .. SCRIPT_GLOB },
      rules = {
        {
          source = '{path}/{name}.{ext}',
          test = {
            '{path}/{name}.test.{ext}',
            '{path}/{name}_test.{ext}',
            '{path}/{name}.spec.{ext}',
            '{path}/{name}_spec.{ext}',
          },
          kind = 'unit',
        },
      },
    },
    {
      id = 'js.playwright.e2e-folder',
      framework = 'playwright',
      doc = 'https://playwright.dev/docs/test-configuration',
      extensions = SCRIPTS,
      markers = { 'playwright.config.*', '**/playwright.config.*' },
      discover = {
        'tests/**/*.{spec,test}.' .. SCRIPT_GLOB,
        'e2e/**/*.{spec,test}.' .. SCRIPT_GLOB,
      },
      rules = { { folder = 'tests/', kind = 'e2e' } },
    },
    {
      id = 'js.cypress.e2e-folder',
      framework = 'cypress',
      doc = 'https://docs.cypress.io/app/references/configuration',
      extensions = SCRIPTS,
      markers = { 'cypress.config.*', '**/cypress.config.*' },
      discover = { 'cypress/e2e/**/*.cy.{js,jsx,ts,tsx}' },
      rules = { { folder = 'cypress/e2e/', kind = 'e2e' } },
    },
  },
  defaults = { { id = 'js.jest.colocated' } },
}
