local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the child, that tells the mode it is in, as
--- `nvim_get_mode()` names it: `t` in Terminal mode, `nt` in Normal mode in a
--- terminal's window.
local MODE = 'vim.api.nvim_get_mode().mode'

--- The expression, run in the child, that tells where Claude's session
--- stands (`aineo.claude`'s `session_status()`).
local SESSION_STATE = "require('aineo.claude').session_status()"

--- The expression, run in the child, that gives the terminal shown in the
--- child's first window, which is Claude's in the layout.
local CLAUDE_WINDOW_BUFFER = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- What the child's windows show while the layout is whole.
local WHOLE_LAYOUT = { 'terminal', 'aineo://report', 'aineo://input' }

--- Types `\c` in `child`, with aineo running the fake `claude` in its `exit`
--- mode under `name`: the layout opens around a Claude Code that exits at its
--- start, with the cursor in Claude's prompt, in Terminal mode. Waits until
--- the session has exited.
---
---@param child table
---@param name string the test's own name for the fake's files
local function type_to_claude_code_exiting_at_start(child, name)
  entry.use_fake(child, claude_session.fake(name, 'exit'))
  child.type_keys('\\c')
  claude_session.wait_for_status(child, 'exited')
end

--- Ends Claude Code in `child` as a hangup does, by stopping the job of the
--- terminal Claude's window shows, and waits until the session has exited.
---
---@param child table
local function end_claude_code(child)
  child.lua(('vim.fn.jobstop(vim.bo[%s].channel)'):format(CLAUDE_WINDOW_BUFFER))
  claude_session.wait_for_status(child, 'exited')
end

--- Opens a terminal of the user's own, running `cat`, in a new tab of
--- `child`, with the cursor in it, in Normal mode.
---
---@param child table
local function start_user_terminal(child)
  child.cmd('tabnew')
  child.lua([[
    _G.user_terminal_ended = false
    _G.user_terminal_job = vim.fn.jobstart({ 'cat' }, {
      term = true,
      on_exit = function()
        _G.user_terminal_ended = true
      end,
    })
  ]])
end

--- Ends the process of the terminal `start_user_terminal()` opened in `child`,
--- and waits, at most two seconds, until Neovim has seen it end.
---
---@param child table
local function end_user_terminal(child)
  child.lua('vim.fn.jobstop(_G.user_terminal_job)')
  layout.wait_until(child, '_G.user_terminal_ended')
end

--- Runs `command` in `child`'s Claude's window once Claude Code has exited at
--- its start (`type_to_claude_code_exiting_at_start()`): the window shows its
--- terminal and is the current one, and no other buffer is listed. Empties
--- `v:errmsg` first, so that what it holds after tells an error raised once
--- the command had run, if any; an error the command raises is kept for
--- `entry.messages()` (`entry.command()`).
---
---@param child table
---@param command string
local function wipe_ended_terminal_from_its_window(child, command)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-wiped')
  child.v.errmsg = ''
  entry.command(child, command)
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

T["Claude Code's exit"] = MiniTest.new_set()

T["Claude Code's exit"]["returns Normal mode in Claude's window when Claude Code exits at its start, after \\c"] = function()
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-at-start')

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]["returns Normal mode in Claude's window when Claude Code exits while the user is in its prompt"] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-in-prompt', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.type_keys('\\c')

  end_claude_code(child)

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]['returns Normal mode once Neovim sees an exit that a busy editor handled \\c before'] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-busy', 'exit'))
  child.cmd('Aineo open')
  child.lua_notify('vim.uv.sleep(1500)')
  child.api.nvim_input('\\c')

  claude_session.wait_for_status(child, 'exited')

  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]["keeps Claude's exit on screen when a key follows it"] = function()
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-next-key')

  child.api.nvim_input('x')

  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]["keeps Claude's ended terminal in Normal mode, whatever is typed on, after"] =
  MiniTest.new_set({
    parametrize = { { 'i' }, { 'a' }, { 'I' }, { 'A' }, { ':startinsert<CR>' } },
  })

T["Claude Code's exit"]["keeps Claude's ended terminal in Normal mode, whatever is typed on, after"]['keys'] = function(
  keys
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-typing-on')

  child.type_keys(keys)
  child.api.nvim_input('fix this')

  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]['leaves Insert mode in Input as it is'] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-input', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.type_keys('i')

  end_claude_code(child)

  eq(entry.current_window(child), 'aineo://input')
  eq(child.lua_get(MODE), 'i')
