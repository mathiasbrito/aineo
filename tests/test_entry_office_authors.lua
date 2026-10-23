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
      child.lua([[vim.fn.delete(vim.fs.joinpath(vim.fn.stdpath('config'), 'aineo-office'), 'rf')]])
    end,
    post_once = child.stop,
  },
})

--- The names of the packs found once the test adds the pack `alt` to the two
--- aineo ships, `default` and `space_station`, sorted.
local PACKS_FOUND = { 'alt', 'default', 'space_station' }

--- The folder the user's own packs are made in: `aineo-office` in the
--- child's configuration directory.
---
---@return string
local function own_folder()
  return child.lua_get([[vim.fs.joinpath(vim.fn.stdpath('config'), 'aineo-office')]])
end

--- Writes the pack `name` and puts the folder it is in on the child's
--- 'runtimepath'.
---
---@param name string
local function add_pack(name)
  local root = fixture.directory('office_authors')
  pack_files.write_pack(root, name)
  child.lua([[vim.opt.runtimepath:append(...)]], { root })
end

--- The lines of the child's current buffer.
---
---@return string[]
local function current_lines()
  return child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
end

T['Aineo office states'] = MiniTest.new_set()

T['Aineo office states']['lists what the pack draws for each state in a window of its own'] = function()
  add_pack('alt')
  local windows_before = #child.api.nvim_list_wins()

  entry.command(child, 'Aineo office states alt')

  local lines = current_lines()
  eq(#child.api.nvim_list_wins(), windows_before + 1)
  eq(lines[1], 'Office pack “alt” by the tests')
  eq(
    vim.tbl_contains(lines, ' 1  arriving               falls back to standing, which draws stand'),
    true
  )
end

T['Aineo office states']['makes the list a scratch buffer that cannot be changed'] = function()
  add_pack('alt')

  entry.command(child, 'Aineo office states alt')

  eq(child.lua_get([[vim.bo.buftype]]), 'nofile')
  eq(child.lua_get([[vim.bo.modifiable]]), false)
  eq(child.lua_get([[vim.bo.bufhidden]]), 'wipe')
end

T['Aineo office states']['lists the pack the setting office.pack names when it is given none'] = function()
  add_pack('alt')
  child.lua([[vim.g.aineo = { office = { pack = { 'alt', 'default' } } }]])

  entry.command(child, 'Aineo office states')

  eq(current_lines()[1], 'Office pack “alt” by the tests')
end

T['Aineo office states']['lists the default pack when the setting is left as it is'] = function()
  entry.command(child, 'Aineo office states')

  eq(current_lines()[1], 'Office pack “default” by aineo')
end

T['Aineo office states']['says there is no such pack, and opens no window'] = function()
  local windows_before = #child.api.nvim_list_wins()

  entry.command(child, 'Aineo office states nothing_here')

  local told = entry.messages(child)
  eq(#told, 1)
  eq(told[1].level, vim.log.levels.ERROR)
  eq(
    vim.startswith(
      told[1].message,
      'aineo: cannot list the states of the office pack “nothing_here”: there is no pack “nothing_here”'
    ),
    true
  )
  eq(#child.api.nvim_list_wins(), windows_before)
end

T['Aineo office states']['lists a pack whose about is not text, and leaves no buffer behind'] = function()
  local root = fixture.directory('office_authors')
  pack_files.write_pack(root, 'odd', {
    ['pack.lua'] = pack_files.pack_text({ name = 'odd', about = 5 }),
  })
  child.lua([[vim.opt.runtimepath:append(...)]], { root })
  local buffers_before = #child.api.nvim_list_bufs()

  entry.command(child, 'Aineo office states odd')

  eq(entry.messages(child), {})
  eq(current_lines()[1], 'Office pack “odd” by the tests')
  eq(#child.api.nvim_list_bufs(), buffers_before + 1)
end

T['Aineo office new'] = MiniTest.new_set()

T['Aineo office new']['copies the default pack into aineo-office in the configuration directory'] = function()
  entry.command(child, 'Aineo office new mine')

  local made = vim.fs.joinpath(own_folder(), 'mine')
  eq(child.lua_get([[vim.uv.fs_stat(...) ~= nil]], { vim.fs.joinpath(made, 'pack.lua') }), true)
  eq(child.lua_get([[vim.uv.fs_stat(...) ~= nil]], { vim.fs.joinpath(made, 'floor.txt') }), true)
  eq(
    child.lua_get([[vim.uv.fs_stat(...) ~= nil]], { vim.fs.joinpath(made, 'art', 'door.txt') }),
    true
  )
end

T['Aineo office new']['says where the pack is and what to do next'] = function()
  entry.command(child, 'Aineo office new mine')

  eq(entry.messages(child), {
    {
      message = ("aineo: the office pack “mine” is in %s; set office.pack to 'mine' to draw it, and use :Aineo office check mine and :Aineo office preview mine while you change it"):format(
        vim.fs.joinpath(own_folder(), 'mine')
      ),
      level = vim.log.levels.INFO,
    },
  })
end

T['Aineo office new']['refuses a folder that exists, and says so'] = function()
  entry.command(child, 'Aineo office new mine')
  child.lua([[_G.entry_test_messages = {}]])

  entry.command(child, 'Aineo office new mine')

  eq(entry.messages(child), {
    {
      message = ('aineo: cannot make the office pack “mine”: there is already a folder %s'):format(
        vim.fs.joinpath(own_folder(), 'mine')
      ),
      level = vim.log.levels.ERROR,
    },
  })
end

T['Aineo office new']['refuses the name of a pack that exists, and says so'] = function()
  entry.command(child, 'Aineo office new default')

  local told = entry.messages(child)
  eq(#told, 1)
  eq(told[1].level, vim.log.levels.ERROR)
  eq(
    vim.startswith(
      told[1].message,
      'aineo: cannot make the office pack “default”: there is already a pack named “default”'
    ),
    true
  )
  eq(
    child.lua_get([[vim.uv.fs_stat(...) == nil]], { vim.fs.joinpath(own_folder(), 'default') }),
    true
  )
end

T['Aineo office new']['needs a name, and only one'] = function()
  entry.command(child, 'Aineo office new')
  entry.command(child, 'Aineo office new one two')

  eq(entry.messages(child), {
    { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR },
    { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR },
  })
end

T['Aineo office completion'] = MiniTest.new_set()

T['Aineo office completion']['offers check, states, preview and new after office'] = function()
  eq(
    child.fn.getcompletion('Aineo office ', 'cmdline'),
    { 'check', 'states', 'preview', 'new', 'pack' }
  )
end

T['Aineo office completion']['offers the packs found after states, check and preview, and nothing after new'] = function()
  add_pack('alt')

  eq(child.fn.getcompletion('Aineo office preview ', 'cmdline'), PACKS_FOUND)
  eq(child.fn.getcompletion('Aineo office states ', 'cmdline'), PACKS_FOUND)
  eq(child.fn.getcompletion('Aineo office check ', 'cmdline'), PACKS_FOUND)
  eq(child.fn.getcompletion('Aineo office states a', 'cmdline'), { 'alt' })
  eq(child.fn.getcompletion('Aineo office new ', 'cmdline'), {})
end

return T
