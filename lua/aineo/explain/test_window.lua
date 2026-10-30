--- The test window: a window below the window of a source file, half of
--- the height they share, showing the source's test file, which the layout
--- of the project's tests (`aineo.explain.TestLayout`) names.

local folders = require('aineo.explain.folders')

local M = {}

--- Where the tests of a file are, and the file a test file tests: what the
--- layout of the project's tests answers for one path.
---@class aineo.explain.TestPlace
---@field path string the file's absolute path
---@field exists boolean whether the file is on disk
---@field candidates string[] the absolute paths of the files that may be it, on disk, best first
---@field origin string what gave the rule that found it: `user`, `agent`, `repository` or `preset`
---@field rule string the rule that found it, in a few words
---@field kind? string the kind of tests the file holds, such as `unit` or `integration`
---@field inline boolean whether the tests are in the source file itself
---@field framework? string the test framework the file is written for
---@field sibling? string an existing test file nearest to `path`, whose header and style a new one follows
---@field companions string[] the absolute paths of files written beside a new test file with it
---@field root string the root of the repository it was read in

--- The layout of a project's tests: where a source's test file is, and a
--- test file's source. A port the composition root binds to
--- `aineo.test_layout`, for which no second approach is foreseen.
---@class aineo.explain.TestLayout
---@field test_for fun(source: string): aineo.explain.TestPlace|nil, string? the place of the test file of the source at that absolute path, or `nil` and why
---@field source_for fun(test: string): aineo.explain.TestPlace|nil, string? the place of the source of the test file at that absolute path, or `nil` and why
---@field is_test fun(path: string): boolean whether the file at that absolute path is a test file
---@field forget fun(path: string) reads again the repository that holds that path, as after a file was written there
---@field correct fun(source: string, test: string): boolean, string? records that the source's test file is the one at `test`, as the user said; `false` and why when it cannot
---@field describe fun(source: string): string the rule that pairs the source at that absolute path with its test file, and its origin, on one line

--- What a test window shows, by the window of the source above it.
---@class aineo.explain.ShownTests
---@field window integer the test window
---@field layout aineo.explain.TestLayout
---@field zoomed? fun(tabpage: integer): boolean whether the layout of that tab page is zoomed, which a resize then leaves alone
---@field source string the absolute path of the source whose test file it shows
---@field place aineo.explain.TestPlace the place of that test file, as the layout answered it

---@type table<integer, aineo.explain.ShownTests>
local shown = {}

--- The buffer of the file at `path`, loaded, listed, and empty when the
--- file is not on disk, which nothing writes.
---
---@param path string
---@return integer
local function buffer_of(path)
  local buffer = vim.fn.bufadd(path)
  vim.bo[buffer].buflisted = true
  vim.fn.bufload(buffer)
  return buffer
end

--- What the bar of a test window says of the test file at `path` it
--- shows for the source at `source`: its path from the project, `new`
--- when it is not on disk, and the rule that pairs them and its origin, as
--- `layout` describes it; a `%` doubled, so that the bar shows it.
---
---@param source string
---@param path string
---@param layout aineo.explain.TestLayout
---@return string
local function bar_of(source, path, layout)
  local parts = {
    vim.fs.relpath(folders.project_of(path), path) or path,
    layout.describe(source),
  }
  if not vim.uv.fs_stat(path) then
    table.insert(parts, 2, 'new')
  end
  return (table.concat(parts, ' · '):gsub('%%', '%%%%'))
end

--- Shows in the test window `tests.window` the test file at `path`, named
--- in its bar (`bar_of()`).
---
---@param tests aineo.explain.ShownTests
---@param path string
local function show_file(tests, path)
  vim.api.nvim_win_set_buf(tests.window, buffer_of(path))
  vim.wo[tests.window].winbar = bar_of(tests.source, path, tests.layout)
end

--- Shows in the test window `tests.window` the test file `place` names
--- for the source at `source` (`show_file()`), and remembers both in
--- `tests`.
---
---@param tests aineo.explain.ShownTests
---@param source string
---@param place aineo.explain.TestPlace
local function show(tests, source, place)
  tests.source = source
  tests.place = place
  show_file(tests, place.path)
