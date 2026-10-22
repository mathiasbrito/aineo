local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

--- The child Neovim the hook relay tells: the user's editor, whose
--- `receive_permission_wait()` keeps what it is told in `_G.waits`.
local editor = MiniTest.new_child_neovim()

--- The start token the hook relay is given in each case.
local TOKEN = 'start-token-permission'

--- How long a run of the hook relay may take, in milliseconds.
local PATIENCE_MS = 10000

--- The hook relay script.
local RELAY = vim.fs.joinpath(vim.fn.getcwd(), 'lua', 'aineo', 'claude', 'hook_relay.lua')

--- Hook inputs Claude Code 2.1.308 wrote, recorded once and scrubbed: the
--- `SessionStart` input, then five `PermissionRequest` inputs, all from the
--- main agent (none carries an `agent_id`).
local RECORDED_INPUTS =
  vim.list_slice(vim.fn.readfile('tests/fixtures/transcripts/hook-inputs-2.1.308.jsonl'), 2)

--- The session every recorded input is from.
local RECORDED_SESSION = '00000000-0000-4000-8000-000000000001'

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(editor)
      editor.lua([[
        _G.waits = {}
        require('aineo.claude').receive_permission_wait = function(...)
          table.insert(_G.waits, { select('#', ...), ... })
        end
      ]])
    end,
    post_once = editor.stop,
  },
})

--- Runs the hook relay as Claude Code runs aineo's `PermissionRequest` hook,
--- with `input` on its stdin, and waits for it to end, at most
--- `PATIENCE_MS`; returns its exit code and what it wrote on stdout and
--- stderr.
---
---@param input string
---@return { code: integer, stdout: string, stderr: string }
local function run_hook(input)
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
      'PermissionRequest',
      '4242',
      '/project',
    }, { stdin = input, text = true })
    :wait(PATIENCE_MS)
  return { code = ended.code, stdout = ended.stdout, stderr = ended.stderr }
end

--- How a run of the hook ends when it ends well: exit 0, nothing written.
local SILENT_END = { code = 0, stdout = '', stderr = '' }

--- What the editor was told, each wait as the number of arguments and then
--- the arguments.
---
---@return table[]
local function waits()
  return editor.lua_get('_G.waits')
end

T['a PermissionRequest hook'] = MiniTest.new_set({
  parametrize = { { 1 }, { 2 }, { 3 }, { 4 }, { 5 } },
})

T['a PermissionRequest hook']['tells the editor the start token and the session, and ends silent'] = function(
  recorded
)
  local ended = run_hook(RECORDED_INPUTS[recorded + 1])

  eq({ ended, waits() }, { SILENT_END, { { 3, TOKEN, RECORDED_SESSION, vim.NIL } } })
end

T['a PermissionRequest hook from a subagent'] = MiniTest.new_set()

T['a PermissionRequest hook from a subagent']['names the subagent that asks'] = function()
  local input = vim.json.decode(RECORDED_INPUTS[2])
  input.agent_id = 'a0000000000000001'
  input.agent_type = 'Explore'

  local ended = run_hook(vim.json.encode(input))

  eq({ ended, waits() }, { SILENT_END, { { 3, TOKEN, RECORDED_SESSION, 'a0000000000000001' } } })
end

T['a hook input the relay cannot use'] = MiniTest.new_set({
  parametrize = {
    { 'nothing', '' },
    { 'text that is not JSON', 'the permission prompt' },
    { 'a JSON list', '[]' },
    { 'a JSON object with no session', '{"agent_id":"a1"}' },
    { 'a session that is not text', '{"session_id":7}' },
    { 'a cut input', '{"session_id":"00000000-0000-4000-8000-0000000000' },
  },
})

T['a hook input the relay cannot use']['tells nothing, and ends silent'] = function(_, input)
  local ended = run_hook(input)

  eq({ ended, waits() }, { SILENT_END, {} })
end

T['an editor that does not answer'] = MiniTest.new_set()

T['an editor that does not answer']['leaves the hook ending well within 6 s, silent'] = function()
  vim.rpcnotify(editor.job.channel, 'nvim_exec_lua', 'vim.uv.sleep(12000)', {})
  local started = vim.uv.hrtime()

  local ended = run_hook(RECORDED_INPUTS[2])

  local within_ms = (vim.uv.hrtime() - started) / 1e6
  eq({ ended, within_ms < 8000 }, { SILENT_END, true })
end

return T
