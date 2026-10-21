local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local against = require('aineo.changes.against')

local T = MiniTest.new_set()

--- Full ids, one per letter.
local BASE, TIP, HEAD, PARENT, COMMIT, MERGE_BASE =
  ('b'):rep(40), ('7'):rep(40), ('e'):rep(40), ('9'):rep(40), ('c'):rep(40), ('d'):rep(40)

--- The working tree as a side stands for it.
local WORKING_TREE = { place = 'working tree' }

--- The empty tree as a side stands for it.
local EMPTY_TREE = { place = 'empty tree' }

--- A worktree other than the editor's, read from `base`, which came from
--- `origin`.
---
---@param base? string
---@param origin? table
---@return table
local function worktree(base, origin)
  return { top = '/tmp/other', base = base, base_origin = origin }
end

--- The sides of the diff of the files listed under `listed`.
---
---@param listed table the filter
---@param source? table what the session knows: `base`, `landed`, `branch`
---@param resolved? table what git told: `head`, `parent`, `merge_base`
---@return table
local function sides_of(listed, source, resolved)
  return against.sides(listed, false, source or {}, resolved or {})
end

--- The sides of the diff against `HEAD` of the files listed under `listed`.
---
---@param listed table the filter
---@param source? table
---@param resolved? table
---@return table
local function sides_against_head(listed, source, resolved)
  return against.sides(listed, true, source or {}, resolved or {})
end

T['the sides of a diff'] = MiniTest.new_set()

T['the sides of a diff']['under Session work are the session start and the working tree'] = function()
  eq(
    sides_of({ kind = 'session_work' }, { base = BASE }),
    { left = { id = BASE, words = 'session start' }, right = WORKING_TREE }
  )
end

T['the sides of a diff']['under Session work are the empty tree and the working tree before the first commit'] = function()
  eq(
    sides_of({ kind = 'session_work' }, { base = nil }),
    { left = EMPTY_TREE, right = WORKING_TREE }
  )
end

T['the sides of a diff']['under Uncommitted are HEAD and the working tree'] = function()
  eq(
    sides_of({ kind = 'uncommitted' }, {}, { head = HEAD }),
    { left = { id = HEAD, words = 'HEAD' }, right = WORKING_TREE }
  )
end

T['the sides of a diff']['under Uncommitted name HEAD alone until its commit is read'] = function()
  eq(sides_of({ kind = 'uncommitted' }), { left = { words = 'HEAD' }, right = WORKING_TREE })
end

T['the sides of a diff']['under a commit are its parent and itself, whichever list the commit is in'] = function()
  local commit = { id = COMMIT }
  local listings = {
    { kind = 'commit', commit = commit },
    { kind = 'commit', commit = commit, worktree = worktree(BASE) },
    { kind = 'commit', commit = commit, landed = 'origin/main' },
    { kind = 'commit', commit = commit, branch = 'feature' },
    { kind = 'commit', commit = commit, graph = true },
  }
  for _, listed in ipairs(listings) do
    eq(
      sides_of(listed, {}, { parent = PARENT }),
      { left = { id = PARENT, words = 'parent' }, right = { id = COMMIT } }
    )
  end
end

T['the sides of a diff']['under a root commit are the empty tree and the commit'] = function()
  eq(
    sides_of({ kind = 'commit', commit = { id = COMMIT } }, {}, { parent = false }),
    { left = EMPTY_TREE, right = { id = COMMIT } }
  )
end

T['the sides of a diff']['under a commit name the parent alone until it is read'] = function()
  eq(
    sides_of({ kind = 'commit', commit = { id = COMMIT } }),
    { left = { words = 'parent' }, right = { id = COMMIT } }
  )
end

T['the sides of a diff']['under Landed are the merge base with the working branch and its commit'] = function()
  eq(
    sides_of(
      { kind = 'landed', landed = 'origin/main' },
      { base = BASE, landed = { name = 'origin/main', tip = TIP } },
      { merge_base = MERGE_BASE }
    ),
    {
      left = { id = MERGE_BASE, words = 'merge base with origin/main' },
      right = { id = TIP },
    }
  )
end

T['the sides of a diff']['under Landed start from the empty tree where the session has no base'] = function()
  eq(
    sides_of(
      { kind = 'landed', landed = 'origin/main' },
      { base = nil, landed = { name = 'origin/main', tip = TIP } }
    ),
    { left = EMPTY_TREE, right = { id = TIP } }
  )
end

T['the sides of a diff']['under Landed start from the empty tree where the base shares no history'] = function()
  eq(
    sides_of(
      { kind = 'landed', landed = 'origin/main' },
      { base = BASE, landed = { name = 'origin/main', tip = TIP } },
      { merge_base = false }
    ),
    { left = EMPTY_TREE, right = { id = TIP } }
  )
end

T['the sides of a diff']['under Landed say what is unread by its words and a question mark'] = function()
  eq(
    sides_of({ kind = 'landed', landed = 'origin/main' }, { base = BASE }),
    { left = { words = 'merge base with origin/main' }, right = { place = '?' } }
  )
