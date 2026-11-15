local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The `claude` the child runs: a shell that appends the size of its pty to
--- the file named by its first argument at its start and at every SIGWINCH.
local RECORDING_CLAUDE = [[
  record() { stty size >> "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 100 & wait $!; done
]]

--- How long a case waits for the explorer's tree, in milliseconds.
local PATIENCE_MS = 10000

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      for name, value in pairs(git_repo.ENVIRONMENT) do
        vim.env[name] = value
      end
    end,
    pre_case = function()
      pcall(child.stop)
      entry.restart(child)
    end,
    post_once = function()
      pcall(child.stop)
    end,
  },
})

--- Waits for `pty.QUIET_PERIOD_MS`.
local function wait_quietly()
  vim.wait(pty.QUIET_PERIOD_MS, function()
    return false
  end, 20)
end

--- Puts the cursor of the child's current window on the line that ends with
--- `text`.
---
---@param text string
local function put_cursor_on(text)
  child.lua(
    [[
      local text = ...
      for line, shown in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if vim.endswith(shown, text) then
          vim.api.nvim_win_set_cursor(0, { line, 0 })
          return
        end
      end
      error('no line ends with ' .. text)
    ]],
    { text }
  )
end

--- Opens aineo's layout in the child around a terminal that records its
--- pty's sizes, with the explorer column on the right and its cursor in it
--- on `README.md`, once the terminal has the size of its window and the
--- explorer its tree; returns the file the terminal records its sizes in.
---
---@param name string the case's own name for its files
---@return string record
local function open_layout_with_explorer(name)
  local top = git_repo.create('claude-pty-focus-' .. name, { ['README.md'] = { 'readme' } })
  local record =
    vim.fs.joinpath(fixture.directory('claude-pty-focus-' .. name .. '-sizes'), 'sizes')
  child.lua(
    'vim.env.XDG_STATE_HOME = ...',
    { fixture.directory('claude-pty-focus-' .. name .. '-state') }
  )
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  child.lua(
    [[vim.g.aineo = {
      claude = { cmd = { 'sh', '-c', ..., 'recording-claude', (select(2, ...)) } },
      layout = { explorer_column = 'right' },
    }]],
    { RECORDING_CLAUDE, record }
  )
  child.cmd('Aineo open')
  pty.wait_for_window_size(child, record)
  entry.press(child, '\\e')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get([[(function()
      local buffer = vim.fn.bufnr('aineo://explorer')
      return buffer ~= -1 and vim.api.nvim_buf_line_count(buffer) > 1
    end)()]])
  end, 20)
  put_cursor_on('README.md')
  wait_quietly()
  return record
end

--- Whether the terminal's job was given a fresh resize at the size its
--- window has now: the last size it saw is that size, and the one before it
--- is another.
---
---@param sizes table `seen` and `final`
---@return boolean
local function was_given_a_fresh_resize(sizes)
  local seen = sizes.seen
  return #seen >= 2
    and vim.deep_equal(seen[#seen], sizes.final)
    and not vim.deep_equal(seen[#seen - 1], sizes.final)
end

--- The Lua that types `keys` in the child as a user does.
---
---@param keys string
---@return string
local function typing(keys)
  return ([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(%q, true, false, true), 'mx', false)]]):format(
    keys
  )
end

--- The Lua that moves the cursor to the window that shows `README.md`.
local ENTER_THE_FILE_WINDOW = [[for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window)):find('README.md', 1, true) then
    vim.api.nvim_set_current_win(window)
  end
end]]

T['the pty of Claude Code'] = MiniTest.new_set()

T['the pty of Claude Code']['is given a fresh resize at its window’s size when the file focus ends'] =
  MiniTest.new_set({
    parametrize = {
      { 'q in the explorer', typing('q') },
      { '<C-l> in the explorer', typing('<C-l>') },
      { ':q in the file window', ENTER_THE_FILE_WINDOW .. "\nvim.cmd('quit')" },
    },
  })

T['the pty of Claude Code']['is given a fresh resize at its window’s size when the file focus ends']['by each way'] = function(
  case,
  ending
)
  local record = open_layout_with_explorer('ends-' .. case:gsub('%W', '-'))
  child.lua(typing('<C-l>'))
  pty.wait_for_window_size(child, record)
  wait_quietly()

  local sizes = pty.sizes_seen_during(child, record, ending)

  eq(was_given_a_fresh_resize(sizes), true)
  eq(#sizes.seen <= 3, true)
end

T['the pty of Claude Code']['is given a fresh resize at its window’s size when q closes the file column without the focus'] = function()
  local record = open_layout_with_explorer('q-without-focus')
  child.lua(typing('l'))
  pty.wait_for_window_size(child, record)
  wait_quietly()

  local sizes = pty.sizes_seen_during(child, record, typing('q'))

  eq(was_given_a_fresh_resize(sizes), true)
  eq(#sizes.seen <= 4, true)
end

T['the pty of Claude Code']['is given no resize when the layout opens again with no file focus on'] = function()
  local record = open_layout_with_explorer('open-again')

  local sizes = pty.sizes_seen_during(child, record, [[vim.cmd('Aineo open')]])

  eq(sizes.seen, {})
end

T['the pty of Claude Code']['is given no resize when the file focus starts'] = function()
  local record = open_layout_with_explorer('focus-starts')

  local sizes = pty.sizes_seen_during(child, record, typing('<C-l>'))

  eq(sizes.seen, {})
end

return T
