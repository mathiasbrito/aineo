--- Records the sizes the pty of Claude's terminal takes in a layout, for the
--- suites that pin what Claude Code is told about its width: the layout is
--- opened in a child around a terminal that appends `stty size` to a file at
--- its start and at every SIGWINCH, with a file as the file column and the
--- explorer column on the right.

local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local M = {}

--- How long a case waits for the terminal's job to see a size, in
--- milliseconds.
M.WAIT_LIMIT_MS = 3000

--- How long a case watches for a size the terminal's job sees after the one
--- its window gives it, in milliseconds: longer than the layout waits before
--- it gives the terminal a fresh size (`aineo.layout`) and what that takes.
M.QUIET_PERIOD_MS = 500

--- The shell program of a terminal that appends the size of its pty, `stty
--- size`, to the file named by its first argument, at its start and at every
--- SIGWINCH.
local RECORDER = [[
  record() { stty size >> "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 100 & wait $!; done
]]

--- The size Neovim gives a terminal shown in the windows of a child that show
--- it: the smallest height and the smallest width among them, `{ lines,
--- columns }`, the columns taken out of a window for its signs and numbers
--- left out.
M.EXPECTED_SIZE = [[(function()
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

--- The sizes the terminal recorded in `record`, in order, each `{ lines,
--- columns }`.
---
---@param record string
---@return integer[][]
function M.sizes(record)
  if vim.fn.filereadable(record) == 0 then
    return {}
  end
  return vim.tbl_map(function(line)
    local lines, columns = line:match('^(%d+) (%d+)$')
    return { tonumber(lines), tonumber(columns) }
  end, vim.fn.readfile(record))
end

--- Waits, at most `M.WAIT_LIMIT_MS`, until the last size the terminal
--- recorded is the one its windows give it.
---
---@param child table
---@param record string
function M.wait_for_window_size(child, record)
  vim.wait(M.WAIT_LIMIT_MS, function()
    return vim.deep_equal(vim.list_slice(M.sizes(record), -1)[1], child.lua_get(M.EXPECTED_SIZE))
  end, 20)
end

--- Opens the layout in a fresh `child` around a terminal running `RECORDER`,
--- waits until the terminal has its window's size, and returns the file it
--- records its sizes in.
---
---@param child table
---@param name string the case's own name for its files
---@return string record
function M.open_around_recorder(child, name)
  local record = vim.fs.joinpath(fixture.directory('pty-recorder-' .. name), 'sizes')
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
  child.cmd('edit ' .. layout.file('size.txt'))
  local arrangement = layout.arrangement(buffers)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = 20
  layout.open(child, arrangement)
  M.wait_for_window_size(child, record)
  vim.wait(M.QUIET_PERIOD_MS, function()
    return false
  end, 20)
  return record
end

--- Runs `change`, a Lua chunk, in the child and returns the sizes the
--- terminal recorded from then on, once none came for `M.QUIET_PERIOD_MS`,
--- and the size its windows give it.
---
---@param child table
---@param record string
---@param change string
---@return table sizes `seen`, the sizes recorded after the change, and `final`
function M.sizes_seen_during(child, record, change)
  local before = #M.sizes(record)
  child.lua(change)
  M.wait_for_window_size(child, record)
  vim.wait(M.QUIET_PERIOD_MS, function()
    return false
  end, 20)
  return {
    seen = vim.list_slice(M.sizes(record), before + 1),
    final = child.lua_get(M.EXPECTED_SIZE),
  }
end

return M
