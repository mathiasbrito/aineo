--- The test layouts of Go: a `_test.go` file beside its source, the
--- default, and a folder of integration tests.

--- The go tool's own page on test packages.
local GO_DOC = 'https://pkg.go.dev/cmd/go#hdr-Test_packages'

return {
  presets = {
    {
      id = 'go.testing.colocated',
      framework = 'go test',
      doc = GO_DOC,
      extensions = { 'go' },
      markers = { 'go.mod', '**/go.mod' },
      discover = { '**/*_test.go' },
      rules = { { source = '{path}/{name}.go', test = '{path}/{name}_test.go', kind = 'unit' } },
    },
    {
      id = 'go.testing.folder-integration',
      framework = 'go test',
      doc = GO_DOC,
      extensions = { 'go' },
      markers = {},
      discover = { 'test/**/*_test.go' },
      rules = { { folder = 'test/', kind = 'integration' } },
    },
  },
  defaults = { { id = 'go.testing.colocated' } },
}
