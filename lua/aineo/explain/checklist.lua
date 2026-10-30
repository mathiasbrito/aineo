--- The checklist: a float beside the cursor listing the tests Claude Code
--- found worth writing, in which the user marks those to write.

local M = {}

--- What a checklist lists and what it does with the tests chosen.
---@class aineo.explain.Choosing
---@field title string what the checklist is for, said in its title
---@field tests aineo.explain.ListedTest[] the tests listed, in their order
---@field on_choose fun(chosen: aineo.explain.ListedTest[]) called, after the float is closed, with the tests chosen, in their order; an error it raises is told to the user, once

--- What the footer of a checklist says its keys do.
local FOOTER = ' x or <Space> marks · a marks all · <CR> writes · q cancels '

--- The line that lists `test`, marked or not.
---
---@param test aineo.explain.ListedTest
---@param marked boolean
---@return string
local function line_of(test, marked)
  return ('[%s] %s — %s'):format(marked and 'x' or ' ', test.name, test.checks)
end

--- The float's configuration for `lines`, the checklist's text, beside the
--- cursor, as wide as its longest line or the screen allows, titled with
--- `title` and its keys in its footer.
---
---@param lines string[]
---@param title string
---@return vim.api.keyset.win_config
local function float_config(lines, title)
  local widest = vim.iter(lines):fold(vim.fn.strdisplaywidth(FOOTER), function(width, line)
    return math.max(width, vim.fn.strdisplaywidth(line))
  end)
  return {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = math.max(1, math.min(widest + 1, vim.o.columns - 4)),
    height = math.max(1, math.min(#lines, vim.o.lines - 6)),
    border = 'rounded',
    title = ' ' .. title .. ' ',
    footer = FOOTER,
    style = 'minimal',
  }
end

--- Opens a checklist of `choosing.tests` in a float beside the cursor, the
--- cursor in it on the first test, none marked: `x` or `<Space>` marks the
--- test on the cursor's line or unmarks it, `a` marks them all, `<CR>`
--- closes the float and calls `choosing.on_choose` with the tests marked —
--- the one on the cursor's line when none is — and `q` or `<Esc>` closes
--- it, choosing nothing.
---
---@param choosing aineo.explain.Choosing
function M.open(choosing)
  local tests = choosing.tests
  local marked = {}
  local lines = vim.tbl_map(function(test)
    return line_of(test, false)
  end, tests)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  local window = vim.api.nvim_open_win(buffer, true, float_config(lines, choosing.title))

  local function redraw(index)
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(
      buffer,
      index - 1,
      index,
      true,
      { line_of(tests[index], marked[index]) }
    )
    vim.bo[buffer].modifiable = false
  end

  local function toggle()
    local index = vim.api.nvim_win_get_cursor(window)[1]
    marked[index] = not marked[index] or nil
    redraw(index)
  end

  local function mark_all()
    for index in ipairs(tests) do
      marked[index] = true
      redraw(index)
    end
  end

  local function close()
    if vim.api.nvim_win_is_valid(window) then
      vim.api.nvim_win_close(window, true)
    end
  end

  local function choose()
    local chosen = {}
    for index, test in ipairs(tests) do
      if marked[index] then
        table.insert(chosen, test)
      end
    end
    if #chosen == 0 then
      chosen = { tests[vim.api.nvim_win_get_cursor(window)[1]] }
    end
    close()
    local called, problem = pcall(choosing.on_choose, chosen)
    if not called then
      vim.notify('aineo: ' .. tostring(problem), vim.log.levels.ERROR)
    end
  end

  local actions = { x = toggle, ['<Space>'] = toggle, a = mark_all, ['<CR>'] = choose }
  actions.q = close
  actions['<Esc>'] = close
  for key, action in pairs(actions) do
    vim.keymap.set('n', key, action, { buffer = buffer, nowait = true })
  end
end

return M