end

T['the sides of a diff']['under a local branch are its base, by where it came from, and its tip'] = function()
  local branch = {
    name = 'feature',
    tip = TIP,
    base = BASE,
    base_origin = { kind = 'merge_base', ref = 'origin/main' },
  }
  eq(sides_of({ kind = 'branch', branch = 'feature' }, { branch = branch }), {
    left = { id = BASE, words = 'merge base with origin/main' },
    right = { id = TIP },
  })
end

T['the sides of a diff']['under a local branch whose base an agent reported say so'] = function()
  local branch = {
    name = 'feature',
    tip = TIP,
    base = BASE,
    base_origin = { kind = 'reported' },
  }
  eq(
    sides_of({ kind = 'branch', branch = 'feature' }, { branch = branch }),
    { left = { id = BASE, words = 'reported base' }, right = { id = TIP } }
  )
end

T['the sides of a diff']['under a local branch with no base start from the empty tree'] = function()
  eq(
    sides_of({ kind = 'branch', branch = 'feature' }, { branch = { name = 'feature', tip = TIP } }),
    { left = EMPTY_TREE, right = { id = TIP } }
  )
end

T['the sides of a diff']['under another worktree are its base, by where it came from, and the working tree'] = function()
  local origin = { kind = 'merge_base', commit = ('a'):rep(40) }
  eq(
    sides_of({ kind = 'worktree', worktree = worktree(BASE, origin) }),
    { left = { id = BASE, words = 'merge base with aaaaaaa' }, right = WORKING_TREE }
  )
end

T['the sides of a diff']['under another worktree whose base an agent reported say so'] = function()
  eq(
    sides_of({ kind = 'worktree', worktree = worktree(BASE, { kind = 'reported' }) }),
    { left = { id = BASE, words = 'reported base' }, right = WORKING_TREE }
  )
end

T['the sides of a diff']['under another worktree with no base start from the empty tree'] = function()
  eq(
    sides_of({ kind = 'worktree', worktree = worktree(nil) }),
    { left = EMPTY_TREE, right = WORKING_TREE }
  )
end

T['the sides of a diff against HEAD'] = MiniTest.new_set()

T['the sides of a diff against HEAD']['from Session work, Uncommitted or a worktree run from HEAD to the working tree'] = function()
  local listings = {
    { kind = 'session_work' },
    { kind = 'uncommitted' },
    { kind = 'worktree', worktree = worktree(BASE, { kind = 'reported' }) },
  }
  for _, listed in ipairs(listings) do
    eq(
      sides_against_head(listed, { base = BASE }, { head = HEAD }),
      { left = { id = HEAD, words = 'HEAD' }, right = WORKING_TREE }
    )
  end
end

T['the sides of a diff against HEAD']['from a commit run from the commit to HEAD'] = function()
  eq(
    sides_against_head({ kind = 'commit', commit = { id = COMMIT } }, {}, { head = HEAD }),
    { left = { id = COMMIT }, right = { id = HEAD, words = 'HEAD' } }
  )
end

T['the sides of a diff against HEAD']['from Landed or a branch run from HEAD to the commit it stands for'] = function()
  eq(
    sides_against_head(
      { kind = 'landed', landed = 'origin/main' },
      { landed = { name = 'origin/main', tip = TIP } },
      { head = HEAD }
    ),
    { left = { id = HEAD, words = 'HEAD' }, right = { id = TIP } }
  )
  eq(
    sides_against_head(
      { kind = 'branch', branch = 'feature' },
      { branch = { name = 'feature', tip = TIP } },
      { head = HEAD }
    ),
    { left = { id = HEAD, words = 'HEAD' }, right = { id = TIP } }
  )
end

T['the commits a diff needs'] = MiniTest.new_set()

T['the commits a diff needs']['are HEAD under Uncommitted and in every diff against HEAD'] = function()
  eq(against.needs({ kind = 'uncommitted' }, false), { head = true })
  eq(against.needs({ kind = 'session_work' }, true), { head = true })
  eq(against.needs({ kind = 'commit', commit = { id = COMMIT } }, true), { head = true })
end

T['the commits a diff needs']['are the parent under a commit'] = function()
  eq(against.needs({ kind = 'commit', commit = { id = COMMIT } }, false), { parent = true })
end

T['the commits a diff needs']['are the merge base under Landed'] = function()
  eq(against.needs({ kind = 'landed', landed = 'origin/main' }, false), { merge_base = true })
end

T['the commits a diff needs']['are none under Session work, a worktree and a branch'] = function()
  eq(against.needs({ kind = 'session_work' }, false), {})
  eq(against.needs({ kind = 'worktree', worktree = worktree(BASE) }, false), {})
  eq(against.needs({ kind = 'branch', branch = 'feature' }, false), {})
end

T['the commits of a diff'] = MiniTest.new_set()

