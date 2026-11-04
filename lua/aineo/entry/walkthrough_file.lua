--- What a step of a walkthrough may show of a file: the file the agent names
--- and the lines its ranges are about, checked against the file system
--- before anything is opened or drawn.

local M = {}

--- The largest file a step shows, in bytes: 1 MiB.
local LARGEST_FILE_BYTES = 1024 * 1024

--- The lines of the file at `path`: those its buffer holds when one is
--- loaded, so that a range is checked against what the user sees, else
--- those on disk.
---
---@param path string
---@return string[]
local function lines_of(path)
  local loaded = vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
    return vim.api.nvim_buf_is_loaded(buffer) and vim.api.nvim_buf_get_name(buffer) == path
  end)
  if loaded then
    return vim.api.nvim_buf_get_lines(loaded, 0, -1, false)
  end
  return vim.fn.readfile(path)
end

--- Whether a segment of `path` is `.git`, in any letter case: the folder of a
--- repository's own files, in which no checkout is found to ask.
---
---@param path string
---@return boolean
local function is_under_dot_git(path)
  return vim.iter(vim.split(path, '/', { plain = true })):any(function(segment)
    return segment:lower() == '.git'
  end)
end

--- Why the file at `path` may not be shown, in words for the agent that name
--- the field `file`; nil when it may: it is on disk, a regular file (a link
--- followed) of at most 1 MiB, inside a checkout of a repository one of
--- `folders` is a checkout of, below no `.git` and through no link that
--- leaves the checkout (`aineo.test_layout`'s `open_checkout_of()` and
--- `stays_inside()`).
---
---@param path string an absolute path
---@param folders string[] the folders whose repositories are open
---@return string?
local function file_problem(path, folders)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return ('file: %s is not on disk'):format(path)
  end
  if stat.type ~= 'file' then
    return ('file: %s is not a regular file'):format(path)
  end
  if stat.size > LARGEST_FILE_BYTES then
    return ('file: %s is larger than 1 MiB'):format(path)
  end
  local leaves = ('file: %s is under .git, outside the repository or a link leading out of it'):format(
    path
  )
  if is_under_dot_git(path) then
    return leaves
  end
  local test_layout = require('aineo.test_layout')
  local directory = vim.uv.fs_realpath(vim.fs.dirname(path))
  local root = directory and test_layout.open_checkout_of(directory, folders)
  if not root then
    return ('file: %s is in no repository the editor has open'):format(path)
  end
  if not test_layout.stays_inside(root, vim.fs.joinpath(directory, vim.fs.basename(path))) then
    return leaves
  end
  return nil
end

--- Why the range numbered `position` may not be shown over `lines`: it
--- reaches past the last line, or its `first_line`, when given, is not what
--- line `start` reads, the spaces around either left out; nil when it may.
---
---@param range aineo.mcp.WalkthroughRange
---@param position integer
---@param lines string[]
---@return string?
local function range_problem(range, position, lines)
  if range['end'] > #lines then
    return ('ranges[%d]: lines %d-%d are outside the file, which has %d lines'):format(
      position,
      range.start,
      range['end'],
      #lines
    )
  end
  local actual = lines[range.start]
  if range.first_line and vim.trim(range.first_line) ~= vim.trim(actual) then
    return ('ranges[%d].first_line: line %d reads "%s", not "%s"'):format(
      position,
      range.start,
      vim.trim(actual),
      vim.trim(range.first_line)
    )
  end
  return nil
end

--- Why the step `call` may not be shown, in words for the agent that name
--- the field at fault, checked in the order file, then ranges; nil when it
--- may. `folders` are those whose repositories are open: a file may be
--- shown when it lies in a checkout of one of them.
---
---@param call aineo.mcp.WalkthroughCall
---@param folders string[]
---@return string?
function M.problem_with(call, folders)
  local problem = file_problem(call.file, folders)
  if problem then
    return problem
  end
  local lines = lines_of(call.file)
  for position, range in ipairs(call.ranges) do
    problem = range_problem(range, position, lines)
    if problem then
      return problem
    end
  end
  return nil
end

return M
