--- Where a report goes: the search the report server makes for each valid
--- report, from the Neovim that claimed the report's session, to the editor
--- that started Claude Code, to a running Neovim that shows the session, to
--- the session's records on disk.

local editor = require('aineo.mcp.editor')
local editors = require('aineo.mcp.editors')
local processes = require('aineo.mcp.processes')
local report = require('aineo.report')

local M = {}

--- What the report server knows of where it runs: the state directory it
--- shares with its editors; the address of the editor that started its
--- Claude Code, if it was told one; its Claude Code process and that start's
--- token, whose record names the session the process is on; the first
--- session of that process, as Claude Code told the server; and the clock a
--- report kept on disk is timed by.
---@class aineo.mcp.DeliveryContext
---@field state_directory string
---@field editor_address string?
---@field pid integer?
---@field token string?
---@field first_session string?
---@field clock fun(): string the local time, as `YYYY-MM-DDTHH:MM:SS`

--- What Claude is told for each way a report went but an error.
local TOLD = {
  delivered = 'Delivered to the Agent Report.',
  claimant = 'Delivered to the Agent Report of another Neovim that claimed this session.',
  shown_elsewhere = 'Delivered to the Agent Report of another Neovim that shows this session,'
    .. ' because the one Claude Code started in is gone or follows another session.',
  kept = "Kept in this session's Agent Report on disk, because no Neovim shows the session now;"
    .. ' it shows when aineo next shows the session.',
}

--- What Claude is told, after why the editor could not be reached, when no
--- session is known to keep the report for.
local NO_SESSION = '; no session was known to keep the report for'

--- The form of a session id as Claude Code gives it, a lower-case
--- version-4 UUID: the check `aineo.claude`'s session ids make, kept here
--- since this home may not require that one.
local SESSION_ID_PATTERN =
  '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'

--- Whether `text` is a session id of the form Claude Code gives.
---
---@param text any
---@return boolean
local function is_session_id(text)
  return type(text) == 'string' and text:find(SESSION_ID_PATTERN) ~= nil and text == text:lower()
end

--- The session of the report: the one the record of the server's Claude
--- Code process names for its start, else the process's first session; nil
--- when neither is a session id.
---
---@param context aineo.mcp.DeliveryContext
---@return string?
local function report_session(context)
  local recorded = context.pid
    and context.token
    and processes.session_of(context.state_directory, context.pid, context.token)
  if is_session_id(recorded) then
    return recorded
  end
  if is_session_id(context.first_session) then
    return context.first_session
  end
end

--- The Lua an editor listed, or a claimant, runs for a report: its report
--- home takes it only while it follows the report's session.
local RECEIVE_SESSION_REPORT = "return require('aineo.report').receive_session_report(...)"

--- The Lua the editor that started Claude Code runs for a report: as
--- `RECEIVE_SESSION_REPORT`, or, where its report home is older than this
--- relay and lacks that function, `receive_report()`, as before.
local RECEIVE_AT_START = [[
  local home = require('aineo.report')
  if home.receive_session_report then
    return home.receive_session_report(...)
  end
  home.receive_report((...))
  return true
]]

--- The outcome of a search that ended at an offer of `kind`, which said
--- `explanation`, with `told` for Claude when it was taken.
---
---@param kind aineo.mcp.OfferKind
---@param explanation string?
---@param told string
---@return 'delivered'|'unconfirmed'|'failed' outcome
---@return string explanation
local function ended_by(kind, explanation, told)
  if kind == 'taken' then
    return 'delivered', told
  end
  if kind == 'unconfirmed' then
    return 'unconfirmed', explanation
  end
  return 'failed', explanation
end

--- Whether an offer of `kind` passes the report on: the editor could not be
--- reached, or does not take reports of the session.
---
---@param kind aineo.mcp.OfferKind
---@return boolean
local function passes_on(kind)
  return kind == 'unreachable' or kind == 'declined'
end

--- Offers `valid_report` of `session` to the editors listed as showing it,
--- the most recently used first — a tie to the entry whose file name sorts
--- first — but those in `tried` and those that may not be tried
--- (`editors.may_be_tried()`). An entry whose editor cannot be reached is
--- removed, if it still holds what was read. Returns how the offer that
--- ended the search went, or nil when every editor passed it on.
---
---@param context aineo.mcp.DeliveryContext
---@param session string
---@param valid_report table
---@param tried table<string, boolean>
---@return 'delivered'|'unconfirmed'|'failed'|nil outcome
---@return string? explanation
local function offer_to_listed(context, session, valid_report, tried)
  local candidates = vim.tbl_filter(function(listed)
    return listed.entry.session == session
      and not tried[listed.entry.address]
      and editors.may_be_tried(listed.entry.address)
  end, editors.read_entries(context.state_directory))
  table.sort(candidates, function(a, b)
    if a.entry.used ~= b.entry.used then
      return a.entry.used > b.entry.used
    end
    return a.name < b.name
  end)
  for _, listed in ipairs(candidates) do
    local kind, explanation = editor.offer_report(
      listed.entry.address,
      { lua = RECEIVE_SESSION_REPORT, arguments = { valid_report, session } }
    )
    if kind == 'unreachable' then
      editors.remove_listed(context.state_directory, listed)
    end
    if not passes_on(kind) then
      return ended_by(kind, explanation, TOLD.shown_elsewhere)
    end
  end
