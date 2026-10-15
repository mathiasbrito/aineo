--- aineo's shell home, `require('aineo.shell')`: the terminal that runs the
--- user's `'shell'` beside Claude Code's, one concern — starting it, keeping
--- track of it, and wiping or stopping it.
---
--- The module is one copy of the home, the first tab's; `M.new()` gives
--- another, each tab's own.

---@class aineo.shell.Settings
---@field cwd string the existing directory, one the editor can enter, the shell starts in

--- The functions of a shell home, as the module and `M.new()` give them.
---@class aineo.shell.Home
---@field start fun(settings: aineo.shell.Settings): integer
---@field shell_buffer fun(): integer|nil
---@field stop fun()
---@field let_go? fun() only on a copy `M.new()` made: stops the shell and removes the copy's handlers

--- The variables the shell's process gets on top of the editor's own, which it
--- inherits unchanged: `AINEO_CHILD` tells aineo, should the shell start a
--- Neovim, that it runs inside aineo's own terminal.
local CHILD_ENVIRONMENT = { AINEO_CHILD = '1' }

--- The words of `'shell'`, split as Neovim splits them to run `:terminal`
--- without an argument: at spaces and tabs, a double quote opening and closing
--- a stretch that keeps its spaces, the quotes themselves dropped, and inside
--- one a backslash before a double quote or a backslash standing for that
--- character.
---
---@return string[] words
local function shell_words()
  local words, word, quoted = {}, nil, false
  local text = vim.o.shell
  local index = 1
  while index <= #text do
    local character = text:sub(index, index)
    if character == '"' then
      quoted = not quoted
      word = word or ''
    elseif quoted and character == '\\' and text:sub(index + 1, index + 1):match('["\\]') then
      index = index + 1
      word = (word or '') .. text:sub(index, index)
    elseif (character == ' ' or character == '\t') and not quoted then
      if word then
        table.insert(words, word)
        word = nil
      end
    else
      word = (word or '') .. character
    end
    index = index + 1
  end
  if word then
    table.insert(words, word)
  end
  return words
end

--- Whether `value` is the path of an existing directory the editor can enter,
--- which a shell started in it needs.
---
---@param value any
---@return boolean
local function is_directory_to_enter(value)
  return type(value) == 'string'
    and vim.fn.isdirectory(value) == 1
    and vim.uv.fs_access(value, 'X') == true
end

--- Raises an error naming the first of `settings` the home cannot start a
--- shell with.
---
---@param settings any
local function validate_settings(settings)
  vim.validate('settings', settings, 'table')
  vim.validate(
    'settings.cwd',
    settings.cwd,
    is_directory_to_enter,
    false,
    'an existing directory it can enter'
  )
end

--- Raises an error naming `'shell'` and `program` when `program` is not
--- executable (`executable()`), the check `jobstart()` makes before it runs
--- a command, worded so that the user finds the option that names it.
---
---@param program string the first word of `'shell'`
local function ensure_executable(program)
  if vim.fn.executable(program) == 0 then
    error(("'shell': '%s' is not executable"):format(program), 0)
  end
end

