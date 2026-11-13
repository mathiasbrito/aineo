local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local explorer_footer = dofile('tests/helpers/explorer_footer.lua')
local entry = dofile('tests/helpers/entry.lua')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

--- The Lua that replaces `vim.ui.select` in the child with a picker that
--- keeps each request in `_G.pickers`, answered by `_G.choose(text)` with
--- the item whose text starts with `text`.
local PICKER = [[
  _G.pickers = {}
  vim.ui.select = function(items, options, on_choice)
    table.insert(_G.pickers, { items = items, options = options, on_choice = on_choice })
  end
  _G.choose = function(text)
    local request = _G.pickers[#_G.pickers]
    for _, item in ipairs(request.items) do
      if vim.startswith(request.options.format_item(item), text) then
        request.on_choice(item)
        return true
      end
    end
    return false
  end
]]

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      for name, value in pairs(git_repo.ENVIRONMENT) do
        vim.env[name] = value
      end
    end,
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.lua(PICKER)
    end,
    post_once = stop_the_child,
  },
})

--- The repository of a case and its surroundings.
---@class ExplorerBackRepository
---@field top string the folder Claude works in, holding `main.txt` and `sub/inner.txt`
---@field worktree string a worktree on the branch `feature` beside it, with `feature.txt` too
---@field elsewhere string a folder of neither, holding `outside.txt`

--- Makes the repository `explorer-back-<name>` with a branch `lonely` and a
--- worktree `feature`, opens the layout in it with the fake `claude` once
--- Claude Code is ready, and the fake picker `snacks` opening `picked` (a path
--- from the repository's top), and returns where things are.
---
---@param name string
---@param picked? string
---@return ExplorerBackRepository
local function open_with_worktree(name, picked)
  local top = git_repo.create(
    'explorer-back-' .. name,
    { ['main.txt'] = { 'main' }, ['sub/inner.txt'] = { 'inner' } }
  )
  git_repo.git(top, { 'branch', 'lonely' })
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'feature')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature', worktree })
  git_repo.write(worktree, 'feature.txt', { 'feature' })
  git_repo.commit_all(worktree, 'Add the feature')
  local elsewhere = git_repo.directory('explorer-back-' .. name .. '-elsewhere')
  git_repo.write(elsewhere, 'outside.txt', { 'outside' })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-back-' .. name, 'ready'))
  find_pickers.install(child, { 'snacks' }, picked and vim.fs.joinpath(top, picked) or nil)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return { top = top, worktree = worktree, elsewhere = elsewhere }
end

--- The lines of the buffer named `name` in the child.
---
---@param name string
---@return string[]
local function lines_of(name)
  return child.lua_get(
    [[(function(name)
      local buffer = vim.fn.bufnr(name)
      return buffer > 0 and vim.api.nvim_buf_get_lines(buffer, 0, -1, false) or {}
    end)(...)]],
    { name }
  )
end

--- Waits, at most `PATIENCE_MS`, until `condition()` is true, and returns
--- whether it became true.
---
---@param condition fun(): boolean
---@return boolean
local function wait_until(condition)
  return vim.wait(PATIENCE_MS, condition, 20)
end

--- The title the footer of the explorer's window in the child's current
--- tab shows, `''` while none shows.
---
---@return string
local function footer_title()
  return explorer_footer.shown_lines_in(child)[1] or ''
end

--- Whether the title of the explorer's footer starts with `text`.
---
---@param text string
---@return boolean
local function title_starts_with(text)
  return vim.startswith(footer_title(), text)
end

--- Whether a line of the explorer ends with `text`.
---
---@param text string
---@return boolean
local function explorer_has(text)
  return vim.iter(lines_of('aineo://explorer')):any(function(line)
    return vim.endswith(line, text)
  end)
end

--- Presses `s` in the child's current window and waits for its picker, then
--- picks the item whose text starts with `text`; returns whether one did.
---
---@param text string
---@return boolean
local function pick(text)
  local before = child.lua_get('#_G.pickers')
  entry.press(child, 's')
  wait_until(function()
    return child.lua_get('#_G.pickers') > before
  end)
  return child.lua_get('_G.choose(...)', { text })
end

--- Shows the explorer by `\e` and has it show the worktree `feature`: waits
--- until its footer names it.
local function show_the_worktree()
  entry.press(child, '\\e')
  wait_until(function()
    return explorer_has('main.txt')
  end)
  pick('[worktree] feature')
  wait_until(function()
    return title_starts_with('Worktree feature (feature)')
  end)
