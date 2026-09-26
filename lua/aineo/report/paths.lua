--- The file paths in a line of the Report: where each could start and end,
--- the file it names, and the line it names in that file. Finding them takes
--- time that grows with the length of the line, not with its square: a report
--- can be as long as a line the relay takes. Whether a path names a file that
--- exists is not decided here.

local M = {}

--- A run of the characters a path may hold: none of an ASCII space, an ASCII
--- control character (U+0000–U+001F, U+007F), `<`, `>`, `"`, `'`, `|`, a
--- backtick, `(`, `)`, `[`, `]`, `{`, `}`, `,` or `*`. Spelled out byte by
--- byte, since `%s` and `%c` follow the C locale's classes, which may not be
--- ASCII's.
local RUN = '[^%z\1-\32\127<>"\'|`()%[%]{},*]+'

--- The characters a path never ends in: punctuation that closes the sentence
--- around it. A `~` is kept: `foo.lua~` is a file's name.
local TRAILING_PUNCTUATION =
  { ['.'] = true, [':'] = true, [';'] = true, ['!'] = true, ['?'] = true }

--- The last byte of the run from `first` to `last` of `text` once the
--- punctuation it ends in (`TRAILING_PUNCTUATION`) is left out, one character
--- after another; `first - 1` when nothing is left.
---
---@param text string
---@param first integer
---@param last integer
---@return integer
local function without_trailing_punctuation(text, first, last)
  while last >= first and TRAILING_PUNCTUATION[text:sub(last, last)] do
    last = last - 1
  end
  return last
end

---@class aineo.report.PathCandidate
---@field first_column integer the byte it starts at, from 0
---@field end_column integer the byte it ends before, from 0
---@field path string the file it names, as written
---@field line integer? the line it names in that file, from 1, when it names one

--- `candidate` apart from the `:<line>` or `:<line>:<column>` at its end: the
--- path, and the line when there is one.
---
---@param candidate string
---@return string path
---@return integer? line
local function without_line(candidate)
  local path, line = candidate:match('^(.-):(%d+):%d+$')
  if not path then
    path, line = candidate:match('^(.-):(%d+)$')
  end
  if not path then
    return candidate
  end
  return path, tonumber(line)
end

--- Whether `path` looks like a path to a file: it holds a `/`, or a `.` that
--- is neither its first nor its last character. `README.md` and
--- `.luarc.json` do; `Makefile` and `.gitignore` do not.
---
---@param path string
---@return boolean
local function looks_like_path(path)
  local first_inner_dot = path:find('.', 2, true)
  return path:find('/', 1, true) ~= nil or (first_inner_dot ~= nil and first_inner_dot < #path)
end

--- Every text in `text` that could name a file, in order: a run of the
--- characters a path may hold (`RUN`), less the punctuation it ends in
--- (`without_trailing_punctuation()`), that looks like a path
--- (`looks_like_path()`) once the `:<line>` or `:<line>:<column>` at its end
--- is set apart (`without_line()`). The candidate spans the whole of that,
--- its line included, and names the line when it has one. Candidates never
--- overlap. The text of a candidate, searched on its own, is found whole
--- again, as the same candidate.
---
---@param text string one line of text
---@return aineo.report.PathCandidate[]
function M.find_path_candidates(text)
  local candidates = {}
  local position = 1
  while true do
    local first, run_last = text:find(RUN, position)
    if not first then
      return candidates
    end
    local last = without_trailing_punctuation(text, first, run_last)
    local path, line = without_line(text:sub(first, last))
    if looks_like_path(path) then
      table.insert(
        candidates,
        { first_column = first - 1, end_column = last, path = path, line = line }
      )
    end
    position = run_last + 1
  end
end

return M
