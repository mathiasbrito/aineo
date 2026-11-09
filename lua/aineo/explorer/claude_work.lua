--- The work of the Claude Code session as one explorer follows it from read
--- to read of its tree: the files in it, and the ones whose lines flash
--- because they joined it, or because their change was read anew
--- (`aineo.explorer.claude_marks`).

local claude_marks = require('aineo.explorer.claude_marks')

local M = {}

--- How long a file that joined the work flashes, in milliseconds.
M.FLASH_MS = 1500

--- What an explorer follows of the session's work.
---@class aineo.explorer.ClaudeWork
---@field files fun(): table<string, true> the files in the work, by path from the tree's root
---@field flashing fun(): table<string, true> the files that flash now
---@field take fun(read: aineo.explorer.RepositoryTree, directory: string, known: boolean) takes the work of a read of the folder `directory`, which says whether the work is known

--- Makes the tracker of one explorer; `redraw` is called each time a file
--- stops flashing.
---
---@param redraw fun()
---@return aineo.explorer.ClaudeWork
function M.new(redraw)
  local files = {}
  ---@type table<string, string>|nil
  local signatures = nil
  ---@type string|nil
  local signed_directory = nil
  ---@type table<string, integer>
  local tokens = {}
  local started = 0

  --- Makes the lines of `flashed` flash for `M.FLASH_MS`; a file that
  --- flashes again before it stops flashes for the whole time again.
  ---
  ---@param flashed table<string, true>
  local function flash(flashed)
    if next(flashed) == nil then
      return
    end
    started = started + 1
    local token = started
    for path in pairs(flashed) do
      tokens[path] = token
    end
    vim.defer_fn(function()
      for path in pairs(flashed) do
        if tokens[path] == token then
          tokens[path] = nil
        end
      end
      redraw()
    end, M.FLASH_MS)
  end

  ---@type aineo.explorer.ClaudeWork
  local work = {}

  function work.files()
    return files
  end

  function work.flashing()
    return vim.tbl_map(function()
      return true
    end, tokens)
  end

  --- Takes the work `read` says for the folder `directory`, and makes the
  --- lines of the files that joined it, or whose change is read anew, flash.
  --- Nothing flashes at the first read of a folder, nor at the read after
  --- one that did not know the work (`known` false).
  function work.take(read, directory, known)
    files = read.claude
    if not known then
      signatures, signed_directory = nil, nil
      return
    end
    local current = claude_marks.signatures(read.claude, read.marks, read.line_counts)
    local same_folder = signed_directory == directory
    flash(claude_marks.flashed(same_folder and signatures or nil, current))
    signatures, signed_directory = current, directory
  end

  return work
end

return M
