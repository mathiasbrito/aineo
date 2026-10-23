local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local pack_files = dofile('tests/helpers/office_pack_files.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.stop()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Writes the pack `name` and, with `files` over its files, puts the folder
--- they are in on the 'runtimepath' of the child. The pack names the states
--- the office's vocabulary has.
---
---@param name string
---@param files? table<string, string|false>
---@return string pack_directory
local function add_pack(name, files)
  local root = fixture.directory('office_check')
  pack_files.write_pack(root, name, files)
  child.lua([[vim.opt.runtimepath:append(...)]], { root })
  return vim.fs.joinpath(root, 'aineo-office', name)
end

--- The quickfix list of the child: its title and its items as `{ file, line,
--- text }`.
---
---@return { title: string, items: table[] }
local function quickfix()
  return child.lua_get([[(function()
    local list = vim.fn.getqflist({ title = true, items = true })
    local items = {}
    for _, item in ipairs(list.items) do
      table.insert(items, { vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ':p'), item.lnum, item.text })
    end
    return { title = list.title, items = items }
  end)()]])
end

--- Whether the child shows a quickfix window.
---
---@return boolean
local function shows_quickfix()
  return child.lua_get([[vim.fn.getqflist({ winid = 0 }).winid ~= 0]])
end

T['Aineo office check'] = MiniTest.new_set()

T['Aineo office check']['lists the problems of the pack it is given in the quickfix list, with file and line'] = function()
  local directory = add_pack('alt', {
    ['pack.lua'] = pack_files.pack_text({ name = 'alt', about = 5 }),
    ['art/spare.txt'] = 'colours: A = ink\n---\nAA\nA\n',
  })

  entry.command(child, 'Aineo office check alt')

  local list = quickfix()
  eq(list.title, 'aineo office check alt')
  eq(#list.items, 2)
  eq(list.items[1][1], vim.fs.joinpath(directory, 'pack.lua'))
  eq(list.items[1][3], 'about must be text')
  eq(list.items[2][2], 4)
  eq(shows_quickfix(), true)
end

T['Aineo office check']['says the pack has no problem, and lists none, when it has none'] = function()
  add_pack('alt')

  entry.command(child, 'Aineo office check alt')

  eq(entry.messages(child), {
    { message = 'aineo: the office pack “alt” has no problem', level = vim.log.levels.INFO },
  })
  eq(shows_quickfix(), false)
end

T['Aineo office check']['checks the pack the setting office.pack names when it is given none'] = function()
  add_pack('alt', { ['pack.lua'] = pack_files.pack_text({ name = 'alt', about = 5 }) })
  child.lua([[vim.g.aineo = { office = { pack = { 'alt', 'default' } } }]])

  entry.command(child, 'Aineo office check')

  eq(quickfix().title, 'aineo office check alt')
end

T['Aineo office check']['lists the problem that the pack is not found'] = function()
  entry.command(child, 'Aineo office check nothing_here')

  local list = quickfix()
  eq(#list.items, 1)
  eq(list.items[1][3]:find('there is no pack “nothing_here”', 1, true) ~= nil, true)
end

T['Aineo office check']['lists the problem that a name leads to another folder'] = function()
  entry.command(child, 'Aineo office check ../outside')

  local list = quickfix()
  eq(#list.items, 1)
  eq(list.items[1][3], 'the pack name “../outside” is not letters, digits, _ and -')
end

T['Aineo office check']['checks the art files the setting office.pieces names with the pack'] = function()
  add_pack('alt')
  local mine = vim.fs.joinpath(fixture.directory('office_check_mine'), 'mine.txt')
  vim.fn.writefile({ 'colours: A = ink', '---', 'AA', 'A' }, mine)
  child.lua([[vim.g.aineo = { office = { pieces = { person = ... } } }]], { mine })

  entry.command(child, 'Aineo office check alt')

  local list = quickfix()
  eq(#list.items, 1)
  eq(list.items[1][1], mine)
  eq(list.items[1][2], 4)
end

T['Aineo office check']['refuses more than a pack’s name, and says what it takes'] = function()
  entry.command(child, 'Aineo office check alt beta')
  entry.command(child, 'Aineo office checks')

  eq(entry.messages(child), {
    { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR },
    { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR },
  })
end

T['Aineo office check']['is offered after office, with the names of the packs found after check'] = function()
  add_pack('alt')

  eq(child.fn.getcompletion('Aineo office ', 'cmdline'), { 'check', 'states', 'preview', 'new' })
  eq(child.fn.getcompletion('Aineo office check ', 'cmdline'), { 'alt', 'default' })
  eq(child.fn.getcompletion('Aineo office check a', 'cmdline'), { 'alt' })
end

return T
