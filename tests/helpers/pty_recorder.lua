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
M.QUIET_PERIOD_MS = 800

--- The shell program of a terminal that appends the size of its pty, `stty
--- size`, to the file named by its first argument, at its start and at every
--- SIGWINCH.
local RECORDER = [[
  record() { stty size >> "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 100 & wait $!; done
]]

--- The same for a process that is busy: it serves a signal only between its
--- commands, 0.2 s apart, so that two sizes told within that time reach it as
--- the last of them.
local BUSY_RECORDER = [[
  record() { stty size >> "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 0.2; done
]]

--- The size Neovim gives a terminal shown in the windows of a child that show
--- it, in every tab page: the largest height and the largest width among
--- them, `{ lines, columns }`, the columns taken out of a window for its signs
--- and numbers left out.
M.EXPECTED_SIZE = [[(function()
  local terminal
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      terminal = buffer
    end
  end
  local lines, columns = 0, 0
  for _, window in ipairs(vim.fn.win_findbuf(terminal)) do
    local info = vim.fn.getwininfo(window)[1]
    lines = math.max(lines, info.height)
    columns = math.max(columns, info.width - info.textoff)
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

--- The last size the terminal recorded in `record`, or nil before it recorded
--- one.
---
---@param record string
---@return integer[]|nil
function M.last_size(record)
  local sizes = M.sizes(record)
  return sizes[#sizes]
end

--- Waits, at most `M.WAIT_LIMIT_MS`, until the last size the terminal
--- recorded is the one its windows give it.
---
---@param child table
---@param record string
function M.wait_for_window_size(child, record)
  vim.wait(M.WAIT_LIMIT_MS, function()
    return vim.deep_equal(M.last_size(record), child.lua_get(M.EXPECTED_SIZE))
  end, 20)
end

--- Opens the layout in a fresh `child` around a terminal running `RECORDER`,
--- or `BUSY_RECORDER` when `busy`, waits until the terminal has its window's
--- size, and returns the file it records its sizes in.
---
---@param child table
---@param name string the case's own name for its files
---@param busy? boolean
---@return string record
function M.open_around_recorder(child, name, busy)
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
    { busy and BUSY_RECORDER or RECORDER, record }
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
