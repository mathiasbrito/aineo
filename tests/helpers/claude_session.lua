--- Starts aineo's Claude session in a child Neovim against a fake `claude`
--- (`tests/helpers/fake_claude.lua`, or `tests/helpers/fake_claude_deaf.sh`),
--- drives and quits that child as a user would, and reads back what the fake
--- recorded.
---
--- Loaded in the test runner and, by `start()` and `start_again()`, in the
--- child too: the child builds the session's settings itself, so that the
--- tables in them reach the session as Lua wrote them rather than as the RPC
--- channel converts them.

local fixture = dofile('tests/helpers/fixture.lua')

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local THIS_FILE = vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'claude_session.lua')
local FAKE_CLAUDE = vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'fake_claude.lua')
local DEAF_FAKE_CLAUDE = vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'fake_claude_deaf.sh')

--- How long a test waits for the fake to do what it is waiting for.
M.PATIENCE_MS = 5000

--- How long a test waits for the fake to end once its editor quits: longer
--- than the session's whole stop.
M.STOP_PATIENCE_MS = 15000

--- The command that runs the fake `claude` in the CLI's place — this Neovim's
--- own executable running the fake as a script — followed by `extra_words`.
---
---@param extra_words? string[]
---@return string[]
function M.fake_command(extra_words)
  return vim.list_extend({ vim.v.progpath, '--clean', '-l', FAKE_CLAUDE }, extra_words or {})
end

--- The command that runs the fake `claude` deaf to every key and to the
--- hangup (`tests/helpers/fake_claude_deaf.sh`).
---
---@return string[]
function M.deaf_fake_command()
  return { 'sh', DEAF_FAKE_CLAUDE }
end

--- The session's settings a test starts it with: the fake's command, the
--- editor's working directory, and stand-ins for the MCP servers, the tools to
--- pre-allow and the instructions the composition root hands over — one server
--- with variables and one with none — overridden key by key by `overrides`.
---
---@param overrides? table
---@return table
function M.stand_in_settings(overrides)
  return vim.tbl_extend('force', {
    cmd = M.fake_command(),
    cwd = vim.fn.getcwd(),
    mcp_servers = {
      aineo = {
        type = 'stdio',
        command = 'nvim',
        args = { '--headless', '-l', 'relay.lua' },
        env = { AINEO_SERVER = '/tmp/aineo-stand-in.sock' },
      },
      quiet = { type = 'stdio', command = 'true', args = {}, env = {} },
    },
    allowed_tools = { 'mcp__aineo__report', 'mcp__aineo__stand_in' },
    instructions = 'Report each step with the \'report\' tool — "started" first.\n  Then $HOME, `code` and a trailing space ',
  }, overrides or {})
end

--- A fake `claude` for one test: its record file, emptied, under
--- `.tests/fixtures/claude-<name>/`, and the environment that makes the fake
--- run in `mode` and write that record.
---
---@param name string the test's own name for its files
---@param mode string one of the fake's modes
---@param extra_environment? table<string, string> more of the fake's variables
---@return { record: string, environment: table<string, string> }
function M.fake(name, mode, extra_environment)
  local record = vim.fs.joinpath(fixture.directory('claude-' .. name), 'record.jsonl')
  return {
    record = record,
    environment = vim.tbl_extend('force', {
      AINEO_FAKE_CLAUDE_RECORD = record,
      AINEO_FAKE_CLAUDE_MODE = mode,
    }, extra_environment or {}),
  }
end

--- Starts the session in `child` with `fake`'s environment and the stand-in
--- settings overridden by `overrides`, shows the buffer `start_session()`
--- returns in the current window at once, as the layout will, and returns
--- that buffer.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param fake { environment: table<string, string> }
---@param overrides? table
---@return integer
function M.start(child, fake, overrides)
  return child.lua(
    [[
      local helper, environment, overrides = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      local buffer = require('aineo.claude').start_session(helper.stand_in_settings(overrides))
      vim.api.nvim_win_set_buf(0, buffer)
      return buffer
    ]],
    { THIS_FILE, fake.environment, overrides or vim.empty_dict() }
  )
end

--- Starts the session in `child` as `start()` does, but shows its buffer in
--- no window, and returns that buffer.
---
---@param child table
---@param fake { environment: table<string, string> }
---@return integer
function M.start_hidden(child, fake)
  return child.lua(
    [[
      local helper, environment = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      return require('aineo.claude').start_session(helper.stand_in_settings())
    ]],
    { THIS_FILE, fake.environment }
  )
