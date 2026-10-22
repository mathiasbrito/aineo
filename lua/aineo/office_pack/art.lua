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
---
--- Every problem of a file is told with the line it is on, and a file with
--- any problem gives no piece.

local M = {}

local FRAME_SEPARATOR = '---'

--- How long a frame shows when the file does not say.
local DEFAULT_SECONDS_PER_FRAME = 0.25

--- The largest art the reader takes, in pixels, and the most frames.
local MAX_WIDTH = 400
local MAX_HEIGHT = 200
local MAX_FRAMES = 64

--- What aineo draws into a piece, by the name an `area` header gives.
local AREA_NAMES = {
  'screen',
  'hand',
  'name',
  'plan',
  'time',
  'date',
  'sky',
  'page',
  'query',
}

---@class aineo.office_pack.Anchor
---@field column integer the pixel's column, from 0 at the left
---@field row integer the pixel's row, from 0 at the top

---@class aineo.office_pack.Stretch
---@field first integer the first column that repeats, counted from 1 at the left
---@field last integer the last column that repeats

---@class aineo.office_pack.Area
---@field column integer from 0 at the left
---@field row integer from 0 at the top
---@field width integer in pixels
---@field height integer in pixels

--- A piece of pixel art.
---@class aineo.office_pack.Piece
---@field name string
---@field about string
---@field colours table<string, string> the colour each letter of the art is: a name from the pack's `colours`, or `agent`, `agent_light`, `agent_shade`, `agent_blush`
---@field anchor aineo.office_pack.Anchor the pixel that stands on the cell the piece is placed at
---@field faces string `left` or `right`: the way the art faces
---@field stretch? aineo.office_pack.Stretch the columns that repeat to stretch the piece; none for a piece that does not stretch
---@field areas table<string, aineo.office_pack.Area> the rectangles aineo draws into, by name
---@field seconds_per_frame number
---@field frames string[][] each frame's rows, top to bottom
---@field width integer the widest row
---@field height integer the most rows of a frame

---@class aineo.office_pack.ArtContext
---@field report aineo.office_pack.Report tells a problem of the file
---@field colour_names table<string, true> the colours a header may name: the pack's, and the character's own

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
---@param line integer
---@param context aineo.office_pack.ArtContext
---@return table<string, string> colours the colour of each letter the value names
---@return boolean is_readable whether every entry of the value is “letter = colour”
local function read_colours(value, line, context)
  local colours = {}
  local is_readable = true
  for entry in vim.gsplit(value, ',', { plain = true }) do
    local letter, name = entry:match('^%s*(%S)%s*=%s*([%w_]+)%s*$')
    if not letter then
      context.report(line, ('“%s” is not “letter = colour”'):format(vim.trim(entry)))
      is_readable = false
    else
      colours[letter] = name
      if not context.colour_names[name] then
        context.report(
          line,
          ('the colour “%s” is not one of the pack’s colours'):format(name)
        )
      end
    end
  end
  return colours, is_readable
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

--- The columns of a header's `stretch` value, `columns 3-20`.
---
---@param value string
---@return aineo.office_pack.Stretch|nil stretch
local function read_stretch(value)
  local first, last = value:match('^columns%s+(%d+)%s*%-%s*(%d+)$')
  if not first then
    return nil
  end
  return { first = tonumber(first), last = tonumber(last) }
end

--- The rectangle of an `area` header's value, `1, 1, 10 x 4`.
---
---@param value string
---@return aineo.office_pack.Area|nil area
local function read_area(value)
  local column, row, width, height = value:match('^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*x%s*(%d+)$')
  if not column then
    return nil
  end
  return {
    column = tonumber(column),
    row = tonumber(row),
    width = tonumber(width),
    height = tonumber(height),
  }
end

