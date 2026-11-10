--- What reveals a file opened with the finder (`aineo.entry.finding`) in the
--- explorer of its tab: the finder hands the search to a picker, which opens
--- the file it confirms in a window of its own choosing and tells no one, so
--- the search is watched instead. While a picker may still be open, the next
--- file a window of the tab's tab page that does not float enters is the one
--- found, and is handed to the explorer's `reveal()`. Entering a file any
--- other way is not a reveal.

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
--- of its own showed to the file column (`aineo.layout`'s redirect).
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

--- Starts watching for the file the picker is about to open: the next file
--- buffer, other than the one in the current window now, a window that does
--- not float of the current tab page enters is revealed (`reveal`), and the
--- watch ends. It ends without a reveal once the cursor is back in the window
--- the search began in and nothing was opened by the time the commands in
--- flight are done: the picker was cancelled.
---
---@param reveal fun(file: string)
---@return { window: integer, stop: fun() } watch
local function start(reveal)
  local page = vim.api.nvim_get_current_tabpage()
  local window = vim.api.nvim_get_current_win()
  local before = vim.api.nvim_get_current_buf()
  local token = {}
  watches[page] = token
  local group = vim.api.nvim_create_augroup(group_name(page), {})
  vim.api.nvim_create_autocmd('BufEnter', {
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
      stop(page, token)
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
      if vim.api.nvim_get_current_win() == window then
        after_the_layout_settles(function()
          stop(page, token)
        end)
      end
    end,
  })
  return {
    window = window,
    stop = function()
      stop(page, token)
    end,
  }
end

--- Runs `search`, which starts a search for a file and may open the file it
--- finds before returning or later, and has the file revealed (`reveal`) the
--- way `start()` says. A search that leaves the cursor in the window it began
--- in has finished already, one that opened nothing included, so it is not
--- watched further. An error `search` raises is raised again, the watch over.
---
---@param reveal fun(file: string) what reveals a file in the tab's explorer
---@param search fun()
function M.watching(reveal, search)
  local watch = start(reveal)
  local searched, failure = pcall(search)
  if not searched or vim.api.nvim_get_current_win() == watch.window then
    watch.stop()
  end
  if not searched then
    error(failure, 0)
  end
end

return M
