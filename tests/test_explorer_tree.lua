local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local tree = require('aineo.explorer.tree')

--- The view of a tree no key has changed: nothing unfolded, no mark,
--- ignored entries hidden, dotfiles shown, no filter.
---
---@param changes? table the fields that differ
---@return aineo.explorer.View
local function view(changes)
  return vim.tbl_extend('force', {
    open = {},
    marks = {},
    show_ignored = false,
    show_dotfiles = true,
  }, changes or {})
end

--- The lines `tree.render()` gives for the folders `paths` make, under
--- `view`, without the header line.
---
---@param paths string[]
---@param shown aineo.explorer.View
---@return string[]
local function body(paths, shown)
  local lines = tree.render(tree.from_paths(paths), shown).lines
  return vim.list_slice(lines, 2)
end

local T = MiniTest.new_set()

T['the tree'] = MiniTest.new_set()

T['the tree']['lists folders first, then files, each alphabetically, folders folded'] = function()
  local paths = { 'zeta.txt', 'src/main.lua', 'Alpha.md', 'docs/guide.md', 'beta.txt' }

  local lines = body(paths, view())

  eq(lines, {
    '▸   docs/',
    '▸   src/',
    '    Alpha.md',
    '    beta.txt',
    '    zeta.txt',
  })
end

T['the tree']['shows an unfolded folder’s entries below it, one indent deeper'] = function()
  local paths = { 'src/lib/util.lua', 'src/main.lua', 'src/zed/z.lua', 'top.txt' }

  local lines = body(paths, view({ open = { src = true, ['src/lib'] = true } }))

  eq(lines, {
    '▾   src/',
    '  ▾   lib/',
    '        util.lua',
    '  ▸   zed/',
    '      main.lua',
    '    top.txt',
  })
end

T['the tree']['puts a file’s mark before its name'] = function()
  local paths = { 'changed.txt', 'kept.txt', 'new.txt', 'gone.txt' }
  local marks = { ['changed.txt'] = 'M', ['new.txt'] = '?', ['gone.txt'] = 'D' }

  local lines = body(paths, view({ marks = marks }))

  eq(lines, {
    '  M changed.txt',
    '  D gone.txt',
    '    kept.txt',
    '  ? new.txt',
  })
end

T['the tree']['marks each folder that holds a change, however deep, with one mark'] = function()
  local paths = { 'src/lib/a.lua', 'src/lib/b.lua', 'src/c.lua', 'docs/d.md' }
  local marks = { ['src/lib/a.lua'] = 'M', ['src/lib/b.lua'] = '?' }

  local lines = body(paths, view({ marks = marks, open = { src = true } }))

  eq(lines, {
    '▸   docs/',
    '▾ • src/',
    '  ▸ • lib/',
    '      c.lua',
  })
end

T['the tree']['hides dotfiles and dot folders while dotfiles are hidden'] = function()
  local paths = { '.env', '.config/x.toml', 'src/.keep', 'src/a.lua', 'b.txt' }

  local lines = body(paths, view({ show_dotfiles = false, open = { src = true } }))

  eq(lines, {
    '▾   src/',
    '      a.lua',
    '    b.txt',
  })
end

T['the tree']['never shows a file named .git, as a linked worktree has'] = function()
  local read = tree.add_listing(
    { children = {} },
    '',
    { { name = '.git', kind = 'file' }, { name = 'a.txt', kind = 'file' } }
  )

  local lines = tree.render(read, view()).lines

  eq(vim.list_slice(lines, 2), { '    a.txt' })
end

T['the tree']['never shows a folder named .git, dotfiles shown or not'] = function()
  local paths = { '.git/config', '.gitignore', 'a.txt' }

  local lines = body(paths, view())

  eq(lines, {
    '    .gitignore',
    '    a.txt',
  })
end

--- A listing with ignored entries: a tracked file beside an ignored one in
--- `build/`, an ignored folder git gave whole, and a folder holding only an
--- ignored file.
local LISTED = { 'build/keep.txt', 'a.txt' }
local IGNORED = { 'build/out.o', 'node_modules/', 'cache/tmp/x.bin', 'debug.log' }

T['the tree']['hides what git ignores while ignored entries are hidden'] = function()
  local listed = tree.from_paths(LISTED, IGNORED)

  local lines = tree.render(listed, view({ open = { build = true } })).lines

  eq(vim.list_slice(lines, 2), {
    '▾   build/',
    '      keep.txt',
    '    a.txt',
  })
end

T['the tree']['shows what git ignores while ignored entries are shown, an ignored folder folded'] = function()
  local listed = tree.from_paths(LISTED, IGNORED)

  local lines = tree.render(listed, view({ show_ignored = true, open = { build = true } })).lines

  eq(vim.list_slice(lines, 2), {
    '▾   build/',
    '      keep.txt',
    '      out.o',
    '▸   cache/',
    '▸   node_modules/',
    '    a.txt',
    '    debug.log',
  })
end

T['the filter'] = MiniTest.new_set()

--- The files the filter cases list.
local FILTERED =
  { 'src/Util.lua', 'src/main.lua', 'src/lib/utils/x.lua', 'docs/guide.md', 'README' }

T['the filter']['shows the files whose path holds it, ignoring case, in their folders, unfolded'] = function()
  local lines = body(FILTERED, view({ filter = 'UTIL' }))

  eq(lines, {
    '▾   src/',
    '  ▾   lib/',
    '    ▾   utils/',
    '          x.lua',
    '      Util.lua',
  })
