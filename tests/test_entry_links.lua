local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The child's screen width: Claude's column, half of it, is wide enough
--- for a `file://` address of a fixture on one line of the terminal.
local COLUMNS = 400

--- How many bytes at a file's start decide whether it is text.
local TEXT_SAMPLE_BYTES = 8192

--- The files of the project each case opens aineo in, path to lines, as
--- `writefile()` writes them: a line feed inside a line is written as a NUL.
--- `nul-inside.dat` holds a NUL as the last of its first `TEXT_SAMPLE_BYTES`
--- bytes, and `nul-after.txt` its first NUL just after them.
local PROJECT_FILES = {
  ['notes.txt'] = { 'one', 'two', 'three', 'four' },
  ['lua/x.lua'] = { 'return {}', 'local y = 2', 'return y' },
  ['nul-inside.dat'] = { string.rep('a', TEXT_SAMPLE_BYTES - 1) .. '\n' .. 'tail' },
  ['nul-after.txt'] = { string.rep('a', TEXT_SAMPLE_BYTES) .. '\n' .. 'tail' },
  ['a/~b.txt'] = { 'tilde inside' },
  ['~user/x.txt'] = { 'named user' },
}

--- The Lua that keeps, in the child, every target `vim.ui.open()` is given,
--- in `_G.opened_externally`, and opens none of them.
local KEEP_EXTERNAL_OPENS = [[
  _G.opened_externally = {}
  vim.ui.open = function(target)
    table.insert(_G.opened_externally, target)
    return { wait = function() end }
  end
]]

--- The Lua that counts, in the child, the answers the git home gave to the
--- looks for a repository, in `_G.finds_answered`, each once its caller's
--- `done` has run.
local COUNT_FINDS = [[
  local git = require('aineo.git')
  local find_repository = git.find_repository
  _G.finds_answered = 0
  git.find_repository = function(directory, done, options)
    return find_repository(directory, function(...)
      done(...)
      _G.finds_answered = _G.finds_answered + 1
    end, options)
  end
]]

--- Makes the repository `.tests/fixtures/git-<name>/repo` holding
--- `PROJECT_FILES` in one commit, and `outside.txt` beside it, outside it;
--- starts the child afresh with the git isolation of the git home's suites,
--- in the repository's top level, where Claude Code starts; keeps what
--- `vim.ui.open()` is given
--- (`KEEP_EXTERNAL_OPENS`); opens the layout around the fake `claude`
--- (`:Aineo open`) and waits until Claude Code is ready and the changes
--- pane's repository was looked for. Returns the repository's top level.
---
---@param name string the case's own name, starting `links-`
---@return string top
local function open_layout_in_project(name)
  local top = git_repo.create(name, PROJECT_FILES)
  git_repo.write(vim.fs.dirname(top), 'outside.txt', { 'outside' })
  entry.restart(child)
  child.o.columns = COLUMNS
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory(name .. '-state') })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.lua(COUNT_FINDS)
  child.lua(KEEP_EXTERNAL_OPENS)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  git_repo.wait_until('the repository looked for', function()
    return child.lua_get('_G.finds_answered') >= 1
  end)
  return top
end

--- How long a test waits for what a click or a key does: typed keys run when
--- the child reads its input, and the file column is arranged from a
--- scheduled callback.
local CLICK_PATIENCE_MS = 5000

--- The expression, run in the child, that finds `text` in the first window
--- showing the buffer the expression `buffer` gives, and returns the screen
--- cell, from 0, of the byte `offset` bytes into it, with that byte's line,
--- from 1, and its byte in the line, from 0; or nil when no line of the
--- buffer holds `text`.
local CELL_OF_TEXT = [[(function(buffer_expression, text, offset)
  local buffer = loadstring('return ' .. buffer_expression)()
  local window = vim.fn.win_findbuf(buffer)[1]
  for line, content in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, true)) do
    local first = content:find(text, 1, true)
    if first then
      local position = vim.fn.screenpos(window, line, first + offset)
      return { row = position.row - 1, col = position.col - 1, line = line, byte = first - 1 + offset }
    end
  end
  return nil
end)(...)]]

--- The expression that gives the child's Report buffer.
local REPORT = [[require('aineo.report').report_buffer()]]

