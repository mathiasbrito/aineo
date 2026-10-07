local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The working directory the cases keep a draft for: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/aineo'

--- How long a case waits for the draft's delayed save, or for the child to
--- reach a state: longer than the delay.
local PATIENCE_MS = 5000

--- Longer than the draft's delayed save, which a case lets pass to show
--- that it wrote nothing: no state of the editor tells that it never will.
local SAVE_DELAY_AND_MARGIN_MS = 1500

local child = MiniTest.new_child_neovim()

--- The file that keeps the draft for `WORKING_DIRECTORY` under the state
--- directory `state`.
---
---@param state string
---@return string
local function directory_draft_file(state)
  return vim.fs.joinpath(state, 'aineo', 'drafts', vim.fn.sha256(WORKING_DIRECTORY) .. '.txt')
end

--- The file that keeps the draft for the Claude session `session` under the
--- state directory `state`.
---
---@param state string
---@param session string
---@return string
local function session_draft_file(state, session)
  return vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(session) .. '.txt')
end

--- Writes `text` as the whole of `file`, making its directory.
---
---@param file string
---@param text string
local function plant_draft(file, text)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  vim.fn.writefile(vim.split(text, '\n', { plain = true }), file, 'b')
end

--- The whole text of the file at `path`, or nil when it cannot be read.
---
---@param path string
---@return string|nil
local function read_text(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- Waits, at most `PATIENCE_MS`, until the file at `path` holds `text`, and
--- returns what it holds then.
---
---@param path string
---@param text string|nil
---@return string|nil
local function wait_for_text(path, text)
  vim.wait(PATIENCE_MS, function()
    return read_text(path) == text
  end, 20)
  return read_text(path)
end

--- Gives the child's draft home its environment, the state directory
--- `state` and `WORKING_DIRECTORY`, with the file writes `_G.draft_files`
--- when a case has set them there, and hands it a new, empty scratch buffer
--- shown in the current window, as the layout's Input is; the buffer is
--- `_G.input` there.
---
---@param state string
local function keep_new_buffer(state)
  child.lua(
    [[
      local state, working_directory = ...
      local draft = require('aineo.draft')
      draft.set_draft_environment({
        state_directory = state,
        working_directory = working_directory,
        files = _G.draft_files,
      })
      _G.input = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, _G.input)
      draft.keep_draft(_G.input)
    ]],
    { state, WORKING_DIRECTORY }
  )
end

--- Tells the child's draft home to follow the Claude session `session`.
---
---@param session string
local function follow(session)
  child.lua("require('aineo.draft').follow_draft_session(...)", { session })
end

--- Replaces the text of the kept buffer, `_G.input` in the child, with
--- `lines`, as a change through the API does.
---
---@param lines string[]
local function set_input(lines)
  child.lua('vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...)', { lines })
end

--- The lines of the kept buffer, `_G.input` in the child.
---
---@return string[]
local function input_lines()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.input, 0, -1, true)')
end

--- Keeps in the child the message of every warning it gives, in
--- `_G.warnings`, rather than showing it.
local KEEP_WARNINGS = [[
  _G.warnings = {}
  vim.notify = function(message, level)
    if level == vim.log.levels.WARN then
      table.insert(_G.warnings, message)
    end
  end
]]

--- The expression, run in the child, that counts the warnings it gave that
--- a draft could not be moved.
local MOVE_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find("cannot move Input's draft", 1, true) ~= nil
end, _G.warnings)]]

--- Ways an expression mapping holds textlock while the child's main loop
--- runs, as a set's `parametrize`: the name of the hold, the Lua call that
--- waits, and the keys that end the wait. `SafeState` fires inside
--- `input()`'s wait, and Neovim refuses a change there too.
local TEXTLOCK_HOLDS = {
  { 'an expression mapping waiting for a key', 'vim.fn.getcharstr()', 'q' },
  { 'an expression mapping waiting in input()', "vim.fn.input('> ')", '<CR>' },
}

--- Maps `X`, in the child's Normal mode, to an expression that makes the
--- Lua call `wait`, holding textlock until it returns, and then returns
--- `keys`, which Neovim then runs as typed, or nothing when not given; and
--- presses it. Waits, at most `PATIENCE_MS`, until it holds. `_G.holding`
--- is true while it holds.
---
---@param wait string
---@param keys? string
local function begin_hold(wait, keys)
  child.lua(([[
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      %s
      _G.holding = false
      return %q
    end, { expr = true })
  ]]):format(wait, keys or ''))
  child.api.nvim_input('X')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == true')
  end, 10)
end

--- Ends the child's hold (`begin_hold()`) with `keys`, and waits, at most
--- `PATIENCE_MS`, until it has ended.
---
---@param keys string
local function end_hold(keys)
  child.api.nvim_input(keys)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.holding == false')
  end, 10)
end

--- The expression, run in the child, that counts the autocommands waiting
--- for its `SafeState`.
local RETRIES = "#vim.api.nvim_get_autocmds({ event = 'SafeState' })"

--- The expression, run in the child, that counts the warnings it gave that
--- a draft could not be read.
local READ_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find("cannot read Input's draft", 1, true) ~= nil
end, _G.warnings)]]

--- The expression, run in the child, that counts the warnings it gave that
--- a draft could not be kept.
local WRITE_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find("cannot keep Input's draft", 1, true) ~= nil
end, _G.warnings)]]

--- The expression, run in the child, that counts the warnings it gave that
--- Input kept its text at a session switch.
local KEPT_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find('Input keeps its text', 1, true) ~= nil
end, _G.warnings)]]

