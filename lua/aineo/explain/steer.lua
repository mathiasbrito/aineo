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
local KEYS_TITLE = '<CR> sends · q or <Esc> cancels · R restores the default'

--- The text last sent, by the name of what it steered.
---@type table<string, string>
local remembered = {}

--- What a float is opened with.
---@class aineo.explain.Steering
---@field name string what it steers: the text sent is remembered under it and starts the next float of that name
---@field title string what the request it steers does, said in the float's title
---@field default string the text to start from when none was sent under `name`, and what `R` brings back
---@field on_send fun(text: string) called with the text sent, after the float is closed

--- The lines of `text`, the way a buffer holds them.
---
---@param text string
---@return string[]
local function lines_of(text)
  return vim.split(text, '\n', { plain = true })
end

--- The configuration of a float that holds `line_count` lines, centred in the
--- editor, with the title `title`.
---
---@param line_count integer
---@param title string
---@return vim.api.keyset.win_config
local function float_config(line_count, title)
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
    title = (' %s: %s '):format(title, KEYS_TITLE),
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

--- Opens a centred float holding a scratch buffer of the markdown filetype,
--- with the text last sent under `steering.name`, else `steering.default`.
--- In Normal mode `<CR>` sends the text, `q` and `<Esc>` close the float with
--- nothing sent, and `R` puts `steering.default` back; Insert mode is plain
--- editing. A text of white space alone is not sent: the user is told, once,
--- and the float stays. Sending closes the float, remembers the text under
--- `steering.name` and calls `steering.on_send` with it.
---
---@param steering aineo.explain.Steering
function M.open(steering)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].filetype = 'markdown'
  vim.bo[buffer].bufhidden = 'wipe'
  local lines = lines_of(remembered[steering.name] or steering.default)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  local window = vim.api.nvim_open_win(buffer, true, float_config(#lines, steering.title))
  vim.wo[window].wrap = true
  vim.wo[window].linebreak = true

  local function send()
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n'))
    if text == '' then
      vim.notify('aineo: the prompt is empty: nothing is sent', vim.log.levels.WARN)
      return
    end
    remembered[steering.name] = text
    close(window)
    steering.on_send(text)
  end
  local function restore_default()
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines_of(steering.default))
  end
  local function cancel()
    close(window)
  end
  vim.keymap.set(
    'n',
    '<CR>',
    send,
    { buffer = buffer, nowait = true, desc = 'aineo: send the prompt' }
  )
  vim.keymap.set('n', 'q', cancel, { buffer = buffer, nowait = true, desc = 'aineo: cancel' })
  vim.keymap.set('n', '<Esc>', cancel, { buffer = buffer, nowait = true, desc = 'aineo: cancel' })
  vim.keymap.set(
    'n',
    'R',
    restore_default,
    { buffer = buffer, nowait = true, desc = 'aineo: restore the default prompt' }
  )
end

return M
