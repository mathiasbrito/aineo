local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local footer = require('aineo.explorer.footer')

--- The view of a tree no key has changed, of the folder `p` on `main`:
--- nothing unfolded, no mark, ignored entries hidden, dotfiles shown, no
--- filter.
---
---@param changes? table the fields that differ
---@return aineo.explorer.View
local function view(changes)
  return vim.tbl_extend('force', {
    open = {},
    marks = {},
    show_ignored = false,
    show_dotfiles = true,
    title = '~/project',
    branch = 'main',
  }, changes or {})
end

--- A window with room for every line of the footer.
local ROOMY = { width = 40, height = 30 }

local T = MiniTest.new_set()

T['the lines'] = MiniTest.new_set()

T['the lines']['name the folder, its branch indented, then the toggles, for a clean checkout'] = function()
  local lines = footer.lines(view(), ROOMY)

  eq(lines, {
    { text = '~/project', role = 'title' },
    { text = '  main', role = 'branch' },
    { text = 'ignored hidden · dotfiles shown', role = 'toggles' },
  })
end

T['the lines']['sum the changes up under the branch, the files git sees as new apart from the others'] = function()
  local marks = { a = 'M', b = 'D', c = '?', d = 'A', e = 'R' }

  local lines = footer.lines(view({ marks = marks }), ROOMY)

  eq(lines[3], { text = '3 changed · 2 new', role = 'summary' })
  eq(lines[4].role, 'toggles')
end

T['the lines']['name only the kind of change there is'] = function()
  local changed = footer.lines(view({ marks = { a = 'M' } }), ROOMY)
  local new = footer.lines(view({ marks = { a = '?' } }), ROOMY)

  eq(changed[3].text, '1 changed')
  eq(new[3].text, '1 new')
end

T['the lines']['end with the filter, after the toggles turned'] = function()
  local shown = view({ show_ignored = true, show_dotfiles = false, filter = 'lua' })

  local lines = footer.lines(shown, ROOMY)

  eq(vim.list_slice(lines, 3), {
    { text = 'ignored shown · dotfiles hidden', role = 'toggles' },
    { text = 'filter “lua”', role = 'filter' },
  })
end

T['the lines']['leave the filter out while it is empty'] = function()
  local lines = footer.lines(view({ filter = '' }), ROOMY)

  eq(#lines, 3)
end

T['the lines']['leave the branch out for a folder outside git'] = function()
  local outside_git = {
    open = {},
    marks = {},
    show_ignored = false,
    show_dotfiles = true,
    title = '~/project',
  }

  local lines = footer.lines(outside_git, ROOMY)

  eq(lines, {
    { text = '~/project', role = 'title' },
    { text = 'ignored hidden · dotfiles shown', role = 'toggles' },
  })
end

T['the lines']['cut a line wider than the window at its start'] = function()
  local shown = view({ title = '/repo/a/long/folder', branch = 'feature/a-long-branch' })

  local lines = footer.lines(shown, { width = 10, height = 30 })

  eq(lines, {
    { text = '…ng/folder', role = 'title' },
    { text = '…ng-branch', role = 'branch' },
    { text = '…les shown', role = 'toggles' },
  })
end

T['the lines']['cut by cells, never past the width'] = function()
  local narrowest = footer.lines(view({ title = 'project' }), { width = 1, height = 30 })
  local none = footer.lines(view({ title = 'project' }), { width = 0, height = 30 })
  local wide = footer.lines(view({ title = '界界界界界界' }), { width = 7, height = 30 })

  eq(narrowest[1].text, '…')
  eq(none[1].text, '')
  eq(wide[1].text, '…界界界')
end

T['the lines']['are the title alone in a window shorter than 12 rows'] = function()
  local shown = view({ marks = { a = 'M' }, filter = 'lua' })

  local short = footer.lines(shown, { width = 40, height = 11 })
  local tall_enough = footer.lines(shown, { width = 40, height = 12 })

  eq(short, { { text = '~/project', role = 'title' } })
  eq(#tall_enough, 5)
end

T['the lines']['show the title, the branch and the filter as the view quotes a name'] = function()
  local shown = view({
    title = 'a\nb',
    branch = 'c\nd',
    filter = 'e\nf',
    quote = function(name)
      return (name:gsub('\n', '\\n'))
    end,
  })

  local lines = footer.lines(shown, ROOMY)

  eq(lines[1].text, 'a\\nb')
  eq(lines[2].text, '  c\\nd')
  eq(lines[4].text, 'filter “e\\nf”')
end

return T
