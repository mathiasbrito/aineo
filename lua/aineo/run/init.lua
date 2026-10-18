--- aineo's run home, `require('aineo.run')`: the services a tab runs in
--- terminals of their own, one concern — starting each one, keeping what the
--- stack needs to show of it, and stopping it with its children.
---
--- The module is one copy of the home, the first tab's; `M.new()` gives
--- another, each tab's own.

---@class aineo.run.Settings
---@field cwd string the existing directory, one the editor can enter, the process starts in
---@field env table<string, string> the variables the process gets on top of the editor's own
---@field shell string[] the program and arguments `'shell'` names, which runs a command and is the interactive shell

--- The functions of a run home, as the module and `M.new()` give them.
---@class aineo.run.Home
---@field start_command fun(command: string, settings: aineo.run.Settings): integer
---@field start_shell fun(settings: aineo.run.Settings): integer
---@field buffers fun(): integer[]
---@field running fun(): string[]
---@field stop_all fun()
---@field discard_ended fun(buffer: integer): boolean
---@field stop fun(buffer: integer)
---@field watch_leaving fun(callback: fun())
---@field let_go? fun() only on a copy `M.new()` made: stops the home's processes and removes its handlers

--- The words of `'shellcmdflag'`, the flag that makes `'shell'` run a command.
---
---@return string[] words
local function shell_command_flag()
  return vim.split(vim.o.shellcmdflag, '%s+', { trimempty = true })
end

--- What the winbar and the question at a quit call the interactive shell.
local SHELL_NAME = 'shell'

--- One process of the stack.
---@class aineo.run.Process
---@field buffer integer the terminal that shows the process
---@field name string the command the user gave, or `shell`
---@field pid integer the process id of the terminal's process, which leads a process group of its own
---@field job integer the job of the terminal's process
---@field is_group_gone boolean whether the process group has been seen empty, after which it is never signalled again: its id may belong to another process by now
---@field status integer|nil the status the process exited with, nil while it runs

--- The status `TermClose` reports for a process the editor stopped itself, as
--- it does when the terminal of a process that runs is unloaded.
local STOPPED_BY_EDITOR = -1

--- How long the processes of a stop have, in milliseconds, to end on a
--- termination signal before they are killed.
local GRACE_MS = 1500

--- How often, in milliseconds, a stop looks whether what it signalled has
--- ended.
local POLL_MS = 20

--- The process ids of everything below the process `pid`: its children, their
--- children, and so on, as the editor finds them by parentage.
---
---@param pid integer
---@return integer[] pids
local function descendants_of(pid)
  local found = {}
  for _, child in ipairs(vim.api.nvim_get_proc_children(pid)) do
    table.insert(found, child)
    vim.list_extend(found, descendants_of(child))
  end
  return found
end

--- Whether anything is left of `target`, a process group (its id negated) or a
--- process.
---
---@param target integer
---@return boolean
local function is_present(target)
  return vim.uv.kill(target, 0) == 0
end

--- Keeps what is left of `targets` (`is_present()`): a target seen gone is
--- forgotten for good, since its id may belong to another process by now.
---
---@param targets integer[]
---@return integer[] present
local function present_of(targets)
  return vim.tbl_filter(is_present, targets)
end

--- Sends the termination signal to each of `targets`.
---
---@param targets integer[]
local function ask_to_end(targets)
  for _, target in ipairs(targets) do
    vim.uv.kill(target, 'sigterm')
  end
end

--- Kills what is left of `targets` once it has had `GRACE_MS` to end on its
--- own, looking every `POLL_MS`, from timers: it stops looking at the first
--- look that finds nothing. `waited` is how long it has waited.
---
---@param targets integer[]
---@param waited integer
local function kill_what_stays(targets, waited)
  local present = present_of(targets)
  if #present == 0 then
    return
  end
  if waited >= GRACE_MS then
    for _, target in ipairs(present) do
      vim.uv.kill(target, 'sigkill')
    end
    return
  end
  vim.defer_fn(function()
    kill_what_stays(present, waited + POLL_MS)
  end, POLL_MS)
