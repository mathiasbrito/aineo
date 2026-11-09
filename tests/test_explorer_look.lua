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

return T
