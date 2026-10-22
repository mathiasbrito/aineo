--- The problems found in a pack: where each is, in plain words, and how it
--- is told — as a line of text, and as an entry of the quickfix list.

local M = {}

---@class aineo.office_pack.Problem
---@field pack string the name of the pack the file belongs to
---@field file string the file's path in the pack's folder, such as `art/door.txt`
---@field path string the file's whole path
---@field line? integer the line of the file the problem is on
---@field message string what is wrong

---@alias aineo.office_pack.Report fun(line: integer|nil, message: string) tells one problem of the file it was made for

---@class aineo.office_pack.Problems
---@field list aineo.office_pack.Problem[] every problem told, in the order they were told
---@field reporter_for fun(pack: string, directory: string, file: string): aineo.office_pack.Report

--- A list of problems, with the means to tell one for a file of a pack.
---
---@return aineo.office_pack.Problems
function M.new_problems()
  local list = {}
  return {
    list = list,
    reporter_for = function(pack, directory, file)
      return function(line, message)
        table.insert(list, {
          pack = pack,
          file = file,
          path = vim.fs.joinpath(directory, file),
          line = line,
          message = message,
        })
      end
    end,
  }
end

--- `problem` as one line: `<pack>/<file>:<line>: <message>`, without the line
--- when the problem names none.
---
---@param problem aineo.office_pack.Problem
---@return string
function M.describe(problem)
  local place = ('%s/%s'):format(problem.pack, problem.file)
  if problem.line then
    place = ('%s:%d'):format(place, problem.line)
  end
  return ('%s: %s'):format(place, problem.message)
end

--- `problems` as entries of a quickfix list (`:h setqflist()`), each with the
--- file's whole path, its line and what is wrong.
---
---@param problems aineo.office_pack.Problem[]
---@return table[] items
function M.quickfix_items(problems)
  return vim.tbl_map(function(problem)
    return { filename = problem.path, lnum = problem.line or 0, text = problem.message }
  end, problems)
end

return M
