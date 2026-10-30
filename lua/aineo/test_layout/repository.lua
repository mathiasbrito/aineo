--- What the test layout reads of a git repository: its worktree's folder,
--- its files, a text search over them, and the folder of its main
--- worktree, each by running `git`.

local M = {}

--- How long one `git` call may take, in milliseconds.
local GIT_TIMEOUT_MS = 10000

--- Runs `git -C <directory> <args…>` and returns its output, or nil when
--- it fails or does not end in time.
---
---@param directory string
---@param args string[]
---@return string?
local function git(directory, args)
  local command = vim.list_extend({ 'git', '-C', directory }, args)
  local ran, process = pcall(vim.system, command, { text = true })
  if not ran then
    return nil
  end
  local result = process:wait(GIT_TIMEOUT_MS)
  return result.code == 0 and result.stdout or nil
end

--- The NUL-separated names of `output`, without empty ones.
---
---@param output string
---@return string[]
local function names_of(output)
  return vim.split(output, '\0', { plain = true, trimempty = true })
end

--- The folder of the worktree that holds `directory`, an existing folder,
--- as git spells it, or nil when `directory` is in no git worktree.
---
---@param directory string
---@return string?
function M.worktree_of(directory)
  local top = git(directory, { 'rev-parse', '--show-toplevel' })
  return top and vim.trim(top) ~= '' and vim.trim(top) or nil
end

--- The folder of the main worktree of the repository whose worktree is
--- `root`, which every worktree of the repository shares; `root` itself
--- when git does not say.
---
---@param root string
---@return string
function M.main_worktree_of(root)
  local common = git(root, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  common = common and vim.trim(common)
  if common and vim.fs.basename(common) == '.git' then
    return vim.fs.dirname(common)
  end
  return root
end

--- The view of the worktree at `root` (`aineo.test_layout.finding`): its
--- tracked files and its untracked ones that are not ignored, a text search
--- over the same files for fixed strings, and a reader of one of them.
---
---@param root string
---@return aineo.test_layout.View
function M.view_of(root)
  local files =
    names_of(git(root, { 'ls-files', '-z', '--cached', '--others', '--exclude-standard' }) or '')
  local has = {}
  for _, file in ipairs(files) do
    has[file] = true
  end
  local sorted = vim.tbl_keys(has)
  table.sort(sorted)
  return {
    root = root,
    files = sorted,
    has = has,
    grep = function(patterns)
      local args = { 'grep', '-l', '-z', '-F', '--untracked' }
      for _, pattern in ipairs(patterns) do
        vim.list_extend(args, { '-e', pattern })
      end
      return names_of(git(root, args) or '')
    end,
    read = function(relative)
      local file = io.open(root .. '/' .. relative, 'r')
      if not file then
        return nil
      end
      local text = file:read('*a')
      file:close()
      return text
    end,
  }
end

return M