--- The expression, run in the child, that counts the warnings it gave that
--- Input's text is not saved, its session's draft being unreadable.
local UNSAVED_WARNINGS = [[#vim.tbl_filter(function(message)
  return message:find("Input's text is not saved", 1, true) ~= nil
end, _G.warnings)]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['following a session'] = MiniTest.new_set()

T['following a session']["puts its draft into Input in place of Input's text, and keeps the next change for it"] = function()
  local state = fixture.directory('draft-sessions-puts')
  plant_draft(session_draft_file(state, 'session-a'), 'Kept for the session\n')
  keep_new_buffer(state)
  set_input({ 'Typed before' })

  follow('session-a')
  local shown = input_lines()
  set_input({ 'Typed for the session' })

  eq({
    shown = shown,
    saved = wait_for_text(session_draft_file(state, 'session-a'), 'Typed for the session\n'),
  }, {
    shown = { 'Kept for the session' },
    saved = 'Typed for the session\n',
  })
end

T['following a session']["refuses an id that is not a string, naming it, and leaves Input's text and session"] =
  MiniTest.new_set({
    parametrize = { { 'nil' }, { '{}' }, { '7' } },
  })

T['following a session']["refuses an id that is not a string, naming it, and leaves Input's text and session"]['as the id'] = function(
  id
)
  local state = fixture.directory('draft-sessions-not-an-id')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })

  local refusal = child.lua_get(([[(function()
    local followed, failure = pcall(require('aineo.draft').follow_draft_session, %s)
    return { followed = followed, named = tostring(failure):find('session_id', 1, true) ~= nil }
  end)()]]):format(id))
  child.lua('vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, {})')

  eq({
    refusal = refusal,
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
  }, {
    refusal = { followed = false, named = true },
    shown = { '' },
    first = '',
  })
end

T['following a session']['with no draft empties Input'] = function()
  local state = fixture.directory('draft-sessions-none')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })

  follow('session-new')

  eq(input_lines(), { '' })
end

T['following a session']['back brings back the text Input held for it'] = function()
  local state = fixture.directory('draft-sessions-back')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  local saved =
    wait_for_text(session_draft_file(state, 'session-a'), 'Notes for the first session\n')
  follow('session-b')
  local on_second = input_lines()

  follow('session-a')

  eq({ saved = saved, on_second = on_second, back = input_lines() }, {
    saved = 'Notes for the first session\n',
    on_second = { '' },
    back = { 'Notes for the first session' },
  })
end

T['following a session']['saves a change not saved yet as the draft of the session followed until then'] = function()
  local state = fixture.directory('draft-sessions-pending')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed a moment ago' })

  follow('session-b')

  eq({
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, {
    first = 'Typed a moment ago\n',
    second = nil,
  })
end

T['following a session']['puts its draft in as no change of the user: no undo takes it out, and no other session keeps it'] = function()
  local state = fixture.directory('draft-sessions-no-change')
  plant_draft(session_draft_file(state, 'session-a'), 'Kept for the first session\n')
  keep_new_buffer(state)
  set_input({ 'Typed before any session' })
  follow('session-a')
  child.cmd('normal! u')
  local undone_after_first = input_lines()

  follow('session-b')
  child.cmd('normal! u')

  eq({
    undone_after_first = undone_after_first,
    undone_after_second = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
  }, {
    undone_after_first = { 'Kept for the first session' },
    undone_after_second = { '' },
    first = 'Kept for the first session\n',
  })
end

T['following a session']["already followed leaves Input's text, cursor and undo as they were"] = function()
  local state = fixture.directory('draft-sessions-same')
  keep_new_buffer(state)
  follow('session-a')
  child.cmd('normal! iTyped for the session')
  child.api.nvim_win_set_cursor(0, { 1, 6 })

  follow('session-a')
  local after_follow = { lines = input_lines(), cursor = child.api.nvim_win_get_cursor(0) }
  child.cmd('normal! u')

  eq({ after_follow = after_follow, undone = input_lines() }, {
    after_follow = { lines = { 'Typed for the session' }, cursor = { 1, 6 } },
    undone = { '' },
  })
end

T["the working directory's draft"] = MiniTest.new_set()

T["the working directory's draft"]['becomes the first session followed'] = function()
  local state = fixture.directory('draft-sessions-moved')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  keep_new_buffer(state)

  follow('session-a')

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'From the directory' },
    directory = nil,
    session = 'From the directory\n',
  })
end

T["the working directory's draft"]['is left as it is when the session has a draft, which is shown'] = function()
  local state = fixture.directory('draft-sessions-both')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  plant_draft(session_draft_file(state, 'session-a'), 'From the session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    warnings = {},
    shown = { 'From the session' },
    directory = 'From the directory\n',
    session = 'From the session\n',
  })
end

T["the working directory's draft"]['moves to the first session followed with a change not saved yet'] = function()
  local state = fixture.directory('draft-sessions-moved-pending')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  keep_new_buffer(state)
  set_input({ 'Edited before the first follow' })

  follow('session-a')

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'Edited before the first follow' },
    directory = nil,
    session = 'Edited before the first follow\n',
  })
end

T["the working directory's draft"]['planted again is not moved at a later follow'] = function()
  local state = fixture.directory('draft-sessions-later')
  keep_new_buffer(state)
  follow('session-a')
  plant_draft(directory_draft_file(state), 'Written by an older aineo\n')

  follow('session-b')
  set_input({ 'Typed for the second session' })

  eq({
    shown = input_lines(),
    saved = wait_for_text(session_draft_file(state, 'session-b'), 'Typed for the second session\n'),
    directory = read_text(directory_draft_file(state)),
  }, {
    shown = { 'Typed for the second session' },
    saved = 'Typed for the second session\n',
    directory = 'Written by an older aineo\n',
  })
end

