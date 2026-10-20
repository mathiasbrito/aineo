--- What aineo does for a tab with a call of a run tool its Claude Code made:
--- starts a command at the bottom of the tab's run stack, without showing the
--- pane, reads what a process printed, or stops a process
--- (`aineo.mcp.run_tools`).

local M = {}

--- How long the list of the repository's worktrees is waited for, in
--- milliseconds.
local WORKTREES_WAIT_MS = 5000

--- What a call is answered with: the words for the agent, and whether they
--- are an error.
---@class aineo.entry.RunToolAnswer
---@field text string
---@field is_error boolean

--- What a call needs of the tab it is made for.
---@class aineo.entry.RunToolsTab
---@field homes { run: aineo.run.Home } the tab's run home
---@field start_in_run_stack fun(command: string, options: { name: string, directory: string? }): integer starts the command at the bottom of the tab's run stack, shows the run pane when the tab page is the current one, the cursor staying where it is, and returns its terminal; raises the error that kept it from starting

--- What a call needs of the editor.
---@class aineo.entry.RunToolsContext
---@field folder string the folder aineo started in, the project folder
---@field tell fun(message: string) tells the user `message`
---@field worktree_folders? fun(folder: string): string[] the top levels of the worktrees of the repository `folder` is in, `worktree_folders()` when not given

--- The words for the agent that tell what was done, and are no error.
---
---@param text string
---@return aineo.entry.RunToolAnswer
local function done(text)
  return { text = text, is_error = false }
end

--- The words for the agent that tell why nothing was done, an error.
---
---@param text string
---@return aineo.entry.RunToolAnswer
local function failed(text)
  return { text = text, is_error = true }
end

--- The top levels of the worktrees of the repository `folder` is in, the
--- one `folder` is in first, as git lists them; none when `folder` is in no
--- repository or git does not answer within `WORKTREES_WAIT_MS`.
---
---@param folder string
---@return string[]
local function worktree_folders(folder)
  local git = require('aineo.git')
  local folders, finished = {}, false
  git.find_repository(folder, function(find_failure, found)
    if find_failure then
      finished = true
      return
    end
    git.list_worktrees(found, function(list_failure, worktrees)
      if not list_failure then
        folders = vim.tbl_map(function(worktree)
          return worktree.top
        end, worktrees)
      end
      finished = true
    end)
  end)
  vim.wait(WORKTREES_WAIT_MS, function()
    return finished
  end, 10)
  return folders
end

--- `directory` as a path with every link resolved, taken from `folder` when
--- it is relative; nil when it is no existing directory. A `~` or a
--- variable in it is not expanded.
---
---@param directory string
---@param folder string
---@return string?
local function existing_directory(directory, folder)
  local path = vim.startswith(directory, '/') and directory or vim.fs.joinpath(folder, directory)
  local resolved = vim.uv.fs_realpath(path)
  return resolved and vim.fn.isdirectory(resolved) == 1 and resolved or nil
end

--- The directories a process may be started in: the project folder, then the
--- other worktrees of its repository, each with every link resolved.
---
---@param context aineo.entry.RunToolsContext
---@return string[]
local function allowed_directories(context)
  local folder = vim.uv.fs_realpath(context.folder) or context.folder
  local allowed = { folder }
  for _, top in ipairs((context.worktree_folders or worktree_folders)(folder)) do
    local resolved = vim.uv.fs_realpath(top)
    if resolved and not vim.list_contains(allowed, resolved) then
      table.insert(allowed, resolved)
    end
  end
  return allowed
end

--- The directory a call asks to start in, with every link resolved, or nil
--- and why not: it is no existing directory, or it is neither the project
--- folder nor a worktree of its repository.
---
---@param directory string
---@param context aineo.entry.RunToolsContext
---@return string? resolved
---@return string? refusal
local function directory_to_start_in(directory, context)
  local resolved = existing_directory(directory, context.folder)
  if not resolved then
    return nil, ('directory "%s" is not an existing directory'):format(directory)
  end
  local allowed = allowed_directories(context)
  if not vim.list_contains(allowed, resolved) then
    return nil,
      ('directory "%s" is neither the project folder nor a worktree of its repository (allowed: %s)'):format(
        directory,
        table.concat(allowed, ', ')
      )
  end
  return resolved
