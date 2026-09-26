local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The buffer of the child's first window, which is Claude's in the layout.
local CLAUDE_WINDOW_BUFFER = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- The expression, run in the child, that tells where Claude's session
--- stands (`aineo.claude`'s `session_status()`).
local SESSION_STATE = "require('aineo.claude').session_status()"

--- The expression, run in the child, that tells the mode it is in, as
--- `nvim_get_mode()` names it: `t` in Terminal mode, `nt` in Normal mode in a
--- terminal's window.
local MODE = 'vim.api.nvim_get_mode().mode'

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

--- The commands that put the cursor in a window of the open layout, other
--- than Claude's.
local AWAY_FROM_CLAUDE = { { 'Aineo report' }, { 'Aineo input' } }

T['\\c'] = MiniTest.new_set()

T['\\c']["enters Terminal mode in Claude's window, from the right column"] = MiniTest.new_set({
  parametrize = AWAY_FROM_CLAUDE,
})

T['\\c']["enters Terminal mode in Claude's window, from the right column"]['after'] = function(
  command
)
  local fake = claude_session.fake('entry-claude-mode-right-column', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.cmd(command)

  child.type_keys('\\c')

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['\\c']["enters Terminal mode in Claude's window, from the file column"] = function()
  local fake = claude_session.fake('entry-claude-mode-file-column', 'ready')
  local file = fixture.write('entry-claude-mode-file-column/file.txt', { 'text' })
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.cmd('edit ' .. file)

  child.type_keys('\\c')

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['\\c']["reopens Claude's closed window in Terminal mode"] = function()
  local fake = claude_session.fake('entry-claude-mode-closed-window', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.lua('vim.api.nvim_win_close(vim.fn.win_getid(1), true)')

  child.type_keys('\\c')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['\\c']["moves from another tab to Claude's window in Terminal mode"] = function()
  local fake = claude_session.fake('entry-claude-mode-other-tab', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.cmd('tabnew')

  child.type_keys('\\c')

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['\\c']['enters Terminal mode while Claude Code shows a dialog as it starts'] = function()
  local fake = claude_session.fake('entry-claude-mode-starting', 'trust')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_screen(child, child.lua_get(CLAUDE_WINDOW_BUFFER), 'I trust this folder')
  child.cmd('Aineo report')

  child.type_keys('\\c')

  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(child.lua_get(MODE), 't')
end

T['\\c']["enters Terminal mode on the new Claude it starts once the ended one's terminal was wiped"] = function()
  local ended = claude_session.fake('entry-claude-mode-ended', 'exit')
  entry.use_fake(child, ended)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  child.cmd('bwipeout! ' .. child.lua_get(CLAUDE_WINDOW_BUFFER))
  entry.use_fake(child, claude_session.fake('entry-claude-mode-restarted', 'trust'))

  child.type_keys('\\c')

  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(child.lua_get(MODE), 't')
end

T['\\c']["stays in Normal mode in Claude's window once Claude's session has ended"] = function()
  local fake = claude_session.fake('entry-claude-mode-exited', 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  child.cmd('Aineo report')

  child.type_keys('\\c')

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 'nt')
end

T['\\r and \\i'] = MiniTest.new_set({
  parametrize = { { 'r', 'aineo://report' }, { 'i', 'aineo://input' } },
})

T['\\r and \\i']['move to their window in Normal mode'] = function(key, shown)
  local fake = claude_session.fake('entry-claude-mode-normal-' .. key, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  child.cmd('tabnew')

  child.type_keys('\\' .. key)

  eq(entry.current_window(child), shown)
  eq(child.lua_get(MODE), 'n')
end

return T
