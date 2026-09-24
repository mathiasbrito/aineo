local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

local AINEO_WINDOWS = { { 'claude' }, { 'report' }, { 'input' } }

T['a file opened in an aineo window'] = MiniTest.new_set()

T['a file opened in an aineo window']['opens in a new column between Claude and the right column'] =
  MiniTest.new_set({ parametrize = AINEO_WINDOWS })

T['a file opened in an aineo window']['opens in a new column between Claude and the right column']['from'] = function(
  window
)
  local buffers = layout.open_with_stand_ins(child)
  local claude_window = layout.window_showing(child, buffers.claude)
  local report_window = layout.window_showing(child, buffers.report)
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers[window])

  child.cmd('edit ' .. path)

  local file_window = layout.window_showing(child, child.lua_get('vim.fn.bufnr(...)', { path }))
  local claude = layout.box(child, claude_window)
  local file = layout.box(child, file_window)
  local report = layout.box(child, report_window)
  eq(layout.window_count(child), 4)
  eq({ file.row, file.col }, { 0, claude.width + 1 })
  eq(report.col, file.col + file.width + 1)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), file_window)
end

--- What a buffer holds, whose number is the argument: its lines, or for a
--- terminal, whose lines follow its window's size, the job it is attached to.
local LINES = 'vim.api.nvim_buf_get_lines(..., 0, -1, false)'
local TERMINAL_JOB = 'vim.bo[...].channel'

T['a file opened in an aineo window']['leaves that window showing its own buffer, unchanged'] =
  MiniTest.new_set({
    parametrize = { { 'claude', TERMINAL_JOB }, { 'report', LINES }, { 'input', LINES } },
  })

T['a file opened in an aineo window']['leaves that window showing its own buffer, unchanged']['from'] = function(
  window,
  content
)
  local buffers = layout.open_with_stand_ins(child)
  child.lua(
    'vim.api.nvim_buf_set_lines(..., 0, -1, false, { "typed into Input" })',
    { buffers.input }
  )
  local aineo_window = layout.window_showing(child, buffers[window])
  local content_before = child.lua_get(content, { buffers[window] })
  layout.enter_window_showing(child, buffers[window])

  child.cmd('edit ' .. layout.file('first.txt'))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { aineo_window }), buffers[window])
  eq(child.lua_get(content, { buffers[window] }), content_before)
end

T['a file opened in an aineo window']['leaves an empty Input its number, name and buftype'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local input_window = layout.window_showing(child, buffers.input)
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit ' .. path)

  eq(
    child.lua_get(
      [[(function(window)
        local buffer = vim.api.nvim_win_get_buf(window)
        return { buffer = buffer, name = vim.api.nvim_buf_get_name(buffer), buftype = vim.bo[buffer].buftype }
      end)(...)]],
      { input_window }
    ),
    { buffer = buffers.input, name = 'aineo://input', buftype = 'nofile' }
  )
  eq(layout.window_count(child), 4)
end

--- Commands that show a file in the current window, `{file}` standing for
--- its path: a buffer command, and a jump to a quickfix entry on line 3.
local SHOW_BUFFER = 'buffer {file}'
local JUMP_TO_ENTRY = [[call setqflist([{ 'filename': '{file}', 'lnum': 3 }]) | cfirst]]

T['a loaded file shown in Input'] = MiniTest.new_set({
  parametrize = { { SHOW_BUFFER }, { JUMP_TO_ENTRY } },
})

T['a loaded file shown in Input']['goes to the file column, and Input stays'] = function(command)
  local buffers = layout.open_with_stand_ins(child)
  local input_window = layout.window_showing(child, buffers.input)
  local path = layout.file('first.txt')
  local file_buffer = child.lua_get('vim.fn.bufadd(...)', { path })
  child.lua('vim.fn.bufload(...)', { file_buffer })
  layout.enter_window_showing(child, buffers.input)

  child.cmd((command:gsub('{file}', path)))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }), buffers.input)
  eq(layout.window_count(child), 4)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), file_buffer)
end

T['a file opened on line 3 in Input'] = MiniTest.new_set({
  parametrize = { { 'edit +3 {file}' }, { JUMP_TO_ENTRY } },
})

T['a file opened on line 3 in Input']['shows line 3 under the cursor in the file column'] = function(
  command
)
  local buffers = layout.open_with_stand_ins(child)
  local input_window = layout.window_showing(child, buffers.input)
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers.input)

  child.cmd((command:gsub('{file}', path)))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }), buffers.input)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 3, 0 })
end

T['the file column'] = MiniTest.new_set()

T['the file column']['makes three columns of a third each, the right one keeping its split'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit ' .. layout.file('first.txt'))

  local third = (layout.COLUMNS - 2) / 3
  local report = layout.box(child, layout.window_showing(child, buffers.report))
  local input = layout.box(child, layout.window_showing(child, buffers.input))
  layout.expect_near(layout.box(child, layout.window_showing(child, buffers.claude)).width, third)
  layout.expect_near(
    layout.box(child, child.lua_get('vim.api.nvim_get_current_win()')).width,
    third
  )
  layout.expect_near(report.width, third)
  layout.expect_near(report.height, layout.REPORT_HEIGHT * (report.height + input.height))
end

T['the file column']['takes a second file opened in an aineo window'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')
  layout.enter_window_showing(child, buffers.report)

  child.cmd('edit ' .. layout.file('second.txt'))

  eq(layout.window_count(child), 4)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), file_window)
  eq(child.lua_get('vim.fn.bufname()'), layout.file('second.txt'))
end

