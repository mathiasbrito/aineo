local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_editor = dofile('tests/helpers/entry_editor.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the child, that gives the text the status line of
--- its first window — Claude's in the layout — draws, however wide.
local CLAUDE_STATUSLINE_TEXT = [[(function()
  local window = vim.fn.win_getid(1)
  return vim.api.nvim_eval_statusline(vim.wo[window].statusline, { winid = window, maxwidth = 1000 }).str
end)()]]

--- The text the status line of Claude's window in `child` draws
--- (`CLAUDE_STATUSLINE_TEXT`).
---
---@param child table
---@return string
local function claude_statusline_text(child)
  return child.lua_get(CLAUDE_STATUSLINE_TEXT)
end

--- What `child`'s current directory reads as, written from the home
--- directory.
---
---@param child table
---@return string
local function folder_of_current_directory(child)
  return child.fn.fnamemodify(child.fn.getcwd(), ':~')
end

--- Makes aineo in `child` run the fake `claude` in `mode` under `name`, opens
--- the layout with `\o`, and waits until that Claude Code has started.
---
---@param child table
---@param name string the test's own name for its files
---@param mode string the fake's mode
---@return { record: string, environment: table<string, string> } fake
local function open_with_fake(child, name, mode)
  local fake = claude_session.fake(name, mode)
  entry.use_fake(child, fake)
  entry.press(child, '\\o')
  claude_session.wait_for_start(fake)
  return fake
end

--- The text the status line of Claude's window in `child` draws once it is
--- `text`, waiting for that at most `claude_session.PATIENCE_MS`, or when the
--- wait runs out.
---
---@param child table
---@param text string
---@return string
local function wait_for_claude_statusline(child, text)
  local shown
  vim.wait(claude_session.PATIENCE_MS, function()
    shown = claude_statusline_text(child)
    return shown == text
  end, 20)
  return shown
end

--- The expression, run in the child, that gives the screen row of the
--- status line of its first window, Claude's in the layout, and that
--- window's width.
local CLAUDE_STATUSLINE_PLACE = [[(function()
  local window = vim.fn.win_getid(1)
  return {
    row = vim.fn.win_screenpos(window)[1] + vim.api.nvim_win_get_height(window),
    width = vim.api.nvim_win_get_width(window),
  }
end)()]]

--- What `child`'s screen shows on the row of the status line of Claude's
--- window, across that window's width, without the blanks that pad it on
--- the right: read from mini.test's screenshot. Its `:redraw`, in a child
--- with no user interface, draws the status line again whether or not
--- anything asked for it, so an empty title's redraw is pinned in an editor
--- that has one (`entry_editor`).
---
---@param child table
---@return string
local function drawn_claude_statusline(child)
  local place = child.lua_get(CLAUDE_STATUSLINE_PLACE)
  local row = child.get_screenshot().text[place.row]
  return vim.trim(table.concat(row, '', 1, place.width))
end

--- The terminal `child`'s first window shows, Claude's in the layout.
---
---@param child table
---@return integer
local function claude_terminal(child)
  return child.api.nvim_win_get_buf(child.fn.win_getid(1))
end

--- Ends Claude Code in `child` as a hangup does, by stopping the job of the
--- terminal Claude's window shows, and fails the test unless the session has
--- exited within `claude_session.PATIENCE_MS`.
---
---@param child table
local function end_claude_code(child)
  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { claude_terminal(child) })
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
end

--- A terminal program of the tests' own standing in for Claude Code, run as
--- `claude.cmd`: it sets the title Claude Code 2.1.292 set for
--- `--name aineo-title-probe`, `✳ aineo-title-probe` (measured on
--- 2026-10-06), then, at each line typed into it, `✳ Second name`, then an
--- empty title, as Claude Code does as it exits, and then exits. It echoes
--- nothing typed, so that a title comes with nothing else drawn in the
--- terminal, which would draw its window again.
local TITLE_SCRIPT = {
  'stty -echo',
  [[printf '\033]0;\342\234\263 aineo-title-probe\007']],
  'read _',
  [[printf '\033]0;\342\234\263 Second name\007']],
  'read _',
  [[printf '\033]0;\007']],
  'read _',
}

--- Makes aineo in `child` run `script`, written under `name`, as
--- `claude.cmd`, and opens the layout with `\o`.
---
---@param child table
---@param name string the test's own name for its files
---@param script string[] the script's lines
local function open_with_script(child, name, script)
  local path = fixture.write(name .. '/claude.sh', script)
  entry.use_fake(child, claude_session.fake(name, 'ready'), { claude = { cmd = { 'sh', path } } })
  entry.press(child, '\\o')
end

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

T["Claude's window"] = MiniTest.new_set()

T["Claude's window"]['reads Claude Code, then the folder, once \\o has opened the layout'] = function()
  open_with_fake(child, 'claude-name-ready', 'ready')

  eq(claude_statusline_text(child), 'Claude Code — ' .. folder_of_current_directory(child))
end

T["Claude's window"]['reads Claude Code, never the terminal’s name, when Claude Code sets no title'] = function()
  open_with_fake(child, 'claude-name-turn', 'turn')

  eq(claude_statusline_text(child), 'Claude Code — ' .. folder_of_current_directory(child))
end

