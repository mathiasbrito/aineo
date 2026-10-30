--- aineo's test layout home, `require('aineo.test_layout')`: where the test
--- file of a source is, and the source of a test file, in a git repository,
--- by the rules in force there — the user's corrections, the rules an agent
--- stated, the presets the repository shows, the language's default
--- (`aineo.test_layout.trust`) — and the keeping of those rules.
---
--- The rules are kept per repository in the editor's state directory,
--- `stdpath('state')`, and a worktree's files are kept 10 s between calls
--- by the event loop's clock: the home's two ambient values, read here, as
--- the functions take the path of a file and nothing else.

local cache = require('aineo.test_layout.cache')
local finding = require('aineo.test_layout.finding')
local presets = require('aineo.test_layout.presets')
local repository = require('aineo.test_layout.repository')
local rules = require('aineo.test_layout.rules')
local store = require('aineo.test_layout.store')
local trust = require('aineo.test_layout.trust')

local M = {}

--- How a line for the user names who stated a rule.
local ORIGIN_WORDS = {
  user = 'you',
  agent = 'the agent',
  repository = 'the repository',
  preset = 'the default',
}

--- A rule named for the user: its description and who stated it.
---
---@param description string
---@param origin 'user'|'agent'|'repository'|'preset'
---@return string
local function named_rule(description, origin)
  return ('%s, from %s'):format(description, ORIGIN_WORDS[origin])
end

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

--- `path` made absolute and normalised.
---
---@param path string
---@return string
local function absolute_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
end

--- The editor's state directory, under which the layouts are kept.
---
---@return string
local function state_directory()
  return vim.fn.stdpath('state') --[[@as string]]
end

--- How long the files of a worktree, and the presets ranked for them, are
--- kept between calls, in milliseconds.
local KEPT_MS = 10000

--- The view of each worktree read lately, by its folder, with the presets
--- ranked for it (`view.ranked`), by the event loop's clock.
local views = cache.new(vim.uv.now, KEPT_MS)

--- The view of the worktree at `root`: the one read within `KEPT_MS`, else
--- read now.
---
---@param root string
---@return aineo.test_layout.View
local function view_of(root)
  return views:get(root, function()
    local view = repository.view_of(root)
    view.ranked = {}
    return view
  end)
end

--- Drops what is kept of the worktree whose folder is `repository_root`,
--- its files and the presets ranked for them, so that the next call reads
--- them again: for a caller that has just written a file there, such as a
--- new test file. `correct()` and `declare()` do it themselves.
---
---@param repository_root string
function M.forget(repository_root)
  views:forget(vim.uv.fs_realpath(repository_root) or absolute_path(repository_root))
end

