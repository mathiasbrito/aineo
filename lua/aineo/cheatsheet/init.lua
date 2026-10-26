--- The cheatsheet of one tab, `require('aineo.cheatsheet')`: a window over the
--- whole right column of the tab's layout that lists aineo's keys in a
--- colourful sheet, written from the groups of keys it is asked for.
---
--- The cursor moves into the sheet when it opens, so that `/` and the keys
--- that scroll work in it; `q` and `<Esc>` close it, and so does toggling it
--- again, each giving the cursor back to the window it came from. It closes,
--- leaving the cursor where the user moved it, when the cursor leaves it, and
--- follows the right column as the screen changes, writing the sheet again for
--- the column's new width, and closes when the layout shows no right column.
---
--- It runs nothing and starts no request: what it shows is text.

local compose = require('aineo.cheatsheet.compose')
local cover_module = require('aineo.cover')
local look = require('aineo.cheatsheet.look')

local M = {}

--- What `open()` tells the user, as a warning, when the layout shows no right
--- side to cover.
local NO_RIGHT_SIDE = "aineo: the cheatsheet has no right side of aineo's layout to cover"

--- How the sheet's window opens (`aineo.cover`): its buffer is of the
--- filetype `aineo-cheatsheet`, the cursor moves into it, and the mouse
--- scrolls it.
---@type aineo.cover.Options
local SHEET_COVER =
  { filetype = 'aineo-cheatsheet', name = 'cheatsheet', enter = true, mouse = true }

--- The namespace of the sheet's highlights.
local NAMESPACE = vim.api.nvim_create_namespace('aineo.cheatsheet')

--- How many sheets have been made, which names the autocommand group of
--- each.
local sheets_made = 0

--- The text of the cheatsheet for a window `width` cells wide, written from
--- `groups`: its lines and the highlight of each part, in one column below 80
--- cells and in two from there on. Pure; the window writes what it gives.
---
---@type fun(groups: aineo.cheatsheet.Group[], width: integer): aineo.cheatsheet.Sheet
M.compose = compose.compose

---@class aineo.cheatsheet.Options
---@field right_side fun(): aineo.layout.Area|nil the screen cells the layout's right side takes now, nil when it shows none
---@field groups fun(): aineo.cheatsheet.Group[] the keys the sheet lists, asked each time it is written

---@class aineo.cheatsheet.Cheatsheet
---@field open fun() shows the sheet over the right side and moves the cursor into it; does nothing when it shows, and tells the user when there is no right side
---@field close fun() closes the sheet, if it shows, and moves the cursor back to the window it was in when the sheet opened, if that window remains
---@field toggle fun() closes the sheet when it shows and opens it otherwise
---@field let_go fun() closes the sheet, leaving the cursor where it is

--- Writes the sheet for the width of `open`'s window into its buffer, with
--- its highlights.
---
---@param open { cover: aineo.cover.Cover, area: aineo.layout.Area }
---@param groups aineo.cheatsheet.Group[]
local function write(open, groups)
  local sheet = compose.compose(groups, open.area.width)
  local buffer = open.cover.buffer
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, sheet.lines)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_clear_namespace(buffer, NAMESPACE, 0, -1)
  for _, highlight in ipairs(sheet.highlights) do
    vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, highlight.line, highlight.from, {
      end_col = highlight.to,
      hl_group = highlight.group,
    })
  end
end

--- Makes the cheatsheet of one tab. It has no window until `open()`.
---
---@param options aineo.cheatsheet.Options
---@return aineo.cheatsheet.Cheatsheet cheatsheet
function M.new_cheatsheet(options)
  vim.validate('options.right_side', options.right_side, 'function')
  vim.validate('options.groups', options.groups, 'function')
  sheets_made = sheets_made + 1

  --- What exists while the sheet shows; nil while it is hidden.
  ---@type { cover: aineo.cover.Cover, group: integer, previous: integer, area: aineo.layout.Area }|nil
  local showing = nil

  local cheatsheet = {}

  --- Closes the sheet `open`, if it is the one that shows, and moves the
  --- cursor to the window it came from when `returns` says so.
  ---
  ---@param open table what exists while the sheet shows
  ---@param returns boolean
  local function close_sheet(open, returns)
    if showing ~= open then
      return
    end
    showing = nil
    pcall(vim.api.nvim_del_augroup_by_id, open.group)
    cover_module.close(open.cover)
    if returns and vim.api.nvim_win_is_valid(open.previous) then
      vim.api.nvim_set_current_win(open.previous)
    end
  end

  --- Moves the sheet to where the right side is now and writes it for that
  --- width; closes it when the layout shows no right side. Does nothing from
  --- another tab page, whose cells are not the sheet's.
  ---
  ---@param open table what exists while the sheet shows
  local function follow_right_side(open)
    if vim.api.nvim_win_get_tabpage(open.cover.window) ~= vim.api.nvim_get_current_tabpage() then
      return
    end
    local area = options.right_side()
    if not area then
      vim.schedule(function()
        close_sheet(open, true)
      end)
    elseif not vim.deep_equal(area, open.area) then
      cover_module.place(open.cover, area)
      open.area = area
      write(open, options.groups())
    end
  end

  --- Makes the sheet follow the screen and the colour scheme, and close when
  --- the cursor leaves it or its window closes.
  ---
  ---@param open table what exists while the sheet shows
  local function watch(open)
    vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
      group = open.group,
      callback = function()
        follow_right_side(open)
      end,
    })
    vim.api.nvim_create_autocmd('WinLeave', {
      group = open.group,
      callback = function()
        if vim.api.nvim_get_current_win() == open.cover.window then
          vim.schedule(function()
            close_sheet(open, false)
          end)
        end
      end,
    })
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = open.group,
      callback = look.define,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = open.group,
      pattern = tostring(open.cover.window),
      callback = function()
        vim.schedule(function()
          close_sheet(open, false)
        end)
      end,
    })
  end

  function cheatsheet.open()
    if showing then
      return
    end
    local area = options.right_side()
    if not area then
      vim.notify(NO_RIGHT_SIDE, vim.log.levels.WARN)
      return
    end
    local groups = options.groups()
    look.define()
    local previous = vim.api.nvim_get_current_win()
    local cover = cover_module.open(area, SHEET_COVER)
    vim.wo[cover.window].signcolumn = 'no'
    local open = {
      cover = cover,
      group = vim.api.nvim_create_augroup(
        'aineo.cheatsheet.' .. sheets_made .. '.' .. cover.buffer,
        {
          clear = true,
        }
      ),
      previous = previous,
      area = area,
    }
    showing = open
    for _, key in ipairs({ 'q', '<Esc>' }) do
      vim.keymap.set('n', key, function()
        close_sheet(open, true)
      end, { buffer = cover.buffer, nowait = true, desc = 'aineo: close the cheatsheet' })
    end
    write(open, groups)
    watch(open)
  end

  function cheatsheet.close()
    if showing then
      close_sheet(showing, true)
    end
  end

  function cheatsheet.toggle()
    if showing then
      cheatsheet.close()
    else
      cheatsheet.open()
    end
  end

  function cheatsheet.let_go()
    if showing then
      close_sheet(showing, false)
    end
  end

  return cheatsheet
end

return M
