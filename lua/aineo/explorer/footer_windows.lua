--- The explorer's footer on screen: a floating window on the bottom rows of
--- each window that shows the explorer's buffer, with the footer's lines
--- (`aineo.explorer.footer`), following that window as it moves, resizes,
--- hides or closes, in whatever tab page it is; and room after the tree's
--- last line for the tree to scroll past it.

local footer = require('aineo.explorer.footer')

local M = {}

--- The filetype of a footer's buffer.
local FILETYPE = 'aineo-explorer-footer'

--- How high a footer stacks among the floating windows: below any other.
local ZINDEX = 1

--- One footer: its floating window and buffer, how many lines it shows, and
--- the line the cursor of the window it sits on was last kept on.
---@class aineo.explorer.FooterWindow
---@field window integer
---@field buffer integer
---@field height integer
---@field cursor_line? integer

--- The highlight groups the footer shows in: each line's, by its role
--- (`aineo.explorer.FooterLine`), and the group of the footer's background.
---@class aineo.explorer.FooterGroups
---@field roles table<string, string>
---@field background string

--- The footers of one explorer buffer, as `M.follow()` gives them.
---@class aineo.explorer.Footers
---@field draw fun(shown: aineo.explorer.View) lays each footer out again under `shown`, what the explorer shows now
---@field keep_cursors fun() keeps the cursor of each window a footer sits on above it, the tree scrolled as needed
---@field stop fun() closes every footer and stops following the windows

--- The namespace of the footers' colours, and of the room left after the
--- tree's last line (`leave_room()`).
local NAMESPACE = vim.api.nvim_create_namespace('aineo.explorer.footer')

--- The place of a footer of `count` lines on the bottom rows of `window`,
--- `size` its size, as `nvim_win_set_config()` takes it.
---
---@param window integer
---@param size { width: integer, height: integer }
---@param count integer
---@return table
local function placement(window, size, count)
  return {
    relative = 'win',
    win = window,
    row = size.height - count,
    col = 0,
    width = size.width,
    height = count,
  }
end

--- Whether the floating window `window` is placed as `wanted` says.
---
---@param window integer
---@param wanted table
---@return boolean
local function is_placed(window, wanted)
  local config = vim.api.nvim_win_get_config(window)
  return config.win == wanted.win
    and config.row == wanted.row
    and config.col == wanted.col
    and config.width == wanted.width
    and config.height == wanted.height
end

--- Opens a footer placed as `wanted` says, its background in `background`.
---
---@param wanted table
---@param background string
---@return aineo.explorer.FooterWindow
local function open(wanted, background)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].filetype = FILETYPE
  local window = vim.api.nvim_open_win(
    buffer,
    false,
    vim.tbl_extend('force', wanted, {
      focusable = false,
      style = 'minimal',
      zindex = ZINDEX,
      border = 'none',
      noautocmd = true,
    })
  )
  vim.wo[window].winhighlight = 'NormalFloat:' .. background
  return { window = window, buffer = buffer, height = wanted.height }
end

--- Writes `lines` into the buffer of `shown_footer`, each line in the group
--- of its role.
---
---@param shown_footer aineo.explorer.FooterWindow
---@param lines aineo.explorer.FooterLine[]
---@param role_groups table<string, string>
local function write(shown_footer, lines, role_groups)
  local buffer = shown_footer.buffer
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(
    buffer,
    0,
    -1,
    false,
    vim.tbl_map(function(line)
      return line.text
    end, lines)
  )
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_clear_namespace(buffer, NAMESPACE, 0, -1)
  for number, line in ipairs(lines) do
    vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, number - 1, 0, {
      line_hl_group = role_groups[line.role],
    })
  end
end

