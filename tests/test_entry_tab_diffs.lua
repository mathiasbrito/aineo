local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry.restart(child)
    end,
    post_once = child.stop,
  },
})

--- The name of the first tab's files buffer, and of the diff it shows of
--- `notes.txt`.
local FIRST_FILES = 'aineo://changes-files'
local FIRST_DIFF = 'aineo://diff/notes.txt'

--- The same two names in the second tab, whose changes pane is a copy of its
--- own.
local SECOND_FILES = 'aineo://copy1/changes-files'
local SECOND_DIFF = 'aineo://copy1/diff/notes.txt'

--- Opens the first tab of aineo in a repository holding `notes.txt`, changed
--- since the session began, and a second tab beside it, both on fakes that
--- stay ready.
---
---@param name string the case's own name, starting `tabdiffs-`
local function open_two_tabs_in_a_changed_repository(name)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  tabs.open_first_tab(child, name)
  git_repo.write(top, 'notes.txt', { 'two' })
  tabs.use_next_fake(child, tabs.fake(name .. '-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
end

--- Goes to the tab page numbered `number`, shows its changes pane, waits
--- until its files window lists `notes.txt`, and presses Enter on it.
---
---@param number integer
---@param files string the name of that tab's files buffer
local function open_diff_of_notes_in_tab(number, files)
  child.cmd('tabnext ' .. number)
  entry.press(child, '\\g')
  git_repo.wait_until(files .. ' listing notes.txt', function()
    return child.lua_get(
      [[(function(name)
        local buffer = vim.fn.bufnr(name)
        local second = buffer ~= -1 and vim.api.nvim_buf_get_lines(buffer, 1, 2, true)[1] or ''
        return vim.fn.bufwinid(buffer) ~= -1 and second:find('notes', 1, true) ~= nil
      end)(...)]],
      { files }
    )
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { files })
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  entry.press(child, '<CR>')
end

--- The names of the buffers shown by the windows of each tab page, in the
--- order of the tab pages, terminals left out.
---
---@return string[][]
local function buffers_shown_per_tab()
  return child.lua_get([[
    vim.tbl_map(function(tabpage)
      local names = {}
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
        if vim.startswith(name, 'aineo://') then
          table.insert(names, name)
        end
      end
      table.sort(names)
      return names
    end, vim.api.nvim_list_tabpages())
  ]])
end

T['Enter on the same file in two tabs'] = MiniTest.new_set()

T['Enter on the same file in two tabs']['shows each tab its own diff buffer, under the name of its own pane'] = function()
  open_two_tabs_in_a_changed_repository('tabdiffs-enter')

  open_diff_of_notes_in_tab(1, FIRST_FILES)
  git_repo.wait_until(FIRST_DIFF .. ' shown', function()
    return child.lua_get('vim.fn.bufwinid(...)', { FIRST_DIFF }) ~= -1
  end)
  open_diff_of_notes_in_tab(2, SECOND_FILES)
  git_repo.wait_until(SECOND_DIFF .. ' shown', function()
    return child.lua_get('vim.fn.bufwinid(...)', { SECOND_DIFF }) ~= -1
  end)

  eq(buffers_shown_per_tab(), {
    { 'aineo://changes-commits', FIRST_FILES, FIRST_DIFF },
    { 'aineo://copy1/changes-commits', SECOND_FILES, SECOND_DIFF },
  })
end

T['Enter on the same file in two tabs']['leaves the first tab’s diff in place when the second tab closes its own'] = function()
  open_two_tabs_in_a_changed_repository('tabdiffs-close')
  open_diff_of_notes_in_tab(1, FIRST_FILES)
  git_repo.wait_until(FIRST_DIFF .. ' shown', function()
    return child.lua_get('vim.fn.bufwinid(...)', { FIRST_DIFF }) ~= -1
  end)
  open_diff_of_notes_in_tab(2, SECOND_FILES)
  git_repo.wait_until(SECOND_DIFF .. ' shown', function()
    return child.lua_get('vim.fn.bufwinid(...)', { SECOND_DIFF }) ~= -1
  end)

  entry.command(child, 'Aineo diff close')

  eq({ child.fn.bufexists(FIRST_DIFF), child.fn.bufexists(SECOND_DIFF) }, { 1, 0 })
  eq(child.lua_get('#vim.fn.win_findbuf(vim.fn.bufnr(...))', { FIRST_DIFF }), 1)
end

return T