---@class aineo.office_pack.ArtHeader
---@field about? string
---@field colours? table<string, string>
---@field colours_are_readable? boolean whether the colours header could be read, false when an entry of it is not “letter = colour”
---@field anchor? aineo.office_pack.Anchor
---@field anchor_line? integer
---@field faces? string
---@field stretch? aineo.office_pack.Stretch
---@field stretch_line? integer
---@field areas table<string, aineo.office_pack.Area>
---@field area_lines table<string, integer>
---@field seconds_per_frame? number

--- Reads one header line `key: value` into `header`.
---
---@param header aineo.office_pack.ArtHeader
---@param key string
---@param value string
---@param line integer
---@param context aineo.office_pack.ArtContext
local function read_field(header, key, value, line, context)
  local report = context.report
  if key == 'about' then
    header.about = value
  elseif key == 'colours' then
    header.colours, header.colours_are_readable = read_colours(value, line, context)
  elseif key == 'anchor' then
    header.anchor, header.anchor_line = read_anchor(value), line
    if not header.anchor then
      report(line, 'the anchor is “column, row”, two whole numbers')
    end
  elseif key == 'faces' then
    header.faces = value
    if value ~= 'left' and value ~= 'right' then
      report(line, 'faces is left or right')
    end
  elseif key == 'stretch' then
    header.stretch, header.stretch_line = read_stretch(value), line
    if not header.stretch then
      report(line, 'stretch is “columns first-last”')
    end
  elseif key == 'seconds per frame' then
    header.seconds_per_frame = tonumber(value)
    if not header.seconds_per_frame or header.seconds_per_frame <= 0 then
      report(line, 'seconds per frame is a number above 0')
    end
  elseif key:match('^area%s+%S+$') then
    local name = key:match('^area%s+(%S+)$')
    local area = read_area(value)
    if not vim.list_contains(AREA_NAMES, name) then
      report(line, ('“%s” is not an area aineo draws into'):format(name))
    elseif not area then
      report(line, 'an area is “column, row, width x height”')
    else
      header.areas[name], header.area_lines[name] = area, line
    end
  else
    report(line, ('“%s” is not a header field aineo knows'):format(key))
  end
end

--- Reads the header lines, `lines[1]` to `lines[last]`, whose file lines are
--- their positions, into a header.
---
---@param lines string[]
---@param last integer
---@param context aineo.office_pack.ArtContext
---@return aineo.office_pack.ArtHeader
local function read_header(lines, last, context)
  local header = { areas = {}, area_lines = {} }
  for line = 1, last do
    local text = lines[line]
    if text:match('%S') then
      local key, value = text:match('^%s*([%a ]-)%s*:%s*(.-)%s*$')
      if key then
        read_field(header, key, value, line, context)
      else
        context.report(line, ('“%s” is not “field: value”'):format(vim.trim(text)))
      end
    end
  end
  return header
end

---@class aineo.office_pack.ArtFrames
---@field frames string[][] each frame's rows
---@field row_lines integer[][] the file line of each row of each frame

--- The frames of the lines after the header: each run of rows between
--- separator lines, a run without rows left out.
---
---@param lines string[]
---@param first integer the file line of the first line after the header's `---`
---@return aineo.office_pack.ArtFrames
local function read_frames(lines, first)
  local frames, row_lines = {}, {}
  local rows, rows_at = {}, {}
  local function end_frame()
    if #rows > 0 then
      table.insert(frames, rows)
      table.insert(row_lines, rows_at)
    end
    rows, rows_at = {}, {}
  end
  for line = first, #lines do
    local text = lines[line]
    if text == FRAME_SEPARATOR then
      end_frame()
    elseif text ~= '' then
      table.insert(rows, text)
      table.insert(rows_at, line)
    end
  end
  end_frame()
  return { frames = frames, row_lines = row_lines }
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