end

--- Starts the session in `child` as `start()` does, but under `:silent!`,
--- which silences the errors of `jobstart()` and of `start_session()` alike,
--- and shows nothing.
---
---@param child table
---@param fake { environment: table<string, string> }
---@param overrides? table
function M.start_silently(child, fake, overrides)
  child.lua(
    [[
      local helper, environment, overrides = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      _G.aineo_test_settings = helper.stand_in_settings(overrides)
      vim.cmd('silent! lua require("aineo.claude").start_session(_G.aineo_test_settings)')
    ]],
    { THIS_FILE, fake.environment, overrides or vim.empty_dict() }
  )
end

--- Calls `start_session()` in `child` once more, with the stand-in settings,
--- and returns what it returns without showing it anywhere: which windows show
--- a new terminal is the session's to decide.
---
---@param child table
---@return integer
function M.start_again(child)
  return child.lua(
    "return require('aineo.claude').start_session(dofile(...).stand_in_settings())",
    { THIS_FILE }
  )
end

--- Wipes the terminal `buffer` in `child` and, in the same tick — before the
--- editor has seen its process end — calls `start_session()` with the
--- stand-in settings; returns what that returns.
---
---@param child table
---@param buffer integer
---@return integer
function M.start_again_after_wiping(child, buffer)
  return child.lua(
    [[
      local helper, buffer = dofile(...), select(2, ...)
      vim.cmd.bwipeout({ tostring(buffer), bang = true })
      return require('aineo.claude').start_session(helper.stand_in_settings())
    ]],
    { THIS_FILE, buffer }
  )
end

--- Wipes the terminal `buffer` in `child` and, in the same tick — before the
--- editor has seen its process end — returns what `session_status()` reports,
--- as a list.
---
---@param child table
---@param buffer integer
---@return any[]
function M.status_after_wiping(child, buffer)
  return child.lua(
    [[
      vim.cmd.bwipeout({ tostring(...), bang = true })
      return { require('aineo.claude').session_status() }
    ]],
    { buffer }
  )
end

--- What `session_status()` reports in `child`, as a list, once its first value
--- is `state` — waiting for that at most `patience_ms`, `PATIENCE_MS` unless
--- given — or when the wait runs out.
---
---@param child table
---@param state string
---@param patience_ms? integer
---@return any[]
function M.wait_for_status(child, state, patience_ms)
  local status
  vim.wait(patience_ms or M.PATIENCE_MS, function()
    status = child.lua_get("{ require('aineo.claude').session_status() }")
    return status[1] == state
  end, 20)
  return status
end

--- The text of `buffer` in `child`, its lines joined by line feeds, once it
--- holds `part` — waiting for that at most `PATIENCE_MS` — or when the wait
--- runs out; empty when `buffer` is no longer valid.
---
---@param child table
---@param buffer integer
---@param part string
---@return string
function M.wait_for_screen(child, buffer, part)
  local screen
  vim.wait(M.PATIENCE_MS, function()
    screen = child.lua(
      [[
        local buffer = ...
        if not vim.api.nvim_buf_is_valid(buffer) then
          return ''
        end
        return table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
      ]],
      { buffer }
    )
    return screen:find(part, 1, true) ~= nil
  end, 20)
  return screen
end

--- The `'buftype'` of `buffer` in `child`, or `vim.NIL` when `buffer` is no
--- longer valid — so that a test given a wiped buffer fails on its assertion.
---
---@param child table
---@param buffer integer
---@return string|userdata
function M.buftype(child, buffer)
  return child.lua(
    'local buffer = ...; return vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype or nil',
    { buffer }
  )
end

--- The arguments the fake was started with, after its own script, once it has
--- started (`wait_for_start()`); none when it has not.
---
---@param fake { record: string }
---@return string[]
function M.arguments(fake)
  return M.wait_for_start(fake).argv or {}
end

--- The words of `argv` that follow the first `flag` in it, up to the next word
--- that starts with `--`; none when `flag` is not in `argv`.
---
---@param argv string[]
---@param flag string such as `--mcp-config`
---@return string[]
function M.words_after(argv, flag)
  local start = vim.iter(ipairs(argv)):find(function(_, word)
    return word == flag
  end)
  if not start then
    return {}
  end
  local words = {}
  for index = start + 1, #argv do
    if vim.startswith(argv[index], '--') then
      break
    end
    table.insert(words, argv[index])
  end
  return words
