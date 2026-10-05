**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, since you are dispatched as that specialist, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T26 | Visual Send (D20, C4): `\s` in Visual mode in Input sends the selection alone, as one message, and removes it; a refused Send removes nothing; `u` in Input brings back what a Send removed, as far as the packet measures it can | T24 | active |

It rests on:
- **D20**: "In Input, `\s` in Visual mode sends only the selection, charwise, linewise or blockwise, as one message, and removes it from Input; the rest of Input stays, not cleared. A refused Send (Claude not ready) removes nothing. `u` in Input brings back what a Send removed — a Visual Send's selection, and a whole-Input Send's text too — if it can be done, which the packet measures first; it restores only Input, the message having reached Claude. `\s` in Normal mode sends the whole Input and clears it, as C4 says". Its annotation of 2026-10-05: the user confirmed its four clauses — "one message" (one bracketed paste and one Enter, for a charwise, linewise or blockwise selection alike), `u`, Neovim's own undo, with no new key, undo after every Send, and the measurement first, gaps reported to the user rather than worked around (`plan.md` › *Decisions for the user*).
- **C4**: "Send (`\s`): the Input buffer as one bracketed paste plus Enter into the terminal, then Input cleared; refused while Claude is not ready (trust dialog, startup) or Input is empty", whose annotation records that D20 supersedes "the Input buffer" and "then Input cleared" for a Visual selection, and adds undo after every Send.
- **D1**: the prefix is `\`, Normal mode, with "a Visual-mode `\s` in Input added by D20".
- **C1** (the entry point: `:Aineo …`, `<Plug>(aineo-…)` mappings, the `\` prefix mapped only where the user has not mapped it), **C7** (health: prefix-mapping conflicts), **D17** and **C11** (Input's draft), **D18** and T24's **PD2 (a)** (Send sends Input while the changes pane hides it).
- **D29** and **D26** for how the suite runs (*Boundary*).

Read them whole in the plan note, with the user's words in their *Reasoning* column.

### The measurement first (D20's fourth clause)

D20 asks that undo be measured in aineo's real Input before it is built on, and that a gap be reported to the user rather than worked around. The plan's settlement of the fourth clause had T26 measure it; the orchestrator measured it instead, for this brief, before dispatch, so that the user heard the gaps before the build: on T24's head, with the suites' fake Claude Code and aineo's real layout, draft and Send (`evidence/t26-probes.txt`, Neovim 0.12.5), and the brief review measured `'undolevels'` (`brief-review-t25-t26.md`, T26-3). The orchestrator told the user on 2026-10-05, with VS1–VS5. What was found:

- **A whole-Input Send is undone today (U1–U7).** `u` in Input after `\s` brings Input's text back, and `<C-r>` empties it again. One `u` per Send: after two Sends, `u` brings back the second's text, then the typing before it, then the first's. The same holds when `\s` was typed in the Report's window (U2), while the changes pane hid Input (U3), and from Insert mode through `<C-o>` (U6). The help already says so (`doc/aineo.txt:451–452` on `cbe5a73`); no test pins it.
- **The saved draft (D17).** The draft restored into a new Input is not undone (`Already at oldest change`, D1), as `restore_draft()` intends (`lua/aineo/draft/init.lua:181–197`, `undolevels = -1` at `:190–193`). After a Send, `u` brings the draft's text back, and the draft file holds it again a second later (D2–D3).
- **A refused Send** changes nothing and adds no undo step (U5).
- **The gap: a failed write (U4).** When the write raises — the closed stream `send()` describes (`lua/aineo/send/init.lua:98–103`) — Send empties Input and puts its lines back in one command, so both are **one undo block**: the first `u` after it changes nothing the user can see, and the second undoes the user's own last change. The same holds for a Visual Send that removes and puts back in one callback (V2b). **This is a gap D20's fourth clause sends to the user, not a thing to work around:** do not join, split or rewrite the undo tree to hide it. The orchestrator told the user on 2026-10-05; the help's *LIMITS* says it (*The behaviours*, VS-H).
- **Visual selections (V, V2).** For every kind of selection measured — charwise on one line and across lines, linewise, blockwise with ragged lines and with `$`, `'selection'` exclusive, multibyte and double-width characters, a selection made backwards, the whole buffer, an empty line, a tab — Vim's own `"_d`, typed or run as `:normal! "_d` inside an `x` mapping's Lua callback, removes the selection, and **one `u` restores it**. A blockwise removal made of one `nvim_buf_set_text()` per line in one callback is one undo step too (V2a).
- **The user's `'undolevels'`** (the brief review's `b_undo`, T26-3; Input has no `'undolevels'` of its own, so the global one holds). With `'undolevels'` 0, after one Send `u` brings the text back and a second `u` empties Input again; after two Sends (`first`, `second`) `u` gives `second`, `u u` empties Input, `u u u` gives `second` again — `first` never comes back. With -1, `u` brings nothing back. "One `u` per Send" holds only while `'undolevels'` is at least the number of Sends. **These too are gaps for the user, not things to work around.**
- **What the selection gives — not always what is removed.** `getregion(getpos('v'), getpos('.'), { type = mode() })` gives Vim's own yank text in most of the drafter's cases, but neither it nor the yank is always what `"_d` removes. The brief review measured (T26-1, T26-2):
  - a `$` block whose cursor ends on a line shorter than another: the yank of `abcdef` / `abc` by `0l<C-v>j$` is `bcdef`, `bc`; `getregion()` gives `bcd`, `bc` — from `getpos('v')` and `getpos('.')`, from `'<` and `'>`, and with the end column set to `v:maxcol` alike — while `"_d` leaves `a`, `a`, removing `bcdef` and `bc`. The drafter's `$` case ended on the longest line, where they agree by chance;
  - a ragged block whose left edge is two or more columns past a short line's end: the yank and `getregion()` pad that line with spaces (`{ abcdef, ab, abcdef }`, `0llll<C-v>jjl` gives `ef`, two spaces, `ef`), and `"_d` removes nothing from it. One column past, the line is empty in both (`0ll<C-v>jjl` gives `cd`, empty, `cd`);
  - `'virtualedit'` `all`: `0lv5l` on `abc` yanks `bc` and four spaces, never in Input; a `$` block under `'virtualedit'` pads every line (`bcdef `, `bc    `);
  - a tab partly inside a block is yanked as spaces (`     b`), and `"_d` puts spaces in its place (`a\tb` becomes `a  `);
  - a selection that ends past the end of a line (`v$`): the yank ends with the line break, `getregion()` does not, and `"_d` removes it, joining the lines.
  What is sent is therefore not read from `getregion()` alone: VS5, and VS-A.
