--- aineo's test layout home, `require('aineo.test_layout')`: where the test
--- file of a source is, and the source of a test file, in a git repository,
--- by the rules in force there — the user's corrections, the rules an agent
--- stated, the presets the repository shows, the language's default
--- (`aineo.test_layout.trust`) — and the keeping of those rules.
---
--- The rules are kept per repository in the editor's state directory,
--- `stdpath('state')`, read here as the home's one ambient value: the
--- functions take the path of a file and nothing else.

local finding = require('aineo.test_layout.finding')
local presets = require('aineo.test_layout.presets')
local repository = require('aineo.test_layout.repository')
local store = require('aineo.test_layout.store')
local trust = require('aineo.test_layout.trust')

local M = {}

--- What a file's path tells of where it is: the view of its worktree, its
--- path relative to that worktree, and the rules in force for it.
---@class aineo.test_layout.Located
---@field view aineo.test_layout.View
---@field relative string
---@field rules aineo.test_layout.Rule[]

--- The nearest folder at or above `path`'s folder that exists, as the
--- file system resolves it (symbolic links followed), or nil when none
--- does.
---
---@param path string an absolute path
---@return string?
local function existing_folder(path)
  local folder = vim.fs.dirname(path)
  while folder do
    local real = vim.uv.fs_realpath(folder)
    if real then
      return real
    end
    local above = vim.fs.dirname(folder)
    folder = above ~= folder and above or nil
  end
  return nil
end

--- `path` relative to `root`, a worktree's folder, as the file system
--- resolves the folders that exist; nil when it is not inside `root`.
---
---@param path string an absolute path
---@param root string
---@return string?
local function relative_to(path, root)
  local folder = vim.fs.dirname(path)
  local tail = vim.fs.basename(path)
  while not vim.uv.fs_realpath(folder) do
    tail = vim.fs.basename(folder) .. '/' .. tail
    folder = vim.fs.dirname(folder)
  end
  local real = vim.uv.fs_realpath(folder) .. '/' .. tail
  if not vim.startswith(real, root .. '/') then
    return nil
  end
  return real:sub(#root + 2)
end

--- Where `path`, any file's path, is, and the rules in force for it; nil
--- and why when it is in no git worktree.
---
---@param path string
---@return aineo.test_layout.Located?
---@return string? problem
local function locate(path)
  local absolute = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  local folder = existing_folder(absolute)
  local root = folder and repository.worktree_of(folder)
  local relative = root and relative_to(absolute, root)
  if not relative then
    return nil, absolute .. ' is in no git worktree'
  end
  local view = repository.view_of(root)
  local stored = store.read(vim.fn.stdpath('state'), repository.main_worktree_of(root))
  return {
    view = view,
    relative = relative,
    rules = trust.rules_for(view, stored, presets, relative),
  }
end

--- Where the test file of the source at `source_path` is, or nil and why
--- not — the source is in no git worktree, no rule matches it, or it is a
--- test file itself.
---
--- The place's `path` is the best existing test file, or, when none
--- exists, the file the creating rule gives; `candidates` every existing
--- one, best first: those the rules' templates name, in the order of the
--- rules, then shortest path first, else the test files whose text names
--- the source's module. `sibling`, for a new test file only, is the
--- existing test file nearest to it, and `companions` the files to create
--- with it — Python's `__init__.py`, when the sibling's folder has one.
---
---@param source_path string
---@return aineo.test_layout.Place?
---@return string? problem
function M.test_for(source_path)
  local located, problem = locate(source_path)
  if not located then
    return nil, problem
  end
  return finding.test_for(located.rules, located.view, located.relative)
end

--- Where the source of the test file at `test_path` is, or nil and why not
--- — it is in no git worktree, or no two-way rule gives it a source — in
--- the shape of `test_for()`'s place, with no `sibling` and no companions.
---
---@param test_path string
---@return aineo.test_layout.Place?
---@return string? problem
function M.source_for(test_path)
  local located, problem = locate(test_path)
  if not located then
    return nil, problem
  end
  return finding.source_for(located.rules, located.view, located.relative)
end

--- Whether the file at `path` is a test file: a discovery glob or a test
--- template of a rule in force names it. False for a file in no git
--- worktree.
---
---@param path string
---@return boolean
function M.is_test(path)
  local located = locate(path)
  return located ~= nil and finding.is_test(located.rules, located.view, located.relative)
end

return M