end

T['a wiped Claude terminal'] = MiniTest.new_set({
  parametrize = { { 'bwipeout!' }, { 'bdelete!' } },
})

T['a wiped Claude terminal']["closes Claude's window, raising no error, after"] = function(command)
  wipe_ended_terminal_from_its_window(child, command)

  eq(entry.messages(child), {})
  eq(child.v.errmsg, '')
  eq(entry.windows(child), { 'aineo://report', 'aineo://input' })
end

T['a wiped Claude terminal']["raises no error when the command that wipes it closes Claude's window too, after"] = function(
  command
)
  wipe_ended_terminal_from_its_window(child, command .. ' | close')

  eq(entry.messages(child), {})
  eq(child.v.errmsg, '')
  eq(entry.windows(child), { 'aineo://report', 'aineo://input' })
end

T['a wiped Claude terminal']['lets \\c start Claude Code again, in Terminal mode, after'] = function(
  command
)
  wipe_ended_terminal_from_its_window(child, command)
  entry.use_fake(child, claude_session.fake('entry-claude-exit-restarted', 'trust'))

  child.type_keys('\\c')

  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['a wiped Claude terminal']['lets the keys of the right column move there once \\c restarted Claude Code, after'] =
  MiniTest.new_set({
    parametrize = { { 'r', 'aineo://report' }, { 'i', 'aineo://input' } },
  })

T['a wiped Claude terminal']['lets the keys of the right column move there once \\c restarted Claude Code, after']['pressing'] = function(
  command,
  key,
  shown
)
  wipe_ended_terminal_from_its_window(child, command)
  entry.use_fake(child, claude_session.fake('entry-claude-exit-right-column', 'trust'))
  child.type_keys('\\c')
  child.type_keys([[<C-\><C-n>]])

  child.type_keys('\\' .. key)

  eq(entry.current_window(child), shown)
  eq(child.lua_get(MODE), 'n')
end

T['a wiped Claude terminal']["raises no error and adds no window when Claude's window is the only one of its tab, after"] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-only-window')
  child.cmd('only')
  child.v.errmsg = ''

  entry.command(child, command)

  eq(entry.messages(child), {})
  eq(child.v.errmsg, '')
  eq(entry.windows(child), { '' })
end

T['a wiped Claude terminal']['lets \\c start Claude Code again, raising no error, when wiped from another tab by'] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-other-tab')
  local terminal = child.lua_get('vim.api.nvim_get_current_buf()')
  child.cmd('tabnew')
  child.v.errmsg = ''
  entry.command(child, command .. ' ' .. terminal)
  entry.use_fake(child, claude_session.fake('entry-claude-exit-other-tab-restarted', 'trust'))

  child.type_keys('\\c')

  eq(entry.messages(child), {})
  eq(child.v.errmsg, '')
  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(child.lua_get(MODE), 't')
end

T["another buffer wiped in Claude's window"] = MiniTest.new_set()

T["another buffer wiped in Claude's window"]["gives Claude's window its terminal back when Neovim keeps the window open, Claude's terminal unlisted"] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-other-buffer', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.lua([[
    local claude_window = vim.fn.win_getid(1)
    vim.bo[vim.api.nvim_win_get_buf(claude_window)].buflisted = false
    vim.api.nvim_set_current_win(claude_window)
    vim.api.nvim_win_set_buf(claude_window, vim.api.nvim_create_buf(true, true))
  ]])

  entry.command(child, 'bwipeout!')

  eq(entry.windows(child)[1], 'terminal')
end

T["another terminal's exit"] = MiniTest.new_set()

T["another terminal's exit"]['leaves Terminal mode in that terminal as Neovim does'] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-other-terminal', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  start_user_terminal(child)
  child.type_keys('i')

  end_user_terminal(child)

  eq(child.lua_get(MODE), 't')
end

T["another terminal's exit"]['lets i enter Terminal mode in that ended terminal as Neovim does'] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-other-terminal-ended', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  start_user_terminal(child)
  end_user_terminal(child)

  child.type_keys('i')

  eq(child.lua_get(MODE), 't')
end

return T