--- The expression that gives the child's Claude terminal.
local CLAUDE_TERMINAL = [[vim.fn.bufnr('term://*')]]

--- Waits, at most `CLICK_PATIENCE_MS`, until a line of the buffer the
--- expression `buffer` gives holds `text`, and returns the screen cell of the
--- byte `offset` bytes into it (`CELL_OF_TEXT`). Raises an error when none
--- does by then.
---
---@param buffer string
---@param text string
---@param offset integer
---@return { row: integer, col: integer, line: integer, byte: integer }
local function cell_of(buffer, text, offset)
  local cell
  vim.wait(CLICK_PATIENCE_MS, function()
    cell = child.lua_get(CELL_OF_TEXT, { buffer, text, offset })
    return cell ~= vim.NIL and cell ~= nil
  end, 20)
  assert(cell ~= vim.NIL and cell ~= nil, ('no line shows %q'):format(text))
  return cell
end

--- Double-clicks, in the child, with the left button, on the screen cell
--- `cell`: two presses and releases, as a mouse sends them.
---
---@param cell { row: integer, col: integer }
local function double_click(cell)
  for _ = 1, 2 do
    child.api.nvim_input_mouse('left', 'press', '', 0, cell.row, cell.col)
    child.api.nvim_input_mouse('left', 'release', '', 0, cell.row, cell.col)
  end
end

--- Hands the child's report home a report whose details are `details`, and
--- makes the Report the current window.
---
---@param details string
local function receive_details_and_enter_report(details)
  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )
  child.lua(('vim.api.nvim_set_current_win(vim.fn.win_findbuf(%s)[1])'):format(REPORT))
end

--- Waits until the child has read every key it was given and runs no
--- callback it scheduled for them, at most `CLICK_PATIENCE_MS`.
local function wait_until_settled()
  vim.wait(CLICK_PATIENCE_MS, function()
    return child.lua_get([[vim.api.nvim_get_mode().blocking]]) == false
  end, 20)
  child.lua_get([[vim.wait(50)]])
end

--- What the child shows and did once a link was followed: what each window
--- shows, left to right (`entry.windows()`), what the current window shows,
--- what `vim.ui.open()` was given, and what it told the user.
---
---@return { windows: string[], current: string, external: string[], told: table[] }
local function what_followed()
  return {
    windows = entry.windows(child),
    current = entry.current_window(child),
    external = child.lua_get('_G.opened_externally'),
    told = entry.messages(child),
  }
end

--- The line, from 1, of the cursor in the child's current window.
---
---@return integer
local function cursor_line()
  return child.lua_get([[vim.fn.line('.')]])
end

--- The windows of the layout when nothing opened in the file column.
local LAYOUT_ALONE = { 'terminal', 'aineo://report', 'aineo://input' }

--- What `what_followed()` tells when the file `file` opened in the file
--- column, current, and nothing went to the system or was told.
---
---@param file string
---@return table
local function opened_in_file_column(file)
  return {
    windows = { 'terminal', file, 'aineo://report', 'aineo://input' },
    current = file,
    external = {},
    told = {},
  }
end

--- Waits, at most `CLICK_PATIENCE_MS`, until the child's current window
--- shows the file `file`.
---
---@param file string
local function wait_until_current_file_is(file)
  vim.wait(CLICK_PATIENCE_MS, function()
    return entry.current_window(child) == file
  end, 20)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      child.stop()
    end,
  },
})

T['a double-click in the Report'] = MiniTest.new_set()

T['a double-click in the Report']['on a file whose first 8 KiB hold a NUL hands it to the system'] = function()
  local top = open_layout_in_project('links-report-binary')
  receive_details_and_enter_report('See nul-inside.dat now')

  double_click(cell_of(REPORT, 'nul-inside.dat', 0))

  wait_until_settled()
  eq(what_followed(), {
    windows = LAYOUT_ALONE,
    current = 'aineo://report',
    external = { vim.fs.joinpath(top, 'nul-inside.dat') },
    told = {},
  })
end

