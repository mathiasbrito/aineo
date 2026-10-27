--- The float in which the user steers a request: a text they edit before it
--- is sent. It knows nothing of what the text asks for; the caller hands it
--- the text to start from and takes the text sent.

local M = {}

--- The most columns the float takes, and the fewest columns it leaves free
--- either side of it on a narrower screen.
local MOST_WIDTH = 100
local SIDE_MARGIN = 2

--- The fewest and the most rows the float's text area takes.
local FEWEST_ROWS = 6
local MOST_ROWS = 20

--- What the float's title says after what the caller names, which keys do.
local KEYS_TITLE = '<CR> sends · q or <Esc> cancels'

--- What the title says after `KEYS_TITLE` when the float has a default text.
local RESTORE_TITLE = ' · R restores the default'

--- A text the user wrote and the default text it was written over.
---@class aineo.explain.Remembered
---@field text string
---@field default string the default text of the float it was written in

--- What the user last wrote, by the name of what it steered.
---@type table<string, aineo.explain.Remembered>
local remembered = {}

--- What a float is opened with.
---@class aineo.explain.Steering
---@field name? string what it steers: the text sent is remembered under it and starts the next float of that name; nothing is remembered when absent
---@field title string what the request it steers does, said in the float's title
---@field default? string the text to start from when none was sent under `name`, and what `R` brings back; its first line is the head that names what the request is about; the float starts empty and maps no `R` when absent
---@field on_send fun(text: string) called with the text sent, after the float is closed
---@field steered_buffer integer the buffer of the code the request is about, which `close_for()` names

--- The lines of `text`, the way a buffer holds them.
---
---@param text string
---@return string[]
local function lines_of(text)
  return vim.split(text, '\n', { plain = true })
end

--- The first line of `text`.
---
---@param text string
---@return string
local function head_of(text)
  return lines_of(text)[1]
end

--- The lines a float starts with: the default text, or the text remembered
--- under `steering.name`, whose head is replaced by the head of
--- `steering.default` when it still reads as the default it was written over
--- had it, so that a text written for another file or other lines names this
--- request's.
---
---@param steering aineo.explain.Steering
---@return string[]
local function starting_lines(steering)
  local last = steering.name and remembered[steering.name]
  if not last then
    return lines_of(steering.default or '')
  end
  local lines = lines_of(last.text)
  if lines[1] == head_of(last.default) then
    lines[1] = head_of(steering.default)
  end
  return lines
end

--- The configuration of a float that holds `line_count` lines, centred in the
--- editor, with the title `title` followed by what its keys do, `R` among
--- them when `restores` is set.
---
---@param line_count integer
---@param title string
---@param restores boolean
---@return vim.api.keyset.win_config
local function float_config(line_count, title, restores)
  local width = math.min(MOST_WIDTH, vim.o.columns - 2 * SIDE_MARGIN)
  local height = math.max(FEWEST_ROWS, math.min(MOST_ROWS, line_count + 2))
  height = math.min(height, vim.o.lines - 4)
  return {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - 1 - height - 2) / 2),
    col = math.floor((vim.o.columns - width - 2) / 2),
    style = 'minimal',
    border = 'rounded',
    title = (' %s: %s%s '):format(title, KEYS_TITLE, restores and RESTORE_TITLE or ''),
    title_pos = 'center',
  }
end

--- Closes `window` if it is still open.
---
---@param window integer
local function close(window)
  if vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, true)
  end
end

--- The window of the float that is open, if any: there is one float at a
--- time.
---@type integer|nil
local open_window = nil

--- The buffer whose request the float that is open steers, if any.
---@type integer|nil
local open_for = nil

--- The text `buffer` holds, white space at its ends cut off.
---
---@param buffer integer
---@return string
local function text_of(buffer)
  return vim.trim(table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n'))
end

--- Remembers `text`, written in the float `steering` opened, under
--- `steering.name`; nothing when it has none.
---
---@param steering aineo.explain.Steering
---@param text string
local function remember(steering, text)
  if steering.name then
    remembered[steering.name] = { text = text, default = steering.default }
  end
end

--- Opens a centred float holding a scratch buffer of the markdown filetype,
--- starting from the text last written under `steering.name`, else from
--- `steering.default`, else empty. In Normal mode `<CR>` sends the text,
--- `q` and `<Esc>` close the float with nothing sent and nothing kept, and,
--- when it has a `steering.default`, `R` puts it back; Insert mode is plain
--- editing. A text of white space alone is not sent: the user is told,
--- once, and the float stays. Sending closes the float, remembers the text
--- (`remember()`) and calls `steering.on_send` with it. Leaving the float
--- closes it with nothing sent and remembers its text as a draft, which
--- starts the next float of that name as a text sent does. While a float is
--- open, a call focuses it and opens no other.
---
---@param steering aineo.explain.Steering
function M.open(steering)
  if open_window and vim.api.nvim_win_is_valid(open_window) then
    vim.api.nvim_set_current_win(open_window)
    return
  end
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].filetype = 'markdown'
  vim.bo[buffer].bufhidden = 'wipe'
  local lines = starting_lines(steering)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  local window = vim.api.nvim_open_win(
    buffer,
    true,
    float_config(#lines, steering.title, steering.default ~= nil)
  )
  open_window = window
  open_for = steering.steered_buffer
  vim.wo[window].wrap = true
  vim.wo[window].linebreak = true

  local finished = false
  local function finish()
    finished = true
    close(window)
  end
  local function send()
    local text = text_of(buffer)
    if text == '' then
      vim.notify('aineo: the prompt is empty: nothing is sent', vim.log.levels.WARN)
      return
    end
    remember(steering, text)
    finish()
    steering.on_send(text)
  end
  local function restore_default()
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines_of(steering.default))
  end
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = buffer,
    once = true,
    desc = 'aineo: close the steering float and keep its text as a draft',
    callback = function()
      if finished then
        return
      end
      local text = text_of(buffer)
      if text ~= '' then
        remember(steering, text)
      end
      vim.schedule(function()
        close(window)
      end)
    end,
  })
  vim.keymap.set(
    'n',
    '<CR>',
    send,
    { buffer = buffer, nowait = true, desc = 'aineo: send the prompt' }
  )
  vim.keymap.set('n', 'q', finish, { buffer = buffer, nowait = true, desc = 'aineo: cancel' })
  vim.keymap.set('n', '<Esc>', finish, { buffer = buffer, nowait = true, desc = 'aineo: cancel' })
  if steering.default then
    vim.keymap.set(
      'n',
      'R',
      restore_default,
      { buffer = buffer, nowait = true, desc = 'aineo: restore the default prompt' }
    )
  end
end

--- Closes the float that is open, if it steers a request for `buffer`
--- (`aineo.explain.Steering`'s `steered_buffer`), with nothing sent; the
--- text remembered from earlier floats stays.
---
---@param buffer integer
function M.close_for(buffer)
  if open_window and open_for == buffer then
    close(open_window)
  end
end

return M
