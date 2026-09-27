local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the child, that tells the mode it is in, as
--- `nvim_get_mode()` names it: `t` in Terminal mode, `nt` in Normal mode in a
--- terminal's window.
local MODE = 'vim.api.nvim_get_mode().mode'

--- The expression, run in the child, that gives the terminal shown in the
--- child's first window, which is Claude's in the layout.
local CLAUDE_WINDOW_BUFFER = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- Gives `child` the state directory `state`, where aineo keeps what it
--- keeps for a working directory, before aineo first reads it.
---
---@param child table
---@param state string
local function use_state_directory(child, state)
  child.lua('vim.env.XDG_STATE_HOME = ...', { state })
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

--- Opens the layout in `child` with aineo running the fake `claude` under
--- `name`, keeping conversations as Claude Code does, and a state
--- directory of its own; ends that Claude Code before anything was sent to
--- it and opens the layout again, which resumes its session, which Claude
--- Code has no conversation for. Waits until the new session aineo starts
--- in its place is ready, and returns the fake.
---
---@param child table
---@param name string the test's own name for its files
---@return { record: string, environment: table<string, string> }
local function open_after_a_resume_with_no_conversation(child, name)
  local fake = claude_session.fake(name, 'ready', {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory(name .. '-conversations'),
  })
  use_state_directory(child, fixture.directory(name .. '-state'))
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  end_claude_code(child)
  child.cmd('Aineo open')
  eq(#claude_session.wait_for_starts(fake, 3), 3)
  eq(claude_session.wait_for_status(child, 'ready'), { 'ready' })
  return fake
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

T["Claude's session"] = MiniTest.new_set()

T["Claude's session"]['resumes, in a new Neovim, the session aineo kept for the directory'] = function()
  local state = fixture.directory('entry-resume-new-neovim-state')
  local fake = claude_session.fake('entry-resume-new-neovim', 'ready')
  use_state_directory(child, state)
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  end_claude_code(child)
  entry.restart(child)
  use_state_directory(child, state)
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  local starts = claude_session.wait_for_starts(fake, 2)
  eq(#claude_session.words_after(starts[1].argv, '--session-id'), 1)
  eq(
    claude_session.words_after(starts[2].argv, '--resume'),
    claude_session.words_after(starts[1].argv, '--session-id')
  )
end

T["Claude's session"]['follows :cd, each directory resuming its own session'] = function()
  local elsewhere = fixture.directory('entry-resume-cd-elsewhere')
  local fake = claude_session.fake('entry-resume-cd', 'ready')
  use_state_directory(child, fixture.directory('entry-resume-cd-state'))
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  end_claude_code(child)
  child.cmd('cd ' .. elsewhere)
  entry.press(child, '\\o')
  claude_session.wait_for_starts(fake, 2)
  end_claude_code(child)
  child.cmd('cd -')

  entry.press(child, '\\o')

  local starts = claude_session.wait_for_starts(fake, 3)
  eq(starts[2].cwd, elsewhere)
  eq(#claude_session.words_after(starts[2].argv, '--session-id'), 1)
  MiniTest.expect.no_equality(
    claude_session.words_after(starts[2].argv, '--session-id'),
    claude_session.words_after(starts[1].argv, '--session-id')
  )
  eq(
    claude_session.words_after(starts[3].argv, '--resume'),
    claude_session.words_after(starts[1].argv, '--session-id')
  )
end

T["Claude's session"]["keeps the session's id under the editor's state directory"] = function()
  local state = fixture.directory('entry-resume-kept-where-state')
  local fake = claude_session.fake('entry-resume-kept-where', 'ready')
  use_state_directory(child, state)
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  local id = claude_session.words_after(claude_session.wait_for_start(fake).argv, '--session-id')
  local kept = vim.fs.joinpath(
    state,
    'nvim',
    'aineo',
    'claude-sessions',
    vim.fn.sha256(vim.fn.getcwd()) .. '.txt'
  )
  eq(vim.fn.filereadable(kept), 1)
  eq(vim.fn.readfile(kept, 'b'), id)
end

T["Claude's session"]["starts on \\o after an exit in Claude's window, which the user pinned with winfixbuf"] = function()
  local fake = claude_session.fake('entry-resume-pinned', 'ready')
  use_state_directory(child, fixture.directory('entry-resume-pinned-state'))
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  end_claude_code(child)
  local ended = child.lua_get(CLAUDE_WINDOW_BUFFER)
  local window = child.fn.win_getid(1)
  child.api.nvim_set_option_value('winfixbuf', true, { win = window, scope = 'local' })

  entry.command(child, 'Aineo open')

  eq(entry.messages(child), {})
  eq(claude_session.wait_for_status(child, 'ready'), { 'ready' })
  eq({
    child.api.nvim_buf_is_valid(ended),
    child.lua_get(('vim.bo[%s].buftype'):format(CLAUDE_WINDOW_BUFFER)),
    child.api.nvim_get_option_value('winfixbuf', { win = window }),
  }, { false, 'terminal', true })
end

T['after a resume with no conversation'] = MiniTest.new_set()

T['after a resume with no conversation, before any \\c'] = MiniTest.new_set()

T['after a resume with no conversation, before any \\c']["moves a file opened in Claude's window to the file column"] = function()
  local file = fixture.write('entry-resume-file/file.txt', { 'text' })
  open_after_a_resume_with_no_conversation(child, 'entry-resume-file')
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')

  entry.command(child, 'edit ' .. file)

  eq(entry.messages(child), {})
  eq(entry.windows(child), { 'terminal', file, 'aineo://report', 'aineo://input' })
end

T['after a resume with no conversation']["\\c enters Terminal mode in the new session's terminal"] = function()
  local fake = open_after_a_resume_with_no_conversation(child, 'entry-resume-focus')

  child.type_keys('\\c')

  eq(child.lua_get(MODE), 't')
  eq(child.api.nvim_get_current_buf(), child.lua_get(CLAUDE_WINDOW_BUFFER))
  eq(#claude_session.wait_for_starts(fake, 3), 3)
end

T['after a resume with no conversation, before any \\c']["returns Normal mode as the new session's process ends, entered by a window command and i"] = function()
  open_after_a_resume_with_no_conversation(child, 'entry-resume-exit-mode')
  child.type_keys('<C-w>t', 'i')
  eq(child.lua_get(MODE), 't')

  end_claude_code(child)

  eq(child.lua_get(MODE), 'nt')
end

T['after a resume with no conversation, before any \\c']["closes Claude's window as the new session's ended terminal is wiped from it"] = function()
  open_after_a_resume_with_no_conversation(child, 'entry-resume-wiped')
  end_claude_code(child)
  child.type_keys('<C-w>t')
  child.v.errmsg = ''

  entry.command(child, 'bwipeout!')

  eq(entry.messages(child), {})
  eq(child.v.errmsg, '')
  eq(entry.windows(child), { 'aineo://report', 'aineo://input' })
end

T['after a resume with no conversation, before any \\c']["refuses Terminal mode in the new session's ended terminal"] = function()
  open_after_a_resume_with_no_conversation(child, 'entry-resume-refused-mode')
  end_claude_code(child)
  child.type_keys('<C-w>t')

  child.type_keys('i')

  eq(child.lua_get(MODE), 'nt')
end

T['after a resume with no conversation, before any \\c']["shows the new session's exit on \\c, starting nothing"] = function()
  local fake = open_after_a_resume_with_no_conversation(child, 'entry-resume-exit-shown')
  local terminal = child.lua_get(CLAUDE_WINDOW_BUFFER)
  end_claude_code(child)

  child.type_keys('\\c')

  eq(child.lua_get(MODE), 'nt')
  eq(child.api.nvim_get_current_buf(), terminal)
  eq(#claude_session.wait_for_starts(fake, 4), 3)
end

T['after a resume with no conversation']['leaves the user in the tab they moved to before it'] = function()
  local fake = claude_session.fake('entry-resume-tab', 'ready', {
    AINEO_FAKE_CLAUDE_CONVERSATIONS = fixture.directory('entry-resume-tab-conversations'),
  })
  use_state_directory(child, fixture.directory('entry-resume-tab-state'))
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  end_claude_code(child)
  child.cmd('Aineo open')
  child.cmd('tabnew')

  eq(#claude_session.wait_for_starts(fake, 3), 3)

  eq(claude_session.wait_for_status(child, 'ready'), { 'ready' })
  eq(child.fn.tabpagenr(), 2)
end

return T
