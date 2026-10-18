--- What aineo does with the processes of the run panes when the editor quits
--- or a tab closes: asks the user once before they are stopped, and stops
--- them with their children.
---
--- A quit that exits the editor (`:qa`, `:q` in the last window, `:wq`,
--- `:x`) triggers `ExitPre` first, and a handler of it can keep the editor
--- open without an error: the one thing that makes Neovim abandon the quit
--- from there is a change in the tab pages, so the handler opens a tab page
--- and closes it again once the command that asked to quit is done. Nothing
--- in `QuitPre` or `ExitPre` tells `:qa` from `:qa!`; a forced quit is
--- recognised in the command line the user typed.

local errors = require('aineo.entry.errors')
local registry = require('aineo.entry.registry')

local M = {}

--- What the question names as the thing the user answers: the sentence's end
--- after the dash, and the buttons, Cancel last and the default.
---@class aineo.entry.Goal
---@field outcome string
---@field buttons string

---@type aineo.entry.Goal
local QUIT = { outcome = 'quit', buttons = '&Quit\n&Cancel' }

---@type aineo.entry.Goal
local CLOSE_TAB = { outcome = 'close the tab', buttons = '&Close\n&Cancel' }

--- The number of the button that confirms, and of the one that cancels,
--- which is the default.
local CONFIRM, CANCEL = 1, 2

--- The Ex commands that quit the editor when given a bang, by every spelling
--- Vim accepts of their names.
local FORCING_COMMANDS = {}
for _, name in ipairs({
  'q',
  'qu',
  'qui',
  'quit',
  'qa',
  'qal',
  'qall',
  'quita',
  'quital',
  'quitall',
  'wq',
  'wqa',
  'wqal',
  'wqall',
  'x',
  'xi',
  'xit',
  'xa',
  'xal',
  'xall',
  'exi',
  'exit',
  'exita',
  'exital',
  'exitall',
}) do
  FORCING_COMMANDS[name] = true
end

--- Whether the command line the user typed last quits with a bang (`:qa!`),
--- in any of the commands it joins with a bar. A quit run by a mapping's
--- `<Cmd>` or by Lua leaves no command line behind and counts as unforced.
---
---@return boolean
local function is_forced_quit()
  for command in vim.fn.histget(':', -1):gmatch('[^|]+') do
    local name = command:match('^[%s:]*(%a+)!')
    if name and FORCING_COMMANDS[name] then
      return true
    end
  end
  return false
end

--- The names of the processes the run panes of all the tabs run, the
--- oldest of each tab first.
---
---@return string[] names
local function running_processes()
  local names = {}
  for _, tab in ipairs(registry.tab_list) do
    vim.list_extend(names, tab.running_processes())
  end
  return names
end

--- The question that asks the user to stop `names`, the processes that run,
--- for `goal`.
---
---@param names string[]
---@param goal aineo.entry.Goal
---@return string
local function question_about(names, goal)
  return ('aineo: %d %s will be stopped (%s) — %s?'):format(
    #names,
    #names == 1 and 'process' or 'processes',
    table.concat(names, ', '),
    goal.outcome
  )
end

--- Asks the user, once, whether to stop the processes `names` for `goal`,
--- Cancel the default; true without a question when there are none.
---
---@param names string[]
---@param goal aineo.entry.Goal
---@return boolean confirmed
local function confirm_stopping(names, goal)
  if #names == 0 then
    return true
  end
  return vim.fn.confirm(question_about(names, goal), goal.buttons, CANCEL) == CONFIRM
end

--- Keeps the editor open, from an `ExitPre` handler: opens a tab page at the
--- end, which makes Neovim abandon the quit, and closes it again, with the
--- cursor back in the window and tab page it was in, once the command that
--- asked to quit is done.
local function keep_editor_open()
  local origin_page, origin_window =
    vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
  vim.cmd('$tabnew')
  local temporary_page = vim.api.nvim_get_current_tabpage()
  vim.schedule(function()
    if vim.api.nvim_tabpage_is_valid(temporary_page) then
      vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(temporary_page))
    end
    if vim.api.nvim_tabpage_is_valid(origin_page) then
      vim.api.nvim_set_current_tabpage(origin_page)
    end
    if vim.api.nvim_win_is_valid(origin_window) then
      vim.api.nvim_set_current_win(origin_window)
    end
  end)
end

--- Whether `ExitPre` ran for the quit that is running now: true from that
--- event until the callback scheduled in it, which a quit that goes on never
--- reaches.
local is_exit_asked = false

--- Asks before the editor exits (`ExitPre`): once, listing the processes that
--- run, unless the quit is forced (`is_forced_quit()`); on Cancel keeps the
--- editor open (`keep_editor_open()`).
local function ask_before_exit()
  is_exit_asked = true
  vim.schedule(function()
    is_exit_asked = false
  end)
  if is_forced_quit() then
    return
  end
  if not confirm_stopping(running_processes(), QUIT) then
    keep_editor_open()
  end
end

--- Stops the processes of the run panes of all the tabs as the editor leaves
--- (`VimLeavePre`), each home with its children, telling the user once that
--- they are being stopped when no question came first (`ExitPre` is not
--- triggered by `:cquit` or a signal that ends the editor). One home that
--- cannot stop does not keep the others from it.
local function stop_processes_at_exit()
  local names = running_processes()
  if #names > 0 and not is_exit_asked then
    vim.notify(
      ('aineo: stopping %d %s (%s)'):format(
        #names,
        #names == 1 and 'process' or 'processes',
        table.concat(names, ', ')
      ),
      vim.log.levels.WARN
    )
  end
  for _, tab in ipairs(registry.tab_list) do
    errors.run(tab.homes.run.stop_all)
  end
end

--- Whether the handlers of the quit have been made (`guard()`).
local is_guarding = false

--- Makes, once, the handlers that ask before the editor exits and stop the
--- processes as it leaves. Made when a process starts, so that an editor
--- that runs none carries no handler of this.
function M.guard()
  if is_guarding then
    return
  end
  is_guarding = true
  local group = vim.api.nvim_create_augroup('aineo.entry.quit', {})
  vim.api.nvim_create_autocmd('ExitPre', {
    group = group,
    desc = 'aineo: ask before the processes of the run pane are stopped',
    callback = ask_before_exit,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    desc = 'aineo: stop the processes of the run pane',
    callback = stop_processes_at_exit,
  })
end

--- Asks the user, once, whether to close `tab`, whose run pane's processes
--- are stopped with it; true without a question when it runs none.
---
---@param tab aineo.entry.Tab
---@return boolean confirmed
function M.confirm_closing(tab)
  return confirm_stopping(tab.running_processes(), CLOSE_TAB)
end

return M