--- Tells the rows of one width that are of another, and the letters the
--- header does not name, each letter once. With no `colours`, the header
--- could not be read, and the letters are not told.
---
---@param read aineo.office_pack.ArtFrames
---@param colours table<string, string>|nil
---@param report aineo.office_pack.Report
local function check_rows(read, colours, report)
  local first_width = #read.frames[1][1]
  local told = {}
  for frame_index, rows in ipairs(read.frames) do
    for row_index, row in ipairs(rows) do
      local line = read.row_lines[frame_index][row_index]
      if #row ~= first_width then
        report(
          line,
          ('this row is %d pixels wide, and the first row is %d'):format(#row, first_width)
        )
      end
      for letter in row:gmatch('.') do
        if colours and letter ~= '.' and not colours[letter] and not told[letter] then
          told[letter] = true
          report(line, ('the letter “%s” is not named in the colours header'):format(letter))
        end
      end
    end
  end
end

--- Tells the size of the art when it is over what the reader takes.
---
---@param read aineo.office_pack.ArtFrames
---@param width integer
---@param height integer
---@param report aineo.office_pack.Report
local function check_size(read, width, height, report)
  local first_row_line = read.row_lines[1][1]
  if width > MAX_WIDTH then
    report(first_row_line, ('the art is wider than %d pixels'):format(MAX_WIDTH))
  end
  if height > MAX_HEIGHT then
    report(first_row_line, ('the art is taller than %d pixels'):format(MAX_HEIGHT))
  end
  if #read.frames > MAX_FRAMES then
    report(first_row_line, ('the art has more than %d frames'):format(MAX_FRAMES))
  end
end

--- Tells the anchor, the stretched columns and the areas of `header` that lie
--- outside art of `width` by `height` pixels.
---
---@param header aineo.office_pack.ArtHeader
---@param width integer
---@param height integer
---@param report aineo.office_pack.Report
local function check_header_against_size(header, width, height, report)
  local anchor = header.anchor
  if anchor and (anchor.column >= width or anchor.row >= height) then
    report(header.anchor_line, 'the anchor lies outside the art')
  end
  local stretch = header.stretch
  if stretch and (stretch.first < 1 or stretch.last < stretch.first or stretch.last > width) then
    report(header.stretch_line, 'the stretched columns lie outside the art')
  end
  for name, area in pairs(header.areas) do
    if area.column + area.width > width or area.row + area.height > height then
      report(header.area_lines[name], 'the area lies outside the art')
    end
  end
end

--- Reads the art file `text` as the piece `name`, telling every problem of the
--- file to `context.report` with its line.
---
--- `nil` when the file has any problem: no `---` line, a header field that is
--- wrong, rows of another width, a letter the header does not name, art over
--- 400 pixels wide, 200 tall or 64 frames, or no pixels.
---
---@param name string
---@param text string
---@param context aineo.office_pack.ArtContext
---@return aineo.office_pack.Piece|nil piece
function M.parse(name, text, context)
  local told = 0
  local counted = {
    colour_names = context.colour_names,
    report = function(line, message)
      told = told + 1
      context.report(line, message)
    end,
  }
  local lines = lines_of(text)
  local separator = vim.fn.index(lines, FRAME_SEPARATOR) + 1
  if separator == 0 then
    counted.report(1, 'the header is not followed by a line “---”')
    return nil
  end
  local header = read_header(lines, separator - 1, counted)
  local read = read_frames(lines, separator + 1)
  if #read.frames == 0 then
    counted.report(separator, 'the piece has no pixels')
    return nil
  end
  local width, height = measure(read.frames)
  local colours = header.colours or {}
  check_size(read, width, height, counted.report)
  check_rows(read, header.colours_are_readable ~= false and colours or nil, counted.report)
  check_header_against_size(header, width, height, counted.report)
  if told > 0 then
    return nil
  end
  return {
    name = name,
    about = header.about or '',
    colours = colours,
    anchor = header.anchor or { column = 0, row = #read.frames[1] - 1 },
    faces = header.faces or 'right',
    stretch = header.stretch,
    areas = header.areas,
    seconds_per_frame = header.seconds_per_frame or DEFAULT_SECONDS_PER_FRAME,
    frames = read.frames,
    width = width,
    height = height,
  }
end

return M
