local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
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

--- The Lua that keeps, in the child, every target `vim.ui.open()` is given,
--- in `_G.opened_externally`, and opens none of them.
local KEEP_EXTERNAL_OPENS = [[
  _G.opened_externally = {}
  vim.ui.open = function(target)
    table.insert(_G.opened_externally, target)
    return { wait = function() end }
  end
]]

--- The Lua that makes `vim.ui.open()` in the child fail as it does when the
--- system has no application for a target.
local FAIL_EXTERNAL_OPENS = [[
  vim.ui.open = function()
    return nil, 'no opener'
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

--- Takes on the git isolation of the git home's suites in this file's own
--- Neovim, which every child it starts inherits.
local function isolate_git()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = isolate_git,
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- The files of the repository each case explores.
local FILES = {
  ['README.md'] = { 'readme' },
  ['src/main.lua'] = { 'main' },
}

--- Makes the repository `system-<name>`, opens the layout in it around the
--- fake `claude` once Claude Code is ready, with `vim.ui.open()` replaced by
--- `replacement` (Lua), and shows the explorer once its tree is drawn;
--- returns the repository's top.
---
---@param name string
---@param replacement string
---@return string top
local function explore_with_opener(name, replacement)
  local top = git_repo.create('system-' .. name, FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('system-' .. name, 'ready'))
  child.lua(replacement)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('vim.api.nvim_buf_get_name(0)') == 'aineo://explorer'
      and child.lua_get('vim.api.nvim_buf_line_count(0)') > 1
  end, 20)
  return top
end

--- Puts the cursor of the child's current window on the line of the explorer
--- that holds `text`.
---
---@param text string
local function put_cursor_on(text)
  child.lua(
    [[
      local text = ...
      for number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if line:find(text, 1, true) then
          vim.api.nvim_win_set_cursor(0, { number, 0 })
          return
        end
      end
    ]],
    { text }
  )
end

--- What the child's `vim.ui.open()` was given (`KEEP_EXTERNAL_OPENS`).
---
---@return string[]
local function opened_externally()
  return child.lua_get('_G.opened_externally')
end

T['<M-l> in the explorer'] = MiniTest.new_set()

T['<M-l> in the explorer']['hands a file to the system, opening no file column and keeping the cursor in the tree'] = function()
  local top = explore_with_opener('file', KEEP_EXTERNAL_OPENS)
  put_cursor_on('README.md')

  entry.press(child, '<M-l>')

  eq(opened_externally(), { top .. '/README.md' })
  eq(entry.windows(child), { 'terminal', 'aineo://explorer' })
  eq(entry.current_window(child), 'aineo://explorer')
end

T['<M-l> in the explorer']['hands a folder to the system'] = function()
  local top = explore_with_opener('folder', KEEP_EXTERNAL_OPENS)
  put_cursor_on('src/')

  entry.press(child, '<M-l>')

  eq(opened_externally(), { top .. '/src' })
end

T['<M-l> in the explorer']['tells the user, once, when the system cannot open the entry'] = function()
  explore_with_opener('failing', FAIL_EXTERNAL_OPENS)
  put_cursor_on('README.md')

  entry.press(child, '<M-l>')

  local messages = entry.messages(child)
  eq(#messages, 1)
  eq(messages[1].message:find('README.md could not be opened: no opener', 1, true) ~= nil, true)
end

return T
