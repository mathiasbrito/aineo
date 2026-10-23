local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local pack_files = dofile('tests/helpers/office_pack_files.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.o.termguicolors = true
    end,
    post_once = stop_the_child,
  },
})

--- Writes the pack `name` in a folder of the test's own and puts the folder on
--- the child's 'runtimepath'.
---
---@param name string
---@param files? table<string, string|false>
local function add_pack(name, files)
  local root = fixture.directory('office_entry_pack')
  pack_files.write_pack(root, name, files)
  child.lua([[vim.opt.runtimepath:append(...)]], { root })
end

--- Makes the child keep, in `_G.staged_packs`, the name of the pack of every
--- stage the office makes from now on.
local function record_staged_packs()
  child.lua([[
    _G.staged_packs = {}
    local office_scene = require('aineo.office_scene')
    local new_stage = office_scene.new_stage
    office_scene.new_stage = function(options)
      table.insert(_G.staged_packs, options.pack.name)
      return new_stage(options)
    end
  ]])
end

--- The names of the packs the office has staged since `record_staged_packs()`.
---
---@return string[]
local function staged_packs()
  return child.lua_get([[_G.staged_packs]])
end

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `pack-`
---@param settings? table more of `vim.g.aineo`
local function open_layout(name, settings)
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Whether the child shows the office's window.
---
---@return boolean
local function office_shows()
  return office_cells.window(child) ~= vim.NIL
end

--- What `:Aineo office pack` tells the user, as an error, when it cannot use
--- the pack `name`, up to the reason.
---
---@param name string
---@return string
local function cannot_use(name)
  return ('aineo: cannot use the office pack “%s”: '):format(name)
end

--- Whether `text` starts with `prefix`.
---
---@param text string
---@param prefix string
---@return boolean
local function starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

T[':Aineo office pack'] = MiniTest.new_set()

T[':Aineo office pack']['makes the office draw the pack it is given, over office.pack'] = function()
  open_layout('pack-switch', { office = { pack = 'default' } })
  add_pack('alt')
  record_staged_packs()

  entry.command(child, 'Aineo office pack alt')
  entry.command(child, 'Aineo office')

  eq(staged_packs(), { 'alt' })
end

T[':Aineo office pack']['tells the user which pack the office draws from now on'] = function()
  add_pack('alt')

  entry.command(child, 'Aineo office pack alt')

  eq(entry.messages(child), {
    {
      message = 'aineo: the office draws the pack “alt” from now on',
      level = vim.log.levels.INFO,
    },
  })
end

T[':Aineo office pack']['shows again the office that shows, with the pack it is given'] = function()
  open_layout('pack-reshow')
  add_pack('alt')
  entry.command(child, 'Aineo office')
  eq(office_shows(), true)
  record_staged_packs()

  entry.command(child, 'Aineo office pack alt')

  eq(staged_packs(), { 'alt' })
  eq(office_shows(), true)
end

T[':Aineo office pack']['draws the pack from the next show when the office is hidden'] = function()
  open_layout('pack-hidden')
  add_pack('alt')
  record_staged_packs()

  entry.command(child, 'Aineo office pack alt')

  eq(staged_packs(), {})
  eq(office_shows(), false)
  entry.command(child, 'Aineo office')
  eq(staged_packs(), { 'alt' })
end

T[':Aineo office pack']['tells an error naming a pack it does not find, and changes nothing'] = function()
  open_layout('pack-missing')
  entry.command(child, 'Aineo office')
  local window = office_cells.window(child)
  record_staged_packs()

  entry.command(child, 'Aineo office pack nothing_here')

  local messages = entry.messages(child)
  eq(#messages, 1)
  eq(messages[1].level, vim.log.levels.ERROR)
  eq(starts_with(messages[1].message, cannot_use('nothing_here')), true)
  eq(staged_packs(), {})
  eq(office_cells.window(child), window)
end

T[':Aineo office pack']['tells an error for a pack it cannot use, and keeps the pack in use'] = function()
  open_layout('pack-broken')
  add_pack('broken', { ['pack.lua'] = 'return {' })
  record_staged_packs()

  entry.command(child, 'Aineo office pack broken')
  entry.command(child, 'Aineo office')

  local messages = entry.messages(child)
  eq(#messages, 1)
  eq(messages[1].level, vim.log.levels.ERROR)
  eq(starts_with(messages[1].message, cannot_use('broken')), true)
  eq(staged_packs(), { 'default' })
end

T[':Aineo office pack']['refuses a name that leads to another folder'] = function()
  open_layout('pack-outside')
  record_staged_packs()

  entry.command(child, 'Aineo office pack ../outside')
  entry.command(child, 'Aineo office')

  eq(starts_with(entry.messages(child)[1].message, cannot_use('../outside')), true)
  eq(staged_packs(), { 'default' })
end

T[':Aineo office pack']['tells the pack in use and that office.pack names it, when given no name'] = function()
  entry.command(child, 'Aineo office pack')

  eq(entry.messages(child), {
    {
      message = 'aineo: the office pack in use is “default”, from office.pack',
      level = vim.log.levels.INFO,
    },
  })
end

T[':Aineo office pack']['tells the pack in use and that the command chose it, when given no name'] = function()
  add_pack('alt')
  entry.command(child, 'Aineo office pack alt')
  local told_of_the_switch = #entry.messages(child)

  entry.command(child, 'Aineo office pack')

  local messages = entry.messages(child)
  eq(#messages, told_of_the_switch + 1)
  eq(messages[#messages], {
    message = 'aineo: the office pack in use is “alt”, from :Aineo office pack',
    level = vim.log.levels.INFO,
  })
end

T[':Aineo office pack']['is offered after office, with the names of the packs found after pack'] = function()
  add_pack('alt')

  eq(
    child.fn.getcompletion('Aineo office ', 'cmdline'),
    { 'check', 'states', 'preview', 'new', 'pack' }
  )
  eq(child.fn.getcompletion('Aineo office pack ', 'cmdline'), { 'alt', 'default', 'space_station' })
  eq(child.fn.getcompletion('Aineo office pack a', 'cmdline'), { 'alt' })
end

T[':Aineo office pack']['refuses more than a pack’s name, and says what it takes'] = function()
  entry.command(child, 'Aineo office pack alt beta')

  eq(entry.messages(child), { { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR } })
end

return T
