# 2026-09-24 — T5 report channel

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t5-report-channel` · **Pull request:** #10 (packet round)

## Links

- **Project:** [[Projects/aineo]]
- **Plan:** [[Planning/aineo — v1 agent console]] — T5, C5, C6, D8, D11, F4, A1, A3, A4
- **Wave:** [[Implementation/Waves/00002-layout-session-report/plan]] · the brief `Implementation/Waves/00002-layout-session-report/brief-t5-report-channel.md` · its review `brief-review.md` (findings 1, 3, 6, 7, 9, 10 shaped this packet)
- **Evidence the tests are built from:** `Implementation/Waves/00002-layout-session-report/evidence/t2-handshake.txt` (the recorded handshake), `t2-mcp-probe-log.txt` (the recorded `tools/call` params)
- **Standards read raw:** MCP 2025-11-25 *Overview*, *Lifecycle*, *Tools*, *Transports* (stdio) and *Ping*, fetched as the spec site's raw Markdown on 2026-09-24. Also the 2025-06-18 *Overview*, *Lifecycle* and *Tools*, for comparison. `schema.ts` at 2025-11-25 was read in the brief reviewer's raw copy (`scratchpad/briefw2-mcp/schema.ts`, fetched with curl); this session's own curl of the GitHub raw URL was refused by the worktree guard. The spec site's generated schema page agrees on `JSONRPCErrorResponse.id?: RequestId`.

## Context

**Goal:** T5 builds the channel through which Claude reports its work to the user (D8), and nothing that starts Claude. That means the stdio MCP server Claude Code runs (C5) and the Report that shows the reports (C6). The packet also builds the three values T7 hands to T4 by injection: the `--mcp-config` servers, the tools to pre-allow (D11) and the appended instructions.

## What was done

**`lua/aineo/report/` (C6), behind `init.lua`:**

- **`format.lua`:**
  - the one list of statuses, each with the moment to report it;
  - `validate_report()` (RP1);
  - `report_schema()`, the tool's input schema (D8).
- **`instructions.lua`:** `report_instructions(tool_name)` (RP5).
- **`render.lua`** (RP2): `HH:MM [status] task — summary`. A newline in the task or summary becomes a space. Details are indented six spaces, under the status.
- **`buffer.lua`** (RP3): `aineo://report` from creation. It is `nofile`, unlisted, has no swap file, is kept when hidden, and has `'modifiable'` off, lifted only while the home writes.
- **`records.lua`** (RP4):
  - one JSON line per report, `{ time, report }`;
  - one file per working directory, `<state>/aineo/reports/<sha256>.jsonl`, created 0600;
  - lines that hold no record are skipped and counted;
  - a file that cannot be read is an error, which the entry point turns into one warning.
- **`init.lua`:**
  - `set_report_environment()`;
  - `report_buffer()`, which creates the Report on first use, shows the records first, and recreates it when the user has deleted or wiped it;
  - `receive_report()`, which validates, keeps, appends, and moves every window showing the Report to the newest report;
  - `validate_report`, `report_schema` and `report_instructions`.

**`lua/aineo/mcp/` (C5), behind `init.lua`:**

- **`init.lua`** (MC3): `mcp_servers(editor_address, editor_program)`, `report_tool_name()` and `allowed_mcp_tools()`.
- **`names.lua`:** the server name, the tool name and the environment variable, shared by the editor's side and the relay.
- **`relay.lua`:** the script Claude Code runs as `nvim --headless --clean -l`. It is that process's composition root: it puts the plugin found from its own path on `'runtimepath'` and reads `AINEO_EDITOR_ADDRESS`.
- **`server.lua`:** the stdio transport over `stdioopen()`, with `LINE_LIMIT` at 1 MiB.
- **`lines.lua`:** the line reader, which applies the limit as each chunk arrives.
- **`protocol.lua`:** the answer to each line (MC1), with the delivery as a port.
- **`editor.lua`** (MC2): delivery over `sockconnect` and `nvim_exec_lua`, with the report as the argument.

**Tests:**

- `tests/test_report.lua` (36 cases), `tests/test_report_buffer.lua` (27), `tests/test_mcp.lua` (5), `tests/test_mcp_relay.lua` (27) and `tests/test_mcp_delivery.lua` (8).
- Helpers: `tests/helpers/report_editor.lua`, `mcp_relay.lua` and `mcp_messages.lua`.
- The fixture `tests/fixtures/mcp/claude-code-2.1.281.jsonl`.

