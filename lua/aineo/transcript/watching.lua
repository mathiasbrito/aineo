--- The watching of a file or a folder, for `aineo.transcript`: tells that the
--- path changed, by a file-system event where the system gives one and by a
--- look every 500 ms where it does not. It reads nothing from the path but its
--- stat, and holds no handle once stopped.

local M = {}

--- How often the path is looked at while no file-system event watches it: when
--- the path does not exist yet, or the system cannot make an event for it.
local POLL_MS = 500

--- How long after a file-system event watch starts that the path is looked at
--- once more. A watch takes effect when the event loop next runs, not when it
--- is started (measured on macOS, 2026-10-22: a write made before the loop ran
--- raised no event, one made after it did), so a change made between the start
--- and the loop's turn is found by this one look instead of waiting for the
--- next event.
local SETTLE_MS = 500

---@class aineo.transcript.Watch
---@field stop fun() ends the watch; nothing is delivered after it

--- Who the file or folder `stat` describes: a name that changes when another
--- file takes the path, as a replacement by rename does. `nil` for no stat.
---
---@param stat uv.fs_stat.result|nil
---@return string|nil
function M.identity_of(stat)
  if not stat then
    return nil
  end
  return ('%s:%s'):format(stat.dev, stat.ino)
end

--- Stops `handle` if it is active and closes it, unless it is closing already.
---
---@param handle uv.uv_handle_t|nil
local function close_handle(handle)
  if not handle or handle:is_closing() then
    return
  end
  if handle.stop then
    handle:stop()
  end
  handle:close()
end

--- Watches the file or folder at `path`, which need not exist yet, and calls
--- `on_change` when it may have changed: on each file-system event, once after
--- the watch starts (`SETTLE_MS`), and, while no event watches it, every
--- `POLL_MS`. A caller finds out what changed by looking; a call is a hint,
--- not a report.
---
--- The watch follows the path, not the file: when another file takes the path
--- (a replacement by rename, which leaves an event watching the file that is
--- gone), or the path appears or vanishes, it watches again.
---
--- `on_change` is called from the editor's main loop, never from a fast event.
---
---@param path string
---@param on_change fun()
---@return aineo.transcript.Watch
function M.watch(path, on_change)
  vim.validate('path', path, 'string')
  vim.validate('on_change', on_change, 'function')

  local stopped = false
  local check_pending = false
  local events = nil
  local ticker = nil
  local settle = nil
  --- The identity of what the path named when the watch last armed; nil when
  --- it named nothing.
  local armed_identity = nil

  --- Looks at the path, watches it again if another file took it, and calls
  --- `on_change`. Defined below, after `arm()`.
  local check

  local function check_soon()
    if stopped or check_pending then
      return
    end
    check_pending = true
    vim.schedule(function()
      check_pending = false
      if not stopped then
        check()
      end
    end)
  end

  --- Looks at the path once more `SETTLE_MS` from now.
  local function settle_soon()
    close_handle(settle)
    settle = assert(vim.uv.new_timer())
    settle:start(SETTLE_MS, 0, function()
      close_handle(settle)
      check_soon()
    end)
  end

  --- Starts looking every `POLL_MS` unless it does already.
  local function poll()
    if ticker then
      return
    end
    ticker = assert(vim.uv.new_timer())
    ticker:start(POLL_MS, POLL_MS, check_soon)
  end

  --- Watches the path by file-system event if it exists and the system can
  --- make one, else by looking every `POLL_MS`.
  local function arm()
    close_handle(events)
    events = nil
    local stat = vim.uv.fs_stat(path)
    armed_identity = M.identity_of(stat)
    if stat then
      local handle = assert(vim.uv.new_fs_event())
      if handle:start(path, {}, check_soon) then
        events = handle
        close_handle(ticker)
        ticker = nil
        settle_soon()
        return
      end
      close_handle(handle)
    end
    poll()
  end

  check = function()
    if M.identity_of(vim.uv.fs_stat(path)) ~= armed_identity then
      arm()
    end
    on_change()
  end

  arm()

  return {
    stop = function()
      stopped = true
      close_handle(events)
      close_handle(ticker)
      close_handle(settle)
    end,
  }
end

return M
