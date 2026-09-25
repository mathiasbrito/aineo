--- Starts a Neovim as a user starts `nvim` in a terminal emulator — with its
--- own UI, attached before its `VimEnter` — and queries it. A mini.test child
--- always starts headless, so the editor runs in a terminal of such a child
--- (`jobstart(…, { term = true })`), with the suites' minimal init
--- and an `AINEO_CHILD` of the test's choosing
--- (`tests/helpers/entry_editor_init.lua`), and
--- listening on an address of its own, which the test connects to.
---
--- The editor inherits the child's environment, and with it the isolation
--- `make test` sets up and the suites' init adds to it. It ends when its child
--- is stopped, which closes its terminal.

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local EDITOR_INIT = vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'entry_editor_init.lua')

--- The hosting child's screen, and so the editor's: Claude's column, half of
--- it, holds the fake `claude`'s screens, which Claude Code drew 80 columns
--- wide, whole.
local COLUMNS = 240
local LINES = 42

--- How long a test waits for the editor to listen, to start, and to settle.
local PATIENCE_MS = 10000

--- How many scheduled callbacks deep the editor's settling goes: deeper than
--- anything its startup schedules, a callback scheduled from one scheduled
--- at `VimEnter` included.
local SETTLING_DEPTH = 4

---@class aineo.test.Editor
---@field channel integer the test's RPC channel to the editor
---@field screen fun(): string[] the lines of the terminal the editor draws in

--- How to start the editor: its arguments, the variables it gets on top of
--- the child's, the text piped to its standard input, and the size of the
--- terminal it draws in.
---@class aineo.test.EditorStart
---@field args? string[]
---@field environment? table<string, string>
---@field stdin? string
---@field columns? integer the terminal's columns, `COLUMNS` when not given
---@field lines? integer the terminal's lines, `LINES` when not given

--- The command that starts the editor with `args`, reading `stdin` from a pipe
--- when given, as `printf <stdin> | nvim <args>` does.
---
---@param address string where the editor listens
---@param args string[]
---@param stdin? string
---@return string[]
local function editor_command(address, args, stdin)
  local command = vim.list_extend(
    { vim.v.progpath, '--clean', '-n', '-u', EDITOR_INIT, '--listen', address },
    args
  )
  if stdin == nil then
    return command
  end
  return vim.list_extend({ 'sh', '-c', 'printf %s "$AINEO_ENTRY_STDIN" | exec "$0" "$@"' }, command)
end

--- Sends `code` to the editor as a Lua chunk with `args`, and returns what it
--- returns.
---
--- Raises an error, with what the editor's screen shows, when the editor is
--- blocked — at a hit-enter prompt, say — where it would answer no request
--- and the test would wait for ever.
---
---@param editor aineo.test.Editor
---@param code string
---@param args? any[]
---@return any
function M.request(editor, code, args)
  local mode = vim.rpcrequest(editor.channel, 'nvim_get_mode')
  if mode.blocking then
    error(
      ('the editor is blocked in mode %s; its screen:\n%s'):format(
        mode.mode,
        table.concat(editor.screen(), '\n')
      )
    )
  end
  return vim.rpcrequest(editor.channel, 'nvim_exec_lua', code, args or {})
end

--- The value of the Lua expression `expression` in the editor.
---
---@param editor aineo.test.Editor
---@param expression string
---@return any
function M.get(editor, expression)
  return M.request(editor, 'return ' .. expression)
end

--- Waits, at most `PATIENCE_MS`, until the editor has run its `VimEnter`
--- autocommands and then every callback scheduled from them, from its
--- `UIEnter` ones, and from the callbacks those schedule, `SETTLING_DEPTH`
--- deep. Raises an error when it does not.
---
---@param editor aineo.test.Editor
function M.settle(editor)
  assert(
    vim.wait(PATIENCE_MS, function()
      return M.get(editor, 'vim.v.vim_did_enter') == 1
    end, 20),
    'the editor did not start'
  )
  M.request(
    editor,
    [[
      _G.entry_editor_settled = false
      local function settle(depth)
        if depth == 0 then
          _G.entry_editor_settled = true
          return
        end
        vim.schedule(function()
          settle(depth - 1)
        end)
      end
      settle(...)
    ]],
    { SETTLING_DEPTH }
  )
  assert(
    vim.wait(PATIENCE_MS, function()
      return M.get(editor, '_G.entry_editor_settled') == true
    end, 20),
    'the editor did not settle'
  )
end

--- Starts the editor in a terminal of `child`, which it restarts first with
--- `children_restart` at `start.columns` by `start.lines` (`COLUMNS` by
--- `LINES` when not given), and returns it once it has accepted the test's
--- connection — retried until it listens — without waiting for it to start
--- or settle.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param children_restart fun(child: table) how the suite restarts a child
---@param start? aineo.test.EditorStart
---@return aineo.test.Editor
function M.launch(child, children_restart, start)
  start = start or {}
  children_restart(child)
  child.o.columns = start.columns or COLUMNS
  child.o.lines = start.lines or LINES
  local address = vim.fn.tempname()
  local environment = vim.tbl_extend(
    'force',
    start.environment or {},
    start.stdin and { AINEO_ENTRY_STDIN = start.stdin } or {}
  )
  child.lua(
    [[
      local command, environment = ...
      vim.fn.jobstart(command, {
        term = true,
        env = next(environment) and environment or nil,
      })
    ]],
    { editor_command(address, start.args or {}, start.stdin), environment }
  )
  local channel
  assert(
    vim.wait(PATIENCE_MS, function()
      if vim.uv.fs_stat(address) == nil then
        return false
      end
      local connected, id = pcall(vim.fn.sockconnect, 'pipe', address, { rpc = true })
      channel = connected and id or nil
      return connected
    end, 20),
    'the editor did not listen on ' .. address
  )
  return {
    channel = channel,
    screen = function()
      return child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, false)')
    end,
  }
end

--- Starts the editor as `M.launch()` does, and returns it once it has
--- started and settled (`M.settle()`).
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param children_restart fun(child: table) how the suite restarts a child
---@param start? aineo.test.EditorStart
---@return aineo.test.Editor
function M.start(child, children_restart, start)
  local editor = M.launch(child, children_restart, start)
  M.settle(editor)
  return editor
end

--- The editor's mode, as `nvim_get_mode()` gives it: a query the editor
--- answers even while it is blocked, at a hit-enter prompt, say.
---
---@param editor aineo.test.Editor
---@return { mode: string, blocking: boolean }
function M.mode(editor)
  return vim.rpcrequest(editor.channel, 'nvim_get_mode')
end

--- Waits, at most `PATIENCE_MS`, until a line of the editor's screen holds
--- `text`, read from the terminal it draws in rather than asked of the
--- editor; returns whether one did.
---
---@param editor aineo.test.Editor
---@param text string
---@return boolean shown
function M.wait_for_screen(editor, text)
  return vim.wait(PATIENCE_MS, function()
    return vim.iter(editor.screen()):any(function(line)
      return line:find(text, 1, true) ~= nil
    end)
  end, 20)
end

return M