**Result at `dcb8e36`:**

- `make test`: 214 cases, `Fails (0)`, exit 0, 89 s.
- `make lint`: clean.
- The deep-`require` check prints 14 lines, each a home requiring its own file: `lua/aineo/mcp/*` → `aineo.mcp.*`, and `lua/aineo/report/*` → `aineo.report.*`. `protocol.lua` requires `aineo.report` through its entry point, an edge the direction table allows.

## Why it is shaped this way

- **Where ambient reads enter.** The report home takes the clock, the state directory and the working directory through `set_report_environment()`, which the composition root calls. The clock returns local time as `YYYY-MM-DDTHH:MM:SS`, so rendering and records need no time zone. `aineo.mcp` takes `v:servername` and `v:progpath` as `mcp_servers()` parameters. The relay reads its environment in `relay.lua` only.
- **One protocol version.** The relay speaks `2025-11-25` only, the version Claude Code 2.1.281 sends, and answers it to any request. 2025-06-18 differs on error ids (required there) and on argument errors (protocol errors there, tool errors in 2025-11-25). Claiming it would have been an untested claim.
- **Validation at both boundaries.** The relay validates before it delivers, so a refused report does not depend on the editor being up. The editor validates again, because its socket is a boundary too.
- **Delivery as data.** The Lua the editor runs is a constant, and the report is its RPC argument. The relay connects per call, so an editor that restarts or vanishes is met by a fresh connect.
- **A named Report.** Named from creation (brief review finding 1). Measured while building: a scratch buffer that is `:bdelete`d and written to again comes back with `'buftype'` empty and `'modified'` set, and `:qall` then fails with E37. So the home recreates an unloaded Report rather than writing to it.
- **Records keyed by SHA-256.** A long working directory as a file name can pass a file-name length limit; its SHA-256 cannot.

**The orchestrator's readings applied (for the MVP review):**

- **RP2:** a newline becomes a space.
- **RP3:** every window showing the Report follows the newest report.
- **RP4:** the Report is kept per working directory and reloaded on start.
- **RP5:** when Claude is told to report — when it begins a task the user gave, at meaningful progress on a long task, when it cannot go on without the user, when the task is complete, when it cannot be completed.

## Measured while building (Nvim 0.11.6, on this Mac)

- `stdioopen({ on_stdin = … })` works under `nvim --headless --clean -l`. It receives `{''}` at EOF, and its `on_print` catches `print()` and `:echo`. Errors in the relay's callbacks went to stderr, not stdout (seen in the red runs).
- `sockconnect('pipe', …)` raises `Vim:connection failed: connection refused` for a missing, empty or vanished socket. `rpcrequest` on a channel whose editor exited raises `Invalid channel: N`.
- A `vim.NIL` inside an argument table crosses `nvim_exec_lua` as `vim.NIL`.
- `vim.json` round-trips integer ids up to 2^53−1 exactly.
- An environment variable set to the empty string reached the relay's `vim.env` as nil. Removing the relay's `== ''` check changed no test, so the check was taken out.
- A mini.test child returns a Lua `nil` over RPC as `vim.NIL`.
- `assert(value, message)` returns both of its arguments. This bit a test helper, fixed before it was used.

## Red and green

**Seen red (45 of the 63 new tests), each with the failure that proved it.**

*`test_report.lua`:*

- returns a report of task, status and summary — `attempt to call field 'validate_report' (a nil value)`
- refuses anything else, naming the field (13 cases) — each report accepted: `Left: { "a report" } Right: { [2] = "arguments: expected an object" }`, and so on
- treats details that are a JSON null as absent — `different values at key "details", left = vim.NIL, right = nil`
- tells when to report each status (5 cases) — `attempt to call field 'report_instructions' (a nil value)`
- names the tool it is given (2 cases) — equality `false`/`true`. It was written in one step together with the next test, and both were seen red in the same run. The fields test was then taken out, the tool line made to pass, and the fields test re-added for its own red; a slip in the one-test-at-a-time rule, recorded here.
- names each field of the format (4 cases) — `Cause: different values`
- `set_report_environment()` refuses an environment it cannot use (4 cases) — no error raised

*`test_report_buffer.lua`:*

