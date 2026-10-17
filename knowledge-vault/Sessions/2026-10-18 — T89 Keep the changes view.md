# 2026-10-18 — T89 Keep the changes view

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t89-keep-view` · **Pull request:** into `dev`

The changes pane remembers its focused view — the worktree, branch or reported set picked, and whether that view or the default view showed — across a quit and a restart, per Claude session; and `<S-CR>` in its files window opens the listed file for edition, in the worktree its line belongs to. Two commits, one per request, on one branch.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D82 (the user's words, A458–A464); C15, C9; D76, D77 (the focused view and the reported set this keeps)
- `doc/aineo.txt` — *aineo-changes-view-kept*, *aineo-changes-edit*

## Task lines

- [X] T89 The changes pane remembers its focused view per Claude session, and `<S-CR>` opens a listed file for edition (D82; C15, C9; A458–A464): `lua/aineo/changes/kept.lua` keeps the view beside the base and saves; `scope.lua` turns a view into a record and back as git now allows it; `copy.lua` keeps it as it changes and restores it silently; `open_file.lua` and the `<S-CR>` map open the file where it is checked out. Done on `feature/t89-keep-view`.

## The user's words

"I found one issue, when I quit aineo, and come back it do not remember the branch/tree/filters I was working on in the git panel"

"also a small change to the behavior of opening a file in the file list of the git pane, if the user press shift+enter, it opens the file in its current content in the specific worktree/branch for edition (no diff)."

## Design

**The view (A458–A461).** One file per Claude session, beside the base's: `<state>/aineo/changes-sessions/<sha256 of the session id>.view.json`, so no id makes a path and two ids never share one (the base's own helper, `kept_base_file()`, names the directory and the hash). It is JSON of this shape, never anything else:

```
{ "repository": "<top level>", "focused": true|false, "shows_reported": true|false,
  "scope": { "top": "<worktree>" } | { "branch": "<name>" } | absent,
  "reported": [ { "top": "<worktree>" } | { "branch": "<name>" }, … ] }
```

- Written by `keep_view()`, called from `show_commits()`, because every change of the view ends in a repaint of the commits window; it compares the record with the view last kept or read (`vim.deep_equal`) and writes only a difference, through `keep_file()` — the temporary file beside it, then a rename, as the base is. A write that fails is told once ("the changes pane cannot keep this session's view, and goes on without") and tried again when the view next changes.
- Read by `begin_view()`, called when the pane follows a session in a repository it has found (`follow_changes_session()`, and the look for the repository when the session was told first). It restores only when a record of this repository exists and the pane has picked and reported nothing yet; it then lists the worktrees and branches (`branch.read_candidates()`), and `scope.restored_view()` drops, untold, every member and pick git no longer lists, shows the focused view only while what it was of is left, and chooses the whole change of the first thing shown. While that read is out nothing is written (`restoring_view`), so the record is never overwritten by the default view. A pick made meanwhile, or before the session was followed, wins and is written over the record.
- Missing, unreadable, malformed (`as_kept_view()`), another repository's, or git unable to list the branches: ignored, the pane as it was; the record is left as it was until the view changes.
- Two tabs on two sessions keep two files; a pane that follows another session clears its view and takes that session's record. A hand-over (`hand_over_changes_session()`) moves the view file with the base.
- Not kept (A460): the pane the right column shows, cursors, expanded commits.
- No wiring in `entry/`: the composition root already hands the session id and the state directory to `follow_changes_session()`.

**`<S-CR>` (A462–A464).** `edit_file_at_cursor()` maps `<S-CR>` in the files buffer. `open_file.edit_place()` says where the file is: the other worktree an entry is listed under (`entry.worktree.top`), for a branch's file the worktree git lists with that branch checked out (read when the key is pressed, as the editor's own worktree may have checked it out since; only the last key's file opens and none when the cursor left the window), else the editor's own. `open_file.open_working_file()` is `open_listed_file()`'s body, so the path is taken whole and the refusals for a gone file and a directory are the same. A branch checked out nowhere opens the tip's file read-only through `show_commit_file()` with the branch's whole-change filter (also when the entry is one of the branch's commits), and aineo says once that the branch is checked out in no worktree. The help names tmux's `extended-keys` and `extended-keys-format` and the `extkeys` terminal feature, read in the tmux 3.8 manual on the host.

## Unit list

1. A worktree picked with `s` is shown again by the next editor following the session (the round trip).
2. The branch; the reported set (worktree and branch members); the pick behind the reported set; the default view shown, back at `\g`; what changes after a restore.
3. Written at once, whole, and not when nothing changed; a write that fails is told once; a write that fails leaves the old record.
4. Ignored: ten malformed shapes, another repository's, git unable to list the branches.
5. Gone since: a worktree, a branch, some members, all members, a pick behind the set, the set with a pick behind it.
6. Two sessions: two tabs, a session with no record, a pane that follows another session, one followed while the first is read back; a hand-over.
7. A pick made before the session was followed, and one made while the record is read back, win.
8. `<S-CR>`: own worktree; own worktree under a commit; a file gone (own and another worktree); another worktree with `:w`; five awkward names; a branch checked out in a worktree; checked out in the editor's own since the pick; checked out nowhere (the entry and a commit of the branch); git unable to list; a key pressed meanwhile; the cursor left meanwhile.

## Red and green

**Seen red:** `a restart | shows the worktree picked with s alone again` (the view after a restart was the default view); all 11 `tests/test_changes_edit_file.lua` cases of the first run (`<S-CR>` mapped to nothing: the buffer stayed `aineo://changes-files`, the messages empty). The implementation of the view was written whole after its first test, so the other view cases of `tests/test_changes_keep_view.lua` arrived green by nature (spent by that implementation); each is killed by a mutant below, which is its red. The `<S-CR>` cases added after the first run (own commit, own checkout since, listing failure, branch commit, two races) arrived green for the same reason and are killed likewise.

