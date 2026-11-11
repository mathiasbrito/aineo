local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a case waits for the terminal's job to see a size, in milliseconds.
local WAIT_LIMIT_MS = 3000

--- The shell program of a terminal that records the size of its pty, `stty
--- size`, in the file named by its first argument, at its start and at every
--- SIGWINCH.
local RECORDER = [[
  record() { stty size > "$1.tmp" && mv "$1.tmp" "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 0.05; done
]]

--- Opens the layout in a fresh child around a terminal running `RECORDER`,
--- with a file shown as the file column when `with_file_column` and the
--- explorer column on the left when `with_explorer_column`; returns the file
--- the terminal records its size in and the layout's arrangement.
---
---@param name string
---@param with_file_column boolean
---@param with_explorer_column boolean
---@return string record
---@return table arrangement
local function open_around_recorder(name, with_file_column, with_explorer_column)
  local record = vim.fs.joinpath(fixture.directory('layout-size-' .. name), 'size')
  layout.start(child)
  local terminal = child.lua_get(
    [[(function(program, record)
      local buffer = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_call(buffer, function()
        vim.fn.jobstart({ 'sh', '-c', program, 'recorder', record }, { term = true })
      end)
      return buffer
    end)(...)]],
    { RECORDER, record }
  )
  local buffers = {
    claude = terminal,
    report = layout.named_scratch(child, 'aineo://report'),
    explorer = layout.named_scratch(child, 'aineo://explorer'),
  }
  if with_file_column then
    child.cmd('edit ' .. layout.file('size.txt'))
  end
  local arrangement = layout.arrangement(buffers)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = with_explorer_column and 'left' or false
  arrangement.explorer_width = 20
  layout.open(child, arrangement)
  return record, arrangement
end

--- The size the terminal last recorded, `{ lines, columns }`, or nil before
--- it recorded one.
---
---@param record string
---@return integer[]|nil
local function recorded_size(record)
  if vim.fn.filereadable(record) == 0 then
    return nil
  end
  local line = vim.fn.readfile(record)[1] or ''
  local lines, columns = line:match('^(%d+) (%d+)$')
  return lines and { tonumber(lines), tonumber(columns) } or nil
end

--- The size Neovim gives a terminal shown in the windows of `child` that show
--- it: the smallest height and the smallest width among them, `{ lines,
--- columns }`, the columns taken out of a window for its signs and numbers
--- left out.
local EXPECTED_SIZE = [[(function()
  local terminal
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      terminal = buffer
    end
  end
  local lines, columns = math.huge, math.huge
  for _, window in ipairs(vim.fn.win_findbuf(terminal)) do
    local info = vim.fn.getwininfo(window)[1]
    lines = math.min(lines, info.height)
    columns = math.min(columns, info.width - info.textoff)
  end
  return { lines, columns }
end)()]]

--- Waits, at most `WAIT_LIMIT_MS`, until the terminal's last recorded size is
--- the one its windows give it, and returns both as they are then.
---
---@param record string
---@return table sizes `recorded` and `expected`
local function settled_sizes(record)
  vim.wait(WAIT_LIMIT_MS, function()
    return vim.deep_equal(recorded_size(record), child.lua_get(EXPECTED_SIZE))
  end, 20)
  return { recorded = recorded_size(record), expected = child.lua_get(EXPECTED_SIZE) }
end

--- Moves Claude's column to `claude_side` in the child's layout.
---
---@param claude_side string
local function set_claude_side(claude_side)
  child.lua([[require('aineo.layout').set_claude_side(...)]], { claude_side })
end

T['the terminal of Claude Code after a swap'] = MiniTest.new_set({
  parametrize = {
    { 'no file column', false, false },
    { 'a file column', true, false },
    { 'a file column and the explorer column', true, true },
  },
})

T['the terminal of Claude Code after a swap']['has the size of its window on the other side'] = function(
  case,
  with_file_column,
  with_explorer_column
)
  local record =
    open_around_recorder('swap-' .. case:gsub('%W', '-'), with_file_column, with_explorer_column)
  settled_sizes(record)

  set_claude_side('right')

  local sizes = settled_sizes(record)
  eq(sizes.recorded, sizes.expected)
end

T['the terminal of Claude Code after a swap']['has the size of its window after the swap back'] = function(
  case,
  with_file_column,
  with_explorer_column
)
  local record =
    open_around_recorder('back-' .. case:gsub('%W', '-'), with_file_column, with_explorer_column)
  settled_sizes(record)

  set_claude_side('right')
  set_claude_side('left')

  local sizes = settled_sizes(record)
  eq(sizes.recorded, sizes.expected)
end

return T
