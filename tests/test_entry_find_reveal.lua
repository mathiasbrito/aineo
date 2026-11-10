local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`).
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
    end,
    post_once = stop_the_child,
  },
})

--- The files of the repository the cases search.
local FILES = {
  ['top.txt'] = { 'at the top' },
  ['sub/note.txt'] = { 'in a directory' },
  ['sub/other.txt'] = { 'another' },
  ['docs/guide.md'] = { 'guide' },
}

--- Makes the repository `find-reveal-<name>` of `FILES`, starts the child in
--- it with the fake `claude`, a fake picker that opens `picked` (a path under
--- the repository) and `settings` as `vim.g.aineo`, and opens the layout;
--- waits until Claude Code is ready, and returns the repository's top.
---
---@param name string
---@param picked string the path of the file the fake picker opens, from the repository's top
---@param settings? table
---@return string top
local function open_in_repository(name, picked, settings)
  local top = git_repo.create('find-reveal-' .. name, FILES)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('find-reveal-' .. name, 'ready'), settings)
  find_pickers.install(child, { 'snacks' }, vim.fs.joinpath(top, picked))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return top
end

--- Opens the layout with the explorer column on the left (`open_in_repository()`).
---
---@param name string
---@param picked string
---@return string top
local function open_with_column(name, picked)
  return open_in_repository(name, picked, { layout = { explorer_column = 'left' } })
end

--- The text of the line the cursor of the explorer's window is on in the
--- child, nil while no window shows the explorer.
local EXPLORER_CURSOR_LINE = [[(function()
  local buffer = vim.fn.bufnr('aineo://explorer')
  local window = buffer ~= -1 and vim.fn.win_findbuf(buffer)[1]
  if not window then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(window)[1]
  return vim.api.nvim_buf_get_lines(buffer, line - 1, line, false)[1]
end)()]]

--- Waits, at most `PATIENCE_MS`, until the explorer's lines are more than its
--- header and a first row (the tree was read).
local function wait_for_tree()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get([[(function()
      local buffer = vim.fn.bufnr('aineo://explorer')
      return buffer ~= -1 and vim.api.nvim_buf_line_count(buffer) > 2
    end)()]])
  end, 20)
end

--- Waits, at most `PATIENCE_MS`, until the child's current window shows a
--- buffer named `name`, and returns what it shows then.
---
---@param name string
---@return string
local function wait_for_current_window(name)
  vim.wait(PATIENCE_MS, function()
    return entry.current_window(child) == name
  end, 20)
  return entry.current_window(child)
end

--- Puts the cursor of the explorer's window in the child on its first line.
local function put_explorer_cursor_on_the_first_line()
  child.lua([[(function()
    local window = vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1]
    vim.api.nvim_win_set_cursor(window, { 1, 0 })
  end)()]])
end

--- Whether the text of the line under the explorer's cursor ends with `name`.
---
---@param name string
---@return boolean
local function explorer_cursor_is_on(name)
  local text = child.lua_get(EXPLORER_CURSOR_LINE)
  return type(text) == 'string' and vim.endswith(text, name)
end

T['a file opened with \\f'] = MiniTest.new_set()

T['a file opened with \\f']['is revealed in the explorer column, the cursor staying in the file'] = function()
  local top = open_with_column('column', 'sub/note.txt')
  wait_for_tree()
  put_explorer_cursor_on_the_first_line()

  entry.press(child, '\\f')

  local note = vim.fs.joinpath(top, 'sub', 'note.txt')
  eq(wait_for_current_window(note), note)
  vim.wait(PATIENCE_MS, function()
    return explorer_cursor_is_on('note.txt')
  end, 20)
  eq(explorer_cursor_is_on('note.txt'), true)
  eq(entry.current_window(child), note)
end

T['a file opened with \\f']['is revealed in the explorer pane too'] = function()
  local top = open_in_repository('pane', 'sub/note.txt')
  entry.press(child, '\\e')
  wait_for_tree()
  put_explorer_cursor_on_the_first_line()

  entry.press(child, '\\f')

  local note = vim.fs.joinpath(top, 'sub', 'note.txt')
  eq(wait_for_current_window(note), note)
  vim.wait(PATIENCE_MS, function()
    return explorer_cursor_is_on('note.txt')
  end, 20)
  eq(explorer_cursor_is_on('note.txt'), true)
end

T['a file opened with \\f']['unfolds its folders for the next time the explorer shows'] = function()
  local top = open_in_repository('hidden', 'sub/note.txt')
  entry.press(child, '\\f')
  local note = vim.fs.joinpath(top, 'sub', 'note.txt')
  wait_for_current_window(note)
  local windows = entry.windows(child)

  entry.press(child, '\\e')
  wait_for_tree()

  eq(windows, { 'terminal', note, 'aineo://report', 'aineo://input' })
  eq(
    child.lua_get([[vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://explorer'), 0, -1, false)]])[3],
    '▾   sub/'
  )
end

T['a file entered another way'] = MiniTest.new_set()

T['a file entered another way']['leaves every explorer cursor where it was'] = function()
  local top = open_with_column('other-way', 'sub/note.txt')
  wait_for_tree()
  entry.press(child, '\\f')
  wait_for_current_window(vim.fs.joinpath(top, 'sub', 'note.txt'))
  vim.wait(PATIENCE_MS, function()
    return explorer_cursor_is_on('note.txt')
  end, 20)
  put_explorer_cursor_on_the_first_line()

  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'sub', 'other.txt')))

  vim.wait(300)
  eq(explorer_cursor_is_on('note.txt') or explorer_cursor_is_on('other.txt'), false)
end

--- Makes the fake snacks picker of the child open a floating window and enter
--- it, as a picker does, and stay open: `_G.picker_float` is its window.
local function install_a_picker_that_stays_open()
  child.lua([[
    package.preload['snacks'] = function()
      return {
        picker = {
          files = function()
            local buffer = vim.api.nvim_create_buf(false, true)
            _G.picker_float = vim.api.nvim_open_win(buffer, true, {
              relative = 'editor',
              row = 1,
              col = 1,
              width = 20,
              height = 3,
            })
          end,
        },
      }
    end
  ]])
end

--- Waits, at most `PATIENCE_MS`, until the child's current window is the
--- picker's float.
local function wait_for_the_picker()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(
      '_G.picker_float ~= nil and vim.api.nvim_get_current_win() == _G.picker_float'
    )
  end, 20)
end

T['a picker that stays open'] = MiniTest.new_set()

T['a search'] = MiniTest.new_set()

T['an asynchronous picker'] = MiniTest.new_set()

T['a picker that raises'] = MiniTest.new_set()

T['a picker that opens nothing'] = MiniTest.new_set()

T['a picker that stays open']['reveals the file it opens once it closes'] = function()
  local top = open_with_column('async', 'sub/note.txt')
  wait_for_tree()
  install_a_picker_that_stays_open()
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()
  local note = vim.fs.joinpath(top, 'sub', 'note.txt')

  child.lua(
    [[
      local path = ...
      vim.api.nvim_win_close(_G.picker_float, true)
      vim.schedule(function()
        vim.cmd.edit(vim.fn.fnameescape(path))
      end)
    ]],
    { note }
  )

  eq(wait_for_current_window(note), note)
  vim.wait(PATIENCE_MS, function()
    return explorer_cursor_is_on('note.txt')
  end, 20)
  eq(explorer_cursor_is_on('note.txt'), true)
end

T['a picker that stays open']['reveals nothing once it was cancelled, whatever file is entered next'] = function()
  local top = open_with_column('cancel', 'sub/note.txt')
  wait_for_tree()
  install_a_picker_that_stays_open()
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()

  child.lua('vim.api.nvim_win_close(_G.picker_float, true)')
  vim.wait(300)
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'sub', 'other.txt')))

  vim.wait(300)
  eq(explorer_cursor_is_on('other.txt'), false)
end

T['a picker that stays open']['reveals nothing once it was cancelled from a file window'] = function()
  local top = open_with_column('cancel-file', 'sub/note.txt')
  wait_for_tree()
  local top_file = vim.fs.joinpath(top, 'top.txt')
  child.cmd('edit ' .. vim.fn.fnameescape(top_file))
  wait_for_current_window(top_file)
  install_a_picker_that_stays_open()
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()

  child.lua('vim.api.nvim_win_close(_G.picker_float, true)')

  vim.wait(300)
  eq(explorer_cursor_is_on('top.txt'), false)
end

T['a picker that stays open']['reveals nothing for a file its preview shows in a float'] = function()
  local top = open_with_column('preview', 'sub/note.txt')
  wait_for_tree()
  install_a_picker_that_stays_open()
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()
  local previewed = vim.fs.joinpath(top, 'docs', 'guide.md')

  child.lua(
    [[
      local path = ...
      vim.cmd.badd(vim.fn.fnameescape(path))
      local buffer = vim.fn.bufnr(path)
      vim.api.nvim_open_win(buffer, true, {
        relative = 'editor',
        row = 5,
        col = 5,
        width = 20,
        height = 3,
      })
    ]],
    { previewed }
  )

  vim.wait(300)
  eq(explorer_cursor_is_on('guide.md'), false)
end

T['a picker that opens nothing']['reveals nothing for the file entered next'] = function()
  local top = open_with_column('nothing', 'sub/note.txt')
  wait_for_tree()
  find_pickers.install(child, { 'snacks' })
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  vim.wait(PATIENCE_MS, function()
    return #find_pickers.calls(child) > 0
  end, 20)

  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'sub', 'other.txt')))

  vim.wait(300)
  eq(explorer_cursor_is_on('other.txt'), false)
end

T['a picker that stays open']['reveals nothing for a file entered in another tab page'] = function()
  local top = open_with_column('other-page', 'sub/note.txt')
  wait_for_tree()
  install_a_picker_that_stays_open()
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()

  child.cmd('tabnew')
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'sub', 'other.txt')))

  vim.wait(300)
  eq(explorer_cursor_is_on('other.txt'), false)
end

T['a picker that stays open']['reveals the file it opens after an empty buffer was entered'] = function()
  local top = open_with_column('empty-first', 'sub/note.txt')
  wait_for_tree()
  install_a_picker_that_stays_open()
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()
  local note = vim.fs.joinpath(top, 'sub', 'note.txt')

  child.lua(
    [[
      local path = ...
      vim.api.nvim_win_close(_G.picker_float, true)
      vim.cmd.enew()
      vim.cmd.edit(vim.fn.fnameescape(path))
    ]],
    { note }
  )

  vim.wait(PATIENCE_MS, function()
    return explorer_cursor_is_on('note.txt')
  end, 20)
  eq(explorer_cursor_is_on('note.txt'), true)
end

T['a picker that raises']['has its error told to the user once'] = function()
  open_with_column('raises', 'sub/note.txt')
  wait_for_tree()
  child.lua([[
    package.preload['snacks'] = function()
      return {
        picker = {
          files = function()
            error('the picker broke')
          end,
        },
      }
    end
  ]])

  entry.press(child, '\\f')
  vim.wait(PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)

  local messages = entry.messages(child)
  eq(#messages, 1)
  eq(vim.endswith(messages[1].message, 'the picker broke'), true)
  eq(messages[1].level, vim.log.levels.ERROR)
end

--- Makes the fake snacks picker of the child work as snacks.nvim's does: it
--- opens its floating window on a later tick than the call that asked for it
--- (`_G.picker_float`), and `_G.close_picker(path)` closes that window and
--- puts the cursor in the window showing `top`, where a file column's file
--- is, as the picker's own jump does, and opens `path` there when given.
---
---@param top string the file the file column shows, a path
local function install_an_asynchronous_picker(top)
  child.lua(
    [[
      local top = ...
      package.preload['snacks'] = function()
        return {
          picker = {
            files = function()
              vim.schedule(function()
                local buffer = vim.api.nvim_create_buf(false, true)
                _G.picker_float = vim.api.nvim_open_win(buffer, true, {
                  relative = 'editor',
                  row = 1,
                  col = 1,
                  width = 20,
                  height = 3,
                })
              end)
            end,
          },
        }
      end
      _G.close_picker = function(path)
        vim.api.nvim_win_close(_G.picker_float, true)
        vim.api.nvim_set_current_win(vim.fn.win_findbuf(vim.fn.bufnr(top))[1])
        if path then
          vim.cmd.edit(vim.fn.fnameescape(path))
        end
      end
    ]],
    { top }
  )
end

--- Opens the layout as `open_with_column()` does, shows `top.txt` in the file
--- column, installs the asynchronous picker (`install_an_asynchronous_picker()`),
--- starts the search from Input and waits for the picker's window; returns the
--- repository's top.
---
---@param name string
---@return string top
local function search_with_an_asynchronous_picker(name)
  local top = open_with_column(name, 'sub/note.txt')
  wait_for_tree()
  local top_file = vim.fs.joinpath(top, 'top.txt')
  child.cmd('edit ' .. vim.fn.fnameescape(top_file))
  wait_for_current_window(top_file)
  install_an_asynchronous_picker(top_file)
  entry.press(child, '\\i')
  put_explorer_cursor_on_the_first_line()
  entry.press(child, '\\f')
  wait_for_the_picker()
  return top
end

T['an asynchronous picker']['reveals the file it opens in the window it returns to'] = function()
  local top = search_with_an_asynchronous_picker('async-confirm')

  child.lua('_G.close_picker(...)', { vim.fs.joinpath(top, 'sub', 'note.txt') })

  vim.wait(PATIENCE_MS, function()
    return explorer_cursor_is_on('note.txt')
  end, 20)
  eq(explorer_cursor_is_on('note.txt'), true)
end

T['an asynchronous picker']['reveals nothing when cancelled, though the cursor returns to a file'] = function()
  local top = search_with_an_asynchronous_picker('async-cancel')

  child.lua('_G.close_picker()')
  vim.wait(300)
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'sub', 'other.txt')))

  vim.wait(300)
  eq({ explorer_cursor_is_on('top.txt'), explorer_cursor_is_on('other.txt') }, { false, false })
end

T['a search']['is not ended by the cancel of the search before it'] = function()
  local top = open_with_column('stale', 'sub/note.txt')
  wait_for_tree()
  put_explorer_cursor_on_the_first_line()
  local note = vim.fs.joinpath(top, 'sub', 'note.txt')

  child.lua(
    [[
      local path = ...
      local watching = require('aineo.entry.find_reveal').watching
      local reveal = function(file)
        _G.revealed = file
      end
      local function open_float()
        local buffer = vim.api.nvim_create_buf(false, true)
        return vim.api.nvim_open_win(buffer, true, {
          relative = 'editor', row = 1, col = 1, width = 20, height = 3,
        })
      end
      local first
      watching(reveal, function()
        first = open_float()
      end)
      vim.api.nvim_win_close(first, true)
      local second
      watching(reveal, function()
        second = open_float()
      end)
      _G.second_float = second
    ]],
    { note }
  )
  vim.wait(300)
  child.lua(
    [[
      local path = ...
      vim.api.nvim_win_close(_G.second_float, true)
      vim.cmd.edit(vim.fn.fnameescape(path))
    ]],
    { note }
  )

  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.revealed ~= nil')
  end, 20)
  eq(child.lua_get('_G.revealed'), note)
end

return T
