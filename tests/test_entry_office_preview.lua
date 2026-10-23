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

--- What `:Aineo office preview` tells the user when no aineo tab exists.
local NO_TAB = 'aineo: there is no aineo tab to show the office in'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `preview-`
local function open_layout(name)
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- The first line of the office's window, once it shows one.
---
---@return string|nil
local function first_line_of_the_office()
  local window = office_cells.window(child)
  if window == vim.NIL then
    return nil
  end
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, 1, false)[1]
  ]],
    { window }
  )
end

--- Waits, at most five seconds, until the office's first line names a
--- preview, and gives that line.
---
---@return string|nil
local function wait_for_the_preview()
  vim.wait(5000, function()
    return (first_line_of_the_office() or ''):find('preview 1/24', 1, true) ~= nil
  end, 20)
  return first_line_of_the_office()
end

T[':Aineo office preview'] = MiniTest.new_set()

T[':Aineo office preview']['shows the preview over the right column of the aineo tab'] = function()
  open_layout('preview-shows')
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  entry.command(child, 'Aineo office preview')

  eq((wait_for_the_preview() or ''):find('preview 1/24 · arriving', 1, true) ~= nil, true)
  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_cells.window(child) })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
end

T[':Aineo office preview']['previews the pack it is given'] = function()
  open_layout('preview-named')
  local root = fixture.directory('office_entry_preview')
  pack_files.write_pack(root, 'alt')
  child.lua([[vim.opt.runtimepath:append(...)]], { root })
  child.lua([[
    local office_scene = require('aineo.office_scene')
    local new_stage = office_scene.new_stage
    office_scene.new_stage = function(options)
      _G.staged_pack = options.pack.name
      return new_stage(options)
    end
  ]])

  entry.command(child, 'Aineo office preview alt')

  eq(child.lua_get([[_G.staged_pack]]), 'alt')
end

T[':Aineo office preview']['tells the user when there is no aineo tab, and shows nothing'] = function()
  entry.command(child, 'Aineo office preview')

  eq(entry.messages(child), { { message = NO_TAB, level = vim.log.levels.WARN } })
  eq(office_cells.window(child), vim.NIL)
end

T[':Aineo office preview']['refuses more than a pack’s name, and says what it takes'] = function()
  entry.command(child, 'Aineo office preview alt beta')

  eq(entry.messages(child), { { message = entry.OFFICE_USAGE, level = vim.log.levels.ERROR } })
end

return T