T['a double-click in the Report']['on a file whose first NUL comes after 8 KiB opens it in the file column'] = function()
  local top = open_layout_in_project('links-report-late-nul')
  receive_details_and_enter_report('See nul-after.txt now')

  double_click(cell_of(REPORT, 'nul-after.txt', 0))

  wait_until_current_file_is(vim.fs.joinpath(top, 'nul-after.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'nul-after.txt')), line = 1 }
  )
end

T['a double-click in the Report']['on a path naming a line opens its file in the file column, at the line'] = function()
  local top = open_layout_in_project('links-report-line')
  receive_details_and_enter_report('See lua/x.lua:3 now')

  double_click(cell_of(REPORT, 'lua/x.lua:3', 0))

  wait_until_current_file_is(vim.fs.joinpath(top, 'lua/x.lua'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'lua/x.lua')), line = 3 }
  )
end

T['a double-click in the Report']['on a text file outside the project opens it in the file column'] = function()
  local top = open_layout_in_project('links-report-outside')
  local outside = vim.fs.joinpath(vim.fs.dirname(top), 'outside.txt')
  receive_details_and_enter_report('See ' .. outside .. ' now')

  double_click(cell_of(REPORT, 'outside.txt', 0))

  wait_until_current_file_is(outside)
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(outside), line = 1 }
  )
end

--- Has the fake `claude` print `text` on its screen, which it does with the
--- text it is typed, and makes Claude's terminal the current window, in
--- Terminal mode.
---
---@param text string
local function show_in_claude_terminal(text)
  child.lua(('vim.api.nvim_chan_send(vim.bo[%s].channel, ...)'):format(CLAUDE_TERMINAL), { text })
  child.lua(('vim.api.nvim_set_current_win(vim.fn.win_findbuf(%s)[1])'):format(CLAUDE_TERMINAL))
  child.cmd('startinsert')
  vim.wait(CLICK_PATIENCE_MS, function()
    return child.lua_get([[vim.fn.mode()]]) == 't'
  end, 20)
end

T["a double-click in Claude's terminal"] = MiniTest.new_set()

T["a double-click in Claude's terminal"]['on a text file of the project opens it in the file column, at its line'] = function()
  local top = open_layout_in_project('links-terminal-text')
  show_in_claude_terminal('See notes.txt:3 now')

  double_click(cell_of(CLAUDE_TERMINAL, 'notes.txt:3', 2))

  wait_until_current_file_is(vim.fs.joinpath(top, 'notes.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'notes.txt')), line = 3 }
  )
end

T["a double-click in Claude's terminal"]['on a text file of the project, in Normal mode, opens it in the file column, at its line'] = function()
  local top = open_layout_in_project('links-terminal-normal')
  show_in_claude_terminal('See notes.txt:2 now')
  local cell = cell_of(CLAUDE_TERMINAL, 'notes.txt:2', 2)
  child.cmd('stopinsert')

  double_click(cell)

  wait_until_current_file_is(vim.fs.joinpath(top, 'notes.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'notes.txt')), line = 2 }
  )
end

--- What `what_followed()` tells when a link in Claude's terminal opened
--- nothing in aineo and handed `external` to the system, telling nothing.
---
---@param external string[]
---@return table
local function handed_to_the_system_from_the_terminal(external)
  return { windows = LAYOUT_ALONE, current = 'terminal', external = external, told = {} }
end

T["a double-click in Claude's terminal"]['on a file of the project that is not text hands it to the system'] = function()
  local top = open_layout_in_project('links-terminal-binary')
  show_in_claude_terminal('See nul-inside.dat now')

  double_click(cell_of(CLAUDE_TERMINAL, 'nul-inside.dat', 0))

  wait_until_settled()
  eq(
    what_followed(),
    handed_to_the_system_from_the_terminal({ vim.fs.joinpath(top, 'nul-inside.dat') })
  )
end

T["a double-click in Claude's terminal"]['on a web link hands its address to the system'] = function()
  open_layout_in_project('links-terminal-web')
  show_in_claude_terminal('See https://example.com/a/b.lua now')

  double_click(cell_of(CLAUDE_TERMINAL, 'https://example.com/a/b.lua', 8))

  wait_until_settled()
  eq(what_followed(), handed_to_the_system_from_the_terminal({ 'https://example.com/a/b.lua' }))
end

T["a double-click in Claude's terminal"]['on a file address naming a line opens its file in the file column, at the line'] = function()
  local top = open_layout_in_project('links-terminal-address')
  local address = vim.uri_from_fname(vim.fs.joinpath(top, 'lua/x.lua')) .. '#L2'
  show_in_claude_terminal('See ' .. address .. ' now')

  double_click(cell_of(CLAUDE_TERMINAL, address, 10))

  wait_until_current_file_is(vim.fs.joinpath(top, 'lua/x.lua'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'lua/x.lua')), line = 2 }
  )