T['the file column']['keeps a file opened in it, without an error'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')

  child.cmd('edit ' .. layout.file('second.txt'))

  eq(layout.window_count(child), 4)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), file_window)
  eq(child.lua_get('vim.fn.bufname()'), layout.file('second.txt'))
  eq(child.lua_get('vim.v.errmsg'), '')
end

T['the file column']['closed with :q, gives back three windows with Claude at half the columns'] =
  MiniTest.new_set({ parametrize = { { 'set equalalways' }, { 'set noequalalways' } } })

T['the file column']['closed with :q, gives back three windows with Claude at half the columns']['after'] = function(
  option
)
  local buffers = layout.open_with_stand_ins(child)
  child.cmd(option)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))

  child.cmd('quit')

  local report = layout.box(child, layout.window_showing(child, buffers.report))
  local input = layout.box(child, layout.window_showing(child, buffers.input))
  eq(layout.window_count(child), 3)
  layout.expect_near(
    layout.box(child, layout.window_showing(child, buffers.claude)).width,
    layout.COLUMNS / 2
  )
  layout.expect_near(report.height, layout.REPORT_HEIGHT * (report.height + input.height))
end

--- Closes one of the file column's two windows after `:split` in it: the
--- window the split made, which has the cursor, or the one below it, which
--- the file opened in.
local CLOSE_THE_SPLIT = 'quit'
local CLOSE_THE_FIRST_WINDOW = 'wincmd j | quit'

T['the file column']['split in two, keeps its third when either window closes'] = MiniTest.new_set({
  parametrize = { { CLOSE_THE_SPLIT }, { CLOSE_THE_FIRST_WINDOW } },
})

T['the file column']['split in two, keeps its third when either window closes']['with'] = function(
  close
)
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  child.cmd('split')

  child.cmd(close)

  local third = (layout.COLUMNS - 2) / 3
  eq(layout.window_count(child), 4)
  layout.expect_near(layout.box(child, layout.window_showing(child, buffers.claude)).width, third)
  layout.expect_near(layout.box(child, layout.window_showing(child, buffers.report)).width, third)
end

T['the file column']['split in two, takes the next file in the window that remains'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  child.cmd('split')
  child.cmd(CLOSE_THE_FIRST_WINDOW)
  local remaining_window = child.lua_get('vim.api.nvim_get_current_win()')
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit ' .. layout.file('second.txt'))

  eq(layout.window_count(child), 4)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), remaining_window)
  eq(child.lua_get('vim.fn.bufname()'), layout.file('second.txt'))
end

T['the file column']['opens right of Claude with a window left of Claude'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local claude_window = layout.window_showing(child, buffers.claude)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('topleft vnew')
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit ' .. layout.file('first.txt'))

  local claude = layout.box(child, claude_window)
  local file = layout.box(child, child.lua_get('vim.api.nvim_get_current_win()'))
  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { claude_window }), buffers.claude)
  eq(file.col, claude.col + claude.width + 1)
end

T['the file column']['shows a file it already shows when Input shows it too'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local input_window = layout.window_showing(child, buffers.input)
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. path)
  layout.enter_window_showing(child, buffers.input)

  child.cmd('buffer ' .. path)

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }), buffers.input)
  eq(layout.window_count(child), 4)
end

--- Makers of buffers that hold no file, by kind: a help buffer, whose
--- window is closed again, a terminal, and a named scratch buffer.
local NOT_A_FILE = {
  help = function()
    return child.lua_get([[(function()
      vim.cmd('help')
      local buffer = vim.api.nvim_get_current_buf()
      vim.cmd('close')
      return buffer
    end)()]])
  end,
  terminal = function()
    return layout.terminal(child)
  end,
  scratch = function()
    return layout.named_scratch(child, 'a scratch buffer')
  end,
}

T['with the layout closed'] = MiniTest.new_set()

T['with the layout closed']['a file opened in what was Input stays there, without an error'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.close_windows(child, buffers, { 'claude', 'report' })
  local input_window = layout.window_showing(child, buffers.input)
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit ' .. path)

  eq(
    child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }),
    child.lua_get('vim.fn.bufnr(...)', { path })
  )
  eq(layout.window_count(child), 1)
  eq(child.lua_get('vim.v.errmsg'), '')
end

T['a file whose aineo window closes before the move'] = MiniTest.new_set()

T['a file whose aineo window closes before the move']['is left alone, without an error'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)

  child.lua('vim.cmd.edit(...); vim.cmd.close()', { layout.file('first.txt') })

  eq(layout.window_count(child), 2)
  eq(child.lua_get('vim.v.errmsg'), '')
end

T['a file that leaves its aineo window before the move'] = MiniTest.new_set()

T['a file that leaves its aineo window before the move']['stays out of the file column'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local report_window = layout.window_showing(child, buffers.report)
  layout.enter_window_showing(child, buffers.report)

  child.lua(
    'local path, report = ...; vim.cmd.edit(path); vim.cmd.buffer(report)',
    { layout.file('first.txt'), buffers.report }
  )

  eq(layout.window_count(child), 3)
  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { report_window }), buffers.report)
end

T['a buffer that is not a file, shown in Input'] = MiniTest.new_set({
  parametrize = { { 'help' }, { 'terminal' }, { 'scratch' } },
})

T['a buffer that is not a file, shown in Input']['stays there'] = function(kind)
  local buffers = layout.open_with_stand_ins(child)
  local buffer = NOT_A_FILE[kind]()
  local input_window = layout.window_showing(child, buffers.input)
  layout.enter_window_showing(child, buffers.input)

  child.cmd('buffer ' .. buffer)

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }), buffer)
  eq(layout.window_count(child), 3)
end

return T
