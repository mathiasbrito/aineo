local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local look = require('aineo.explorer.look')
local tree = require('aineo.explorer.tree')

--- The view of a tree no key has changed, every look off: nothing
--- unfolded, no mark, ignored entries hidden, dotfiles shown, no filter.
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

--- The rendering of the folders `paths` make under `shown`.
---
---@param paths string[]
---@param shown aineo.explorer.View
---@return aineo.explorer.Rendering
local function render(paths, shown)
  return tree.render(tree.from_paths(paths), shown)
end

--- The text of the first chunk of each virtual text of `rendering`'s line
--- `line` at `position`, in the order given.
---
---@param rendering aineo.explorer.Rendering
---@param line integer
---@param position string
---@return string[]
local function virtual_texts(rendering, line, position)
  local texts = {}
  for _, item in ipairs(rendering.virtual[line] or {}) do
    if item.position == position then
      table.insert(texts, item.chunks[1].text)
    end
  end
  return texts
end

local T = MiniTest.new_set()

T['the guides'] = MiniTest.new_set()

local NESTED = { 'src/lib/util.lua', 'src/main.lua', 'src/zed/z.lua', 'top.txt' }

T['the guides']['lay a connector on the indent of each entry below the root, the line’s text unchanged'] = function()
  local shown = view({ guides = true, open = { src = true, ['src/lib'] = true } })

  local rendering = render(NESTED, shown)

  eq(rendering.lines, {
    '▾   src/',
    '  ▾   lib/',
    '        util.lua',
    '  ▸   zed/',
    '      main.lua',
    '    top.txt',
  })
  eq(rendering.virtual[1], nil)
  eq(rendering.virtual[2], {
    { position = 'overlay', column = 0, chunks = { { text = '├ ', role = 'guide' } } },
  })
  eq(rendering.virtual[6], nil)
end

T['the guides']['continue a level while its folder has entries after it, and end it on the last'] = function()
  local shown = view({ guides = true, open = { src = true, ['src/lib'] = true } })

  local rendering = render(NESTED, shown)

  eq(virtual_texts(rendering, 2, 'overlay'), { '├ ' })
  eq(virtual_texts(rendering, 3, 'overlay'), { '│ └ ' })
  eq(virtual_texts(rendering, 4, 'overlay'), { '├ ' })
  eq(virtual_texts(rendering, 5, 'overlay'), { '└ ' })
end

T['the guides']['leave a level blank under a folder that is the last of its folder'] = function()
  local shown = view({ guides = true, open = { src = true, ['src/lib'] = true } })

  local rendering = render({ 'src/lib/util.lua' }, shown)

  eq(virtual_texts(rendering, 2, 'overlay'), { '└ ' })
  eq(virtual_texts(rendering, 3, 'overlay'), { '  └ ' })
end

T['the guides']['count the entries that show, not the ones hidden after an entry'] = function()
  local shown = view({ guides = true, open = { src = true }, show_dotfiles = false })

  local rendering = render({ 'src/a.lua', 'src/.hidden' }, shown)

  eq(virtual_texts(rendering, 2, 'overlay'), { '└ ' })
end

T['the guides']['are not laid while the look is off'] = function()
  local rendering = render(NESTED, view({ open = { src = true } }))

  eq(rendering.virtual, {})
end

T['a chain of single-child folders'] = MiniTest.new_set()

local CHAIN = { 'lua/aineo/explorer/home.lua', 'lua/aineo/explorer/tree.lua', 'README.md' }

T['a chain of single-child folders']['folds onto one line, its entry the deepest folder'] = function()
  local rendering = render(CHAIN, view({ compact = true }))

  eq(rendering.lines, { '▸   lua/aineo/explorer/', '    README.md' })
  eq(rendering.entries[1].path, 'lua/aineo/explorer')
  eq(rendering.entries[1].kind, 'folder')
end

