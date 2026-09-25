local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality
local no_eq = MiniTest.expect.no_equality

--- The buffer of the child's first window, which is Claude's in the layout.
local CLAUDE_WINDOW_BUFFER = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- The MCP servers of the report home for the child's own address and
--- program, as Claude Code's `--mcp-config` takes them, read in the child.
local REPORT_SERVERS = "require('aineo.mcp').mcp_servers(vim.v.servername, vim.v.progpath)"

--- The instructions for the report tool, read in the child.
local REPORT_INSTRUCTIONS =
  "require('aineo.report').report_instructions(require('aineo.mcp').report_tool_name())"

--- What Claude's terminal receives when Send sends an Input holding `hello`:
--- one bracketed paste, then Enter.
local SENT_HELLO = '\27[200~hello\27[201~\r'

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

T[':Aineo'] = MiniTest.new_set()

T[':Aineo']['without an argument tells the user its five subcommands and does nothing else'] = function()
  child.cmd('Aineo')

  eq(entry.messages(child), { { message = entry.USAGE, level = vim.log.levels.ERROR } })
  eq(entry.windows(child), { '' })
end

T[':Aineo']['completes its argument to its five subcommands'] = function()
  eq(child.fn.getcompletion('Aineo ', 'cmdline'), { 'send', 'open', 'report', 'input', 'claude' })
end

T[':Aineo']['completes the subcommands that begin with what is typed'] = function()
  eq(child.fn.getcompletion('Aineo re', 'cmdline'), { 'report' })
end

T[':Aineo']['with another argument tells the user its five subcommands and does nothing else'] = function()
  child.cmd('Aineo reports')

  eq(entry.messages(child), { { message = entry.USAGE, level = vim.log.levels.ERROR } })
  eq(entry.windows(child), { '' })
end

