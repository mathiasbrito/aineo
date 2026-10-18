--- What one tab does with its run pane: asks for a command and starts it in
--- the project folder, adds an interactive shell, shows the stack and puts the
--- cursor in it, and keeps the pane in step with the processes that come and
--- go.

local errors = require('aineo.entry.errors')
local places = require('aineo.entry.places')
local quitting = require('aineo.entry.quitting')

local M = {}

--- What the prompt for a command says.
local PROMPT = 'Run in the project folder: '

--- What the run pane tells the user, as an error, when the folder aineo
--- started in (`kept_places()`) is gone: the folder, in `%s`.
local FOLDER_GONE = 'the folder aineo started in is gone, so nothing started: %s'

--- What a tab hands its run pane to act on.
---@class aineo.entry.RunPaneTab
---@field run aineo.run.Home the tab's run home
---@field layout aineo.layout.Layout the tab's layout
---@field focus_pane fun(pane: aineo.layout.Pane) shows the pane and moves the cursor into it (`aineo.entry.Tab`)
---@field show_pane fun(pane: aineo.layout.Pane) shows the pane, the cursor staying where it is
---@field is_current fun(): boolean whether the tab page of the tab is the current one

--- What one tab's run pane does, as fields.
---@class aineo.entry.RunPane
---@field run_command fun() what `:Aineo pane run` does
---@field run_shell fun() what `:Aineo run shell` does
---@field start_in_stack fun(command: string, options: { name: string, directory: string? }): integer what a run tool's call does: starts `command` at the bottom of the stack and leaves the pane as it is
---@field watch fun(group_name: string) keeps the pane in step with the processes

--- What a process of the run pane is started with: the folder aineo started
--- in, whatever `:cd` or `:tcd` says later, the variable that marks aineo's
--- own terminals, and the user's `'shell'`. Raises `FOLDER_GONE` when the
--- folder is no more.
---
---@return aineo.run.Settings
local function process_settings()
  local folder = places.kept_places().working_directory
  if vim.fn.isdirectory(folder) == 0 then
    error(FOLDER_GONE:format(folder), 0)
  end
  local shell = require('aineo.shell')
  return { cwd = folder, env = shell.child_environment(), shell = shell.shell_command() }
end

--- The window of the current tab page that shows `buffer`, or `nil`.
---
---@param buffer integer
---@return integer|nil window
local function window_showing(buffer)
  local page = vim.api.nvim_get_current_tabpage()
  return vim.iter(vim.fn.win_findbuf(buffer)):find(function(window)
    return vim.api.nvim_win_get_tabpage(window) == page
  end)
end

--- Moves the cursor to the window that shows `buffer` in the current tab
--- page, if there is one.
---
---@param buffer integer
local function enter_window_of(buffer)
  local window = window_showing(buffer)
  if window then
    vim.api.nvim_set_current_win(window)
  end
end