--- Where `path`, any file's path, is, and the rules in force for it; nil
--- and why when it is in no git worktree.
---
---@param path string
---@return aineo.test_layout.Located?
---@return string? problem
local function locate(path)
  local absolute = absolute_path(path)
  local folder = existing_folder(absolute)
  local root = folder and repository.worktree_of(folder)
  local relative = root and relative_to(absolute, root)
  if not relative then
    return nil, absolute .. ' is in no git worktree'
  end
  local view = view_of(root)
  local stored = store.read(state_directory(), repository.main_worktree_of(root))
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
--- — it is in no git worktree, or no rule gives it a source — in the shape
--- of `test_for()`'s place, with no `sibling` and no companions. A two-way
--- rule gives the source; with none, the existing files named by the stem
--- a one-way rule's test template binds, then those the test imports
--- (`aineo.test_layout.finding`'s `source_for()`).
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

--- Keeps the user's correction: the test file of the source at
--- `source_path` is the file at `test_path`, in every worktree of its
--- repository, before any rule (`test_for()` then gives it, whether it
--- exists or not); and when a preset's template gives that pair, the
--- template becomes the user's rule for the repository's other sources.
--- Returns whether it was kept, and why not: the source is in no git
--- worktree, or the test file is outside the source's.
---
--- Raises an error naming the file when the layout cannot be written.
---
---@param source_path string
---@param test_path string
---@return boolean kept
---@return string? problem
function M.correct(source_path, test_path)
  local located, problem = locate(source_path)
  if not located then
    return false, problem
  end
  local test = relative_to(absolute_path(test_path), located.view.root)
  if not test then
    return false, absolute_path(test_path) .. ' is outside the worktree of its source'
  end
  local main = repository.main_worktree_of(located.view.root)
  local stored = store.read(state_directory(), main)
  local user = stored.user or {}
  user.pairs = user.pairs or {}
  user.rules = user.rules or {}
  user.pairs[located.relative] = test
  local fitted = trust.fitting_template(located.view, presets, located.relative, test)
  if fitted and not vim.tbl_contains(user.rules, fitted, { deep = true }) then
    table.insert(user.rules, fitted)
  end
  stored.user = user
  store.write(state_directory(), main, stored)
  views:forget(located.view.root)
  return true
end

--- The rules in force for the tests of the git worktree that holds the
--- folder `directory`, each once, in the order of trust, named with who
--- stated it as `describe()` names a rule, such as `python.pytest.flat,
--- from the repository`; and the worktree's folder. Nil and why when
--- `directory` is in no git worktree.
---
---@param directory string
---@return string[]? rules
---@return string root_or_problem the worktree's folder, or why there are no rules
function M.rules_in_force(directory)
  local folder = vim.uv.fs_realpath(directory)
  local root = folder and repository.worktree_of(folder)
  if not root then
    return nil, absolute_path(directory) .. ' is in no git worktree'
  end
  local stored = store.read(state_directory(), repository.main_worktree_of(root))
  local named = vim.tbl_map(function(rule)
    return named_rule(rule.description, rule.origin)
  end, trust.in_force(view_of(root), stored, presets))
  return named, root
end

--- The ids of the presets an agent may name, in the catalogue's order.
---
---@return string[]
function M.preset_ids()
  return presets.ids()
end

--- What an agent states of a repository's test layout, through aineo's
--- `test_layout` tool.
---@class aineo.test_layout.Declaration
---@field worktree string the absolute path of a folder of the repository's worktree
---@field rules aineo.test_layout.Statement[] the rules, each a preset named by its id or a rule of its own
---@field framework? string the framework of the rules that name none
---@field replace? boolean whether the rules replace those kept (true when not given) or are added after them

--- `count` and `noun`, the noun made plural unless `count` is one.
---
---@param count integer
---@param noun string
---@return string
local function counted(count, noun)
  return ('%d %s%s'):format(count, noun, count == 1 and '' or 's')
end

--- The line of the reply for one assessed rule, at `position`.
---
---@param position integer
---@param assessment aineo.test_layout.Assessment
---@return string
local function assessment_line(position, assessment)
  local line = ('%d. %s: pairs %s with a test, %s'):format(
    position,
    assessment.description,
    counted(assessment.pairs, 'source'),
    counted(assessment.contradictions, 'contradiction')
  )
  if #assessment.after == 0 then
    return line
  end
  return ('%s; kept after %s, which %s the repository’s sources with tests'):format(
    line,
    table.concat(assessment.after, ', '),
    #assessment.after == 1 and 'pairs' or 'pair'
  )
end

--- The words of a refusal of a declaration, for the agent.
---
---@param reason string
---@return { text: string, is_error: boolean }
local function refused(reason)
  return { text = 'aineo refused the test layout: ' .. reason, is_error = true }
end

--- Keeps the rules `declaration` states as the agent's rules of its
--- worktree's repository — in place of those kept, or after them when
--- `replace` is false — and answers the agent: each rule kept, how many
--- existing sources it pairs with existing tests, how many of those tests
--- another rule pairs with a different source, and the presets it is kept
--- after when it pairs nothing while they pair some (A669). The agent's
--- rules then come after the user's corrections and before the presets.
---
--- Refuses, keeping nothing, a worktree that is no git checkout, and rules
--- `aineo.test_layout.rules`'s `statements_problem()` refuses — an unknown
--- preset, a template a guard refuses, more than 32 rules — naming the
--- field at fault.
---
--- Raises an error naming the file when the layout cannot be written.
---
---@param declaration aineo.test_layout.Declaration
---@return { text: string, is_error: boolean }
function M.declare(declaration)
  local folder = vim.uv.fs_realpath(declaration.worktree)
  local root = folder and repository.worktree_of(folder)
  if not root then
    return refused(('worktree: %s is not a git checkout'):format(declaration.worktree))
  end
  local main = repository.main_worktree_of(root)
  local stored = store.read(state_directory(), main)
  local statements = vim.deepcopy(declaration.rules)
  if declaration.replace == false then
    statements =
      vim.list_extend(vim.deepcopy(stored.agent and stored.agent.rules or {}), statements)
  end
  local problem = rules.statements_problem(statements, presets)
  if problem then
    return refused(problem)
  end
  stored.agent = { rules = statements, framework = declaration.framework }
  store.write(state_directory(), main, stored)
  views:forget(root)
  local lines = { ('aineo keeps %s for this repository:'):format(counted(#statements, 'rule')) }
  for position, assessment in ipairs(trust.assess(view_of(root), stored, presets)) do
    table.insert(lines, assessment_line(position, assessment))
  end
  return { text = table.concat(lines, '\n'), is_error = false }
end

--- One line on the file at `path` for the window that shows it: the rule
--- that gives its pair — its test file, or for a test file its source —
--- and who stated it, such as `python.pytest.flat, from the repository`;
--- or why it has none.
---
---@param path string
---@return string
function M.describe(path)
  local located, problem = locate(path)
  if not located then
    return problem
  end
  local place, why
  if finding.is_test(located.rules, located.view, located.relative) then
    place, why = finding.source_for(located.rules, located.view, located.relative)
  else
    place, why = finding.test_for(located.rules, located.view, located.relative)
  end
  if not place then
    return why
  end
  return named_rule(place.rule, place.origin)
end

return M
