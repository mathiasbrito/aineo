--- Where aineo keeps the test layout of each repository: the agent's rules
--- and the user's corrections, as JSON in the editor's state directory,
--- one file per repository, never in the repository itself.

local M = {}

--- The file that keeps the layout of the repository whose main worktree
--- is `root`, under `state_directory`: named by a hash of `root`, so that
--- every worktree of the repository shares it.
---
---@param state_directory string
---@param root string
---@return string
local function file_of(state_directory, root)
  return vim.fs.joinpath(
    state_directory,
    'aineo',
    'test_layout',
    vim.fn.sha256(root):sub(1, 32) .. '.json'
  )
end

--- What is kept of the repository whose main worktree is `root`: an empty
--- table when nothing is, or the file cannot be read or decoded, or it
--- keeps another repository's layout.
---
---@param state_directory string
---@param root string
---@return aineo.test_layout.Stored
function M.read(state_directory, root)
  local file = io.open(file_of(state_directory, root), 'r')
  if not file then
    return {}
  end
  local text = file:read('*a')
  file:close()
  local decoded, kept = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if not decoded or type(kept) ~= 'table' or kept.root ~= root then
    return {}
  end
  return { agent = kept.agent, user = kept.user }
end

--- Keeps `stored` as the layout of the repository whose main worktree is
--- `root`, in place of what was kept: written beside its file first, which
--- then takes the file's name at once, so that a reader sees the one or
--- the other whole.
---
--- Raises an error naming the file when it cannot be written.
---
---@param state_directory string
---@param root string
---@param stored aineo.test_layout.Stored
function M.write(state_directory, root, stored)
  local path = file_of(state_directory, root)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local written = ('%s.%d.writing'):format(path, vim.fn.getpid())
  local text = vim.json.encode({ root = root, agent = stored.agent, user = stored.user })
  if vim.fn.writefile({ text }, written) ~= 0 then
    error('aineo: cannot write the test layout to ' .. written, 0)
  end
  local renamed, failure = vim.uv.fs_rename(written, path)
  if not renamed then
    error(('aineo: cannot keep the test layout in %s: %s'):format(path, failure), 0)
  end
end

return M
