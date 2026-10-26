# 2026-10-25 — T150 deep explain

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t150-deep-explain` (from `dev` at ba9c690c) · **Pull request:** into `dev`

T150: `\VV` and `\VVI`, the deep requests of the explain home, with a float in which the user steers the prompt (D122, A625). D123 and T151 (propose fix) are not in this packet; the float is its own file so that T151 reuses it with its own default text.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D122 and T150 rows, beside D103–D106 and T115–T122
- [[Sessions/2026-10-24 — T148 attach claimed session]] — the last session note before this packet
- `lua/aineo/explain/{request,kept,kinds,marks,runs,steer,init}.lua`, `lua/aineo/entry/explaining.lua`, `lua/aineo/config/init.lua`, `lua/aineo/health.lua`, `plugin/aineo.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T150 deep explain `\VV` and `\VVI` (D122, A625): the `deep` field of `aineo.explain`'s request; `aineo.explain.steer` (the float); the deep prompt; `--effort`; the kept key with the text, the model and the effort; `expl+` / `issue+` and the deep working words; `explain.deep_model`, `explain.deep_effort`, `explain.deep_timeout_ms`; the keys, `<Plug>` mappings, health, help and README.

## What was done, and why

1. **Settings** (`aineo.config`): `explain.deep_model` (`sonnet`), `explain.deep_effort` (`high`, one of five), `explain.deep_timeout_ms` (300000).
2. **Request** (`aineo.explain.request`): `arguments(command, options)` takes `model`, `tools` and `effort` as one table (a fourth positional argument would pass the three-parameter bound) and appends `--effort` last, so the plain requests' words are unchanged. `prompt()` takes a `steer`: the edited text, a blank line, the tie rule of the kind (shared with the plain prompt through `TIES`, so one rule has one text), a blank line, the numbered buffer. `default_steer()` builds the editable text.
3. **The float** (`aineo.explain.steer`): a thin file that knows nothing of explanations. It is handed a name (what the remembered text is kept under), a title, the default text and `on_send`; T151 passes its own.
4. **The flow** (`aineo.explain`): a deep request without a `steer` opens the float; sending asks again with the text. The kept key adds the text, the model and the effort as JSON, so no separator can make two requests collide. Labels are per placement (`record.deep[id]` in `marks`), because one range can hold answers of both depths.
5. **Entry and plugin**: `\VV` / `\VVI` in Normal and Visual mode through the existing explain orders with `deep = true`; `explain.deep_*` are read there.
6. **Health, help, README**: the prefix-key list and the Explain code section; `*aineo-explain-deep*`, the three settings, the two `<Plug>` mappings and the four key tags; the README's keys table, a paragraph and the settings.

## Decisions

- **No toggle-clear for a deep key** (A625 is silent): `\V` clears what its kind shows when pressed on the whole buffer; `\VV` opens the float instead, so a user can steer again over a shown answer. Clearing stays with the plain keys. A deep answer placed again from the kept one says `change the prompt to ask again`, since `:Aineo explain new` does not ask deep.
- **`Give each issue as an item of the answer's list.` stays in the fixed part** of the issues prompt: it is about the answer's structure, which the schema fixes, not about the steer.
- **Rejected**: a copy of each `Kind` for deep answers (a range holding both depths takes the first one's label); a deep word for `:Aineo explain` (not in A625).
- The text sent is `vim.trim`med, which is also the blank test.

## Tests and mutants

New files: `tests/test_explain_deep.lua` (the home: arguments, prompt, kept, float, look) and `tests/test_entry_explain_deep.lua` (the keys, defaults, settings, timeout). Changed: `tests/test_config.lua`, `test_doc.lua`, `test_health.lua`, `test_plugin.lua`. The fake `claude` runs every request; the real one never runs.

Mutants are listed in the pull request and the report; each was one literal edit to a pristine copy, run alone on the file that targets it and restored, and each was killed by an assertion (the failure printed `Failed expectation`).

## Fix round of PR #372 (A626)

The settled points of the first round (a deep key never toggle-clears; the kept-answer message; the float's size) are accepted by A626 rule 5 and live here, not in the D122 row. The review's findings, built as A626 says:

1. **Rule 1**: the deep prompt's fixed part says `The code asked about is the file X, lines a to b.` before the tie rule. `aineo.explain.steer` remembers a text with the default it was written over; the next float's first line (the head) is replaced by the new default's where it still equals the old default's. A head the user rewrote stays.
2. **Rule 2**: the send checks `range[2]` against the buffer (one warning, nothing sent, float closed); a buffer gone sends nothing and raises nothing.
3. **Rule 3**: one float at a time (`open_window`); `WinLeave` keeps the text as the kind's draft and closes the float on the next tick unless a send or a cancel finished it; a second call focuses the open float. `M.ask` is unchanged, so a send stops no run but the one `\V` would.
4. **Rule 4**: `bufhidden = 'wipe'` pinned by a buffer count over `q`, `<Esc>`, `<CR>`, `<C-w>p` and `:q`.

Measured on the committed fix: the buffer-gone guard (M30) is pinned by calling the `<CR>` mapping's callback under `pcall`, so the kill is an assertion, not the crash a key press would raise. Mutants (one literal edit each, a pristine copy, `tests/test_explain_deep.lua`, every kill an assertion): M30 `if false then` for the validity guard; M37 delete the `bufhidden` line (5 cases); stale-range guard `if false then`; head refresh `if false` and `if true`; the file in the fixed part replaced by `'other.lua'` (4 cases); the draft not remembered; `finished` ignored; the scheduled close removed (2 cases); the single-float guard `if false then`. A first attempt at the fixed-part mutant dropped `CODE_ASKED_ABOUT` and crashed `string.format`, so it was not counted as a kill and was replaced.

Counts: `test_explain_deep` 38 cases, `test_entry_explain_deep` 8, `test_explain` 110, `test_doc` 150, all with no fail; `make lint` clean.

## Open threads

- T151 (propose fix, D123) reuses `aineo.explain.steer` with its own default; nothing of it is built.
- Whether a deep key should also clear a shown answer when pressed on one is the user's call.
- The float's size (up to 100 columns, 6 to 20 rows) is the implementer's choice, not A625's.

## Commits

Recorded after the merge.

## Commits on dev

PR #372 into `dev`, rebased; released in `v0.2.81` (PR #373, `main` `9f24b4a6`).

- `963d86f8` Document the A626 float rules and record the fix round (T150)
- `0f577e3c` Keep one steering float, refuse a stale range, pin its wipe (A626, T150)
- `fa6d1d5f` Name the code asked about, and refresh a remembered head (A626, T150)
- `2110ad5c` Record D122, A625 and T150 in the v1 plan and a session note
- `fecfec30` Map \VV and \VVI to the deep request and configure it
- `6a261cae` Add the deep request and its steering float to the explain home