--- Leaves room after the last line of `buffer`, the explorer's, for the tree
--- to scroll past a footer: as many blank virtual lines as `rows`.
---
---@param buffer integer
---@param rows integer
local function leave_room(buffer, rows)
  vim.api.nvim_buf_clear_namespace(buffer, NAMESPACE, 0, -1)
  if rows < 1 then
    return
  end
  local blank_lines = {}
  for _ = 1, rows do
    table.insert(blank_lines, { { '' } })
  end
  vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, vim.api.nvim_buf_line_count(buffer) - 1, 0, {
    virt_lines = blank_lines,
  })
end

--- The rows the lines of `window` from `top` to the one before `line` take
--- on screen, with the virtual lines above `line`.
---
---@param window integer
---@param top integer
---@param line integer
---@return integer
local function rows_between(window, top, line)
  if line <= top then
    return 0
  end
  return vim.api.nvim_win_text_height(
    window,
    { start_row = top - 1, end_row = line - 1, end_vcol = 0 }
  ).all
end

--- The first line `window` shows.
---
---@param window integer
---@return integer
local function top_line(window)
  return vim.api.nvim_win_call(window, function()
    return vim.fn.line('w0')
  end)
end

--- Keeps the cursor of `window` on one of its `rows` top rows, the rows
--- above its footer, when it is below them: the cursor goes up to the last
--- of them when `scrolled_up`, as the tree scrolling up pushed it there;
--- otherwise the tree scrolls until its line shows on it.
---
---@param window integer
---@param rows integer
---@param scrolled_up boolean
local function keep_cursor_above(window, rows, scrolled_up)
  local cursor = vim.api.nvim_win_get_cursor(window)
  local line, top = cursor[1], top_line(window)
  if rows < 1 or rows_between(window, top, line) < rows then
    return
  end
  if scrolled_up then
    repeat
      line = line - 1
    until line <= top or rows_between(window, top, line) < rows
    vim.api.nvim_win_set_cursor(window, { line, cursor[2] })
    return
  end
  repeat
    top = top + 1
  until rows_between(window, top, line) < rows
  vim.api.nvim_win_call(window, function()
    vim.fn.winrestview({ topline = top })
  end)
end