end

--- The words of `argv` that start with `--`, sorted.
---
---@param argv string[]
---@return string[]
function M.flags(argv)
  local flags = vim.tbl_filter(function(word)
    return vim.startswith(word, '--')
  end, argv)
  table.sort(flags)
  return flags
end

--- The words of `argv` that follow the first `flag`, as `words_after()` finds
--- them, each decoded from JSON.
---
---@param argv string[]
---@param flag string
---@return any[]
function M.decoded_words_after(argv, flag)
  return vim.tbl_map(vim.json.decode, M.words_after(argv, flag))
end

--- The entries the fake has recorded so far, in order.
---
---@param fake { record: string }
---@return table[]
function M.record(fake)
  if vim.fn.filereadable(fake.record) == 0 then
    return {}
  end
  return vim.tbl_map(vim.json.decode, vim.fn.readfile(fake.record))
end

--- Once `fake` has started, and so reads its keys raw, presses a double Ctrl-C
--- in the terminal `buffer` of `child`, as a user ending Claude Code would,
--- and waits for the session to report `exited` — so that the test's teardown
--- does not spend the whole stop on quit. Presses nothing when the session has
--- exited already or `buffer` is gone: it runs from `MiniTest.finally()`, where
--- an error would stop the whole run rather than fail the test.
---
---@param child table
---@param fake { record: string }
---@param buffer integer the session's terminal buffer
function M.end_by_keys(child, fake, buffer)
  M.wait_for_start(fake)
  child.lua(
    [[
      local buffer = ...
      local running = require('aineo.claude').session_status() ~= 'exited'
      if running and vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_chan_send(vim.bo[buffer].channel, '\3\3')
      end
    ]],
    { buffer }
  )
  M.wait_for_status(child, 'exited')
end

--- Presses `keys` in the terminal `buffer` of `child`, as a user typing in
--- Claude Code's window would.
---
---@param child table
---@param buffer integer the session's terminal buffer
---@param keys string the bytes the keys send, such as `'\r'` for Enter
function M.press_keys(child, buffer, keys)
  child.lua('local buffer, keys = ...; vim.api.nvim_chan_send(vim.bo[buffer].channel, keys)', {
    buffer,
    keys,
  })
end

--- Quits `child` with `:qa`, as a user would, without waiting for it to end.
---
---@param child table
function M.quit(child)
  child.lua_notify('vim.cmd.qall()')
end

--- Wipes the terminal `buffer` in `child` and quits it with `:qa` in the same
--- tick, as `:bwipeout! | qa` would, without waiting for it to end.
---
---@param child table
---@param buffer integer
function M.wipe_terminal_and_quit(child, buffer)
  child.lua_notify('vim.cmd.bwipeout({ tostring(...), bang = true }); vim.cmd.qall()', { buffer })
end

--- Registers in `child`, as another plugin would, a handler of Neovim's quit
--- (`VimLeavePre`) that writes the line `ran` to the file `path`.
---
---@param child table
---@param path string
function M.add_exit_handler(child, path)
  child.lua(
    [[
      local path = ...
      vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
          vim.fn.writefile({ 'ran' }, path)
        end,
      })
    ]],
    { path }
  )
end

--- Registers in `child`, as another plugin might, a handler of Neovim's quit
--- (`VimLeavePre`) that stops every job — Claude Code's terminal among them —
--- so that a handler after it finds that terminal closed while its exit is
--- not yet seen.
---
---@param child table
function M.add_job_stopping_exit_handler(child)
  child.lua([[
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        for _, channel in ipairs(vim.api.nvim_list_chans()) do
          if channel.stream == 'job' then
            vim.fn.jobstop(channel.id)
          end
        end
      end,
    })
  ]])
end

--- Registers in `child`, as another plugin might, a handler of Neovim's quit
--- (`VimLeavePre`) that wipes every terminal buffer — Claude Code's among them
--- — so that a handler after it finds that terminal gone while its process
--- still runs.
---
---@param child table
function M.add_terminal_wiping_exit_handler(child)
  child.lua([[
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[buffer].buftype == 'terminal' then
            vim.api.nvim_buf_delete(buffer, { force = true })
          end
        end
      end,
    })
  ]])
