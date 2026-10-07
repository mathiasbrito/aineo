--- The hook relay: the command hook Claude Code runs at each `SessionStart`
--- and `SessionEnd` of aineo's session, as
--- `nvim --headless --clean --cmd 'set noloadplugins' -l <this file>
--- <editor address> <start token> <event>` (`aineo.claude.arguments`'s
--- `--settings`), and the composition root of that process.
---
--- As the hook, it reads the hook's JSON from stdin and, when it is an object
--- with a string `session_id`, starts this file again, detached from it, as
--- the deliverer of that event, then exits 0 at once: Claude Code waits for a
--- `SessionStart` hook of an in-session `/resume`, and nothing it waits for
--- may wait on the editor. Input of any other shape starts nothing. The hook
--- writes nothing on stdout or stderr.
---
--- As the deliverer — `-l <this file> --deliver <editor address> <start
--- token> <event> <session id> <source or reason> <hook time>`, the hook time
--- being `vim.uv.hrtime()` as the hook began, a monotonic clock every process
--- on the host shares, by which the editor tells the order the hooks ran in
--- whatever order their deliverers reach it — it sends the editor one RPC
--- notification calling `require('aineo.claude').receive_session_event
--- (event, session id, source or reason, start token, hook time)` there,
--- then waits for the editor's answer to a request sent behind it on the
--- same connection before it closes it, and exits. Neovim 0.12.5 drops an
--- RPC notification whose sender closed the connection before the editor
--- ran it, when the editor could not run it at once — busy, or at a
--- hit-enter prompt — and a channel connected earlier has a message waiting
--- too, as the TUI's keys have when its user leaves the prompt. It ends at
--- once when the editor cannot be reached, and when the editor ends while
--- it waits.
---
--- It runs only when it is the script `-l` runs (`arg[0]`, `:h lua-args`):
--- loaded inside an editor, by `require` or `dofile`, it does nothing.

local this_script = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')
local script_run = arg and arg[0] and vim.fn.fnamemodify(arg[0], ':p')
if script_run ~= this_script then
  return
end

--- The word that makes this file the deliverer.
local DELIVER = '--deliver'

--- The field of each event's JSON that says how the session started or why
--- it ended.
local CAUSE_FIELDS = { SessionStart = 'source', SessionEnd = 'reason' }

--- The Lua the editor runs for each event. The event travels as its
--- arguments, as data: nothing of it becomes code.
local RECEIVE_SESSION_EVENT = "require('aineo.claude').receive_session_event(...)"

--- The Lua of the request whose answer tells the deliverer that the editor
--- has handled its notification: the editor handles the requests and
--- notifications of one connection in order, and runs Lua only once it is
--- free, so it answers this request once it has handled the notification.
local CONFIRMATION = 'return 0'

--- The hook's input, read from stdin, when it is a JSON object with a string
--- `session_id`; else nil.
---
---@return table?
local function hook_input()
  local read, input = pcall(vim.json.decode, io.read('*a'), { luanil = { object = true } })
  if read and type(input) == 'table' and type(input.session_id) == 'string' then
    return input
  end
end

--- One run of the hook: its event, its input (`hook_input()`), and when it
--- began, by `vim.uv.hrtime()`.
---@alias aineo.claude.HookRun { event: string, input: table, ran: number }

--- Starts this file as the deliverer of `hook` for the editor at `address`,
--- detached in a session of its own with no standard stream, so that the
--- hook ends without waiting for it and Claude Code reads no output of its.
---
---@param address string
---@param start_token string
---@param hook aineo.claude.HookRun
local function start_deliverer(address, start_token, hook)
  local cause = hook.input[CAUSE_FIELDS[hook.event]]
  local deliverer = vim.uv.spawn(vim.v.progpath, {
    args = {
      '--headless',
      '--clean',
      '--cmd',
      'set noloadplugins',
      '-l',
      this_script,
      DELIVER,
      address,
      start_token,
      hook.event,
      hook.input.session_id,
      type(cause) == 'string' and cause or '',
      ('%.0f'):format(hook.ran),
    },
    detached = true,
  }, function() end)
  if deliverer then
    deliverer:unref()
  end
end

--- Sends the editor at `address` the notification that calls
--- `RECEIVE_SESSION_EVENT` with `event_arguments`, over TCP when `address`
--- is `host:port` and over a local socket otherwise, then waits for the
--- answer to `CONFIRMATION` before it closes the connection. Raises an error
--- when the editor cannot be reached or ends before it answers.
---
---@param address string
---@param event_arguments any[]
local function deliver(address, event_arguments)
  local mode = address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'
  local channel = vim.fn.sockconnect(mode, address, { rpc = true })
  vim.rpcnotify(channel, 'nvim_exec_lua', RECEIVE_SESSION_EVENT, event_arguments)
  vim.rpcrequest(channel, 'nvim_exec_lua', CONFIRMATION, {})
  vim.fn.chanclose(channel)
end

if arg[1] == DELIVER then
  local address, start_token, event, session_id, cause, ran = unpack(arg, 2, 7)
  -- An editor that cannot be reached, or ends before it answers, has nothing
  -- more to be told: the deliverer ends as quietly as when it has told it.
  pcall(deliver, address, {
    event,
    session_id,
    cause ~= '' and cause or vim.NIL,
    start_token,
    tonumber(ran) or vim.NIL,
  })
  return
end

local address, start_token, event = arg[1], arg[2], arg[3]
local ran = vim.uv.hrtime()
local input = hook_input()
if input then
  start_deliverer(address, start_token, { event = event, input = input, ran = ran })
end
