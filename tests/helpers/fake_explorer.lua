--- An explorer home (`aineo.explorer`) made for a suite that runs in its own
--- Neovim, over a fake git home that answers at once from a table.

local M = {}

--- What the fake git lists and the explorer is handed, changed by a case
--- between reads.
---@class FakeExplorerWorld
---@field files string[] the files git lists
---@field changes aineo.git.Change[] the files that differ from `HEAD`
---@field counts table<string, aineo.git.LineCount>
---@field work aineo.explorer.SessionWork|nil the work of the session
---@field folder string the folder Claude works in
---@field look? fun(): table<string, boolean>, string[]|nil what `settings.look` answers; none given, none is handed

--- Makes the world of a case, `overrides` over its defaults: the files
--- `a.txt`, `b.txt` and `c.txt` of the repository `/repo`, nothing changed.
---
---@param overrides? table
---@return FakeExplorerWorld
function M.new_world(overrides)
  return vim.tbl_extend('force', {
    files = { 'a.txt', 'b.txt', 'c.txt' },
    changes = {},
    counts = {},
    work = { top = '/repo', paths = {} },
    folder = '/repo',
  }, overrides or {})
end

--- An explorer home reading the repository `/repo` as `world` says at each
--- read.
---
---@param world FakeExplorerWorld
---@return aineo.explorer.Home
function M.new(world)
  local git = {
    find_repository = function(_, done)
      done(nil, { top = '/repo', git_directory = '/repo/.git', branch = 'main' })
    end,
    list_files = function(_, done)
      done(nil, world.files)
    end,
    uncommitted_files = function(_, done)
      done(nil, world.changes)
    end,
    ignored_files = function(_, done)
      done(nil, {})
    end,
    submodule_paths = function(_, done)
      done(nil, {})
    end,
    list_worktrees = function(_, done)
      done(nil, {})
    end,
    watch_repository = function() end,
    line_counts = function(_, done)
      done(nil, world.counts)
    end,
  }
  return require('aineo.explorer').new({
    git = git,
    claude_folder = function()
      return world.folder
    end,
    open_file = function() end,
    paste = function() end,
    quote_name = function(name)
      return name
    end,
    change_groups = {
      added = 'DiffAdd',
      modified = 'DiffChange',
      deleted = 'DiffDelete',
      renamed = 'DiffChange',
      type_changed = 'DiffChange',
      untracked = 'DiffAdd',
    },
    define_change_groups = function() end,
    session_work = function(done)
      done(world.work)
    end,
    look = world.look,
  })
end

return M
