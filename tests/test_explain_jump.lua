local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case explains: twelve, the third and the
--- ninth indented.
local CODE = {
  'line 1',
  'line 2',
  '    line 3',
  'line 4',
  'line 5',
  'line 6',
  'line 7',
  'line 8',
  '  line 9',
  'line 10',
  'line 11',
  'line 12',
}

--- Starts the child with `CODE` open and nothing explained.
local function start()
  explained.start(child, 'explain-jump', CODE)
end

--- Places explanations on the lines `lines` of the child's buffer.
---
---@param lines integer[]
local function explain_lines(lines)
  explained.place(
    child,
    'explanations',
    vim.tbl_map(function(line)
      return { line = line, text = 'Explains line ' .. line .. '.' }
    end, lines)
  )
end

--- Places issues on the lines `lines` of the child's buffer.
---
---@param lines integer[]
local function find_issues_on(lines)
  explained.place(
    child,
    'issues',
    vim.tbl_map(function(line)
      return { line = line, text = 'Breaks at line ' .. line .. '.' }
    end, lines)
  )
end

--- Types `keys` in the child, mappings applied, and waits until they have run.
---
---@param keys string
local function press(keys)
  child.type_keys(keys)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- The cursor's line and column, as the child holds them.
---
---@return integer[]
local function cursor()
  return child.api.nvim_win_get_cursor(0)
end

T[']v'] = MiniTest.new_set({ hooks = { pre_case = start } })

T[']v']['moves to the line of the next explanation, at its first non-blank'] = function()
  explain_lines({ 3, 6 })

  press(']v')

  eq(cursor(), { 3, 4 })
end

T[']v']['moves from a line between explanations to the one after it'] = function()
  explain_lines({ 3, 6, 9 })
  child.api.nvim_win_set_cursor(0, { 4, 0 })

  press(']v')

  eq(cursor(), { 6, 0 })
end

T[']v']['moves on from the line of an explanation to the next, not to itself'] = function()
  explain_lines({ 3, 6, 9 })
  child.api.nvim_win_set_cursor(0, { 6, 0 })

  press(']v')

  eq(cursor(), { 9, 2 })
end

T[']v']['with a count moves that many explanations on'] = function()
  explain_lines({ 3, 6, 9, 11 })

  press('3]v')

  eq(cursor(), { 9, 2 })
end

T[']v']['wraps around to the first explanation after the last'] = function()
  explain_lines({ 3, 6 })
  child.api.nvim_win_set_cursor(0, { 8, 0 })

  press(']v')

  eq(cursor(), { 3, 4 })
end

T[']v']['with a count wraps around as many times as it needs'] = function()
  explain_lines({ 3, 6, 9 })

  press('5]v')

  eq(cursor(), { 6, 0 })
end

T['[v'] = MiniTest.new_set({ hooks = { pre_case = start } })

T['[v']['moves to the line of the previous explanation'] = function()
  explain_lines({ 3, 6, 9 })
  child.api.nvim_win_set_cursor(0, { 8, 0 })

  press('[v')

  eq(cursor(), { 6, 0 })
end

T['[v']['with a count moves that many explanations back'] = function()
  explain_lines({ 3, 6, 9 })
  child.api.nvim_win_set_cursor(0, { 12, 0 })

  press('2[v')

  eq(cursor(), { 6, 0 })
end