T["the working directory's draft"]['that cannot be moved is told once, and the session keeps its own'] = function()
  local state = fixture.directory('draft-sessions-unmovable')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  local drafts = vim.fs.dirname(directory_draft_file(state))
  vim.uv.fs_chmod(drafts, tonumber('500', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(drafts, tonumber('700', 8))
  end)
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ '' })
  vim.uv.fs_chmod(drafts, tonumber('700', 8))

  set_input({ 'Typed for the session' })

  eq({
    moves = child.lua_get(MOVE_WARNINGS),
    writes = child.lua_get(WRITE_WARNINGS),
    saved = wait_for_text(session_draft_file(state, 'session-a'), 'Typed for the session\n'),
    directory = read_text(directory_draft_file(state)),
  }, {
    moves = 1,
    writes = 1,
    saved = 'Typed for the session\n',
    directory = 'From the directory\n',
  })
end

--- The Lua that makes the child's next file move — its first call of
--- `vim.uv.fs_rename` or `vim.uv.fs_link` — first run
--- `_G.other_editor(from, to)`, what another editor does at that moment,
--- and then the call itself.
local OTHER_EDITOR_FIRST = [[
  local real = { fs_rename = vim.uv.fs_rename, fs_link = vim.uv.fs_link }
  for name, call in pairs(real) do
    vim.uv[name] = function(from, to)
      vim.uv.fs_rename, vim.uv.fs_link = real.fs_rename, real.fs_link
      _G.other_editor(from, to)
      return call(from, to)
    end
  end
]]

T["the working directory's draft"]['whose file cannot be removed once linked is told once'] = function()
  local state = fixture.directory('draft-sessions-unremovable')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(KEEP_WARNINGS)
  child.lua([[
    vim.uv.fs_unlink = function(path)
      return nil, 'EACCES: permission denied: ' .. path, 'EACCES'
    end
  ]])
  keep_new_buffer(state)

  follow('session-a')

  eq({
    moves = child.lua_get(MOVE_WARNINGS),
    session = read_text(session_draft_file(state, 'session-a')),
  }, { moves = 1, session = 'From the directory\n' })
end

T["the working directory's draft"]['taken by another editor first is told as no failure'] = function()
  local state = fixture.directory('draft-sessions-race-taken')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(KEEP_WARNINGS)
  child.lua(
    [[
      local other = ...
      _G.other_editor = function(from)
        assert(vim.uv.fs_rename(from, other))
      end
    ]],
    { session_draft_file(state, 'session-other') }
  )
  child.lua(OTHER_EDITOR_FIRST)
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    other = read_text(session_draft_file(state, 'session-other')),
  }, { warnings = {}, other = 'From the directory\n' })
end

T["the working directory's draft"]["never replaces a session's draft another editor made meanwhile"] = function()
  local state = fixture.directory('draft-sessions-race-made')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua([[
      _G.other_editor = function(from, to)
        vim.fn.writefile({ 'Kept by the other editor' }, to)
        vim.fn.writefile({ 'Written by an older aineo' }, from)
      end
    ]])
  child.lua(OTHER_EDITOR_FIRST)
  keep_new_buffer(state)

  follow('session-a')

  eq({
    session = read_text(session_draft_file(state, 'session-a')),
    directory = read_text(directory_draft_file(state)),
  }, {
    session = 'Kept by the other editor\n',
    directory = 'Written by an older aineo\n',
  })
end

--- The Lua that interleaves another editor's first follow with the child's,
--- one call at a time: the other editor links the file being moved to its
--- own session's file, given as the chunk's argument, just before the
--- child's link, and removes the moved file's name just before the child's
--- removal of it.
local OTHER_EDITOR_INTERLEAVED = [[
  local other = ...
  local real_link, real_unlink = vim.uv.fs_link, vim.uv.fs_unlink
  vim.uv.fs_link = function(from, to)
    vim.uv.fs_link = real_link
    assert(real_link(from, other))
    return real_link(from, to)
  end
  vim.uv.fs_unlink = function(path)
    vim.uv.fs_unlink = real_unlink
    assert(real_unlink(path))
    return real_unlink(path)
  end
]]

T["the working directory's draft"]['moved by another editor at the same moment stays that session draft alone'] = function()
  local state = fixture.directory('draft-sessions-race-interleaved')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(KEEP_WARNINGS)
  child.lua(OTHER_EDITOR_INTERLEAVED, { session_draft_file(state, 'session-other') })
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    shown = input_lines(),
    a = read_text(session_draft_file(state, 'session-a')),
    other = read_text(session_draft_file(state, 'session-other')),
  }, {
    warnings = {},
    shown = { '' },
    a = nil,
    other = 'From the directory\n',
  })
end

T["the working directory's draft"]['moved by another editor at the same moment is told so when the link cannot be removed'] = function()
  local state = fixture.directory('draft-sessions-race-unremovable')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  local from = directory_draft_file(state)
  local to = session_draft_file(state, 'session-a')
  child.lua(KEEP_WARNINGS)
  child.lua(OTHER_EDITOR_INTERLEAVED, { session_draft_file(state, 'session-other') })
  child.lua([[
    local interleaved = vim.uv.fs_unlink
    vim.uv.fs_unlink = function(path)
      local result = { interleaved(path) }
      vim.uv.fs_unlink = function(refused)
        return nil, 'EACCES: permission denied: ' .. refused, 'EACCES'
      end
      return unpack(result)
    end
  ]])
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    session = read_text(to),
  }, {
    warnings = {
      ("aineo: cannot move Input's draft in %s to %s: another editor moved it to its session at the same moment, and %s cannot be removed, so both sessions keep it: EACCES: permission denied: %s"):format(
        from,
        to,
        to,
        to
      ),
    },
    session = 'From the directory\n',
  })
