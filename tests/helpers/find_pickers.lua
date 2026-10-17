--- Installs fake third-party file pickers in a child Neovim for the suites of
--- aineo's file finder, so that no picker plugin is ever needed: a fake is a
--- module made available through `package.preload` that records the options
--- it was called with, and, when the
--- test has said which file to pick, opens that file in the window that is
--- current when it is called — where a picker's confirm leaves a file, once
--- its own window has closed.

local M = {}

--- The names of the pickers aineo knows, in the order `find.picker = 'auto'`
--- looks for them.
M.NAMES = { 'snacks', 'fzf-lua', 'telescope', 'mini.pick' }

--- The Lua that installs the fake pickers named by its first argument,
--- `names`, and the path to pick by its second, `picked` (`false` for none):
--- each fake call is kept in `_G.picker_calls` as `{ picker, options }`, the
--- picker's name and the options the call gave. The pinned mini.nvim is on
--- every child's 'runtimepath', so mini.pick is installed unless the Lua
--- hides it: it is hidden when `names` leaves it out.
local INSTALL = [[
  local names, picked = ...
  _G.picker_calls = {}
  local function fake(picker)
    return function(...)
      local options = (select(select('#', ...), ...))
      table.insert(_G.picker_calls, { picker = picker, options = options })
      if picked then
        vim.cmd.edit(vim.fn.fnameescape(picked))
      end
    end
  end
  package.preload['mini.pick'] = function()
    error("module 'mini.pick' not found")
  end
  for _, name in ipairs(names) do
    if name == 'snacks' then
      package.preload['snacks'] = function()
        return { picker = { files = fake('snacks') } }
      end
    elseif name == 'fzf-lua' then
      package.preload['fzf-lua'] = function()
        return { files = fake('fzf-lua') }
      end
    elseif name == 'telescope' then
      package.preload['telescope.builtin'] = function()
        return { find_files = fake('telescope') }
      end
    elseif name == 'mini.pick' then
      package.preload['mini.pick'] = function()
        return { builtin = { files = fake('mini.pick') } }
      end
    end
  end
]]

--- Installs the fake pickers `names` in `child`, each of which opens `picked`,
--- an absolute path, when called; none when `picked` is not given. Every
--- picker `names` leaves out is not installed, mini.pick included.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param names string[] some of `M.NAMES`
---@param picked? string
function M.install(child, names, picked)
  child.lua(INSTALL, { names, picked or false })
end

--- What the fake pickers of `child` have been called with, in order, each
--- as `{ picker = name, options = the options of the call }`.
---
---@param child table
---@return { picker: string, options: table }[]
function M.calls(child)
  return child.lua_get('_G.picker_calls')
end

return M