- **Two traps measured.** In an `x` mapping's Lua callback Visual mode is still on, and `'<` and `'>` still hold the **previous** selection: read the selection from `getpos('v')` and `getpos('.')` (or after leaving Visual mode). A callback that changes nothing leaves Visual mode on (V2d).
- **`\s` in Visual mode where nothing maps it** — a file buffer, today: `\` does nothing, and `s` replaces the selection: the selected text is deleted and Insert mode entered. V's last line shows the deletion, and reads mode `n` only because `nvim_feedkeys(…, 'mtx')` ends Insert mode once its keys have run; the brief review re-measured it with an `InsertEnter` autocommand, which fired once (`brief-review-t25-t26.md`, T26-6). That is VS1's reason.
- **`:'<,'>Aineo send`** and `:1Aineo send` raise `E481: No range allowed` today (V2c).

### Before dispatch: the user's decisions

D20 fixes the key and what it does in Input. It leaves five things open, each with more than one defensible form. Each is a decision for the user under the orchestrate skill's rule 5, numbered once here and in the plan's *Packet T26* section: **VS1–VS5**, VS5 widened as the brief review worded it (T26-2). The orchestrator put them to the user on 2026-10-05, with the gaps above; the answers are in *Amendment — 2026-10-05: the user's answers*, at the end of this brief. **A behaviour below marked "VS<n>" is built as the amendment records it, never as an option's wording here.** The options below are kept as they were put to the user.

- **VS1 — `\s` in Visual mode outside Input.** Options:
  - (a) aineo maps `\s` in Visual mode globally, as it maps every prefix key (C1); outside Input it sends nothing, removes nothing, and tells the user once that Visual Send works in Input;
  - (b) aineo maps it only in Input, buffer-locally: elsewhere `\s` does what Vim does — measured, `s` deletes the selection and enters Insert mode;
  - (c) aineo maps it globally, and outside Input it sends the selection without removing it.
  - The orchestrator's recommendation: (a). D20 says "In Input" and nothing about elsewhere; D1's annotation reads "a Visual-mode `\s` **in Input** added by D20", which leans toward (b). Against (b): a habit typed in a file deletes text; (c) is a behaviour no row holds.
- **VS2 — the `<Plug>` mapping (C1).** Options:
  - (a) `<Plug>(aineo-send)` is defined in Visual mode too: one name for Send, in both modes, so that `vim.keymap.set({ 'n', 'x' }, '<Leader>as', '<Plug>(aineo-send)')` maps both;
  - (b) a name of its own in Visual mode, `<Plug>(aineo-send-selection)`.
  - The orchestrator's recommendation: (a).
- **VS3 — `:Aineo send` with a range.** Options:
  - (a) no range, as today: `:'<,'>Aineo send` stays Neovim's own `E481: No range allowed`, and `:Aineo send` sends the whole Input;
  - (b) `:[range]Aineo send`, run in Input, sends and removes those lines, linewise, whatever kind the Visual selection was; refused elsewhere; every other subcommand refuses a range with one error;
  - (c) a range is refused by aineo with one error naming `\s` in Visual mode.
  - The orchestrator's recommendation: (a). A range is linewise, so under (b) `:'<,'>Aineo send` after a charwise or blockwise selection sends something other than what `\s` sends; `\s` and `<Plug>(aineo-send)` are the Visual doors.
- **VS4 — Visual mode after a Visual Send that sends nothing** (refused, or VS1 (a) outside Input). Options:
  - (a) Visual mode ends, the selection kept for `gv`, as Vim ends it after a command that fails (`d` in a buffer that is not modifiable);
  - (b) Visual mode stays, the selection as it was, so that `\s` can be pressed again.
  - The orchestrator's recommendation: (a). Measured (V2d): a callback that changes nothing leaves Visual mode on, so (a) must end it.
- **VS5 — where Vim's yank text and the text removed differ**, widened by the brief review (T26-2) from the line break alone: a line break past a line's end (`v$`, or `v` across a line's end), the padding of a ragged or `$` block, `'virtualedit'`, a tab cut by a block (*The measurement first*). Vim's `"_d` does the removal in every option; the message is one bracketed paste. Options:
  - (a) the message is Vim's yank text: a final line feed for the line break, spaces for padding;
  - (b) the message is exactly the text removed from Input: each line's removed part, a ragged line's part empty, no padding;
  - (c) the line break is neither sent nor removed: the lines are not joined.
  - The orchestrator's recommendation: (b). "The message is what left Input" is what the user can check with `u`. The drafter's VS5 had put the line break alone, with a (b) that left the final line break out of the message; the widened (b) is the text removed, and a line break past a line's end is removed. What Claude Code makes of a paste ending in a line feed was not measured, and no other Send ends in one.

