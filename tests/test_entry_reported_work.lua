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

T['an announcement'] = MiniTest.new_set()

--- The Lua that keeps, in `_G.bases`, the bases of the branches of each
--- report the first tab's changes home is handed, as it is handed them, and
--- hands it on.
local KEEP_BASES_TAKEN = [[
  local changes = require('aineo.entry.registry').tab_list[1].homes.changes
  local add = changes.add_reported_work
  _G.bases = {}
  changes.add_reported_work = function(work, tell)
    table.insert(_G.bases, vim.tbl_map(function(branch)
      return branch.base
    end, work.branches))
    return add(work, tell)
  end
]]

--- The bases the first tab's changes home was handed (`KEEP_BASES_TAKEN`).
---
---@return string[][]
local function bases_taken()
  return child.lua_get('_G.bases')
end

--- An agent's call for the worktree at `path`, labelled `T111`, listing
--- `branches`.
---
---@param path string
---@param branches table[]
---@return table
local function call_for(path, branches)
  return { worktree = path, label = 'T111', branches = branches }
end

T['an announcement']['is taken by the tab with each branch’s base as the full id it names in the worktree’s folder'] = function()
  local repository, token = open_with_worktree('resolved')
  child.lua(KEEP_BASES_TAKEN)

  local taken = announce(
    call_for(repository.worktree, {
      { name = 'feature', base = 'HEAD' },
      { name = 'lonely', base = 'HEAD~1' },
    }),
    token
  )

  eq({ taken, bases_taken() }, { true, { { repository.worktree_head, repository.head } } })
end

T['an announcement']['of a folder that is no repository yet has its bases resolved in the session’s repository'] = function()
  local repository, token = open_with_worktree('resolved-session')
  child.lua(KEEP_BASES_TAKEN)
  local not_yet = vim.fs.joinpath(vim.fs.dirname(repository.top), 'not-yet')

  announce(call_for(not_yet, { { name = 'lonely', base = 'HEAD' } }), token)

  eq(bases_taken(), { { repository.head } })
end

T['an announcement']['listing no branch is taken as it is'] = function()
  local repository, token = open_with_worktree('no-branch')
  child.lua(KEEP_BASES_TAKEN)

  local taken = announce(call_for(repository.worktree, {}), token)

  eq({ taken, bases_taken() }, { true, { {} } })
end

T['an announcement']['whose base git cannot resolve is refused in words naming the item, and nothing is recorded'] = function()
  local repository, token = open_with_worktree('unresolved')
  child.lua(KEEP_BASES_TAKEN)

  local answer = announce(
    call_for(repository.worktree, {
      { name = 'feature', base = 'HEAD' },
      { name = 'lonely', base = 'no-such-ref' },
    }),
    token
  )

  eq(
    answer,
    ('branches[2].base: no-such-ref names no commit in %s, nor in %s'):format(
      repository.worktree,
      repository.top
    )
  )
  eq(bases_taken(), {})
end

T['an announcement']['naming a branch git does not have is refused in words naming the item, and nothing is recorded'] = function()
  local repository, token = open_with_worktree('unknown-branch')
  child.lua(KEEP_BASES_TAKEN)

  local answer = announce(
    call_for(repository.worktree, {
      { name = 'feature', base = 'HEAD' },
      { name = 'feature/never', base = 'HEAD' },
    }),
    token
  )

  eq(
    answer,
    ('branches[2].name: feature/never is no local branch in %s'):format(repository.worktree)
  )
  eq(bases_taken(), {})
end

T['an announcement']['naming a revision of a branch, not a branch, is refused naming the item'] =
  MiniTest.new_set({ parametrize = { { 'feature^0' }, { 'lonely~1' }, { 'feature@{0}' } } })

T['an announcement']['naming a revision of a branch, not a branch, is refused naming the item']['given'] = function(
  name
)
  local repository, token = open_with_worktree('revision-branch')
  child.lua(KEEP_BASES_TAKEN)

  local answer = announce(
    call_for(repository.worktree, {
      { name = 'feature', base = 'HEAD' },
      { name = name, base = 'HEAD' },
    }),
    token
  )

  eq(answer, ('branches[2].name: %s is no local branch in %s'):format(name, repository.worktree))
  eq(bases_taken(), {})
end

T['an announcement']['of an older shape is not taken'] = function()
  local repository, token = open_with_worktree('older-shape')

  local taken = announce({ kind = 'worktree', path = repository.worktree, base = 'HEAD' }, token)

  eq(taken, false)
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

T['Enter on a branch’s line'] = MiniTest.new_set()

T['Enter on a branch’s line']['shows its commits alone, and the explorer follows'] = function()
  local repository, token = open_with_worktree('enter')
  announce(
    call_for(repository.worktree, {
      { name = 'feature', base = 'HEAD' },
      { name = 'lonely', base = 'HEAD' },
    }),
    token
  )
  wait_until(function()
    return #entry.messages(child) == 1
  end)
  entry.press(child, '\\g')
  wait_until(function()
    return entry.current_window(child) == 'aineo://changes-commits'
  end)
  entry.press(child, '\\g')
  local lonely_line = ('    lonely from %s'):format(repository.head:sub(1, 7))
  eq(
    wait_until(function()
      return lines_of('aineo://changes-commits')[6] == lonely_line
    end),
    true
  )

  child.lua('vim.api.nvim_win_set_cursor(0, { 6, 0 })')
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
      return lines_of('aineo://changes-commits')[1]
        == 'Branch lonely (not checked out: commits only)'
    end),
    true
  )
end

T['a report of aineo’s hook'] = MiniTest.new_set()

T['a report of aineo’s hook']['through the editor, adds its branch beside the agent’s, the label kept'] = function()
  local repository, token = open_with_worktree('hook-through-editor')
  local taken =
    announce(call_for(repository.worktree, { { name = 'feature', base = 'HEAD' } }), token)
  eq(taken, true)
  wait_until(function()
    return #entry.messages(child) == 1
  end)
  git_repo.git(repository.worktree, { 'branch', 'extra' })

  local hook_taken = announce({
    worktree = repository.worktree,
    branches = { { name = 'extra', base = 'HEAD' } },
    by_hook = true,
  }, token)
  eq(hook_taken, true)

  entry.press(child, '\\g')
  wait_until(function()
    return entry.current_window(child) == 'aineo://changes-commits'
  end)
  entry.press(child, '\\g')
  local expected = { 'T111 now', '  feature', 'feature', 'extra' }
  local function tree_shown()
    local shown = lines_of('aineo://changes-commits')
    return {
      shown[2],
      shown[3],
      (shown[4] or ''):match('^    (%S+)'),
      (shown[6] or ''):match('^    (%S+)'),
    }
  end
  wait_until(function()
    return vim.deep_equal(tree_shown(), expected)
  end)
  eq(tree_shown(), expected)
end

return T