end

--- `wanted`, or, when `taken` holds it, `wanted-2`, `wanted-3` and so on:
--- the first of them that `taken` does not hold.
---
---@param wanted string
---@param taken string[]
---@return string
local function unused_name(wanted, taken)
  local name, number = wanted, 1
  while vim.list_contains(taken, name) do
    number = number + 1
    name = ('%s-%d'):format(wanted, number)
  end
  return name
end

--- The names of the processes of the tab's stack, the oldest first.
---
---@param tab aineo.entry.RunToolsTab
---@return string[]
local function names_in_stack(tab)
  return vim.tbl_map(function(entry)
    return entry.name
  end, tab.homes.run.entries())
end

--- The name a command is given when the call gives none: its first word
--- without the control characters it holds, `command` when nothing is left.
---
---@param command string
---@return string
local function first_word_of(command)
  local word = (command:match('%S+') or ''):gsub('%c', '')
  return word ~= '' and word or 'command'
end

--- Starts the command a `run` call gives at the bottom of the tab's run
--- stack (`aineo.entry.Tab`'s `start_in_run_stack()`), named as the call
--- says, else by the command's first word, a name the stack holds already
--- made unused (`unused_name()`), in the project folder or the directory the
--- call gives; tells the user once. Answers at once; the run pane is shown when
--- the tab page is the one the user is in, the cursor staying where it is.
--- An error that keeps it from starting, or a directory not allowed, is
--- answered as a refusal that says why.
---
---@param tab aineo.entry.RunToolsTab
---@param arguments { command: string, name?: string, directory?: string }
---@param context aineo.entry.RunToolsContext
---@return aineo.entry.RunToolAnswer
local function run(tab, arguments, context)
  local directory
  if arguments.directory then
    local refusal
    directory, refusal = directory_to_start_in(arguments.directory, context)
    if not directory then
      return failed('refused: ' .. refusal)
    end
  end
  local wanted = arguments.name or first_word_of(arguments.command)
  local name = unused_name(wanted, names_in_stack(tab))
  local started, failure =
    pcall(tab.start_in_run_stack, arguments.command, { name = name, directory = directory })
  if not started then
    return failed('refused: ' .. tostring(failure):match('^[^\n]*'))
  end
  context.tell(('aineo: started %s in the run pane'):format(name))
  return done(
    ('Started "%s" in the run pane, which aineo brings into view when the user is in its tab page, the cursor staying where it is.'):format(
      name
    ) .. (' Read what it prints with run_output, name "%s".'):format(name)
  )
end

--- `count` and `noun`, the noun in the plural unless `count` is 1.
---
---@param count integer
---@param noun string
---@return string
local function counted(count, noun)
  return ('%d %s%s'):format(count, noun, count == 1 and '' or 's')
end

--- The process of the tab's stack called `name`, or nil and the words for the
--- agent that say why there is none to `verb` (`read`, `stopped`): no
--- process has the name, which the words answer with the names there are, or
--- several do.
---
---@param tab aineo.entry.RunToolsTab
---@param name string
---@param verb string
---@return aineo.run.Entry? entry
---@return aineo.entry.RunToolAnswer? refusal
local function process_called(tab, name, verb)
  local called = vim.tbl_filter(function(entry)
    return entry.name == name
  end, tab.homes.run.entries())
  if #called == 1 then
    return called[1]
  end
  if #called > 1 then
    return nil,
      failed(
        ('%d processes are called "%s" in the run pane; none was %s'):format(#called, name, verb)
      )
  end
  local names = names_in_stack(tab)
  return nil,
    failed(
      ('no process called "%s" in the run pane (processes: %s)'):format(
        name,
        #names > 0 and table.concat(names, ', ') or 'none'
      )
    )
end

--- The words for the agent that give what a read of the output of the
--- process `name` found: a header with the state and the number of lines in
--- all, which is what `after_line` follows from; how many earlier matching
--- lines were left out; then each line read, its number and a colon for a
--- line that matches or a dash for one that only lies around a match, a
--- `--` between lines that do not follow one another. When `after_line` is
--- past the last line, the rows were renumbered, and the words say so.
---
---@param name string
---@param output aineo.run.Output
---@param after_line integer? the `after_line` the read was asked with
---@return string
local function describe_output(name, output, after_line)
  local described = {
    ('%s: %s; %s in total'):format(name, output.state, counted(output.total, 'line')),
  }
  if after_line and after_line > output.total then
    table.insert(
      described,
      ("(after_line %d is past the last line, %d: the rows were renumbered, by a resize of the pane or by 'scrollback'; read again without after_line)"):format(
        after_line,
        output.total
      )
    )
  end
  if output.omitted > 0 then
    table.insert(
      described,
      ('(%s left out)'):format(counted(output.omitted, 'earlier matching line'))
    )
  end
  if #output.lines == 0 then
    table.insert(described, '(no matching lines)')
  end
  local previous
  for _, line in ipairs(output.lines) do
    if previous and line.number ~= previous + 1 then
      table.insert(described, '--')
    end
    table.insert(
      described,
      ('%d%s %s'):format(line.number, line.is_match and ':' or '-', line.text)
    )
    previous = line.number
  end
  return table.concat(described, '\n')
end

--- Reads the output of the process a `run_output` call names, as the call
--- asks (`aineo.run`'s `read_output()`), and answers with what it found
--- (`describe_output()`); a name no process, or several, have, and a pattern
--- or exclusion that is no regex, are answered as errors saying why.
---
---@param tab aineo.entry.RunToolsTab
---@param arguments table the call's arguments
---@return aineo.entry.RunToolAnswer
local function run_output(tab, arguments)
  local entry, refusal = process_called(tab, arguments.name, 'read')
  if not entry then
    return refusal
  end
  if entry.is_interactive_shell then
    return failed(
      ('"%s" is an interactive shell; its screen is not read, as it may hold what you typed'):format(
        entry.name
      )
    )
  end
  local output, failure = tab.homes.run.read_output(entry.buffer, arguments)
  if not output then
    return failed(failure)
  end
  return done(describe_output(entry.name, output, arguments.after_line))
end

--- Stops the process a `run_stop` call names as closing its terminal does
--- (`aineo.run`'s `stop()`): its process group and what its shell started.
--- A name no process, or several, have is answered as an error saying why,
--- and stops nothing.
---
---@param tab aineo.entry.RunToolsTab
---@param arguments { name: string }
---@return aineo.entry.RunToolAnswer
local function run_stop(tab, arguments)
  local entry, refusal = process_called(tab, arguments.name, 'stopped')
  if not entry then
    return refusal
  end
  tab.homes.run.stop(entry.buffer)
  return done(('Stopped "%s".'):format(entry.name))
end

--- What each run tool does for a tab, by the tool.
---@type table<string, fun(tab: aineo.entry.RunToolsTab, arguments: table, context: aineo.entry.RunToolsContext): aineo.entry.RunToolAnswer>
local HANDLERS = { run = run, run_output = run_output, run_stop = run_stop }

--- Does for `tab` what the call `run_call` of a run tool asks
--- (`aineo.mcp.run_tools`), and answers with the words for the agent and
--- whether they are an error.
---
---@param tab aineo.entry.RunToolsTab
---@param run_call aineo.mcp.RunCall
---@param context aineo.entry.RunToolsContext
---@return aineo.entry.RunToolAnswer
function M.call(tab, run_call, context)
  return HANDLERS[run_call.tool](tab, run_call.arguments, context)
end

return M