T["Claude's window"]['draws each title Claude Code sets, and Claude Code again on an empty one'] = function()
  open_with_script(child, 'claude-name-titles', TITLE_SCRIPT)
  local folder = folder_of_current_directory(child)
  wait_for_claude_statusline(child, 'aineo-title-probe — ' .. folder)
  local drawn = { drawn_claude_statusline(child) }

  claude_session.press_keys(child, claude_terminal(child), '\r')
  wait_for_claude_statusline(child, 'Second name — ' .. folder)
  table.insert(drawn, drawn_claude_statusline(child))
  claude_session.press_keys(child, claude_terminal(child), '\r')
  wait_for_claude_statusline(child, 'Claude Code — ' .. folder)
  table.insert(drawn, drawn_claude_statusline(child))

  eq(drawn, {
    'aineo-title-probe — ' .. folder,
    'Second name — ' .. folder,
    'Claude Code — ' .. folder,
  })
end

--- A terminal program of the tests' own standing in for Claude Code in an
--- editor with a user interface: it sets the title `✳ aineo-title-probe`,
--- then, a second after a line is typed into it, an empty title, so that
--- the empty title comes while the editor has nothing else to draw. It
--- echoes nothing typed.
local LATE_EMPTY_TITLE_SCRIPT = {
  'stty -echo',
  [[printf '\033]0;\342\234\263 aineo-title-probe\007']],
  'read _',
  'sleep 1',
  [[printf '\033]0;\007']],
  'read _',
}

--- The code, run in an editor of `entry_editor`'s, that presses Enter in the
--- terminal its first window shows, Claude's in the layout.
local PRESS_ENTER_IN_CLAUDE = [[
  local terminal = vim.api.nvim_win_get_buf(vim.fn.win_getid(1))
  vim.api.nvim_chan_send(vim.bo[terminal].channel, '\r')
]]

T["Claude's window"]['draws Claude Code again on an empty title that comes while the editor draws nothing else'] = function()
  local script = fixture.write('claude-name-ui/claude.sh', LATE_EMPTY_TITLE_SCRIPT)
  local settings = { autostart = false, claude = { cmd = { 'sh', script } } }
  local editor = entry_editor.start(child, entry.restart, {
    args = { '--cmd', 'lua vim.g.aineo = ' .. vim.inspect(settings, { newline = '', indent = '' }) },
  })
  local folder = entry_editor.get(editor, "vim.fn.fnamemodify(vim.fn.getcwd(), ':~')")
  entry_editor.request(editor, "vim.cmd('Aineo open')")
  local named = entry_editor.wait_for_screen(editor, 'aineo-title-probe — ' .. folder)

  entry_editor.request(editor, PRESS_ENTER_IN_CLAUDE)

  eq(
    { named, (entry_editor.wait_for_screen(editor, 'Claude Code — ' .. folder)) },
    { true, true }
  )
end

T["Claude's window"]['reads Claude Code, then the folder, once Claude Code has cleared its title and exited'] = function()
  open_with_script(child, 'claude-name-exit', {
    [[printf '\033]0;\342\234\263 aineo-title-probe\007']],
    'read _',
    [[printf '\033]0;\007']],
  })
  local folder = folder_of_current_directory(child)
  wait_for_claude_statusline(child, 'aineo-title-probe — ' .. folder)

  claude_session.press_keys(child, claude_terminal(child), '\r')

  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
  eq(
    { claude_statusline_text(child), drawn_claude_statusline(child) },
    { 'Claude Code — ' .. folder, 'Claude Code — ' .. folder }
  )
end

T["Claude's window"]['reads a % in the name and in the folder as written'] = function()
  local directory = fixture.directory('claude-name-50%-off')
  child.cmd('cd ' .. vim.fn.fnameescape(directory))

  open_with_script(child, 'claude-name-percent', {
    [[printf '\033]0;\342\234\263 Fix 100%% CPU\007']],
    'read _',
  })

  eq(
    wait_for_claude_statusline(child, 'Fix 100% CPU — ' .. vim.fn.fnamemodify(directory, ':~')),
    'Fix 100% CPU — ' .. vim.fn.fnamemodify(directory, ':~')
  )
  eq(entry.messages(child), {})
end

T["Claude's window"]['reads the folder Claude Code started in, whatever :cd and \\o do while it runs'] = function()
  local started_in = fixture.directory('claude-name-started-in')
  local moved_to = fixture.directory('claude-name-moved-to')
  child.cmd('cd ' .. started_in)
  open_with_fake(child, 'claude-name-cd', 'ready')

  child.cmd('cd ' .. moved_to)
  entry.press(child, '\\o')

  eq(claude_statusline_text(child), 'Claude Code — ' .. vim.fn.fnamemodify(started_in, ':~'))
end

T["Claude's window"]['reads the folder of the Claude Code \\o starts again once the last has exited'] = function()
  local started_in = fixture.directory('claude-name-first-start')
  local moved_to = fixture.directory('claude-name-second-start')
  child.cmd('cd ' .. started_in)
  local fake = open_with_fake(child, 'claude-name-restart', 'ready')
  end_claude_code(child)
  child.cmd('cd ' .. moved_to)

  entry.press(child, '\\o')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(claude_statusline_text(child), 'Claude Code — ' .. vim.fn.fnamemodify(moved_to, ':~'))
end

T["Claude's window"]['reads Claude Code, then the folder, for the new session that takes the place of a resume with no conversation'] = function()
  local name = 'claude-name-fallback'
  local fake = claude_session.fake(name, 'ready', {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
  child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory(name .. '-state') })
  entry.use_fake(child, fake)
  entry.press(child, '\\o')
  claude_session.wait_for_start(fake)
  end_claude_code(child)

  child.cmd('Aineo open')

  eq(#claude_session.wait_for_starts(fake, 3), 3)
  eq(claude_session.wait_for_status(child, 'ready'), { 'ready' })
  eq(claude_statusline_text(child), 'Claude Code — ' .. folder_of_current_directory(child))
end

return T
