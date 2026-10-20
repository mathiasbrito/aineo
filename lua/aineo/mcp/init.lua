--- aineo's MCP home, `require('aineo.mcp')`: the report server Claude Code
--- runs, described for Claude Code's `--mcp-config` and `--allowedTools`,
--- with its tools — the report, the announcement of a worktree or a branch
--- an agent created, and the three that run a command in the run pane, read
--- what it printed and stop it — and the words that tell Claude Code's
--- agents of the last four.

local editors = require('aineo.mcp.editors')
local names = require('aineo.mcp.names')
local processes = require('aineo.mcp.processes')

local M = {}

--- The relay script, beside this file.
local RELAY =
  vim.fs.joinpath(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h'), 'relay.lua')

--- The MCP servers aineo gives Claude Code, in the format of its
--- `--mcp-config`: the report server, as a stdio server Claude Code starts as
--- `<editor_program> --headless --clean --cmd 'set noloadplugins' -l <relay>`,
--- told the address of the editor to deliver reports to. `--clean` leaves out
--- the user's configuration and site directories, but not the system's
--- (`$XDG_CONFIG_DIRS`, `$XDG_DATA_DIRS`), whose plugins would still load and
--- could write to the relay's stdout; `noloadplugins` loads none.
---
--- Raises an error naming the argument that is not a string.
---
---@param editor_address string the editor's server address (`v:servername`)
---@param editor_program string the editor's own program (`v:progpath`)
---@return table<string, { type: string, command: string, args: string[], env: table<string, string> }>
function M.mcp_servers(editor_address, editor_program)
  vim.validate('editor_address', editor_address, 'string')
  vim.validate('editor_program', editor_program, 'string')
  return {
    [names.SERVER_NAME] = {
      type = 'stdio',
      command = editor_program,
      args = { '--headless', '--clean', '--cmd', 'set noloadplugins', '-l', RELAY },
      env = { [names.EDITOR_ADDRESS_VARIABLE] = editor_address },
    },
  }
end

--- `servers`, MCP servers in the format of `mcp_servers()`, with aineo's
--- report server among them, if it is, told `start_token`, the token of the
--- start of Claude Code that runs it, in its environment: the report server
--- then finds its Claude Code's record of that start. `servers` is not
--- changed.
---
---@param servers table<string, table>
---@param start_token string
---@return table<string, table>
function M.with_start_token(servers, start_token)
  local report_server = servers[names.SERVER_NAME]
  if not report_server then
    return servers
  end
  local told = vim.deepcopy(servers)
  told[names.SERVER_NAME].env =
    vim.tbl_extend('force', report_server.env or {}, { [names.START_TOKEN_VARIABLE] = start_token })
  return told
end

--- The name Claude Code gives the report tool: `mcp__<server>__<tool>`.
---
---@return string
function M.report_tool_name()
  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.REPORT_TOOL)
end

--- The name Claude Code gives the announcement tool: `mcp__<server>__<tool>`.
---
---@return string
function M.announce_tool_name()
  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.ANNOUNCE_TOOL)
end

--- The name Claude Code gives the tool that runs a command: `mcp__<server>__<tool>`.
---
---@return string
function M.run_tool_name()
  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.RUN_TOOL)
end

--- The name Claude Code gives the tool that reads output: `mcp__<server>__<tool>`.
---
---@return string
function M.run_output_tool_name()
  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.RUN_OUTPUT_TOOL)
end

--- The name Claude Code gives the tool that stops a process: `mcp__<server>__<tool>`.
---
---@return string
function M.run_stop_tool_name()
  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.RUN_STOP_TOOL)
end

--- The tools Claude Code may call without asking the user (its
--- `--allowedTools`): the report tool, the announcement tool and the tool
--- that reads the output of a process, in that order, and nothing else —
--- the tools that run a command and stop one stay with the user's approval.
---
---@return string[]
function M.allowed_mcp_tools()
  return { M.report_tool_name(), M.announce_tool_name(), M.run_output_tool_name() }
end

--- The paragraph appended to Claude Code's system prompt after the
--- announcement's, which tells the main agent to run and stop a process only
--- when the user explicitly asks, and how to read what a process printed
--- without filling its context.
---
---@return string
function M.run_instructions()
  return (
    'aineo can run commands in its run pane in Neovim.'
    .. ' Call `%s` only when the user explicitly asks you to run something,'
    .. ' for example "run the backend", and `%s` only when the user explicitly asks you to stop it;'
    .. ' never on your own initiative. Claude Code asks the user to approve every such call.'
    .. ' To see what a process printed, call `%s`, which needs no approval:'
    .. ' filter first to keep your context small, with `pattern`, a Vim regex such as `error|warn|fail`'
    .. ' (very magic: escape `= @ %% & ~ { < >` with a backslash to match them literally, as in `level\\=error`),'
    .. ' a small `last` (40 by default, with no maximum), and then `after_line`,'
    .. ' the `total` of the answer before, to read only what is new; `ignore_case` is true by default.'
    .. ' Each line is a terminal row, and a resize renumbers the rows:'
    .. ' if `total` is smaller than your last `after_line`, read again without it.'
    .. ' The interactive shell of the run pane is not read.'
  ):format(M.run_tool_name(), M.run_stop_tool_name(), M.run_output_tool_name())