end

--- The Lua that makes the child's next removal of a file find it gone, as
--- when a third party removes the working directory's draft between the
--- child's link of it to a session and its removal of it: the file is
--- removed just before the child's removal.
local REMOVED_MEANWHILE = [[
  local real_unlink = vim.uv.fs_unlink
  vim.uv.fs_unlink = function(path)
    vim.uv.fs_unlink = real_unlink
    assert(real_unlink(path))
    return real_unlink(path)
  end
]]

T["the working directory's draft"]['removed between the link and its removal stays the session draft'] = function()
  local state = fixture.directory('draft-sessions-race-removed')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(KEEP_WARNINGS)
  child.lua(REMOVED_MEANWHILE)
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    shown = input_lines(),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    warnings = {},
    shown = { 'From the directory' },
    session = 'From the directory\n',
  })
end

--- The Lua that makes the child's every hard link fail as a file system
--- refuses one, with the code given as the chunk's argument, as libuv
--- returns it.
local LINKS_REFUSED = [[
  local code = ...
  vim.uv.fs_link = function(from)
    return nil, code .. ': hard links refused: ' .. from, code
  end
]]

--- The codes a file system refuses a hard link with, as a set's
--- `parametrize`: no hard links on it (exFAT, FAT, some network and FUSE
--- mounts), a file on another device, or too many links.
local LINK_REFUSALS = { { 'ENOTSUP' }, { 'EPERM' }, { 'EXDEV' }, { 'EMLINK' }, { 'ENOSYS' } }

T["the working directory's draft"]['where hard links are refused'] = MiniTest.new_set({
  parametrize = LINK_REFUSALS,
})

T["the working directory's draft"]['where hard links are refused']['becomes the first session followed by a rename'] = function(
  code
)
  local state = fixture.directory('draft-sessions-no-links')
  plant_draft(directory_draft_file(state), 'Typed before any session\n')
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    warnings = {},
    shown = { 'Typed before any session' },
    directory = nil,
    session = 'Typed before any session\n',
  })
end

T["the working directory's draft"]['where hard links are refused']['is left as it is when the session has a draft'] = function(
  code
)
  local state = fixture.directory('draft-sessions-no-links-both')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  plant_draft(session_draft_file(state, 'session-a'), 'Kept for the session\n')
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    warnings = {},
    shown = { 'Kept for the session' },
    directory = 'From the directory\n',
    session = 'Kept for the session\n',
  })
end

T["the working directory's draft"]['where hard links are refused']['taken by another editor first is told as no failure'] = function(
  code
)
  local state = fixture.directory('draft-sessions-no-links-taken')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })
  child.lua(
    [[
      local other = ...
      _G.other_editor = function(from)
        assert(vim.uv.fs_rename(from, other))
      end
    ]],
    { session_draft_file(state, 'session-other') }
  )
  child.lua(OTHER_EDITOR_FIRST)
  keep_new_buffer(state)

  follow('session-a')

  eq({
    warnings = child.lua_get('_G.warnings'),
    other = read_text(session_draft_file(state, 'session-other')),
    session = read_text(session_draft_file(state, 'session-a')),
  }, { warnings = {}, other = 'From the directory\n', session = nil })
end

T["the working directory's draft"]['where hard links are refused']['that cannot be renamed is told once'] = function(
  code
)
  local state = fixture.directory('draft-sessions-no-links-unmovable')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  local drafts = vim.fs.dirname(directory_draft_file(state))
  child.lua(KEEP_WARNINGS)
  child.lua(LINKS_REFUSED, { code })
  keep_new_buffer(state)
  vim.uv.fs_chmod(drafts, tonumber('500', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(drafts, tonumber('700', 8))
  end)

  follow('session-a')
  vim.uv.fs_chmod(drafts, tonumber('700', 8))

  eq({
    moves = child.lua_get(MOVE_WARNINGS),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    moves = 1,
    directory = 'From the directory\n',
    session = nil,
  })
end

T["the working directory's draft"]['that is a symbolic link stays one at the first session followed, and its saves reach the file it leads to'] = function()
  local state = fixture.directory('draft-sessions-symbolic-link')
  local target = vim.fs.joinpath(state, 'kept-elsewhere.txt')
  plant_draft(target, 'Typed before any session\n')
  local directory = directory_draft_file(state)
  vim.fn.mkdir(vim.fs.dirname(directory), 'p')
  assert(vim.uv.fs_symlink(target, directory))
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)

  follow('session-a')
  set_input({ 'Typed after the follow' })
  wait_for_text(target, 'Typed after the follow\n')

  eq({
    warnings = child.lua_get('_G.warnings'),
    session = vim.fn.getftype(session_draft_file(state, 'session-a')),
    target = read_text(target),
  }, {
    warnings = {},
    session = 'link',
    target = 'Typed after the follow\n',
  })
end

T['a session told before the environment'] = MiniTest.new_set()

T['a session told before the environment']["is held: once it comes, the directory's draft moves to it, and Input is given its draft"] = function()
  local state = fixture.directory('draft-sessions-held')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  follow('session-a')

  keep_new_buffer(state)

  eq({
    shown = input_lines(),
    directory = read_text(directory_draft_file(state)),
    session = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'From the directory' },
    directory = nil,
    session = 'From the directory\n',
  })
end