end

--- Opens the test window of the source at `source`, which `source_window`
--- shows, below it, half of the height they share, showing the test file
--- `place` names (`show()`); the cursor stays where it is.
---
---@param source_window integer
---@param source string
---@param place aineo.explain.TestPlace
---@param layout aineo.explain.TestLayout
---@param zoomed? fun(tabpage: integer): boolean
local function open(source_window, source, place, layout, zoomed)
  local window = vim.api.nvim_open_win(buffer_of(place.path), false, {
    split = 'below',
    win = source_window,
    height = math.floor(vim.api.nvim_win_get_height(source_window) / 2),
  })
  shown[source_window] =
    { window = window, layout = layout, zoomed = zoomed, source = source, place = place }
  show(shown[source_window], source, place)
end

--- The window of the source whose test window is `window`, when it is
--- one; else `window` itself, when it shows a test window; `nil` when it
--- is neither, or when its test window or its source window was closed,
--- which forgets the pair.
---
---@param window integer
---@return integer|nil
local function source_window_of(window)
  for source_window, tests in pairs(shown) do
    if source_window == window or tests.window == window then
      if vim.api.nvim_win_is_valid(tests.window) and vim.api.nvim_win_is_valid(source_window) then
        return source_window
      end
      shown[source_window] = nil
    end
  end
end

--- Closes the test window of the source `source_window` shows.
---
---@param source_window integer
local function close(source_window)
  vim.api.nvim_win_close(shown[source_window].window, false)
  shown[source_window] = nil
end

--- Tells the user, once, that the layout knows no test file of the source
--- at `source`, and `problem`, why.
---
---@param source string
---@param problem string
local function tell_no_test_file(source, problem)
  vim.notify(
    ('aineo: no test file is known for %s: %s'):format(
      vim.fs.relpath(folders.project_of(source), source) or source,
      problem
    ),
    vim.log.levels.WARN
  )
end

--- The place of the test file of the source at `source`, as `layout`
--- answers it; `nil` after telling the user, once, that the layout knows
--- none (`tell_no_test_file()`).
---
---@param source string
---@param layout aineo.explain.TestLayout
---@return aineo.explain.TestPlace|nil
function M.test_place(source, layout)
  local place, problem = layout.test_for(source)
  if not place then
    tell_no_test_file(source, problem)
  end
  return place
end

--- Opens the test window of the source `source_window` shows (`open()`),
--- its test file found by `layout`, a resize leaving it alone while
--- `zoomed` says the layout is zoomed, and returns what it shows; tells
--- the user, once, when `layout` finds none, and opens nothing then.
---
---@param source_window integer
---@param layout aineo.explain.TestLayout
---@param zoomed? fun(tabpage: integer): boolean
---@return aineo.explain.ShownTests|nil
local function open_for(source_window, layout, zoomed)
  local source = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(source_window))
  local place = M.test_place(source, layout)
  if not place then
    return nil
  end
  open(source_window, source, place, layout, zoomed)
  return shown[source_window]
end

--- Hides the test window when `window` is it or the window of its source
--- (`close()`); else shows the test window of the source `window` shows,
--- its test file found by `layout`, which a resize leaves alone while
--- `zoomed` says the layout of its tab page is zoomed (`open_for()`).
---
---@param window integer
---@param layout aineo.explain.TestLayout
---@param zoomed? fun(tabpage: integer): boolean
function M.toggle(window, layout, zoomed)
  local shown_for = source_window_of(window)
  if shown_for then
    close(shown_for)
    return
  end
  open_for(window, layout, zoomed)
end

--- The test window of the source `source_window` shows, and what it
--- shows, opened when hidden (`open_for()`, with `zoomed`); `nil` when the
--- layout knows no test file of the source, the user told so.
---
---@param source_window integer
---@param layout aineo.explain.TestLayout
---@param zoomed? fun(tabpage: integer): boolean
---@return aineo.explain.ShownTests|nil
function M.ensure(source_window, layout, zoomed)
  if shown[source_window] and vim.api.nvim_win_is_valid(shown[source_window].window) then
    return shown[source_window]
  end
  return open_for(source_window, layout, zoomed)
