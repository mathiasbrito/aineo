local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

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

  eq(vim.list_slice(rendering.lines, 2), {
    '▾   src/',
    '  ▾   lib/',
    '        util.lua',
    '  ▸   zed/',
    '      main.lua',
    '    top.txt',
  })
  eq(rendering.virtual[2], nil)
  eq(rendering.virtual[3], {
    { position = 'overlay', column = 0, chunks = { { text = '├ ', role = 'guide' } } },
  })
  eq(rendering.virtual[7], nil)
end

T['the guides']['continue a level while its folder has entries after it, and end it on the last'] = function()
  local shown = view({ guides = true, open = { src = true, ['src/lib'] = true } })

  local rendering = render(NESTED, shown)

  eq(virtual_texts(rendering, 3, 'overlay'), { '├ ' })
  eq(virtual_texts(rendering, 4, 'overlay'), { '│ └ ' })
  eq(virtual_texts(rendering, 5, 'overlay'), { '├ ' })
  eq(virtual_texts(rendering, 6, 'overlay'), { '└ ' })
end

T['the guides']['leave a level blank under a folder that is the last of its folder'] = function()
  local shown = view({ guides = true, open = { src = true, ['src/lib'] = true } })

  local rendering = render({ 'src/lib/util.lua' }, shown)

  eq(virtual_texts(rendering, 3, 'overlay'), { '└ ' })
  eq(virtual_texts(rendering, 4, 'overlay'), { '  └ ' })
end

T['the guides']['count the entries that show, not the ones hidden after an entry'] = function()
  local shown = view({ guides = true, open = { src = true }, show_dotfiles = false })

  local rendering = render({ 'src/a.lua', 'src/.hidden' }, shown)

  eq(virtual_texts(rendering, 3, 'overlay'), { '└ ' })
end

T['the guides']['are not laid while the look is off'] = function()
  local rendering = render(NESTED, view({ open = { src = true } }))

  eq(rendering.virtual, {})
end

T['a chain of single-child folders'] = MiniTest.new_set()

local CHAIN = { 'lua/aineo/explorer/home.lua', 'lua/aineo/explorer/tree.lua', 'README.md' }

T['a chain of single-child folders']['folds onto one line, its entry the deepest folder'] = function()
  local rendering = render(CHAIN, view({ compact = true }))

  eq(vim.list_slice(rendering.lines, 2), { '▸   lua/aineo/explorer/', '    README.md' })
  eq(rendering.entries[2].path, 'lua/aineo/explorer')
  eq(rendering.entries[2].kind, 'folder')
end

T['a chain of single-child folders']['unfolds with the deepest folder, its entries one level down'] = function()
  local shown = view({ compact = true, open = { ['lua/aineo/explorer'] = true } })

  local rendering = render(CHAIN, shown)

  eq(vim.list_slice(rendering.lines, 2), {
    '▾   lua/aineo/explorer/',
    '      home.lua',
    '      tree.lua',
    '    README.md',
  })
end

T['a chain of single-child folders']['is not folded while the look is off'] = function()
  local rendering = render(CHAIN, view({ open = { lua = true } }))

  eq(vim.list_slice(rendering.lines, 2), { '▾   lua/', '  ▸   aineo/', '    README.md' })
end

T['a chain of single-child folders']['ends at a folder holding more than one entry'] = function()
  local paths = { 'a/b/c/x.lua', 'a/b/y.lua', 'a/b/c/z.lua' }

  local rendering = render(paths, view({ compact = true, open = { ['a/b'] = true } }))

  eq(vim.list_slice(rendering.lines, 2), { '▾   a/b/', '  ▸   c/', '      y.lua' })
  eq(rendering.entries[2].path, 'a/b')
end

T['a chain of single-child folders']['counts the entries that show, not the ones hidden'] = function()
  local paths = { 'a/.hidden', 'a/b/x.lua' }

  local hidden = render(paths, view({ compact = true, show_dotfiles = false }))
  local shown = render(paths, view({ compact = true }))

  eq(vim.list_slice(hidden.lines, 2), { '▸   a/b/' })
  eq(vim.list_slice(shown.lines, 2), { '▸   a/' })
end

T['a chain of single-child folders']['unfolds through under a filter'] = function()
  local rendering = render(CHAIN, view({ compact = true, filter = 'tree' }))

  eq(vim.list_slice(rendering.lines, 2), { '▾   lua/aineo/explorer/', '      tree.lua' })
end

T['a chain of single-child folders']['is one level of the guides'] = function()
  local shown = view({ compact = true, guides = true, open = { ['a/b'] = true } })

  local rendering = render({ 'a/b/x.lua', 'a/b/y.lua' }, shown)

  eq(virtual_texts(rendering, 3, 'overlay'), { '├ ' })
  eq(virtual_texts(rendering, 4, 'overlay'), { '└ ' })
end

T['a chain of single-child folders']['takes the mark of a change below it'] = function()
  local shown = view({ compact = true, marks = { ['a/b/c.lua'] = 'M' } })

  local rendering = render({ 'a/b/c.lua' }, shown)

  eq(rendering.lines[2], '▸ • a/b/')
  eq(rendering.spans[2][2].role, 'changed_folder')