end

--- The winbar of every window that shows a process: the title the home keeps
--- for the process (`b:aineo_run_title`), which names its command and says
--- whether it runs or how it exited. A single `%{}` item, so that a `%` in a
--- command is drawn as typed.
local WINBAR = "%{get(b:, 'aineo_run_title', '')}"

--- The title of `process`: its name, and that it runs or the status it exited
--- with.
---
---@param process aineo.run.Process
---@return string
local function title_of(process)
  local state = process.status and ('exited %d'):format(process.status) or 'running'
  return ('%s — %s'):format(process.name, state)
end

--- Raises an error naming the first of `settings` the home cannot start a
--- process with.
---
---@param settings any
local function validate_settings(settings)
  vim.validate('settings', settings, 'table')
  vim.validate('settings.cwd', settings.cwd, 'string')
  vim.validate('settings.env', settings.env, 'table')
  vim.validate('settings.shell', settings.shell, 'table')
  if vim.fn.isdirectory(settings.cwd) == 0 or vim.uv.fs_access(settings.cwd, 'X') ~= true then
    error(
      ('settings.cwd: %s is not an existing directory the editor can enter'):format(settings.cwd),
      0
    )
  end
end

--- Makes a run home: its state, and the functions that act on it.
---
---@param group_name string the autocommand group of the home's handlers
---@return aineo.run.Home home
local function make_run(group_name)
  local home = {}
  vim.api.nvim_create_augroup(group_name, { clear = false })

  --- The home's processes, the oldest first.
  ---@type aineo.run.Process[]
  local processes = {}

  --- What is called when a process leaves the stack of itself
  --- (`home.watch_leaving()`).
  ---@type fun()|nil
  local on_leaving = nil

  --- Whether `home.stop_all()` is stopping the processes.
  local is_stopping_all = false

  --- Notes that `process` ended with the status of the `TermClose` that
  --- reports it, and has its terminal show it.
  ---
  ---@param process aineo.run.Process
  local function note_exit(process)
    process.status = vim.v.event.status
    if vim.api.nvim_buf_is_valid(process.buffer) then
      vim.b[process.buffer].aineo_run_title = title_of(process)
    end
  end

  --- Whether `process` is left to stop: it runs, or the editor stopped it as
  --- its terminal unloaded. A process that ended on its own is left alone:
  --- its process group may have been taken by another process since.
  ---
  ---@param process aineo.run.Process
  ---@return boolean
  local function is_to_stop(process)
    return process.status == nil or process.status == STOPPED_BY_EDITOR
  end

  --- What a stop of `process` signals, and what is left of it: the process
  --- group of the terminal's process, which leads a group of its own that
  --- holds what it started and did not move out of it (its id negated), and,
  --- while its job runs, everything below it by parentage, since a shell
  --- under job control moves its jobs to groups of their own. Once the job
  --- has ended or been freed the shell is gone, and the group is all there is
  --- to find.
  ---
  --- A group seen empty is not looked at again.
  ---
  ---@param process aineo.run.Process
  ---@return integer[] targets
  local function targets_of(process)
    local targets = process.is_group_gone and {} or { -process.pid }
    if vim.fn.jobwait({ process.job }, 0)[1] == -1 then
      vim.list_extend(targets, descendants_of(process.pid))
    end
    local present = present_of(targets)
    process.is_group_gone = process.is_group_gone or not vim.list_contains(present, -process.pid)
    return present
  end

  --- Stops what is left of `process` by a termination signal and, from timers,
  --- a kill for what has not ended within `GRACE_MS` (`kill_what_stays()`).
  ---
  ---@param process aineo.run.Process
  local function terminate(process)
    local targets = targets_of(process)
    ask_to_end(targets)
    kill_what_stays(targets, 0)
  end

  --- Takes `process` out of the home, stopping what is left of it
  --- (`is_to_stop()`, `terminate()`), and wipes its terminal and tells the
  --- watcher of the home (`home.watch_leaving()`) once the command that
  --- unloaded it is done. Done when the terminal unloads: the user's
  --- `:bdelete`, a wipe, or a process the editor wipes as it ends. Does
  --- nothing while the editor exits: Neovim unloads every buffer before
  --- `VimLeavePre`, where `stop_all()` stops what is left, with its kill.
  ---
  ---@param process aineo.run.Process
  local function leave(process)
    if vim.v.exiting ~= vim.NIL then
      return
    end
    for index, listed in ipairs(processes) do
      if listed == process then
        table.remove(processes, index)
        break
      end
    end
    if is_to_stop(process) then
      terminate(process)
    end
    local is_watched = not is_stopping_all
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(process.buffer) then
        vim.api.nvim_buf_delete(process.buffer, { force = true })
      end
      if is_watched and on_leaving then
        on_leaving()
      end
    end)
  end

  --- Starts the program whose words are `command` in a terminal buffer of
  --- its own, in `settings.cwd`, with the editor's environment and
  --- `settings.env` added, and returns the buffer.
  --- The buffer is unlisted and stays loaded while hidden, whatever the
  --- user's `'hidden'`, and is shown in no window: the caller shows it.
  ---
  --- Raises the error `jobstart()` raises when the program cannot run, which
  --- names it, and leaves no buffer.
  ---
  ---@param name string what the process is called
  ---@param command string[]
  ---@param settings aineo.run.Settings
  ---@return integer buffer
  local function start(name, command, settings)
    validate_settings(settings)
    local buffer = vim.api.nvim_create_buf(false, true)
    local job
    local started, failure = pcall(vim.api.nvim_buf_call, buffer, function()
      job = vim.fn.jobstart(command, { term = true, cwd = settings.cwd, env = settings.env })
    end)
    if not started then
      vim.api.nvim_buf_delete(buffer, { force = true })
      error(failure, 0)
    end
    local process = {
      buffer = buffer,
      name = name,
      pid = vim.fn.jobpid(job),
      job = job,
      is_group_gone = false,
    }
    table.insert(processes, process)
    vim.b[buffer].aineo_run_title = title_of(process)
    vim.api.nvim_create_autocmd('TermClose', {
      group = group_name,
      buffer = buffer,
      once = true,
      callback = function()
        note_exit(process)
        terminate(process)
      end,
    })
    vim.api.nvim_create_autocmd('BufUnload', {
      group = group_name,
      buffer = buffer,
      once = true,
      callback = function()
        leave(process)
      end,
    })
    return buffer
  end

  --- Starts `command` through `settings.shell`, with the flag that makes
  --- `'shell'` run a command (`'shellcmdflag'`), named by the command, in a
  --- terminal buffer of its own (`start()`).
  ---
  ---@param command string
  ---@param settings aineo.run.Settings
  ---@return integer buffer
  function home.start_command(command, settings)
    vim.validate('settings', settings, 'table')
    vim.validate('settings.shell', settings.shell, 'table')
    local words = vim.list_extend(vim.list_slice(settings.shell), shell_command_flag())
    return start(command, vim.list_extend(words, { command }), settings)
  end

  --- Starts an interactive shell, `settings.shell`, named `shell`, in a
  --- terminal buffer of its own (`start()`).
  ---
  ---@param settings aineo.run.Settings
  ---@return integer buffer
  function home.start_shell(settings)
    vim.validate('settings', settings, 'table')
    vim.validate('settings.shell', settings.shell, 'table')
    return start(SHELL_NAME, settings.shell, settings)
  end

  --- The terminal of every process of the home, the oldest first.
  ---
  ---@return integer[] buffers
  function home.buffers()
    return vim.tbl_map(function(process)
      return process.buffer
    end, processes)
  end

  --- The names of the processes that still run, the oldest first: the command
  --- the user gave, or `shell`.
  ---
  ---@return string[] names
  function home.running()
    return vim
      .iter(processes)
      :filter(function(process)
        return process.status == nil
      end)
      :map(function(process)
        return process.name
      end)
      :totable()
  end

  --- Wipes the terminal `buffer` and takes its process out of the home when
  --- that process has ended; does nothing for a process that runs and for a
  --- buffer that is none of the home's. What the stack does when the user
  --- closes the window of a process that ended.
  ---
  ---@param buffer integer
  ---@return boolean discarded whether `buffer` was the terminal of a process that ended
  function home.discard_ended(buffer)
    local ended = vim.iter(processes):any(function(process)
      return process.buffer == buffer and process.status ~= nil
    end)
    if ended then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
    return ended
  end

  --- Stops the process of the terminal `buffer` with its children and takes
  --- it out of the home, as the user's `:bdelete!` of the terminal does;
  --- does nothing for a buffer that is none of the home's.
  ---
  ---@param buffer integer
  function home.stop(buffer)
    if vim.iter(processes):any(function(process)
      return process.buffer == buffer
    end) then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
  end

  --- Stops every process of the home with its children: a termination signal
  --- to each process group and to what its shell started under job control
  --- (`targets_of()`), a kill to what has not ended within `GRACE_MS`; then
  --- wipes every terminal, and holds the editor until then. A process that
  --- ended on its own is not signalled (`is_to_stop()`). The watcher of
  --- `watch_leaving()` is not called.
  function home.stop_all()
    is_stopping_all = true
    local targets = {}
    for _, process in ipairs(vim.tbl_filter(is_to_stop, processes)) do
      vim.list_extend(targets, targets_of(process))
    end
    ask_to_end(targets)
    vim.wait(GRACE_MS, function()
      targets = present_of(targets)
      return #targets == 0
    end, POLL_MS)
    for _, target in ipairs(targets) do
      vim.uv.kill(target, 'sigkill')
    end
    for _, process in ipairs(vim.list_slice(processes)) do
      vim.api.nvim_buf_delete(process.buffer, { force = true })
    end
    is_stopping_all = false
  end

  --- Has `callback` called, from a scheduled callback, whenever a process
  --- leaves the stack of itself: the user deleted its terminal, or the
  --- editor wiped it as an interactive shell ended with status 0; also when
  --- `discard_ended()` wiped it, but not when `stop_all()` did. Replaces the
  --- callback given before.
  ---
  ---@param callback fun()
  function home.watch_leaving(callback)
    on_leaving = callback
  end

  return home
end

local M = make_run('aineo.run')

M.WINBAR = WINBAR

--- The number of homes made, the module's included.
local homes_made = 1

--- Whether the autocommand group `name` exists.
---
---@param name string
---@return boolean
local function has_group(name)
  return (pcall(vim.api.nvim_get_autocmds, { group = name }))
end

--- A run home of its own, whose processes and handlers are its own, apart
--- from the module's and from every home made before; its functions are
--- fields, as the module's own are. Its handlers are in the group
--- `aineo.run.<n>`, `<n>` being the next number after those the homes made
--- since the module loaded took, and one whose group does not exist yet.
---
--- The home has a `let_go()` of its own, which the module lacks: it stops the
--- home's processes (`stop_all()`) and removes its handlers, for when its tab
--- page has closed.
---
---@return aineo.run.Home home
function M.new()
  repeat
    homes_made = homes_made + 1
  until not has_group(('aineo.run.%d'):format(homes_made))
  local group_name = ('aineo.run.%d'):format(homes_made)
  local home = make_run(group_name)
  home.let_go = function()
    home.stop_all()
    pcall(vim.api.nvim_del_augroup_by_name, group_name)
  end
  return home
end

return M
