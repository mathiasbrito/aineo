--- A tab's explorer, made of the tab's other homes: the explorer
--- (`aineo.explorer`) reads through the git home, shows the folder the
--- tab's Claude Code works in or what the tab's changes pane shows alone,
--- whose pick its `s` shares (`aineo.changes`' `focused_work()`,
--- `offer_scopes()`), opens a file as a link to it opens
--- (`aineo.entry.links`), and pastes into that Claude Code's prompt through
--- the Send home (`aineo.send`'s `paste()`).

local links = require('aineo.entry.links')

local M = {}

--- The explorer of the tab whose homes are `homes`, all but the explorer
--- itself made.
---
---@param homes aineo.entry.Homes
---@return aineo.explorer.Home
function M.make_explorer(homes)
  local explorer = require('aineo.explorer').new({
    git = require('aineo.git'),
    claude_folder = function()
      return homes.claude.session_directory() or vim.fn.getcwd()
    end,
    focused_work = homes.changes.focused_work,
    offer_work = homes.changes.offer_scopes,
    open_file = links.open_file,
    paste = function(text)
      require('aineo.send').paste(text, { session = homes.claude })
    end,
  })
  homes.changes.watch_focused_work(explorer.refresh)
  return explorer
end

--- What has a tab's explorer follow the current file.
---@class aineo.entry.ExplorerFollowing
---@field group string the autocommand group of the handler, made anew
---@field explorer aineo.explorer.Home
---@field page fun(): integer|nil the tab page the tab is in, nil before its layout opens

--- Has `following.explorer` follow each file a window of the tab's tab page
--- shows as the cursor enters it (`aineo.explorer`'s `follow()`): a buffer
--- that is a file, by its full name. A buffer that is no file — a terminal,
--- a pane's scratch buffer, a diff — and a window of another tab page change
--- nothing.
---
---@param following aineo.entry.ExplorerFollowing
function M.follow_current_file(following)
  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup(following.group, {}),
    desc = 'aineo: the explorer follows the current file',
    callback = function(event)
      local page = following.page()
      if page ~= vim.api.nvim_get_current_tabpage() or vim.bo[event.buf].buftype ~= '' then
        return
      end
      local name = vim.api.nvim_buf_get_name(event.buf)
      if name ~= '' then
        following.explorer.follow(vim.fn.fnamemodify(name, ':p'))
      end
    end,
  })
end

return M