### The behaviours — one test each, each seen red first

The shapes are yours under `tdd` and `modularity`; the properties below are not. "Input" below is the layout's Input buffer (`require('aineo.layout').input_buffer()`), in whichever window it is current.

- **VS-A — Visual Send (D20).** `\s` in Visual mode in Input sends the selection alone, as one message — its lines joined by line feeds, without control bytes, as one bracketed paste and one Enter in one write, as Send writes Input (`lua/aineo/send/init.lua:72–80`, `104–124`) — and removes it from Input. The rest of Input stays. One case per kind: charwise, linewise, blockwise.
  - **What is removed** is what Vim's own `"_d` removes, measured in each case (V): a block with ragged lines leaves the short lines as they are; a block with `$` removes to each line's end; `'selection'` exclusive leaves the character under the cursor; a selection holding all of Input leaves Input empty.
  - **What is sent** is VS5's, as the amendment records it: exactly the text removed from Input. A cut through a multibyte or double-width character never splits it; a double-width character a block cuts through is removed whole and sent whole.
  - **The read.** `getregion()` alone is not that text (*The measurement first*). The one candidate measured is the brief review's (`b_dollar2`, T26-1): `getregion()` for every selection but a `$` block; for a block whose `curswant` is `v:maxcol`, `getregionpos()` for each line's left edge, then that line from its edge to its end with `getregion()`, and an empty line where the edge lies past the line's end. Its limits, as measured: it was compared with Vim's yank, never with the text removed; it matched the yank in 5 of 7 `$` blocks and differed exactly where the yank pads — a line shorter than the block's left edge (the candidate empty, which is what `"_d` removes from it) and a left edge on a double-width character's right half (the candidate gives the whole character); it was not run on a ragged block without `$` (where `getregion()` pads as the yank does), under `'virtualedit'`, on a tab cut by a block, or on a line break past a line's end. Build the read as you choose; **every case pins what is sent against what was removed** — Input's lines before the Send against its lines after — for each family: charwise, linewise, blockwise; a `$` block whose cursor ends on a shorter line; a ragged block whose edge is one, and two or more, columns past a short line; `'virtualedit'` `all` and `block`; a tab cut by a block; a line break past a line's end; a multibyte and a double-width character cut.
  - **No register is written.** The user's registers, the unnamed one included, are as they were.
  - The cursor and the mode after it: where Vim's `"_d` leaves them, in Normal mode.
