local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

--- The name of the changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- How long `child.type_keys()` waits after each key, far shorter than the
--- pause before the diff follows the cursor, so that the child acts on every
--- key, its `CursorMoved` included, before the next arrives.
local KEY_GAP_MS = 10

--- How long a case waits to be sure no diff is drawn: well past the pause
--- before the diff follows the cursor.
local QUIET_MS = 500

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, shows the pane's two buffers there — the files buffer in
--- the current window, the commits buffer in a window below it — and counts,
--- in `_G.reads`, the diffs the home reads. Every buffer the home asks to show
--- is kept in `_G.shown_diffs` and shown in a window of its own at the
--- bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory = ...
  local changes = require('aineo.changes')
  _G.shown_diffs, _G.reads, _G.pane_shown_times = {}, 0, 0
  local entry_diff = require('aineo.changes.entry_diff')
  local read = entry_diff.read
  entry_diff.read = function(...)
    _G.reads = _G.reads + 1
    return read(...)
  end
  changes.begin_session({
    directory = directory,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      local showing = vim.fn.bufwinid(diff)
      if showing ~= -1 then
        return showing
      end
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
    show_changes_pane = function()
      _G.pane_shown_times = _G.pane_shown_times + 1
      local files = changes.pane_buffers().files
      if vim.fn.bufwinid(files) == -1 then
        vim.api.nvim_open_win(files, false, { split = 'above', win = -1 })
      end
    end,
  })
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
end

--- Waits until the child's buffer named `name` holds `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param name string
---@param expected string[]
local function expect_lines(name, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(lines_of(name), expected)
  end, 10)
  eq(lines_of(name), expected)
end

--- Makes the current window the one showing the child's buffer named
--- `name`.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- The name of the buffer the child was asked to show last.
---
---@return string
local function last_shown_name()
  return child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])')
end

