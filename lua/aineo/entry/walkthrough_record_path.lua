--- Where the record of a walkthrough is written: the PDF the user asks their
--- agent for with `\Vq` (`aineo.entry.walkthrough_record`), in the record
--- folder, named for the day and for the walkthrough, and not named as a
--- record written before is.

local M = {}

--- How many words of a title its slug keeps at most.
local MOST_WORDS = 6

--- How many characters a slug keeps at most.
local LONGEST_SLUG = 60

--- The slug of a walkthrough that has no title to name it by.
local UNTITLED = 'walkthrough'

--- The words that end a record's file names: the PDF the agent is asked for,
--- and the HTML it is made from, next to it.
local EXTENSIONS = { 'pdf', 'html' }

--- The slug a walkthrough's file names carry: the first words of its title,
--- lowercase, of ASCII letters and digits, joined by dashes, so that nothing
--- in a title reaches another folder or breaks a file name. `walkthrough`
--- when the title has no such word, or there is no title.
---
---@param title string|false|nil
---@return string
function M.slug_of(title)
  local words = {}
  for word in (title or ''):lower():gmatch('[a-z0-9]+') do
    table.insert(words, word)
    if #words == MOST_WORDS then
      break
    end
  end
  local slug = table.concat(words, '-'):sub(1, LONGEST_SLUG):gsub('%-+$', '')
  return slug ~= '' and slug or UNTITLED
end

--- What is needed to name a record.
---@class aineo.entry.WalkthroughRecordRequest
---@field folder string the folder the tab's Claude Code works in
---@field record_folder string `walkthrough.record_folder`: under `folder` when relative, `~` and variables expanded when absolute
---@field date string the day, as `YYYY-MM-DD`
---@field title string|false|nil the title of the walkthrough's plan, `false` or nil when the tab has none
---@field is_taken fun(path: string): boolean whether a file is there

--- Whether a record of that name was written: its PDF or its HTML is there.
---
---@param without_extension string
---@param is_taken fun(path: string): boolean
---@return boolean
local function is_written(without_extension, is_taken)
  for _, extension in ipairs(EXTENSIONS) do
    if is_taken(without_extension .. '.' .. extension) then
      return true
    end
  end
  return false
end

--- The path of the HTML a record's PDF is made from: the same name, ending in
--- `.html`.
---
---@param pdf_path string
---@return string
function M.html_beside(pdf_path)
  return (pdf_path:gsub('%.pdf$', '.html'))
end

--- The path of the PDF to ask the agent for: `<record folder>/<date>-<slug>.pdf`,
--- with `-2`, `-3`… after the slug while a record of that name is written
--- already, its PDF or its HTML.
---
---@param request aineo.entry.WalkthroughRecordRequest
---@return string
function M.path_for(request)
  local record_folder = vim.fs.normalize(request.record_folder)
  local folder = vim.startswith(record_folder, '/') and record_folder
    or vim.fs.normalize(vim.fs.joinpath(request.folder, record_folder))
  local name = ('%s-%s'):format(request.date, M.slug_of(request.title))
  local without_extension = vim.fs.joinpath(folder, name)
  local number = 1
  while is_written(without_extension, request.is_taken) do
    number = number + 1
    without_extension = vim.fs.joinpath(folder, ('%s-%d'):format(name, number))
  end
  return without_extension .. '.pdf'
end

return M
