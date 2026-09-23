--- Runs git for the suites the same way everywhere — without the developer's
--- global or system git configuration, under a fixed identity — and builds the
--- local repositories that stand in for mini.nvim's on GitHub, so `make deps`
--- is tested without the network.

local M = {}

--- The environment every git the suites start runs with, `make`'s included.
M.HERMETIC_ENVIRONMENT = {
  GIT_CONFIG_GLOBAL = '/dev/null',
  GIT_CONFIG_NOSYSTEM = '1',
  GIT_AUTHOR_NAME = 'aineo tests',
  GIT_AUTHOR_EMAIL = 'tests@aineo.invalid',
  GIT_COMMITTER_NAME = 'aineo tests',
  GIT_COMMITTER_EMAIL = 'tests@aineo.invalid',
}

--- Runs `git <args…>` in `directory` and returns its trimmed output.
--- Raises an error carrying git's message when git fails.
---
---@param directory string
---@param args string[]
---@return string
local function run(directory, args)
  local result = vim
    .system(vim.list_extend({ 'git' }, args), {
      cwd = directory,
      env = M.HERMETIC_ENVIRONMENT,
      text = true,
    })
    :wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end

--- Makes the empty directory `directory` a repository holding `count` empty
--- commits, one after another.
---
---@param directory string an existing, empty directory
---@param count integer
---@return string url the repository's `file://` URL
---@return string[] commits the commits' hashes, oldest first
function M.create_repository(directory, count)
  run(directory, { 'init', '--quiet' })
  local commits = {}
  for index = 1, count do
    run(directory, { 'commit', '--quiet', '--allow-empty', '--message', 'commit ' .. index })
    commits[index] = run(directory, { 'rev-parse', 'HEAD' })
  end
  return 'file://' .. directory, commits
end

--- The commit checked out in the repository at `directory`. Only that
--- repository is asked, never one enclosing it.
---
---@param directory string
---@return string
function M.head(directory)
  return run(directory, { '--git-dir', vim.fs.joinpath(directory, '.git'), 'rev-parse', 'HEAD' })
end

return M
