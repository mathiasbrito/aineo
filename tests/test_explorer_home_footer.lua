local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')
local footer = dofile('tests/helpers/explorer_footer.lua')

local eq = MiniTest.expect.equality

--- How long a case waits for the footer to follow its window, in ms.
local WAIT_MS = 2000

--- What asks the user for text, as the editor gives it, put back after each
--- case that answers in its place.
local editor_input = vim.ui.input

local world
local explorer

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      world = fake_explorer.new_world()
      explorer = fake_explorer.new(world)
      vim.cmd('tabonly')
      vim.cmd('only')
      vim.api.nvim_win_set_buf(0, explorer.buffer())
    end,
    post_case = function()
      explorer.let_go()
      vim.ui.input = editor_input
    end,
  },
})

--- Has the explorer list the files `file01.txt` to `file60.txt`, more than
--- its window shows.
local function list_many_files()
  world.files = vim.fn.map(vim.fn.range(1, 60), 'printf("file%02d.txt", v:val)')
  explorer.refresh()
end

T['the footer'] = MiniTest.new_set()

T['the footer']['sits on the bottom rows of a window showing the explorer, with what it says'] = function()
  local window = vim.api.nvim_get_current_win()
  local height, width = vim.api.nvim_win_get_height(window), vim.api.nvim_win_get_width(window)

  local lines, placement = footer.lines(window), footer.placement(window)

  eq(lines, { '/repo', '  main', 'ignored hidden · dotfiles shown' })
  eq(placement, { row = height - 3, col = 0, width = width, height = 3, focusable = false })
end

T['the footer']['says what the keys turned, as they turn it'] = function()
  local window = vim.api.nvim_get_current_win()

  vim.api.nvim_feedkeys('H', 'x', false)

  eq(footer.lines(window)[3], 'ignored hidden · dotfiles hidden')
end

T['the footer']['moves to the new bottom rows of its window, and takes its new width, as it resizes'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.cmd('botright split')
  vim.api.nvim_win_set_height(window, 15)
  vim.api.nvim_set_current_win(window)
  vim.cmd('vsplit')
  local height, width = vim.api.nvim_win_get_height(window), vim.api.nvim_win_get_width(window)

  vim.wait(WAIT_MS, function()
    local placement = footer.placement(window)
    return placement.row == height - 3 and placement.width == width
  end)

  eq(footer.placement(window).row, height - 3)
  eq(footer.placement(window).width, width)
end

T['the footer']['stays on the bottom rows as the tree scrolls'] = function()
  list_many_files()
  local window = vim.api.nvim_get_current_win()
  local before = footer.placement(window)

  vim.cmd('normal! 20\5')

  eq(vim.fn.line('w0') > 1, true)
  eq(footer.placement(window), before)
end

T['the footer']['sits on each window that shows the explorer, one each'] = function()
  local first = vim.api.nvim_get_current_win()
  vim.cmd('vsplit')
  local second = vim.api.nvim_get_current_win()

  vim.wait(WAIT_MS, function()
    return #footer.footers_of(second) == 1
  end)

  eq({ #footer.footers_of(first), #footer.footers_of(second) }, { 1, 1 })
end

T['the footer']['sits on a window of another tab page that shows the explorer'] = function()
  vim.cmd('tabnew')
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(window, explorer.buffer())

  vim.wait(WAIT_MS, function()
    return footer.footer_of(window) ~= nil
  end)

  eq(footer.lines(window), { '/repo', '  main', 'ignored hidden · dotfiles shown' })
  eq(vim.api.nvim_win_get_tabpage(footer.footer_of(window)), vim.api.nvim_get_current_tabpage())
end

T['the footer']['closes with its window'] = function()
  local first = vim.api.nvim_get_current_win()
  vim.cmd('vsplit')
  local second = vim.api.nvim_get_current_win()
  vim.wait(WAIT_MS, function()
    return footer.footer_of(second) ~= nil
  end)
  local second_footer = footer.footer_of(second)

  vim.api.nvim_win_close(second, true)
  vim.wait(WAIT_MS, function()
    return not vim.api.nvim_win_is_valid(second_footer)
  end)

  eq(vim.api.nvim_win_is_valid(second_footer), false)
  eq(#footer.footers_of(first), 1)
end

T['the footer']['stays as git fails, the failure alone on the tree’s first line'] = function()
  local window = vim.api.nvim_get_current_win()
  world.list_failure = { reason = 'exit', message = 'boom' }

  explorer.refresh()

  eq(vim.api.nvim_buf_get_lines(explorer.made_buffer(), 0, -1, false), {
    '  git could not list the files: boom',
  })
  eq(footer.lines(window), { '/repo', '  main', 'ignored hidden · dotfiles shown' })
end

T['the footer']['closes as the explorer is let go'] = function()
  local shown_footer = footer.footer_of(vim.api.nvim_get_current_win())

  explorer.let_go()

  eq(vim.api.nvim_win_is_valid(shown_footer), false)
end

T['the footer']['comes back on its window when something closed it'] = function()
  local window = vim.api.nvim_get_current_win()

  vim.api.nvim_win_close(footer.footer_of(window), true)
  vim.wait(WAIT_MS, function()
    return footer.footer_of(window) ~= nil
  end)

  eq(footer.lines(window), { '/repo', '  main', 'ignored hidden · dotfiles shown' })
end

T['the footer']['is the title alone in a window shorter than 12 rows'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.cmd('botright split')
  vim.api.nvim_win_set_height(window, 8)

  vim.wait(WAIT_MS, function()
    return footer.placement(window).height == 1
  end)

  eq(footer.lines(window), { '/repo' })
  eq(footer.placement(window).row, 7)
end

T['the footer']['shows each line in a group of its own, linked by default'] = function()
  local window = vim.api.nvim_get_current_win()
  world.changes = { { path = 'a.txt', kind = 'modified' } }
  explorer.refresh()
  vim.ui.input = function(_, on_confirm)
    on_confirm('a')
  end
  vim.api.nvim_feedkeys('f', 'x', false)

  local groups = footer.line_groups(window)

  eq(groups, {
    'AineoExplorerFooterTitle',
    'AineoExplorerFooterBranch',
    'AineoExplorerFooterSummary',
    'AineoExplorerFooterToggles',
    'AineoExplorerFooterFilter',
  })
  eq(vim.api.nvim_get_hl(0, { name = 'AineoExplorerFooterTitle' }).link, 'Title')
  eq(vim.api.nvim_get_hl(0, { name = 'AineoExplorerFooterToggles' }).link, 'Comment')
end

T['the tree under the footer'] = MiniTest.new_set()

T['the tree under the footer']['scrolls far enough for its last entry to show above the footer'] = function()
  list_many_files()
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 60, 0 })

  vim.cmd('normal! zb')

  eq(vim.fn.winline(), vim.api.nvim_win_get_height(window) - 3)
end

T['the tree under the footer']['shows a file revealed above the footer'] = function()
  list_many_files()
  local window = vim.api.nvim_get_current_win()
  vim.cmd('botright new')

  explorer.reveal('/repo/file60.txt')

  eq(vim.api.nvim_win_get_cursor(window)[1], 60)
  eq(
    vim.api.nvim_win_call(window, vim.fn.winline),
    vim.api.nvim_win_get_height(window) - footer.placement(window).height
  )
end

return T
