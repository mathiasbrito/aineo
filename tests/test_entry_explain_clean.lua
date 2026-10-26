local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case cleans.
local CODE = {
  'local function add(a, b)',
  '  return a - b',
  'end',
  '',
  'return add',
}

--- What the user is told once a buffer is cleaned.
local CLEANED = 'aineo: explanations cleaned from this buffer'

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude`, and keys told apart after 100 ms.
local function start()
  explained.start(child, 'entry-explain-clean', CODE, { claude = { cmd = explained.FAKE_CLAUDE } })
  child.o.timeoutlen = 100
end

--- Types `keys` in the child and waits until it has settled.
---
---@param ... string
local function press(...)
  child.type_keys(...)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- The messages the child was told, without their levels.
---
---@return string[]
local function messages()
  return vim.tbl_map(function(told)
    return told.message
  end, explained.told(child))
end

--- The fix of the issue on line 2.
local FIX = {
  summary = 'Add.',
  edits = {
    { line = 2, last = 2, old = { '  return a - b' }, new = { '  return a + b' }, why = 'Adds.' },
  },
}

--- How many extmarks the child's current buffer holds in aineo's
--- namespaces.
---
---@return integer
local function aineo_extmarks()
  return child.lua_get([[(function()
    local found = 0
    for name, namespace in pairs(vim.api.nvim_get_namespaces()) do
      if name:find('^aineo') then
        found = found + #vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})
      end
    end
    return found
  end)()]])
end

--- The keys aineo mapped for the child's current buffer alone, told by
--- their `desc`, each after the letter of its mode.
---
---@return string[]
local function aineo_buffer_keys()
  return child.lua_get([[(function()
    local found = {}
    for _, mode in ipairs({ 'n', 'x', 'o' }) do
      for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
        if (mapping.desc or ''):find('^aineo') then
          table.insert(found, mode .. ' ' .. mapping.lhs)
        end
      end
    end
    return found
  end)()]])
end

--- Starts the child (`start()`) and has the buffer show all the keys can
--- add: an explanation of line 1 (`\\V`), an issue of line 2 (`\\VI`)
--- marked (`\\vm`), its fix shown (`\\Vf`), and a request for
--- explanations that answers line 3 after 1.5 s, running.
local function fill_buffer()
  start()
  explained.place(child, 'explanations', { { line = 1, text = 'Defines add.' } })
  explained.place(child, 'issues', { { line = 2, text = 'Subtracts where it should add.' } })
  child.cmd('2')
  press('\\vm')
  explained.answer_with(child, FIX)
  press('\\Vf')
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get('require("aineo.explain.preview").is_shown(0)')
  end, 20)
  explained.begin_slowly(child, 'explanations', { { line = 3, text = 'Late.' } }, 1500)
end

T['\\vc'] = MiniTest.new_set()

T['\\vc']['on a buffer with nothing to clean says so once, and changes nothing'] = function()
  start()

  press('\\vc')

  eq(messages(), { CLEANED })
  eq(child.api.nvim_buf_get_lines(0, 0, -1, false), CODE)
end

T['\\vc']['leaves no virtual line, key or badge of aineo in the buffer'] = function()
  fill_buffer()
  local before = { aineo_extmarks() > 0, #aineo_buffer_keys() > 0, #explained.floats(child) > 0 }

  press('\\vc')

  eq(before, { true, true, true })
  eq({ aineo_extmarks(), aineo_buffer_keys(), explained.floats(child) }, { 0, {}, {} })
end

T['\\vc']['gives back the window its options and the buffer its modifiable'] = function()
  fill_buffer()
  local while_shown = { child.wo.conceallevel, child.wo.concealcursor, child.bo.modifiable }

  press('\\vc')

  eq(while_shown, { 2, 'n', false })
  eq({ child.wo.conceallevel, child.wo.concealcursor, child.bo.modifiable }, { 0, '', true })
end

T['\\vc']['shows no answer of the request that ran, later'] = function()
  fill_buffer()

  press('\\vc')
  local answered_later = vim.wait(2500, function()
    return aineo_extmarks() > 0
  end, 50)

  eq(answered_later, false)
end

T['\\vc']['leaves the text and its undo history as they were'] = function()
  fill_buffer()
  local before = child.lua_get('{ vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.fn.undotree() }')

  press('\\vc')

  eq(child.lua_get('{ vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.fn.undotree() }'), before)
end

T[':Aineo explain clear'] = MiniTest.new_set()

T[':Aineo explain clear']['closes the float steering a request for the buffer'] = function()
  start()
  local buffer = child.api.nvim_get_current_buf()
  press('\\VV')
  local opened = #explained.floats(child)

  child.lua(
    [[vim.api.nvim_buf_call(..., function()
      vim.cmd('Aineo explain clear')
    end)]],
    { buffer }
  )

  eq({ opened, explained.floats(child) }, { 1, {} })
end

return T