T['a session told before the environment']['whose draft cannot be read keeps it from what is typed in Input, telling why'] = function()
  local state = fixture.directory('draft-sessions-held-unreadable')
  local session = session_draft_file(state, 'session-a')
  plant_draft(session, 'Kept for the session\n')
  vim.uv.fs_chmod(session, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(session, tonumber('600', 8))
  end)
  child.lua(KEEP_WARNINGS)
  follow('session-a')
  keep_new_buffer(state)

  set_input({ 'Typed for the session' })
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)
  vim.uv.fs_chmod(session, tonumber('600', 8))

  eq({
    reads = child.lua_get(READ_WARNINGS),
    unsaved = child.lua_get(UNSAVED_WARNINGS),
    session = read_text(session),
  }, {
    reads = 1,
    unsaved = 1,
    session = 'Kept for the session\n',
  })
end

T['a follow refused while textlock holds'] = MiniTest.new_set()

T['a follow refused while textlock holds']["puts the session's draft into Input once the hold ends, with no retry left"] =
  MiniTest.new_set({ parametrize = TEXTLOCK_HOLDS })

T['a follow refused while textlock holds']["puts the session's draft into Input once the hold ends, with no retry left"]['under'] = function(
  _,
  wait,
  release
)
  local state = fixture.directory('draft-sessions-textlock')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  child.lua(KEEP_WARNINGS)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold(wait)

  follow('session-b')
  local meanwhile = {
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    retries = child.lua_get(RETRIES),
  }
  end_hold(release)

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  eq({
    meanwhile = meanwhile,
    shown = input_lines(),
    retries = child.lua_get(RETRIES),
    warnings = child.lua_get('_G.warnings'),
  }, {
    meanwhile = {
      shown = { 'Typed for the first session' },
      first = 'Typed for the first session\n',
      retries = 1,
    },
    shown = { 'Kept for the second session' },
    retries = 0,
    warnings = {},
  })
end

T['two editors on one session'] = MiniTest.new_set()

T['two editors on one session']['a follow back shows the draft another editor kept for the session meanwhile'] = function()
  local state = fixture.directory('draft-sessions-other-editor')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed here' })
  follow('session-b')
  plant_draft(session_draft_file(state, 'session-a'), 'Typed in another editor\n')

  follow('session-a')

  eq(input_lines(), { 'Typed in another editor' })
end

T['two editors on one session']['a follow writes nothing back over the draft another editor keeps for it'] = function()
  local state = fixture.directory('draft-sessions-no-write-back')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Read at the follow\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  follow('session-b')

  plant_draft(second, 'Written by the other editor since\n')
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq(read_text(second), 'Written by the other editor since\n')
end

T['a draft that cannot be read'] = MiniTest.new_set()

T['a draft that cannot be read']['is left as it is by a follow, which tells it once'] = function()
  local state = fixture.directory('draft-sessions-unreadable')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)

  follow('session-b')
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)
  vim.uv.fs_chmod(second, tonumber('600', 8))

  eq({
    reads = child.lua_get(READ_WARNINGS),
    second = read_text(second),
  }, { reads = 1, second = 'Kept for the second session\n' })
end

T['a draft that cannot be read']['empties Input at a follow, which keeps no later change as the old session draft'] = function()
  local state = fixture.directory('draft-sessions-unreadable-empties')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)

  follow('session-b')
  local shown = input_lines()
  set_input({ 'Typed after the follow' })
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({ shown = shown, first = read_text(session_draft_file(state, 'session-a')) }, {
    shown = { '' },
    first = 'Notes for the first session\n',
  })
end

T['a draft that cannot be read']['of the working directory, before any follow, is replaced by the first change'] = function()
  local state = fixture.directory('draft-sessions-unreadable-directory')
  local directory = directory_draft_file(state)
  plant_draft(directory, 'From the directory\n')
  vim.uv.fs_chmod(directory, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(directory, tonumber('600', 8))
  end)
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)

  set_input({ 'Typed before any session' })

  eq(wait_for_text(directory, 'Typed before any session\n'), 'Typed before any session\n')
end

T['a draft that cannot be read']['is told at each follow to its session'] = function()
  local state = fixture.directory('draft-sessions-unreadable-each-follow')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)

  follow('session-b')
  follow('session-a')
  follow('session-b')

  eq(child.lua_get(READ_WARNINGS), 2)
end

T['a draft that cannot be read']['is told once at a follow to its session that waits while textlock holds'] = function()
  local state = fixture.directory('draft-sessions-unreadable-textlock')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  begin_hold('vim.fn.getcharstr()')

  follow('session-b')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({ reads = child.lua_get(READ_WARNINGS), shown = input_lines() }, { reads = 1, shown = { '' } })
end

T['a draft that cannot be read']['readable again at a later follow to its session takes what is typed'] = function()
  local state = fixture.directory('draft-sessions-unreadable-readable-again')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  follow('session-b')
  follow('session-a')
  vim.uv.fs_chmod(second, tonumber('600', 8))
  follow('session-b')
  local shown = input_lines()

  set_input({ 'Typed once it is readable' })

  eq({
    shown = shown,
    second = wait_for_text(second, 'Typed once it is readable\n'),
    unsaved = child.lua_get(UNSAVED_WARNINGS),
  }, {
    shown = { 'Kept for the second session' },
    second = 'Typed once it is readable\n',
    unsaved = 0,
  })
end

T['a draft that cannot be read']['is not replaced by what is typed while Input follows its session'] = function()
  local state = fixture.directory('draft-sessions-unreadable-typed')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  follow('session-b')

  set_input({ 'Typed on the second session' })
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)
  vim.uv.fs_chmod(second, tonumber('600', 8))

  eq(read_text(second), 'Kept for the second session\n')
end

T['a draft that cannot be read']["tells again, at the first change after each follow to its session, that Input's text is not saved"] = function()
  local state = fixture.directory('draft-sessions-unreadable-told-again')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  follow('session-b')
  set_input({ 'Typed on the second session' })
  set_input({ '' })
  follow('session-a')
  follow('session-b')

  set_input({ 'Typed on the second session again' })

  eq(child.lua_get(UNSAVED_WARNINGS), 2)
