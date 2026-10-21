local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local lines = require('aineo.changes.lines')
local report_rules = require('aineo.changes.reports')

--- The moment the ages of these cases are counted to.
local NOW = 1800000000

--- A full commit id, the base of the branch below.
local BASE = '0123456789abcdef0123456789abcdef01234567'

--- The editor's own worktree's top level.
local OWN_TOP = '/projects/main'

--- The worktree `agent-1`, on `feature/a`, as git lists it.
local AGENT = { top = '/projects/agent-1', branch = 'feature/a' }

--- The nodes of the Reported section: the worktree `agent-1`, with the
--- branch `feature/b`, not checked out, and `feature/a`, checked out, both
--- from `BASE`.
local NODES = {
  {
    worktree = AGENT,
    label = 'T114 tree commits',
    at = NOW - 300,
    branches = { { name = 'feature/b', base = BASE }, { name = 'feature/a', base = BASE } },
  },
}

--- The commit whose id is `digit` repeated, written `minutes_ago` minutes
--- before `NOW` by `Ada`.
---
---@param digit string
---@param subject string
---@param minutes_ago integer
---@return aineo.git.Commit
local function commit(digit, subject, minutes_ago)
  return {
    id = digit:rep(40),
    subject = subject,
    author = 'Ada',
    authored_at = NOW - minutes_ago * 60,
  }
end

--- The commits window's page for the tree of `NODES`, the commits
--- `commits` read for the branch on line `at` of the tree
--- (`FEATURE_B`, `FEATURE_A`).
---
---@param at integer
---@param commits aineo.git.Commit[]|nil
---@return aineo.changes.Page
local function page_with_commits_at(at, commits)
  local tree = report_rules.tree_lines(NODES, OWN_TOP)
  tree[at].read_base = BASE
  tree[at].commits = commits
  return lines.commits_window({
    lists_filters = true,
    since = { commits = {}, base_is_ancestor = true },
    worktrees = { sections = {} },
    reported = tree,
    now = NOW,
  })
end

--- The third line of the tree, `feature/b`'s, for `page_with_commits_at()`.
local FEATURE_B = 3

--- The fourth line of the tree, `feature/a`'s.
local FEATURE_A = 4

local T = MiniTest.new_set()

T['the commits under a branch'] = MiniTest.new_set()

T['the commits under a branch']['are listed below its line, six cells in, newest first, as any commit line is'] = function()
  local newer, older = commit('2', 'Newer work', 5), commit('1', 'Older work', 90)

  local page = page_with_commits_at(FEATURE_B, { newer, older })

  eq(vim.list_slice(page.text, 4, 7), {
    '    feature/b from 0123456',
    '      2222222 Ada 5m               Newer work',
    '      1111111 Ada 1h               Older work',
    '    feature/a * from 0123456',
  })
end

T['the commits under a branch']['are listed below a checked-out branch’s line too'] = function()
  local page = page_with_commits_at(FEATURE_A, { commit('3', 'On the checked-out branch', 1) })

  eq(vim.list_slice(page.text, 5, 6), {
    '    feature/a * from 0123456',
    '      3333333 Ada 1m               On the checked-out branch',
  })
end

T['the commits under a branch']['colour the id, the author, the age and the subject as the commit lines of the window'] = function()
  local page = page_with_commits_at(FEATURE_B, { commit('2', 'Newer work', 5) })

  eq(page.colours[5], {
    { first_column = 6, end_column = 13, group = 'AineoChangesCommitId' },
    { first_column = 14, end_column = 17, group = 'AineoChangesCommitAuthor' },
    { first_column = 18, end_column = 20, group = 'AineoChangesCommitAge' },
    { first_column = 35, end_column = 45, group = 'AineoChangesCommitSubject' },
  })
end

T['the commits under a branch']['list the files of their commit, as a commit of a branch listed alone does'] = function()
  local newer = commit('2', 'Newer work', 5)

  local page = page_with_commits_at(FEATURE_B, { newer })

  eq(page.entries[5], {
    key = '\0branch\0feature/b\0' .. newer.id,
    commit = newer,
    filter = { kind = 'commit', commit = newer, branch = 'feature/b' },
  })
end

T['the commits under a branch']['are none for a branch with no commit past its base'] = function()
  local without = page_with_commits_at(FEATURE_B, {})
  local unread = page_with_commits_at(FEATURE_B, nil)

  eq(without.text, unread.text)
  eq(vim.list_slice(without.text, 4, 5), {
    '    feature/b from 0123456',
    '    feature/a * from 0123456',
  })
end

--- `count` commits, the first the newest, whose subjects are `Work 1` on.
---
---@param count integer
---@return aineo.git.Commit[]
local function commits_of(count)
  local made = {}
  for number = 1, count do
    table.insert(made, {
      id = ('%040x'):format(number),
      subject = 'Work ' .. number,
      author = 'Ada',
      authored_at = NOW - number * 60,
    })
  end
  return made
end

T['the commits under a branch']['stop at 20 with none left out, and say nothing more'] = function()
  local page = page_with_commits_at(FEATURE_B, commits_of(20))

  eq(#page.text, 4 + 20 + 1 + 3)
  eq(page.text[24], '      0000000 Ada 20m              Work 20')
  eq(page.text[25], '    feature/a * from 0123456')
end

T['the commits under a branch']['stop at 20, a line saying how many more there are in the group of notes'] = function()
  local page = page_with_commits_at(FEATURE_B, commits_of(23))

  eq(page.text[24], '      0000000 Ada 20m              Work 20')
  eq(page.text[25], '      … 3 more')
  eq(page.text[26], '    feature/a * from 0123456')
  eq(page.colours[25], { { first_column = 6, end_column = 16, group = 'AineoChangesNote' } })
end

T['the commits under a branch']['say one more, left out, for 21 commits'] = function()
  local page = page_with_commits_at(FEATURE_B, commits_of(21))

  eq(page.text[25], '      … 1 more')
end

T['the commits under a branch']['have a line saying more are left out that picks the branch, as its own line does'] = function()
  local page = page_with_commits_at(FEATURE_B, commits_of(21))

  eq(page.entries[25], page.entries[4])
  eq(page.entries[25].picks, {
    branch = 'feature/b',
    text = '[reported]     feature/b from 0123456',
  })
end

return T
