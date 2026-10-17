--- What `:Aineo find` does in an aineo tab: searches the files under the
--- folder the tab's Claude Code works in, or under the top of the repository
--- that folder is in, with the picker `find.picker` names
--- (`aineo.find`), and so opens the file picked in the file column.

local errors = require('aineo.entry.errors')

local M = {}

--- aineo's configuration, resolved from `vim.g.aineo` and the options
--- `require('aineo').setup()` recorded (`aineo.config`'s `resolve_config()`).
--- Raises its error naming the setting that is wrong.
---
---@return table
local function resolved_config()
  local config = require('aineo.config')
  return (config.resolve_config(vim.g.aineo, config.recorded_setup_options()))
end

--- The folder the tab's Claude Code works in: where it started, and before
--- it has started, where the editor is.
---
---@param tab aineo.entry.Tab
---@return string
local function claude_directory(tab)
  return tab.homes.claude.session_directory() or vim.fn.getcwd()
end

--- Calls `done` with the repository `directory` is in, as the git home finds
--- it (`aineo.git`'s `find_repository()`), and with nil when it is in none, or
--- git cannot say.
---
---@param directory string
---@param done fun(repository: aineo.git.Repository|nil)
local function find_repository(directory, done)
  require('aineo.git').find_repository(directory, function(_, repository)
    done(repository)
  end)
end

--- How the finder lists the files of `repository`: through the git home, so
--- that its environment handling and time limit hold.
---
---@param repository aineo.git.Repository
---@return aineo.find.ListFiles
local function list_files_of(repository)
  return function(done)
    require('aineo.git').list_files(repository, done)
  end
end

--- What the user is told when the search is asked for from a floating window.
local FROM_A_FLOAT = 'aineo: a file is found from a window of the tab, not from a floating one'

--- Starts the search for a file of `tab` (`aineo.find`'s `find_file()`) once the
--- repository of its folder is known (`find_repository()`), unless the cursor
--- has left the window it was in by then; under the repository's top, else
--- under the folder. A search asked for from a floating window starts nothing
--- and tells the user once, with a warning: the file would open in the float,
--- and a picker's own float would be left. The configuration is read at once,
--- so a wrong setting raises its error to the caller; an error the search
--- raises later is told to the user once (`aineo.entry.errors`' `run()`).
---
---@param tab aineo.entry.Tab
function M.find_in(tab)
  local picker = resolved_config().find.picker
  local window = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(window).relative ~= '' then
    vim.notify(FROM_A_FLOAT, vim.log.levels.WARN)
    return
  end
  local directory = claude_directory(tab)
  find_repository(directory, function(repository)
    if vim.api.nvim_get_current_win() ~= window then
      return
    end
    errors.run(function()
      require('aineo.find').find_file({
        directory = repository and repository.top or directory,
        picker = picker,
        list_files = repository and list_files_of(repository) or nil,
      })
    end)
  end)
end

return M