--- Waits until the buffer the child was asked to show last is named `name`,
--- at most `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param name string
local function expect_last_shown_name(name)
  vim.wait(git_repo.PATIENCE_MS, function()
    return child.lua_get('#_G.shown_diffs') > 0 and last_shown_name() == name
  end, 10)
  eq(child.lua_get('#_G.shown_diffs') > 0 and last_shown_name() or '', name)
end

--- How many times the child was asked to show a buffer.
---
---@return integer
local function draws()
  return child.lua_get('#_G.shown_diffs')
end

--- The changed lines of the diff the child was asked to show last: its `+` and
--- `-` lines, less the two that name the files.
---
---@return string[]
local function last_shown_changes()
  return vim.tbl_filter(function(line)
    return (vim.startswith(line, '+') or vim.startswith(line, '-'))
      and not vim.startswith(line, '+++')
      and not vim.startswith(line, '---')
  end, child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[#_G.shown_diffs], 0, -1, true)'))
end

--- The window the child's cursor is in, by the name of the buffer it shows.
---
---@return string
local function current_buffer_name()
  return child.lua_get('vim.api.nvim_buf_get_name(0)')
end

--- Makes a repository whose base commit holds `a.txt`, `b.txt` and `c.txt`
--- with `one`, begins the session there with the pane shown, commits the
--- three as `two`, writes them `three` into the working tree and waits for the
--- files window to list them under Session work. The cursor is left in the
--- files window, on its header, with nothing shown.
---
---@param case string the case's own name
---@param before_beginning? string Lua run in the child before the session begins
local function pane_with_three_edited_files(case, before_beginning)
  local top =
    git_repo.create(case, { ['a.txt'] = { 'one' }, ['b.txt'] = { 'one' }, ['c.txt'] = { 'one' } })
  if before_beginning then
    child.lua(before_beginning)
  end
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  for _, path in ipairs({ 'a.txt', 'b.txt', 'c.txt' }) do
    git_repo.write(top, path, { 'two' })
  end
  local commit = git_repo.commit_all(top, 'Second')
  for _, path in ipairs({ 'a.txt', 'b.txt', 'c.txt' }) do
    git_repo.write(top, path, { 'three' })
  end
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', git_repo.commit_line(commit, 'Second') })
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  M b.txt', '  M c.txt' })
  enter_window_of(FILES)
end

--- The Lua that keeps, in `_G.timers`, every timer the pause behind a diff
--- following the cursor makes in the child after it.
local TRACK_PAUSE_TIMERS = [[
  _G.timers = {}
  local new_timer = vim.uv.new_timer
  vim.uv.new_timer = function()
    local timer = new_timer()
    if debug.traceback():find('aineo/changes/pause.lua', 1, true) then
      table.insert(_G.timers, timer)
    end
    return timer
  end
]]

T['moving the cursor in the files window'] = MiniTest.new_set()

T['moving the cursor in the files window']['shows the diff of the file it reaches'] = function()
  pane_with_three_edited_files('follow-shows')

  child.type_keys('j', 'j')

  expect_last_shown_name('aineo://diff/b.txt')
  eq(last_shown_changes(), { '-one', '+three' })
end

T['moving the cursor in the files window']['leaves the cursor in the files window, on its line'] = function()
  pane_with_three_edited_files('follow-cursor-stays')

  child.type_keys('j', 'j')

  expect_last_shown_name('aineo://diff/b.txt')
  eq(
    { current_buffer_name(), child.lua_get('vim.api.nvim_win_get_cursor(0)') },
    { FILES, { 3, 0 } }
  )
end

T['moving the cursor in the files window']['draws only the last file of the moves within the pause'] = function()
  pane_with_three_edited_files('follow-debounce')

  child.type_keys(KEY_GAP_MS, 'j', 'j', 'j')

  expect_last_shown_name('aineo://diff/c.txt')
  vim.wait(QUIET_MS)
  eq({ draws = draws(), reads = child.lua_get('_G.reads') }, { draws = 1, reads = 1 })
end

T['moving the cursor in the files window']['shows nothing when the cursor left the window within the pause'] = function()
  pane_with_three_edited_files('follow-left')

  child.type_keys('j')
  enter_window_of(COMMITS)

  vim.wait(QUIET_MS)
  eq({ draws = draws(), reads = child.lua_get('_G.reads') }, { draws = 0, reads = 0 })
end

T['moving the cursor in the files window']['keeps the diff against the previous version until h chooses HEAD'] = function()
  pane_with_three_edited_files('follow-previous')

  child.type_keys('j')
  expect_last_shown_name('aineo://diff/a.txt')
  child.type_keys('j')

  expect_last_shown_name('aineo://diff/b.txt')
end

T['moving the cursor in the files window']['shows the diffs against HEAD after h'] = function()
  pane_with_three_edited_files('follow-head')
  child.type_keys('j', 'h')
  expect_last_shown_name('aineo://uncommitted/a.txt')

  child.type_keys('j')

  expect_last_shown_name('aineo://uncommitted/b.txt')
  eq(last_shown_changes(), { '-two', '+three' })
end

T['moving the cursor in the files window']['shows the diffs against HEAD on every move after h'] = function()
  pane_with_three_edited_files('follow-head-again')
  child.type_keys('j', 'h')
  expect_last_shown_name('aineo://uncommitted/a.txt')
  child.type_keys('j')
  expect_last_shown_name('aineo://uncommitted/b.txt')

  child.type_keys('j')

  expect_last_shown_name('aineo://uncommitted/c.txt')
end

T['moving the cursor in the files window']['shows the diffs against the previous version again after l'] = function()
  pane_with_three_edited_files('follow-head-then-previous')
  child.type_keys('j', 'h')
  expect_last_shown_name('aineo://uncommitted/a.txt')
  child.type_keys('l', 'j')

  expect_last_shown_name('aineo://diff/b.txt')
end

T['moving the cursor in the files window']['shows nothing new on the header'] = function()
  pane_with_three_edited_files('follow-header')
  child.type_keys('j')
  expect_last_shown_name('aineo://diff/a.txt')

  child.type_keys('k')

  vim.wait(QUIET_MS)
  eq({ draws = draws(), name = last_shown_name() }, { draws = 1, name = 'aineo://diff/a.txt' })
end

T['moving the cursor in the files window']['shows nothing new on a line that lists no file'] = function()
  local top = git_repo.create('follow-note', { ['a.txt'] = { 'one' } })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  enter_window_of(FILES)

  child.type_keys('j')

  vim.wait(QUIET_MS)
  eq(draws(), 0)
end

T['moving the cursor in the files window']['leaves the commits window’s choice and cursor as they were'] = function()
  pane_with_three_edited_files('follow-commits-unchanged')
  local commits_cursor = 'vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))'
  local before = child.lua_get(commits_cursor, { COMMITS })

  child.type_keys('j', 'j')
  expect_last_shown_name('aineo://diff/b.txt')

  vim.wait(QUIET_MS)
  eq(
    { cursor = child.lua_get(commits_cursor, { COMMITS }), files = lines_of(FILES)[1] },
    { cursor = before, files = 'Files in: Session work' }
  )
end

T['moving the cursor in the files window']['shows a diff again after the diff was closed'] = function()
  pane_with_three_edited_files('follow-after-close')
  child.type_keys('j')
  expect_last_shown_name('aineo://diff/a.txt')
  child.lua("require('aineo.changes').close_shown_diff()")
  child.type_keys('k')
  vim.wait(QUIET_MS)
  local drawn = draws()

  child.type_keys('j')

  git_repo.wait_until('the diff is drawn again', function()
    return draws() > drawn
  end)
  eq(
    child.lua_get(
      'vim.fn.bufwinid(vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])) ~= -1'
    ),
    true
  )
end

T['moving the cursor in the files window']['draws the diff once while it is shown already'] = function()
  pane_with_three_edited_files('follow-already-shown')
  child.type_keys('j')
  expect_last_shown_name('aineo://diff/a.txt')

  child.type_keys('l')
  child.type_keys('k', 'j')

  vim.wait(QUIET_MS)
  eq(draws(), 2)
end

--- Wipes the child's files buffer and tells how many pause timers there were
--- (`TRACK_PAUSE_TIMERS`) at that moment, and how many of those are not closed
--- afterwards: a pause made once the buffer is wiped, as the commits window's
--- when the cursor enters it, is none of them.
---
---@return { made: integer, open: integer }
local function wipe_files_buffer_counting_pause_timers()
  return child.lua(
    [[
    local made = { unpack(_G.timers) }
    vim.api.nvim_buf_delete(vim.fn.bufnr(...), { force = true })
    return {
      made = #made,
      open = #vim.tbl_filter(function(timer)
        return not timer:is_closing()
      end, made),
    }
  ]],
    { FILES }
  )
end

T['moving the cursor in the files window']['closes its timer once the files buffer is wiped'] = function()
  pane_with_three_edited_files('follow-wiped', TRACK_PAUSE_TIMERS)
  child.type_keys('j')
  expect_last_shown_name('aineo://diff/a.txt')

  local timers = wipe_files_buffer_counting_pause_timers()

  eq({ made = timers.made > 0, open = timers.open }, { made = true, open = 0 })
end

T['moving the cursor in the files window']['leaves no handler of its own once the files buffer is wiped'] = function()
  pane_with_three_edited_files('follow-wiped-handler')
  child.lua('vim.api.nvim_buf_delete(vim.fn.bufnr(...), { force = true })', { FILES })

  eq(
    child.lua_get([[#vim.tbl_filter(function(autocmd)
      return vim.startswith(autocmd.desc or '', 'aineo: show the diff of the file under the cursor')
    end, vim.api.nvim_get_autocmds({ event = 'CursorMoved' }))]]),
    0
  )
end

--- Waits until the child's current buffer is the one named `name`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it is.
---
---@param name string
local function expect_current_buffer(name)
  vim.wait(git_repo.PATIENCE_MS, function()
    return current_buffer_name() == name
  end, 10)
  eq(current_buffer_name(), name)
end

--- Moves the cursor into the window that shows the diff the child was asked
--- to show last, and puts the cursor of the files window on line `line`
--- without entering it, as a user who scrolled the list does.
---
---@param line integer
local function enter_last_diff_with_files_cursor_on(line)
  child.lua(
    [[
    vim.api.nvim_win_set_cursor(vim.fn.bufwinid(vim.fn.bufnr(...)), { select(2, ...), 0 })
    vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.shown_diffs[#_G.shown_diffs]))
  ]],
    { FILES, line }
  )
end

T['<BS> in a diff'] = MiniTest.new_set()

T['<BS> in a diff']['shown by Enter moves the cursor to the files window, on the line of its file'] = function()
  pane_with_three_edited_files('back-enter')
  child.type_keys('j', 'j', '<CR>')
  expect_last_shown_name('aineo://diff/b.txt')
  expect_current_buffer('aineo://diff/b.txt')
  enter_last_diff_with_files_cursor_on(1)

  child.type_keys('<BS>')

  expect_current_buffer(FILES)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 3, 0 })
end

T['<BS> in a diff']['shown by following the cursor moves the cursor to the files window, on the line of its file'] = function()
  pane_with_three_edited_files('back-follow')
  child.type_keys('j', 'j', 'j')
  expect_last_shown_name('aineo://diff/c.txt')
  enter_last_diff_with_files_cursor_on(1)

  child.type_keys('<BS>')

  expect_current_buffer(FILES)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 4, 0 })
end

T['<BS> in a diff']['shown by h moves the cursor to the files window, on the line of its file'] = function()
  pane_with_three_edited_files('back-head')
  child.type_keys('j', 'j', 'h')
  expect_last_shown_name('aineo://uncommitted/b.txt')
  enter_last_diff_with_files_cursor_on(1)

  child.type_keys('<BS>')

  expect_current_buffer(FILES)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 3, 0 })
end

T['<BS> in a diff']['shows the changes pane first when the files window is not on screen'] = function()
  pane_with_three_edited_files('back-hidden')
  child.type_keys('j', 'j', '<CR>')
  expect_current_buffer('aineo://diff/b.txt')
  child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), true)', { FILES })

  child.type_keys('<BS>')

  expect_current_buffer(FILES)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 3, 0 })
  eq(child.lua_get('_G.pane_shown_times'), 1)
end

T['<BS> in a diff']['asks for the changes pane only when the files window is not on screen'] = function()
  pane_with_three_edited_files('back-shown')
  child.type_keys('j', 'j', '<CR>')
  expect_current_buffer('aineo://diff/b.txt')

  child.type_keys('<BS>')

  expect_current_buffer(FILES)
  eq(child.lua_get('_G.pane_shown_times'), 0)
end

T['<BS> in a diff']['stays Vim’s own in a file opened for editing'] = function()
  pane_with_three_edited_files('back-edited-file')
  child.type_keys('j')
  expect_last_shown_name('aineo://diff/a.txt')
  child.lua("vim.fn.maparg('gf', 'n', false, true).callback()")
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.fs.basename(current_buffer_name()) == 'a.txt'
  end, 10)
  eq(vim.fs.basename(current_buffer_name()), 'a.txt')

  eq(child.lua_get("next(vim.fn.maparg('<BS>', 'n', false, true)) == nil"), true)
end

return T
