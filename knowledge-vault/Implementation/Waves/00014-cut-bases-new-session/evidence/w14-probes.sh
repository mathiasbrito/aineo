#!/usr/bin/env bash
# Wave 14's planning probes, as they were run on 2026-10-13: each step a
# plain command from the checkout's root, the fixture under the checkout's
# git-ignored `.tests/w14/`, since an agent's hooks refuse git run from a
# script or outside its worktree. Output: `w14-probes.txt`.
#
# P1  `git ls-tree -l -z` gives a blob's size in the call that finds it (A183).
# P2  a 128 MiB blob read whole, as `lua/aineo/git/content.lua` reads it
#     today, against a read that stops git once 1 MiB + 4 bytes have come
#     (A183). Run three times.
# P3  a worktree's base against an old detached HEAD of the editor (D32)
#     and against the working branch (A154), reconstructed from this
#     repository's own history, read-only.
#
# The fixture makes no commit: the blob is written with `hash-object` and its
# tree with `mktree`, which `ls-tree` and `cat-file` read as they read a
# commit's tree.
set -euo pipefail

# P1
mkdir -p .tests/w14/big
cd .tests/w14/big
git init -q -b main .
awk 'BEGIN { for (i = 0; i < 2097152; i++) printf "line %07d of a long text file, padded to 64 bytes...........\n", i }' > big.txt
printf 'small\n' > small.txt
big=$(git hash-object -w big.txt)
small=$(git hash-object -w small.txt)
tree=$(printf '100644 blob %s\tbig.txt\n100644 blob %s\tsmall.txt\n160000 commit 0123456789012345678901234567890123456789\tsub\n' "$big" "$small" | git mktree)
echo "$tree" > ../tree
ls -l big.txt | awk '{ print "big.txt bytes on disk: " $5 }'
git ls-tree -l -z --full-tree "$tree" big.txt small.txt sub | tr '\0' '\n'
git cat-file -s "$big"

# P2
cat > ../p2.lua <<'LUA'
local cap = 1048576 + 4
local function rss() return math.floor(vim.uv.resident_set_memory() / 1048576) end
local function whole(id)
  local t0, before = vim.uv.hrtime(), rss()
  local result = vim.system({ 'git', 'cat-file', 'blob', id }, { text = false }):wait()
  return (vim.uv.hrtime() - t0) / 1e6, #result.stdout, before, rss()
end
local function stopped(id)
  local t0, before = vim.uv.hrtime(), rss()
  local chunks, got, killed, sizes = {}, 0, false, {}
  local process
  process = vim.system({ 'git', 'cat-file', 'blob', id }, {
    text = false,
    detach = true,
    stdout = function(_, data)
      if data and got < cap then
        table.insert(chunks, data)
        table.insert(sizes, #data)
        got = got + #data
        if got >= cap and not killed then
          killed = true
          vim.uv.kill(-process.pid, 'sigkill')
        end
      end
    end,
  })
  local result = process:wait()
  local text = table.concat(chunks):sub(1, cap)
  return (vim.uv.hrtime() - t0) / 1e6, #text, before, rss(), result.signal, #sizes, sizes[1], result.stdout
end
local tree = vim.trim(io.open(arg[1]):read('a'))
local id = vim.trim(vim.system({ 'git', 'rev-parse', tree .. ':big.txt' }):wait().stdout)
local ms, bytes, before, after, signal, chunks, first, collected = stopped(id)
print(('stopped: %.0f ms, %d bytes kept, rss %d -> %d MiB, signal %d, %d chunks, first chunk %d bytes, result.stdout %s')
  :format(ms, bytes, before, after, signal, chunks, first, tostring(collected)))
collectgarbage('collect')
ms, bytes, before, after = whole(id)
print(('whole:   %.0f ms, %d bytes, rss %d -> %d MiB'):format(ms, bytes, before, after))
LUA
for _ in 1 2 3; do nvim --clean --headless -l ../p2.lua ../tree 2>&1; done
cd ../../..

# P3: T55's commit 090f6f6 stands for an agent's worktree HEAD forked from
# 8ea8f82, which was origin/dev's tip when T55 was dispatched; 1dc3186,
# wave 13's base, stands for an editor detached at an older dev.
git merge-base 090f6f6 1dc3186
git rev-list --count 1dc3186..090f6f6
git diff --name-only 1dc3186...090f6f6 | wc -l
git merge-base 090f6f6 8ea8f82
git rev-list --count 8ea8f82..090f6f6
git diff --name-only 8ea8f82...090f6f6 | wc -l
git worktree list --porcelain