end

T['the filter']['says so in a line when no file matches'] = function()
  local lines = body(FILTERED, view({ filter = 'nothing' }))

  eq(lines, { '  no file matches “nothing”' })
end

T['a repository’s listing'] = MiniTest.new_set()

--- What git lists of a repository whose top holds the tree's root as `sub`:
--- its files, those that changed, and those it ignores.
local REPOSITORY_LISTING = {
  files = { 'outside.txt', 'sub/kept.txt', 'sub/changed.txt', 'sub/dir/added.txt', 'sub/new.txt' },
  changes = {
    { path = 'outside.txt', kind = 'modified' },
    { path = 'sub/changed.txt', kind = 'modified' },
    { path = 'sub/dir/added.txt', kind = 'added' },
    { path = 'sub/new.txt', kind = 'untracked' },
    { path = 'sub/gone.txt', kind = 'deleted' },
    { path = 'sub/moved.txt', kind = 'renamed', old_path = 'sub/was.txt' },
    { path = 'sub/link', kind = 'type_changed' },
  },
  ignored = { 'sub/build/', 'other.log' },
}

T['a repository’s listing']['gives the files under the root, its deleted ones and their marks'] = function()
  local read = tree.from_repository(REPOSITORY_LISTING, 'sub')

  local lines = tree.render(read.tree, view({ marks = read.marks, open = { dir = true } })).lines

  eq(vim.list_slice(lines, 2), {
    '▾ • dir/',
    '    A added.txt',
    '  M changed.txt',
    '  D gone.txt',
    '    kept.txt',
    '  T link',
    '  R moved.txt',
    '  ? new.txt',
  })
end

T['a repository’s listing']['gives the ignored entries under the root'] = function()
  local read = tree.from_repository(REPOSITORY_LISTING, 'sub')

  local lines = tree.render(read.tree, view({ marks = read.marks, show_ignored = true })).lines

  eq(lines[2], '▸   build/')
end

T['a repository’s listing']['at the repository’s top gives every file'] = function()
  local read = tree.from_repository({ files = { 'a', 'sub/b' }, changes = {} }, '')

  local lines = tree.render(read.tree, view()).lines

  eq(vim.list_slice(lines, 2), { '▸   sub/', '    a' })
end

T['a repository’s listing']['shows a nested repository and a submodule as folders read from disk, the untracked one marked'] = function()
  local listing = {
    files = { 'a.txt', 'nested/', 'vendor/lib' },
    changes = { { path = 'nested/', kind = 'untracked' } },
    submodules = { 'vendor/lib' },
  }

  local read = tree.from_repository(listing, '')
  local lines = tree.render(read.tree, view({ marks = read.marks, open = { vendor = true } })).lines

  eq(vim.list_slice(lines, 2), { '▸ ? nested/', '▾   vendor/', '  ▸   lib/', '    a.txt' })
  eq(
    { tree.is_known(read.tree, 'nested'), tree.is_known(read.tree, 'vendor/lib') },
    { false, false }
  )
end

T['a folder read from disk'] = MiniTest.new_set()

T['a folder read from disk']['shows the entries listed for it, and is not known before'] = function()
  local root = tree.add_listing(
    { children = {} },
    '',
    { { name = 'lib', kind = 'folder' }, { name = 'a.txt', kind = 'file' } }
  )
  local read = tree.add_listing(root, 'lib', { { name = 'b.txt', kind = 'file' } })

  local before = tree.render(root, view({ open = { lib = true } })).lines
  local after = tree.render(read, view({ open = { lib = true } })).lines

  eq({ tree.is_known(root, 'lib'), tree.is_known(read, 'lib') }, { false, true })
  eq(vim.list_slice(before, 2), { '▾   lib/', '    a.txt' })
  eq(vim.list_slice(after, 2), { '▾   lib/', '      b.txt', '    a.txt' })
end

T['a folder read from disk']['inside an ignored folder lists ignored entries'] = function()
  local listed = tree.from_paths({ 'a.txt' }, { 'node_modules/' })
  local read = tree.add_listing(listed, 'node_modules', { { name = 'pkg', kind = 'folder' } })

  local hidden = tree.render(read, view({ show_ignored = false })).lines
  local shown =
    tree.render(read, view({ show_ignored = true, open = { node_modules = true } })).lines

  eq(vim.list_slice(hidden, 2), { '    a.txt' })
  eq(vim.list_slice(shown, 2), { '▾   node_modules/', '  ▸   pkg/', '    a.txt' })
  eq(read.children.node_modules[1].ignored, true)
end

T['the folders above a path'] = MiniTest.new_set()

T['the folders above a path']['are listed from the root down, none for an entry of the root'] = function()
  eq(tree.folders_above('src/lib/util.lua'), { 'src', 'src/lib' })
  eq(tree.folders_above('top.txt'), {})
end

T['the header'] = MiniTest.new_set()

T['the header']['names what the tree shows and its toggles'] = function()
  local lines = tree.render(tree.from_paths({ 'a' }), view({ title = 'project' })).lines

  eq(lines[1], 'project  ·  ignored hidden  ·  dotfiles shown')
end

T['the header']['names the toggles turned and the filter'] = function()
  local shown =
    view({ title = 'project', show_ignored = true, show_dotfiles = false, filter = 'x' })

  local lines = tree.render(tree.from_paths({ 'x' }), shown).lines

  eq(lines[1], 'project  ·  ignored shown  ·  dotfiles hidden  ·  filter “x”')
end

return T