T['a chain of single-child folders']['unfolds with the deepest folder, its entries one level down'] = function()
  local shown = view({ compact = true, open = { ['lua/aineo/explorer'] = true } })

  local rendering = render(CHAIN, shown)

  eq(rendering.lines, {
    '▾   lua/aineo/explorer/',
    '      home.lua',
    '      tree.lua',
    '    README.md',
  })
end

T['a chain of single-child folders']['is not folded while the look is off'] = function()
  local rendering = render(CHAIN, view({ open = { lua = true } }))

  eq(rendering.lines, { '▾   lua/', '  ▸   aineo/', '    README.md' })
end

T['a chain of single-child folders']['ends at a folder holding more than one entry'] = function()
  local paths = { 'a/b/c/x.lua', 'a/b/y.lua', 'a/b/c/z.lua' }

  local rendering = render(paths, view({ compact = true, open = { ['a/b'] = true } }))

  eq(rendering.lines, { '▾   a/b/', '  ▸   c/', '      y.lua' })
  eq(rendering.entries[1].path, 'a/b')
end

T['a chain of single-child folders']['counts the entries that show, not the ones hidden'] = function()
  local paths = { 'a/.hidden', 'a/b/x.lua' }

  local hidden = render(paths, view({ compact = true, show_dotfiles = false }))
  local shown = render(paths, view({ compact = true }))

  eq(hidden.lines, { '▸   a/b/' })
  eq(shown.lines, { '▸   a/' })
end

T['a chain of single-child folders']['unfolds through under a filter'] = function()
  local rendering = render(CHAIN, view({ compact = true, filter = 'tree' }))

  eq(rendering.lines, { '▾   lua/aineo/explorer/', '      tree.lua' })
end

T['a chain of single-child folders']['is one level of the guides'] = function()
  local shown = view({ compact = true, guides = true, open = { ['a/b'] = true } })

  local rendering = render({ 'a/b/x.lua', 'a/b/y.lua' }, shown)

  eq(virtual_texts(rendering, 2, 'overlay'), { '├ ' })
  eq(virtual_texts(rendering, 3, 'overlay'), { '└ ' })
end

T['a chain of single-child folders']['takes the mark of a change below it'] = function()
  local shown = view({ compact = true, marks = { ['a/b/c.lua'] = 'M' } })

  local rendering = render({ 'a/b/c.lua' }, shown)

  eq(rendering.lines[1], '▸ • a/b/')
  eq(rendering.spans[1][2].role, 'changed_folder')
end

