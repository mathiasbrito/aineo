local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- What `:Aineo office` tells the user when no aineo tab exists.
local NO_TAB = 'aineo: there is no aineo tab to show the office in'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `office-`
---@param settings? table more of `vim.g.aineo`
local function open_layout(name, settings)
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Writes `lines` as the transcript of the session the child's Claude Code
--- follows, where Claude Code keeps it: `projects/<folder>/<session id>.jsonl`
--- under its configuration directory.
---
---@param lines string[]
local function write_transcript(lines)
  local session = child.lua_get([[require('aineo.claude').session_id()]])
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  local path = vim.fs.joinpath(directory, 'projects', 'office-test', session .. '.jsonl')
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  fake_transcript.append(path, lines)
end

--- The area the layout gives the right column in the child.
---
---@return table
local function right_column_area()
  return child.lua_get([[require('aineo.layout').right_column_area()]])
end

--- The recorded turn, whose first five lines end with a call that runs.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- Each way to ask for the office, as a set's `parametrize`: its name, and
--- the function that asks.
local DOORS = {
  {
    'the command :Aineo office',
    function()
      entry.command(child, 'Aineo office')
    end,
  },
  {
    'pressing <Plug>(aineo-office)',
    function()
      entry.press(child, '<Plug>(aineo-office)')
    end,
  },
  {
    'pressing \\O',
    function()
      entry.press(child, '\\O')
    end,
  },
}

T['showing the office'] = MiniTest.new_set({ parametrize = DOORS })

T['showing the office']['opens a window over exactly the cells of the right column'] = function(
  _,
  ask
)
  open_layout('office-covers')
  local area = right_column_area()

  ask()

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_cells.window(child) })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
end

T['showing the office']['leaves the cursor in the window it was in'] = function(_, ask)
  open_layout('office-cursor')
  local before = child.lua_get([[vim.api.nvim_get_current_win()]])

  ask()

  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), before)
end

T['showing the office']['opens it once however many times it is asked for'] = function(_, ask)
  open_layout('office-once')

  ask()
  ask()

  eq(
    child.lua_get([[#vim.iter(vim.api.nvim_list_wins()):filter(function(window)
      return vim.api.nvim_win_get_config(window).relative ~= ''
    end):totable()]]),
    1
  )
end

T['what the office shows'] = MiniTest.new_set()

T['what the office shows']['has the main agent sit and type while the session’s transcript holds a call that runs'] = function()
  open_layout('office-typing')
  write_transcript(vim.list_slice(RECORDED_TURN, 1, 5))

  entry.command(child, 'Aineo office')

  eq(office_cells.is_typing(child), true)
end

T['what the office shows']['has the main agent stand when the session’s transcript holds a turn that ended'] = function()
  open_layout('office-ended')
  write_transcript(RECORDED_TURN)

  entry.command(child, 'Aineo office')

  eq(office_cells.is_standing(child), true)
  eq(office_cells.is_typing(child), false)
end

T['what the office shows']['has the main agent stand when the session has no transcript yet'] = function()
  open_layout('office-none')

  entry.command(child, 'Aineo office')

  eq(office_cells.is_standing(child), true)
  eq(entry.messages(child), {})
end

T['what the office shows']['follows no transcript a session id with a path in it would name'] = function()
  open_layout('office-traversal')
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  vim.fn.mkdir(vim.fs.joinpath(directory, 'projects', 'office-test'), 'p')
  fake_transcript.append(
    vim.fs.joinpath(directory, 'projects', 'escape.jsonl'),
    vim.list_slice(RECORDED_TURN, 1, 5)
  )

  child.lua([[
    local tab = {
      homes = { layout = { right_column_area = require('aineo.layout').right_column_area } },
      session_id = function()
        return '../escape'
      end,
    }
    require('aineo.entry.office').show(tab)
  ]])

  eq(office_cells.is_standing(child), true)
end

--- The Lua that makes the child note, as `_G.tracker_options`, the options
--- the office makes its tracker with.
local NOTE_THE_TRACKER_OPTIONS = [[
  local office_states = require('aineo.office_states')
  local new_tracker = office_states.new_tracker
  office_states.new_tracker = function(options)
    _G.tracker_options = options
    return new_tracker(options)
  end
]]

T['what the office is told'] = MiniTest.new_set()

T['what the office is told']['gives its tracker the classes of commands of office.commands'] = function()
  open_layout('office-commands', { office = { commands = { tests = { 'just check' } } } })
  child.lua(NOTE_THE_TRACKER_OPTIONS)

  entry.command(child, 'Aineo office')

  eq(child.lua_get([[_G.tracker_options.commands]]), { tests = { 'just check' } })
end

T['what the office is told']['gives its tracker the default classes of commands when none is set'] = function()
  open_layout('office-default-commands')
  child.lua(NOTE_THE_TRACKER_OPTIONS)

  entry.command(child, 'Aineo office')

  eq(
    child.lua_get([[(_G.tracker_options.commands or {}).committing]]),
    { 'git commit', 'git push', 'gh pr create' }
  )
end

T['what the office is told']['gives its tracker the classes of commands that setup() was given'] = function()
  open_layout('office-setup-commands')
  child.lua([[require('aineo').setup({ office = { commands = { tests = { 'just check' } } } })]])
  child.lua(NOTE_THE_TRACKER_OPTIONS)

  entry.command(child, 'Aineo office')

  eq(child.lua_get([[_G.tracker_options.commands]]), { tests = { 'just check' } })
end

T['what the office is told']["gives its tracker the name of aineo's report tool"] = function()
  open_layout('office-report-tool')
  child.lua(NOTE_THE_TRACKER_OPTIONS)

  entry.command(child, 'Aineo office')

  eq(child.lua_get([[_G.tracker_options.report_tool]]), 'mcp__aineo__report')
end

T['without an aineo tab'] = MiniTest.new_set()

T['without an aineo tab']['says there is no tab to show the office in, and shows none'] = function()
  entry.command(child, 'Aineo office')

  eq(entry.messages(child), { { message = NO_TAB, level = vim.log.levels.WARN } })
  eq(office_cells.window(child), vim.NIL)
end

return T
