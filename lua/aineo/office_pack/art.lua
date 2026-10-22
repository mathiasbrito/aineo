--- The reader of a pack's art files: a header of `field: value` lines, a line
--- `---`, then the frames of a piece of pixel art, each a block of rows, one
--- character per pixel, `.` transparent, the frames separated by `---`.
---
--- ```
--- about: A person.
--- colours: A = agent, k = ink
--- anchor: 5, 11
--- seconds per frame: 0.2
--- ---
--- .AA.
--- AkkA
--- ```

local M = {}

local FRAME_SEPARATOR = '---'

--- How long a frame shows when the file does not say.
local DEFAULT_SECONDS_PER_FRAME = 0.25

---@class aineo.office_pack.Anchor
---@field column integer the pixel's column, from 0 at the left
---@field row integer the pixel's row, from 0 at the top

--- A piece of pixel art.
---@class aineo.office_pack.Piece
---@field name string
---@field colours table<string, string> the colour each letter of the art is: a name from the pack's `colours`, or `agent`, `agent_light`, `agent_shade`, `agent_blush`
---@field anchor aineo.office_pack.Anchor the pixel that stands on the cell the piece is placed at
---@field seconds_per_frame number
---@field frames string[][] each frame's rows, top to bottom
---@field width integer the widest row
---@field height integer the most rows of a frame

--- The lines of `text` without line ends.
---
---@param text string
---@return string[]
local function lines_of(text)
  return vim.split(text:gsub('\r', ''), '\n', { plain = true })
end

--- The colours of a header's `colours` value, `A = agent, k = ink`.
---
---@param value string
---@return table<string, string>|nil colours
---@return string|nil problem
local function read_colours(value)
  local colours = {}
  for entry in vim.gsplit(value, ',', { plain = true }) do
    local letter, name = entry:match('^%s*(%S)%s*=%s*([%w_]+)%s*$')
    if not letter then
      return nil, ('“%s” is not “letter = colour”'):format(vim.trim(entry))
    end
    colours[letter] = name
  end
  return colours
end

--- The anchor of a header's `anchor` value, `5, 11`.
---
---@param value string
---@return aineo.office_pack.Anchor|nil anchor
local function read_anchor(value)
  local column, row = value:match('^%s*(%d+)%s*,%s*(%d+)%s*$')
  if not column then
    return nil
  end
  return { column = tonumber(column), row = tonumber(row) }
end

--- Reads the header lines into a piece's fields.
---
---@param header string[]
---@return table|nil fields colours, anchor and seconds_per_frame, each when the header gave it
---@return string|nil problem
local function read_header(header)
  local fields = {}
  for _, line in ipairs(header) do
    local key, value = line:match('^%s*([%a ]-)%s*:%s*(.-)%s*$')
    if key == 'colours' then
      local colours, problem = read_colours(value)
      if not colours then
        return nil, problem
      end
      fields.colours = colours
    elseif key == 'anchor' then
      fields.anchor = read_anchor(value)
      if not fields.anchor then
        return nil, 'the anchor is “column, row”, two whole numbers'
      end
    elseif key == 'seconds per frame' then
      fields.seconds_per_frame = tonumber(value)
      if not fields.seconds_per_frame or fields.seconds_per_frame <= 0 then
        return nil, 'seconds per frame is a number above 0'
      end
    end
  end
  return fields
end

--- The frames of the lines after the header: each run of rows between
--- separator lines, a run without rows left out.
---
---@param lines string[]
---@return string[][] frames
local function read_frames(lines)
  local frames = {}
  local rows = {}
  local function end_frame()
    if #rows > 0 then
      table.insert(frames, rows)
    end
    rows = {}
  end
  for _, line in ipairs(lines) do
    if line == FRAME_SEPARATOR then
      end_frame()
    elseif line ~= '' then
      table.insert(rows, line)
    end
  end
  end_frame()
  return frames
end

--- The largest width and height of `frames`.
---
---@param frames string[][]
---@return integer width
---@return integer height
local function measure(frames)
  local width, height = 0, 0
  for _, rows in ipairs(frames) do
    height = math.max(height, #rows)
    for _, row in ipairs(rows) do
      width = math.max(width, #row)
    end
  end
  return width, height
end

--- Reads the art file `text` as the piece `name`.
---
--- `nil` and the problem when the file has no `---` line, a header field
--- that is wrong, or no pixels.
---
---@param name string
---@param text string
---@return aineo.office_pack.Piece|nil piece
---@return string|nil problem
function M.parse(name, text)
  local lines = lines_of(text)
  local separator = vim.fn.index(lines, FRAME_SEPARATOR)
  if separator < 0 then
    return nil, 'the header is not followed by a line “---”'
  end
  local fields, problem = read_header(vim.list_slice(lines, 1, separator))
  if not fields then
    return nil, problem
  end
  local frames = read_frames(vim.list_slice(lines, separator + 2))
  if #frames == 0 then
    return nil, 'the piece has no pixels'
  end
  local width, height = measure(frames)
  return {
    name = name,
    colours = fields.colours or {},
    anchor = fields.anchor or { column = 0, row = #frames[1] - 1 },
    seconds_per_frame = fields.seconds_per_frame or DEFAULT_SECONDS_PER_FRAME,
    frames = frames,
    width = width,
    height = height,
  }
end

return M