end

T['a draft that cannot be read']['keeps what was typed for its session in Input at the next follow, telling why'] = function()
  local state = fixture.directory('draft-sessions-unreadable-kept')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  plant_draft(session_draft_file(state, 'session-c'), 'Kept for the third session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  follow('session-b')
  set_input({ 'Typed on the second session' })

  follow('session-c')
  vim.uv.fs_chmod(second, tonumber('600', 8))

  eq({
    shown = input_lines(),
    kept = child.lua_get(KEPT_WARNINGS),
    second = read_text(second),
    third = read_text(session_draft_file(state, 'session-c')),
  }, {
    shown = { 'Typed on the second session' },
    kept = 1,
    second = 'Kept for the second session\n',
    third = 'Kept for the third session\n',
  })
end

T['a draft that cannot be read']['lets an emptied Input take the next session draft, writing nothing'] = function()
  local state = fixture.directory('draft-sessions-unreadable-emptied')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  plant_draft(session_draft_file(state, 'session-c'), 'Kept for the third session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  follow('session-b')
  set_input({ 'Typed on the second session' })
  set_input({ '' })

  follow('session-c')
  vim.uv.fs_chmod(second, tonumber('600', 8))

  eq({
    shown = input_lines(),
    kept = child.lua_get(KEPT_WARNINGS),
    second = read_text(second),
  }, {
    shown = { 'Kept for the third session' },
    kept = 0,
    second = 'Kept for the second session\n',
  })
end

T['a draft that cannot be read']["tells at the first change after the follow, once, that Input's text is not saved"] = function()
  local state = fixture.directory('draft-sessions-unreadable-told')
  local second = session_draft_file(state, 'session-b')
  plant_draft(second, 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  keep_new_buffer(state)
  follow('session-a')
  vim.uv.fs_chmod(second, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(second, tonumber('600', 8))
  end)
  follow('session-b')

  set_input({ 'Typed on the second session' })
  set_input({ 'Typed on the second session, and more' })
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({ unsaved = child.lua_get(UNSAVED_WARNINGS), warnings = child.lua_get('#_G.warnings') }, {
    unsaved = 1,
    warnings = 2,
  })
end

T['a follow refused while textlock holds']["keeps an emptying of Input made meanwhile as the old session's draft"] = function()
  local state = fixture.directory('draft-sessions-window-empty')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold('vim.fn.getcharstr()', 'ggdG')

  follow('session-b')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, {
    shown = { 'Kept for the second session' },
    first = '',
    second = 'Kept for the second session\n',
  })
end

T['a follow refused while textlock holds']["keeps an edit of Input made meanwhile as the old session's draft"] = function()
  local state = fixture.directory('draft-sessions-window-edit')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')

  follow('session-b')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, {
    shown = { 'Kept for the second session' },
    first = 'Typed for the first session and more\n',
    second = 'Kept for the second session\n',
  })
end

T['a follow refused while textlock holds']["keeps an edit made while Insert-mode completion keeps it waiting as the old session's"] = function()
  local state = fixture.directory('draft-sessions-window-completion')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  child.lua([[
    _G.complete = function(findstart)
      if findstart == 1 then
        return vim.fn.col('.') - 1
      end
      vim.defer_fn(function()
        require('aineo.draft').follow_draft_session('session-b')
      end, 20)
      vim.wait(200)
      return { 'alpha', 'alphabet', 'alphanumeric' }
    end
    vim.bo[_G.input].completefunc = 'v:lua._G.complete'
  ]])
  child.api.nvim_input('A <C-x><C-u>')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('vim.fn.pumvisible()') == 1
  end, 10)
  local refused = child.lua_get(RETRIES)
  child.api.nvim_input('<C-n>')
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)
  local second_meanwhile = read_text(session_draft_file(state, 'session-b'))

  child.api.nvim_input('<C-e><Esc>')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({
    refused = refused,
    second_meanwhile = second_meanwhile,
    second = read_text(session_draft_file(state, 'session-b')),
    shown = input_lines(),
  }, {
    refused = 1,
    second_meanwhile = 'Kept for the second session\n',
    second = 'Kept for the second session\n',
    shown = { 'Kept for the second session' },
  })
end

T['a session switch when the draft cannot be saved'] = MiniTest.new_set()

--- The Lua that makes every write of the child's draft home fail as on a
--- full disk, through `_G.draft_files`, which `keep_new_buffer()` hands it,
--- while `_G.full` is true there, as it is at first: a case frees the disk
--- by setting it false.
local WRITES_THAT_FAIL = [[
  _G.full = true
  _G.draft_files = {
    write = function(descriptor, text)
      if _G.full then
        return nil, 'ENOSPC: no space left on device'
      end
      return vim.uv.fs_write(descriptor, text)
    end,
  }
]]

T['a session switch when the draft cannot be saved']["leaves Input's text in Input, telling why"] = function()
  local state = fixture.directory('draft-sessions-unsaved')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  child.lua(WRITES_THAT_FAIL)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })

  follow('session-b')

  eq({ shown = input_lines(), kept = child.lua_get(KEPT_WARNINGS) }, {
    shown = { 'Notes for the first session' },
    kept = 1,
  })
end

T['a session switch when the draft cannot be saved']['tells it again at each switch'] = function()
  local state = fixture.directory('draft-sessions-unsaved-again')
  child.lua(KEEP_WARNINGS)
  child.lua(WRITES_THAT_FAIL)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  follow('session-b')
  set_input({ 'Notes for the second session' })

  follow('session-c')

  eq({ shown = input_lines(), kept = child.lua_get(KEPT_WARNINGS) }, {
    shown = { 'Notes for the second session' },
    kept = 2,
  })
