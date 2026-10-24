local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local pack_files = dofile('tests/helpers/office_pack_files.lua')

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
      child.o.termguicolors = true
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

--- Removes the transcripts earlier cases wrote under the child's Claude
--- configuration directory: the fake Claude Code names its session the same
--- in every case, so an earlier case's file is this session's.
local function forget_earlier_transcripts()
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  vim.fn.delete(vim.fs.joinpath(directory, 'projects'), 'rf')
end

--- Writes `lines` as the transcript of the session the child's Claude Code
--- follows, in the folder Claude Code names after the working directory the
--- session runs in: every character of its path but a letter or a digit
--- becomes a dash.
---
---@param lines string[]
local function write_transcript_in_the_sessions_own_folder(lines)
  local session = child.lua_get([[require('aineo.claude').session_id()]])
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  local working_directory = child.lua_get([[vim.fn.getcwd()]])
  local folder = working_directory:gsub('[^%w]', '-')
  fake_transcript.append(vim.fs.joinpath(directory, 'projects', folder, session .. '.jsonl'), lines)
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

T['what the office shows']['has the main agent search the file cabinet while the session’s transcript holds a search that runs'] = function()
  open_layout('office-searching')
  write_transcript(vim.list_slice(RECORDED_TURN, 1, 5))

  entry.command(child, 'Aineo office')

  local searching = vim.wait(5000, function()
    return office_cells.is_at(child, 'file_cabinet')
  end, 50)
  eq(searching, true)
end

T['what the office shows']['has the main agent rest on the sofa when the session’s transcript holds a turn that ended'] = function()
  open_layout('office-ended')
  write_transcript(RECORDED_TURN)

  entry.command(child, 'Aineo office')

  eq(office_cells.is_on_the_sofa(child), true)
  eq(office_cells.is_typing(child), false)
end

T['what the office shows']['has the main agent rest on the sofa when the session has no transcript yet'] = function()
  open_layout('office-none')

  entry.command(child, 'Aineo office')

  eq(office_cells.is_on_the_sofa(child), true)
  eq(entry.messages(child), {})
end

T['what the office shows']['has the main agent type once the session writes its transcript after the office showed'] = function()
  open_layout('office-late')
  forget_earlier_transcripts()
  entry.command(child, 'Aineo office')
  eq(office_cells.is_standing(child), true)

  write_transcript_in_the_sessions_own_folder(vim.list_slice(RECORDED_TURN, 1, 5))

  local typing = vim.wait(5000, function()
    return office_cells.is_typing(child)
  end, 50)
  eq(typing, true)
end

--- Makes a named pipe named as the transcript of the child's session in the
--- folder `any-folder` of its projects, which a process opens for writing a
--- second from now: an open of it for reading, which blocks until then, ends
--- by itself. The process opens the pipe for reading and writing, which does
--- not wait for a reader, so that it ends by itself when nobody reads the pipe.
---
---@return vim.SystemObj opener
local function make_pipe_named_as_the_transcript()
  local session = child.lua_get([[require('aineo.claude').session_id()]])
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  local path = vim.fs.joinpath(directory, 'projects', 'any-folder', session .. '.jsonl')
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.system({ 'mkfifo', path }):wait()
  return vim.system({ 'sh', '-c', 'sleep 1; exec 3<> "$0"', path })
end

T['what the office shows']['is shown at once though a named pipe is named as the transcript'] = function()
  open_layout('office-pipe')
  forget_earlier_transcripts()
  local opener = make_pipe_named_as_the_transcript()

  local started = vim.uv.hrtime()
  entry.command(child, 'Aineo office')
  local held = math.floor((vim.uv.hrtime() - started) / 1e6)

  eq(held < 500, true)
  eq(opener:wait(3000).code, 0)
end

T['what the office shows']["follows the transcript in the session's own folder, not a named pipe named as it elsewhere"] = function()
  open_layout('office-pipe-shadow')
  forget_earlier_transcripts()
  make_pipe_named_as_the_transcript()
  entry.command(child, 'Aineo office')

  write_transcript_in_the_sessions_own_folder(vim.list_slice(RECORDED_TURN, 1, 5))

  local typing = vim.wait(5000, function()
    return office_cells.is_typing(child)
  end, 50)
  eq(typing, true)
