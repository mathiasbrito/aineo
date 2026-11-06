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

--- One timer that looks for every watch that has none of its own to look with.
---@class aineo.transcript.Poller
---@field add fun(look: fun()): fun() has `look` called every period while it is added, one timer for all, and returns what removes it; the timer is closed once none is added

--- Makes a poller that calls what is added to it every `period_ms`, on a
--- timer of its own, which runs only while something is added. Watches handed
--- it (`M.watch()`) look for a path that is not there with it, so that
--- several share one timer and look less often than `POLL_MS`.
---
---@param period_ms integer
---@return aineo.transcript.Poller
function M.new_poller(period_ms)
  local ticker = nil
  local looks = {}
  return {
    add = function(look)
      local entry = { look = look }
      table.insert(looks, entry)
      if not ticker then
        ticker = assert(vim.uv.new_timer())
        ticker:start(period_ms, period_ms, function()
          for _, each in ipairs(vim.list_slice(looks)) do
            each.look()
          end
        end)
      end
      return function()
        for position, each in ipairs(looks) do
          if each == entry then
            table.remove(looks, position)
            break
          end
        end
        if #looks == 0 and ticker then
          ticker:stop()
          if not ticker:is_closing() then
            ticker:close()
          end
          ticker = nil
        end
      end
    end,
  }
end

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
--- With a `poller`, the looks that would be every `POLL_MS` are the poller's,
--- every period it was made with, and share its timer.
---
---@param path string
---@param on_change fun()
---@param poller? aineo.transcript.Poller
---@return aineo.transcript.Watch
function M.watch(path, on_change, poller)
  vim.validate('path', path, 'string')
  vim.validate('on_change', on_change, 'function')
  vim.validate('poller', poller, 'table', true)

  local stopped = false
  local check_pending = false
  local events = nil
  local ticker = nil
  local settle = nil
  --- What takes this watch off its poller; nil while it is not on one.
  local leave_poller = nil
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
    if poller then
      leave_poller = leave_poller or poller.add(check_soon)
      return
    end
    if ticker then
      return
    end
    ticker = assert(vim.uv.new_timer())
    ticker:start(POLL_MS, POLL_MS, check_soon)
  end

  --- Watches the path by file-system event if it is a regular file or a
  --- folder and the system can make one, else by looking every `POLL_MS`. A
  --- named pipe or a device is not given an event: making one opens it, which
  --- holds the editor until something writes to the pipe.
  local function arm()
    close_handle(events)
    events = nil
    local stat = vim.uv.fs_stat(path)
    armed_identity = M.identity_of(stat)
    if stat and (stat.type == 'file' or stat.type == 'directory') then
      local handle = assert(vim.uv.new_fs_event())
      if handle:start(path, {}, check_soon) then
        events = handle
        close_handle(ticker)
        ticker = nil
        if leave_poller then
          leave_poller()
          leave_poller = nil
        end
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
      if leave_poller then
        leave_poller()
        leave_poller = nil
      end
    end,
  }
end

return M