end

--- Whether the commits window of the changes pane shows the worktree
--- `feature` alone, shown by `\g` first.
---
---@return boolean
local function changes_pane_shows_feature()
  entry.press(child, '\\g')
  return wait_until(function()
    return lines_of('aineo://changes-commits')[1] == 'Worktree feature (feature)'
  end)
end

--- The text of the line the cursor of the explorer's window is on in the
--- child, nil while no window shows the explorer.
local EXPLORER_CURSOR_LINE = [[(function()
  local buffer = vim.fn.bufnr('aineo://explorer')
  local window = buffer ~= -1 and vim.fn.win_findbuf(buffer)[1]
  if not window then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(window)[1]
  return vim.api.nvim_buf_get_lines(buffer, line - 1, line, false)[1]
end)()]]

--- Opens `file` in the child as `:edit` does, from its current window.
---
---@param file string
local function edit(file)
  entry.command(child, 'edit ' .. vim.fn.fnameescape(file))
end

T['\\f'] = MiniTest.new_set()

T['\\f']['searches the worktree the explorer shows'] = function()
  local repository = open_with_worktree('find-worktree')
  show_the_worktree()

  entry.press(child, '\\f')

  git_repo.wait_until('a picker to be called', function()
    return #find_pickers.calls(child) > 0
  end)
  eq(find_pickers.calls(child), { { picker = 'snacks', options = { cwd = repository.worktree } } })
end

T['\\f']['searches the folder Claude works in while the explorer shows the default view'] = function()
  local repository = open_with_worktree('find-default')
  entry.press(child, '\\e')
  wait_until(function()
    return explorer_has('main.txt')
  end)

  entry.press(child, '\\f')

  git_repo.wait_until('a picker to be called', function()
    return #find_pickers.calls(child) > 0
  end)
  eq(find_pickers.calls(child), { { picker = 'snacks', options = { cwd = repository.top } } })
end

T['a file of the folder Claude works in'] = MiniTest.new_set()

T['a file of the folder Claude works in']['opened with :e takes the explorer back to that folder, unfolded to the file, the changes pane keeping its view'] = function()
  local repository = open_with_worktree('edit')
  show_the_worktree()

  edit(vim.fs.joinpath(repository.top, 'sub', 'inner.txt'))

  eq(
    wait_until(function()
      return explorer_has('inner.txt')
        and not explorer_has('feature.txt')
        and not title_starts_with('Worktree feature (feature)')
    end),
    true
  )
  eq(changes_pane_shows_feature(), true)
end

T['a file of the folder Claude works in']['revealed by \\f takes the explorer back and puts its cursor on the file'] = function()
  local repository = open_with_worktree('reveal', 'sub/inner.txt')
  show_the_worktree()

  entry.press(child, '\\f')

  local inner = vim.fs.joinpath(repository.top, 'sub', 'inner.txt')
  eq(
    wait_until(function()
      local text = child.lua_get(EXPLORER_CURSOR_LINE)
      return type(text) == 'string' and vim.endswith(text, 'inner.txt')
    end),
    true
  )
  eq(title_starts_with('Worktree feature (feature)'), false)
  eq(entry.current_window(child), inner)
end

T['a file of the folder Claude works in']['leaves the explorer showing Claude’s folder until the focused work changes'] = function()
  local repository = open_with_worktree('release')
  show_the_worktree()
  edit(vim.fs.joinpath(repository.top, 'sub', 'inner.txt'))
  wait_until(function()
    return not title_starts_with('Worktree feature (feature)')
  end)

  pick('[branch] lonely')

  eq(
    wait_until(function()
      return footer_title():find('has no folder on disk', 1, true) ~= nil
    end),
    true
  )
end

T['a file outside both folders'] = MiniTest.new_set()

T['a file outside both folders']['changes nothing in the explorer'] = function()
  local repository = open_with_worktree('outside')
  show_the_worktree()
  local tree_before = lines_of('aineo://explorer')

  edit(vim.fs.joinpath(repository.elsewhere, 'outside.txt'))
  vim.wait(300)

  eq(title_starts_with('Worktree feature (feature)'), true)
  eq(lines_of('aineo://explorer'), tree_before)
end

return T
