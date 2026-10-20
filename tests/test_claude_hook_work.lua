local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

--- The child Neovim the hook relay tells: the user's editor, whose MCP home
--- keeps every announcement it is offered in `_G.announced`.
local editor = MiniTest.new_child_neovim()

--- The start token the hook relay is given in each case.
local TOKEN = 'start-token-hook'

--- How long a run of the hook relay may take, in milliseconds.
local PATIENCE_MS = 10000

--- The hook relay script.
local RELAY = vim.fs.joinpath(vim.fn.getcwd(), 'lua', 'aineo', 'claude', 'hook_relay.lua')

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      for name, value in pairs(git_repo.ENVIRONMENT) do
        vim.env[name] = value
      end
    end,
    pre_case = function()
      children.restart(editor)
      editor.lua([[
        _G.announced = {}
        require('aineo.mcp').on_work_announced(function(work, start_token)
          table.insert(_G.announced, { work, start_token })
          return true
        end)
      ]])
    end,
    post_once = editor.stop,
  },
})

--- Runs the hook relay as Claude Code runs aineo's `PostToolUse` hook, after
--- a `Bash` call of `command` in `cwd`, telling the editor, and waits for it
--- to end, at most `PATIENCE_MS`; returns its exit code and what it wrote
--- on stdout and stderr.
---
---@param command string
---@param cwd string
---@return { code: integer, stdout: string, stderr: string }
local function run_hook(command, cwd)
  local input = vim.json.encode({
    session_id = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31',
    transcript_path = '/tmp/aineo-hook/c9d64d84.jsonl',
    cwd = cwd,
    hook_event_name = 'PostToolUse',
    tool_name = 'Bash',
    tool_input = { command = command, description = 'Make work' },
    tool_response = { stdout = '', stderr = '', interrupted = false },
    tool_use_id = 'toolu_hook',
  })
  local ended = vim
    .system({
      vim.v.progpath,
      '--headless',
      '--clean',
      '--cmd',
      'set noloadplugins',
      '-l',
      RELAY,
      editor.job.address,
      TOKEN,
      'PostToolUse',
      '4242',
      cwd,
    }, { stdin = input, text = true })
    :wait(PATIENCE_MS)
  return { code = ended.code, stdout = ended.stdout, stderr = ended.stderr }
end

--- How a run of the hook ends when it ends well: exit 0, nothing written.
local SILENT_END = { code = 0, stdout = '', stderr = '' }

--- What the editor was offered, each announcement beside its start token.
---
---@return table[]
local function announced()
  return editor.lua_get('_G.announced')
end

T['a git command that makes work'] = MiniTest.new_set()

T['a git command that makes work']['is told as a worktree, from the HEAD of the folder it ran in'] = function()
  local top = git_repo.create('hook-work-worktree', { ['main.txt'] = { 'main' } })
  local head = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature/x', '../wt' })

  local ended = run_hook('git worktree add -b feature/x ../wt', top)

  eq(ended, SILENT_END)
  eq(announced(), {
    {
      {
        kind = 'worktree',
        path = vim.fs.joinpath(vim.fs.dirname(top), 'wt'),
        base = head,
        by_hook = true,
      },
      TOKEN,
    },
  })
end

T['a git command that makes work']['is told as a branch, from the start point it names'] = function()
  local top = git_repo.create('hook-work-start', { ['main.txt'] = { 'main' } })
  local first = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.write(top, 'next.txt', { 'next' })
  git_repo.commit_all(top, 'Next')
  git_repo.git(top, { 'branch', 'feature/y', 'HEAD~1' })

  run_hook('git branch feature/y HEAD~1', top)

  eq(
    announced(),
    { { { kind = 'branch', branch = 'feature/y', base = first, by_hook = true }, TOKEN } }
  )
end

T['a git command that makes work']['is told from the HEAD of the folder -C names'] = function()
  local top = git_repo.create('hook-work-folder', { ['main.txt'] = { 'main' } })
  local head = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'branch', 'feature/z' })

  run_hook('git -C repo branch feature/z', vim.fs.dirname(top))

  eq(
    announced(),
    { { { kind = 'branch', branch = 'feature/z', base = head, by_hook = true }, TOKEN } }
  )
end

T['a git command that makes work']['is told as a worktree whose path is read in the folder -C names'] = function()
  local top = git_repo.create('hook-work-folder-worktree', { ['main.txt'] = { 'main' } })
  local head = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature/c', '../wt' })

  run_hook('git -C repo worktree add -b feature/c ../wt', vim.fs.dirname(top))

  eq(announced(), {
    {
      {
        kind = 'worktree',
        path = vim.fs.joinpath(vim.fs.dirname(top), 'wt'),
        base = head,
        by_hook = true,
      },
      TOKEN,
    },
  })
end

T['a command the hook cannot read'] = MiniTest.new_set()

T['a command the hook cannot read']['tells nothing, and the hook ends well'] = function()
  local top = git_repo.create('hook-work-unread', { ['main.txt'] = { 'main' } })

  local ended = run_hook('cd . && git branch feature/q', top)

  eq({ ended, announced() }, { SILENT_END, {} })
end

T['a command the hook cannot read']['tells nothing when its start point names no commit'] = function()
  local top = git_repo.create('hook-work-no-start', { ['main.txt'] = { 'main' } })

  local ended = run_hook('git branch feature/q no-such-start', top)

  eq({ ended, announced() }, { SILENT_END, {} })
end

T['an editor that does not answer'] = MiniTest.new_set()

T['an editor that does not answer']['leaves the hook ending well within 6 s, silent'] = function()
  local top = git_repo.create('hook-work-blocked', { ['main.txt'] = { 'main' } })
  git_repo.git(top, { 'branch', 'feature/hang' })
  vim.rpcnotify(editor.job.channel, 'nvim_exec_lua', 'vim.uv.sleep(12000)', {})
  local started = vim.uv.hrtime()

  local ended = run_hook('git branch feature/hang', top)

  local within_ms = (vim.uv.hrtime() - started) / 1e6
  eq({ ended, within_ms < 8000 }, { SILENT_END, true })
end

return T
