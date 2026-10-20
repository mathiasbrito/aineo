local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local lines = require('aineo.changes.lines')
local report_rules = require('aineo.changes.reports')
local scope = require('aineo.changes.scope')

--- The moment the ages of these cases are counted to.
local NOW = 1800000000

--- A full commit id, the base of the reports below.
local BASE = '0123456789abcdef0123456789abcdef01234567'

--- The worktree `agent-1` on `feature/a`, as the commits window lists it.
local AGENT = { top = '/projects/agent-1', branch = 'feature/a' }

--- What the commits window knows of a session with no commit and no other
--- worktree, the reports `reports` given.
---
---@param reports table[]
---@return aineo.changes.CommitsView
local function view_with(reports)
  return {
    lists_filters = true,
    since = { commits = {}, base_is_ancestor = true },
    worktrees = { sections = {} },
    reports = reports,
    now = NOW,
  }
end

local T = MiniTest.new_set()

T['the Reported section'] = MiniTest.new_set()

T['the Reported section']['is not listed while the session has no report'] = function()
  local page = lines.commits_window(view_with({}))

  eq(page.text, { 'Uncommitted', 'Session work', 'No commits on this session' })
end

T['the Reported section']['lists each report above Uncommitted, in the order given, one line each'] = function()
  local reports = {
    {
      member = { worktree = AGENT },
      report = { kind = 'worktree', base = BASE, label = 'T108 reported work', at = NOW - 300 },
    },
    {
      member = { branch = { name = 'feature/b' } },
      report = { kind = 'branch', base = BASE, at = NOW - 2 * 3600 },
    },
  }

  local page = lines.commits_window(view_with(reports))

  eq(page.text, {
    'Reported',
    'worktree feature/a from 0123456 T108 reported work 5m',
    'branch feature/b from 0123456 2h',
    'Uncommitted',
    'Session work',
    'No commits on this session',
  })
end

T['the Reported section']['colours its heading, and each line’s base, label and age, in their groups'] = function()
  local reports = {
    {
      member = { worktree = AGENT },
      report = { kind = 'worktree', base = BASE, label = 'T108 reported work', at = NOW - 300 },
    },
  }

  local page = lines.commits_window(view_with(reports))

  eq({ page.colours[1], page.colours[2] }, {
    { { first_column = 0, end_column = 8, group = 'AineoChangesReportedHeading' } },
    {
      { first_column = 24, end_column = 31, group = 'AineoChangesCommitId' },
      { first_column = 32, end_column = 50, group = 'AineoChangesReportedLabel' },
      { first_column = 51, end_column = 53, group = 'AineoChangesReportedAge' },
    },
  })
end

T['the Reported section']['lists on each line the whole change of its work, and what Enter picks'] = function()
  local reports = {
    {
      member = { worktree = AGENT },
      report = { kind = 'worktree', base = BASE, label = 'T108 reported work', at = NOW },
    },
    { member = { branch = { name = 'feature/b' } }, report = { kind = 'branch', base = BASE } },
  }

  local page = lines.commits_window(view_with(reports))

  eq({ page.entries[1], page.entries[2], page.entries[3] }, {
    nil,
    {
      key = '/projects/agent-1\0\0worktree',
      filter = { kind = 'worktree', worktree = AGENT },
      worktree = AGENT,
      picks = {
        top = '/projects/agent-1',
        text = '[reported] feature/a from 0123456  T108 reported work',
      },
    },
    {
      key = '\0branch\0feature/b',
      filter = { kind = 'branch', branch = 'feature/b' },
      picks = { branch = 'feature/b', text = '[reported] feature/b from 0123456' },
    },
  })
end

T['the Reported section']['shows the base its work was last read from, in place of the reported one'] = function()
  local read_from = ('c'):rep(40)
  local reports = {
    {
      member = {
        worktree = {
          top = AGENT.top,
          branch = AGENT.branch,
          base = read_from,
          listed = { commits = {} },
        },
      },
      report = { kind = 'worktree', base = BASE, at = NOW },
    },
    {
      member = { branch = { name = 'feature/b', tip = BASE, base = read_from, commits = {} } },
      report = { kind = 'branch', base = BASE, at = NOW },
    },
  }

  local page = lines.commits_window(view_with(reports))

  eq(
    { page.text[2], page.text[3] },
    { 'worktree feature/a from ccccccc now', 'branch feature/b from ccccccc now' }
  )
end

T['the Reported section']['names a detached worktree by its folder'] = function()
  local reports = {
    {
      member = { worktree = { top = '/projects/agent-2' } },
      report = { kind = 'worktree', base = BASE, at = NOW },
    },
  }

  local page = lines.commits_window(view_with(reports))

  eq(page.text[2], 'worktree agent-2 from 0123456 now')
end

T['the Reported section']['says from ? for a report kept before reports gave a base, and no age when untimed'] = function()
  local reports = { { member = { worktree = AGENT }, report = { kind = 'worktree' } } }

  local page = lines.commits_window(view_with(reports))

  eq(page.text[2], 'worktree feature/a from ?')
end

T['the Reported section']['shows a control character of the label as a space'] = function()
  local reports = {
    {
      member = { worktree = AGENT },
      report = { kind = 'worktree', base = BASE, label = 'a\tb\27c', at = NOW },
    },
  }

  local page = lines.commits_window(view_with(reports))

  eq(page.text[2], 'worktree feature/a from 0123456 a b c now')
end

T['the order'] = MiniTest.new_set()

