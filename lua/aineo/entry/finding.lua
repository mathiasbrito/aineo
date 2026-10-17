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

--- Calls `done` with the top of the repository `directory` is in, and with
--- `directory` itself when it is in none, or git cannot say.
---
---@param directory string
---@param done fun(root: string)
local function find_root(directory, done)
  require('aineo.git').find_repository(directory, function(_, repository)
    done(repository and repository.top or directory)
  end)
end

--- Starts the search for a file of `tab` (`aineo.find`'s `find_file()`) once the
--- root of its folder is known (`find_root()`), unless the cursor has left
--- the window it was in by then. The configuration is read at once, so a
--- wrong setting raises its error to the caller; an error the search raises
--- later is told to the user once (`aineo.entry.errors`' `run()`).
---
---@param tab aineo.entry.Tab
function M.find_in(tab)
  local picker = resolved_config().find.picker
  local window = vim.api.nvim_get_current_win()
  find_root(claude_directory(tab), function(root)
    if vim.api.nvim_get_current_win() ~= window then
      return
    end
    errors.run(function()
      require('aineo.find').find_file({ directory = root, picker = picker })
    end)
  end)
end

return M
