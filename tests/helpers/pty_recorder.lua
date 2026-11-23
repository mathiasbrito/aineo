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

--- The shell program of a terminal that records what it reads as well: it
--- reads its input a byte at a time, without echo, and appends `key <hex>` to
--- the same file as the sizes, so that the order of a size and a key can be
--- read from it.
M.KEY_RECORDER = [[
  record() { stty size >> "$1"; }
  stty -icanon -echo min 1 time 0
  trap 'record "$1"' WINCH
  record "$1"
  exec 3<&0
  (
    while :; do
      byte=$(dd bs=1 count=1 <&3 2>/dev/null | od -An -tx1)
      [ -n "$byte" ] || break
      echo "key $byte" >> "$1"
    done
  ) &
  while :; do sleep 100 & wait $!; done
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
  local sizes = {}
  for _, event in ipairs(M.events(record)) do
    if event.size then
      table.insert(sizes, event.size)
    end
  end
  return sizes
end

--- What the terminal recorded in `record`, in order: each a table with `size`,
--- `{ lines, columns }`, or with `key`, the hexadecimal of a byte it read.
---
---@param record string
---@return table[]
function M.events(record)
  if vim.fn.filereadable(record) == 0 then
    return {}
  end
  local events = {}
  for _, line in ipairs(vim.fn.readfile(record)) do
    local lines, columns = line:match('^(%d+) (%d+)$')
    local key = line:match('^key%s+(%x+)%s*$')
    if lines then
      table.insert(events, { size = { tonumber(lines), tonumber(columns) } })
    elseif key then
      table.insert(events, { key = key })
    end
  end
  return events
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

--- Opens the layout in a fresh `child` around a terminal running `program`,
--- waits until the terminal has its window's size, and returns the file it
--- records in. `settings` are fields of the arrangement the layout is
--- opened with, besides its buffers. With `claude_is_ready`, the layout is
--- handed a predicate that reads the child's `vim.g.test_claude_is_ready`,
--- true from the start.
---
---@param child table
---@param name string the case's own name for its files
---@param program string
---@param settings? table
---@param claude_is_ready? boolean
---@return string record
local function open_around(child, name, program, settings, claude_is_ready)
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
    { program, record }
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
  for field, value in pairs(settings or {}) do
    arrangement[field] = value
  end
  if claude_is_ready then
    child.lua(
      [[vim.g.test_claude_is_ready = true
        local arrangement = ...
        arrangement.claude_is_ready = function()
          return vim.g.test_claude_is_ready
        end
        require('aineo.layout').open(arrangement)]],
      { arrangement }
    )
  else
    layout.open(child, arrangement)
  end
  M.wait_for_window_size(child, record)
  vim.wait(M.QUIET_PERIOD_MS, function()
    return false
  end, 20)
  return record
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
  return open_around(child, name, busy and BUSY_RECORDER or RECORDER)
end

--- The same around a terminal that records the bytes it reads as well
--- (`M.events()`), the layout opened with the arrangement's `settings` and a
--- predicate for Claude Code's readiness that the child's
--- `vim.g.test_claude_is_ready` answers.
---
---@param child table
---@param name string the case's own name for its files
---@param settings? table
---@param hands_no_predicate? boolean open the layout with no predicate for the readiness
---@return string record
function M.open_around_key_recorder(child, name, settings, hands_no_predicate)
  return open_around(child, name, M.KEY_RECORDER, settings, not hands_no_predicate)
end

--- Runs `change`, a Lua chunk, in the child and returns what the terminal
--- recorded from then on (`M.events()`), once no size came for
--- `M.QUIET_PERIOD_MS`, and the size its windows give it.
---
---@param child table
---@param record string
---@param change string
---@return table recorded `events` and `final`
function M.events_during(child, record, change)
  local before = #M.events(record)
  child.lua(change)
  M.wait_for_window_size(child, record)
  vim.wait(M.QUIET_PERIOD_MS, function()
    return false
  end, 20)
  return {
    events = vim.list_slice(M.events(record), before + 1),
    final = child.lua_get(M.EXPECTED_SIZE),
  }
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
