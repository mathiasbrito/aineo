local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')

local eq = MiniTest.expect.equality

local world
local explorer
local notify
local notified

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      notified = {}
      notify = vim.notify
      vim.notify = function(message)
        table.insert(notified, message)
      end
      world = fake_explorer.new_world({ files = { 'a/x.txt', 'a/y.txt' } })
      vim.cmd('only')
    end,
    post_case = function()
      vim.notify = notify
      explorer.let_go()
    end,
  },
})

--- Makes the explorer with `look` as what it is handed for the looks, and
--- shows it with the folder `a` unfolded.
---
---@param look fun(): table<string, boolean>, string[]|nil
local function show_with_looks(look)
  world.look = look
  explorer = fake_explorer.new(world)
  explorer.follow('/repo/a/x.txt')
  vim.api.nvim_win_set_buf(0, explorer.buffer())
end

--- The guides the explorer's buffer shows.
---
---@return integer
local function guides_shown()
  local buffer = explorer.made_buffer()
  local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
  local count = 0
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
    if mark[4].virt_text_pos == 'overlay' then
      count = count + 1
    end
  end
  return count
end

T['the looks'] = MiniTest.new_set()

T['the looks']['are asked for once for each read of the tree, whatever the drawings between'] = function()
  local asked = 0
  show_with_looks(function()
    asked = asked + 1
    return {}
  end)
  local after_first_read = asked

  explorer.follow('/repo/a/y.txt')
  explorer.follow('/repo/a/x.txt')
  explorer.refresh()

  eq(after_first_read, 1)
  eq(asked, 2)
end

T['the looks']['all apply when what answers for them raises, which is told once whatever the reads'] = function()
  show_with_looks(function()
    error('the configuration is wrong')
  end)

  explorer.refresh()
  explorer.refresh()

  eq(guides_shown() > 0, true)
  eq(#notified, 1)
  eq(notified[1]:find('the configuration is wrong', 1, true) ~= nil, true)
end

T['the looks']['apply but the ones a problem names, which is told once whatever the reads'] = function()
  show_with_looks(function()
    return { guides = false }, { 'explorer.icons: expected boolean, got string' }
  end)

  explorer.refresh()
  explorer.refresh()

  eq(guides_shown(), 0)
  eq(#notified, 1)
  eq(notified[1]:find('explorer.icons: expected boolean, got string', 1, true) ~= nil, true)
end

T['the looks']['tell a problem again once it was gone and comes back'] = function()
  local problems = { 'explorer.dim: expected boolean, got string' }
  show_with_looks(function()
    return {}, problems
  end)
  problems = {}
  explorer.refresh()
  problems = { 'explorer.dim: expected boolean, got string' }

  explorer.refresh()

  eq(#notified, 2)
end

return T
