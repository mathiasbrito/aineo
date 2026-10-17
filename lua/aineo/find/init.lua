--- aineo's file finder, `require('aineo.find')`: a search for a file under a
--- directory, handed to a third-party picker when one is installed, and
--- otherwise run through `vim.ui.select()` over the directory's files. It
--- reads no setting and knows no tab: the composition root hands it the
--- directory and the picker `find.picker` names.

local files = require('aineo.find.files')
local pickers = require('aineo.find.pickers')

local M = {}

--- The name of the third-party picker `setting`, a value of `find.picker`,
--- asks for, when it is installed: for `auto`, the first of snacks, fzf-lua,
--- telescope and mini.pick that is; for a name, that picker alone. Nil when
--- none is, and the finder lists the files itself.
---
---@param setting string
---@return string|nil
function M.picker_in_use(setting)
  local picker = pickers.installed(setting)
  return picker and picker.name
end

--- What a search for a file is given.
---@class aineo.find.Options
---@field directory string the directory whose files are searched: an absolute path
---@field picker string `find.picker`: `auto`, or the name of the one picker to use
---@field list_files? aineo.find.ListFiles how the files of the repository the directory is in are listed, for the finder's own list; nil when the directory is in none, and the files are those a walk of it finds

--- What the user is told when the picker `find.picker` forces, `name`, is not
--- installed.
---
---@param name string
---@return string
local function not_installed(name)
  return ('aineo: find.picker is %s, which is not installed: the files are listed with vim.ui.select'):format(
    name
  )
end

--- The prompt of the list the finder offers through `vim.ui.select()`.
local PROMPT = 'Find file'

--- Opens `path`, relative to `directory`, in `window` when it still exists,
--- else in the current window, as `:edit` does. Tells the user once, with an
--- error, when `:edit` refuses — the buffer in the window holds unsaved changes
--- and cannot be hidden, say.
---
---@param directory string
---@param path string
---@param window integer
local function open_file(directory, path, window)
  if vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_set_current_win(window)
  end
  local opened, failure = pcall(vim.cmd.edit, vim.fn.fnameescape(vim.fs.joinpath(directory, path)))
  if not opened then
    vim.notify(('aineo: %s'):format((tostring(failure):gsub('^Vim:', ''))), vim.log.levels.ERROR)
  end
end

--- What the user is told when `failure` kept the repository's files from
--- being listed under `directory`.
---
---@param directory string
---@param failure aineo.find.ListFailure
---@return string
local function git_could_not_list(directory, failure)
  return ('aineo: git could not list the files under %s (%s): the list is what a walk of the folder finds'):format(
    directory,
    failure.message
  )
end

--- Offers the files under `directory` through `vim.ui.select()`, once they
--- are listed (`aineo.find.files`'s `list()`, given `list_files`), and opens
--- the one picked in the window the cursor is in now. Tells the user once, with
--- a warning, when listing the repository's files failed and a walk of the
--- folder stands in.
---
---@param directory string
---@param list_files aineo.find.ListFiles|nil
local function select_from_files(directory, list_files)
  local window = vim.api.nvim_get_current_win()
  files.list(directory, list_files, function(listed, cut, failure)
    if failure then
      vim.notify(git_could_not_list(directory, failure), vim.log.levels.WARN)
    end
    if #listed == 0 then
      vim.notify(('aineo: no file under %s'):format(directory), vim.log.levels.INFO)
      return
    end
    if cut then
      vim.notify(
        ('aineo: the list stops at the first %d files under %s'):format(files.MOST_FILES, directory),
        vim.log.levels.INFO
      )
    end
    vim.ui.select(listed, { prompt = PROMPT }, function(path)
      if path then
        open_file(directory, path, window)
      end
    end)
  end)
end

--- Starts a search for a file under `options.directory`, in the third-party
--- picker `options.picker` asks for (`picker_in_use()`), which is called with
--- the directory as its working directory and opens the file picked as it
--- opens any file: in the window that is current when it confirms. With none
--- installed, the files under the directory are offered through
--- `vim.ui.select()` (`select_from_files()`), so that a `vim.ui.select` of the
--- user's gives the search whatever matching it has; when a picker was forced,
--- the user is told once that it is not installed.
---
---@param options aineo.find.Options
function M.find_file(options)
  local picker = pickers.installed(options.picker)
  if picker then
    picker.open(options.directory)
    return
  end
  if options.picker ~= 'auto' then
    vim.notify(not_installed(options.picker), vim.log.levels.WARN)
  end
  select_from_files(options.directory, options.list_files)
end

return M
