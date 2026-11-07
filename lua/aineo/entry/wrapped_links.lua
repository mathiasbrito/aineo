--- The links Claude Code wrapped across rows of its terminal. A terminal
--- buffer holds one line per screen row, so a path that did not fit a row
--- lies on several, and `aineo.report`'s `find_path_candidates()`, which reads
--- one line, finds only a piece of it. A link that ends its row
--- (nothing follows it but the punctuation links leave out) continues with
--- the first run of non-blank characters of the next row, which Claude Code
--- may have indented.
--- Whether a join names a file is for the caller to decide.

local M = {}

--- The rows a joined link spans at most.
local MAX_ROWS = 4

---@class aineo.entry.WrappedLink
---@field path string the file it names, as written
---@field line integer? the line it names in that file, from 1, when it names one
---@field length integer how many bytes of text it joins
---@field parts aineo.entry.WrappedLinkPart[] where it lies, row by row

---@class aineo.entry.WrappedLinkPart
---@field row integer the row, from 0
---@field first_column integer the byte it starts at, from 0
---@field end_column integer the byte it ends before, from 0

--- `text` without the blank characters at its end.
---
---@param text string
---@return string
local function without_trailing_blanks(text)
  return (text:gsub('%s+$', ''))
end

--- Whether nothing but the punctuation a link leaves out
--- (`aineo.report`'s `find_path_candidates()`: a dot, a colon, a semicolon, an
--- exclamation mark or a question mark) follows byte `end_column`, from 0, of
--- `text`.
---
---@param text string
---@param end_column integer
---@return boolean
local function leaves_only_punctuation(text, end_column)
  return text:sub(end_column + 1):match('^[.:;!?]*$') ~= nil
end

--- The link of the row `text` that ends the row: no non-blank character
--- follows it but the punctuation a link leaves out, which a path broken
--- after its dot or its colon has at its end. Or nil.
---
---@param text string
---@return aineo.report.PathCandidate?
local function link_ending_the_row(text)
  local row = without_trailing_blanks(text)
  return vim.iter(require('aineo.report').find_path_candidates(row)):find(function(candidate)
    return leaves_only_punctuation(row, candidate.end_column)
  end)
end

--- The link that `text` starts with, or nil.
---
---@param text string
---@return aineo.report.PathCandidate?
local function link_starting(text)
  return vim.iter(require('aineo.report').find_path_candidates(text)):find(function(candidate)
    return candidate.first_column == 0
  end)
end

--- The joins that start with the link ending row `first_row`, each one row
--- longer than the one before, shortest first. A join goes on to the next row
--- when the run it took there is that row's last, and the link took it whole
--- but for the punctuation it leaves out.
---
---@param row_text fun(row: integer): string
---@param first_row integer
---@return aineo.entry.WrappedLink[]
local function joins_starting_at(row_text, first_row)
  local text = row_text(first_row)
  local head = link_ending_the_row(text)
  if not head then
    return {}
  end
  local row_end = #without_trailing_blanks(text)
  local written = text:sub(head.first_column + 1, row_end)
  local parts = { { row = first_row, first_column = head.first_column, end_column = row_end } }
  local joins = {}
  for row = first_row + 1, first_row + MAX_ROWS - 1 do
    local below = row_text(row)
    local run_first, run_last = below:find('%S+')
    if not run_first then
      break
    end
    local joined = written .. below:sub(run_first, run_last)
    local link = link_starting(joined)
    if not link or link.end_column <= #written then
      break
    end
    parts = vim.list_extend(vim.deepcopy(parts), {
      {
        row = row,
        first_column = run_first - 1,
        end_column = run_first - 1 + link.end_column - #written,
      },
    })
    table.insert(
      joins,
      { path = link.path, line = link.line, length = link.end_column, parts = parts }
    )
    if
      not leaves_only_punctuation(joined, link.end_column)
      or run_last < #without_trailing_blanks(below)
    then
      break
    end
    written = joined
  end
  return joins
end

--- Whether the join `link` covers byte `byte`, from 0, of row `row`, from 0.
---
---@param link aineo.entry.WrappedLink
---@param row integer
---@param byte integer
---@return boolean
local function covers(link, row, byte)
  return vim.iter(link.parts):any(function(part)
    return part.row == row and part.first_column <= byte and byte < part.end_column
  end)
end

--- The links joined across rows that cover byte `byte`, from 0, of row `row`,
--- from 0, longest first. `row_text` gives the text of a row, and an empty
--- one for a row the buffer does not have.
---
---@param row_text fun(row: integer): string
---@param row integer
---@param byte integer
---@return aineo.entry.WrappedLink[]
function M.covering(row_text, row, byte)
  local covering = {}
  for first_row = math.max(row - (MAX_ROWS - 1), 0), row do
    for _, link in ipairs(joins_starting_at(row_text, first_row)) do
      if covers(link, row, byte) then
        table.insert(covering, link)
      end
    end
  end
  table.sort(covering, function(a, b)
    return a.length > b.length
  end)
  return covering
end

return M