T['the commits of a diff']['are the ids of its sides, the left first, each once'] = function()
  eq(against.ids({ left = { id = BASE }, right = { id = TIP } }), { BASE, TIP })
  eq(against.ids({ left = { id = BASE }, right = { place = 'working tree' } }), { BASE })
  eq(against.ids({ left = { words = 'parent' }, right = { id = TIP } }), { TIP })
  eq(against.ids({ left = { id = BASE }, right = { id = BASE } }), { BASE })
end

local LABEL, ID, BRANCH, WORDS =
  'AineoChangesFilter', 'AineoChangesCommitId', 'AineoChangesReportedBranch', 'AineoChangesNote'

T['the heading line'] = MiniTest.new_set()

T['the heading line']['says the abbreviated id, the names and where the base came from, then the working tree'] = function()
  local text, colours = against.heading({
    left = { id = BASE, words = 'session start' },
    right = { place = 'working tree' },
  }, { [BASE] = { 'dev', 'origin/dev' } })

  eq(text, 'Against: bbbbbbb (dev, origin/dev) session start → working tree')
  eq(colours, {
    { first_column = 0, end_column = 8, group = LABEL },
    { first_column = 9, end_column = 16, group = ID },
    { first_column = 17, end_column = 34, group = BRANCH },
    { first_column = 35, end_column = 48, group = WORDS },
  })
end

T['the heading line']['shows the id alone before the names are read'] = function()
  local text = against.heading({
    left = { id = BASE, words = 'reported base' },
    right = { id = TIP },
  }, nil)

  eq(text, 'Against: bbbbbbb reported base → 7777777')
end

T['the heading line']['colours the id of the right side and its names too'] = function()
  local text, colours = against.heading(
    { left = { words = 'parent' }, right = { id = COMMIT } },
    { [COMMIT] = { 'feature' } }
  )

  eq(text, 'Against: parent → ccccccc (feature)')
  eq(colours, {
    { first_column = 0, end_column = 8, group = LABEL },
    { first_column = 9, end_column = 15, group = WORDS },
    { first_column = 20, end_column = 27, group = ID },
    { first_column = 28, end_column = 37, group = BRANCH },
  })
end

T['the heading line']['says the empty tree and an unread side in plain words'] = function()
  local text, colours = against.heading({
    left = { place = 'empty tree' },
    right = { place = '?' },
  }, nil)

  eq(text, 'Against: empty tree → ?')
  eq(colours, { { first_column = 0, end_column = 8, group = LABEL } })
end

T['the heading line']['says merge base with the reference it was taken against'] = function()
  local text = against.heading({
    left = { id = MERGE_BASE, words = 'merge base with origin/main' },
    right = { id = TIP },
  }, { [MERGE_BASE] = { 'main' }, [TIP] = { 'feature' } })

  eq(text, 'Against: ddddddd (main) merge base with origin/main → 7777777 (feature)')
end

T['the diff bar'] = MiniTest.new_set()

T['the diff bar']['says both sides with a double arrow, then the path'] = function()
  local bar = against.bar({
    left = { id = BASE, words = 'session start' },
    right = { place = 'working tree' },
  }, { [BASE] = { 'dev' } }, 'lua/a.txt')

  eq(
    bar,
    '%#AineoChangesCommitId#bbbbbbb%* %#AineoChangesReportedBranch#(dev)%*'
      .. ' %#AineoChangesNote#session start%* ↔ working tree  lua/a.txt'
  )
end

T['the diff bar']['has no path for a whole diff'] = function()
  local bar = against.bar({
    left = { words = 'HEAD' },
    right = { id = TIP },
  }, nil, nil)

  eq(bar, '%#AineoChangesNote#HEAD%* ↔ %#AineoChangesCommitId#7777777%*')
end

T['the diff bar']['doubles every percent sign, which the winbar would read as a code'] = function()
  local bar = against.bar({
    left = { id = BASE },
    right = { place = 'working tree' },
  }, { [BASE] = { 'fix-100%' } }, 'docs/100%.md')

  eq(
    bar,
    '%#AineoChangesCommitId#bbbbbbb%* %#AineoChangesReportedBranch#(fix-100%%)%*'
      .. ' ↔ working tree  docs/100%%.md'
  )
end

T['the names of a commit'] = MiniTest.new_set({
  parametrize = {
    { {}, '' },
    { { 'dev' }, '(dev)' },
    { { 'dev', 'origin/dev' }, '(dev, origin/dev)' },
    { { 'dev', 'origin/dev', 'v1' }, '(dev, origin/dev, v1)' },
    { { 'dev', 'origin/dev', 'v1', 'v2' }, '(dev, origin/dev, v1, …)' },
    { { 'a', 'b', 'c', 'd', 'e', 'f' }, '(a, b, c, …)' },
  },
})

T['the names of a commit']['are in parentheses, at most three of them, then an ellipsis, none for none'] = function(
  names,
  expected
)
  eq(against.names_text(names), expected)
end

T['the names of a commit']['are the empty text before they are read'] = function()
  eq(against.names_text(nil), '')
end

return T