T[':Aineo']['with a subcommand and more tells the user its five subcommands and does nothing else'] = function()
  local fake = claude_session.fake('entry-usage-extra', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open extra')

  eq(entry.messages(child), { { message = entry.USAGE, level = vim.log.levels.ERROR } })
  eq(entry.windows(child), { '' })
end

T[':Aineo']['with a subcommand and a space after it runs the subcommand'] = function()
  local fake = claude_session.fake('entry-open-trailing-space', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open ')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(entry.messages(child), {})
end

T[':Aineo']['followed by a bar runs the subcommand, then the command after the bar'] = function()
  local fake = claude_session.fake('entry-open-bar', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open | let g:entry_after_bar = 1')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(child.g.entry_after_bar, 1)
end

T[':Aineo open'] = MiniTest.new_set()

T[':Aineo open']['starts Claude in the layout, beside the Report above Input'] = function()
  local fake = claude_session.fake('entry-open', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(#claude_session.wait_for_starts(fake, 1), 1)
end

T[':Aineo open']["hands Claude this editor's report server"] = function()
  local fake = claude_session.fake('entry-open-servers', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  eq(
    claude_session.decoded_words_after(claude_session.arguments(fake), '--mcp-config'),
    { { mcpServers = child.lua_get(REPORT_SERVERS) } }
  )
end

T[':Aineo open']['lets Claude call the report tool without asking'] = function()
  local fake = claude_session.fake('entry-open-tools', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  eq(
    claude_session.words_after(claude_session.arguments(fake), '--allowedTools'),
    child.lua_get("require('aineo.mcp').allowed_mcp_tools()")
  )
end

T[':Aineo open']['tells Claude when and how to call the report tool'] = function()
  local fake = claude_session.fake('entry-open-instructions', 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  eq(
    claude_session.words_after(claude_session.arguments(fake), '--append-system-prompt'),
    { child.lua_get(REPORT_INSTRUCTIONS) }
  )
end

T[':Aineo open']["runs Claude in the editor's working directory"] = function()
  local fake = claude_session.fake('entry-open-cwd', 'ready')
  entry.use_fake(child, fake)
  child.fn.chdir(fixture.directory('entry-open-cwd-directory'))

  child.cmd('Aineo open')

  eq(claude_session.wait_for_start(fake).cwd, child.fn.getcwd())
end

T[':Aineo open']['with a wrong setting tells the user once, naming it, and opens nothing'] = function()
  local fake = claude_session.fake('entry-open-wrong-setting', 'ready')
  entry.use_fake(child, fake, { layout = { report_height = 2 } })

  entry.command(child, 'Aineo open')

  eq(entry.messages(child), {
    {
      message = 'aineo: layout.report_height: expected a number strictly between 0 and 1, got 2',
      level = vim.log.levels.ERROR,
    },
  })
  eq(entry.windows(child), { '' })
end

T[':Aineo open']['with a command that cannot run tells the user once, on one line naming it'] = function()
  local fake = claude_session.fake('entry-open-no-such-command', 'ready')
  entry.use_fake(child, fake, { claude = { cmd = { 'aineo-no-such-claude' } } })

  entry.command(child, 'Aineo open')

  eq(entry.messages(child), {
    {
      message = "aineo: claude.cmd: 'aineo-no-such-claude' is not executable",
      level = vim.log.levels.ERROR,
    },
  })
  eq(entry.windows(child), { '' })
end

T[':Aineo open']['with a key no setting knows opens without a word'] = function()
  local fake = claude_session.fake('entry-open-unknown-key', 'ready')
  entry.use_fake(child, fake, { claude = { command = 'claude' }, autostrat = false })

  child.cmd('Aineo open')

  eq(entry.messages(child), {})
  eq(child.cmd_capture('messages'), '')
  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
end

T[':Aineo open']['again while Claude runs restores the layout and starts nothing'] = function()
  local fake = claude_session.fake('entry-open-again', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  local running_terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)
  child.cmd('only')

  child.cmd('Aineo open')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(child.lua_get(CLAUDE_WINDOW_BUFFER), running_terminal)
end

T[':Aineo open']['after Claude has exited starts a new Claude in the layout'] = function()
  local fake = claude_session.fake('entry-open-after-exit', 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  local exited_terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)

  child.cmd('Aineo open')

  eq(#claude_session.wait_for_starts(fake, 2), 2)
  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  no_eq(child.lua_get(CLAUDE_WINDOW_BUFFER), exited_terminal)
end

--- The focus subcommands, each with what the window it moves to shows.
local FOCUS_SUBCOMMANDS = {
  { 'report', 'aineo://report' },
  { 'input', 'aineo://input' },
  { 'claude', 'terminal' },
}

T[':Aineo report, input and claude'] = MiniTest.new_set({ parametrize = FOCUS_SUBCOMMANDS })

T[':Aineo report, input and claude']['move the cursor to their window of the layout'] = function(
  subcommand,
  shown
)
  local fake = claude_session.fake('entry-focus-' .. subcommand, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  child.cmd('tabnew')

  child.cmd('Aineo ' .. subcommand)

  eq(entry.current_window(child), shown)
end

T[':Aineo report, input and claude']['open the layout around a new Claude when it is closed'] = function(
  subcommand,
  shown
)
  local fake = claude_session.fake('entry-focus-closed-' .. subcommand, 'ready')
  entry.use_fake(child, fake)

  child.cmd('Aineo ' .. subcommand)

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(entry.current_window(child), shown)
  eq(#claude_session.wait_for_starts(fake, 1), 1)
end

--- The expression, run in the child, that tells where Claude's session
--- stands (`aineo.claude`'s `session_status()`).
local SESSION_STATE = "require('aineo.claude').session_status()"

T[':Aineo report, input and claude']['after Claude has exited move to their window and keep its exit on screen'] = function(
  subcommand,
  shown
)
  local fake = claude_session.fake('entry-focus-after-exit-' .. subcommand, 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  local exited_terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)
  child.cmd('tabnew')

  child.cmd('Aineo ' .. subcommand)

  eq(entry.current_window(child), shown)
  eq(child.lua_get(CLAUDE_WINDOW_BUFFER), exited_terminal)
  eq(child.lua_get(SESSION_STATE), 'exited')
end

T[':Aineo report, input and claude']['after Claude has exited reopen the closed layout around its exit'] = function(
  subcommand,
  shown
)
  local fake = claude_session.fake('entry-focus-closed-after-exit-' .. subcommand, 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  local exited_terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)
  child.cmd('tabnew')
  child.cmd('tabonly')

  child.cmd('Aineo ' .. subcommand)

  eq(entry.current_window(child), shown)
  eq(child.lua_get(CLAUDE_WINDOW_BUFFER), exited_terminal)
  eq(child.lua_get(SESSION_STATE), 'exited')
end

T[':Aineo report after Claude has exited and its terminal was wiped'] = MiniTest.new_set()

T[':Aineo report after Claude has exited and its terminal was wiped']['moves to the open Report and starts nothing'] = function()
  local fake = claude_session.fake('entry-focus-after-wipe', 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  child.cmd('bwipeout! ' .. child.lua_get(CLAUDE_WINDOW_BUFFER))

  child.cmd('Aineo report')

  eq(entry.current_window(child), 'aineo://report')
  eq(child.lua_get(SESSION_STATE), 'exited')
end

T[':Aineo report after Claude has exited and its terminal was wiped']['starts a new Claude when the layout is closed'] = function()
  local fake = claude_session.fake('entry-focus-closed-after-wipe', 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  child.cmd('bwipeout! ' .. child.lua_get(CLAUDE_WINDOW_BUFFER))
  child.cmd('tabnew')
  child.cmd('tabonly')

  child.cmd('Aineo report')

  eq(entry.current_window(child), 'aineo://report')
  eq(#claude_session.wait_for_starts(fake, 2), 2)
end

T['<Plug>(aineo-open)'] = MiniTest.new_set()

T['<Plug>(aineo-open)']['starts Claude in the layout, beside the Report above Input'] = function()
  local fake = claude_session.fake('entry-plug-open', 'ready')
  entry.use_fake(child, fake)

  entry.press(child, '<Plug>(aineo-open)')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(#claude_session.wait_for_starts(fake, 1), 1)
end

T['<Plug>(aineo-report), (aineo-input) and (aineo-claude)'] =
  MiniTest.new_set({ parametrize = FOCUS_SUBCOMMANDS })

T['<Plug>(aineo-report), (aineo-input) and (aineo-claude)']['move the cursor to their window of the layout'] = function(
  subcommand,
  shown
)
  local fake = claude_session.fake('entry-plug-focus-' .. subcommand, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  child.cmd('tabnew')

  entry.press(child, '<Plug>(aineo-' .. subcommand .. ')')

  eq(entry.current_window(child), shown)
end

T['the prefix typed'] = MiniTest.new_set()

T['the prefix typed']['\\o starts Claude in the layout, beside the Report above Input'] = function()
  local fake = claude_session.fake('entry-prefix-typed-open', 'ready')
  entry.use_fake(child, fake)

  entry.press(child, '\\o')

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(#claude_session.wait_for_starts(fake, 1), 1)
end

T['the prefix typed']['\\r moves the cursor to the Report'] = function()
  local fake = claude_session.fake('entry-prefix-typed-report', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  child.cmd('tabnew')

  entry.press(child, '\\r')

  eq(entry.current_window(child), 'aineo://report')
end

T['<Plug>(aineo-send)'] = MiniTest.new_set()

T['<Plug>(aineo-send)']["sends Input's text to Claude"] = function()
  local fake = claude_session.fake('entry-plug-send', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.set_input(child, { 'hello' })
  local received_before = #claude_session.received(fake)

  entry.press(child, '<Plug>(aineo-send)')

  eq(claude_session.wait_for_received_after(fake, received_before, #SENT_HELLO), SENT_HELLO)
  eq(entry.messages(child), {})
end

T[':Aineo send'] = MiniTest.new_set()

T[':Aineo send']["sends Input's text to Claude"] = function()
  local fake = claude_session.fake('entry-send', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.set_input(child, { 'hello' })
  local received_before = #claude_session.received(fake)

  child.cmd('Aineo send')

  eq(claude_session.wait_for_received_after(fake, received_before, #SENT_HELLO), SENT_HELLO)
end

return T