end

T['what the office shows']["follows the transcript of the session's id that exists, not the path the folder rule names"] = function()
  open_layout('office-existing-wins')
  forget_earlier_transcripts()
  local session = child.lua_get([[require('aineo.claude').session_id()]])
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])
  fake_transcript.append(
    vim.fs.joinpath(directory, 'projects', 'elsewhere', session .. '.jsonl'),
    RECORDED_TURN
  )
  entry.command(child, 'Aineo office')

  write_transcript_in_the_sessions_own_folder(vim.list_slice(RECORDED_TURN, 1, 5))
  vim.wait(1500)

  eq(office_cells.is_on_the_sofa(child), true)
  eq(office_cells.is_typing(child), false)
end

T['what the office shows']["names the session's folder with a dash for each character, not each byte"] = function()
  open_layout('office-folder-rule')
  forget_earlier_transcripts()
  child.lua([[require('aineo.entry.places').kept_places().working_directory = '/tmp/joão x']])
  entry.command(child, 'Aineo office')
  local session = child.lua_get([[require('aineo.claude').session_id()]])
  local directory = child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]])

  fake_transcript.append(
    vim.fs.joinpath(directory, 'projects', '-tmp-jo-o-x', session .. '.jsonl'),
    vim.list_slice(RECORDED_TURN, 1, 5)
  )

  local typing = vim.wait(5000, function()
    return office_cells.is_typing(child)
  end, 50)
  eq(typing, true)
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
      panes_session = function()
        return nil
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

--- Makes a pack `alt` with a floor of the colour `#ff0000` on the
--- 'runtimepath' of the child, as a plugin that brings one would.
local function add_the_alt_pack()
  local root = fixture.directory('office_entry_setting_pack')
  pack_files.write_pack(root, 'alt', {
    ['pack.lua'] = pack_files.pack_text({
      name = 'alt',
      colours = { wall = '#292c3c', floor = '#ff0000', ink = '#1e1e2e', wood = '#b4875a' },
    }),
  })
  child.lua([[vim.opt.runtimepath:append(...)]], { root })
  return root
end

T['the setting office.pack'] = MiniTest.new_set()

T['the setting office.pack']['names the pack the office draws, found on the runtime path'] = function()
  entry.use_fake(child, claude_session.fake('office-pack', 'ready'), { office = { pack = 'alt' } })
  add_the_alt_pack()
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')

  entry.command(child, 'Aineo office')

  eq(office_cells.shows_colour(child, 'ff0000'), true)
end

T['the setting office.pack']['draws the default pack when it is not set'] = function()
  open_layout('office-default-pack')
  add_the_alt_pack()

  entry.command(child, 'Aineo office')

  eq(office_cells.shows_colour(child, 'ff0000'), false)
end

T['the setting office.pieces'] = MiniTest.new_set()

T['the setting office.pieces']['leave the pieces of the pack alone when none is named'] = function()
  open_layout('office-pieces-none')

  entry.command(child, 'Aineo office')

  eq(office_cells.shows_colour(child, '414559'), true)
end

T['the setting office.pieces']['name art files that replace the pieces of the pack'] = function()
  local mine = vim.fs.joinpath(fixture.directory('office_entry_pieces'), 'mine.txt')
  vim.fn.writefile({ 'colours: A = ink', '---', '.', '.' }, mine)
  entry.use_fake(
    child,
    claude_session.fake('office-pieces', 'ready'),
    { office = { pieces = { baseboard = mine } } }
  )
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')

  entry.command(child, 'Aineo office')

  eq(office_cells.shows_colour(child, '414559'), false)
  eq(entry.messages(child), {})
end

T['without an aineo tab'] = MiniTest.new_set()

T['without an aineo tab']['says there is no tab to show the office in, and shows none'] = function()
  entry.command(child, 'Aineo office')

  eq(entry.messages(child), { { message = NO_TAB, level = vim.log.levels.WARN } })
  eq(office_cells.window(child), vim.NIL)
end

return T