Two cases of an earlier draft were weak and were rebuilt before the mutants: the "untold" assertions passed before the restore ran (the pane begins as the default view), so each now waits for the record to be rewritten before it reads the messages, and a counter of the branch listings (`COUNT_BRANCH_LISTINGS`) pins that an ignored record reads nothing.

## Mutants, as literal edits (each run on the narrowed cases of its own group, one at a time, on the tree committed)

Every one was killed by an assertion on the pane's lines, the messages, a buffer's name or the record's text; two kills (`V19`'s "no reported set" case, `E09`) follow a raise of an error in the code, which stops the pane listing anything — an assertion failed, but by way of a crash.

| # | File: edit | Killed by |
|---|---|---|
| V01 | `copy.lua`: `if vim.deep_equal(view, session.kept_view) then return end` → `if true then return end` | a restart shows the worktree picked |
| V02 | same → `if false then` | the record is not written while the view never changes |
| V03 | `copy.lua`: `or session.restoring_view then` → `then` | a restart leaves the view kept untouched while the worktrees and branches are read |
| V04 | `copy.lua`: `if not (on_disk and on_disk.repository == repository and has_no_view()) then` → `if not (on_disk and has_no_view()) then` | the record of another repository is ignored |
| V05 | `copy.lua`: `if not candidates or not has_no_view() then` → `if not candidates then` | a restart gives way to a pick made while the view kept is read back |
| V06 | `copy.lua`: `kept.read_kept_view(followed.state_directory, followed.id)` → the first test session's id as a literal | two sessions start with the default view when the session has no view kept |
| V07 | `copy.lua`: delete `session.kept_view, session.restoring_view = nil, false` in `follow_changes_session()` | two sessions followed while the view of another is read back keep their own |
| V08 | `copy.lua`: the `kept.move_kept_view(...)` call in `hand_over_changes_session()` → `nil` | a hand-over moves the view |
| V09 | `scope.lua`: `M.still_listed(vim.tbl_map(member_of_pick, kept.reported), candidates)` → `vim.tbl_map(member_of_pick, kept.reported)` | gone view: the members, the whole set |
| V10 | `scope.lua`: `kept.scope and M.still_listed({ member_of_pick(kept.scope) }, candidates)[1]` → `kept.scope and member_of_pick(kept.scope)` | gone view: a worktree removed, a branch deleted |
| V11 | `scope.lua`: `elseif kept.focused then shown = picked` → `else shown = picked` | a restart shows the default view when it was shown |
| V12 | `scope.lua`: `kept.shows_reported and #reported > 0` → `kept.shows_reported` | gone view: the set gone, the pick behind it at `\g` |
| V13 | `scope.lua`: `selected = shown and M.whole_change_of(shown) or nil,` → `selected = nil,` | the worktree and the branch picked, files window heading |
| V14 | `copy.lua`: delete `if session.shown then read_commits(false) end` after the restore | a restart reads the branch of the reported set after the pane read its own lists |
| V15 | `kept.lua`: `or replace_file(file, vim.json.encode(value))` → `or write_file(...)` | the record is replaced whole: a write that fails leaves the view as it was |
| V16 | `copy.lua`: delete the `if view_failure_told then return end` guard | the record that cannot be written is told once |
| V17 | `kept.lua`: delete `or type(decoded.focused) ~= 'boolean'` | malformed: a focused flag that is no boolean |
| V18 | `kept.lua`: delete `or type(decoded.shows_reported) ~= 'boolean'` | malformed: a reported flag that is no boolean |
| V19 | `kept.lua`: delete `or not vim.islist(decoded.reported)` | malformed: no reported set, a set that is no list |
| V20 | `kept.lua`: `and branch == nil then` → `then` in `as_kept_pick()` | malformed: a pick of both |
| V21 | `kept.lua`: `'.view.json'` → `'.json'` | the record is written when the view changes |
| V22 | `copy.lua`: delete `session.kept_view = scope.kept_view_of(repository, current)` in the failed-read branch | a view that is gone stays kept when git cannot list the branches |
| V23 | `copy.lua`: `on_disk.repository == repository and has_no_view()) then` → `on_disk.repository == repository) then` | a restart gives way to a pick made before the session was followed |
| E01 | `copy.lua`: `'<S-CR>'` → `'<S-F9>'` in the map | opens the file as it is in the own worktree |
| E02 | `open_file.lua`: `if entry.worktree then return { top = entry.worktree.top }` → `if false then …` | opens the file as it is now in the worktree picked |
| E03 | `open_file.lua`: `if checkout then return { top = checkout.top }` → `if false then …` | the branch checked out in a worktree, and in the own worktree since |
| E04 | `open_file.lua`: delete the `entry.worktree` branch of `edit_place()` | the worktree picked |
| E05 | `copy.lua`: `show_commit_file(vim.tbl_extend('force', entry, { filter = filter.of_branch(place.branch) }))` → `show_commit_file(entry)` | a file under a commit of a branch checked out nowhere |
| E06 | `copy.lua`: delete the `vim.notify(open_file.branch_checked_out_nowhere(...))` | a branch checked out nowhere, told once |
| E07 | `copy.lua`: delete `this_key ~= enters or` | a key pressed while git lists the worktrees |
| E08 | `copy.lua`: delete `or vim.api.nvim_get_current_win() ~= pressed_in` | the cursor left the window |
| E09 | `copy.lua`: delete the `if failure then … return end` after `list_worktrees` | worktrees that cannot be listed |
| E10 | `open_file.lua`: `magic = { file = false, bar = false }` → `{ file = true, bar = true }` | the awkward names (`100% #1.txt`, the backtick command) |
| E11 | `open_file.lua`: `if not vim.uv.fs_lstat(file) then` → `if false then` | a file deleted, own and another worktree |
| E12 | `open_file.lua`: delete `if not branch then return { top = own_top } end` | the own worktree, a file under a commit of the editor's own |

## Verification

- `tests/test_changes_keep_view.lua`: 49 cases; `tests/test_changes_edit_file.lua`: 17 cases; both green after the last edit, as were `tests/test_doc.lua`, `tests/test_changes_announce.lua`, `tests/test_changes_sessions.lua`, `tests/test_changes_open_file.lua` and `tests/test_changes_keys.lua`.
- The whole suite once, on the tree pushed, on Neovim 0.12.5 on the host, `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test`: 4559 cases in 116 files, `Fails (0)`, exit status 0.
- `make lint`: 0 errors, 0 warnings, 0 parse errors.

## Limits

- The restore reads the worktrees and branches once at follow time: a worktree added in between is not part of it, as `s` would not offer it either.
- `<S-CR>` on a directory, a submodule or a nested repository is refused by the code `gf` shares, and pinned by `gf`'s own cases (`tests/test_changes_open_file.lua`); the new file has no case of it.
- `<S-CR>` is not a `<Plug>` mapping (A464: no other key); it is a buffer-local map of the files window, as `gf` is.
- The terminal that does not tell Shift+Enter from Enter cannot reach it; the help says so and names tmux's options.

## Commits

*Recorded after the merge.*
