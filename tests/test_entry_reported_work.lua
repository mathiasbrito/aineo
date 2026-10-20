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
--- keeps each request in `_G.pickers`.
local PICKER = [[
  _G.pickers = {}
  vim.ui.select = function(items, options, on_choice)
    table.insert(_G.pickers, { items = items, options = options, on_choice = on_choice })
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

--- A repository `reported-work-<name>` holding `main.txt`, with a worktree
--- `feature` beside it on the branch `feature`, and a branch `lonely` no
--- worktree has checked out.
---@class ReportedWorkRepository
---@field top string
---@field worktree string
---@field head string the full id of the repository's `HEAD`
---@field worktree_head string the full id of the worktree's `HEAD`, one commit past `head`

--- Makes the repository of `ReportedWorkRepository`, opens the layout in it
--- with the fake `claude` once Claude Code is ready, and returns where it
--- is, the token of the fake's start beside it.
---
---@param name string
---@return ReportedWorkRepository
---@return string token
local function open_with_worktree(name)
  local top = git_repo.create('reported-work-' .. name, { ['main.txt'] = { 'main' } })
  git_repo.git(top, { 'branch', 'lonely' })
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'feature')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature', worktree })
  git_repo.write(worktree, 'feature.txt', { 'feature' })
  git_repo.commit_all(worktree, 'Add the feature')
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local fake = claude_session.fake('reported-work-' .. name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local head = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local worktree_head = git_repo.git(worktree, { 'rev-parse', 'HEAD' })
  return { top = top, worktree = worktree, head = head, worktree_head = worktree_head },
    claude_session.start_token(fake, 1)
end

--- Offers the child's MCP home the announcement `work` of the start
--- `token`, as the relay's offer does, and returns its answer.
---
---@param work table
---@param token string
---@return boolean|string
local function announce(work, token)
  return child.lua_get([[require('aineo.mcp').receive_work_announcement(...)]], { work, token })
end

--- The texts of what `s` in the tab's changes pane offers, once its picker
--- opens, at most `PATIENCE_MS`.
---
---@return string[]
local function offered()
  local before = child.lua_get('#_G.pickers')
  child.lua([[require('aineo.entry.registry').tab_list[1].homes.changes.offer_scopes()]])
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('#_G.pickers') > before
  end, 20)
  return child.lua_get([[(function(request)
    return request and vim.tbl_map(request.options.format_item, request.items) or {}
  end)(_G.pickers[#_G.pickers])]])
end

--- Waits, at most `PATIENCE_MS`, until what `s` offers starts with
--- `expected`, and returns its first items as they are then.
---
---@param expected string[]
---@return string[]
local function wait_for_offered(expected)
  local first
  vim.wait(PATIENCE_MS, function()
    first = vim.list_slice(offered(), 1, #expected)
    return vim.deep_equal(first, expected)
  end, 100)
  return first
end

T['an announcement'] = MiniTest.new_set()

--- The Lua that keeps, in `_G.bases`, the base of each report the first
--- tab's changes home is handed, as it is handed it, and hands it on.
local KEEP_BASES_TAKEN = [[
  local changes = require('aineo.entry.registry').tab_list[1].homes.changes
  local add = changes.add_reported_work
  _G.bases = {}
  changes.add_reported_work = function(work, tell)
    table.insert(_G.bases, work.base)
    return add(work, tell)
  end
]]

--- The bases the first tab's changes home was handed (`KEEP_BASES_TAKEN`).
---
---@return string[]
local function bases_taken()
  return child.lua_get('_G.bases')
end

T['an announcement']['is taken by the tab with its base as the full id it names in the reported worktree’s folder'] = function()
  local repository, token = open_with_worktree('resolved')
  child.lua(KEEP_BASES_TAKEN)

  local taken = announce({ kind = 'worktree', path = repository.worktree, base = 'HEAD' }, token)

  eq({ taken, bases_taken() }, { true, { repository.worktree_head } })
end

T['an announcement']['of a branch a worktree has checked out has its base resolved in that worktree’s folder'] = function()
  local repository, token = open_with_worktree('resolved-branch')
  child.lua(KEEP_BASES_TAKEN)

  announce({ kind = 'branch', branch = 'feature', base = 'HEAD' }, token)

  eq(bases_taken(), { repository.worktree_head })
end

T['an announcement']['of a branch with no worktree, or of a folder that is no repository yet, has its base resolved in the session’s repository'] = function()
  local repository, token = open_with_worktree('resolved-session')
  child.lua(KEEP_BASES_TAKEN)
  local not_yet = vim.fs.joinpath(vim.fs.dirname(repository.top), 'not-yet')

  announce({ kind = 'branch', branch = 'lonely', base = 'HEAD' }, token)
  announce({ kind = 'worktree', path = not_yet, base = 'HEAD' }, token)

  eq(bases_taken(), { repository.head, repository.head })
end

T['an announcement']['whose base git cannot resolve is refused in words naming it, and nothing is recorded'] = function()
  local repository, token = open_with_worktree('unresolved')

  local answer =
    announce({ kind = 'worktree', path = repository.worktree, base = 'no-such-ref' }, token)
  announce({ kind = 'branch', branch = 'lonely', base = 'HEAD' }, token)

  eq(
    answer,
    ('base: no-such-ref names no commit in %s, nor in %s'):format(
      repository.worktree,
      repository.top
    )
  )
  local only_lonely = {
    ('[reported] lonely from %s'):format(repository.head:sub(1, 7)),
    '[reported] All reported work (1)',
  }
  eq(wait_for_offered(only_lonely), only_lonely)
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

T['Enter on a report’s line'] = MiniTest.new_set()

T['Enter on a report’s line']['shows its work alone, and the explorer follows'] = function()
  local repository, token = open_with_worktree('enter')
  announce({ kind = 'worktree', path = repository.worktree, base = 'HEAD' }, token)
  announce({ kind = 'branch', branch = 'lonely', base = 'HEAD', label = 'alone' }, token)
  wait_until(function()
    return #entry.messages(child) == 2
  end)
  entry.press(child, '\\g')
  wait_until(function()
    return entry.current_window(child) == 'aineo://changes-commits'
  end)
  entry.press(child, '\\g')
  local lonely_line = ('branch lonely from %s alone now'):format(repository.head:sub(1, 7))
  eq(
    wait_until(function()
      return lines_of('aineo://changes-commits')[2] == lonely_line
    end),
    true
  )

  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  entry.press(child, '<CR>')
  entry.press(child, '\\e')

  eq(
    wait_until(function()
      return (lines_of('aineo://explorer')[1] or ''):find(
        '(Branch lonely has no folder on disk)',
        1,
        true
      ) ~= nil
    end),
    true
  )
  eq(
    wait_until(function()
      return lines_of('aineo://changes-commits')[1] == 'Branch lonely (no worktree: commits only)'
    end),
    true
  )
end

return T