- **VS-B — a refused Visual Send removes nothing (D20).** Each refusal Send has that a selection in Input can meet — the selection holding only white space, Claude Code not started, starting or behind a dialog, exited (`REFUSALS`, `lua/aineo/send/init.lua:27–33`) — sends nothing, removes nothing, and tells the user once, as Send does today. What the mode is then: VS4. The selection holding only white space is refused as an Input holding only white space is (C4's "Input is empty"), with words that say the selection is empty.
- **VS-C — a failed write after a Visual Send** puts Input's text back as it was before the Send, raises the write's error as Send does (`:119–123`), and is the one undo block the measurement found (U4, V2b). Pin what `u` then does, as measured; do not change it.
- **VS-D — undo after every Send (D20).** `u` in Input brings back what a Send removed, one `u` per Send:
  - a Visual Send, of each kind: one `u` brings the selection back where it was, Input whole again;
  - a whole-Input Send: **pinned by a test** for the first time (U1);
  - a Send made while Input's window was not current (U2) or the changes pane hid Input (U3);
  - after the draft was restored into Input (D2): `u` brings the sent text back, and stops there.
  - Undo restores only Input: nothing is written to Claude Code's terminal by `u` (D20).
  - Every case above sets `'undolevels'` to its default, 1000, itself: the user's value decides what `u` can bring back.
  - **The `'undolevels'` gaps, pinned as measured** (T26-3): with 0, after two Sends `u` brings back the second's text and never the first's; with -1, `u` brings nothing back.
  - **A gap your pins find that the measurement did not** — for a whole-Input Send, a Visual Send or a refusal — is reported to the orchestrator, not worked around (D20's fourth clause): do not join, split or rewrite the undo tree to hide it.
- **VS-E — the four doors (C1).** `\s` in Visual mode (D1, D20), the `<Plug>` mapping (VS2), `:Aineo send` (VS3), and outside Input (VS1). One case per door, as `tests/test_entry_panes.lua` does for `\pa` and `\pc`.
  - **Outside Input with no Input at all** — the layout never opened, or Input wiped: the message is VS1 (a)'s, that Visual Send works in Input, not `REFUSALS.no_input`. A selection is never in an Input that does not exist, so `no_input` is a refusal of Normal mode's Send alone. The orchestrator's reading, for the MVP review (T26-9); one case pins it.
  - The Visual `\s` is mapped once the editor has started, unless the user mapped `\s` **in Visual mode** globally, and not at all when `prefix` is `false`. A user's own Normal-mode `\s` does not keep aineo from mapping the Visual one, nor the other way round: `has_global_mapping()` (`plugin/aineo.lua:554–559`) reads Normal-mode mappings alone today, and must read the mode it maps.
  - Normal-mode `\s` sends the whole Input as today (D20's last sentence).
- **VS-F — the health check (C7).** `:checkhealth aineo`'s *Prefix mappings* reports the Visual-mode `\s` as it reports every key: ok when it runs its `<Plug>` mapping, a warning when it runs the user's or nothing. Its row goes **last** in `PREFIX_KEYS` (`lua/aineo/health.lua:253–262`), and its line says Visual mode, so that it is told apart from Normal mode's `\s`. `global_mapping()` (`:278–283`) and `check_prefix_key()` (`:306–325`) read Normal mode alone today.
- **VS-G — the help.** `doc/aineo.txt` documents Visual Send, its key, its `<Plug>` mapping, `:Aineo send`'s range (VS3), undo after every Send, and the gaps (VS-H). A Visual-mode key takes a tag of its own, `*aineo-v_\s*`, after Vim's own `v_` tags (`:help v_d`), and joins `TAGS` (`tests/test_doc.lua:76–114`). `TAGS_THE_PLUGIN_DEFINES` (`:119–144`) derives tags from Normal-mode mappings only (`:124`): make it derive the Visual-mode ones too, so the new key cannot lose its tag unseen.
- **VS-H — the gaps, said.** `doc/aineo.txt`'s *LIMITS* names each gap, in the user's terms: after a failed write, the first `u` changes nothing visible (VS-C); with `'undolevels'` 0, `u` toggles only the last Send; with -1, `u` brings nothing back (VS-D). No workaround is built.

### Facts, checked against `origin/dev` (`cbe5a73`)

Every line number below is `cbe5a73`'s: T24 merged as `c9b78b1` (PR #105, 2026-10-05), and `cbe5a73`'s code is `c9b78b1`'s and T24's final head `8f08be9`'s (`git diff --stat c9b78b1 cbe5a73 -- lua plugin tests doc scripts Makefile` prints nothing). The brief review re-checked every number at `8f08be9` (T26-7). T30 and T25 merge before this packet is dispatched, and shift them; find each place again by its text after they merge. The orchestrator re-checks these facts against the `origin/dev` the dispatch message names (rule 2).
- **T30** (PR #108, in review, head `c599679`), of the files below: `plugin/aineo.lua` at `ERROR_FRAMING` and its docstring (`:463–478`, three lines fewer); `lua/aineo/health.lua`, a new `Neovim` section near its top (`check_neovim()`, eighteen lines more before `PREFIX_KEYS`) and `run_within_bound()`'s docstring; `tests/test_health.lua`, two `Neovim` cases near its top (36 lines more before the *Prefix mappings* cases, whose indexes into the section stay); `doc/aineo.txt`, a `Neovim ~` entry in `10. HEALTH CHECK` (four lines more before `Prefix mappings ~`); and `tests/test_entry.lua`.
- **T25** changes `plugin/aineo.lua` between `:207` and `:358`, `lua/aineo/layout/init.lua`, `doc/aineo.txt`'s sections 2, 3 and 11, and `tests/test_doc.lua`'s `TAGS`.

- **The send home** (`lua/aineo/send/init.lua`, 126 lines): `REFUSALS` `:27–33`, `existing_input()` `:46–52`, `without_control_bytes()` `:63–70`, `pasteable_text()` `:77–80`, `M.send()` `:104–124` — the clear at `:117–118`, the write at `:119`, the put-back at `:120–123`. Its docstring says how a failed write puts the lines back (`:98–103`). It requires `aineo.claude` and `aineo.layout` (`:4–5`), as the modularity skill's direction table allows (`.claude/skills/modularity/SKILL.md:42`; `:43` once PR #109 adds `aineo.changes`' row above it).
- **The draft home** restores the draft with `undolevels = -1` (`lua/aineo/draft/init.lua:190–193`) and watches Input's lines (`keep_draft()`, `:381–423`). T26 does not touch it.
- **The composition root** (`plugin/aineo.lua`, 764 lines):
  - `SUBCOMMANDS` `:27`, `USAGE` `:34`;
  - `ACTIONS` `:440–461`, `send` at `:441–443`;
  - `plug_mapping()` `:523–525`, and the `<Plug>` loop `:527–531`, which maps **Normal mode** alone;
  - `PREFIX_KEYS` `:535–544`;
  - `has_global_mapping()` `:554–559`, Normal mode alone;
  - `map_prefix()` `:568–578`, Normal mode alone;
  - `:Aineo` `:752–764`: `nargs = '*'`, `bar = true`, no `range` (V2c).
- **The health check:** `PREFIX_KEYS` `lua/aineo/health.lua:253–262`, `global_mapping()` `:278–283`, `check_prefix_key()` `:306–325`, the loop `:477–479`.
- **The pins that count or list what T26 adds — every one inside your boundary:**
  - `tests/test_plugin.lua:79–107`: every mapping and autocommand sourcing defines, listed whole, each with its mode (`'n <Plug>(aineo-send)'`, `'n \\s'`);
  - `tests/test_entry_prefix.lua:7–16`: `PREFIX_KEYS`, parametrizing every prefix case, each case reading `maparg(…, 'n')` (18 reads, from `:27` to `:151`: `grep -n maparg tests/test_entry_prefix.lua`);
  - `tests/helpers/health.lua`: `keys_mapped_to_aineo()` (`:88–99`) reads `nvim_get_keymap('n')` alone, and `keys_reported_in_place()` (`:106–113`) parses `^%- ✅ OK (%S+) runs `. They feed `tests/test_health.lua:603–610`, *the prefix mappings › report the keys plugin/aineo.lua mapped to aineo, no more and no fewer*: with a Visual row, a line of that shape adds `\s` a second time and the case fails, or the Visual row passes it unseen and the case no longer means "no more and no fewer" (the brief review, T26-4). Both helpers and the case are inside your boundary;
  - `tests/test_health.lua`, *Prefix mappings*: the full lists at `:498`, `:617`, `:635`, `:693`, `:726`, `:766`, `:827`, `:885` and `:895`; the count `== 8` at `:565` and `:600`; the index past the keys, `[9]`, at `:516`, `:533`, `:549`, `:582`, `:659`, `:679`, `:849`, `:864` and `:875`; `[1]` at `:750` and `[2]` at `:805` and `:816`, which hold while the Visual row goes last. Find them with `grep -n "Prefix mappings" tests/test_health.lua`;
  - `tests/test_doc.lua`: `TAGS` `:76–114`, `TAGS_THE_PLUGIN_DEFINES` `:119–144`, and the floor `#tags >= 19`;
  - `tests/test_send.lua` (557 lines): `send()`'s cases, among them *keeps Input and raises when the write fails after Input is emptied* (`:499`); no case presses `u`.
  - `tests/test_entry.lua` names "seven subcommands" in four case names (`:38`, `:45`, `:56`, `:63`); under VS3 (a) or (c) T26 adds no subcommand and none changes. T30 edits that file; T26 touches it only under VS3 (b), its cases on a range.
- **The help's sections T26 makes false or incomplete** (`doc/aineo.txt`, 738 lines), each running from its heading to the line before the next `====` rule:
  - `1. INTRODUCTION *aineo*`, from `:19`: the keys paragraph, `:26–32` ("Every command sits behind one prefix key, `\` by default, in Normal mode");
  - `4. COMMANDS *aineo-commands*`, from `:216`: the `*:Aineo-send*` entry, `:224–225`, under VS3;
  - `5. MAPPINGS *aineo-mappings*`, from `:313`: "aineo defines one Normal-mode `<Plug>` mapping per action" (`:315–318`, its example mapping Normal mode), the `*<Plug>(aineo-send)*` entry (`:319–320`), and `Prefix keys ~ *aineo-keys*` (`:346–386`): "globally, in Normal mode" (`:348–349`) and the paragraph on keys the user mapped (`:368–375`);
  - `7. SEND *aineo-send*`, `:447–466`: Visual Send, and undo after every Send (`:451–452` says it of a whole-Input Send today);
  - `10. HEALTH CHECK *aineo-health*`, `Prefix mappings ~`, `:681–692`;
  - `11. LIMITS *aineo-limits*`, from `:717`: VS-H.
- **Measured for this brief:** `evidence/t26-probes.txt`, Neovim 0.12.5, on `8e520f5`'s code, each probe with its source and output: U (undo after Sends), D (the draft), V (every kind of selection), V2 (API removals, `:'<,'>Aineo send`, a callback that changes nothing). The brief review re-ran U, D, V and V2 on `8f08be9` (identical) and measured more, quoted in `brief-review-t25-t26.md`: `b_dollar` and `b_dollar2` (T26-1), `b_visual`, `b_visual2` and `ragged` (T26-2, T26-6), `b_undo` (T26-3), `b_modes` (VS4's reason, and `nvim_get_keymap('x')` listing a `vmap` and an `xmap` alike).

### Baseline

The dispatch message names the `origin/dev` you start from — T25's merge — and pastes the counts of the orchestrator's verification of that merge on Neovim 0.12.5: `tests/test_entry_guard.lua`, `make test` and `make lint`. That verification is the merge before this packet's, so its counts do not exist yet as this brief is written; `plan.md` › *Landed* records them with T25's merge, as it records T24's. Those pasted counts are your baseline; do not run a whole suite to make one.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D20, C4, D1, C1, C7, D17;
- `knowledge-vault/Implementation/Waves/00007-panes/plan.md` › *Decisions for the user* (D20's four clauses, and the gaps told to the user) and *Packet T26*, and this brief's amendment, which records VS1–VS5;
- `knowledge-vault/Implementation/Waves/00007-panes/evidence/t26-probes.txt`;
- `knowledge-vault/Implementation/Waves/00007-panes/brief-review-t25-t26.md` › *T26*: what the brief review measured;
- `knowledge-vault/Projects/aineo.md`;
- `knowledge-vault/Sessions/2026-09-27 — T12 Claude line numbers.md` and `knowledge-vault/Sessions/2026-10-05 — T24 Panes.md`: the last packets to add a `<Plug>` mapping, a prefix key, a health line and help entries.

## Boundary

- **Branch:** `feature/t26-visual-send` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus` — every role in this project runs on Opus.
- **Resources:** `impl_t26_visual_send`.
- **You may touch:**
  - `lua/aineo/send/`: its entry point and new files inside it;
  - `plugin/aineo.lua`: the `<Plug>` loop and `plug_mapping()`, `PREFIX_KEYS`, `has_global_mapping()` and `map_prefix()`, a Visual-mode action beside `ACTIONS`, and, under VS3 (b) or (c), `:Aineo`'s definition and `USAGE`. Not `ERROR_FRAMING`, the panes' functions, T25's changes-pane functions, nor the autostart (`start_up()` and what it reaches);
  - `lua/aineo/health.lua`: `PREFIX_KEYS`, `global_mapping()`, `check_prefix_key()`, and their docstrings;
  - `doc/aineo.txt`: the sections listed under *Facts*. Correct each one T26 makes false, and say in your report what you corrected;
  - new test files `tests/test_send_selection.lua` and `tests/test_entry_send_selection.lua`, or names of your own under `tests/test_*send_selection*.lua`;
  - the pins under *Facts*: `tests/test_plugin.lua`, `tests/test_entry_prefix.lua`, `tests/test_health.lua`, `tests/test_doc.lua`, `tests/test_send.lua` (the whole-Input undo case), and `tests/test_entry.lua` only under VS3 (b);
  - `tests/helpers/health.lua`: `keys_mapped_to_aineo()` and `keys_reported_in_place()`, so that `tests/test_health.lua`'s *… no more and no fewer* case counts the Visual-mode key as a key of its own (T26-4); other test files that require these two are then yours to run (D26);
  - `tests/helpers/send.lua`: new functions only;
  - your session note.
- **You must not touch:**
  - `lua/aineo/draft/`, `lua/aineo/layout/`, `lua/aineo/changes/`, `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/report/`, `lua/aineo/git/`, `lua/aineo/config/`, `lua/aineo/init.lua`;
  - `scripts/`, the `Makefile`;
  - every test file and helper not named above;
  - the task list: this rolling wave holds its marks (SKILL §3 rule 6). Write a `## Task lines` section in your session note, one paragraph for T26 in the closed lines' style;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Fixture names** carry a `selection-` prefix no other file uses (`git grep -n "'selection-" cbe5a73 -- tests` prints nothing): test files run side by side (T22), and `fixture.directory(name)` deletes and recreates `.tests/fixtures/<name>`.
- **Never run the real `claude`.** The suites' fake and the `PATH` guard are the root `CLAUDE.md`'s.
- **Session note:** `knowledge-vault/Sessions/2026-10-06 — T26 Visual Send.md`, dated the day of dispatch: on another day, that day's date.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). Prefix every file with `t26-`. Keep all scratch inside your worktree, never in `/tmp`.
- **How you run the suite** (the root `CLAUDE.md`):
  - **D29:** on the newest Neovim release only, the host's 0.12.5. **Never 0.11.**
  - **D26:** run the test files your change touches while you work, at every red and green step. Run a mutant on the test files that exercise the code it breaks, and on the whole suite only if it survives there. Run the whole suite (`make test`) **once before each push**, on the tree you push.
  - **D28 does not apply:** this is a code packet.
  - Measure your new test files' run time and report it. A case never waits a fixed delay to prove that something did not happen, when a later event can prove it.
  - Keys in a test are typed, as the measurement typed them (`nvim_feedkeys(…, 'mtx')` or the child's `type_keys`): an undo block is what one typed command makes, and a case that calls `send()` directly from Lua measures something else.
- **Stop every process you start, by pid.**
- Anything the task needs outside this boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **D20 and its four clauses are the user's** (2026-09-25; confirmed 2026-10-05): one message; `u`, no new key; undo after every Send, pinned; the measurement first, gaps reported, not worked around. The measurement is this brief's, the orchestrator's (and the brief review's), not yours; you pin each fact it found in a test. The gaps — the failed write's undo block and the two `'undolevels'` gaps — were told to the user on 2026-10-05, who answered "as for the gaps in D20 do as you propose": the help's *LIMITS* names each, a test pins each, and no workaround is built.
- **VS1–VS5 are the user's** (2026-10-05), in *Amendment — 2026-10-05: the user's answers*, below.
- **T24's PD2 (a)**: Send sends Input while the changes pane hides it. A Visual Send needs a selection, so it happens only where Input is shown.
- **The orchestrator's readings**, for your note's *Readings for the MVP review*:
  - "in Input" is Input as the current buffer, in whichever window;
  - what is removed is what Vim's `"_d` removes, and what is sent is exactly that text (VS5 (b)): a ragged block's short lines are empty lines of the message, and no padding is sent;
  - a tab a block cuts: `"_d` removes the tab and puts spaces for its part outside the block; the text removed is the tab and what follows it inside the block, and the spaces put back are not sent (`a\tb`, `0lll<C-v>jl` on `{ abcdefghij, a\tb }`: that line's part of the message is `\tb`). This reading is the amendment's, for the MVP review: the user's words, "exactly the text removed from Input", do not say how a tab half inside counts;
  - outside Input, with or without an Input, VS1 (a)'s message (VS-E);
  - a selection holding only white space is refused as an empty Input is;
  - no register is written;
  - the Visual key's tag is `*aineo-v_\s*`, and its health row goes last;
  - a failed write's single undo block is reported, and stays (VS-C, VS-H).
- **Not in scope:**
  - the changes pane (T25) and the panes' switching (T24);
  - the draft home: its restore is not undone by design (D17, `restore_draft()`), which the measurement confirmed;
  - a Send of a selection made in another buffer (VS1).

## Budget

Medium: a Visual-mode path in the send home, a new mode on the entry point's three tables, the health check, the help, the undo pins, and eight behaviours with the pins they move. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t26-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.

## Amendment — 2026-10-05: the user's answers

The orchestrator put VS1–VS5 to the user on 2026-10-05, each explained in plain words, with the options above and a recommendation, VS5 widened as the brief review worded it, and told the user the undo gaps D20's fourth clause sends there. The user's answer, verbatim, which also answers T25's questions: "CP1 as you recommended. CP2. stay, as recommended, CP3 One middle window, as you propose, CP4 as recommended, CP5 as recommended. CP6 As recommended, CP7 ok, as recommended, CP8 fine, as recommended, CP9, fine, as recommended, VS1 Agreed, VS2 Ok, VS3 ok, agreed, VS4 ok, fine agreed, VS5 agree, as for the gaps in D20 do as you propose". Each is the orchestrator's recommendation. Build them so:

- **VS1 — (a).** `\s` in Visual mode is mapped globally, as every prefix key is (C1). Outside Input it sends nothing, removes nothing, and says once that Visual Send works in Input — with no Input at all too (VS-E). The brief review's T26-5, that VS1 (b) could not be built inside this boundary, is moot: the boundary stands as written.
- **VS2 — (a).** `<Plug>(aineo-send)` is defined in Visual mode too: one name for Send, in both modes.
- **VS3 — (a).** No range: `:'<,'>Aineo send` stays Neovim's `E481: No range allowed`, and `:Aineo send` sends the whole Input. `tests/test_entry.lua` stays outside your boundary.
- **VS4 — (a).** After a Visual Send that sends nothing — refused, or outside Input — Visual mode ends, and `gv` brings the selection back.
- **VS5 — (b), widened.** Wherever Vim's yank text and the text removed differ — a line break past a line's end, the padding of a ragged or `$` block, `'virtualedit'`, a tab cut by a block — the message is exactly the text removed from Input, a ragged line's part empty. A line break past a line's end is removed, so the message holds it (VS-A; *What was decided already* for the tab).
- **The undo gaps (D20's fourth clause), "do as you propose".** The help's *LIMITS* names each gap, a test pins each, and no workaround is built:
  - after a failed write, the first `u` changes nothing visible (VS-C);
  - with `'undolevels'` 0, `u` toggles only the last Send (VS-D);
  - with -1, `u` brings nothing back (VS-D).

**The brief review's corrections** (`brief-review-t25-t26.md`, T26-1 to T26-10) are made in the body above, each as the review words it: *The measurement first* (who measured, the `'undolevels'` gaps, what `getregion()` gives, VS1's evidence line), VS1's and VS5's options, VS-A (the read and its candidate), VS-B, VS-D, VS-E, VS-H, *Facts* (re-anchored to `cbe5a73`, `tests/helpers/health.lua` among the pins), *Baseline*, *Boundary* and *What was decided already*.

**Verification mutants for these answers** are in `plan.md` › *Packet T26*, one per option the user did not choose.
