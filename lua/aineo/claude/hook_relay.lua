--- The hook relay: the command hook Claude Code runs at each `SessionStart`
--- and `SessionEnd` of aineo's session, as
--- `nvim --headless --clean --cmd 'set noloadplugins' -l <this file>
--- <editor address> <start token> <event> "$PPID" <working directory>`
--- (`aineo.claude.arguments`'s `--settings`), and the composition root of
--- that process. The shell that runs the hook expands `"$PPID"` to the pid
--- of the process that ran it, Claude Code's.
---
--- As the hook, it reads the hook's JSON from stdin and, when it is an object
--- with a string `session_id`, records the event in the record of Claude
--- Code's process — under its own `stdpath('state')`, the editor's — which
--- the report server reads (`aineo.mcp`'s `record_session_event()`); a pid
--- that is not all digits, or a missing directory, records nothing. It then
--- starts this file again, detached from it, as the deliverer of that event,
--- told the switch the record completed if it completed one, and exits 0 at
--- once: Claude Code waits for a `SessionStart` hook of an in-session
--- `/resume`, and nothing it waits for may wait on the editor. Input of any
--- other shape records and starts nothing. The hook writes nothing on stdout
--- or stderr.
---
--- As the deliverer — `-l <this file> --deliver <editor address> <start
--- token> <event> <session id> <source or reason> <hook time> <session left>
--- <new session> <working directory>`, the hook time being `vim.uv.hrtime()`
--- as the hook began, a monotonic clock every process on the host shares, by
--- which the editor tells the order the hooks ran in whatever order their
--- deliverers reach it, and the two sessions empty when the hook completed
--- no switch — it sends the editor one RPC notification calling
--- `require('aineo.claude').receive_session_event(event, session id, source
--- or reason, start token, hook time)` there, then waits for the editor's
--- answer to a request sent behind it on the same connection before it
--- closes it. Neovim 0.12.5 drops an RPC notification whose sender closed
--- the connection before the editor ran it, when the editor could not run it
--- at once — busy, or at a hit-enter prompt — and a channel connected
--- earlier has a message waiting too, as the TUI's keys have when its user
--- leaves the prompt. It goes on at once when the editor cannot be reached,
--- and when the editor ends while it waits. For a switch, it then keeps the
--- new session for the working directory, as the session the next start
--- there resumes, when its editor could not be reached; and, whether or not
--- it could, tells the switch to each other editor that follows the session
--- left by a claim, and to its claimant (`tell_followers()`). Then it exits.
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

--- The Lua an editor runs to take a switch of a Claude Code it does not run.
local RECEIVE_FOLLOWED_SWITCH = "require('aineo.mcp').receive_followed_switch(...)"

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

--- One run of the hook: its event, its input (`hook_input()`), when it
--- began, by `vim.uv.hrtime()`, and the switch its record completed, if it
--- completed one (`record_hook()`).
---@alias aineo.claude.HookRun { event: string, input: table, ran: number, switch: { left: string, new: string }? }

--- What the hook's command line gives besides its event: the editor's
--- address, the start token, the pid of Claude Code's process as the shell
--- expanded `"$PPID"`, and the directory Claude Code runs in.
---@alias aineo.claude.HookPlace { address: string, start_token: string, claude_pid: string?, working_directory: string? }

--- Puts the plugin this file is in on 'runtimepath', which `--clean` leaves
--- it off, so that aineo's homes can be required.
local function load_aineo()
  vim.opt.runtimepath:prepend(vim.fn.fnamemodify(this_script, ':h:h:h:h'))
end

--- Records `hook` in the record of Claude Code's process `place.claude_pid`
--- under this process's state directory, its own `stdpath('state')`, which
--- is the editor's (`aineo.mcp`'s `record_session_event()`), and returns
--- the last switch that record completed, if any. Records nothing when the
--- pid is not all digits, or no directory is given.
---
--- Raises an error naming the record's file when it cannot be written.
---
---@param place aineo.claude.HookPlace
---@param hook aineo.claude.HookRun
---@return { left: string, new: string }?
local function record_hook(place, hook)
  if not (place.claude_pid or ''):match('^%d+$') or not place.working_directory then
    return nil
  end
  load_aineo()
  local switches = require('aineo.mcp').record_session_event(vim.fn.stdpath('state'), {
    pid = tonumber(place.claude_pid),
    token = place.start_token,
    event = hook.event,
    session = hook.input.session_id,
    ran = hook.ran,
    working_directory = place.working_directory,
  })
  return switches[#switches]
end

--- Starts this file as the deliverer of `hook` for the editor at
--- `place.address`, detached in a session of its own with no standard
--- stream, so that the hook ends without waiting for it and Claude Code
--- reads no output of its.
---
---@param place aineo.claude.HookPlace
---@param hook aineo.claude.HookRun
local function start_deliverer(place, hook)
  local cause = hook.input[CAUSE_FIELDS[hook.event]]
  local switch = hook.switch or { left = '', new = '' }
  local deliverer = vim.uv.spawn(vim.v.progpath, {
    args = {
      '--headless',
      '--clean',
      '--cmd',
      'set noloadplugins',
      '-l',
      this_script,
      DELIVER,
      place.address,
      place.start_token,
      hook.event,
      hook.input.session_id,
      type(cause) == 'string' and cause or '',
      ('%.0f'):format(hook.ran),
      switch.left,
      switch.new,
      place.working_directory or '',
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
--- answer to `CONFIRMATION` before it closes the connection. Returns whether
--- the editor could be reached. Raises an error when the editor ends before
--- it answers.
---
---@param address string
---@param event_arguments any[]
---@return boolean reached
local function deliver(address, event_arguments)
  local mode = address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'
  local connected, channel = pcall(vim.fn.sockconnect, mode, address, { rpc = true })
  if not connected then
    return false
  end
  vim.rpcnotify(channel, 'nvim_exec_lua', RECEIVE_SESSION_EVENT, event_arguments)
  vim.rpcrequest(channel, 'nvim_exec_lua', CONFIRMATION, {})
  vim.fn.chanclose(channel)
  return true
end

--- Tells each editor that follows the session `left` by a claim, and the
--- claimant of `left`, but the editor at `address`, that Claude Code
--- switched from `left` to `new` (`aineo.mcp`'s `switch_followers()`),
--- waiting for each to answer. An editor that cannot be reached, or ends
--- before it answers, is passed by: it has nothing more to be told.
---
---@param address string
---@param left string
---@param new string
local function tell_followers(address, left, new)
  local followers = require('aineo.mcp').switch_followers(vim.fn.stdpath('state'), left, address)
  for _, follower in ipairs(followers) do
    pcall(function()
      local channel = vim.fn.sockconnect('pipe', follower, { rpc = true })
      vim.rpcrequest(channel, 'nvim_exec_lua', RECEIVE_FOLLOWED_SWITCH, { left, new })
      vim.fn.chanclose(channel)
    end)
  end
end

if arg[1] == DELIVER then
  local address, start_token, event, session_id, cause, ran, left, new, working_directory =
    unpack(arg, 2, 10)
  -- An editor that ends before it answers has nothing more to be told: the
  -- deliverer goes on as when it has told it.
  local told, reached = pcall(deliver, address, {
    event,
    session_id,
    cause ~= '' and cause or vim.NIL,
    start_token,
    tonumber(ran) or vim.NIL,
  })
  if (left or '') == '' or (new or '') == '' then
    return
  end
  load_aineo()
  if told and not reached and (working_directory or '') ~= '' then
    -- No one is left to tell of a switch that cannot be kept: the next
    -- start in the directory resumes the session before it.
    pcall(
      require('aineo.claude.session_ids').keep_session_id,
      vim.fn.stdpath('state'),
      working_directory,
      new
    )
  end
  tell_followers(address, left, new)
  return
end

local place = {
  address = arg[1],
  start_token = arg[2],
  claude_pid = arg[4],
  working_directory = arg[5],
}
local event = arg[3]
local ran = vim.uv.hrtime()
local input = hook_input()
if input then
  local hook = { event = event, input = input, ran = ran }
  -- A record that cannot be written leaves the report server the session it
  -- had; the hook still tells its editor.
  local recorded, switch = pcall(record_hook, place, hook)
  hook.switch = recorded and switch or nil
  start_deliverer(place, hook)
end
