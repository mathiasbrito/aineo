--- What the test layout reads of a git repository: its worktree's folder,
--- its files, a text search over them, and the folder of its main
--- worktree, each by running `git`.

local M = {}

--- How long one `git` call may take, in milliseconds.
local GIT_TIMEOUT_MS = 10000

--- Runs `git -C <directory> -c core.fsmonitor=false <args…>` and returns
--- its output, or nil when it fails or does not end in time. The file
--- system monitor is off so that no command a repository's own
--- configuration names runs for aineo.
---
---@param directory string
---@param args string[]
---@return string?
local function git(directory, args)
  local command = vim.list_extend({ 'git', '-C', directory, '-c', 'core.fsmonitor=false' }, args)
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

--- The git folder every worktree of the repository holding `directory`
--- shares (`--git-common-dir`), as the file system resolves it; nil when
--- `directory` is in no git worktree.
---
---@param directory string
---@return string?
function M.common_folder_of(directory)
  local common = git(directory, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  common = common and vim.trim(common)
  return common and common ~= '' and (vim.uv.fs_realpath(common) or common) or nil
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

--- The largest file the view reads, in bytes: 1 MiB.
local LARGEST_READ = 1024 * 1024

--- The text of the file at `path` when it is a regular file, links
--- followed, of at most `LARGEST_READ` bytes; nil for anything else — a
--- pipe, a device, a folder, a larger file — or a file that cannot be read,
--- so that no read waits on a pipe or fills the memory.
---
---@param path string
---@return string?
local function read_regular(path)
  local stat = vim.uv.fs_stat(path)
  if not (stat and stat.type == 'file' and stat.size <= LARGEST_READ) then
    return nil
  end
  local file = io.open(path, 'r')
  if not file then
    return nil
  end
  local text = file:read(LARGEST_READ)
  file:close()
  return text
end

--- The view of the worktree at `root` (`aineo.test_layout.finding`): its
--- tracked files and its untracked ones that are not ignored, a text search
--- over the same files for fixed strings, and a reader of one of them, of a
--- regular file of at most 1 MiB only (`read_regular()`).
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
      local args = { 'grep', '-n', '-z', '-F', '--untracked' }
      for _, pattern in ipairs(patterns) do
        vim.list_extend(args, { '-e', pattern })
      end
      local hits = {}
      for line in vim.gsplit(git(root, args) or '', '\n', { plain = true }) do
        local path, text = line:match('^([^%z]+)%z[^%z]*%z(.*)$')
        if path then
          table.insert(hits, { path = path, text = text })
        end
      end
      return hits
    end,
    read = function(relative)
      return read_regular(root .. '/' .. relative)
    end,
  }
end

return M