end

T["a double-click in Claude's terminal"]['on a path that names no file opens nothing and says so once'] = function()
  open_layout_in_project('links-terminal-missing')
  show_in_claude_terminal('See gone.lua:4 now')

  double_click(cell_of(CLAUDE_TERMINAL, 'gone.lua:4', 0))

  wait_until_settled()
  eq(what_followed(), {
    windows = LAYOUT_ALONE,
    current = 'terminal',
    external = {},
    told = { { message = 'aineo: gone.lua names no file', level = vim.log.levels.WARN } },
  })
end

T["a double-click in Claude's terminal"]['on a directory of the project hands it to the system'] = function()
  local top = open_layout_in_project('links-terminal-directory')
  show_in_claude_terminal('See lua/ now')

  double_click(cell_of(CLAUDE_TERMINAL, 'lua/', 1))

  wait_until_settled()
  eq(what_followed(), handed_to_the_system_from_the_terminal({ vim.fs.joinpath(top, 'lua/') }))
end

T["a double-click in Claude's terminal"]['on no link, in Normal mode, selects the word, as Neovim does'] = function()
  open_layout_in_project('links-terminal-word')
  show_in_claude_terminal('Words alone here')
  local cell = cell_of(CLAUDE_TERMINAL, 'Words alone here', 7)
  child.cmd('stopinsert')

  double_click(cell)

  vim.wait(CLICK_PATIENCE_MS, function()
    return child.lua_get([[vim.fn.mode()]]) == 'v'
  end, 20)
  eq(
    { mode = child.lua_get([[vim.fn.mode()]]), followed = what_followed() },
    { mode = 'v', followed = handed_to_the_system_from_the_terminal({}) }
  )
end

T["a double-click in Claude's terminal"]['on a text file outside the project opens it in the file column, at its line'] = function()
  local top = open_layout_in_project('links-terminal-outside')
  local outside = vim.fs.joinpath(vim.fs.dirname(top), 'outside.txt')
  show_in_claude_terminal('See ../outside.txt:1 now')

  double_click(cell_of(CLAUDE_TERMINAL, '../outside.txt:1', 4))

  wait_until_current_file_is(outside)
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(outside), line = 1 }
  )
end

T["gx in Claude's terminal"] = MiniTest.new_set()

T["gx in Claude's terminal"]['on a text file of the project opens it in the file column, at its line'] = function()
  local top = open_layout_in_project('links-terminal-gx')
  show_in_claude_terminal('See lua/x.lua:3 now')
  local cell = cell_of(CLAUDE_TERMINAL, 'lua/x.lua:3', 4)
  child.cmd('stopinsert')
  child.api.nvim_win_set_cursor(0, { cell.line, cell.byte })

  entry.press(child, 'gx')

  wait_until_current_file_is(vim.fs.joinpath(top, 'lua/x.lua'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'lua/x.lua')), line = 3 }
  )
end

--- Makes the child's home folder a folder of its own holding `x.txt`, four
--- lines long, and returns its path: `~` is looked up there.
---
---@param name string the case's own name, starting `links-`
---@return string home
local function use_home_with_x_txt(name)
  local home = fixture.directory(name .. '-home')
  fixture.write(vim.fs.basename(home) .. '/x.txt', { 'one', 'two', 'three', 'four' })
  child.lua('vim.env.HOME = ...', { home })
  return home
end