- renders as its time, status, task and summary — `attempt to call field 'set_report_environment' (a nil value)`
- renders each line of its details below it, indented — `key 2, left = nil, right = "      Changed three files"`
- renders a newline in its task or summary as a space — `'replacement string' item contains newlines`
- renders no details line when its details are empty — `key 2, left = "      ", right = nil`
- that is invalid is refused, naming the field, and not rendered — `different types` (no error)
- is named aineo://report, is no file, has no swap file and is kept hidden — `key 1, left = "", right = "aineo://report"`
- shows reports in the order they arrive — `left = "09:06 [done] First — Ended", right = "09:05 [started] First — Began"`
- refuses the user an edit, and still takes the next report — `Left: nil Right: "E21:"`
- moves every window showing it to the newest report — `Left: { 1, 1 } Right: { 4, 4 }`
- comes back with every report after the user deletes it (2 cases) — `:bdelete`: `left = "", right = "nofile"`; `:bwipeout`: `Invalid buffer id: 2`
- the Report buffer is refused until the report home has its environment — `Left: 2 Right: "aineo.report has no environment: …"`
- a report is refused until the report home has its environment — `attempt to index upvalue 'environment' (a nil value)`
- the records show a report again, at its own time, in a new editor in the same directory — `left = "", right = "09:05 [done] Task — Summary"`
- are readable and writable by their owner only — `Left: "644" Right: "600"`
- that cannot be read are skipped and counted (4 cases) — `Expected value but found invalid token`; `attempt to index local 'report'`; `" [done] T — S"` rendered; `attempt to index local 'time'`
- that cannot be read are reported, and the Report opens without them — `Left: false Right: true` (it opened silently)
- of another working directory never show — `left = "09:05 [done] Task — Summary", right = ""`

*`test_mcp.lua`:*

- describes the report server the way Claude Code starts a stdio server — `attempt to call field 'mcp_servers' (a nil value)`
- refuses an address or a program that is not a string (2 cases) — no error raised
- `report_tool_name()` — `attempt to call field 'report_tool_name' (a nil value)`
- `allowed_mcp_tools()` — `attempt to call field 'allowed_mcp_tools' (a nil value)`

*`test_mcp_relay.lua`:*

- initialize answers the recorded request… — `cannot open …/lua/aineo/mcp/relay.lua: No such file or directory` (no relay yet)
- a notification gets no answer — `Left: nil Right: 7`
- ping is answered with an empty object — `Left: { "123", false } Right: { "123", true }`
- tools/list lists one tool… — `attempt to index field 'result' (a nil value)` (it answered -32601)
- tools/call of another tool is answered with error -32602 — `Left: { 3, -32601 }`
- tools/call of a refused report is a tool error naming the field — `attempt to index field 'result' (a nil value)`
- tools/call whose params are no object… (2 cases) — no answer; stderr `attempt to index local 'params' (a number value)` / `(a userdata value)`
- a request for another method is answered with error -32601 — no answer; stderr `protocol.lua:37: attempt to call a nil value`
- a line that is not JSON… — no answer; stderr `Expected value but found T_END at character 34`
- a line that is JSON but no object… (4 cases) — `42` and `null` crashed the callback; `"ping"` and `[1,2]` were taken for notifications
- written in two parts… — `Left: { false, … } Right: { true, 11 }` (the first part answered alone)
- longer than 1 MiB is refused… before its newline arrives — no answer within 10 s
- longer than 1 MiB is dropped up to its newline… — `Left: nil Right: 14`

*`test_mcp_delivery.lua`:*

- a report reaches the editor the relay was given… — `key 2, left = nil` (no result)
- for an editor that is gone… — `Left: { false, false, 3 } Right: { true, true, 3 }` (it claimed delivery)
- that the editor does not take… — the text carried the editor's stack traceback
- with no editor address… (2 cases) — `aineo could not reach the editor at nil: Vim:E474: Invalid argument`

**Arrived green (18), each with the reason and the killer, run on `dcb8e36` and killed by assertion:**