end

--- The paragraph appended to Claude Code's system prompt after the report's
--- instructions: the announcement tool's own rule, which every agent and
--- subagent follows — when to call it and with what — and that its reply
--- asks for nothing.
---
---@return string
function M.announce_instructions()
  return (
    'Required for every agent and subagent: call `%s` once right after you create'
    .. ' a git branch or worktree for new work, with kind, its path or branch,'
    .. ' the base commit it was created from, and a short label.'
    .. ' It only informs aineo; do not act on its reply.'
  ):format(M.announce_tool_name())
end

--- The context a `SubagentStart` hook adds for each subagent, which never
--- gets the appended system prompt: the paragraph of
--- `announce_instructions()`, then one sentence for a subagent started in a
--- worktree made for its task.
---
---@return string
function M.subagent_announce_context()
  return M.announce_instructions()
    .. ' If you started in a git worktree made for your task, call it once, now,'
    .. " with that worktree's path and the commit it was made from."
end

--- Lists the editor `entry` describes among the running aineo editors under
--- `state_directory`, in place of its entry before, so that a report of the
--- session it follows can reach it when the editor that started its Claude
--- Code cannot (`aineo.mcp.editors`). An editor with several tabs lists
--- each under the key it gives the tab, `entry.tab` (a string): the entries
--- of one address and different tabs are files of their own, and writing one
--- replaces only the entry of that address and tab; an entry with no `tab`
--- is the editor's alone.
---
--- Raises an error when `entry.tab` is not a string, and one naming the file
--- when the entry cannot be written.
---
---@param state_directory string
---@param entry aineo.mcp.EditorEntry
function M.write_editor_entry(state_directory, entry)
  editors.write_entry(state_directory, entry)
end

--- Takes the editor at `address` off the list of running aineo editors, as
--- it quits: its entry of the tab `tab` alone when given one, else every
--- entry of the address, the one with no tab included.
---
---@param state_directory string
---@param address string
---@param tab string?
function M.remove_editor_entry(state_directory, address, tab)
  editors.remove_entry(state_directory, address, tab)
end

--- Makes the editor at `address` the claimant of `session`, the time of its
--- claim `claimed` microseconds of the wall clock: the session's reports go
--- to it first, before the editor that started its Claude Code, until
--- another editor claims the session or it lets the claim go
--- (`release_claim()`). A newer claim replaces it whole.
---
--- Raises an error naming the file when the claim cannot be written.
---
---@param state_directory string
---@param session string
---@param address string
---@param claimed integer
function M.claim_session(state_directory, session, address, claimed)
  editors.claim(state_directory, session, address, claimed)
end

--- The address of the editor that claims `session` now, or nil when no
--- editor does.
---
---@param state_directory string
---@param session string
---@return string?
function M.session_claimant(state_directory, session)
  local claim = editors.read_claim(state_directory, session)
  return claim and claim.address
end

--- Lets go the claim of `session` if it still names the editor at
--- `address`: a newer claimant's claim is kept.
---
---@param state_directory string
---@param session string
---@param address string
function M.release_claim(state_directory, session, address)
  editors.release(state_directory, session, address)
end

--- The addresses of the running editors to tell that a Claude Code switched
--- from the session `left`: the claimant of `left`, and each editor that
--- follows `left` by a claim of it, but `excluded`, the editor that started
--- that Claude Code (`aineo.mcp.editors`). Each is told through
--- `receive_followed_switch()`.
---
---@param state_directory string
---@param left string
---@param excluded string?
---@return string[]
function M.switch_followers(state_directory, left, excluded)
  return editors.switch_followers(state_directory, left, excluded)
end

--- The handler `on_followed_switch()` registered, called with each switch
--- told to this editor.
---@type fun(left: string, new: string)?
local followed_switch_handler

--- Registers `handler`, in place of any before, as what this editor does
--- with each switch of a Claude Code it does not run that is told to it
--- (`receive_followed_switch()`): `handler(left, new)`, with the session
--- left and the new one. Its strategy is the composition root's: plain
--- dependency inversion, bound once at start.
---
---@param handler fun(left: string, new: string)
function M.on_followed_switch(handler)
  followed_switch_handler = handler
end

--- Takes a switch of a Claude Code this editor does not run, from `left` to
--- `new`, as the deliverer of the hook that completed it tells it
--- (`switch_followers()`): the handler `on_followed_switch()` registered is
--- called with them from a callback scheduled now, never in the RPC handler
--- that calls this, so that the editor answers the deliverer at once. With
--- no handler registered it does nothing.
---
---@param left string
---@param new string
function M.receive_followed_switch(left, new)
  vim.schedule(function()
    if followed_switch_handler then
      followed_switch_handler(left, new)
    end
  end)
