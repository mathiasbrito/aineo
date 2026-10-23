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

--- `problems` grouped by file, the files in the order they first have a
--- problem, each file's problems by line (those that name none first) and,
--- on one line, in the order they were told.
---
---@param problems aineo.office_pack.Problem[]
---@return aineo.office_pack.Problem[]
function M.ordered(problems)
  local file_order, ranks = {}, {}
  for index, problem in ipairs(problems) do
    local file = problem.pack .. '/' .. problem.file
    file_order[file] = file_order[file] or index
    ranks[problem] = index
  end
  local ordered = vim.list_slice(problems)
  table.sort(ordered, function(first, second)
    local first_file = file_order[first.pack .. '/' .. first.file]
    local second_file = file_order[second.pack .. '/' .. second.file]
    if first_file ~= second_file then
      return first_file < second_file
    end
    if (first.line or 0) ~= (second.line or 0) then
      return (first.line or 0) < (second.line or 0)
    end
    return ranks[first] < ranks[second]
  end)
  return ordered
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

--- What to tell the user, in one message, of the problems of the pack `name`:
--- how many there are, the first problem of each file that has one — at most
--- `most` files — and the command that lists them all.
---
---@param problems aineo.office_pack.Problem[]
---@param name string
---@param most integer
---@return string
function M.warning_of(problems, name, most)
  local lines, files_told = {}, {}
  for _, problem in ipairs(M.ordered(problems)) do
    local file = problem.pack .. '/' .. problem.file
    if not files_told[file] then
      files_told[file] = true
      table.insert(lines, M.describe(problem))
    end
  end
  local listed = vim.list_slice(lines, 1, most)
  if #lines > most then
    table.insert(listed, ('and the problems of %d more files'):format(#lines - most))
  end
  local counted = #problems == 1 and '1 problem' or ('%d problems'):format(#problems)
  local head = ('aineo: the office pack “%s” has %s; :Aineo office check %s lists them'):format(
    name,
    counted,
    name
  )
  return head .. '\n' .. table.concat(listed, '\n')
end

--- `problems` as entries of a quickfix list (`:h setqflist()`), each with the
--- file's whole path, its line and what is wrong.
---
---@param problems aineo.office_pack.Problem[]
---@return table[] items
function M.quickfix_items(problems)
  return vim.tbl_map(function(problem)
    local text = problem.message:gsub('%z', '^@')
    return { filename = problem.path, lnum = problem.line or 0, text = text }
  end, problems)
end

return M