end

T['a session switch when the draft cannot be saved']["keeps Input's text whose delayed save failed before the switch, telling why"] = function()
  local state = fixture.directory('draft-sessions-delayed-unsaved')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  child.lua(WRITES_THAT_FAIL)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)
  local writes_before = child.lua_get(WRITE_WARNINGS)

  follow('session-b')

  eq({
    writes_before = writes_before,
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    kept = child.lua_get(KEPT_WARNINGS),
  }, {
    writes_before = 1,
    shown = { 'Notes for the first session' },
    first = nil,
    kept = 1,
  })
end

T['a session switch when the draft cannot be saved']['saves the text whose delayed save failed once the disk is freed before the switch'] = function()
  local state = fixture.directory('draft-sessions-delayed-freed')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  child.lua(WRITES_THAT_FAIL)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)
  child.lua('_G.full = false')

  follow('session-b')

  eq({
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'Kept for the second session' },
    first = 'Notes for the first session\n',
  })
end

T['a session switch when the draft cannot be saved']['saves an emptying of Input whose save failed once the disk is freed before the switch'] = function()
  local state = fixture.directory('draft-sessions-emptying-freed')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  child.lua(KEEP_WARNINGS)
  child.lua(WRITES_THAT_FAIL)
  child.lua('_G.full = false')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  wait_for_text(session_draft_file(state, 'session-a'), 'Notes for the first session\n')
  child.lua('_G.full = true')
  set_input({ '' })
  child.lua('_G.full = false')

  follow('session-b')

  eq({
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
  }, {
    shown = { 'Kept for the second session' },
    first = '',
  })
end

T['a session switch when the draft cannot be saved']['keeps the text when its delayed save fails between two switches'] = function()
  local state = fixture.directory('draft-sessions-delayed-between')
  child.lua(KEEP_WARNINGS)
  child.lua(WRITES_THAT_FAIL)
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Notes for the first session' })
  follow('session-b')
  local shown_after_first = input_lines()
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  follow('session-c')

  eq({
    shown_after_first = shown_after_first,
    shown = input_lines(),
    kept = child.lua_get(KEPT_WARNINGS),
  }, {
    shown_after_first = { 'Notes for the first session' },
    shown = { 'Notes for the first session' },
    kept = 2,
  })
end