--- Makes the actions of the run pane for `tab`.
---
---@param tab aineo.entry.RunPaneTab
---@return aineo.entry.RunPane
function M.make(tab)
  --- Whether the cursor is in a window of the run pane's stack.
  ---
  ---@return boolean
  local function is_cursor_in_stack()
    return tab.layout.shown_pane() == 'run'
      and vim.list_contains(tab.run.buffers(), vim.api.nvim_get_current_buf())
  end

  --- Shows the run pane and puts the cursor in the window of the process
  --- `buffer` just started. A pane that cannot be shown (Claude Code cannot
  --- start in the layout it must open) raises its error, and the process is
  --- stopped, so that none runs that nothing shows.
  ---
  ---@param buffer integer
  local function show_started(buffer)
    local shown, failure = pcall(tab.focus_pane, 'run')
    if not shown then
      tab.run.stop(buffer)
      error(failure, 0)
    end
    enter_window_of(buffer)
  end

  --- Starts a process with `start`, given the settings of one
  --- (`process_settings()`), and shows it (`show_started()`). The quit of the
  --- editor is guarded from the first process on (`aineo.entry.quitting`),
  --- once showing it has opened the layout and Claude Code has registered its
  --- own stop, so that the handler of the processes comes after it.
  ---
  ---@param start fun(settings: aineo.run.Settings): integer
  local function start_and_show(start)
    show_started(start(process_settings()))
    quitting.guard()
  end

  --- What `:Aineo pane run` does. With processes running and the cursor
  --- elsewhere than in the stack, shows the pane and moves the cursor to the
  --- bottom window. Otherwise asks for a command (`vim.ui.input()`, completing
  --- shell commands) and starts it in the project folder, an empty answer or
  --- Esc starting nothing; the new process's window, at the bottom, takes the
  --- cursor in Normal mode. With the cursor in the stack, the windows the user
  --- closed come back before the question. An error starting it is told once.
  local function run_command()
    local buffers = tab.run.buffers()
    if #buffers > 0 and not is_cursor_in_stack() then
      tab.focus_pane('run')
      enter_window_of(buffers[#buffers])
      return
    end
    if #buffers > 0 then
      tab.show_pane('run')
    end
    vim.ui.input({ prompt = PROMPT, completion = 'shellcmd' }, function(command)
      if command == nil or vim.trim(command) == '' then
        return
      end
      errors.run(function()
        start_and_show(function(settings)
          return tab.run.start_command(vim.trim(command), settings)
        end)
      end)
    end)
  end

  --- Shows the stack again, the cursor staying where it is, when the run pane
  --- is shown in the tab page the user is in, so that it lists the process
  --- just started; tells the user once an error showing it raises. A pane not
  --- shown, or shown in another tab page, is left as it is.
  local function refresh_shown_stack()
    if tab.layout.shown_pane() ~= 'run' or not tab.is_current() then
      return
    end
    errors.run(function()
      tab.show_pane('run')
    end)
  end

  --- Starts `command` in the project folder, or in `options.directory`, named
  --- `options.name`, at the bottom of the stack, as a call of a run tool asks
  --- (`aineo.entry.run_tools`): the pane is not brought into view and the
  --- cursor stays where it is, but a stack that is shown lists the process
  --- (`refresh_shown_stack()`). The quit of the editor is guarded from the
  --- first process on (`aineo.entry.quitting`). Returns the process's
  --- terminal; raises the error that kept it from starting, and then nothing
  --- runs.
  ---
  ---@param command string
  ---@param options { name: string, directory: string? }
  ---@return integer buffer
  local function start_in_stack(command, options)
    local settings = process_settings()
    settings.name = options.name
    settings.cwd = options.directory or settings.cwd
    local buffer = tab.run.start_command(command, settings)
    quitting.guard()
    refresh_shown_stack()
    return buffer
  end

  --- What `:Aineo run shell` does: starts an interactive shell in the project
  --- folder at the bottom of the stack, shows the pane, and puts the cursor in
  --- the shell, in Terminal mode.
  local function run_shell()
    start_and_show(tab.run.start_shell)
    vim.cmd.startinsert()
  end

  --- Shows the pane again as the processes changed under it: the agent pane
  --- once none is left, else the stack without the process that left. Does
  --- nothing unless the run pane is shown in the tab page the user is in, and
  --- tells the user once an error showing it raises.
  local function follow_processes()
    if tab.layout.shown_pane() ~= 'run' or not tab.is_current() then
      return
    end
    errors.run(function()
      tab.show_pane(#tab.run.buffers() == 0 and 'agent' or 'run')
    end)
  end

  --- Has the process of a window the user closes taken out of the stack once
  --- that closing is done, when it ended: it keeps its window and its output
  --- until then. A process that runs stays, hidden, for the next `:Aineo pane
  --- run`. A window the layout closes as another pane shows is no closing by
  --- the user: the layout notes the other pane first.
  ---
  ---@param event { match: string }
  local function discard_ended_in_closed_window(event)
    local window = tonumber(event.match)
    if tab.layout.shown_pane() ~= 'run' or not window or not vim.api.nvim_win_is_valid(window) then
      return
    end
    local buffer = vim.api.nvim_win_get_buf(window)
    vim.schedule(function()
      tab.run.discard_ended(buffer)
    end)
  end

  --- Has the pane follow the processes (`follow_processes()`) and the
  --- windows the user closes (`discard_ended_in_closed_window()`), with the
  --- handlers of the autocommand group `group_name`.
  ---
  ---@param group_name string
  local function watch(group_name)
    tab.run.watch_leaving(follow_processes)
    vim.api.nvim_create_autocmd('WinClosed', {
      group = vim.api.nvim_create_augroup(group_name, {}),
      callback = discard_ended_in_closed_window,
    })
  end

  return {
    run_command = run_command,
    run_shell = run_shell,
    start_in_stack = start_in_stack,
    watch = watch,
  }
end

return M