--- Has a footer follow each window that shows `buffer`, the explorer's, its
--- lines in `groups`; it is drawn as `draw()` is asked, and again as windows
--- close, resize or change buffer, once the commands in flight are done.
--- Every footer closes once `buffer` is wiped. The cursor of each window a
--- footer sits on is kept above it: the tree scrolls when the cursor goes
--- down under it, and as each footer is drawn; the cursor moves up when the
--- tree scrolled and left it there.
---
---@param buffer integer
---@param groups aineo.explorer.FooterGroups
---@return aineo.explorer.Footers
function M.follow(buffer, groups)
  local group_name = 'aineo.explorer.footer.' .. buffer
  ---@type table<integer, aineo.explorer.FooterWindow>
  local footers = {}
  ---@type aineo.explorer.View|nil
  local last_shown = nil

  --- Closes the footer that sits on `window`, when one does.
  ---
  ---@param window integer
  local function close(window)
    local shown_footer = footers[window]
    footers[window] = nil
    if shown_footer and vim.api.nvim_win_is_valid(shown_footer.window) then
      vim.api.nvim_win_close(shown_footer.window, true)
    end
  end

  --- Lays the footer of `window` out under `shown`: opened when it is not,
  --- placed on its bottom rows, its lines written for its size.
  ---
  ---@param window integer
  ---@param shown aineo.explorer.View
  local function lay_out(window, shown)
    local size =
      { width = vim.api.nvim_win_get_width(window), height = vim.api.nvim_win_get_height(window) }
    if size.width < 1 or size.height < 1 then
      close(window)
      return
    end
    local lines = footer.lines(shown, size)
    local wanted = placement(window, size, #lines)
    local shown_footer = footers[window]
    if not (shown_footer and vim.api.nvim_win_is_valid(shown_footer.window)) then
      shown_footer = open(wanted, groups.background)
      footers[window] = shown_footer
    elseif not is_placed(shown_footer.window, wanted) then
      vim.api.nvim_win_set_config(shown_footer.window, wanted)
    end
    shown_footer.height = #lines
    write(shown_footer, lines, groups.roles)
  end

  --- Keeps the cursor of `window` above the footer that sits on it
  --- (`keep_cursor_above()`), when one does, and remembers its line.
  ---
  ---@param window integer
  ---@param scrolled_up boolean
  local function keep_cursor_of(window, scrolled_up)
    local shown_footer = footers[window]
    if not (shown_footer and vim.api.nvim_win_is_valid(window)) then
      return
    end
    local rows = vim.api.nvim_win_get_height(window) - shown_footer.height
    keep_cursor_above(window, rows, scrolled_up)
    shown_footer.cursor_line = vim.api.nvim_win_get_cursor(window)[1]
  end

  --- Whether a window a footer sits on no longer shows `buffer`.
  ---
  ---@return boolean
  local function sits_on_another_buffer()
    return vim.iter(pairs(footers)):any(function(window)
      return vim.api.nvim_win_is_valid(window) and vim.api.nvim_win_get_buf(window) ~= buffer
    end)
  end

  --- Lays out the footer of every window that shows `buffer` under what the
  --- explorer showed last, each window's cursor kept above it, closes the
  --- footers of windows that no longer do, and leaves room after the tree's
  --- last line for the tallest footer (`leave_room()`).
  local function draw_all()
    if not (last_shown and vim.api.nvim_buf_is_valid(buffer)) then
      return
    end
    local showing = {}
    for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
      showing[window] = true
      lay_out(window, last_shown)
      keep_cursor_of(window, false)
    end
    local tallest = 0
    for window, shown_footer in pairs(footers) do
      if showing[window] then
        tallest = math.max(tallest, shown_footer.height)
      else
        close(window)
      end
    end
    leave_room(buffer, tallest)
  end

  local draw_asked = false

  --- Draws every footer once the commands in flight are done, however many
  --- times it is asked for meanwhile.
  local function draw_soon()
    if draw_asked then
      return
    end
    draw_asked = true
    vim.schedule(function()
      draw_asked = false
      draw_all()
    end)
  end

  local augroup = vim.api.nvim_create_augroup(group_name, {})

  ---@type aineo.explorer.Footers
  local shown_footers = {}

  function shown_footers.draw(shown)
    last_shown = shown
    draw_all()
  end

  function shown_footers.keep_cursors()
    for window in pairs(footers) do
      keep_cursor_of(window, false)
    end
  end

  function shown_footers.stop()
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    for window in pairs(footers) do
      close(window)
    end
  end

  vim.api.nvim_create_autocmd({ 'WinClosed', 'WinResized' }, {
    group = augroup,
    desc = 'aineo: keep the explorer’s footers on the windows that show it',
    callback = draw_soon,
  })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = augroup,
    desc = 'aineo: keep the explorer’s footers on the windows that show it',
    callback = function(event)
      if event.buf == buffer or sits_on_another_buffer() then
        draw_soon()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinScrolled', {
    group = augroup,
    desc = 'aineo: keep the cursor of the explorer above its footer as the tree scrolls',
    callback = function()
      for key, change in pairs(vim.v.event) do
        local window = tonumber(key)
        if
          window
          and change.topline ~= 0
          and vim.api.nvim_win_is_valid(window)
          and vim.api.nvim_win_get_buf(window) == buffer
        then
          keep_cursor_of(window, true)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = buffer,
    desc = 'aineo: keep the cursor of the explorer above its footer',
    callback = function()
      local window = vim.api.nvim_get_current_win()
      local shown_footer = footers[window]
      if not shown_footer then
        return
      end
      local line = vim.api.nvim_win_get_cursor(window)[1]
      keep_cursor_of(window, shown_footer.cursor_line ~= nil and line < shown_footer.cursor_line)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = augroup,
    buffer = buffer,
    desc = 'aineo: close the explorer’s footers',
    callback = shown_footers.stop,
  })
  return shown_footers
end

return M
