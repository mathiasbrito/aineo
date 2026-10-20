local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
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

--- A repository `explorer-pick-<name>` holding `main.txt`, with a worktree
--- beside it on the branch `feature` holding `feature.txt` too, and a branch
--- `lonely` no worktree has checked out.
---@class ExplorerPickRepository
---@field top string
---@field worktree string

--- Makes the repository of `ExplorerPickRepository`, opens the layout in it
--- with the fake `claude` once Claude Code is ready, and returns where it is.
---
---@param name string
---@return ExplorerPickRepository
local function open_with_worktree(name)
  local top = git_repo.create('explorer-pick-' .. name, { ['main.txt'] = { 'main' } })
  git_repo.git(top, { 'branch', 'lonely' })
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'feature')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature', worktree })
  git_repo.write(worktree, 'feature.txt', { 'feature' })
  git_repo.commit_all(worktree, 'Add the feature')
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-pick-' .. name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return { top = top, worktree = worktree }
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

--- Waits until the explorer's lines below its header are `expected`, and
--- returns them as they are then.
---
---@param expected string[]
---@return string[]
local function wait_for_tree(expected)
  local lines
  wait_until(function()
    lines = vim.list_slice(lines_of('aineo://explorer'), 2)
    return vim.deep_equal(lines, expected)
  end)
  return lines
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

--- Shows the changes pane by `\g` and waits until its commits window lists
--- the worktree `feature`, which it reads once shown.
local function show_changes_pane()
  entry.press(child, '\\g')
  wait_until(function()
    return vim.list_contains(lines_of('aineo://changes-commits'), 'Worktree feature (feature)')
  end)
end

--- What the explorer shows of the repository's own folder.
local OWN_TREE = { '    main.txt' }

--- What the explorer shows of the worktree `feature`.
local FEATURE_TREE = { '    feature.txt', '    main.txt' }

--- Whether the commits window of the changes pane shows the worktree
--- `feature` alone: its heading on its first line.
---
---@return boolean
local function changes_pane_shows_feature()
  return lines_of('aineo://changes-commits')[1] == 'Worktree feature (feature)'
end

T['one pick'] = MiniTest.new_set()

T['one pick']['in the changes pane moves the explorer to the worktree picked'] = function()
  local repository = open_with_worktree('from-changes')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)
  show_changes_pane()

  eq(pick('[worktree] feature'), true)
  entry.press(child, '\\e')

  eq(wait_for_tree(FEATURE_TREE), FEATURE_TREE)
  eq(vim.startswith(lines_of('aineo://explorer')[1], 'Worktree feature (feature)'), true)
  eq(repository.worktree ~= nil, true)
end

T['one pick']['in the explorer moves the changes pane, which shows the worktree alone'] = function()
  open_with_worktree('from-explorer')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)

  local picked = pick('[worktree] feature')

  eq(picked, true)
  eq(wait_for_tree(FEATURE_TREE), FEATURE_TREE)
  entry.press(child, '\\g')
  eq(wait_until(changes_pane_shows_feature), true)
end

T['one pick']['opens a file of the worktree picked for editing there'] = function()
  local repository = open_with_worktree('open-in-worktree')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)
  pick('[worktree] feature')
  wait_for_tree(FEATURE_TREE)
  child.lua([[
    for line, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if vim.endswith(text, 'feature.txt') then
        vim.api.nvim_win_set_cursor(0, { line, 0 })
      end
    end
  ]])
  local file = vim.fs.joinpath(repository.worktree, 'feature.txt')

  entry.press(child, '<CR>')

  eq(
    wait_until(function()
      return entry.current_window(child) == file
    end),
    true
  )
end

T['one pick']['of a branch with no worktree shows the folder Claude works in, the header saying so'] = function()
  open_with_worktree('lonely-branch')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)

  pick('[branch] lonely')

  eq(
    wait_until(function()
      return lines_of('aineo://explorer')[1]:find('(Branch lonely has no folder on disk)', 1, true)
        ~= nil
    end),
    true
  )
  eq(vim.list_slice(lines_of('aineo://explorer'), 2), OWN_TREE)
end

T['one pick']['gives way to the folder Claude works in in the changes pane’s default view'] = function()
  open_with_worktree('default-view')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)
  pick('[worktree] feature')
  wait_for_tree(FEATURE_TREE)
  entry.press(child, '\\g')
  wait_until(changes_pane_shows_feature)

  entry.press(child, '\\g')
  entry.press(child, '\\e')

  eq(wait_for_tree(OWN_TREE), OWN_TREE)
end

T['one pick']['of reported work shows the first worktree reported'] = function()
  local repository = open_with_worktree('reported')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)

  child.lua(
    [[require('aineo.changes').add_reported_work({ kind = 'worktree', path = ... }, function() end)]],
    { repository.worktree }
  )

  eq(wait_for_tree(FEATURE_TREE), FEATURE_TREE)
end

T['one pick']['of a worktree that is gone falls back to the folder Claude works in, telling once'] = function()
  local repository = open_with_worktree('gone')
  entry.press(child, '\\e')
  wait_for_tree(OWN_TREE)
  pick('[worktree] feature')
  wait_for_tree(FEATURE_TREE)
  entry.press(child, '\\pa')

  vim.fn.delete(repository.worktree, 'rf')
  entry.press(child, '\\e')
  entry.press(child, 'R')
  wait_for_tree(OWN_TREE)
  entry.press(child, 'R')

  eq(wait_for_tree(OWN_TREE), OWN_TREE)
  local told = vim.tbl_filter(function(message)
    return message.message
      == 'aineo: Worktree feature (feature) is gone; the explorer shows the folder Claude works in'
  end, entry.messages(child))
  eq(#told, 1)
end

return T