- *`test_report.lua` › accepts each status of the format* — spent by the refusal unit's list of statuses. Killer: M8.
- *keeps details that are a string* — spent by the null unit's copy. Killer: "details dropped".
- *`test_report_buffer.lua` › is the same buffer on every use* — spent by the first rendering unit's cache. Killer: "new buffer every call"; the plain `if true` edit died by a crash (E95), so the edit that wipes the old buffer is the recorded one.
- *stays the Report when a file is edited from its window while it is empty* — spent by the naming unit. Killer: "unnamed buffer".
- *keep each report as one line of one file under the state directory* — spent by the first records unit. Killer: "records overwritten".
- *refuse a report they cannot keep, naming the file, and show nothing* — its branch was written ahead of its test, in the 0600 unit. Killer: "open failure unchecked". Its first run was an invalid red, from the test's own `mkdir` with mode 0500; the setup was fixed first.
- *keep no refused report* — spent by validating before keeping. Killer: "editor does not validate".
- *show before a new report, and each only once* — spent by opening the Report before keeping. Killer: "kept before the Report opens".
- *`test_mcp_relay.lua` › exits 0 when its input closes* — the EOF check was written ahead, in the first relay unit. Killer: "close never noticed" (`{ 124, 9 }`).
- *answers a protocol version it does not speak* — one version, always answered. Killer: "version echoed". Its first run failed on a harness defect, fixed.
- *is answered with its id unchanged* (4 cases) — the id has been echoed since the first relay unit. Killer: "id echoed as a string".
- *split inside a multibyte character is answered whole* — spent by the line reader. Killer: "every chunk a line", 3 of 3 runs.
- *that is empty gets no answer* — the guard was written ahead, in the first relay unit. Killer: "empty line answered".
- *three times 1 MiB long is refused once, its rest not kept* — spent by the dropping logic. Killer: "tail kept while dropping". At 2 × 1 MiB + 2 bytes the same edit survived, because the limit is checked per chunk; hence 3 × 1 MiB.
- *of exactly 1 MiB is read and answered* — spent by the `>` of the refusal unit. Killer: "limit >=".
- *`test_mcp_delivery.lua` › the server entry, started as Claude Code starts it…* — built by the units before it. Killer: "relay not on runtimepath".
- *reaches the editor as data* — by design. Killer: "report sent as code".
- *whose details are null renders without details* — spent by RP1's null handling. Killer: "null not absent", run on this file.

**Test changes after a first green, each re-measured:**

- The relay tests were rewritten so that a silent relay fails an assertion rather than a helper timeout. `next_lines()` returns what came, `decoded()` turns a missing line into `{}`, and fields are read with `vim.tbl_get`. After the rewrite, "limit doubled" and "relay not on runtimepath" die by assertion.
- The RP2 newline test now asserts on the call's outcome. Commit `fec11e6`; "newline kept" had died only by a crash.

## Mutants

54 literal edits. Each was applied to the committed file at `dcb8e36`, run with `make test_file`, and restored, and the restore was checked. **54 killed, all by assertion.** The runner and its per-mutant logs lived in the session's scratchpad (`t5-mutants.lua`); the table holds every edit whole. One survivor was found in the run on `fec11e6`: the line reader's guard holding back the end of a dropped line. `dcb8e36` removed the guard, since no test could ask for it, and it is not in the table.

