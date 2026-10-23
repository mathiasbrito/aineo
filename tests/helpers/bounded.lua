--- Runs Lua in a Neovim of its own with a time limit, for the tests of code
--- that must not hang the editor: if the code runs on, the process is
--- killed when the limit is up and the test fails by its assertion, instead of
--- the suite waiting for it.

local fixture = dofile('tests/helpers/fixture.lua')

local M = {}

--- The init of the suites, which puts this checkout on 'runtimepath'.
local INIT = vim.fs.joinpath(vim.uv.cwd(), 'scripts', 'minimal_init.lua')

--- What a run of `run()` came to.
---@class aineo.tests.BoundedRun
---@field finished boolean whether the code ended by itself, without an error, before the limit
---@field stdout string what it printed
---@field stderr string what it told on the error stream, an error among it

--- Runs `source`, Lua, in a headless Neovim with the suites' init, for at
--- most `limit_ms`; kills it past that. The code prints what it wants to hand
--- back (`print()` writes to the output stream here, not to the error stream
--- Neovim's `-l` gives it), and ends the process itself or by running out.
---
---@param source string
---@param limit_ms integer
---@return aineo.tests.BoundedRun
function M.run(source, limit_ms)
  local directory = fixture.directory(('bounded_%d'):format(vim.fn.getpid()))
  local script = vim.fs.joinpath(directory, 'probe.lua')
  local prelude =
    "print = function(...) io.stdout:write(table.concat(vim.tbl_map(tostring, { ... }), '\\t'), '\\n') end\n"
  assert(
    vim.fn.writefile(vim.split(prelude .. source, '\n', { plain = true }), script) == 0,
    'cannot write ' .. script
  )
  local result = vim
    .system(
      { vim.v.progpath, '--headless', '-u', INIT, '-i', 'NONE', '-l', script },
      { text = true, timeout = limit_ms }
    )
    :wait()
  return {
    finished = result.code == 0 and result.signal == 0,
    stdout = result.stdout or '',
    stderr = result.stderr or '',
  }
end

return M
