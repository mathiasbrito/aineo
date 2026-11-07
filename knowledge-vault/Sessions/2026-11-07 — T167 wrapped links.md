# 2026-11-07 — T167 wrapped links

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `bugfix/t167-wrapped-links` (from `dev` at 8d0d3965) · **Pull request:** into `dev`

T167: a double-click or `gx` on a file name Claude Code wrapped across rows of its terminal followed only the piece on the clicked row (the user, 2026-11-07, in D88's row: "a file name in the claude pane that wraps, do not open when I double click, it considers only the content of the first line"). A small fix in the user's prompt-driven waves (D30).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D88's row (A715 inside it) and the T167 row
- `lua/aineo/entry/wrapped_links.lua` (new), `lua/aineo/entry/links.lua`, `lua/aineo/entry/tab.lua`, `tests/test_entry_links.lua`, `doc/aineo.txt` (`aineo-links`)

## Task lines

- [X] T167 Follow a link wrapped across rows of Claude's terminal (D88, A715): see the T167 row in the plan note.

## What was built

- `aineo.entry.wrapped_links` (a file of the entry home, pure over a row-text function): `covering(row_text, row, byte)` gives the joins that cover a byte, longest first. A join starts at a row's link that ends the row (A716: only `.`, `:`, `;`, `!` or `?` may follow it up to the row's last non-blank character, and the joined text runs to that character) and takes, from each next row, the first run of non-blank characters (leading blanks skipped), as `find_path_candidates()` reads the joined text; it goes on to a further row only when the run was the row's last and the link took it whole but for such punctuation; at most 4 rows.
- `entry/links.lua`: `locate()` is the one resolution (`:line`/`#L` fragment, `file://`, `~`, relative to the directory) that `open_link()` and the existence check of a join both use; `link_at()` follows the longest join that names something that exists, else the clicked row's own link; a join that is a web address names nothing. `map_link_keys()` is handed `directory`, a function.
- `entry/tab.lua`: `link_directory()` (the session's directory, else the current one) is handed to `map_link_keys()` and used by `follow_link()`; the old `follow_link()` handed `nil` to a relative path when the session had no directory.
- Help: `aineo-links` says so. The README says nothing of wrapped lines and is unchanged.

## Decisions (the implementer's, within A715)

1. The join is a separate file, `wrapped_links.lua`, inside the entry home rather than more lines in `links.lua`: it is pure and `links.lua` keeps the file-system rule.
2. The join is read by `find_path_candidates()` on the joined text, so trailing punctuation, `:line` and `:line:column` are those of one rule; a join that adds nothing to the head link is no join.
3. A continuation row's run need not look like a path by itself (`th` of `path`): only the joined text must.
4. Tests print rows with the fake `claude`'s echo (`\r` between rows), each padded with blanks to 90 cells so nothing the fake drew there earlier shows after the text.

## Spec conflicts and edges to raise

None. Left as the ruling has it: a click on a row's first run joins it backwards only to a link that ends the row above.

## Fix round (A716, review of the pull request)

- F1: `find_path_candidates()` leaves a trailing `.:;!?` out of a link, so a path a terminal broke after its dot or its colon (`…/abcdefghi.` / `lua:12`, `x.lua:` / `34`) had no link ending its row and no join. A head now counts when only those characters follow it up to the row's last non-blank character, and so does a chain's next row. Cases: rows `lua/x.lua:` / `2 now`; real autowrap, a path written with no newline and a filler sized from the window's width so that the terminal breaks it after the dot; the case `chain/.` that stopped a chain now goes on, as the ruling has it.
- Red of the fix round: the colon case opened the file at line 1, not 2; the autowrap case and the `chain/.` case opened nothing. F2's case passes on the code and is killed by the mutant that looks back one row only (`math.max(row - 1, 0)`).
- Mutants of the round, on the 17 wrapped-links cases, all killed: that one, a head that must end at the row's last character, a chain that needs the link to take the run whole, and the earlier set (indent anchor, caps at 3 and 5, line dropped, a join that always exists, no backward join, shortest first, row end untrimmed, no last-run check, web address checked as a path, `gx` in another directory).
- F3: one sentence in `aineo-links`.

## Verification

- Red: the first case (a double-click on the first row of a two-row path) handed `lua/` to the system; the second (a double-click on the continuation row) opened nothing; the three-row middle-row case and the five-row cap case each failed on a two-row join only. The cases for the indented row, the `:line` fragment, `gx`, and the fallbacks passed on first run, as the general join made them pass; they were checked by mutants instead.
- `tests/test_entry_links.lua`: 39 cases green after the fix round on the newest Neovim, `make lint` clean. No whole suite (D30).
- Mutants on the wrapped-links group (14 cases), each killed: the join anchored to the row's first character (indent), the cap at 3 and at 5, the line dropped, a join that always exists, no backward join, shortest first, the row end taken untrimmed, no check that the run is the row's last, no check that the link took the run whole (this one survived until the punctuation case was added), the web-address check removed (killed once a file named like a web address was added to the fixture project), `gx` looking in another directory.

## Commits

Recorded after the merge.

## Open threads

- Rows that Claude Code fills to the full width and wraps mid-word, with the break inside the `:line` fragment, join as one number (`x.lua:3` + `4` is line 34); no test.
- The Report is out of scope (A715 clause 4).
