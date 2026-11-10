--- What reveals a file opened with the finder (`aineo.entry.finding`) in the
--- explorer of its tab: the finder hands the search to a picker, which opens
--- its own windows, on a later tick than the call that asked for them, and
--- opens the file it confirms in a window of its own choosing, telling no one.
--- So the search is watched: once a window that did not exist when the search
--- began has been entered, the picker is open, and the next file a window of
--- the tab page that does not float shows is the one found, and is handed to
--- the explorer's `reveal()`. The watch ends when the cursor goes back to a
--- window that existed when the search began (the picker closed), and a file
--- shown before any picker window was entered, once the search call had
--- returned, is not the one found. Entering a file any other way is not a
--- reveal.

local M = {}

--- The autocommand group of the watch of a tab page, made anew with each
--- search, by the tab page's number.
---
---@param page integer
---@return string
local function group_name(page)
  return 'aineo.entry.find_reveal.' .. page
end

--- The watch of each tab page that has one, by its tab page, as the token of
--- the search that made it: a search's own stop ends nothing a later search
--- watches.
---@type table<integer, table>
local watches = {}

--- Ends the watch `token` made of `page`, if it is still the watch of `page`.
---
---@param page integer
---@param token table
local function stop(page, token)
  if watches[page] == token then
    watches[page] = nil
    pcall(vim.api.nvim_del_augroup_by_name, group_name(page))
  end
end

--- Runs `callback` after the commands in flight are done and the callbacks
--- they scheduled have run, which is when the layout has moved a file a window
--- of its own showed to the file column (`aineo.layout`'s redirect), and a
--- picker has opened the file it confirmed after returning the cursor.
---
---@param callback fun()
local function after_the_layout_settles(callback)
  vim.schedule(function()
    vim.schedule(callback)
  end)
end

--- Whether the current window floats.
---
---@return boolean
local function in_a_float()
  return vim.api.nvim_win_get_config(0).relative ~= ''
end

--- Whether `buffer` is a file with a name.
---
---@param buffer integer
---@return boolean
local function is_named_file(buffer)
  return vim.bo[buffer].buftype == '' and vim.api.nvim_buf_get_name(buffer) ~= ''
end

--- What a watch knows of its search.
---@class aineo.entry.FindWatch
---@field searching boolean whether the call that starts the search has not returned yet
---@field picker_seen boolean whether a window that did not exist when the search began was entered
---@field stop fun() ends the watch

--- Starts watching for the file the picker is about to open: the next file
--- buffer, other than the one in the current window now, that a window that
--- does not float of the current tab page comes to show is revealed
--- (`reveal`), and the watch ends, provided the search call is still running
--- or a picker window was entered. The watch ends without a reveal two ticks
--- after the cursor enters a window that did not float and existed when the
--- search began, once a picker window was entered: the picker was closed.
---
---@param reveal fun(file: string)
---@return aineo.entry.FindWatch watch
local function start(reveal)
  local page = vim.api.nvim_get_current_tabpage()
  local before = vim.api.nvim_get_current_buf()
  local token = {}
  local existing = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(page)) do
    existing[window] = true
  end
  watches[page] = token
  local group = vim.api.nvim_create_augroup(group_name(page), {})
  local watch = {
    searching = true,
    picker_seen = false,
    stop = function()
      stop(page, token)
    end,
  }
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    desc = 'aineo: reveal the file the finder opened in the explorer',
    callback = function(event)
      if
        vim.api.nvim_get_current_tabpage() ~= page
        or in_a_float()
        or event.buf == before
        or not is_named_file(event.buf)
      then
        return
      end
      watch.stop()
      if not (watch.searching or watch.picker_seen) then
        return
      end
      local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(event.buf), ':p')
      after_the_layout_settles(function()
        reveal(file)
      end)
    end,
  })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = group,
    desc = 'aineo: stop watching for the finder’s file once its picker is gone',
    callback = function()
      if not existing[vim.api.nvim_get_current_win()] then
        watch.picker_seen = true
      elseif watch.picker_seen and not in_a_float() then
        after_the_layout_settles(watch.stop)
      end
    end,
  })
  return watch
end

--- Runs `search`, which starts a search for a file and may open the file it
--- finds before returning or later, and has the file revealed (`reveal`) the
--- way `start()` says. An error `search` raises is raised again, the watch
--- over.
---
---@param reveal fun(file: string) what reveals a file in the tab's explorer
---@param search fun()
function M.watching(reveal, search)
  local watch = start(reveal)
  local searched, failure = pcall(search)
  watch.searching = false
  if not searched then
    watch.stop()
    error(failure, 0)
  end
end

return M