T["a double-click in Claude's terminal"]['on a path in the home folder, written with ~, opens it in the file column'] = function()
  open_layout_in_project('links-terminal-tilde')
  local home = use_home_with_x_txt('links-terminal-tilde')
  show_in_claude_terminal('See ~/x.txt now')

  double_click(cell_of(CLAUDE_TERMINAL, '~/x.txt', 1))

  wait_until_current_file_is(vim.fs.joinpath(home, 'x.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(home, 'x.txt')), line = 1 }
  )
end

T["a double-click in Claude's terminal"]['on a ~ path naming a line opens its file in the file column, at the line'] = function()
  open_layout_in_project('links-terminal-tilde-line')
  local home = use_home_with_x_txt('links-terminal-tilde-line')
  show_in_claude_terminal('See ~/x.txt:3 now')

  double_click(cell_of(CLAUDE_TERMINAL, '~/x.txt:3', 1))

  wait_until_current_file_is(vim.fs.joinpath(home, 'x.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(home, 'x.txt')), line = 3 }
  )
end

T["gx in Claude's terminal"]['on a ~ path naming a line opens its file in the file column, at the line'] = function()
  open_layout_in_project('links-terminal-tilde-gx')
  local home = use_home_with_x_txt('links-terminal-tilde-gx')
  show_in_claude_terminal('See ~/x.txt:2 now')
  local cell = cell_of(CLAUDE_TERMINAL, '~/x.txt:2', 3)
  child.cmd('stopinsert')
  child.api.nvim_win_set_cursor(0, { cell.line, cell.byte })

  entry.press(child, 'gx')

  wait_until_current_file_is(vim.fs.joinpath(home, 'x.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(home, 'x.txt')), line = 2 }
  )
end

T["a double-click in Claude's terminal"]['on the home folder, written ~/, hands it to the system'] = function()
  open_layout_in_project('links-terminal-tilde-folder')
  local home = use_home_with_x_txt('links-terminal-tilde-folder')
  show_in_claude_terminal('See ~/ now')

  double_click(cell_of(CLAUDE_TERMINAL, 'See ~/ now', 4))

  wait_until_settled()
  eq(what_followed(), handed_to_the_system_from_the_terminal({ home .. '/' }))
end

T["a double-click in Claude's terminal"]['on a ~ path that names no file opens nothing and says so once'] = function()
  open_layout_in_project('links-terminal-tilde-missing')
  use_home_with_x_txt('links-terminal-tilde-missing')
  show_in_claude_terminal('See ~/nope now')

  double_click(cell_of(CLAUDE_TERMINAL, '~/nope', 1))

  wait_until_settled()
  eq(what_followed(), {
    windows = LAYOUT_ALONE,
    current = 'terminal',
    external = {},
    told = { { message = 'aineo: ~/nope names no file', level = vim.log.levels.WARN } },
  })
end

T["a double-click in Claude's terminal"]['on a path with a ~ inside it keeps the ~ and looks it up in the project'] = function()
  local top = open_layout_in_project('links-terminal-tilde-inside')
  use_home_with_x_txt('links-terminal-tilde-inside')
  show_in_claude_terminal('See a/~b.txt now')

  double_click(cell_of(CLAUDE_TERMINAL, 'a/~b.txt', 0))

  wait_until_current_file_is(vim.fs.joinpath(top, 'a/~b.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, 'a/~b.txt')), line = 1 }
  )
end

T["a double-click in Claude's terminal"]['on a ~user path leaves the ~user and looks it up in the project'] = function()
  local top = open_layout_in_project('links-terminal-tilde-user')
  use_home_with_x_txt('links-terminal-tilde-user')
  show_in_claude_terminal('See ~user/x.txt now')

  double_click(cell_of(CLAUDE_TERMINAL, '~user/x.txt', 1))

  wait_until_current_file_is(vim.fs.joinpath(top, '~user/x.txt'))
  eq(
    { followed = what_followed(), line = cursor_line() },
    { followed = opened_in_file_column(vim.fs.joinpath(top, '~user/x.txt')), line = 1 }
  )
end

T['following the link ~ alone'] = MiniTest.new_set()

T['following the link ~ alone']['hands the home folder to the system'] = function()
  local top = open_layout_in_project('links-tilde-alone')
  local home = use_home_with_x_txt('links-tilde-alone')

  child.lua([[require('aineo.entry.links').open_link('~', nil, ...)]], { top })

  local followed = what_followed()
  eq({ external = followed.external, told = followed.told }, { external = { home }, told = {} })
end

return T