end

--- Offers `valid_report` of `session` to the editor that claimed the
--- session, as its claim file names it, unless that is the starting editor
--- or may not be tried (`editors.may_be_tried()`). A claimant that cannot be
--- reached, or does not follow the session any more, passes the report on:
--- its claim is removed if it still names it, and, when it cannot be
--- reached, its entry too. Returns how the offer went when it ended the
--- search, else nil; adds the claimant to `tried`.
---
---@param context aineo.mcp.DeliveryContext
---@param session string
---@param valid_report table
---@param tried table<string, boolean>
---@return 'delivered'|'unconfirmed'|'failed'|nil outcome
---@return string? explanation
local function offer_to_claimant(context, session, valid_report, tried)
  local claim = editors.read_claim(context.state_directory, session)
  if
    not claim
    or claim.address == context.editor_address
    or not editors.may_be_tried(claim.address)
  then
    return nil
  end
  tried[claim.address] = true
  local kind, explanation = editor.offer_report(
    claim.address,
    { lua = RECEIVE_SESSION_REPORT, arguments = { valid_report, session } }
  )
  if not passes_on(kind) then
    return ended_by(kind, explanation, TOLD.claimant)
  end
  editors.release(context.state_directory, session, claim.address)
  if kind == 'unreachable' then
    for _, listed in ipairs(editors.read_entries(context.state_directory)) do
      if listed.entry.address == claim.address then
        editors.remove_listed(context.state_directory, listed)
      end
    end
  end
end

--- Keeps `valid_report` in the records of `session` on disk.
---
---@param context aineo.mcp.DeliveryContext
---@param session string
---@param valid_report table
---@return 'delivered'|'failed' outcome
---@return string explanation
local function keep_on_disk(context, session, valid_report)
  local kept, failure = pcall(
    report.keep_session_report,
    context.state_directory,
    session,
    valid_report,
    context.clock()
  )
  if not kept then
    return 'failed', tostring(failure)
  end
  return 'delivered', TOLD.kept
end

--- Hands `valid_report` on as `context` allows (`aineo.mcp.DeliveryContext`),
--- and says how it went, in the terms of `aineo.mcp.DeliverReport`, the
--- explanation always given. The report's session is the one the record
--- of the server's Claude Code process names, else its first
--- (`report_session()`). With none known, the report goes to the editor
--- that started Claude Code as it always has
--- (`editor.deliver_report()`). With one, it is offered in turn:
---
--- 1. to the editor at the address of the session's claim file, unless it
---    is the starting editor or may not be tried: taken, unconfirmed or
---    closed ends the search; one that cannot be reached, or does not
---    follow the session any more, passes it on, and its claim is removed
---    if it still names it;
--- 2. to the editor that started Claude Code: anything but an address that
---    cannot be reached, or a decline because it follows another session,
---    ends the search;
--- 3. to the editors listed as showing the session (`offer_to_listed()`);
--- 4. to the session's records on disk (`keep_on_disk()`).
---
--- Only an editor that holds the request without answering waits, up to
--- the offer's bound; nothing is offered twice.
---
---@param context aineo.mcp.DeliveryContext
---@param valid_report table
---@return 'delivered'|'unconfirmed'|'failed' outcome
---@return string explanation
function M.deliver(context, valid_report)
  local session = report_session(context)
  if not session then
    local outcome, explanation, unreachable =
      editor.deliver_report(context.editor_address, valid_report)
    if unreachable then
      explanation = explanation .. NO_SESSION
    end
    return outcome, explanation or TOLD.delivered
  end
  local tried = {}
  local claimant_outcome, claimant_explanation =
    offer_to_claimant(context, session, valid_report, tried)
  if claimant_outcome then
    return claimant_outcome, claimant_explanation
  end
  local starting = context.editor_address
  if starting then
    tried[starting] = true
    local kind, explanation = editor.offer_report(
      starting,
      { lua = RECEIVE_AT_START, arguments = { valid_report, session } }
    )
    if not passes_on(kind) then
      return ended_by(kind, explanation, TOLD.delivered)
    end
  end
  local outcome, explanation = offer_to_listed(context, session, valid_report, tried)
  if outcome then
    return outcome, explanation
  end
  return keep_on_disk(context, session, valid_report)
end

return M
