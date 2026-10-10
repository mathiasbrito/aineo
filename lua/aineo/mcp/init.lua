--- aineo's MCP home, `require('aineo.mcp')`: the report server Claude Code
--- runs, described for Claude Code's `--mcp-config` and `--allowedTools`.

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

--- The tools Claude Code may call without asking the user (its
--- `--allowedTools`): the report tool, and nothing else.
---
---@return string[]
function M.allowed_mcp_tools()
  return { M.report_tool_name() }
end

--- Lists the editor `entry` describes among the running aineo editors under
--- `state_directory`, in place of its entry before, so that a report of the
--- session it follows can reach it when the editor that started its Claude
--- Code cannot (`aineo.mcp.editors`).
---
--- Raises an error naming the file when the entry cannot be written.
---
---@param state_directory string
---@param entry aineo.mcp.EditorEntry
function M.write_editor_entry(state_directory, entry)
  editors.write_entry(state_directory, entry)
end

--- Takes the editor at `address` off the list of running aineo editors, as
--- it quits.
---
---@param state_directory string
---@param address string
function M.remove_editor_entry(state_directory, address)
  editors.remove_entry(state_directory, address)
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
