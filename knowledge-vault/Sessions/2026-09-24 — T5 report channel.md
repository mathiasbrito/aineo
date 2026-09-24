# 2026-09-24 — T5 report channel

**Author:** Mathias Santos de Brito, with Claude — implementer agents (`neovim-claude-code-integrator`): the packet's author, then, for the end of its fix round, the agent it handed over to; then, for the correction of the re-measure, a fresh agent
**Branch:** `feature/t5-report-channel` · **Pull request:** #10 (packet round, then the fix round and the correction below)

The sections up to *Open threads* describe the packet round at `dcb8e36`. Where the reviews showed one of them wrong, it is corrected in place and says so; where the fix round changed what it describes, it points to the *Fix round* section below. The *Fix round* section describes the branch at `1a67263`; where the re-measure showed it wrong, it says so in place and points to *Correction*.

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
- **`relay.lua`:** the script Claude Code runs as `nvim --headless --clean -l`. It is that process's composition root: it puts the plugin found from its own path on `'runtimepath'` and reads `AINEO_EDITOR_ADDRESS`. `--clean` does not isolate it: plugins under `$XDG_CONFIG_DIRS` and `$XDG_DATA_DIRS` still load (the attack review's A6); the fix round adds `--cmd 'set noloadplugins'`.
- **`server.lua`:** the stdio transport over `stdioopen()`, with `LINE_LIMIT` at 1 MiB.
- **`lines.lua`:** the line reader, which applies the limit as each chunk arrives.
- **`protocol.lua`:** the answer to each line (MC1), with the delivery as a port.
- **`editor.lua`** (MC2): delivery over `sockconnect` and `nvim_exec_lua`, with the report as the argument. The fix round bounds the wait for the editor's answer (A2).

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
- **A named Report.** Named from creation (brief review finding 1). Measured while building: a scratch buffer that is `:bdelete`d and written to again comes back with `'buftype'` empty and `'modified'` set, and `:qall` then fails with E37. So the home recreates an unloaded Report rather than writing to it. That was not enough: a deleted Report the user shows again (`:buffer #`) is loaded again as an ordinary buffer (the attack review's A3). Since the fix round, a Report counts as showing only while it is `nofile`; since the correction, only while it is also loaded, since `:bunload` keeps `nofile` (see *Correction*).
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
- *split inside a multibyte character is answered whole* — spent by the line reader. Killer: "every chunk a line", 3 of 3 runs. That kill held only while the relay was already reading when the first part arrived; under a slow relay start both partial-line tests went green (the test-integrity review's I3). The fix round sends a ping first.
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

**53 distinct literal edits in 55 runs** — corrected by the records review (R1). The packet round recorded "54 literal edits … 54 killed, all by assertion"; that was wrong in three ways:

- M8's one edit ran on two files, so 54 rows held 53 edits.
- The run of "null not absent" on `test_mcp_delivery.lua`, which the arrived-green account names as a killer, had no row. The records review ran it on `70ed857`, whose code is `dcb8e36`'s: `Fails (1)`, by assertion. Its row is added below, credited.
- Every run was killed by at least one assertion, but not every failing case failed by assertion. The `[bwipeout]` case of "never recreated" failed only by a crash (`Invalid buffer id: 2`), as its row says (the test-integrity review's I4).

Each edit was applied to the committed file at `dcb8e36`, run with `make test_file`, and restored, and the restore was checked. The runner and its per-mutant logs lived in the session's scratchpad (`t5-mutants.lua`); the table holds every edit whole. One survivor was found in the run on `fec11e6`: the line reader's guard holding back the end of a dropped line. `dcb8e36` removed the guard, since no test could ask for it, and it is not in the table.

| Mutant | File | Literal edit (old → new; ⏎ is a newline) | Run | Result on `dcb8e36` |
|---|---|---|---|---|
| M8 | `lua/aineo/report/format.lua` | `  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" },` → (nothing) | `tests/test_report.lua` | killed (assertion): 5 failing case(s), 5 by assertion, 0 crash |
| M8 (tools/list, tools/call) | `lua/aineo/report/format.lua` | `  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" },` → (nothing) | `tests/test_mcp_relay.lua` | killed (assertion): 2 failing case(s), 2 by assertion, 0 crash |
| details dropped | `lua/aineo/report/format.lua` | `    details = not is_absent(arguments.details) and arguments.details or nil,` → `    details = nil,` | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| null not absent | `lua/aineo/report/format.lua` | `  return value == nil or value == vim.NIL` → `  return value == nil` | `tests/test_report.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash |
| null not absent (delivery; the records review's run, on `70ed857`) | `lua/aineo/report/format.lua` | `  return value == nil or value == vim.NIL` → `  return value == nil` | `tests/test_mcp_delivery.lua` | killed (assertion): 1 failing case(s), 1 by assertion, 0 crash — "whose details are null renders without details" |
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
  - `test_mcp_relay.lua` › `tools/list` › "lists one tool, report, whose input schema is the report format" (the enum) and `tools/call` › "of a refused report is a tool error naming the field" (the refusal's list of statuses). The packet round named `tools/list` alone for both kills; `tools/list` has one case (R1, measured by the records review).
- **M9:** `test_report_buffer.lua` › the records › "of another working directory never show".

## Task lines

This wave holds its marks (plan, *Packets* rule 6), so the plan is untouched. For the knowledge pass:

- **T5 — MCP server and relay (C5), report rendering and persistence (C6):** done in PR #10 — RP1–RP5 and MC1–MC3 as the brief reads them.
- The relay speaks MCP 2025-11-25 only.
- The line limit is 1 MiB.
- Records go in `<state>/aineo/reports/<sha256 of cwd>.jsonl`, created 0600. The Report shows the newest 2 MiB of them, and the file is cut back to its newest 2 MiB past 4 MiB (fix round, A5).
- The relay waits at most 5 s for the editor to confirm a report (fix round, A2), and runs as `nvim --headless --clean --cmd 'set noloadplugins' -l <relay>` (A6).
- Correction of the re-measure: the relay reads the editor's answer through `vim.uv` handles; an unconfirmed report is "sent, not confirmed", and the editor tells the user of a report it cannot keep; a failed cut keeps the report; cut files are per process.
- For T7, the root calls `set_report_environment()` first, then:
  - `mcp_servers(vim.v.servername, vim.v.progpath)`;
  - `allowed_mcp_tools()`;
  - `report_instructions(report_tool_name())`;
  - `report_buffer()`.

## Candidate learnings (for the knowledge pass; this packet writes no Learnings note)

- **A `:bdelete`d scratch buffer written to again is an ordinary modified buffer that blocks `:qall` (E37).** A plugin-owned buffer is recreated when it is no longer `nofile`, not reused. Checking "unloaded" is not enough: `:buffer #` loads the deleted buffer again, as an ordinary buffer (the fix round, A3).
- **`nvim -l` with `stdioopen()` is a clean stdio server once no plugin loads.** Messages go to `on_print` or stderr, never to stdout; EOF arrives as `{''}`; and `rpcrequest` works from inside `on_stdin`. `--clean` still loads plugins from `$XDG_CONFIG_DIRS` and `$XDG_DATA_DIRS`, which can write to stdout; `--cmd 'set noloadplugins'` keeps out `plugin/`, `pack/*/start` and `after/plugin` there (the fix round, A6).
- **Mutant kills through a child process must be assertions.** A helper that raises on a timeout turns every "the process went silent" mutant into a crash. Return what arrived and let the test's assertion fail.
- **`sockconnect()`'s `on_data` is not binary-safe.** Its list form hands a zero byte over as a newline, so msgpack read through it breaks whenever a length or a type is zero; read a binary protocol through a `vim.uv` handle (the correction, finding 2).
- **`:bunload` keeps a `nofile` buffer's `'buftype'`, and writing into the unloaded buffer loads it, firing its `BufReadCmd`.** "Still `nofile`" does not mean "still showing" (the correction, finding 1).
- **`vim.fn.mkdir(…, 'p')` fails with E739 on whichever directory of the path another process made first.** Retry, bounded by the path's depth (the correction, finding 10).
- **A line limit checked per read chunk lets up to one chunk past the limit be held.** A test of "not buffered past the limit" needs a line longer than the limit plus the largest chunk.

## Open threads

- **The oldest `claude` version supported is still the user's decision.** A Claude Code that sends 2025-06-18 is answered 2025-11-25 and may disconnect; the report tool would then be missing.
- **The relay's `rpcrequest` has no timeout** — understated, corrected by the attack review (A2): not only an editor that never answers, but any editor at a hit-enter prompt held the call and every message after it, and aineo's own warning could raise that prompt. The fix round bounds the wait (see *Fix round*).
- **What Neovim writes to stdout at the relay's exit after a callback error was not measured.** The relay registers no `on_print`.
- **`serverInfo.version` is `0.0.0`.** aineo has no release version yet.
- **After `set_report_environment()` is called with a new working directory, an existing Report keeps its first directory's records file until the editor restarts.** Documented on `report_buffer()`.
- **The end-to-end check, a real Claude calling `mcp__aineo__report`, is T7's** (wave plan, *Why T4 runs beside T5*).

## Fix round (2026-09-24)

The three reviews of PR #10 at `70ed857` were worked as one round, under the orchestrator's fix-round brief and its fifteen decisions. They are attack A1–A10, test-integrity I1–I7 and records R1–R6, plus the reviewers' cross-notes, and the findings are cited here by those IDs.

The packet's author did the round up to `668a3a7`. It stopped when its context reached the model's limit, not because its work was wrong. The agent it handed over to then:

- committed the author's last test change;
- checked each decision against the commits;
- ran each new test against the reviewed head's code;
- pinned what the final mutant run found unpinned;
- ran the final table and wrote this section.

A claim that rests on the author's account alone says so.

The hashes below are branch states named as measurement points: `70ed857` (reviewed), `668a3a7` (where the author stopped), `d01bea8` (the final code, and the state the mutant table ran on). The *Commits* section is recorded after the merge.

**What the round changed, in commit order:**

1. **The author's commits:**
   1. the reviewers' test pins (I1–I6), and relay tests that start the relay from the entry point (R2);
   2. the Report's lifecycle (A1, A3, A4), and R6;
   3. the schema admits a `null` in `details` (R4); a `null` id is refused; the relay serves only as the `-l` script; A7 and A8;
   4. a bounded wait on the editor (A2), and bounded records (A5);
   5. `noloadplugins` in the relay (A6), and R5. That commit's message says that the packet round's records of `--clean` as isolation were wrong;
   6. the Report's loaded check removed, which the author's mutant run showed to be unobservable — **wrong**: `:bunload` separates it, and the correction restores it (see *Correction*, finding 1);
   7. the relay's answer queue removed, for the same reason.
2. **The handover's commits:**
   1. the relay's load test reaches the script through the entry point;
   2. every path of the records' bound pinned by assertion;
   3. the answer reader pinned against an editor that notifies first, and its unobservable id check dropped;
   4. the Report's autocommand group created with the default, and two docstrings corrected;
   5. this section.

**Result at `d01bea8`** (measured in the handover):

- `make test`: 239 cases, `Fails (0) and Notes (0)`, exit 0. Per T5 file: `test_report.lua` 42, `test_report_buffer.lua` 37, `test_mcp.lua` 5, `test_mcp_relay.lua` 30, `test_mcp_delivery.lua` 11, `test_mcp_blocked_editor.lua` 3.
- `make lint`: clean.
- The deep-`require` check prints 14 lines, each a file of a home requiring a file of that same home:
  - in `aineo.mcp`: `init` and `protocol` require `names`; `server` requires `editor`, `lines` and `protocol`; `relay` requires `names` and `server`;
  - in `aineo.report`: `init` requires `buffer`, `format`, `instructions`, `records` and `render`; `instructions` and `records` require `format`.

### Findings

| Finding | Outcome |
|---|---|
| A1 a Report name already taken | **Fixed** (the reviewer's F3): any buffer named `aineo://report` is wiped before the Report is created (since the correction, one whose text the user changed is kept, unnamed — finding 3). Pinned by `:bwipeout` then `:edit aineo://report`, and by `:file aineo://report`, the line a restored session runs. Red on `70ed857`'s code: E95 on both reports, in both cases. |
| A2 a hit-enter prompt holds the report and everything after it | **Fixed where aineo causes it, and bounded.** aineo's warnings are scheduled. The relay sends its msgpack-RPC request itself and waits at most 5 s (the bound is explained under *Readings*). Pinned with a real TUI editor held at a hit-enter prompt: the report is answered "not confirmed" in time; a ping sent during the wait is answered next; the report shows after Enter. Also pinned: an editor killed mid-wait is a tool error at once, and aineo's own warning no longer holds the report. What remains is under *Limits*. |
| A3 a deleted Report shown again | **Fixed** (the reviewer's F4): a Report counts as showing only while it is `nofile` (since the correction, and loaded — finding 1). Pinned with `:buffer #` and `:buffer aineo://report`, after which `:qall` quits. Red on `70ed857`'s code: `'buftype'` empty and `jobwait` −1. A residue measured in the handover is under *Limits*. |
| A4 `:edit` empties the Report | **Fixed**: a buffer-local `BufReadCmd` renders the records again. This was chosen over refusing the command, for which Neovim offers no hook on a `nofile` buffer (the author's measurement). Pinned with `:edit` and `:edit!`. Red: `{ "" }`. |
| A5 records grow without bound | **Fixed, bounded in bytes**: the Report shows the newest 2 MiB, and a file past 4 MiB is cut back to its newest 2 MiB. The orchestrator's 1000 records were replaced, since one report can hold 1 MiB. Red on `70ed857`'s code: 3072 records shown; 4098 lines kept. The handover pinned the remaining paths: whole records only when the window begins mid-line, a file kept whole up to 4 MiB, and the cut test reading records without raising. |
| A6 system site plugins load in the relay | **Fixed** (the reviewer's F5): `--cmd 'set noloadplugins'`. The orchestrator read C5's row as allowing this, so there is no spec change. Pinned by a plugin planted under a fixture `$XDG_DATA_DIRS`. Red: its marker was created. The handover also measured `pack/*/start` and `after/plugin` (below). |
| A7 an answer that fails to encode breaks the reader | **Fixed** (the reviewer's F1): each line is answered under `pcall`, and the failure goes to stderr through `vim.uv.fs_write`, since selene refuses `io.stderr:write`. Pinned with `1e999`. Red: `{}` where `{ 31 }` was expected. |
| A8 a TCP editor address | **Fixed** (the reviewer's F2). Pinned with `serverstart('127.0.0.1:0')`. Red: a tool error. |
| A9 a `tools/call` over 1 MiB is answered −32600 without an id | **Recorded as a limit**, as the reviewer states it: the client cannot match the answer to its request. It follows from MC1. |
| A10 JSON-RPC edge answers | The `null` id is **fixed**: refused with −32600 and no id (decision 14). A client response is still answered −32601, and an object id is still echoed; both are **recorded**, as the reviewer states them. |
| I1 the wire format only spot-checked | **Fixed** (the reviewer's patch): whole decoded answers for `initialize` and −32601, with the raw `"tools":{}` check kept. N2a, N2c, N8a and N8b die by assertion on `test_mcp_relay.lua`. They still survive `test_mcp_delivery.lua`, which reads selected fields, as the reviewer measured there before the fix. |
| I2 the shell payload unchecked | **Fixed**: a witness file. P2 dies by assertion. |
| I3 the partial-line tests are timing-dependent | **Fixed**: a ping is answered first. Slow start plus "every chunk a line" fails 6 cases by assertion, both partial-line tests among them, 3 of 3 runs. |
| I4 crash-only kills | **Fixed**. `decoded()` never raises, and N12 fails 29 cases by assertion. "Cannot keep" uses `tostring`, and N10 dies by assertion. "Comes back" asserts the outcome first, and "never recreated" fails 5 cases by assertion, `[bwipeout]` among them. The handover made one more crash-only kill an assertion kill: the cut test on "partial first line kept". |
| I5 the channel close unpinned | **Fixed**: one socket is left in the editor after a delivery. N9 dies by assertion. |
| I6 "unlisted" unpinned | **Fixed**: `buflisted` false is pinned. N17 dies by assertion. |
| I7 (REFUTED: what the reviewer found true) | No action. |
| R1 the mutant ledger | **Corrected** in *Mutants* above, in the pull request body and in the report: 53 distinct edits in 55 runs, M8's relay killers named, and the "null not absent" run on `test_mcp_delivery.lua` given its row. |
| R2 tests bound to the relay's file path | **Fixed** (the reviewer's measured patch, in the author's first commit). In the handover, the last test that still required `aineo.mcp.relay` by name was changed to load the script the entry names. The rename probe's 27 of 27 passing is the author's measurement, not re-run in the handover. |
| R3 code written before its test (disclosed) | No code change, as the reviewer says. The round's tests that arrived green are named below, each with its killer run. |
| R4 schema and validator disagree on `details: null` | **Fixed**: the schema admits `["string", "null"]`, with an agreement test over six JSON types. Red on `null`. |
| R5 "disconnects" stated as fact | **Fixed**: "should then disconnect (a SHOULD)". |
| R6 `kept` holds an error message | **Fixed**: `records_or_failure`. |
| Cross-notes, attack → test-integrity | A hit-enter editor, a taken name and a reopened deleted Report are each driven by a test now (A2, A1, A3). |
| Cross-notes, attack → records | Both **corrected**: the understated timeout limit and the overstated `--clean`. The corrections are in the message of the commit that adds `noloadplugins`, the pull request body, and this note (*What was done*, *Open threads*). |
| Cross-note, test-integrity → records | The "unlisted" docstring is pinned (I6). |
| Cross-notes, records | **Fixed**, each with a pin: the relay loaded inside an editor serves nothing; a `null` id is refused; the `[bwipeout]` case now dies by assertion. |
| Test-integrity's note "the wave brief lists 24 files, gh 23" | **No T5 record states 24.** The packet report lists 23 files, and the records review counted 23 inside the boundary. After this round the pull request changes 25 files, every one inside the brief's boundary. |

### Measured in the fix round (Nvim 0.11.6, on this Mac)

**The author's measurements** (from its progress note; the handover re-measured only where marked):

- `:edit` and `:edit!` on the named `nofile` Report fire a buffer-local `BufUnload`, `BufReadCmd` and `BufEnter`. A `BufReadCmd` that fills the buffer leaves it `nofile`, not modifiable and not modified.
- **The open time was per record.** One `nvim_buf_set_lines` call per record took about 90 µs, so a 4 MiB file of ordinary records opened in 1722 ms; with one write it opened in 104 ms.
- **A queued request survives the client.** Once the editor has read a request, it runs it even after the client has closed the socket.
- **The TUI is a separate client process.** Stopping it or killing it lets the editor's server answer the queued request first. An editor that dies without answering has to be simulated by killing the server process.
- **`vim.mpack.Unpacker` is stateful across chunks.** It returns nil on a partial message and resumes with the next chunk.
- **The relay's stdin callback does not re-enter** while one call of it waits in `vim.wait`. The evidence is the survival of "answered inside the stdin callback" against a ping sent 500 ms into the wait.

**Re-measured or new in the handover:**

- **Open time at the bound**, one run each (the author measured 47, 78 and 45 ms):
  - the newest 2 MiB of a 4 MiB file (9320 of 18641 records): 45 ms;
  - a case of 520004 Report lines: 93 ms — not the worst case: the re-measure measured 1 040 004 lines in 156 ms (see *Correction*, finding 9);
  - a 40 MiB file: 49 ms, since only its end is read.
- **`noloadplugins` keeps every system site plugin out.** With `--headless --clean` alone, a `plugin/`, a `pack/*/start/*/plugin/` and an `after/plugin/` script under `$XDG_DATA_DIRS/nvim/site` all ran. With `--cmd 'set noloadplugins'` added, none did.
- **Each test the round added fails by assertion against `70ed857`'s production code**, with the current tests. The failure messages are listed under *Red and green*.
- **A deleted Report shown again before the next report** (`:bdelete`, then `:buffer #`) is loaded again through its own `BufReadCmd`. It comes back as an ordinary buffer showing the records: `'buftype'` empty, modifiable, not modified. `:qall` quits.
- **`vim.json.encode` writes DEL (0x7f) as the six bytes `\u007f`.** A client can send it raw, as one byte. Of the other characters probed, `/` and U+2028 are not grown: `\u00e9` shrinks to `é`, and `\u0001` stays six bytes.

### Readings for the MVP review

- **One protocol version.** The relay speaks MCP 2025-11-25 only.
  - A client asking for any other version gets an `initialize` result whose `protocolVersion` is `"2025-11-25"`, with the same capabilities and server. The test "answers a protocol version it does not speak with the one it speaks" pins this with `2024-11-05`.
  - By the Lifecycle page, such a client *should* disconnect; if it does, Claude has no report tool for that session.
  - **Which `claude` is the oldest supported remains the user's decision.** Claude Code 2.1.281 sends 2025-11-25.
- **A report not confirmed within 5 s** (an editor at a hit-enter prompt, say) is answered as sent but not confirmed, and Claude is told not to send it again. The answer is not an error, and the report shows when the user is done. **Corrected by the correction:** that held only when keeping the report then succeeded; a report the editor could not keep was dropped silently (finding 6). See *Correction › Readings*.
  - Why 5 s: it is far above a delivery's time (the attack reviewer measured 80 ms for a report of 524 000 newlines, and 11 ms for one with 1 MiB of details). It is also well below the two minutes after which Claude Code moves a tool call to the background, a figure that is the reviewer's reading of the Claude Code docs, not a measurement.
- **`:edit` in the Report renders its records again**, rather than refusing the command.
- **The Report shows the newest 2 MiB of records**, and the file is cut back to its newest 2 MiB when it grows past 4 MiB. This is a bound in bytes, where the orchestrator's reading was 1000 records.
- **The tool's input schema says `"details": {"type": ["string", "null"]}`.** Whether Claude Code accepts a type array there is not measured, since the real `claude` never runs here. It is T7's end-to-end check.

### Red and green in the fix round

17 new tests, 25 new cases: the suite went from 214 to 239 cases.

**Seen red (13, the author's).** The author recorded each red in its progress note; the *Findings* table above quotes them. The message shown here is from the handover's run of each test against `70ed857`'s production code, where every one failed by assertion:

- *`report_schema()` admits the same details as `validate_report()`* [`null`] — `false` where `true` was expected.
- *takes its name back from a buffer holding it, and leaks none* (2 cases) — E95 on both reports.
- *deleted then shown again by the user takes no report, and the editor quits* (2) — `{ vim.NIL, "", -1 }` where `{ vim.NIL, "nofile", 0 }` was expected.
- *keeps every report when the user edits it again* (2) — `{ "" }`.
- *show the newest 2 MiB of them* — 3072 records shown, where 2048 were expected.
- *are cut to their newest 2 MiB once they have grown past 4 MiB* — 4098 lines kept, where 2049 were expected.
- *the relay loads no plugin from the system site directories* — the marker was created.
- *a request whose id is null is refused with error -32600 and no id* — it was answered, echoing `"id":null`.
- *a request whose answer cannot be written does not take the next one down* — `{}` where `{ 31 }` was expected.
- *the relay script loaded inside an editor serves nothing* — one stdio channel where none was expected. The author wrote it as "required inside an editor"; the handover's first commit loads the script the entry names, and its killer still dies by assertion.
- *a report reaches an editor listening on a TCP address* — a tool error.
- *a report for an editor at a hit-enter prompt is answered in time, the relay keeps serving, and the report shows once the user is done* — no answer.
- *a report that opens a Report with a warning is confirmed before the warning can hold the editor* — no answer within 4 s.

**Arrived green (4):**

- *is a tool error at once when the editor dies before it answers* (the author's). Its branch was written with the bounded wait, ahead of the test. Against `70ed857`'s code it failed only on the wording of the error. Killers: "close ignored while waiting" and "EOF not noted", each killed by assertion, 3 of 3 runs.
- *the records show whole records only, when the newest 2 MiB begin inside one* (the handover's) — the code came with the author's bounded records. Killers: "partial first line kept" and "first line dropped only when empty", each killed by assertion on the spurious "skipped 1 unreadable report record(s)" warning.
- *the records are kept whole up to 4 MiB when a report is added* (the handover's). Killers: "cut past 2 MiB, not 4" and "cut at 4 MiB exactly", each killed by assertion.
- *a report is confirmed by an editor that writes a notification before its answer* (the handover's) — the type check came with the author's bounded wait. Killer: "any message taken for the answer", killed by assertion, 3 of 3 runs. It was first written with both messages in one write, and that version let the killer survive: the answer, read after the notification, overwrote it. Hence the 50 ms delay.

**Tests changed, each re-measured on its reviewer's literal mutant:**

- the `initialize` and −32601 whole answers (N2a, N2c, N8a, N8b);
- the witness file (P2);
- a ping first in the two partial-line tests (I3);
- `decoded()` never raises, and the id test also decodes (N12);
- "cannot keep" via `tostring` (N10);
- "comes back" asserts the outcome first ("never recreated");
- one socket left in the editor after a delivery (N9);
- `buflisted` (N17);
- the MC3 pin and the `tools/list` schema, for A6 and R4;
- the cut test reads records through `recorded_task()` (the handover's), so "partial first line kept" dies by assertion there.

### Mutants on the final head

Head `d01bea8`. K = killed, A = by assertion, E = by crash; a row run several times gives the ratio.

**The reviewers' literal edits:**

| Mutant | Literal edit (old → new; ⏎ is a newline) | Run | Result | Killing cases |
|---|---|---|---|---|
| N2a | `protocol.lua`: `capabilities = { tools = vim.empty_dict() },` → `capabilities = { tools = vim.empty_dict(), logging = {} },` | `test_mcp_relay.lua` | K: 1 A | A initialize › answers the recorded request with its protocol version, a tools object and the server |
| N2a | `protocol.lua`: `capabilities = { tools = vim.empty_dict() },` → `capabilities = { tools = vim.empty_dict(), logging = {} },` | `test_mcp_delivery.lua` | survived — this file reads selected fields; the relay file kills it |  |
| N2c | `protocol.lua`: `serverInfo = { name = 'aineo', version = '0.0.0' },` → `serverInfo = { name = 'aineo' },` | `test_mcp_relay.lua` | K: 1 A | A initialize › answers the recorded request with its protocol version, a tools object and the server |
| N2c | `protocol.lua`: `serverInfo = { name = 'aineo', version = '0.0.0' },` → `serverInfo = { name = 'aineo' },` | `test_mcp_delivery.lua` | survived — this file reads selected fields; the relay file kills it |  |
| N8a | `protocol.lua`: `  return { jsonrpc = '2.0', id = message.id, result = result }` → `  return { id = message.id, result = result }` | `test_mcp_relay.lua` | K: 1 A | A initialize › answers the recorded request with its protocol version, a tools object and the server |
| N8a | `protocol.lua`: `  return { jsonrpc = '2.0', id = message.id, result = result }` → `  return { id = message.id, result = result }` | `test_mcp_delivery.lua` | survived — this file reads selected fields; the relay file kills it |  |
| N8b | `protocol.lua`: `  return { jsonrpc = '2.0', id = id, error = { code = code, message = message } }` → `  return { id = id, error = { code = code, message = message } }` | `test_mcp_relay.lua` | K: 1 A | A a request for another method › is answered with error -32601 |
| N8b | `protocol.lua`: `  return { jsonrpc = '2.0', id = id, error = { code = code, message = message } }` → `  return { id = id, error = { code = code, message = message } }` | `test_mcp_delivery.lua` | survived — this file reads selected fields; the relay file kills it |  |
| N9 | `editor.lua`: `  vim.fn.chanclose(channel) ⏎ ` → (nothing) | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches the editor the relay was given, and renders in its Report |
| N17 | `buffer.lua`: `vim.api.nvim_create_buf(false, true)` → `vim.api.nvim_create_buf(true, true)` | `test_report_buffer.lua` | K: 1 A | A the Report buffer › is named aineo://report, is no file, has no swap file, is kept hidden and unlisted |
| P2 shell log (its inserted line; anchor: the current connect call) | `editor.lua`: `  local connected, channel = ⏎ ` → `  vim.fn.system('echo "' .. (report.details or '') .. '" > /dev/null') ⏎   local connected, channel = ⏎ ` | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches the editor as data: fields holding code render literally and run nothing |
| N10 | `records.lua`: `    error(('aineo cannot keep the report in %s: %s'):format(file, open_failure), 0)` → `    return` | `test_report_buffer.lua` | K: 1 A | A the records › refuse a report they cannot keep, naming the file, and show nothing |
| N11 | `init.lua`: `    report_view.buffer = open_report_buffer(report_view.records_file)` → `    report_view.buffer = buffer.create_report_buffer()` | `test_report_buffer.lua` | K: 2 A | A the Report buffer › comes back with every report after the user deletes it › with the command + args { "bdelete" }; A the Report buffer › comes back with every report after the user deletes it › with the command + args { "bwipeout" } |
| N12 | `server.lua`: `    vim.fn.chansend(stdio, vim.json.encode(answer) .. '\n')` → `    vim.fn.chansend(stdio, 'answer ' .. vim.json.encode(answer) .. '\n')` | `test_mcp_relay.lua` | K: 29 A | A the relay › loads no plugin from the system site directories; A initialize › answers the recorded request with its protocol version, a tools object and the server; … 27 more |
| never recreated (the author's edit; its [bwipeout] case was crash-only) | `init.lua`: `  elseif not buffer.is_showing(report_view.buffer) then` → `  elseif false then` | `test_report_buffer.lua` | K: 5 A | A the Report buffer › comes back with every report after the user deletes it › with the command + args { "bdelete" }; A the Report buffer › comes back with every report after the user deletes it › with the command + args { "bwipeout" }; … 3 more |
| I3 slow start + every chunk a line (the reviewer's sleep, anchored at the current prepend) | `relay.lua`: `vim.opt.runtimepath:prepend(vim.fn.fnamemodify(this_script, ':h:h:h:h'))` → `vim.opt.runtimepath:prepend(vim.fn.fnamemodify(this_script, ':h:h:h:h')) ⏎ vim.uv.sleep(400)`; `lines.lua`: `    for index, piece in ipairs(data) do` → `    for _, whole in ipairs(data) do ⏎       options.on_line(whole) ⏎     end ⏎     for index, piece in ipairs({}) do` | `test_mcp_relay.lua` | K: 6 A (3 of 3 runs) | A a line › written in two parts is answered once, when its newline arrives; A a line › split inside a multibyte character is answered whole; … 4 more |

**The wave plan's M7, M8, M9:**

| Mutant | Literal edit (old → new; ⏎ is a newline) | Run | Result | Killing cases |
|---|---|---|---|---|
| M7 | `protocol.lua`: `      capabilities = { tools = vim.empty_dict() },` → `      capabilities = { tools = {} },` | `test_mcp_relay.lua` | K: 1 A | A initialize › answers the recorded request with its protocol version, a tools object and the server |
| M8 | `format.lua`: `  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" }, ⏎ ` → (nothing) | `test_report.lua` | K: 5 A | A validate_report() › refuses anything else, naming the field › with no report + args { {summary = "Summary",task = "Task"}, "status: expected one of started, progress, blocked, done, failed; A validate_report() › refuses anything else, naming the field › with no report + args { {status = "finished",summary = "Summary",task = "Task"}, "status: expected one of started, progress, b; … 3 more |
| M8 | `format.lua`: `  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" }, ⏎ ` → (nothing) | `test_mcp_relay.lua` | K: 2 A | A tools/list › lists one tool, report, whose input schema is the report format; A tools/call › of a refused report is a tool error naming the field |
| M9 | `records.lua`: `    vim.fn.sha256(working_directory) .. '.jsonl'` → `    'reports.jsonl'` | `test_report_buffer.lua` | K: 1 A | A the records › of another working directory never show |

**The author's table, re-run on this head:**

| Mutant | Literal edit (old → new; ⏎ is a newline) | Run | Result | Killing cases |
|---|---|---|---|---|
| details dropped | `format.lua`: `    details = not is_absent(arguments.details) and arguments.details or nil,` → `    details = nil,` | `test_report.lua` | K: 1 A | A validate_report() › keeps details that are a string |
| null not absent | `format.lua`: `  return value == nil or value == vim.NIL` → `  return value == nil` | `test_report.lua` | K: 2 A | A validate_report() › treats details that are a JSON null as absent; A report_schema() › admits the same details as validate_report() › as a + args { "null", vim.NIL } |
| null not absent | `format.lua`: `  return value == nil or value == vim.NIL` → `  return value == nil` | `test_mcp_delivery.lua` | K: 1 A | A a report › whose details are null renders without details |
| schema says string only (R4) | `format.lua`: `      details = { type = { 'string', 'null' } },` → `      details = { type = 'string' },` | `test_report.lua` | K: 1 A | A report_schema() › admits the same details as validate_report() › as a + args { "null", vim.NIL } |
| unknown field allowed | `format.lua`: `  local unknown = first_unknown_field(arguments)` → `  local unknown = nil` | `test_report.lua` | K: 1 A | A validate_report() › refuses anything else, naming the field › with no report + args { {priority = "high",status = "done",summary = "Summary",task = "Task"}, "priority: not a report field" |
| any status | `format.lua`: `  if not vim.list_contains(M.STATUS_NAMES, arguments.status) then` → `  if arguments.status == nil then` | `test_report.lua` | K: 2 A | A validate_report() › refuses anything else, naming the field › with no report + args { {status = "finished",summary = "Summary",task = "Task"}, "status: expected one of started, progress, b; A validate_report() › refuses anything else, naming the field › with no report + args { {status = "Done",summary = "Summary",task = "Task"}, "status: expected one of started, progress, block |
| environment table unchecked | `init.lua`: `  vim.validate('environment', report_environment, 'table') ⏎ ` → (nothing) | `test_report.lua` | K: 1 A | A set_report_environment() › refuses an environment it cannot use, naming what is wrong › as the environment + args { "an environment", "environment: expected table, got string" } |
| instructions ignore the tool name | `instructions.lua`: `      tool_name ⏎     ),` → `      'mcp__aineo__report' ⏎     ),` | `test_report.lua` | K: 1 A | A report_instructions() › names the tool it is given › as the tool to call + args { "mcp__renamed__report" } |
| environment not required | `init.lua`: `  if not environment then` → `  if false then` | `test_report_buffer.lua` | K: 2 A | A a report › is refused until the report home has its environment; A the Report buffer › is refused until the report home has its environment |
| new buffer every call | `init.lua`: `  if not report_view then ⏎     local records_file` → `  if report_view then ⏎     buffer.discard(report_view.buffer) ⏎   end ⏎   if true then ⏎     local records_file` | `test_report_buffer.lua` | K: 3 A | A the Report buffer › is the same buffer on every use; A the Report buffer › stays the Report when a file is edited from its window while it is empty; A the Report buffer › moves every window showing it to the newest report |
| unnamed buffer | `buffer.lua`: `  vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME) ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 5 A, 4 E | A the Report buffer › is named aineo://report, is no file, has no swap file, is kept hidden and unlisted; A the Report buffer › stays the Report when a file is edited from its window while it is empty; … 7 more |
| name not taken back (A1) | `buffer.lua`: `  free_report_buffer_name() ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 2 A | A the Report buffer › takes its name back from a buffer holding it, and leaks none › after + args { { "lua require('aineo.report').report_buffer()", "bwipeout aineo://report", "edit a; A the Report buffer › takes its name back from a buffer holding it, and leaks none › after + args { { "file aineo://report" } } |
| buffer modifiable | `buffer.lua`: `  vim.bo[buffer].modifiable = false ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 1 A | A the Report buffer › refuses the user an edit, and still takes the next report |
| modifiable left on | `buffer.lua`: `  vim.bo[buffer].modifiable = modifiable` → `  vim.bo[buffer].modifiable = true` | `test_report_buffer.lua` | K: 1 A | A the Report buffer › refuses the user an edit, and still takes the next report |
| reopened counts as showing (A3) | `buffer.lua`: ` and vim.bo[buffer].buftype == 'nofile'` → (nothing) | `test_report_buffer.lua` | K: 3 A | A the Report buffer › comes back with every report after the user deletes it › with the command + args { "bdelete" }; A the Report buffer › deleted then shown again by the user takes no report, and the editor quits › with + args { "buffer #" }; A the Report buffer › deleted then shown again by the user takes no report, and the editor quits › with + args { "buffer aineo://report" } |
| no re-render on :edit (A4) | `buffer.lua`: `      fill(event.buf)` → `      local _ = event` | `test_report_buffer.lua` | K: 2 A | A the Report buffer › keeps every report when the user edits it again › with + args { "edit" }; A the Report buffer › keeps every report when the user edits it again › with + args { "edit!" } |
| windows do not follow | `init.lua`: `  buffer.follow_last_line(report_buffer) ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 1 A | A the Report buffer › moves every window showing it to the newest report |
| editor does not validate | `init.lua`: `  local valid_report, refusal = format.validate_report(arguments)` → `  local valid_report, refusal = arguments, nil` | `test_report_buffer.lua` | K: 2 A | A a report › that is invalid is refused, naming the field, and not rendered; A the records › keep no refused report |
| kept before the Report opens | `init.lua`: `  local report_buffer = M.report_buffer() ⏎   local record = { time = current_environment().clock(), report = valid_report } ⏎   records.append_record(report_view.records_file, record)` → `  local record = { time = current_environment().clock(), report = valid_report } ⏎   records.append_record( ⏎     records.records_file(current_environment().state_directory, current_environment().working_directory), ⏎     record ⏎   ) ⏎   local report_buffer = M.report_buffer()` | `test_report_buffer.lua` | K: 9 A | A a report › renders as its time, status, task and summary; A a report › renders each line of its details below it, indented; … 7 more |
| newline kept | `render.lua`: `  return (text:gsub('\n', ' '))` → `  return text` | `test_report_buffer.lua` | K: 1 A | A a report › renders a newline in its task or summary as a space |
| empty details rendered | `render.lua`: `  if details == nil or details == '' then` → `  if details == nil then` | `test_report_buffer.lua` | K: 1 A | A a report › renders no details line when its details are empty |
| details indented by two | `render.lua`: `local DETAILS_INDENT = (' '):rep(#'HH:MM ')` → `local DETAILS_INDENT = '  '` | `test_report_buffer.lua` | K: 1 A | A a report › renders each line of its details below it, indented |
| records overwritten | `records.lua`: `  write_to(file, 'a', vim.json.encode(record) .. '\n')` → `  write_to(file, 'w', vim.json.encode(record) .. '\n')` | `test_report_buffer.lua` | K: 5 A | A the Report buffer › keeps every report when the user edits it again › with + args { "edit" }; A the Report buffer › keeps every report when the user edits it again › with + args { "edit!" }; … 3 more |
| records 0644 | `records.lua`: `local OWNER_ONLY = tonumber('600', 8)` → `local OWNER_ONLY = tonumber('644', 8)` | `test_report_buffer.lua` | K: 1 A | A the records › are readable and writable by their owner only |
| open failure unchecked | `records.lua`: `  if not descriptor then ⏎     error(('aineo cannot keep the report in %s: %s'):format(file, open_failure), 0) ⏎   end ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 1 A | A the records › refuse a report they cannot keep, naming the file, and show nothing |
| record shape unchecked | `records.lua`: `  if not decoded or type(record) ~= 'table' or not is_record_time(record.time) then` → `  if not decoded then` | `test_report_buffer.lua` | K: 1 A | A the records › that cannot be read are skipped and counted › as a line + args { '{"time":"08:00","report":{"task":"T","status":"done","summary":"S"}}' } |
| whole file read (A5) | `records.lua`: `  for _, line in ipairs(last_lines(file, RECORDS_KEPT_BYTES)) do` → `  for _, line in ipairs(last_lines(file, math.huge)) do` | `test_report_buffer.lua` | K: 2 A | A the records › show the newest 2 MiB of them; A the records › show whole records only, when the newest 2 MiB begin inside one |
| kept part off by one (A5) | `records.lua`: `  local start = math.max(0, size - bytes - 1)` → `  local start = math.max(0, size - bytes)` | `test_report_buffer.lua` | K: 2 A | A the records › show the newest 2 MiB of them; A the records › are cut to their newest 2 MiB once they have grown past 4 MiB |
| never cut back (A5) | `records.lua`: `  if stat and stat.size > 2 * RECORDS_KEPT_BYTES then` → `  if false then` | `test_report_buffer.lua` | K: 1 A | A the records › are cut to their newest 2 MiB once they have grown past 4 MiB |
| skipped records not told | `init.lua`: `  if skipped > 0 then` → `  if false then` | `test_report_buffer.lua` | K: 4 A | A the records › that cannot be read are skipped and counted › as a line + args { "not JSON" }; A the records › that cannot be read are skipped and counted › as a line + args { '{"time":"2026-09-24T08:00:00"}' }; … 2 more |
| unreadable records not told | `init.lua`: `    warn_later(records_or_failure) ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 1 A | A the records › that cannot be read are reported, and the Report opens without them |
| warnings not scheduled (A2) | `init.lua`: `  vim.schedule(function() ⏎     vim.notify(message, vim.log.levels.WARN) ⏎   end)` → `  vim.notify(message, vim.log.levels.WARN)` | `test_mcp_blocked_editor.lua` | K: 1 A (3 of 3 runs) | A a report that opens a Report with a warning › is confirmed before the warning can hold the editor |
| version echoed | `protocol.lua`: `  initialize = function() ⏎     return { ⏎       protocolVersion = PROTOCOL_VERSION,` → `  initialize = function(params) ⏎     return { ⏎       protocolVersion = params.protocolVersion,` | `test_mcp_relay.lua` | K: 1 A | A initialize › answers a protocol version it does not speak with the one it speaks |
| notifications answered | `protocol.lua`: `  if message.id == nil then ⏎     return nil ⏎   end ⏎ ` → (nothing) | `test_mcp_relay.lua` | K: 1 A | A a notification › gets no answer |
| null id echoed | `protocol.lua`: `  if message.id == vim.NIL then` → `  if false then` | `test_mcp_relay.lua` | K: 1 A | A a request › whose id is null is refused with error -32600 and no id |
| ping result an array | `protocol.lua`: `    return vim.empty_dict() ⏎   end, ⏎   ['tools/list']` → `    return {} ⏎   end, ⏎   ['tools/list']` | `test_mcp_relay.lua` | K: 1 A | A ping › is answered with an empty object |
| -32601 as -32600 | `protocol.lua`: `local METHOD_NOT_FOUND = -32601` → `local METHOD_NOT_FOUND = -32600` | `test_mcp_relay.lua` | K: 1 A | A a request for another method › is answered with error -32601 |
| any tool is report | `protocol.lua`: `  if params.name ~= names.REPORT_TOOL then` → `  if false then` | `test_mcp_relay.lua` | K: 3 A | A tools/call › of another tool is answered with error -32602; A tools/call › whose params are no object names no tool, and is answered with error -32602 › as + args { "42" }; A tools/call › whose params are no object names no tool, and is answered with error -32602 › as + args { "null" } |
| refusal as RPC error | `protocol.lua`: `    return tool_result('aineo refused the report: ' .. refusal, true)` → `    return nil, { code = INVALID_PARAMS, message = refusal }` | `test_mcp_relay.lua` | K: 1 A | A tools/call › of a refused report is a tool error naming the field |
| parse error with an id | `protocol.lua`: `    return error_response(nil, PARSE_ERROR, 'Parse error: the message is not JSON')` → `    return error_response(0, PARSE_ERROR, 'Parse error: the message is not JSON')` | `test_mcp_relay.lua` | K: 1 A | A a line › that is not JSON is answered with error -32700 and no id, and the relay keeps serving |
| array taken as object | `protocol.lua`: `  if type(message) ~= 'table' or vim.islist(message) then` → `  if type(message) ~= 'table' then` | `test_mcp_relay.lua` | K: 1 A | A a line › that is JSON but no object is answered with error -32600 and no id › as + args { "[1,2]" } |
| params unguarded | `protocol.lua`: `  local params = type(message.params) == 'table' and message.params or {}` → `  local params = message.params` | `test_mcp_relay.lua` | K: 2 A | A tools/call › whose params are no object names no tool, and is answered with error -32602 › as + args { "42" }; A tools/call › whose params are no object names no tool, and is answered with error -32602 › as + args { "null" } |
| id echoed as a string | `protocol.lua`: `  return { jsonrpc = '2.0', id = message.id, result = result }` → `  return { jsonrpc = '2.0', id = tostring(message.id), result = result }` | `test_mcp_relay.lua` | K: 20 A | A the relay › loads no plugin from the system site directories; A initialize › answers the recorded request with its protocol version, a tools object and the server; … 18 more |
| every chunk a line | `lines.lua`: `    for index, piece in ipairs(data) do` → `    for _, whole in ipairs(data) do ⏎       options.on_line(whole) ⏎     end ⏎     for index, piece in ipairs({}) do` | `test_mcp_relay.lua` | K: 6 A | A a line › written in two parts is answered once, when its newline arrives; A a line › split inside a multibyte character is answered whole; … 4 more |
| limit >= | `lines.lua`: `      if #partial > options.limit then` → `      if #partial >= options.limit then` | `test_mcp_relay.lua` | K: 1 A | A a line › of exactly 1 MiB is read and answered |
| tail kept while dropping | `lines.lua`: `      if not dropping then ⏎         partial = partial .. piece ⏎       end` → `      partial = partial .. piece` | `test_mcp_relay.lua` | K: 2 A | A a line › longer than 1 MiB is dropped up to its newline, and the next message answered; A a line › three times 1 MiB long is refused once, its rest not kept |
| limit doubled | `server.lua`: `local LINE_LIMIT = 1024 * 1024` → `local LINE_LIMIT = 2 * 1024 * 1024` | `test_mcp_relay.lua` | K: 2 A | A a line › longer than 1 MiB is refused with error -32600 and no id, before its newline arrives; A a line › longer than 1 MiB is dropped up to its newline, and the next message answered |
| empty line answered | `server.lua`: `local answer = line ~= '' and protocol.answer_line(line, deliver_report)` → `local answer = protocol.answer_line(line, deliver_report)` | `test_mcp_relay.lua` | K: 3 A | A a line › that is empty gets no answer; A a line › longer than 1 MiB is dropped up to its newline, and the next message answered; A a line › three times 1 MiB long is refused once, its rest not kept |
| close never noticed | `server.lua`: `        closed = true ⏎ ` → (nothing) | `test_mcp_relay.lua` | K: 1 A | A the relay › exits 0 when its input closes |
| answers unguarded (A7) | `server.lua`: `  local answered, failure = pcall(answer)` → `  local answered, failure = true, answer()` | `test_mcp_relay.lua` | K: 1 A | A a request › whose answer cannot be written does not take the next one down |
| failure not written to stderr (A7) | `server.lua`: `    vim.uv.fs_write(STDERR, ('aineo relay: %s\n'):format(tostring(failure)))` → `    local _ = failure` | `test_mcp_relay.lua` | K: 1 A | A a request › whose answer cannot be written does not take the next one down |
| delivery result ignored | `protocol.lua`: `  local outcome, explanation = deliver_report(valid_report)` → `  local outcome, explanation = 'delivered', deliver_report(valid_report)` | `test_mcp_delivery.lua` | K: 4 A | A a report › for an editor that is gone is a tool error saying so, and the relay keeps serving; A a report › that the editor does not take is a tool error with the reason it gave; … 2 more |
| no-address guard removed | `editor.lua`: `  if address == nil then ⏎     return 'failed', 'aineo has no editor address to deliver the report to' ⏎   end ⏎ ` → (nothing) | `test_mcp_delivery.lua` | K: 2 A | A a report › with no editor address is a tool error saying so, and the relay keeps serving › in the environment + args { {} }; A a report › with no editor address is a tool error saying so, and the relay keeps serving › in the environment + args { {AINEO_EDITOR_ADDRESS = ""} } |
| traceback kept | `editor.lua`: `first_line(tostring(failure[2]))` → `tostring(failure[2])` | `test_mcp_delivery.lua` | K: 1 A | A a report › that the editor does not take is a tool error with the reason it gave |
| report sent as code | `editor.lua`: `{ RECEIVE_REPORT, { report } }` → `{ ("require('aineo.report').receive_report({ task = '%s', status = '%s', summary = '%s', details = [[%s]] })"):format(report.task, report.status, report.summary, report.details or ''), {} }` | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches the editor as data: fields holding code render literally and run nothing |
| TCP dialled as a pipe (A8) | `editor.lua`: `  return address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'` → `  return 'pipe'` | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches an editor listening on a TCP address |
| wait unbounded (A2) | `editor.lua`: `local CONFIRMATION_TIMEOUT_MS = 5000` → `local CONFIRMATION_TIMEOUT_MS = 600000` | `test_mcp_blocked_editor.lua` | K: 1 A (3 of 3 runs) | A a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done |
| close ignored while waiting (A2) | `editor.lua`: `    return call.response ~= nil or call.closed` → `    return call.response ~= nil` | `test_mcp_blocked_editor.lua` | K: 1 A (3 of 3 runs) | A a report for an editor at a hit-enter prompt › is a tool error at once when the editor dies before it answers |
| relay serves when required | `relay.lua`: `if script_run ~= this_script then ⏎   return ⏎ end ⏎ ` → (nothing) | `test_mcp_delivery.lua` | K: 1 A | A the relay script › loaded inside an editor serves nothing |
| relay not on runtimepath | `relay.lua`: `vim.opt.runtimepath:prepend(vim.fn.fnamemodify(this_script, ':h:h:h:h'))` → `local _ = this_script` | `test_mcp_delivery.lua` | K: 10 A | A the server entry › started as Claude Code starts it, completes the recorded handshake and relays a report; A a report › reaches the editor the relay was given, and renders in its Report; … 8 more |
| system plugins load (A6) | `init.lua`: `'--cmd', 'set noloadplugins', ` → (nothing) | `test_mcp_relay.lua` | K: 1 A | A the relay › loads no plugin from the system site directories |
| entry without --clean | `init.lua`: `'--headless', '--clean', ` → `'--headless', ` | `test_mcp.lua` | K: 1 A | A mcp_servers() › describes the report server the way Claude Code starts a stdio server |
| another tool allowed | `init.lua`: `  return { M.report_tool_name() }` → `  return { M.report_tool_name(), 'Bash' }` | `test_mcp.lua` | K: 1 A | A allowed_mcp_tools() › pre-allows the report tool and nothing else |
| address unchecked | `init.lua`: `  vim.validate('editor_address', editor_address, 'string') ⏎ ` → (nothing) | `test_mcp.lua` | K: 1 A | A mcp_servers() › refuses an address or a program that is not a string, naming it › given + args { 42, "/opt/nvim/bin/nvim", "editor_address: expected string, got number" } |
| tool name misspelt | `init.lua`: `  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.REPORT_TOOL)` → `  return ('mcp__%s_%s'):format(names.SERVER_NAME, names.REPORT_TOOL)` | `test_mcp.lua` | K: 2 A | A report_tool_name() › is the name Claude Code gives the report tool of the aineo server; A allowed_mcp_tools() › pre-allows the report tool and nothing else |

**The handover's rows: code the round wrote that no row above reached:**

| Mutant | Literal edit (old → new; ⏎ is a newline) | Run | Result | Killing cases |
|---|---|---|---|---|
| EOF not noted | `editor.lua`: `      call.closed = true ⏎       return ⏎ ` → `      return ⏎ ` | `test_mcp_blocked_editor.lua` | K: 1 A (3 of 3 runs) | A a report for an editor at a hit-enter prompt › is a tool error at once when the editor dies before it answers |
| any message taken for the answer | `editor.lua`: `      if message[1] == RESPONSE then` → `      if true then` | `test_mcp_delivery.lua` | K: 1 A (3 of 3 runs) | A a report › is confirmed by an editor that writes a notification before its answer |
| unconfirmed as an error | `protocol.lua`: `  return tool_result(explanation, outcome == 'failed')` → `  return tool_result(explanation, true)` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done |
| partial first line kept | `records.lua`: `  if start > 0 then ⏎     table.remove(lines, 1) ⏎   end ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 2 A | A the records › show whole records only, when the newest 2 MiB begin inside one; A the records › are cut to their newest 2 MiB once they have grown past 4 MiB |
| first line dropped only when empty | `records.lua`: `  if start > 0 then ⏎     table.remove(lines, 1)` → `  if start > 0 and lines[1] == '' then ⏎     table.remove(lines, 1)` | `test_report_buffer.lua` | K: 1 A | A the records › show whole records only, when the newest 2 MiB begin inside one |
| trailing empty line kept | `records.lua`: `  if lines[#lines] == '' then ⏎     table.remove(lines) ⏎   end ⏎ ` → (nothing) | `test_report_buffer.lua` | K: 6 A | A the records › show whole records only, when the newest 2 MiB begin inside one; A the records › are cut to their newest 2 MiB once they have grown past 4 MiB; … 4 more |
| cut past 2 MiB, not 4 | `records.lua`: `  if stat and stat.size > 2 * RECORDS_KEPT_BYTES then` → `  if stat and stat.size > RECORDS_KEPT_BYTES then` | `test_report_buffer.lua` | K: 1 A | A the records › are kept whole up to 4 MiB when a report is added |
| cut at 4 MiB exactly | `records.lua`: `  if stat and stat.size > 2 * RECORDS_KEPT_BYTES then` → `  if stat and stat.size >= 2 * RECORDS_KEPT_BYTES then` | `test_report_buffer.lua` | K: 1 A | A the records › are kept whole up to 4 MiB when a report is added |
| rename failure unchecked | `records.lua`: `  if not renamed then ⏎     error(('aineo cannot keep the report in %s: %s'):format(file, rename_failure), 0) ⏎   end ⏎ ` → (nothing) | `test_report_buffer.lua` | survived |  |

**88 literal edits in 106 runs: some edits ran on two files, and the timing-sensitive ones three times. 87 of the 88 edits were killed by assertion; the one survivor is "rename failure unchecked". 101 of the 106 runs were killed, none by a crash only, and 5 runs survived. Every file was restored and checked after each run.**

One killed run also has cases that fail by crash: "unnamed buffer" fails 5 cases by assertion and 4 by crash. The crashes are the tests' own commands, which find no buffer of the name: `:edit` (E32), `:bwipeout aineo://report` and `:buffer aineo://report` (E94).

Of the 5 surviving runs, four are N2a, N2c, N8a and N8b on `test_mcp_delivery.lua`, a second file that reads selected fields and was not expected to kill them; `test_mcp_relay.lua` kills each. The fifth is "rename failure unchecked", the one edit no file kills; it is under *Limits*.

**Two survivors were removed from the code rather than kept**, beside the author's two (the Report's loaded check and the relay's answer queue; the loaded check was not equivalent, and the correction restored it):

- the answer reader's id check, since a connection carries one request;
- the Report group's `clear = false`, whose stated reason could not arise.

**Not mutated: `serve_stdio`'s poll interval, changed from 50 to 10 ms with the bounded wait.** It only sets how quickly the relay notices that stdin has closed, and no test can see it.

### Limits recorded in the fix round

- **A2, what the bound leaves.**
  - While a delivery waits, the relay answers nothing else: later lines, pings included, wait their turn.
  - A report to an editor held by the user costs up to 5 s, and reports sent meanwhile queue behind it, 5 s each.
  - Claude Code's own timeouts are the attack reviewer's reading of its docs, not a measurement.
- **A deleted Report shown again before the next report is an ordinary buffer the user can edit.** Measured in the handover. The next report wipes it out and creates a new Report. An edit the user makes there leaves a modified buffer, which `:qall` refuses (E37). **Corrected by the correction:** that held only until a report came; the next report then discarded the edit without a prompt (finding 3), and now keeps it, unnamed.
- **The cut's rename failure is unpinned.** No portable test makes `fs_rename` fail once the kept records have been read and written beside the file. Its mutant survives, and the branch stays, since clean-code forbids swallowing the error. (Since the correction a failed cut is a warning, the report kept; the re-anchored mutant still survives.)
- **A record longer than 2 MiB is shown when it arrives, but never in a later editor, and a cut drops it.** A report under the 1 MiB line limit can grow that far only when made mostly of raw DEL characters, which the records write six bytes each (measured). **Corrected by the correction:** also raw control characters, from a client that does not escape them (finding 9).
- **Trimming races other editors.** Two editors appending to one records file while one of them trims it can lose a record written between the trim's read and its rename. This is reasoned from the code, not measured. **Corrected by the correction:** the re-measure measured it, refused reports as well as lost records (finding 5); see *Correction › Limits*.
- **`serverInfo.version` is `0.0.0`**, since aineo has no release version.
- **Two JSON-RPC edges remain** (A10): a client response is answered −32601, and an object id is echoed. Claude Code sends neither.

## Correction (2026-09-24)

The re-measure of the fix round, at `1a67263`, found eleven things (findings 1–11 of the re-measure report, cited here by number). The orchestrator sent a fresh agent for one bounded correction, scoped to what the re-measure refuted or found missing; the fix round's other decisions stand. Everything the re-measure found holding stays as it was. The state measured below is the correction's last code commit, `17e034f` (the records commit after it changes this note only).

**What the correction changed, in commit order** (each seen red first; the tests are named under *Red and green in the correction*):

1. **The 5 s bound is pinned by time** (finding 7): the hit-enter test takes its two answers within 6 s. The reviewer's pin.
2. **The Report's loaded check is back** (finding 1): `:bunload` kept `'buftype'` `nofile`, so an unloaded Report counted as showing, and the next report showed twice. The fix round's claim that the check was redundant (its commit "Drop the Report's loaded check that no test could ask for", and item 1.6 of *What the round changed*) was wrong: the survivor was not equivalent, the suite never unloaded the Report. The reviewer's fix and pin.
3. **A records path that opens but cannot be read** (a directory) raises the named error the docstrings promise (finding 4). The reviewer's fix and pin.
4. **Text the user typed into a buffer holding the Report's name is kept** (finding 3). Such a buffer, when modified, gives up the name (`:0file`) and keeps its text; any other is wiped out as before. The reviewer's design (as `let_go`), renamed `free_name_held_by()`.
5. **The relay reads the editor's answer byte for byte** (finding 2), through a `vim.uv` pipe or TCP handle, where `sockconnect()`'s `on_data` had handed a zero byte over as a newline. A host name is resolved and its first address dialled.
6. **The user is told of a report the editor cannot keep, and the tool result promises no showing** (finding 6). `receive_report()` warns the user once (scheduled) whenever it fails, and still raises. The unconfirmed answer now reads "… The report is sent, not confirmed; do not send it again."
7. **A records file that cannot be cut back no longer refuses the report** (finding 8, and the refusal half of finding 5): the record is appended, the user is warned once for that report, and the next report tries the cut again.
8. **A symlinked records file is cut behind its link** (finding 8): the cut resolves the path and replaces the file the link leads to; the link stays. Chosen over leaving it uncut with a warning.
9. **Each editor cuts through its own temporary file**, `<file>.<pid>.cut` (finding 5). The reviewer's fix, measured by their probe.
10. **A records directory another editor made at the same moment is taken** (finding 10), and a directory that cannot be made is named in the error. The first version took a failed `mkdir()` as success only when the records directory existed afterwards; re-running the re-measure's race probe on it still refused one report, lost on a directory higher up the path. `mkdir()` is now retried, at most once for each directory on the path, and a third case pins that bound.
11. **The records** (findings 9 and 11, and the corrections this section lists), in this note and the pull request body.

**Result at `17e034f`:**

- `make test`: **258 cases, `Fails (0) and Notes (0)`, exit 0.** Per T5 file: `test_report.lua` 42, `test_report_buffer.lua` 49, `test_mcp.lua` 5, `test_mcp_relay.lua` 30, `test_mcp_delivery.lua` 18, `test_mcp_blocked_editor.lua` 3 — 147 in all; the other files hold 111.
- `make lint`: StyLua `--check` clean; selene 0 errors, 0 warnings.
- The deep-`require` check prints the same 14 lines as before, each a file of a home requiring a file of that same home.

### Findings of the re-measure

| Finding | Outcome |
|---|---|
| 1 `:bunload` shows the next report twice | **Fixed** (the reviewer's patch): `is_showing` checks `nvim_buf_is_loaded` again. Pinned by the `bunload` case of *comes back with every report after the user deletes it*. The fix round's reasoning is corrected above and in the commit that restores the check. |
| 2 the answer reader is not binary-safe | **Fixed**: `vim.uv` handles, whose `read_start()` chunks are the bytes as they came. Pinned with editor refusals of 255, 256, 300, 512 and 513 bytes, each reaching Claude as the refusal within 2 s. |
| 3 typed text discarded without a prompt | **Fixed** (the reviewer's design): kept, unnamed. Pinned with the reviewer's two cases, one per path (`bwipeout` then `:edit aineo://report`; `enew \| bdelete \| buffer aineo://report`). |
| 4 a directory at the records path raises a raw error | **Fixed** (the reviewer's patch and pin). |
| 5 the trim race | **Refusals fixed** (a failed cut no longer refuses, item 7, and the cut file is per process, item 9), pinned by a deterministic interleaving of two editors. **Losses recorded as a limit** with the reviewer's measurement. |
| 6 an unconfirmed report that later fails is dropped silently | **Fixed**: the editor tells the user, once; the tool result says "sent, not confirmed". The *Readings* are corrected below. |
| 7 the 5 s value unpinned | **Fixed** (the reviewer's pin): W9 dies by assertion, 2 of 2. |
| 8 a read-only directory refuses every report past 4 MiB; a symlink becomes a file | **Fixed**, both, each pinned. |
| 9 two recorded figures | **Corrected**: the worst case measured is the reviewer's 1 040 004 lines in 156 ms (RSS 104 MB), not 520004 lines; and a record grows past 2 MiB with raw control characters from a non-conforming client, not only with DEL. |
| 10 E739 when two editors make the records directory at once (pre-existing) | **Fixed**, in more than the brief's line or two: a race lost on any directory of the path is retried, at most once per directory; a directory that cannot be made is named. Pinned by the race's outcome, fixed in a test by a stub of `vim.fn.mkdir` that loses one or two races: at the records directory, at its parent, and at the parent and then the directory. The race probe then refused nothing in 4 of 4 runs. |
| 11 informational | **Recorded** under *Limits recorded in the correction*: the user's `:doautocmd BufReadCmd` in the Report, and `:file` / `:saveas` in it. The non-Neovim peers were re-measured against the new reader (below). |
| Test-integrity: the notifying-editor test hangs against the old mechanism | **Fixed**: the stand-in editors answer requests only. The hang was a ping-pong (measured below). The test now ends against `70ed857`'s code, and passes there, as `vim.rpcrequest` does confirm that report; against "any message taken for the answer" it fails by assertion, 2 of 2. |
| Test-integrity: W9, F0, D0, R0 | **W9 killed.** **F0**'s literal edit no longer applies: its site now calls `free_name_held_by()`, and the edit that replaces that call with the old wipe dies by assertion. **D0**'s literal edit now lands inside `free_name_held_by()`, where it **survives, equivalent**: only a buffer whose text is unchanged reaches that `nvim_buf_delete`, and for such a buffer `force` changes nothing (reasoned; a terminal buffer whose job still runs, named `aineo://report` by the user, is the one case not measured). The edit that replaces the Report's discard with the old wipe dies by assertion. **R0 survives, equivalent**: the new read check raises before `vim.split` whenever `data` is nil, so `data or ''` never takes its right side; the edit that removes that check dies by assertion. |

### Measured in the correction (Nvim 0.11.6, on this Mac)

- **`sockconnect()`'s zero byte, and the new reader.** Through the relay, a stand-in editor's refusal whose text holds a zero byte reached Claude as that text, zero byte included, in 18 ms; a 256-byte refusal in 20 ms (probe `t5c-p2-peers.lua`, run on the reader as committed in `39ea0aa`).
- **A host name.** `serverstart('localhost:0')` listens on `::1` only — the first of `::1` and `127.0.0.1` that `getaddrinfo` gives — and `sockconnect()` reaches it. The new relay, given `localhost:<port>`, dials the first resolved address and delivered in 22 ms.
- **TCP addresses that cannot be dialled.** `getaddrinfo('127.0.0.1', '99999')` fails; `tcp:connect('127.0.0.1', 0)` fails at once (`EADDRNOTAVAIL`); a closed port fails through the callback (`ECONNREFUSED`); a missing socket path too (`ENOENT`). At `1a67263`, the address `127.0.0.1:0` got no answer from the relay within 2 s.
- **The old stand-in's hang.** Against `70ed857`'s relay (`vim.rpcrequest`), a stand-in that answered every message it decoded received 200 messages in 3 s — the request (`0 1`), then `2 nvim_error_event` over and over: the relay answers an unknown notification with an error event, and the stand-in answered that with another notification. Uncapped, the probe's own Neovim never returned from a 3 s `vim.wait` and was killed at 40 s.
- **Non-Neovim peers against the new reader** (finding 11's table, re-run): a response followed by garbage is delivered, now without a traceback, since the reader stops at the response; the byte `0xc1` and the msgpack integer `5` give "not confirmed" at 5.2 s, with the unpacker's error on stderr; `[1]` gets no answer, with `attempt to index local 'failure'` on stderr. In every case the next ping was answered. Neovim writes none of these.
- **The late failure, end to end** (finding 6; probe `t5c-p5-late.lua`, with the re-measure's probe library, on a copy of `17e034f`'s code): a TUI editor whose records path is a directory, held at a hit-enter prompt, got a report. The relay answered at 5147 ms: "aineo sent the report, but the editor did not confirm it within 5 s: … The report is sent, not confirmed; do not send it again." After Enter, the editor ran the request, and `:messages` held the Report's own warning (its records cannot be read, `EISDIR`) and, once, "aineo cannot keep the report in <file>: EISDIR …". Three Enters were needed: the original prompt and one for each warning.
- **The two-editor race, re-run** (the re-measure's probe `remeasure10-p23-race.lua`, 5000 reports of 4000 bytes per editor, from a new state directory, on copies of the code): on `faf16db` (the first mkdir fix), 1 report refused by E739 on `.remeasure10`, the probe's state root, and 1 record lost; on a version with the retry that still checked `isdirectory`, 4 runs: 0 refused, 0, 0, 12 and 1 lost; on `17e034f`, 4 runs: 0 refused, 0 lost. No run left a `.cut` file or an undecodable line.
- **Each new test against `1a67263`'s production code**, with the final tests (the copy tree `t5c-oldcode`): every test listed as seen red below fails there by assertion.

### Readings for the MVP review (corrected by the correction)

- **A report not confirmed within 5 s** is answered "sent, not confirmed", and Claude is told not to send it again. It is not an error. The editor runs the request when the user is done; if it cannot keep the report then, it tells the user, once. Nothing is promised to Claude about the report showing. (The fix round's reading said "the report shows when the user is done", which was true only when keeping it succeeded.)
- **A buffer holding the Report's name** gives it up when a Report is made: wiped out, or, when the user changed its text, kept unnamed.
- **A records file that cannot be cut back** is appended to all the same, and the user is warned with each report until the cut succeeds; the Report still reads only its newest 2 MiB.

### Red and green in the correction

10 new tests, 19 new cases: the suite went from 239 to 258 cases.

**Seen red (every test the correction added or changed, except those under *Arrived green*).** Each was run against `1a67263`'s production code with the final tests, and failed there by assertion:

- *comes back with every report after the user deletes it* [`bunload`] — `{ …, "09:06 [done] First — Ended", "09:06 [done] First — Ended" }`, the last report twice.
- *never discards text the user typed into a buffer holding its name* (2 cases) — `{ vim.NIL, {} }` where `{ vim.NIL, { "my own notes" } }` was expected.
- *the records that are no file are reported, naming the file, and the Report opens without them* — `false` where `true` was expected.
- *a report that the editor refuses is a tool error with the reason, at once, whatever its length* [256] and [512] — no answer within 2 s.
- *a report for a TCP address that cannot be dialled is a tool error saying so* [`127.0.0.1:0`] — no answer within 2 s at `1a67263`; also red against this correction's first version of the reader, which passed the resolved entry's missing port to `connect()`.
- *a report for an editor at a hit-enter prompt is answered in time…* (changed: the wording) — the "will show" text.
- *the records that cannot keep a report tell the user why, once* — `:messages` empty.
- *the records that cannot be cut keep the report, and tell the user why* — the report refused with `… .cut: EACCES`.
- *the records kept through a symbolic link are cut behind it, and the link stays* — `{ "file", 4097, "Task 4097" }`.
- *the records cut by another editor while this one cuts them are still cut, without a warning* — the report refused with `ENOENT` at `1a67263`; on the code just before the per-process name, the cut's `ENOENT` warning.
- *the records keep a report when another editor makes their directory at the same moment* [0], [1] and [1, 0] — the `E739` refusal at `1a67263`; [1] was also red on `faf16db` (the named E739 refusal), the correction's first fix, which the race probe had shown incomplete.
- *the records whose directory cannot be made refuse a report, naming the directory* — `false` where `true` was expected (the raw Vim message).
- The hit-enter test's 6 s window (changed) — green on unchanged code; red on W9 by assertion (`left = nil, right = 2` at key 3).

**Arrived green:**

- the refusal lengths 255, 300 and 513 — green by nature at `1a67263` too: their answers hold one zero byte, the error type, which the old reader read as 10 and still decoded. Killer: "NUL read as newline" fails 256 and 512 only, by assertion;
- *a report for a TCP address that cannot be dialled* [`127.0.0.1:99999`] — its guard was written with the reader, ahead of the test; green at `1a67263` as well. Killer: "resolution unchecked", by assertion;
- *a report is confirmed by an editor that writes a notification before its answer* (its stand-in changed to answer requests only) — killer "any message taken for the answer", by assertion, 2 of 2;
- *the records keep a report when another editor makes their directory at the same moment* [1, 0] — red at `1a67263`, but green where it was added: the bound was written with the retry, one commit earlier. Killer: "one retry only", by assertion.

### Mutants on the correction's last code commit

Head `17e034f`. Every edit literal (the exact strings are in `t5c-mutants.json`; the table trims leading spaces), applied from the committed file, run, restored and the restore checked (`t5c-mutate.py`, a copy of the re-measure's runner). K = killed, A = by assertion, E = by crash. The rows named for the re-measure's survivors come first; then one or more per numbered item that changed code; then the fix round's rows on code this correction touched, re-anchored where the old text is gone. The fix round's rows on files the correction did not touch stand as measured on `d01bea8`.

| Mutant | Literal edit (old → new; ⏎ is a newline) | Run | Result | Killing cases |
|---|---|---|---|---|
| W9 (the re-measure's) | `editor.lua`: `vim.wait(CONFIRMATION_TIMEOUT_MS, function()` → `vim.wait(9000, function()` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done |
| W9 (the re-measure's) | `editor.lua`: `vim.wait(CONFIRMATION_TIMEOUT_MS, function()` → `vim.wait(9000, function()` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done |
| F0 (the re-measure's) | `buffer.lua`: `nvim_buf_delete(other, { force = true })` → `nvim_buf_delete(other, { force = false })` | — | not applied: the text no longer occurs | |
| D0 (the re-measure's) | `buffer.lua`: `nvim_buf_delete(buffer, { force = true })` → `nvim_buf_delete(buffer, { force = false })` | `test_report_buffer.lua` | survived |  |
| R0 (the re-measure's) | `records.lua`: `vim.split(data, '\n', { plain = true })` → `vim.split(data or '', '\n', { plain = true })` | `test_report_buffer.lua` | survived |  |
| M7 | `protocol.lua`: `capabilities = { tools = vim.empty_dict() },` → `capabilities = { tools = {} },` | `test_mcp_relay.lua` | K: 1 A | A initialize › answers the recorded request with its protocol version, a tools object and the server |
| M8 | `format.lua`: `{ name = 'blocked', moment = "when you cannot go on without the user's answer or action" }, ⏎` → `(nothing)` | `test_report.lua` | K: 5 A | A the three status refusals of `validate_report()`; A accepts each status of the format [blocked]; A tells when to report each status of the format [blocked] |
| M8 | `format.lua`: `{ name = 'blocked', moment = "when you cannot go on without the user's answer or action" }, ⏎` → `(nothing)` | `test_mcp_relay.lua` | K: 2 A | A tools/list › lists one tool, report, whose input schema is the report format; A tools/call › of a refused report is a tool error naming the field |
| M9 | `records.lua`: `vim.fn.sha256(working_directory) .. '.jsonl'` → `'reports.jsonl'` | `test_report_buffer.lua` | K: 2 A | A the records › that are no file are reported, naming the file, and the Report opens without them; A the records › of another working directory never show |
| 1 loaded check removed again | `buffer.lua`: `and vim.api.nvim_buf_is_loaded(buffer) ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 1 A | A the Report buffer › comes back with every report after the user deletes it › with the command + args { "bunload" } |
| 2 NUL read as newline | `editor.lua`: `local position = 1 ⏎` → `chunk = chunk:gsub('%z', '\n') ⏎     local position = 1 ⏎` | `test_mcp_delivery.lua` | K: 2 A | A a report › that the editor refuses is a tool error with the reason, at once, whatever its length › of + args { 256 }; A a report › that the editor refuses is a tool error with the reason, at once, whatever its length › of + args { 512 } |
| 2 TCP dialled as a pipe | `editor.lua`: `local host, port = address:match('^([^/]+):(%d+)$')` → `local host, port = nil, nil` | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches an editor listening on a TCP address |
| 2 resolution unchecked | `editor.lua`: `if not resolved then ⏎     return nil, resolve_failure ⏎   end ⏎` → `(nothing)` | `test_mcp_delivery.lua` | K: 1 A | A a report › for a TCP address that cannot be dialled is a tool error saying so › such as + args { "127.0.0.1:99999" } |
| 2 port from the resolution | `editor.lua`: `tcp:connect(resolved[1].addr, tonumber(port), on_connect)` → `tcp:connect(resolved[1].addr, resolved[1].port, on_connect)` | `test_mcp_delivery.lua` | K: 1 A | A a report › for a TCP address that cannot be dialled is a tool error saying so › such as + args { "127.0.0.1:0" } |
| 2 connect start failure ignored | `editor.lua`: `if not started then ⏎     close(connection) ⏎     return nil, failure ⏎   end ⏎` → `(nothing)` | `test_mcp_delivery.lua` | K: 1 A | A a report › for a TCP address that cannot be dialled is a tool error saying so › such as + args { "127.0.0.1:0" } |
| 2 connect failure not noted | `editor.lua`: `call.unreachable = connect_failure ⏎` → `(nothing)` | `test_mcp_delivery.lua` | K: 1 A | A a report › for an editor that is gone is a tool error saying so, and the relay keeps serving |
| 2 connection kept after the answer (N9 re-anchored) | `editor.lua`: `call.response = message ⏎         close(connection) ⏎` → `call.response = message ⏎` | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches the editor the relay was given, and renders in its Report |
| 2 any message taken for the answer (and item 11) | `editor.lua`: `if message[1] == RESPONSE then` → `if true then` | `test_mcp_delivery.lua` | K: 1 A | A a report › is confirmed by an editor that writes a notification before its answer |
| 2 any message taken for the answer (and item 11) | `editor.lua`: `if message[1] == RESPONSE then` → `if true then` | `test_mcp_delivery.lua` | K: 1 A | A a report › is confirmed by an editor that writes a notification before its answer |
| 2 report through a shell (P2 re-anchored) | `editor.lua`: `local call = { closed = false } ⏎` → `vim.fn.system('echo "' .. (report.details or '') .. '" > /dev/null') ⏎   local call = { closed = false } ⏎` | `test_mcp_delivery.lua` | K: 1 A | A a report › reaches the editor as data: fields holding code render literally and run nothing |
| 2 close ignored while waiting (re-anchored) | `editor.lua`: `return call.unreachable ~= nil or call.response ~= nil or call.closed ⏎` → `return call.unreachable ~= nil or call.response ~= nil ⏎` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is a tool error at once when the editor dies before it answers |
| 2 close ignored while waiting (re-anchored) | `editor.lua`: `return call.unreachable ~= nil or call.response ~= nil or call.closed ⏎` → `return call.unreachable ~= nil or call.response ~= nil ⏎` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is a tool error at once when the editor dies before it answers |
| 2 EOF not noted (re-anchored) | `editor.lua`: `call.closed = true ⏎       close(connection) ⏎       return ⏎` → `close(connection) ⏎       return ⏎` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is a tool error at once when the editor dies before it answers |
| 2 EOF not noted (re-anchored) | `editor.lua`: `call.closed = true ⏎       close(connection) ⏎       return ⏎` → `close(connection) ⏎       return ⏎` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is a tool error at once when the editor dies before it answers |
| 3 typed text wiped again | `buffer.lua`: `if vim.bo[buffer].modified then` → `if false then` | `test_report_buffer.lua` | K: 2 A | A the Report buffer › never discards text the user typed into a buffer holding its name › after + args { "bwipeout %d \| edit aineo://report" }; A the Report buffer › never discards text the user typed into a buffer holding its name › after + args { "enew \| bdelete %d \| buffer aineo://report" } |
| 3 name freed by a wipe (F0 site) | `buffer.lua`: `free_name_held_by(other)` → `vim.api.nvim_buf_delete(other, { force = true })` | `test_report_buffer.lua` | K: 1 A | A the Report buffer › never discards text the user typed into a buffer holding its name › after + args { "bwipeout %d \| edit aineo://report" } |
| 3 Report discarded by a wipe (D0 site) | `buffer.lua`: `free_name_held_by(buffer)` → `vim.api.nvim_buf_delete(buffer, { force = true })` | `test_report_buffer.lua` | K: 1 A | A the Report buffer › never discards text the user typed into a buffer holding its name › after + args { "enew \| bdelete %d \| buffer aineo://report" } |
| 4 read check removed | `records.lua`: `if not data then ⏎     error(('aineo cannot read the report records in %s: %s'):format(file, read_failure), 0) ⏎   end ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 1 A | A the records › that are no file are reported, naming the file, and the Report opens without them |
| 5 shared cut name | `records.lua`: `local cut = ('%s.%d.cut'):format(target, vim.uv.os_getpid())` → `local cut = target .. '.cut'` | `test_report_buffer.lua` | K: 1 A | A the records › cut by another editor while this one cuts them are still cut, without a warning |
| 6 user not told | `init.lua`: `warn_later(failure) ⏎     error(failure, 0)` → `error(failure, 0)` | `test_report_buffer.lua` | K: 1 A | A the records › that cannot keep a report tell the user why, once |
| 6 will-show wording back | `editor.lua`: `' The report is sent, not confirmed; do not send it again.'` → `' The report will show when the editor is free; do not send it again.'` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done |
| 8 cut failure refuses | `records.lua`: `local cut, failure = pcall(keep_newest_records, file) ⏎     if not cut then ⏎       return failure ⏎     end ⏎` → `keep_newest_records(file) ⏎` | `test_report_buffer.lua` | K: 1 A | A the records › that cannot be cut keep the report, and tell the user why |
| 8 cut failure not told | `init.lua`: `if cut_failure then ⏎     warn_later(cut_failure) ⏎   end ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 1 A | A the records › that cannot be cut keep the report, and tell the user why |
| 8 link replaced | `records.lua`: `local target = vim.uv.fs_realpath(file) or file` → `local target = file` | `test_report_buffer.lua` | K: 1 A | A the records › kept through a symbolic link are cut behind it, and the link stays |
| 10 no retry | `records.lua`: `local tries_left = #vim.split(directory, '/', { trimempty = true })` → `local tries_left = 0` | `test_report_buffer.lua` | K: 3 A | A the records › keep a report when another editor makes their directory at the same moment › levels up + args { { 0 } }; A the records › keep a report when another editor makes their directory at the same moment › levels up + args { { 1 } }; A the records › keep a report when another editor makes their directory at the same moment › levels up + args { { 1, 0 } } |
| 10 one retry only | `records.lua`: `local tries_left = #vim.split(directory, '/', { trimempty = true })` → `local tries_left = 1` | `test_report_buffer.lua` | K: 1 A | A the records › keep a report when another editor makes their directory at the same moment › levels up + args { { 1, 0 } } |
| 10 directory failure swallowed | `records.lua`: `error( ⏎         ('aineo cannot make the directory of the report records %s: %s'):format(directory, failure), ⏎         0 ⏎       ) ⏎` → `return ⏎` | `test_report_buffer.lua` | K: 1 A | A the records › whose directory cannot be made refuse a report, naming the directory |
| 1-3 buffer-side rows still applying: unnamed buffer | `buffer.lua`: `vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME) ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 6 A, 5 E | A the Report buffer › is named aineo://report, is no file, has no swap file, is kept hidden and unlisted; A the Report buffer › stays the Report when a file is edited from its window while it is empty; C the Report buffer › keeps every report when the user edits it again › with + args { "edit" }: nvim_exec2(), line 1: Vim(edit):E32: No file name; C the Report buffer › keeps every report when the user edits it again › |
| 1-3 name not taken back (A1) | `buffer.lua`: `free_report_buffer_name() ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 3 A | A the Report buffer › takes its name back from a buffer holding it, and leaks none › after + args { { "lua require('aineo.report').report_buffer()", "bwipeout aineo://report", "edit a; A the Report buffer › takes its name back from a buffer holding it, and leaks none › after + args { { "file aineo://report" } }; A the Report buffer › never discards text the user typed into a buffer holding its name › after + args { " |
| 1-3 reopened counts as showing (A3) | `buffer.lua`: `and vim.bo[buffer].buftype == 'nofile' ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 3 A | A the Report buffer › deleted then shown again by the user takes no report, and the editor quits › with + args { "buffer #" }; A the Report buffer › deleted then shown again by the user takes no report, and the editor quits › with + args { "buffer aineo://report" }; A the Report buffer › never discards text the user typed into a buffer holding its name › after + args { "enew \| bdelete %d \| buffer aineo://report" } |
| 8 never cut back (A5) | `records.lua`: `if stat and stat.size > 2 * RECORDS_KEPT_BYTES then` → `if false then` | `test_report_buffer.lua` | K: 3 A | A the records › are cut to their newest 2 MiB once they have grown past 4 MiB; A the records › kept through a symbolic link are cut behind it, and the link stays; A the records › that cannot be cut keep the report, and tell the user why |
| 8 records overwritten (re-anchored) | `records.lua`: `local append_failure = write_to(file, 'a', vim.json.encode(record) .. '\n')` → `local append_failure = write_to(file, 'w', vim.json.encode(record) .. '\n')` | `test_report_buffer.lua` | K: 7 A | A the Report buffer › keeps every report when the user edits it again › with + args { "edit" }; A the Report buffer › keeps every report when the user edits it again › with + args { "edit!" }; A the records › are cut to their newest 2 MiB once they have grown past 4 MiB; A the records › are kept whole up to 4 MiB when a report is added; A the records › kept through a symbolic link are cut behind it, and the link stay |
| 8 append failure unchecked (re-anchored N10) | `records.lua`: `if append_failure then ⏎     error(('aineo cannot keep the report in %s: %s'):format(file, append_failure), 0) ⏎   end ⏎` → `(nothing)` | `test_report_buffer.lua` | K: 2 A | A the records › refuse a report they cannot keep, naming the file, and show nothing; A the records › that cannot keep a report tell the user why, once |
| 8 rename failure unchecked (re-anchored) | `records.lua`: `failure = not renamed and rename_failure or nil ⏎` → `(nothing)` | `test_report_buffer.lua` | survived |  |
| 2 wait unbounded (A2) | `editor.lua`: `local CONFIRMATION_TIMEOUT_MS = 5000` → `local CONFIRMATION_TIMEOUT_MS = 600000` | `test_mcp_blocked_editor.lua` | K: 1 A | A a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done |

**40 literal edits, 39 applied** (F0's text no longer occurs) **in 44 runs** (the timing-sensitive ones twice, M8 on two files). **36 of the 39 applied edits were killed by assertion**, none by a crash only; "unnamed buffer" also fails 5 cases by crash, beside 6 by assertion. **3 survive:** D0 and R0, each equivalent for the reason given under *Findings of the re-measure*, and "rename failure unchecked", the limit the fix round recorded.

### Limits recorded in the correction

These replace the fix round's *Limits* where they say otherwise.

- **The trim race still loses records.** Two editors appending to one records file while one cuts it can lose a record appended between the cut's read and its rename. The reviewer measured 4 and 1 records lost in two runs of 5000 reports per editor with the per-process cut name, and ENOENT refusals went to 0. The correction's runs of the same probe lost 1 (on `faf16db`), then 0, 0, 12 and 1 (with the mkdir retry and its `isdirectory` check), then 0 in each of 4 runs on `17e034f` — a race, so a run without loss proves nothing. Preventing the loss needs a lock.
- **A records file that cannot be cut back grows** until its directory can be written; the user is warned with each report meanwhile.
- **The cut's rename failure** is now a cut failure (a warning, the report kept). Its mutant is reported below; no portable test makes the rename fail once the cut file is written.
- **A record longer than 2 MiB** is shown when it arrives, but never in a later editor, and a cut drops it. A report under the 1 MiB line limit grows that far only when its details hold mostly characters the records write as six bytes: DEL from any client, or raw control characters from a client that does not escape them as JSON requires (lua-cjson's decoder accepts them raw).
- **The worst case measured** at the bound: a Report of 1 040 004 lines, opened in 156 ms with 104 MB resident (the re-measure's run of the attack reviewer's flood probe). The fix round's "520004 lines, 93 ms" was not the worst case.
- **The user's own commands in the Report** (finding 11, the reviewer's measurement at `1a67263`, not re-run): `:doautocmd BufReadCmd` appends every record a second time; `:file x` and `:saveas x` rename the Report, and `:saveas` also leaves an ordinary buffer named `aineo://report` while reports keep going to the renamed Report.
- **A peer at the editor's address that is not Neovim** can hold a report for 5 s or get no answer (above). Neovim writes none of these.

## Commits

Merged by rebase into `dev` on 2026-09-24 (PR #10, final head `2058eff`; 30 commits; per-file identity 25 of 25), recorded by the orchestrator's knowledge pass:

| `dev` | was | round |
|---|---|---|
| `adf4815` | `7f910a8` | packet — Add the report channel: the MCP relay and the Agent Report |
| `dffcd96` | `a1a1f26` | packet — Pin that an over-long line is not kept while it is dropped |
| `19d18b3` | `fec11e6` | packet — Make the newline rendering test fail on its assertion |
| `6f023fa` | `dcb8e36` | packet — Drop a guard in the line reader that no test could ask for |
| `b12a93c` | `70ed857` | packet — Record the T5 report channel session |
| `da5315b` | `989d34b` | fix round — Adopt the reviewers' test pins for the relay and the Report |
| `65811ea` | `1f0c81b` | fix round — Keep the Report the Report across the user's buffer commands |
| `f838522` | `d2926a6` | fix round — Harden the relay's protocol edges and make the schema say null |
| `02cc0c1` | `977beec` | fix round — Bound the relay's wait on the editor and the records it keeps |
| `2e7d189` | `aabf131` | fix round — Keep plugins from the system site directories out of the relay |
| `33974fc` | `f22d8aa` | fix round — Drop the Report's loaded check that no test could ask for |
| `b090cbc` | `668a3a7` | fix round — Answer each line in the stdin callback, as the queue changed nothing |
| `d9a5337` | `c26ea30` | fix round — Reach the relay script through the entry point in its load test |
| `c3e4867` | `13759c3` | fix round — Pin every path of the records' bound, each by assertion |
| `8fc6af1` | `e8a6df3` | fix round — Pin the relay's answer reader against a notifying editor |
| `b6ada26` | `d01bea8` | fix round — Create the Report's autocommand group anew, as its docstring now says |
| `faf1214` | `1a67263` | fix round — Record the T5 fix round and correct the packet round's ledger |
| `a0adb3d` | `f80413b` | correction — Pin the relay's 5 s bound by the time its answer takes |
| `10892e1` | `b8a4df7` | correction — Restore the Report's loaded check, which :bunload needs |
| `ad02beb` | `ee63e9d` | correction — Name the records file when it opens but cannot be read |
| `12522ed` | `33b78d1` | correction — Keep the text a user typed into a buffer holding the Report's name |
| `bc4d9ed` | `39ea0aa` | correction — Read the editor's answer byte for byte, through a libuv handle |
| `08c7d0c` | `66ef7e0` | correction — Tell the user of a report the editor cannot keep; promise no showing |
| `b680e47` | `299fdc1` | correction — Keep a report whose records file cannot be cut back |
| `eb3e068` | `5147c0d` | correction — Cut a symlinked records file behind its link |
| `42c5180` | `e61c375` | correction — Name each editor's cut file for its own process |
| `a3c2162` | `faf16db` | correction — Take a records directory another editor made at the same moment |
| `4775cd6` | `30c4ba1` | correction — Take a race lost on any directory of the records' path |
| `6c4da1e` | `17e034f` | correction — Pin the records directory's retry bound with two lost races |
| `e006d58` | `2058eff` | correction — Record the T5 correction and correct the fix round's refuted records |