end

T['a chain of single-child folders']['starting at a folder ignored shows whole in the ignored colour'] = function()
  local tree_of = tree.from_paths({ 'src/a.lua' }, { 'build/out/' })
  local shown = view({ compact = true, show_ignored = true })

  local rendering = tree.render(tree_of, shown)

  eq(
    rendering.spans[2],
    { { first_column = 0, end_column = #'▸   build/out/', role = 'ignored' } }
  )
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

  eq(rendering.lines[2], '▸ • docs/')
  eq(placed(rendering, 2, 'inline'), { { #'▸ •', '1' } })
  eq(placed(rendering, 3, 'inline'), { { #'▸ •', '2' } })
  eq(rendering.virtual[3][1].chunks[1].role, 'changed_folder')
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

  eq(placed(rendering, 2, 'right_align'), { { 0, '+12 −3' } })
  eq(rendering.virtual[2][1].chunks, {
    { text = '+12', role = 'added_lines' },
    { text = ' ' },
    { text = '−3', role = 'removed_lines' },
  })
  eq(rendering.virtual[3], nil)
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

  eq(placed(rendering, 2, 'right_align'), {})
  eq(placed(rendering, 3, 'right_align'), { { 0, '+1 −1' } })
end

T['the counts']['are shown at any width while the window’s is not known'] = function()
  local shown = view({
    counts = true,
    marks = { ['a.txt'] = 'M' },
    line_counts = { ['a.txt'] = { added = 1, removed = 0 } },
  })

  eq(placed(render({ 'a.txt' }, shown), 2, 'right_align'), { { 0, '+1 −0' } })
end

T['the counts']['are not shown for a file git does not count, nor while the look is off'] = function()
  local counts = { ['a.txt'] = { added = 1, removed = 1 } }

  local untracked = render(
    { 'a.txt', 'new.txt' },
    view({ counts = true, marks = { ['a.txt'] = 'M', ['new.txt'] = '?' }, line_counts = counts })
  )
  local off = render({ 'a.txt' }, view({ marks = { ['a.txt'] = 'M' }, line_counts = counts }))

  eq(untracked.virtual[3], nil)
  eq(off.virtual, {})
end

T['the header'] = MiniTest.new_set()

--- The header line `tree.render()` gives under `shown`.
---
---@param shown aineo.explorer.View
---@return string
local function header_of(shown)
  return tree.render(tree.from_paths({ 'a' }), shown).lines[1]
end

T['the header']['names the branch after the folder, the toggles after both'] = function()
  local shown = view({ title = '~/project', branch = 'main' })

  eq(header_of(shown), '~/project · main  ·  ignored hidden  ·  dotfiles shown')
end

T['the header']['sums the changes up, the files git sees as new apart from the others'] = function()
  local marks = { a = 'M', b = 'D', c = '?', d = 'A', e = 'R' }
  local shown = view({ title = 'p', branch = 'main', marks = marks })

  eq(header_of(shown), 'p · main · 3 changed · 2 new  ·  ignored hidden  ·  dotfiles shown')
end

T['the header']['names only the kind of change there is'] = function()
  eq(
    header_of(view({ title = 'p', marks = { a = 'M' } })):sub(1, #'p · 1 changed  ·'),
    'p · 1 changed  ·'
  )
  eq(
    header_of(view({ title = 'p', marks = { a = '?' } })):sub(1, #'p · 1 new  ·'),
    'p · 1 new  ·'
  )
end

T['the header']['lays the toggles at the right edge of a window whose width is known'] = function()
  local shown = view({ title = 'p', branch = 'main', width = 60 })

  local header = header_of(shown)

  eq(vim.api.nvim_strwidth(header), 60)
  eq(header:sub(1, #'p · main'), 'p · main')
  eq(header:sub(-#'ignored hidden  ·  dotfiles shown'), 'ignored hidden  ·  dotfiles shown')
end

T['the header']['drops the toggles first, then the summary, when they would not fit'] = function()
  local base = { title = 'p', branch = 'main', marks = { a = 'M' } }
  local toggles_fit = vim.api.nvim_strwidth('p · main · 1 changed')
    + 2
    + vim.api.nvim_strwidth('ignored hidden  ·  dotfiles shown')

  local with_toggles = header_of(view(vim.tbl_extend('force', base, { width = toggles_fit })))
  local without_toggles =
    header_of(view(vim.tbl_extend('force', base, { width = toggles_fit - 1 })))
  local without_summary =
    header_of(view(vim.tbl_extend('force', base, { width = vim.api.nvim_strwidth('p · main') })))

  eq(vim.endswith(with_toggles, 'dotfiles shown'), true)
  eq(without_toggles, 'p · main · 1 changed')
  eq(without_summary, 'p · main')
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

  eq(rendering.spans[3], { { first_column = 2, end_column = 9, role = 'modified' } })
  eq(rendering.spans[4], { { first_column = 4, end_column = 9, role = 'unchanged' } })
  eq(rendering.spans[2], {
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

  eq(off.spans[3], nil)
  eq(ignored.spans[3], { { first_column = 0, end_column = #'    out.log', role = 'ignored' } })
end

return T
