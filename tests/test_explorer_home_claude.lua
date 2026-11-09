local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

--- How long a case waits for the flash to end, in milliseconds.
local PATIENCE_MS = 5000

--- The shared state of a case: what the fake git lists and the work the
--- session reports, changed between reads.
local world

local explorer

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      world = {
        files = { 'a.txt', 'b.txt', 'c.txt' },
        changes = {},
        counts = {},
        work = { top = '/repo', paths = {} },
        folder = '/repo',
      }
      local git = {
        find_repository = function(_, done)
          done(nil, { top = '/repo', git_directory = '/repo/.git', branch = 'main' })
        end,
        list_files = function(_, done)
          done(nil, world.files)
        end,
        uncommitted_files = function(_, done)
          done(nil, world.changes)
        end,
        ignored_files = function(_, done)
          done(nil, {})
        end,
        submodule_paths = function(_, done)
          done(nil, {})
        end,
        list_worktrees = function(_, done)
          done(nil, {})
        end,
        watch_repository = function() end,
        line_counts = function(_, done)
          done(nil, world.counts)
        end,
      }
      explorer = require('aineo.explorer').new({
        git = git,
        claude_folder = function()
          return world.folder
        end,
        open_file = function() end,
        paste = function() end,
        quote_name = function(name)
          return name
        end,
        change_groups = {
          added = 'DiffAdd',
          modified = 'DiffChange',
          deleted = 'DiffDelete',
          renamed = 'DiffChange',
          type_changed = 'DiffChange',
          untracked = 'DiffAdd',
        },
        define_change_groups = function() end,
        session_work = function(done)
          done(world.work)
        end,
      })
      vim.cmd('only')
    end,
    post_case = function()
      explorer.let_go()
    end,
  },
})

--- Shows the explorer in the current window, which reads its tree for the
--- first time.
local function show_explorer()
  vim.api.nvim_win_set_buf(0, explorer.buffer())
end

--- The lines of the explorer's buffer that flash, from 1.
---
---@return integer[]
local function flashing_lines()
  local buffer = explorer.made_buffer()
  local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
  local lines = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
    if mark[4].line_hl_group == 'AineoExplorerClaudeFlash' then
      table.insert(lines, mark[2] + 1)
    end
  end
  return lines
end

--- The lines of the explorer's buffer that carry Claude's mark, from 1.
---
---@return integer[]
local function marked_lines()
  local buffer = explorer.made_buffer()
  local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
  local lines = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
    for _, chunk in ipairs(mark[4].virt_text or {}) do
      if chunk[1] == '✦ ' then
        table.insert(lines, mark[2] + 1)
      end
    end
  end
  return lines
end

T['the work of the session'] = MiniTest.new_set()

T['the work of the session']['flashes the lines of the files that join it after the first read, for 1.5 seconds'] = function()
  world.work.paths = { 'a.txt' }
  show_explorer()
  eq(flashing_lines(), {})

  world.work.paths = { 'a.txt', 'c.txt' }
  explorer.refresh()
  local started = vim.uv.now()
  local flashing = flashing_lines()
  local ended = vim.wait(PATIENCE_MS, function()
    return #flashing_lines() == 0
  end, 10)
  local lasted = vim.uv.now() - started

  eq(flashing, { 4 })
  eq(ended, true)
  eq(lasted >= 1400 and lasted <= 2200, true)
  eq(marked_lines(), { 2, 4 })
end

T['the work of the session']['flashes the line of a file whose change is read anew'] = function()
  world.work.paths = { 'a.txt' }
  world.changes = { { path = 'a.txt', kind = 'modified' } }
  world.counts = { ['a.txt'] = { added = 1, removed = 0 } }
  show_explorer()

  world.counts = { ['a.txt'] = { added = 2, removed = 0 } }
  explorer.refresh()

  eq(flashing_lines(), { 2 })
end

T['the work of the session']['flashes a file for the whole time again when its change is read anew while it flashes'] = function()
  world.changes = { { path = 'a.txt', kind = 'modified' } }
  world.counts = { ['a.txt'] = { added = 1, removed = 0 } }
  world.work = { top = '/repo', paths = {} }
  show_explorer()
  world.work.paths = { 'a.txt' }
  explorer.refresh()
  local joined = vim.uv.now()
  vim.wait(1000)

  world.counts = { ['a.txt'] = { added = 2, removed = 0 } }
  explorer.refresh()
  vim.wait(math.max(0, joined + 1700 - vim.uv.now()))

  eq(flashing_lines(), { 2 })
end

T['the work of the session']['flashes nothing when it is read again as it was'] = function()
  world.work.paths = { 'a.txt' }
  world.changes = { { path = 'a.txt', kind = 'modified' } }
  show_explorer()

  explorer.refresh()

  eq(flashing_lines(), {})
end

T['the work of the session']['flashes nothing at the read after one that did not know it'] = function()
  world.work = nil
  show_explorer()
  eq(marked_lines(), {})

  world.work = { top = '/repo', paths = { 'a.txt', 'b.txt' } }
  explorer.refresh()

  eq(flashing_lines(), {})
  eq(marked_lines(), { 2, 3 })
end

T['the work of the session']['flashes nothing at the read after one that did not know it, whatever it read before'] = function()
  world.work = { top = '/repo', paths = { 'a.txt' } }
  show_explorer()
  world.work = nil
  explorer.refresh()

  world.work = { top = '/repo', paths = { 'a.txt', 'b.txt' } }
  explorer.refresh()

  eq(flashing_lines(), {})
end

T['the work of the session']['flashes nothing when the folder shown is another, its files named from it'] = function()
  world.files = { 'a.txt', 'sub/x.txt', 'sub/y.txt' }
  world.work = { top = '/repo', paths = { 'a.txt', 'sub/x.txt' } }
  show_explorer()

  world.folder = '/repo/sub'
  explorer.refresh()

  eq(marked_lines(), { 2 })
  eq(flashing_lines(), {})
end

T['the work of the session']['is not marked in a repository that is not the session’s'] = function()
  world.work = { top = '/elsewhere', paths = { 'a.txt' } }

  show_explorer()

  eq(marked_lines(), {})
end

return T