T['[v']['wraps around to the last explanation before the first'] = function()
  explain_lines({ 3, 6, 9 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('[v')

  eq(cursor(), { 9, 2 })
end

T['both kinds'] = MiniTest.new_set({ hooks = { pre_case = start } })

T['both kinds']['are jumped between as one list, a line with both counting once'] = function()
  explain_lines({ 3, 8 })
  find_issues_on({ 8, 11 })
  local visited = {}

  for _ = 1, 4 do
    press(']v')
    table.insert(visited, cursor()[1])
  end

  eq(visited, { 3, 8, 11, 3 })
end

T['both kinds']['are jumped back through as one list'] = function()
  explain_lines({ 3, 8 })
  find_issues_on({ 5, 8 })
  child.api.nvim_win_set_cursor(0, { 12, 0 })
  local visited = {}

  for _ = 1, 4 do
    press('[v')
    table.insert(visited, cursor()[1])
  end

  eq(visited, { 8, 5, 3, 8 })
end

T['a jump'] = MiniTest.new_set({ hooks = { pre_case = start } })

T['a jump']['in Visual mode extends the selection to the line it lands on'] = function()
  explain_lines({ 3, 6 })

  press('V]v')

  eq({ child.fn.mode(), child.fn.line('v'), child.fn.line('.') }, { 'V', 1, 3 })
end

T['a jump']['in Operator-pending mode is the motion of the operator'] = function()
  explain_lines({ 3, 6 })
  child.api.nvim_win_set_cursor(0, { 2, 0 })

  press('d]v')

  eq(child.api.nvim_buf_get_lines(0, 0, 3, false), { 'line 1', 'line 3', 'line 4' })
end

T['a jump']['sets the previous context mark first, so that two quotes come back'] = function()
  explain_lines({ 6 })
  child.api.nvim_win_set_cursor(0, { 2, 0 })

  press(']v')
  press("''")

  eq(cursor(), { 2, 0 })
end

T['a jump']['is an entry of the jumplist that Ctrl-O goes back through'] = function()
  explain_lines({ 6 })
  child.api.nvim_win_set_cursor(0, { 2, 0 })

  press(']v')
  press('<C-o>')

  eq(cursor(), { 2, 0 })
end

T['a jump']['to an explanation on the cursor’s own line, the only one, stays on it'] = function()
  explain_lines({ 6 })
  child.api.nvim_win_set_cursor(0, { 6, 3 })

  press(']v')

  eq(cursor(), { 6, 0 })
end

T['a jump']['into a closed fold opens it, at each landing'] = function()
  explain_lines({ 4, 5, 9 })
  child.cmd('4,7fold')

  press(']v')
  local first = child.fn.foldclosed(child.fn.line('.'))
  press(']v')
  local second = child.fn.foldclosed(child.fn.line('.'))

  eq({ child.fn.line('.'), first, second }, { 5, -1, -1 })
end

T['a jump']['to the top line of the window scrolls up to show the explanation above it'] = function()
  local lines = {}
  for number = 1, 100 do
    lines[number] = 'line ' .. number
  end
  explained.start(child, 'explain-jump-scroll', lines)
  child.o.lines = 20
  explained.place(child, 'explanations', { { line = 50, text = ('x'):rep(200) } })
  child.cmd('normal! 52zt')
  child.api.nvim_win_set_cursor(0, { 60, 0 })

  press('[v')

  local view = child.fn.winsaveview()
  eq({ view.lnum, view.topline, view.topfill }, { 50, 50, 3 })
end

T['the mappings'] = MiniTest.new_set({ hooks = { pre_case = start } })

--- The buffer-local mapping of `keys` in `mode` as the child holds it: its
--- right side and whether it is local to the buffer; none when unmapped.
---
---@param mode string
---@param keys string
---@return { rhs: string, buffer: integer }|nil
local function mapping(mode, keys)
  return child.lua(
    [[
    local found = vim.fn.maparg(select(2, ...), (...), false, true)
    if next(found) == nil then
      return nil
    end
    return { rhs = found.rhs, buffer = found.buffer }
  ]],
    { mode, keys }
  )
end

T['the mappings']['are not there while the buffer shows no explanation'] = function()
  eq({ mapping('n', ']v'), mapping('n', '[v') }, { vim.NIL, vim.NIL })
end

T['the mappings']['appear for the buffer once it shows an explanation, to the plug mappings, in Normal, Visual and Operator-pending mode'] = function()
  explain_lines({ 3 })

  for _, mode in ipairs({ 'n', 'x', 'o' }) do
    eq(mapping(mode, ']v'), { rhs = '<Plug>(aineo-explain-next)', buffer = 1 })
    eq(mapping(mode, '[v'), { rhs = '<Plug>(aineo-explain-previous)', buffer = 1 })
  end
end

T['the mappings']['appear for an issue alone too'] = function()
  find_issues_on({ 3 })

  eq(mapping('n', ']v').buffer, 1)
end

T['the mappings']['leave when the explanations are cleared'] = function()
  explain_lines({ 3 })

  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  eq({ mapping('n', ']v'), mapping('x', '[v') }, { vim.NIL, vim.NIL })
end

T['the mappings']['stay while the other kind is still shown'] = function()
  explain_lines({ 3 })
  find_issues_on({ 5 })

  press('\\vi')

  eq(mapping('n', ']v').buffer, 1)
end

T['the mappings']['leave when edits delete every line that is explained'] = function()
  explain_lines({ 3 })

  child.api.nvim_buf_set_lines(0, 2, 3, false, {})

  vim.wait(explained.PATIENCE_MS, function()
    return mapping('n', ']v') == vim.NIL
  end, 20)
  eq({ mapping('n', ']v'), mapping('o', '[v') }, { vim.NIL, vim.NIL })
end

T['the mappings']['leave when an edit and a jump come in one tick, the jump finding the lines gone first'] = function()
  explain_lines({ 3 })

  child.lua([[
    vim.api.nvim_buf_set_lines(0, 2, 3, false, {})
    require('aineo.explain').jump(vim.api.nvim_get_current_win(), 'next', 1)
  ]])

  vim.wait(explained.PATIENCE_MS, function()
    return mapping('n', ']v') == vim.NIL
  end, 20)
  eq({ mapping('n', ']v'), mapping('o', '[v') }, { vim.NIL, vim.NIL })
end

T['the mappings']['of the user, local to the buffer, are never replaced nor removed'] = function()
  child.cmd('nnoremap <buffer> ]v :echo "mine"<CR>')
  explain_lines({ 3 })

  eq(mapping('n', ']v'), { rhs = ':echo "mine"<CR>', buffer = 1 })
  eq(mapping('n', '[v').rhs, '<Plug>(aineo-explain-previous)')
  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")
  eq(mapping('n', ']v'), { rhs = ':echo "mine"<CR>', buffer = 1 })
end

T['the mappings']['of the user, global, are never replaced either'] = function()
  child.cmd('nnoremap [v :echo "global"<CR>')
  explain_lines({ 3 })

  eq(mapping('n', '[v'), { rhs = ':echo "global"<CR>', buffer = 0 })
end

T['the plug mappings'] = MiniTest.new_set({ hooks = { pre_case = start } })

T['the plug mappings']['exist in Normal, Visual and Operator-pending mode before anything is explained'] = function()
  for _, mode in ipairs({ 'n', 'x', 'o' }) do
    eq(mapping(mode, '<Plug>(aineo-explain-next)').buffer, 0)
    eq(mapping(mode, '<Plug>(aineo-explain-previous)').buffer, 0)
  end
end

T['the plug mappings']['with nothing explained tell the user once, and leave the cursor'] = function()
  child.api.nvim_win_set_cursor(0, { 4, 2 })

  press('<Plug>(aineo-explain-next)')

  eq(cursor(), { 4, 2 })
  eq(explained.told(child), {
    { message = 'aineo: no explanation to jump to', level = 2 },
  })
end

return T
