local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
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

--- How long a key typed in Claude's terminal may take to be handled while
--- its stopped process still runs: generous, for a loaded host, and far
--- below the seconds a wait for that process to end would take.
local STOPPED_TERMINAL_PATIENCE_MS = 1000

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
--- terminal Claude's window shows, and fails the test unless the session has
--- exited within `claude_session.PATIENCE_MS`.
---
---@param child table
local function end_claude_code(child)
  child.lua(('vim.fn.jobstop(vim.bo[%s].channel)'):format(CLAUDE_WINDOW_BUFFER))
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')
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
--- and fails the test unless Neovim has seen it end within two seconds.
---
---@param child table
local function end_user_terminal(child)
  child.lua('vim.fn.jobstop(_G.user_terminal_job)')
  eq(layout.wait_until(child, '_G.user_terminal_ended'), true)
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

--- Runs `command` in `child`'s Claude's window while Claude Code runs there,
--- in Normal mode, and no other buffer is listed, as
--- `wipe_ended_terminal_from_its_window()` does once it has exited.
---
---@param child table
---@param command string
local function wipe_running_terminal_from_its_window(child, command)
  entry.use_fake(child, claude_session.fake('entry-claude-exit-running-wiped', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.type_keys('\\c', [[<C-\><C-n>]])
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

T["Claude Code's exit"]["returns Normal mode in Claude's window when Claude Code exits on the keys the user types to it"] = function()
  local fake = claude_session.fake('entry-claude-exit-typed', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  child.type_keys('\\c')

  claude_session.end_by_keys(child, fake, child.lua_get(CLAUDE_WINDOW_BUFFER))

  local events = claude_session.wait_for_end(fake)
  eq(events[#events].ended, 'keys')
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]["returns Normal mode when Claude Code exits while the user is in its terminal in another tab's window"] = function()
  entry.use_fake(child, claude_session.fake('entry-claude-exit-other-window', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)
  child.cmd('tab sbuffer ' .. terminal)
  child.type_keys('i')

  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { terminal })
  eq(claude_session.wait_for_status(child, 'exited')[1], 'exited')

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), terminal)
  eq(child.lua_get(MODE), 'nt')
end

T["Claude Code's exit"]["returns at once when i is typed in Claude's terminal whose stopped process still runs"] = function()
  local fake = claude_session.fake('entry-claude-exit-stopped', 'deaf')
  entry.use_fake(child, fake, { claude = { cmd = claude_session.deaf_fake_command() } })
  child.cmd('Aineo open')
  eq(claude_session.wait_for_start(fake).argv, {})
  child.type_keys('\\c', [[<C-\><C-n>]])
  child.lua(('vim.fn.jobstop(vim.bo[%s].channel)'):format(CLAUDE_WINDOW_BUFFER))
  local started_ns = vim.uv.hrtime()

  child.type_keys('i')

  local elapsed_ms = (vim.uv.hrtime() - started_ns) / 1e6
  eq(elapsed_ms < STOPPED_TERMINAL_PATIENCE_MS, true)
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
  eq(child.lua_get(SESSION_STATE), 'starting')
  child.type_keys([[<C-\><C-n>]])

  child.type_keys('\\' .. key)

  eq(entry.current_window(child), shown)
  eq(child.lua_get(MODE), 'n')
end

T['a wiped Claude terminal']["raises no error and adds no window when Claude's window is Neovim's last, after"] = function(
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

T['a wiped Claude terminal']["lets \\c start Claude Code again when Claude's window was Neovim's last, after"] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-last-window')
  child.cmd('only')
  entry.command(child, command)
  entry.use_fake(child, claude_session.fake('entry-claude-exit-last-window-restarted', 'trust'))

  child.type_keys('\\c')

  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(child.lua_get(MODE), 't')
end

T['a wiped Claude terminal']['keeps the window of the Claude Code that :Aineo open starts in the same command line, after'] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-reopened')
  entry.use_fake(child, claude_session.fake('entry-claude-exit-reopened-new', 'trust'))

  entry.command(child, command .. ' | Aineo open')

  eq(entry.messages(child), {})
  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
end

T['a wiped Claude terminal']["keeps the window Claude's window reopened in the same command line, after"] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-closed-reopened')
  entry.use_fake(child, claude_session.fake('entry-claude-exit-closed-reopened-new', 'trust'))

  entry.command(child, command .. ' | close | Aineo claude')

  eq(entry.messages(child), {})
  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
end

T['a wiped Claude terminal']["keeps in view the file the same command line opens in Claude's window, after"] = function(
  command
)
  local file = fixture.write('entry-claude-exit-edit/file.txt', { 'text' })
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-edit')

  entry.command(child, command .. ' | edit ' .. file)

  eq(entry.messages(child), {})
  eq(entry.windows(child), { file, 'aineo://report', 'aineo://input' })
end

T['a wiped Claude terminal']['raises no error when the command-line window opens right after it, after'] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-cmdwin')
  child.v.errmsg = ''

  child.api.nvim_input(':' .. command .. '<CR>q:')

  eq(layout.wait_until(child, "vim.fn.getcmdwintype() == ':'"), true)
  eq(child.v.errmsg, '')
end

T['a wiped Claude terminal']['lets \\c start Claude Code again once the command-line window that opened right after it is closed, after'] = function(
  command
)
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-cmdwin-closed')
  child.api.nvim_input(':' .. command .. '<CR>q:')
  eq(layout.wait_until(child, "vim.fn.getcmdwintype() == ':'"), true)
  child.api.nvim_input(':quit<CR>')
  eq(
    layout.wait_until(child, "vim.fn.getcmdwintype() == '' and vim.api.nvim_get_mode().mode == 'n'"),
    true
  )
  child.v.errmsg = ''
  entry.use_fake(child, claude_session.fake('entry-claude-exit-cmdwin-restarted', 'trust'))

  child.type_keys('\\c')

  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(child.lua_get(MODE), 't')
end

T['a wiped running Claude terminal'] = MiniTest.new_set({
  parametrize = { { 'bwipeout!' }, { 'bdelete!' } },
})

T['a wiped running Claude terminal']["closes Claude's window, raising no error, after"] = function(
  command
)
  wipe_running_terminal_from_its_window(child, command)

  eq(entry.messages(child), {})
  eq(child.v.errmsg, '')
  eq(entry.windows(child), { 'aineo://report', 'aineo://input' })
end

T['a wiped running Claude terminal']['lets \\c start Claude Code again, in Terminal mode, after'] = function(
  command
)
  wipe_running_terminal_from_its_window(child, command)
  entry.use_fake(child, claude_session.fake('entry-claude-exit-running-restarted', 'trust'))

  child.type_keys('\\c')

  eq(child.lua_get(SESSION_STATE), 'starting')
  eq(entry.windows(child), WHOLE_LAYOUT)
  eq(child.lua_get(MODE), 't')
end

T["a user's TermClose autocommand that wipes Claude's terminal"] = MiniTest.new_set()

T["a user's TermClose autocommand that wipes Claude's terminal"]['lets \\c start Claude Code again'] = function()
  child.lua([[
    vim.api.nvim_create_autocmd('TermClose', {
      callback = function(event)
        vim.api.nvim_buf_delete(event.buf, { force = true })
      end,
    })
  ]])
  type_to_claude_code_exiting_at_start(child, 'entry-claude-exit-user-wipe')
  entry.use_fake(child, claude_session.fake('entry-claude-exit-user-wipe-restarted', 'trust'))

  child.type_keys('\\c')

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