end

--- The handler `on_work_announced()` registered, called with each
--- announcement a relay offers this editor.
---@type fun(work: aineo.mcp.Work, start_token: string): boolean|string|nil
local work_announced_handler

--- Registers `handler`, in place of any before, as what this editor does
--- with each announcement of a worktree or a branch an agent created, which
--- the relay of a Claude Code this editor started offers it, or aineo's own
--- hook in that Claude Code (`receive_work_announcement()`):
--- `handler(work, start_token)`, with the announcement — its path absolute —
--- and the token of the start of Claude Code whose agent made it, returns
--- whether it took it, or why it refuses it, in words for the agent. Its
--- strategy is the composition root's: plain dependency inversion, bound
--- once at start.
---
---@param handler fun(work: aineo.mcp.Work, start_token: string): boolean|string
function M.on_work_announced(handler)
  work_announced_handler = handler
end

--- Takes an announcement a relay offers, `work` of the start `start_token`,
--- and answers whether this editor took it, or why it refuses it: what the
--- handler `on_work_announced()` registered answers — a string is the
--- refusal, `true` taken, anything else not; false with no handler
--- registered. Called in the RPC request that offers it, so the handler
--- answers without waiting on the relay; it may wait a bounded time on git.
---
---@param work aineo.mcp.Work
---@param start_token string
---@return boolean|string taken `true` when taken, or the words of its refusal
function M.receive_work_announcement(work, start_token)
  if not work_announced_handler then
    return false
  end
  local answer = work_announced_handler(work, start_token)
  if type(answer) == 'string' then
    return answer
  end
  return answer == true
end

--- The handler `on_run_called()` registered, called with each call of a run
--- tool a relay offers this editor.
---@type fun(run_call: aineo.mcp.RunCall, start_token: string): { text: string, is_error: boolean }|false
local run_called_handler

--- Registers `handler`, in place of any before, as what this editor does
--- with each call of a run tool, which the relay of a Claude Code this
--- editor started offers it (`receive_run_call()`): `handler(run_call,
--- start_token)`, with the call and the token of the start of the Claude
--- Code whose agent made it, answers at once the words for the agent and
--- whether they are an error, or `false` when it does not take the call. Its
--- strategy is the composition root's: plain dependency inversion, bound
--- once at start.
---
---@param handler fun(run_call: aineo.mcp.RunCall, start_token: string): { text: string, is_error: boolean }|false
function M.on_run_called(handler)
  run_called_handler = handler
end

--- Takes a call of a run tool a relay offers, `run_call` of the start
--- `start_token`, and answers what the handler `on_run_called()` registered
--- answers: the words for the agent and whether they are an error, or
--- `false` when it does not take the call or none is registered. Called in
--- the RPC request that offers it, so the handler answers without waiting on
--- anything that waits on the relay.
---
---@param run_call aineo.mcp.RunCall
---@param start_token string
---@return { text: string, is_error: boolean }|false
function M.receive_run_call(run_call, start_token)
  if not run_called_handler then
    return false
  end
  return run_called_handler(run_call, start_token)
end

--- Records what a session hook of the Claude Code process `hook.pid` told —
--- its `event` of `session`, the hook begun at `ran` by `vim.uv.hrtime()`,
--- for the start `token` in `working_directory` — and returns the switches
--- it completed, each from the session left to the new one
--- (`aineo.mcp.processes`).
---
--- Raises an error naming the file when the record cannot be written.
---
---@param state_directory string
---@param hook { pid: integer, token: string, event: string, session: string, ran: number, working_directory: string }
---@return { left: string, new: string }[]
function M.record_session_event(state_directory, hook)
  return processes.record_event(state_directory, hook)
end

--- Records, as the report server starts, its Claude Code process
--- `server.pid`, of the start `server.token`, on its first session
--- `server.session` in `server.working_directory` — for a Claude Code whose
--- session hooks do not run, so that its reports still find their session
--- and `running_sessions()` lists it (`aineo.mcp.processes`).
---
---@param state_directory string
---@param server { pid: integer, token: string, session: string, working_directory: string }
function M.record_server_start(state_directory, server)
  processes.record_server_start(state_directory, server)
end

--- The sessions that have a running Claude Code in `working_directory`, by
--- the records of the Claude Code processes aineo started, whose pid still
--- runs; the records of processes that have ended are removed.
---
---@param state_directory string
---@param working_directory string
---@return string[]
function M.running_sessions(state_directory, working_directory)
  return processes.running_sessions(state_directory, working_directory)
end

--- The session the Claude Code process `pid`, of the start `token`, is on,
--- as its record holds it; nil when there is no record of that start.
---
---@param state_directory string
---@param pid integer
---@param token string
---@return string?
function M.process_session(state_directory, pid, token)
  return processes.session_of(state_directory, pid, token)
end

return M