T['a follow refused while textlock holds']["followed twice, puts the last session's draft in and changes no draft"] = function()
  local state = fixture.directory('draft-sessions-textlock-twice')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  plant_draft(session_draft_file(state, 'session-c'), 'Kept for the third session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold('vim.fn.getcharstr()')
  follow('session-b')
  follow('session-c')
  local meanwhile = { shown = input_lines(), retries = child.lua_get(RETRIES) }
  end_hold('q')

  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({
    meanwhile = meanwhile,
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
    third = read_text(session_draft_file(state, 'session-c')),
  }, {
    meanwhile = { shown = { 'Typed for the first session' }, retries = 1 },
    shown = { 'Kept for the third session' },
    first = 'Typed for the first session\n',
    second = 'Kept for the second session\n',
    third = 'Kept for the third session\n',
  })
end

T['a follow refused while textlock holds']['keeps an edit made while the first follow waits with the draft it moved'] = function()
  local state = fixture.directory('draft-sessions-first-follow-window')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  keep_new_buffer(state)
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')
  follow('session-a')
  local waiting = child.lua_get(RETRIES)
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({
    waiting = waiting,
    shown = input_lines(),
    session = read_text(session_draft_file(state, 'session-a')),
    directory = read_text(directory_draft_file(state)),
  }, {
    waiting = 1,
    shown = { 'From the directory and more' },
    session = 'From the directory and more\n',
    directory = nil,
  })
end

T['a follow refused while textlock holds']['keeps an edit made while the first follow waits with the draft it moved, its first name removed meanwhile'] = function()
  local state = fixture.directory('draft-sessions-first-follow-window-removed')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(REMOVED_MEANWHILE)
  keep_new_buffer(state)
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')
  follow('session-a')
  local waiting = child.lua_get(RETRIES)
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({
    waiting = waiting,
    shown = input_lines(),
    session = read_text(session_draft_file(state, 'session-a')),
    directory = read_text(directory_draft_file(state)),
  }, {
    waiting = 1,
    shown = { 'From the directory and more' },
    session = 'From the directory and more\n',
    directory = nil,
  })
end

T['a follow refused while textlock holds']['keeps an edit made while the first follow waits as its session draft when another editor took the draft at the same moment'] = function()
  local state = fixture.directory('draft-sessions-first-follow-window-interleaved')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(OTHER_EDITOR_INTERLEAVED, { session_draft_file(state, 'session-other') })
  keep_new_buffer(state)
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')
  follow('session-a')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({
    shown = input_lines(),
    session = read_text(session_draft_file(state, 'session-a')),
    other = read_text(session_draft_file(state, 'session-other')),
    directory = read_text(directory_draft_file(state)),
  }, {
    shown = { 'From the directory and more' },
    session = 'From the directory and more\n',
    other = 'From the directory\n',
    directory = nil,
  })
end

T['a follow refused while textlock holds']['keeps an edit made while the first follow waits with the draft it moved, its first name not removable'] = function()
  local state = fixture.directory('draft-sessions-first-follow-window-unremovable')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(KEEP_WARNINGS)
  child.lua([[
    local real_unlink = vim.uv.fs_unlink
    vim.uv.fs_unlink = function(path)
      vim.uv.fs_unlink = real_unlink
      return nil, 'EACCES: permission denied: ' .. path, 'EACCES'
    end
  ]])
  keep_new_buffer(state)
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')
  follow('session-a')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({
    shown = input_lines(),
    session = read_text(session_draft_file(state, 'session-a')),
    directory = read_text(directory_draft_file(state)),
  }, {
    shown = { 'From the directory and more' },
    session = 'From the directory and more\n',
    directory = 'From the directory\n',
  })
end

T['a follow refused while textlock holds']['leaves no retry and raises nothing when Input is wiped while it waits, keeping the edit as the old session draft'] = function()
  local state = fixture.directory('draft-sessions-wiped-window')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  child.lua(KEEP_WARNINGS)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  child.cmd('split')
  child.lua('vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))')
  child.cmd('wincmd p')
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>:bwipeout!<CR>')
  follow('session-b')
  local waiting = child.lua_get(RETRIES)
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({
    waiting = waiting,
    valid = child.lua_get('vim.api.nvim_buf_is_valid(_G.input)'),
    retries = child.lua_get(RETRIES),
    warnings = child.lua_get('_G.warnings'),
    errmsg = child.lua_get('vim.v.errmsg'),
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, {
    waiting = 1,
    valid = false,
    retries = 0,
    warnings = {},
    errmsg = '',
    first = 'Typed for the first session and more\n',
    second = 'Kept for the second session\n',
  })
end

T['a follow refused while textlock holds']["followed twice, keeps an edit made meanwhile as the first session's draft"] = function()
  local state = fixture.directory('draft-sessions-textlock-twice-edit')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  plant_draft(session_draft_file(state, 'session-c'), 'Kept for the third session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')
  follow('session-b')
  follow('session-c')
  local waiting = child.lua_get(RETRIES)
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  eq({
    waiting = waiting,
    shown = input_lines(),
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
    third = read_text(session_draft_file(state, 'session-c')),
  }, {
    waiting = 1,
    shown = { 'Kept for the third session' },
    first = 'Typed for the first session and more\n',
    second = 'Kept for the second session\n',
    third = 'Kept for the third session\n',
  })
end

T['a follow refused while textlock holds']["keeps an edit made meanwhile as the old session's draft when Neovim quits"] = function()
  local state = fixture.directory('draft-sessions-quit-window')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>:qall<CR>')
  follow('session-b')
  local waiting = child.lua_get(RETRIES)
  pcall(child.api.nvim_input, 'q')
  vim.wait(PATIENCE_MS, function()
    return read_text(session_draft_file(state, 'session-a')) ~= 'Typed for the first session\n'
      or read_text(session_draft_file(state, 'session-b')) ~= 'Kept for the second session\n'
  end, 20)

  eq({
    waiting = waiting,
    first = read_text(session_draft_file(state, 'session-a')),
    second = read_text(session_draft_file(state, 'session-b')),
  }, {
    waiting = 1,
    first = 'Typed for the first session and more\n',
    second = 'Kept for the second session\n',
  })
end

T['a follow refused while textlock holds']['keeps an edit made while the first follow waits with the draft it renamed where links are refused'] = function()
  local state = fixture.directory('draft-sessions-first-follow-window-renamed')
  plant_draft(directory_draft_file(state), 'From the directory\n')
  child.lua(LINKS_REFUSED, { 'ENOTSUP' })
  keep_new_buffer(state)
  begin_hold('vim.fn.getcharstr()', 'A and more<Esc>')
  follow('session-a')
  local waiting = child.lua_get(RETRIES)
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)
  vim.wait(SAVE_DELAY_AND_MARGIN_MS)

  eq({
    waiting = waiting,
    shown = input_lines(),
    session = read_text(session_draft_file(state, 'session-a')),
    directory = read_text(directory_draft_file(state)),
  }, {
    waiting = 1,
    shown = { 'From the directory and more' },
    session = 'From the directory and more\n',
    directory = nil,
  })
end

T['a follow refused while textlock holds']['is made still when every SafeState autocommand in no group is cleared while it waits'] = function()
  local state = fixture.directory('draft-sessions-safestate-cleared')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  plant_draft(session_draft_file(state, 'session-c'), 'Kept for the third session\n')
  keep_new_buffer(state)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  begin_hold('vim.fn.getcharstr()')
  follow('session-b')
  local waiting = child.lua_get(RETRIES)
  child.cmd('autocmd! SafeState')
  end_hold('q')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(RETRIES) == 0
  end, 10)

  follow('session-c')
  set_input({ 'Typed while following the third session' })

  eq({
    waiting = waiting,
    shown = input_lines(),
    first = wait_for_text(
      session_draft_file(state, 'session-a'),
      'Typed while following the third session\n'
    ),
    third = read_text(session_draft_file(state, 'session-c')),
  }, {
    waiting = 1,
    shown = { 'Typed while following the third session' },
    first = 'Typed for the first session\n',
    third = 'Typed while following the third session\n',
  })
end

T['a follow refused for another reason'] = MiniTest.new_set()

T['a follow refused for another reason']['is told once, and not tried again'] = function()
  local state = fixture.directory('draft-sessions-unmodifiable')
  plant_draft(session_draft_file(state, 'session-b'), 'Kept for the second session\n')
  keep_new_buffer(state)
  child.lua(KEEP_WARNINGS)
  follow('session-a')
  set_input({ 'Typed for the first session' })
  child.lua('vim.bo[_G.input].modifiable = false')

  follow('session-b')

  eq({
    shown = input_lines(),
    retries = child.lua_get(RETRIES),
    refusals = child.lua_get([[#vim.tbl_filter(function(message)
      return message:find("cannot put Input's draft", 1, true) ~= nil
    end, _G.warnings)]]),
  }, {
    shown = { 'Typed for the first session' },
    retries = 0,
    refusals = 1,
  })
end

return T
