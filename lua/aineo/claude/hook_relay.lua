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
--- or reason, start token, hook time)` there. For a switch, it then sends
--- each other editor that follows the session left by a claim, and its
--- claimant, a notification of the switch (`notify_followers()`), and, when
--- its own editor could not be reached, keeps the new session for the
--- working directory, as the session the next start there resumes. Only
--- then does it wait, editor by editor, for the answer to a request sent
--- behind each notification on the same connection, and close it
--- (`wait_for_confirmation()`): so an editor held at a hit-enter prompt
--- keeps no other from being told. Neovim 0.12.5 drops an RPC notification
--- whose sender closed the connection before the editor ran it, when the
--- editor could not run it at once — busy, or at a hit-enter prompt — and a
--- channel connected earlier has a message waiting too, as the TUI's keys
--- have when its user leaves the prompt. An editor that cannot be reached,
--- or ends while it waits, is passed by. Then it exits.
---
--- As aineo's `PostToolUse` hook, which Claude Code runs in the background
--- after a `Bash` call of git with the event `PostToolUse` in place of a
--- session's, it records nothing and starts no deliverer: it reads the call's
--- command as work made, when it is one of the plain forms the hook reads
--- (`aineo.claude.work_commands`), resolves its base in the folder the
--- command ran in (`made_work()`), and tells the editor, as an agent's call
--- of `announce_work` reaches it, waiting for its answer
--- (`tell_made_work()`). Any other call, and any failure, tells nothing; the
--- hook writes nothing on stdout or stderr and exits 0.
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

--- Connects to the editor at `address`, over TCP when it is `host:port` and
--- over a local socket otherwise, and sends it one RPC notification that
--- runs `lua` with `arguments` there. Returns the channel, which stays open
--- until `wait_for_confirmation()` closes it — a notification whose sender
--- closed the connection first can be dropped — or nil when the editor
--- cannot be reached.
---
---@param address string
---@param lua string
---@param arguments any[]
---@return integer? channel
local function notify(address, lua, arguments)
  local mode = address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'
  local connected, channel = pcall(vim.fn.sockconnect, mode, address, { rpc = true })
  if not connected then
    return nil
  end
  vim.rpcnotify(channel, 'nvim_exec_lua', lua, arguments)
  return channel
end

--- Waits for the editor on `channel` to answer `CONFIRMATION`, which it does
--- once it has handled the notification sent before it, then closes the
--- channel. An editor that ends before it answers is passed by: it has
--- nothing more to be told.
---
---@param channel integer
local function wait_for_confirmation(channel)
  pcall(vim.rpcrequest, channel, 'nvim_exec_lua', CONFIRMATION, {})
  pcall(vim.fn.chanclose, channel)
end

--- Sends each editor that follows the session `left` by a claim, and the
--- claimant of `left`, but the editor at `address`, the notification that
--- Claude Code switched from `left` to `new` (`aineo.mcp`'s
--- `switch_followers()`), and returns the channels of those it reached,
--- without waiting for any to answer.
---
---@param address string
---@param left string
---@param new string
---@return integer[] channels
local function notify_followers(address, left, new)
  local channels = {}
  local followers = require('aineo.mcp').switch_followers(vim.fn.stdpath('state'), left, address)
  for _, follower in ipairs(followers) do
    table.insert(channels, notify(follower, RECEIVE_FOLLOWED_SWITCH, { left, new }))
  end
  return channels
end

--- The event of aineo's hook after a `Bash` call of git.
local TOOL_USE_EVENT = 'PostToolUse'

--- How long the hook waits for git to resolve the base of work made.
local BASE_RESOLUTION_MS = 3000

--- The Lua the editor runs for work the hook read, its arguments the
--- announcement and the start token: `aineo.mcp`'s
--- `receive_work_announcement()`, as an agent's call of `announce_work`
--- reaches it.
local RECEIVE_WORK = "return require('aineo.mcp').receive_work_announcement(...)"

--- `path` made absolute against `folder` when it is not, and normalised,
--- with no `~` and no environment variable expanded.
---
---@param path string
---@param folder string
---@return string
local function absolute_in(path, folder)
  local absolute = vim.startswith(path, '/') and path or vim.fs.joinpath(folder, path)
  return vim.fs.normalize(absolute, { expand_env = false })
end

--- The full id of the commit `name` gives in the folder `folder`, as git
--- reads a name there, or nil when it gives none, git fails, or it takes
--- longer than `BASE_RESOLUTION_MS`.
---
---@param folder string
---@param name string
---@return string?
local function commit_in(folder, name)
  local resolved = vim
    .system({
      'git',
      '-C',
      folder,
      'rev-parse',
      '--verify',
      '--quiet',
      '--end-of-options',
      name .. '^{commit}',
    }, { text = true })
    :wait(BASE_RESOLUTION_MS)
  return resolved.code == 0 and (resolved.stdout or ''):match('^(%x+)\n$') or nil
end

--- The work `input`, the JSON of a `PostToolUse` hook, says a `Bash` call
--- made, as an announcement (`aineo.claude.work_commands`'s `work_of()`):
--- its kind; the worktree's folder or the branch's name; its base, the start
--- point the command names, else `HEAD`, resolved to a commit in the folder
--- the command ran in — `-C`'s, against the call's `cwd`, else the call's
--- `cwd`, else the directory Claude Code runs in — at the time of the hook;
--- and that aineo's hook made it. Nil when the call is not a command the
--- hook reads, or its base resolves to no commit.
---
---@param place aineo.claude.HookPlace
---@param input table
---@return table?
local function made_work(place, input)
  local command = vim.tbl_get(input, 'tool_input', 'command')
  if input.tool_name ~= 'Bash' or type(command) ~= 'string' then
    return nil
  end
  load_aineo()
  local made = require('aineo.claude.work_commands').work_of(command)
  local cwd = type(input.cwd) == 'string' and input.cwd or place.working_directory
  if not (made and cwd) then
    return nil
  end
  local folder = made.directory and absolute_in(made.directory, cwd) or cwd
  local base = commit_in(folder, made.start or 'HEAD')
  if not base then
    return nil
  end
  if made.kind == 'worktree' then
    return { kind = 'worktree', path = absolute_in(made.path, folder), base = base, by_hook = true }
  end
  return { kind = 'branch', branch = made.branch, base = base, by_hook = true }
end

--- Tells the editor at `place.address` the work the `Bash` call of `input`
--- made (`made_work()`), as an agent's announcement reaches it, waiting
--- for its answer, and closes the connection; tells nothing when the call
--- made no work the hook reads. Run in the background of Claude Code, so
--- the wait holds no tool call.
---
---@param place aineo.claude.HookPlace
---@param input table
local function tell_made_work(place, input)
  local work = made_work(place, input)
  if not work then
    return
  end
  local mode = place.address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'
  local connected, channel = pcall(vim.fn.sockconnect, mode, place.address, { rpc = true })
  if not connected then
    return
  end
  pcall(vim.rpcrequest, channel, 'nvim_exec_lua', RECEIVE_WORK, { work, place.start_token })
  pcall(vim.fn.chanclose, channel)
end

if arg[1] == DELIVER then
  local address, start_token, event, session_id, cause, ran, left, new, working_directory =
    unpack(arg, 2, 10)
  local editor = notify(address, RECEIVE_SESSION_EVENT, {
    event,
    session_id,
    cause ~= '' and cause or vim.NIL,
    start_token,
    tonumber(ran) or vim.NIL,
  })
  local followers = {}
  if (left or '') ~= '' and (new or '') ~= '' then
    load_aineo()
    followers = notify_followers(address, left, new)
    if not editor and (working_directory or '') ~= '' then
      -- No one is left to tell of a switch that cannot be kept: the next
      -- start in the directory resumes the session before it.
      pcall(
        require('aineo.claude.session_ids').keep_session_id,
        vim.fn.stdpath('state'),
        working_directory,
        new
      )
    end
  end
  for _, channel in ipairs(vim.list_extend({ editor }, followers)) do
    wait_for_confirmation(channel)
  end
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
if input and event == TOOL_USE_EVENT then
  -- Whatever fails here is the hook's alone: the agent's call went on.
  pcall(tell_made_work, place, input)
elseif input then
  local hook = { event = event, input = input, ran = ran }
  -- A record that cannot be written leaves the report server the session it
  -- had; the hook still tells its editor.
  local recorded, switch = pcall(record_hook, place, hook)
  hook.switch = recorded and switch or nil
  start_deliverer(place, hook)
end