end

--- Has the test window of `source_window`, when it has one, show the test
--- file of the source it shows now, a file's, when the layout knows one
--- (`show()`); a buffer of no file, or one the layout knows no test file
--- for, leaves the test window as it is.
---
---@param source_window integer
local function follow(source_window)
  local tests = shown[source_window]
  if not tests or not vim.api.nvim_win_is_valid(tests.window) then
    return
  end
  local buffer = vim.api.nvim_win_get_buf(source_window)
  local source = vim.api.nvim_buf_get_name(buffer)
  if vim.bo[buffer].buftype ~= '' or source == '' or source == tests.source then
    return
  end
  local place = tests.layout.test_for(source)
  if place then
    show(tests, source, place)
  end
end

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufFilePost' }, {
  group = vim.api.nvim_create_augroup('aineo_explain_test_window', {}),
  desc = 'aineo: show in the test window the test file of the source above it, also renamed',
  -- Nested, so that a test file loaded here runs its own BufRead and
  -- FileType autocommands: its filetype, syntax and ftplugin.
  nested = true,
  callback = function()
    follow(vim.api.nvim_get_current_win())
  end,
})

--- Names again, in the bar of each test window that shows `buffer`, the
--- file it shows (`bar_of()`), which is on disk once written.
---
---@param buffer integer
local function rename_in_bars(buffer)
  for _, tests in pairs(shown) do
    if
      vim.api.nvim_win_is_valid(tests.window) and vim.api.nvim_win_get_buf(tests.window) == buffer
    then
      vim.wo[tests.window].winbar =
        bar_of(tests.source, vim.api.nvim_buf_get_name(buffer), tests.layout)
    end
  end
end

vim.api.nvim_create_autocmd('BufWritePost', {
  group = 'aineo_explain_test_window',
  desc = 'aineo: name a test file written as no longer new in the test window',
  callback = function(event)
    rename_in_bars(event.buf)
  end,
})

--- The test files the test window of `tests` goes through: the one the
--- layout placed first, then each other candidate, in their order.
---
---@param tests aineo.explain.ShownTests
---@return string[]
local function cycle_of(tests)
  local paths = { tests.place.path }
  for _, candidate in ipairs(tests.place.candidates or {}) do
    if candidate ~= tests.place.path then
      table.insert(paths, candidate)
    end
  end
  return paths
end

--- The test window, and what it shows, of `window`, a test window or the
--- window of its source; `nil` after telling the user, once, that it works
--- in the test window, when `window` is neither.
---
---@param window integer
---@return aineo.explain.ShownTests|nil
local function tests_of(window)
  local source_window = source_window_of(window)
  if not source_window then
    vim.notify('aineo: this works in a test window', vim.log.levels.INFO)
    return nil
  end
  return shown[source_window]
end