T['the order']['is newest first, an untimed report after every timed one, later before earlier'] = function()
  local entries = {
    { member = { branch = { name = 'a' } }, report = { kind = 'branch', at = NOW - 60 } },
    { member = { branch = { name = 'b' } }, report = { kind = 'branch' } },
    { member = { branch = { name = 'c' } }, report = { kind = 'branch', at = NOW } },
    { member = { branch = { name = 'd' } }, report = { kind = 'branch', at = NOW - 60 } },
    { member = { branch = { name = 'e' } }, report = { kind = 'branch' } },
  }

  local ordered = report_rules.newest_first(entries)

  eq(
    vim.tbl_map(function(entry)
      return entry.member.branch.name
    end, ordered),
    { 'c', 'd', 'a', 'e', 'b' }
  )
end

T['the list s offers'] = MiniTest.new_set()

T['the list s offers']['holds each report first, then all reported work, then the worktrees and branches'] = function()
  local report_items = {
    { branch = 'feature/b', text = '[reported] feature/b from 0123456' },
    { top = AGENT.top, text = '[reported] feature/a from 0123456  T108' },
  }
  local reported = { { worktree = AGENT }, { branch = { name = 'feature/b' } } }
  local others = { sections = { AGENT } }
  local candidates = {
    branches = { { name = 'main' }, { name = 'feature/b' }, { name = 'lonely' } },
    worktrees = { { top = '/projects/main', branch = 'main' }, AGENT },
  }

  local items = scope.items_of(others, candidates, reported, report_items)

  eq(
    vim.tbl_map(function(item)
      return item.text
    end, items),
    {
      '[reported] feature/b from 0123456',
      '[reported] feature/a from 0123456  T108',
      '[reported] All reported work (2)',
      '[worktree] agent-1 (feature/a)',
      '[branch] feature/b',
      '[branch] lonely',
    }
  )
end

T['the base a report is read from'] = MiniTest.new_set()

--- Two commits: the base an agent reported, and the pane's own base for the
--- same work.
local REPORTED, OWN = ('a'):rep(40), ('b'):rep(40)

T['the base a report is read from']['is the reported one or the pane’s own, as their history says'] =
  MiniTest.new_set({
    parametrize = {
      {
        'the reported base descends from the pane’s',
        REPORTED,
        OWN,
        { reported_in_tip = true, own_before_reported = true },
        REPORTED,
      },
      {
        'the pane’s base descends from the reported one',
        REPORTED,
        OWN,
        { reported_in_tip = true, own_before_reported = false },
        OWN,
      },
      {
        'the reported base is no longer behind the tip',
        REPORTED,
        OWN,
        { reported_in_tip = false, own_before_reported = true },
        OWN,
      },
    },
  })

T['the base a report is read from']['is the reported one where the pane has no base of its own'] = function()
  eq(
    report_rules.effective_base(
      REPORTED,
      nil,
      { reported_in_tip = true, own_before_reported = false }
    ),
    REPORTED
  )
end

T['the base a report is read from']['is the reported one or the pane’s own, as their history says']['when'] = function(
  _,
  reported,
  own,
  ancestry,
  expected
)
  eq(report_rules.effective_base(reported, own, ancestry), expected)
end

T['the base a report is read from']['is the pane’s own for a report that gave none'] = function()
  eq(
    report_rules.effective_base(nil, OWN, { reported_in_tip = false, own_before_reported = false }),
    OWN
  )
end

T['a report made again'] = MiniTest.new_set()

--- Reports of one worktree: two calls of the tool, and two of aineo's hook.
local CALL_1 = { kind = 'worktree', base = BASE, label = 'first', at = NOW - 60 }
local CALL_2 = { kind = 'branch', base = ('f'):rep(40), label = 'second', at = NOW }
local HOOK_1 = { kind = 'worktree', base = BASE, at = NOW - 60, by_hook = true }
local HOOK_2 = { kind = 'worktree', base = ('e'):rep(40), at = NOW, by_hook = true }

T['a report made again']['with none before is the report, the tool’s or the hook’s'] = function()
  eq({ report_rules.merged(nil, CALL_1), report_rules.merged(nil, HOOK_1) }, { CALL_1, HOOK_1 })
end

T['a report made again']['by the tool replaces any before; by the hook keeps the one before'] =
  MiniTest.new_set({
    parametrize = {
      { CALL_1, CALL_2, CALL_2 },
      { HOOK_1, CALL_2, CALL_2 },
      { CALL_1, HOOK_2, CALL_1 },
      { HOOK_1, HOOK_2, HOOK_1 },
    },
  })

T['a report made again']['by the tool replaces any before; by the hook keeps the one before']['given'] = function(
  before,
  again,
  kept
)
  eq(report_rules.merged(before, again), kept)
end

T['a report made again']['by the hook for a branch made in that work takes the branch and its base, the label kept'] = function()
  local before =
    { kind = 'worktree', base = BASE, label = 'task', at = NOW - 60, on_branch = 'feature/a' }
  local again =
    { kind = 'branch', base = ('e'):rep(40), at = NOW, by_hook = true, on_branch = 'feature/b' }

  local kept = report_rules.merged(before, again)

  eq(kept, {
    kind = 'worktree',
    base = ('e'):rep(40),
    label = 'task',
    at = NOW,
    by_hook = true,
    on_branch = 'feature/b',
  })
end

T['a report made again']['by the hook on the branch the work was on keeps the one before'] = function()
  local before =
    { kind = 'worktree', base = BASE, label = 'task', at = NOW - 60, on_branch = 'feature/a' }
  local again =
    { kind = 'branch', base = ('e'):rep(40), at = NOW, by_hook = true, on_branch = 'feature/a' }

  eq(report_rules.merged(before, again), before)
end

return T
