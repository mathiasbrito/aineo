# git commit --allow-empty rewrites the index, while reset --soft and update-ref do not

**Tags:** #git #watch #testing
**Discovered:** [[Sessions/2026-10-05 — T25 Changes pane]] (the author's measurement for mutant K4; the records review of PR #112, finding 7; its test review, finding 10)
**Applies to:** [[Projects/aineo]]

## The insight

On git 2.50.1, `git commit --allow-empty` writes a new `.git/index`, though it changes no file: the index's inode changes. `git reset --soft HEAD~1`, and a commit made with `git commit-tree` and moved to with `git update-ref`, leave the index untouched, with the same inode and modification time. So a watch that counts an index write as a change of the working tree's files sees an empty commit as a file change too. Only a branch move that writes no index is seen as a branch move alone.

## Why it matters

The git home's watch reports two things for each burst of events: `files_changed`, which an index write sets (`changes_the_list()` in `lua/aineo/git/watch.lua`, the orchestrator's decision for T23, MR189), and `branch_moved`. D22 asks the changes pane to read its commits on every commit, even one that changes no file. A test that wants to tell "commits read when the branch moves" from "commits read when files change" therefore needs a commit that writes no index. With `--allow-empty` both flags are set, and code that reads the commits on either one passes.

## How it showed up here

- **The mutant that survived.** T25's K4 reads the commits window only on `files_changed`, where the code reads it on `branch_moved`. The first form of D22's case made its commit with `git commit --allow-empty`, and K4 survived it: the author measured the index rewritten, so the watch reported `files_changed` with the branch move. The test review confirmed that K4 survives that form (its K4ALT).
- **The case reworked.** The case now makes its commit with `git commit-tree HEAD^{tree} -p HEAD` and moves the branch with `git update-ref` (`tests/test_changes.lua`). K4 dies there by assertion: the commits window kept `Add the marker` where `Nothing` was expected.
- **"The only way" was wrong.** The author's commit message (`6cf587c` on the branch, `791b7f1` on `dev`) called `commit-tree` with `update-ref` "the only way" to tell K4 apart. The records review measured `git reset --soft HEAD~1` leaving the index's inode and modification time as they were, so a soft reset is another branch move with no index write. The fix round's commit message (`f7c246b`, `3fe9c47` on `dev`) corrects it; the history is not rewritten.

## Where it applies again

Any test of a watch or a cache keyed on `.git/index`, `HEAD` or the refs: say which git commands write the index before choosing one to make the event. The new inode means git put a new file in the index's place rather than writing into it, which a watch on the file itself does not survive: [[Learnings/A watch on a file git replaces goes silent after the replacement]]. Measured on git 2.50.1 only.