--- Has the test window of `window`, a test window or the window of its
--- source, show the next of the test files it goes through
--- (`cycle_of()`), after the last the first.
---
---@param window integer
function M.next_file(window)
  local tests = tests_of(window)
  if not tests then
    return
  end
  local paths = cycle_of(tests)
  local current = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(tests.window))
  local index = vim.fn.index(paths, current) + 1
  show_file(tests, paths[index % #paths + 1])
end

--- The absolute path `answer`, a path the user typed, names: as it is
--- when absolute, else from `folder`.
---
---@param answer string
---@param folder string
---@return string
local function absolute_path(answer, folder)
  local path = vim.fn.expand(answer)
  if not vim.startswith(path, '/') then
    path = folder .. '/' .. path
  end
  return vim.fs.normalize(path)
end

--- Asks the user, in an input that starts with the path from the project of
--- the test file the test window of `window` shows — `window` a test
--- window or the window of its source — for the path of the source's test
--- file, and, for a path given, tells the layout the correction and shows
--- the test file it then places (`show()`); a correction the layout
--- refuses, or after which it places no test file, is told to the user,
--- once, and changes nothing. Nothing when the user gives none.
---
---@param window integer
function M.correct_file(window)
  local tests = tests_of(window)
  if not tests then
    return
  end
  local folder = folders.project_of(tests.source)
  local current = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(tests.window))
  vim.ui.input({
    prompt = 'Test file: ',
    default = vim.fs.relpath(folder, current) or current,
    completion = 'file',
  }, function(answer)
    if not answer or vim.trim(answer) == '' or not vim.api.nvim_win_is_valid(tests.window) then
      return
    end
    local path = absolute_path(vim.trim(answer), folder)
    local kept, problem = tests.layout.correct(tests.source, path)
    if kept == false then
      vim.notify('aineo: the test file was not corrected: ' .. problem, vim.log.levels.WARN)
      return
    end
    local place, missing = tests.layout.test_for(tests.source)
    if not place then
      tell_no_test_file(tests.source, missing)
      return
    end
    show(tests, tests.source, place)
  end)
end

--- The window that shows the source at `path`, whose test the user asks
--- code for in `window`: a window of the tab page that shows it already;
--- else the window of the source above `window` when it is a test window,
--- made to show it; else a new window above `window`. The source not on
--- disk shows as an empty buffer of its name, which nothing writes.
---
---@param window integer
---@param path string
---@return integer source_window
function M.show_source(window, path)
  local buffer = buffer_of(path)
  local showing = vim
    .iter(vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(window)))
    :find(function(shown_in)
      return vim.api.nvim_win_get_buf(shown_in) == buffer
    end)
  if showing then
    return showing
  end
  local source_window = source_window_of(window)
  if source_window and source_window ~= window then
    vim.api.nvim_win_set_buf(source_window, buffer)
    return source_window
  end
  return vim.api.nvim_open_win(buffer, false, { split = 'above', win = window })
end

--- The tab pages resized while they were not the current one, whose
--- source and test windows share their heights again once entered.
---@type table<integer, true>
local resized_elsewhere = {}

--- Gives each source window and its test window in the tab page
--- `tabpage` half of the rows they hold together, as when the test window
--- was opened, but for a pair whose layout says it is zoomed.
---
---@param tabpage integer
local function share_heights_in(tabpage)
  for source_window, tests in pairs(shown) do
    if
      vim.api.nvim_win_is_valid(source_window)
      and vim.api.nvim_win_is_valid(tests.window)
      and vim.api.nvim_win_get_tabpage(source_window) == tabpage
      and not (tests.zoomed and tests.zoomed(tabpage))
    then
      local rows = vim.api.nvim_win_get_height(source_window)
        + vim.api.nvim_win_get_height(tests.window)
      vim.api.nvim_win_set_height(tests.window, math.floor(rows / 2))
    end
  end
end

--- After a resize of the editor: shares the heights of the current tab
--- page's pairs (`share_heights_in()`), and marks every other tab page that
--- holds a pair to share them once it is entered.
local function share_heights_after_a_resize()
  local current = vim.api.nvim_get_current_tabpage()
  for source_window, tests in pairs(shown) do
    if vim.api.nvim_win_is_valid(source_window) and vim.api.nvim_win_is_valid(tests.window) then
      local tabpage = vim.api.nvim_win_get_tabpage(source_window)
      if tabpage ~= current then
        resized_elsewhere[tabpage] = true
      end
    end
  end
  share_heights_in(current)
end

vim.api.nvim_create_autocmd('VimResized', {
  group = 'aineo_explain_test_window',
  desc = 'aineo: keep a source and its test window at half the height each',
  callback = share_heights_after_a_resize,
})

vim.api.nvim_create_autocmd('TabEnter', {
  group = 'aineo_explain_test_window',
  desc = 'aineo: share the heights of a tab page resized while another was current',
  callback = function()
    local tabpage = vim.api.nvim_get_current_tabpage()
    if resized_elsewhere[tabpage] then
      resized_elsewhere[tabpage] = nil
      share_heights_in(tabpage)
    end
  end,
})

return M