--- Makes a shell home: its state, and the functions that act on it.
---
---@param group_name string the autocommand group of the home's handlers
---@return aineo.shell.Home home
local function make_shell(group_name)
  local home = {}
  vim.api.nvim_create_augroup(group_name, { clear = false })

  --- The home's shell: its terminal buffer, while it has one.
  ---@type { buffer: integer }|nil
  local shell

  --- Forgets the home's shell when it is the one whose terminal is `buffer`.
  ---
  ---@param buffer integer
  local function forget(buffer)
    if shell and shell.buffer == buffer then
      shell = nil
    end
  end

  --- Wipes `buffer` once the commands and autocommands that told of the end
  --- of its shell are done, so that a handler of another home that reacts to
  --- the end runs first; does nothing when it is wiped already, as Neovim's
  --- own handler wipes the terminal of a shell that exited with status 0.
  ---
  ---@param buffer integer
  local function wipe_later(buffer)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end)
  end

  --- Watches the terminal `buffer` for the end of its shell.
  ---
  ---@param buffer integer
  local function watch(buffer)
    vim.api.nvim_create_autocmd('TermClose', {
      group = group_name,
      buffer = buffer,
      once = true,
      callback = function()
        forget(buffer)
        wipe_later(buffer)
      end,
    })
  end

  --- Forgets the home's shell when its buffer was wiped where none of the
  --- home's handlers saw it: by a command run in an autocommand that is not
  --- nested, such as a user's `TermClose` handler that deletes the terminal,
  --- runs no autocommand, and takes a buffer's own handlers with it.
  local function forget_wiped_shell()
    if shell and not vim.api.nvim_buf_is_valid(shell.buffer) then
      shell = nil
    end
  end

  --- Starts the home's shell and returns its terminal buffer: `'shell'`, as
  --- `:terminal` runs it without an argument, in `settings.cwd`, with the
  --- editor's own environment and `AINEO_CHILD=1` added. The buffer is
  --- unlisted and stays loaded while hidden, whatever the user's `'hidden'`,
  --- and is shown in no window: the caller shows it. While the home's shell
  --- lives, returns its buffer and starts nothing.
  ---
  --- When the shell's process ends, whatever its status, the home forgets it
  --- and wipes its buffer once the autocommands of that end are done; a
  --- buffer wiped sooner — by Neovim's own handler when a shell run as
  --- `'shell'` alone exits with status 0, by `:bdelete!` or `:bwipeout!`, or
  --- by a command in an autocommand that is not nested, which no handler of
  --- the home's sees — is forgotten by the next `shell_buffer()` or `start()`.
  ---
  --- Raises an error naming the setting when `settings` is not a table or
  --- `settings.cwd` is not an existing directory the editor can enter, and one naming `'shell'`
  --- and the program when that program is not executable; it then starts
  --- nothing.
  ---
  ---@param settings aineo.shell.Settings
  ---@return integer buffer
  function home.start(settings)
    validate_settings(settings)
    forget_wiped_shell()
    if shell then
      return shell.buffer
    end
    local words = shell_words()
    ensure_executable(words[1] or '')
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(buffer, function()
      vim.fn.jobstart(words, { term = true, cwd = settings.cwd, env = CHILD_ENVIRONMENT })
    end)
    shell = { buffer = buffer }
    watch(buffer)
    return buffer
  end

  --- The home's shell buffer while its shell lives, `nil` before one started
  --- and once it ended or its buffer was wiped.
  ---
  ---@return integer|nil buffer
  function home.shell_buffer()
    forget_wiped_shell()
    return shell and shell.buffer
  end

  --- Stops the home's shell and wipes its buffer at once, as a tab page's
  --- close must. The process is stopped first, so that a wipe Neovim refuses
  --- (inside an expression mapping, say) leaves no shell running that nothing
  --- owns: the handlers then wipe the buffer once the process has ended. Does
  --- nothing without a shell.
  function home.stop()
    if not shell then
      return
    end
    local stopped = shell
    shell = nil
    if vim.api.nvim_buf_is_valid(stopped.buffer) then
      vim.fn.jobstop(vim.bo[stopped.buffer].channel)
      vim.api.nvim_buf_delete(stopped.buffer, { force = true })
    end
  end

  return home
end

local M = make_shell('aineo.shell')

--- The number of homes made, the module's included.
local homes_made = 1

--- Whether the autocommand group `name` exists.
---
---@param name string
---@return boolean
local function has_group(name)
  return (pcall(vim.api.nvim_get_autocmds, { group = name }))
end

--- A shell home of its own, whose shell and handlers are its own, apart from
--- the module's and from every home made before; its functions are fields,
--- as the module's own are. Its handlers are in the group `aineo.shell.<n>`,
--- `<n>` being the next number after those the homes made since the module
--- loaded took, and one whose group does not exist yet.
---
--- The home has a `let_go()` of its own, which the module lacks: it stops the
--- home's shell (`stop()`) and removes its handlers, for when its tab page
--- has closed.
---
---@return aineo.shell.Home home
function M.new()
  repeat
    homes_made = homes_made + 1
  until not has_group(('aineo.shell.%d'):format(homes_made))
  local group_name = ('aineo.shell.%d'):format(homes_made)
  local home = make_shell(group_name)
  home.let_go = function()
    home.stop()
    pcall(vim.api.nvim_del_augroup_by_name, group_name)
  end
  return home
end

return M
