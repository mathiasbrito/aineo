# A Neovim 0.12 TUI waits for a DSR answer at startup and serves requests meanwhile

**Tags:** #neovim #neovim-0.12 #tui #rpc #startup #testing #measured
**Discovered:** [[Sessions/2026-09-25 — T13 Neovim 0.12]] (PR #31, NC6, and the re-measure) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

When Neovim 0.12.5 starts with its TUI on a terminal, it does three things before the user's config runs:
- it sends an OSC 11 query (the background colour) and a DSR query (`CSI 5 n`);
- it waits up to 100 ms, inside `vim.wait()`, for the DSR answer `CSI 0 n`;
- when no answer comes, it warns `E1568: Terminal did not respond to DSR request for 'background' color. Startup may be slower. :help 'ttyfast'`, unless `NVIM_TEST` is set.

`vim.wait()` runs the event loop, and the event loop serves RPC requests. A client that connects the moment the server's socket appears can have its request run before the user's init. For example, a `require` of a plugin that the init puts on `'runtimepath'` fails.

0.11.6 sends the OSC 11 query only, and does not wait.

## Example

T13 (PR #31): `tests/helpers/report_tui.lua` starts an editor with its TUI in a pseudo-terminal and sends it reports over RPC.
- **On 0.12.5 at `dev` `9af91a6`:**
  - the three cases of `tests/test_mcp_blocked_editor.lua` then in the suite failed with `Lua: [string "<nvim>"]:2: module 'aineo.report' not found` (`Implementation/Waves/00006-fixes/evidence/baseline-0.12.5.txt`);
  - the editor's `:messages` held E1568 (T13's red for NC6b).
- **The fix, in two parts** (`39d9cb0`, `766f092` on `dev`):
  1. The helper answers each `CSI 5 n` with `CSI 0 n`, as a terminal would.
  2. It also waits for startup to end. The end is marked by a file that a `--cmd` writes from a `vim.schedule()` callback at `VimEnter`. A request would not do: one sent to an editor at a hit-enter prompt is held there ([[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]).
- **Answering the DSR alone was not enough.** With the answer in place and the startup wait removed (mutant M11), all 5 cases then in the file still failed on 0.12.5: 1 by assertion, 4 by the helper's `require` raising `module 'aineo.report' not found`. The first request was still served during startup. M11 survived on 0.11.6.
- **0.11.6 serves requests only after startup.** T13's re-measure asked the moment the socket appeared, 30 times, and 0.11.6 answered after `VimEnter` 30 times of 30.

**Why.** Both runtimes were read by this knowledge pass (2026-09-28), in the two releases' own files.
- `runtime/lua/vim/_core/defaults.lua` at `v0.12.5` runs this code only when a UI with a `stdout_tty` is attached (lines 790–799).
- Lines 965–988 hold the wait:
  - `vim.api.nvim_ui_send(osc11 .. dsr)`;
  - then `vim.wait(100, function() return did_dsr_response end, 1)`;
  - the source's comment: "Wait until detection of OSC 11 capabilities is complete to ensure background is automatically set before user config".
- 0.11.6's `runtime/lua/vim/_defaults.lua` writes `\027]11;?\007` (line 836) and does not wait.

## Why it matters

Several kinds of program drive a real 0.12 TUI from a pseudo-terminal: a test harness, an embedding terminal that does not answer DSR, a remote wrapper. Each of them:
- pays up to 100 ms at every start and gets E1568, unless it answers `CSI 5 n`;
- must not take "the socket exists" for "the editor has started".

Setting `NVIM_TEST` hides the warning but keeps the wait. T13 answered the query instead, because no user's editor has that switch.

**Limits:**
- measured on 0.11.6 and 0.12.5;
- a headless Neovim, with no terminal UI, does not run this code;
- T13's helper does not answer the OSC 11 query, so its editor keeps the default `'background'`.