end

--- The lines of the file `path` once it exists — waiting for that at most
--- `STOP_PATIENCE_MS` — or none when the wait runs out.
---
---@param path string
---@return string[]
function M.wait_for_file(path)
  vim.wait(M.STOP_PATIENCE_MS, function()
    return vim.fn.filereadable(path) == 1
  end, 50)
  return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
end

--- How often `quit_pressing_ctrl_c()` presses Ctrl-C in the editor.
local CTRL_C_EVERY_MS = 100

--- Quits `child` with `:qa` and, while it quits, presses Ctrl-C in the editor
--- every `CTRL_C_EVERY_MS`, as a user waiting on a slow quit might, until the
--- editor has exited or `STOP_PATIENCE_MS` has passed. A press that reaches an
--- editor already exiting fails, and is dropped: the exit is what the presses
--- wait for.
---
---@param child table
function M.quit_pressing_ctrl_c(child)
  M.quit(child)
  vim.wait(M.STOP_PATIENCE_MS, function()
    if vim.fn.jobwait({ child.job.id }, 0)[1] ~= -1 then
      return true
    end
    pcall(child.api_notify.nvim_input, '<C-c>')
    return false
  end, CTRL_C_EVERY_MS)
end

--- What the fake did besides starting and receiving input — a turn it ended,
--- a signal, how it ended — in order, once it has ended, waiting for that at
--- most `STOP_PATIENCE_MS`, or when the wait runs out.
---
---@param fake { record: string }
---@return table[]
function M.wait_for_end(fake)
  local events
  vim.wait(M.STOP_PATIENCE_MS, function()
    events = vim.tbl_filter(function(entry)
      return entry.argv == nil and entry.received == nil
    end, M.record(fake))
    return #events > 0 and events[#events].ended ~= nil
  end, 50)
  return events
end

--- Whether every process of the group that `pid` leads — a terminal job and
--- whatever it started — has ended, once they have, waiting for that at most
--- `STOP_PATIENCE_MS`, or when the wait runs out; false when there is no `pid`
--- because the fake never started.
---
---@param pid integer?
---@return boolean
function M.wait_for_process_end(pid)
  if not pid then
    return false
  end
  return vim.wait(M.STOP_PATIENCE_MS, function()
    return vim.uv.kill(-pid, 0) ~= 0
  end, 50)
end

--- The input the fake has received so far, every chunk joined in order.
---
---@param fake { record: string }
---@return string
function M.received(fake)
  return table.concat(vim.tbl_map(function(entry)
    return entry.received or ''
  end, M.record(fake)))
end

--- The input the fake has received after its first `offset` bytes of input,
--- once that holds at least `length` bytes — waiting for that at most
--- `patience_ms`, `PATIENCE_MS` unless given — or when the wait runs out.
---
---@param fake { record: string }
---@param offset integer how many bytes of input came before
---@param length integer
---@param patience_ms? integer
---@return string
function M.wait_for_received_after(fake, offset, length, patience_ms)
  local input
  vim.wait(patience_ms or M.PATIENCE_MS, function()
    input = M.received(fake):sub(offset + 1)
    return #input >= length
  end, 20)
  return input
end

--- How many Ctrl-C presses — `\3` bytes — the fake has received.
---
---@param fake { record: string }
---@return integer
function M.ctrl_c_count(fake)
  local input = table.concat(vim.tbl_map(function(entry)
    return entry.received or ''
  end, M.record(fake)))
  return select(2, input:gsub('\3', ''))
end

--- The record entries in which a fake started — its arguments, working
--- directory and variables — once there are `count` of them, waiting for that
--- at most `PATIENCE_MS`, or when the wait runs out.
---
---@param fake { record: string }
---@param count integer
---@return table[]
function M.wait_for_starts(fake, count)
  local starts
  vim.wait(M.PATIENCE_MS, function()
    starts = vim.tbl_filter(function(entry)
      return entry.argv ~= nil
    end, M.record(fake))
    return #starts >= count
  end, 20)
  return starts
end

--- The fake's first start entry (`wait_for_starts()`) once it has started; an
--- empty table when it has not started by then, so that a test reading a field
--- of it fails on its assertion.
---
---@param fake { record: string }
---@return table
function M.wait_for_start(fake)
  return M.wait_for_starts(fake, 1)[1] or {}
end

return M