T['a chain of single-child folders']['starting at a folder ignored shows whole in the ignored colour'] = function()
  local tree_of = tree.from_paths({ 'src/a.lua' }, { 'build/out/' })
  local shown = view({ compact = true, show_ignored = true })

  local rendering = tree.render(tree_of, shown)

  eq(
    rendering.spans[1],
    { { first_column = 0, end_column = #'▸   build/out/', role = 'ignored' } }
  )
end

T['a chain of single-child folders']['takes the colour of its deepest folder: ignored when that folder is'] = function()
  local tree_of = tree.from_paths({ 'a/.keep' }, { 'a/b/' })
  local shown = view({ compact = true, show_ignored = true, show_dotfiles = false })

  local rendering = tree.render(tree_of, shown)

  eq(rendering.lines[1], '▸   a/b/')
  eq(rendering.spans[1], { { first_column = 0, end_column = #'▸   a/b/', role = 'ignored' } })
end

T['a chain of single-child folders']['ending at a changed submodule shows the submodule’s mark and no count'] = function()
  local read = tree.from_repository({
    files = { 'vendor/lib', 'a.txt' },
    changes = { { path = 'vendor/lib', kind = 'modified' } },
    submodules = { 'vendor/lib' },
  }, '')

  local rendering =
    tree.render(read.tree, view({ marks = read.marks, compact = true, counts = true }))

  eq(rendering.lines[1], '▸ M vendor/lib/')
  eq(rendering.virtual[1], nil)
end

T['the counts'] = MiniTest.new_set()

--- The virtual text of `rendering`'s line `line` at `position` as
--- `{ column, text, role }` of its chunks, joined into one text.
---
---@param rendering aineo.explorer.Rendering
---@param line integer
---@param position string
---@return table[]
local function placed(rendering, line, position)
  local found = {}
  for _, item in ipairs(rendering.virtual[line] or {}) do
    if item.position == position then
      table.insert(found, {
        item.column,
        table.concat(vim.tbl_map(function(chunk)
          return chunk.text
        end, item.chunks)),
      })
    end
  end
  return found
end

local CHANGED = {
  ['src/lib/util.lua'] = 'M',
  ['src/main.lua'] = '?',
  ['docs/guide.md'] = 'M',
}

T['the counts']['follow the mark of a folder with the number of the changed files below it, at any depth'] = function()
  local shown = view({ counts = true, marks = CHANGED })

  local rendering = render({ 'src/lib/util.lua', 'src/main.lua', 'docs/guide.md' }, shown)

  eq(rendering.lines[1], '▸ • docs/')
  eq(placed(rendering, 1, 'inline'), { { #'▸ •', '1' } })
  eq(placed(rendering, 2, 'inline'), { { #'▸ •', '2' } })
  eq(rendering.virtual[2][1].chunks[1].role, 'changed_folder')
end

T['the counts']['are left out while the look is off, and for a folder with a mark of its own'] = function()
  local without = render({ 'src/main.lua' }, view({ marks = CHANGED }))
  local nested =
    tree.render(tree.from_paths({ 'nested/' }), view({ counts = true, marks = { nested = '?' } }))

  eq(without.virtual, {})
  eq(nested.virtual, {})
end

T['the counts']['show the lines added and removed at the right edge of a changed file'] = function()
  local shown = view({
    counts = true,
    width = 30,
    marks = { ['a.txt'] = 'M' },
    line_counts = { ['a.txt'] = { added = 12, removed = 3 } },
  })

  local rendering = render({ 'a.txt', 'b.txt' }, shown)

  eq(placed(rendering, 1, 'right_align'), { { 0, '+12 −3' } })
  eq(rendering.virtual[1][1].chunks, {
    { text = '+12', role = 'added_lines' },
    { text = ' ' },
    { text = '−3', role = 'removed_lines' },
  })
  eq(rendering.virtual[2], nil)
end

T['the counts']['are left out of a line they would not fit on, and the others keep theirs'] = function()
  local shown = view({
    counts = true,
    width = 15,
    marks = { ['a.txt'] = 'M', ['b.txt'] = 'M' },
    line_counts = {
      ['a.txt'] = { added = 12, removed = 3 },
      ['b.txt'] = { added = 1, removed = 1 },
    },
  })

  local rendering = render({ 'a.txt', 'b.txt' }, shown)

  eq(placed(rendering, 1, 'right_align'), {})
  eq(placed(rendering, 2, 'right_align'), { { 0, '+1 −1' } })
end

T['the counts']['are shown at any width while the window’s is not known'] = function()
  local shown = view({
    counts = true,
    marks = { ['a.txt'] = 'M' },
    line_counts = { ['a.txt'] = { added = 1, removed = 0 } },
  })

  eq(placed(render({ 'a.txt' }, shown), 1, 'right_align'), { { 0, '+1 −0' } })
end

T['the counts']['are not shown for a file git does not count, nor while the look is off'] = function()
  local counts = { ['a.txt'] = { added = 1, removed = 1 } }

  local untracked = render(
    { 'a.txt', 'new.txt' },
    view({ counts = true, marks = { ['a.txt'] = 'M', ['new.txt'] = '?' }, line_counts = counts })
  )
  local off = render({ 'a.txt' }, view({ marks = { ['a.txt'] = 'M' }, line_counts = counts }))

  eq(untracked.virtual[2], nil)
  eq(off.virtual, {})
end

T['the icons'] = MiniTest.new_set()

--- An icon provider that gives every file `L` in `IconLua` and records the
--- paths it was asked about in `asked`.
---
---@param asked string[]
---@return fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil
local function icons_asking(asked)
  return function(entry)
    table.insert(asked, entry.path)
    return { text = 'L', group = 'IconLua' }
  end
end

T['the icons']['sit before a file’s name, a folder’s place left blank so the names line up'] = function()
  local asked = {}
  local shown = view({ icons = icons_asking(asked) })

  local rendering = render({ 'src/main.lua', 'top.lua' }, shown)

  eq(rendering.virtual[1], {
    { position = 'inline', column = #'▸   ', chunks = { { text = '  ' } } },
  })
  eq(rendering.virtual[2], {
    { position = 'inline', column = #'    ', chunks = { { text = 'L ', group = 'IconLua' } } },
  })
  eq(asked, { 'top.lua' })
end

T['the icons']['are none when the look has no provider'] = function()
  eq(render({ 'top.lua' }, view()).virtual, {})
end

T['the icons']['are left blank for a file the provider gives none'] = function()
  local shown = view({ icons = function() end })

  local rendering = render({ 'top.lua' }, shown)

  eq(rendering.virtual[1][1].chunks, { { text = '  ' } })
end

T['the icons']['leave the right-hand counts room for themselves'] = function()
  local shown = view({
    icons = icons_asking({}),
    counts = true,
    marks = { ['a.txt'] = 'M' },
    line_counts = { ['a.txt'] = { added = 1, removed = 1 } },
    width = #'  M   a.txt' + 1 + #'+1 −1' - 3,
  })

  local rendering = render({ 'a.txt' }, shown)

  eq(placed(rendering, 1, 'right_align'), {})
end

T['the looks'] = MiniTest.new_set()

T['the looks']['are the tree’s looks, all on, when no setting is given'] = function()
  local defaults = {
    guides = true,
    icons = true,
    dim = true,
    counts = true,
    compact = true,
    diagnostics = true,
  }

  eq(look.resolve(nil), defaults)
  eq(look.resolve({}), defaults)
end

T['the looks']['are the defaults but the ones a setting changes'] = function()
  local resolved = look.resolve({ icons = false, counts = false })

  eq(resolved, {
    guides = true,
    icons = false,
    dim = true,
    counts = false,
    compact = true,
    diagnostics = true,
  })
end

T['the claude marks'] = MiniTest.new_set()

--- The chunks of the first inline virtual text of `rendering`'s line
--- `line`, the places before its name; none for a line with none.
---
---@param rendering aineo.explorer.Rendering
---@param line integer
---@return aineo.explorer.VirtualChunk[]
local function name_places(rendering, line)
  for _, item in ipairs(rendering.virtual[line] or {}) do
    if item.position == 'inline' then
      return item.chunks
    end
  end
  return {}
end

T['the claude marks']['sit before the name of each file in the session’s work, a blank before the others so the names line up'] = function()
  local shown = view({ claude = { ['b.txt'] = true } })

  local rendering = render({ 'a.txt', 'b.txt', 'src/c.txt' }, shown)

  eq(rendering.lines[1], '▸   src/')
  eq(name_places(rendering, 1), { { text = '  ' } })
  eq(name_places(rendering, 2), { { text = '  ' } })
  eq(name_places(rendering, 3), { { text = '✦ ', role = 'claude' } })
end

T['the claude marks']['come before the icon'] = function()
  local shown = view({
    claude = { ['b.txt'] = true },
    icons = function()
      return { text = 'L', group = 'IconLua' }
    end,
  })

  local rendering = render({ 'b.txt' }, shown)

  eq(name_places(rendering, 1), {
    { text = '✦ ', role = 'claude' },
    { text = 'L ', group = 'IconLua' },
  })
end

T['the claude marks']['take no place while the session has no work'] = function()
  eq(render({ 'a.txt' }, view({ claude = {} })).virtual, {})
  eq(render({ 'a.txt' }, view()).virtual, {})
end

T['the claude marks']['flash the line of a file named, as a line to colour'] = function()
  local shown = view({ claude = { ['b.txt'] = true }, flash = { ['b.txt'] = true } })

  local rendering = render({ 'a.txt', 'b.txt' }, shown)

  eq(rendering.flashed, { [2] = true })
end

T['the claude marks']['flash nothing for a file that shows no mark'] = function()
  local shown = view({ claude = { ['b.txt'] = true }, flash = { ['a.txt'] = true } })

  eq(render({ 'a.txt', 'b.txt' }, shown).flashed, {})
end

T['the claude marks']['come from the files of the session’s work a repository’s listing gives, under the folder shown, from it'] = function()
  local listing = {
    files = { 'outside.txt', 'sub/a.txt', 'sub/dir/b.txt' },
    changes = {},
    session_paths = { 'outside.txt', 'sub/dir/b.txt' },
  }

  eq(tree.from_repository(listing, 'sub').claude, { ['dir/b.txt'] = true })
  eq(tree.from_repository({ files = { 'a.txt' }, changes = {} }, '').claude, {})
end

T['the unsaved mark'] = MiniTest.new_set()

T['the unsaved mark']['follows the name of a file with unsaved edits, a folder never showing one'] = function()
  local shown = view({ modified = { ['a.txt'] = true, src = true } })

  local rendering = render({ 'a.txt', 'b.txt', 'src/c.txt' }, shown)

  eq(rendering.virtual[1], nil)
  eq(rendering.virtual[2], {
    {
      position = 'inline',
      column = #'    a.txt',
      chunks = { { text = ' ●', role = 'unsaved' } },
    },
  })
  eq(rendering.virtual[3], nil)
end

T['the diagnostics'] = MiniTest.new_set()

--- The texts of the chunks of the right-aligned virtual text of
--- `rendering`'s line `line`, in order; none for a line with none.
---
---@param rendering aineo.explorer.Rendering
---@param line integer
---@return string[]
local function right_chunks(rendering, line)
  for _, item in ipairs(rendering.virtual[line] or {}) do
    if item.position == 'right_align' then
      return vim.tbl_map(function(chunk)
        return chunk.text
      end, item.chunks)
    end
  end
  return {}
end

T['the diagnostics']['show the errors and the warnings of a file at the right, in their own roles'] = function()
  local shown = view({ diagnostics = { ['a.txt'] = { error = 2, warn = 1 } } })

  local rendering = render({ 'a.txt' }, shown)

  eq(rendering.virtual[1][1].chunks, {
    { text = 'E2', role = 'diagnostic_error' },
    { text = ' ' },
    { text = 'W1', role = 'diagnostic_warn' },
  })
end

T['the diagnostics']['name only the severity there is, and nothing for a file with none'] = function()
  local shown = view({
    diagnostics = {
      ['a.txt'] = { error = 3, warn = 0 },
      ['b.txt'] = { error = 0, warn = 4 },
      ['c.txt'] = { error = 0, warn = 0 },
    },
  })

  local rendering = render({ 'a.txt', 'b.txt', 'c.txt' }, shown)

  eq(right_chunks(rendering, 1), { 'E3' })
  eq(right_chunks(rendering, 2), { 'W4' })
  eq(right_chunks(rendering, 3), {})
end

T['the diagnostics']['come before the lines added and removed, on one right-aligned text'] = function()
  local shown = view({
    counts = true,
    marks = { ['a.txt'] = 'M' },
    line_counts = { ['a.txt'] = { added = 3, removed = 1 } },
    diagnostics = { ['a.txt'] = { error = 2, warn = 1 } },
  })

  local rendering = render({ 'a.txt' }, shown)

  eq(right_chunks(rendering, 1), { 'E2', ' ', 'W1', ' ', '+3', ' ', '−1' })
  eq(#rendering.virtual[1], 1)
end

T['the diagnostics']['give way when the line is full: the lines added and removed first, then themselves'] = function()
  local counts = {
    counts = true,
    marks = { ['a.txt'] = 'M' },
    line_counts = { ['a.txt'] = { added = 3, removed = 1 } },
    diagnostics = { ['a.txt'] = { error = 2, warn = 0 } },
  }
  local line_width = vim.api.nvim_strwidth('  M a.txt')

  local both =
    render({ 'a.txt' }, view(vim.tbl_extend('force', counts, { width = line_width + 1 + 8 })))
  local only_diagnostics =
    render({ 'a.txt' }, view(vim.tbl_extend('force', counts, { width = line_width + 1 + 7 })))
  local neither =
    render({ 'a.txt' }, view(vim.tbl_extend('force', counts, { width = line_width + 2 })))

  eq(right_chunks(both, 1), { 'E2', ' ', '+3', ' ', '−1' })
  eq(right_chunks(only_diagnostics, 1), { 'E2' })
  eq(right_chunks(neither, 1), {})
end

T['a repository’s listing'] = MiniTest.new_set()

T['a repository’s listing']['gives the line counts of the files under the folder shown, from it'] = function()
  local listing = {
    files = { 'outside.txt', 'sub/a.txt', 'sub/dir/b.txt' },
    changes = {},
    line_counts = {
      ['outside.txt'] = { added = 9, removed = 9 },
      ['sub/a.txt'] = { added = 1, removed = 2 },
      ['sub/dir/b.txt'] = { added = 3, removed = 4 },
    },
  }

  local read = tree.from_repository(listing, 'sub')
  local top = tree.from_repository(listing, '')

  eq(read.line_counts, {
    ['a.txt'] = { added = 1, removed = 2 },
    ['dir/b.txt'] = { added = 3, removed = 4 },
  })
  eq(top.line_counts['sub/a.txt'], { added = 1, removed = 2 })
end

T['a repository’s listing']['gives none when git was not asked for them'] = function()
  local read = tree.from_repository({ files = { 'a.txt' }, changes = {} }, '')

  eq(read.line_counts, {})
end

T['the dimming'] = MiniTest.new_set()

T['the dimming']['shows the name of a file git sees unchanged in the unchanged role while a changed file shows'] = function()
  local shown = view({ dim = true, marks = { ['a.txt'] = 'M' } })

  local rendering = render({ 'a.txt', 'b.txt', 'src/c.txt' }, shown)

  eq(rendering.spans[2], { { first_column = 2, end_column = 9, role = 'modified' } })
  eq(rendering.spans[3], { { first_column = 4, end_column = 9, role = 'unchanged' } })
  eq(rendering.spans[1], {
    { first_column = 0, end_column = 3, role = 'folder' },
    { first_column = 6, end_column = 10, role = 'folder' },
  })
end

T['the dimming']['dims nothing while no changed file shows'] = function()
  local hidden = render(
    { 'a.txt', '.hidden' },
    view({ dim = true, show_dotfiles = false, marks = { ['.hidden'] = 'M' } })
  )
  local none = render({ 'a.txt' }, view({ dim = true }))

  eq(hidden.spans, {})
  eq(none.spans, {})
end

T['the dimming']['is off while the look is off, and leaves an entry git ignores in its own role'] = function()
  local marks = { ['a.txt'] = 'M' }
  local off = render({ 'a.txt', 'b.txt' }, view({ marks = marks }))
  local ignored = tree.render(
    tree.from_paths({ 'a.txt' }, { 'out.log' }),
    view({ dim = true, show_ignored = true, marks = marks })
  )

  eq(off.spans[2], nil)
  eq(ignored.spans[2], { { first_column = 0, end_column = #'    out.log', role = 'ignored' } })
end

return T
