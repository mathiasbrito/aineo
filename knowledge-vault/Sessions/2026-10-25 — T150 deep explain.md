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

## Open threads

- T151 (propose fix, D123) reuses `aineo.explain.steer` with its own default; nothing of it is built.
- Whether a deep key should also clear a shown answer when pressed on one is the user's call.
- The float's size (up to 100 columns, 6 to 20 rows) is the implementer's choice, not A625's.

## Commits

Recorded after the merge.