| Mutant | File | Literal edit (old → new; ⏎ is a newline) | Run | Result on `dcb8e36` |
|---|---|---|---|---|
| M8 | `lua/aineo/report/format.lua` | `  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" },` → (nothing) | `tests/test_report.lua` | killed (assertion): 5 failing case(s), 5 by assertion, 0 crash |
| M8 (tools/list) | `lua/aineo/report/format.lua` | `  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" },` → (nothing) | `tests/test_mcp_relay.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| details dropped | `lua/aineo/report/format.lua` | `    details = not is_absent(arguments.details) and arguments.details or nil,` → `    details = nil,` | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| null not absent | `lua/aineo/report/format.lua` | `  return value == nil or value == vim.NIL` → `  return value == nil` | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| unknown field allowed | `lua/aineo/report/format.lua` | `  local unknown = first_unknown_field(arguments)` → `  local unknown = nil` | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| any status | `lua/aineo/report/format.lua` | `  if not vim.list_contains(M.STATUS_NAMES, arguments.status) then` → `  if arguments.status == nil then` | `tests/test_report.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| environment table unchecked | `lua/aineo/report/init.lua` | `  vim.validate('environment', report_environment, 'table')` → (nothing) | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| instructions ignore the tool name | `lua/aineo/report/instructions.lua` | `      tool_name ⏎     ),` → `      'mcp__aineo__report' ⏎     ),` | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| environment not required | `lua/aineo/report/init.lua` | `  if not environment then` → `  if false then` | `tests/test_report_buffer.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| new buffer every call | `lua/aineo/report/init.lua` | `  if not report_view then ⏎     local records_file` → `  if report_view then ⏎     buffer.discard(report_view.buffer) ⏎   end ⏎   if true then ⏎     local records_file` | `tests/test_report_buffer.lua` | killed (assertion): 3 failing case(s), 3 by assertion, 0 crash |
| unnamed buffer | `lua/aineo/report/buffer.lua` | `  vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME)` → (nothing) | `tests/test_report_buffer.lua` | killed (assertion): 4 failing case(s), 4 by assertion, 0 crash |
| buffer modifiable | `lua/aineo/report/buffer.lua` | `  vim.bo[buffer].modifiable = false` → (nothing) | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| modifiable left on | `lua/aineo/report/buffer.lua` | `  vim.bo[buffer].modifiable = modifiable` → `  vim.bo[buffer].modifiable = true` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| unloaded counts as showing | `lua/aineo/report/buffer.lua` | `  return vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer)` → `  return vim.api.nvim_buf_is_valid(buffer)` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| never recreated | `lua/aineo/report/init.lua` | `  elseif not buffer.is_showing(report_view.buffer) then` → `  elseif false then` | `tests/test_report_buffer.lua` | killed (assertion): 2 failing case(s), 1 by assertion, 1 crash |
| windows do not follow | `lua/aineo/report/init.lua` | `  buffer.follow_last_line(report_buffer)` → (nothing) | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| editor does not validate | `lua/aineo/report/init.lua` | `  local valid_report, refusal = format.validate_report(arguments)` → `  local valid_report, refusal = arguments, nil` | `tests/test_report_buffer.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| kept before the Report opens | `lua/aineo/report/init.lua` | `  local report_buffer = M.report_buffer() ⏎   local record = { time = current_environment().clock(), report = valid_report } ⏎   records.append_record(report_view.records_file, record)` → `  local record = { time = current_environment().clock(), report = valid_report } ⏎   records.append_record( ⏎     records.records_file(current_environment().state_directory, current_environment().working_directory), ⏎     record ⏎   ) ⏎   local report_buffer = M.report_buffer()` | `tests/test_report_buffer.lua` | killed (assertion): 9 failing case(s), 9 by assertion, 0 crash |
| newline kept | `lua/aineo/report/render.lua` | `  return (text:gsub('\n', ' '))` → `  return text` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| empty details rendered | `lua/aineo/report/render.lua` | `  if details == nil or details == '' then` → `  if details == nil then` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| details indented by two | `lua/aineo/report/render.lua` | `local DETAILS_INDENT = (' '):rep(#'HH:MM ')` → `local DETAILS_INDENT = '  '` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| M9 | `lua/aineo/report/records.lua` | `    vim.fn.sha256(working_directory) .. '.jsonl'` → `    'reports.jsonl'` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| records overwritten | `lua/aineo/report/records.lua` | `vim.uv.fs_open(file, 'a', OWNER_ONLY)` → `vim.uv.fs_open(file, 'w', OWNER_ONLY)` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| records 0644 | `lua/aineo/report/records.lua` | `local OWNER_ONLY = tonumber('600', 8)` → `local OWNER_ONLY = tonumber('644', 8)` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| open failure unchecked | `lua/aineo/report/records.lua` | `  if not descriptor then ⏎     error(('aineo cannot keep the report in %s: %s'):format(file, open_failure), 0) ⏎   end` → (nothing) | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| record shape unchecked | `lua/aineo/report/records.lua` | `  if not decoded or type(record) ~= 'table' or not is_record_time(record.time) then` → `  if not decoded then` | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| skipped records not told | `lua/aineo/report/init.lua` | `  if skipped > 0 then` → `  if false then` | `tests/test_report_buffer.lua` | killed (assertion): 4 failing case(s), 4 by assertion, 0 crash |
| unreadable records not told | `lua/aineo/report/init.lua` | `    vim.notify(kept, vim.log.levels.WARN)` → (nothing) | `tests/test_report_buffer.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| M7 | `lua/aineo/mcp/protocol.lua` | `      capabilities = { tools = vim.empty_dict() },` → `      capabilities = { tools = {} },` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| version echoed | `lua/aineo/mcp/protocol.lua` | `  initialize = function() ⏎     return { ⏎       protocolVersion = PROTOCOL_VERSION,` → `  initialize = function(params) ⏎     return { ⏎       protocolVersion = params.protocolVersion,` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| notifications answered | `lua/aineo/mcp/protocol.lua` | `  if message.id == nil then ⏎     return nil ⏎   end` → (nothing) | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| ping result an array | `lua/aineo/mcp/protocol.lua` | `    return vim.empty_dict() ⏎   end, ⏎   ['tools/list'` → `    return {} ⏎   end, ⏎   ['tools/list'` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| -32601 as -32600 | `lua/aineo/mcp/protocol.lua` | `local METHOD_NOT_FOUND = -32601` → `local METHOD_NOT_FOUND = -32600` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| any tool is report | `lua/aineo/mcp/protocol.lua` | `  if params.name ~= names.REPORT_TOOL then` → `  if false then` | `tests/test_mcp_relay.lua` | killed (assertion): 3 failing case(s), 3 by assertion, 0 crash |
| refusal as RPC error | `lua/aineo/mcp/protocol.lua` | `    return tool_result('aineo refused the report: ' .. refusal, true)` → `    return nil, { code = INVALID_PARAMS, message = refusal }` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| parse error with an id | `lua/aineo/mcp/protocol.lua` | `    return error_response(nil, PARSE_ERROR, 'Parse error: the message is not JSON')` → `    return error_response(0, PARSE_ERROR, 'Parse error: the message is not JSON')` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| array taken as object | `lua/aineo/mcp/protocol.lua` | `  if type(message) ~= 'table' or vim.islist(message) then` → `  if type(message) ~= 'table' then` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| params unguarded | `lua/aineo/mcp/protocol.lua` | `  local params = type(message.params) == 'table' and message.params or {}` → `  local params = message.params` | `tests/test_mcp_relay.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| id echoed as a string | `lua/aineo/mcp/protocol.lua` | `  return { jsonrpc = '2.0', id = message.id, result = result }` → `  return { jsonrpc = '2.0', id = tostring(message.id), result = result }` | `tests/test_mcp_relay.lua` | killed (assertion): 17 failing case(s), 17 by assertion, 0 crash |
| every chunk a line | `lua/aineo/mcp/lines.lua` | `    for index, piece in ipairs(data) do` → `    for _, whole in ipairs(data) do ⏎       options.on_line(whole) ⏎     end ⏎     for index, piece in ipairs({}) do` | `tests/test_mcp_relay.lua` | killed (assertion): 6 failing case(s), 6 by assertion, 0 crash |
| limit >= | `lua/aineo/mcp/lines.lua` | `      if #partial > options.limit then` → `      if #partial >= options.limit then` | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| tail kept while dropping | `lua/aineo/mcp/lines.lua` | `      if not dropping then ⏎         partial = partial .. piece ⏎       end` → `      partial = partial .. piece` | `tests/test_mcp_relay.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| limit doubled | `lua/aineo/mcp/server.lua` | `local LINE_LIMIT = 1024 * 1024` → `local LINE_LIMIT = 2 * 1024 * 1024` | `tests/test_mcp_relay.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| empty line answered | `lua/aineo/mcp/server.lua` | `      local answer = line ~= '' and protocol.answer_line(line, deliver_report)` → `      local answer = protocol.answer_line(line, deliver_report)` | `tests/test_mcp_relay.lua` | killed (assertion): 3 failing case(s), 3 by assertion, 0 crash |
| close never noticed | `lua/aineo/mcp/server.lua` | `        closed = true` → (nothing) | `tests/test_mcp_relay.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| delivery result ignored | `lua/aineo/mcp/protocol.lua` | `  local delivered, failure = deliver_report(valid_report)` → `  local delivered, failure = true, deliver_report(valid_report)` | `tests/test_mcp_delivery.lua` | killed (assertion): 4 failing case(s), 4 by assertion, 0 crash |
| no-address guard removed | `lua/aineo/mcp/editor.lua` | `  if address == nil then ⏎     return false, 'aineo has no editor address to deliver the report to' ⏎   end` → (nothing) | `tests/test_mcp_delivery.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| traceback kept | `lua/aineo/mcp/editor.lua` | `first_line(tostring(failure))` → `tostring(failure)` | `tests/test_mcp_delivery.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| report sent as code | `lua/aineo/mcp/editor.lua` | `pcall(vim.rpcrequest, channel, 'nvim_exec_lua', RECEIVE_REPORT, { report })` → `pcall(vim.rpcrequest, channel, 'nvim_exec_lua', ("require('aineo.report').receive_report({ task = '%s', status = '%s', summary = '%s', details = [[%s]] })"):format(report.task, report.status, report.summary, report.details or ''), {})` | `tests/test_mcp_delivery.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| relay not on runtimepath | `lua/aineo/mcp/relay.lua` | `vim.opt.runtimepath:prepend(plugin_root)` → `local _ = plugin_root` | `tests/test_mcp_delivery.lua` | killed (assertion): 8 failing case(s), 8 by assertion, 0 crash |
| entry without --clean | `lua/aineo/mcp/init.lua` | `      args = { '--headless', '--clean', '-l', RELAY },` → `      args = { '--headless', '-l', RELAY },` | `tests/test_mcp.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| another tool allowed | `lua/aineo/mcp/init.lua` | `  return { M.report_tool_name() }` → `  return { M.report_tool_name(), 'Bash' }` | `tests/test_mcp.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| address unchecked | `lua/aineo/mcp/init.lua` | `  vim.validate('editor_address', editor_address, 'string')` → (nothing) | `tests/test_mcp.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| tool name misspelt | `lua/aineo/mcp/init.lua` | `  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.REPORT_TOOL)` → `  return ('mcp__%s_%s'):format(names.SERVER_NAME, names.REPORT_TOOL)` | `tests/test_mcp.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |

The brief's verification mutants:

- **M7:** `test_mcp_relay.lua` › initialize › "answers the recorded request with its protocol version, a tools object and the server", which asserts on the raw `"tools":{}`.
- **M8:**
  - `test_report.lua` › "accepts each status of the format" [`blocked`];
  - `test_report.lua` › "tells when to report each status of the format" [`blocked`], which names C6's statuses literally;
  - `test_report.lua`: the three status refusals;
  - `test_mcp_relay.lua` › `tools/list`: the enum.
- **M9:** `test_report_buffer.lua` › the records › "of another working directory never show".

## Task lines

This wave holds its marks (plan, *Packets* rule 6), so the plan is untouched. For the knowledge pass:

- **T5 — MCP server and relay (C5), report rendering and persistence (C6):** done in PR #10 — RP1–RP5 and MC1–MC3 as the brief reads them.
- The relay speaks MCP 2025-11-25 only.
- The line limit is 1 MiB.
- Records go in `<state>/aineo/reports/<sha256 of cwd>.jsonl`, created 0600.
- For T7, the root calls `set_report_environment()` first, then:
  - `mcp_servers(vim.v.servername, vim.v.progpath)`;
  - `allowed_mcp_tools()`;
  - `report_instructions(report_tool_name())`;
  - `report_buffer()`.

## Candidate learnings (for the knowledge pass; this packet writes no Learnings note)

- **A `:bdelete`d scratch buffer written to again is an ordinary modified buffer that blocks `:qall` (E37).** A plugin-owned buffer is recreated when unloaded, not reused.
- **`nvim -l` with `stdioopen()` is a clean stdio server.** Messages go to `on_print` or stderr, never to stdout; EOF arrives as `{''}`; and `rpcrequest` works from inside `on_stdin`.
- **Mutant kills through a child process must be assertions.** A helper that raises on a timeout turns every "the process went silent" mutant into a crash. Return what arrived and let the test's assertion fail.
- **A line limit checked per read chunk lets up to one chunk past the limit be held.** A test of "not buffered past the limit" needs a line longer than the limit plus the largest chunk.

## Open threads

- **The oldest `claude` version supported is still the user's decision.** A Claude Code that sends 2025-06-18 is answered 2025-11-25 and may disconnect; the report tool would then be missing.
- **The relay's `rpcrequest` has no timeout.** An editor that accepts the socket but never answers holds the tool call until Claude Code's own timeout.
- **What Neovim writes to stdout at the relay's exit after a callback error was not measured.** The relay registers no `on_print`.
- **`serverInfo.version` is `0.0.0`.** aineo has no release version yet.
- **After `set_report_environment()` is called with a new working directory, an existing Report keeps its first directory's records file until the editor restarts.** Documented on `report_buffer()`.
- **The end-to-end check, a real Claude calling `mcp__aineo__report`, is T7's** (wave plan, *Why T4 runs beside T5*).

## Commits

*Recorded after the merge.* The branch carries four code commits and this note's commit; their hashes change on rebase.
