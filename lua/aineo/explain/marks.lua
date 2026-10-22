--- How the explain home shows explanations: as virtual lines above the lines
--- they explain, in the namespace `aineo_explain`.

local M = {}

local NAMESPACE = vim.api.nvim_create_namespace('aineo_explain')

--- The highlight group of every virtual line the explain home shows.
local HIGHLIGHT = 'AineoExplain'

--- What starts the text of every virtual line, after the line's indent.
local MARK = '┊ '

--- The fewest columns a virtual line's text is wrapped at, however narrow
--- the window.
local NARROWEST = 1

--- The bytes of the longest start of `word` no wider than `width` display
--- columns, and at least its first character. Walks the characters of that
--- start alone, so that a long word costs its length, not its length per row.
---
---@param word string
---@param width integer
---@return integer
local function fitting_bytes(word, width)
  local bytes, used = 0, 0
  while bytes < #word do
    local character = word:sub(bytes + 1, bytes + 1 + vim.str_utf_end(word, bytes + 1))
    local wide = vim.fn.strdisplaywidth(character)
    if used + wide > width and bytes > 0 then
      break
    end
    bytes = bytes + #character
    used = used + wide
  end
  return bytes
end

--- `text` broken into rows no wider than `width` display columns: between
--- words, a word wider than `width` cut into rows of its own, and a new row
--- at each line break.
---
---@param text string
---@param width integer
---@return string[]
local function wrapped(text, width)
  local rows = {}
  for _, paragraph in ipairs(vim.split(text, '\n', { plain = true })) do
    local row = ''
    for word in paragraph:gmatch('%S+') do
      while vim.fn.strdisplaywidth(word) > width do
        if row ~= '' then
          table.insert(rows, row)
          row = ''
        end
        local cut = fitting_bytes(word, width)
        table.insert(rows, word:sub(1, cut))
        word = word:sub(cut + 1)
      end
      local longer = row == '' and word or row .. ' ' .. word
      if vim.fn.strdisplaywidth(longer) <= width then
        row = longer
      else
        table.insert(rows, row)
        row = word
      end
    end
    table.insert(rows, row)
  end
  return rows
end

--- The columns a window showing `buffer` shows text in, without its
--- number, sign and fold columns: `window`'s when it still shows `buffer`,
--- else the first such window's, else the screen's when none shows it.
---
---@param buffer integer
---@param window integer
---@return integer
local function text_width(buffer, window)
  if not (vim.api.nvim_win_is_valid(window) and vim.api.nvim_win_get_buf(window) == buffer) then
    window = vim.fn.bufwinid(buffer)
  end
  local info = vim.fn.getwininfo(window)[1]
  if not info then
    return vim.o.columns
  end
  return info.width - info.textoff
end

--- The indent of `line` of `buffer`, from 1, as the spaces that fill it, at
--- most `most` of them.
---
---@param buffer integer
---@param line integer
---@param most? integer no limit when absent
---@return string
local function indent_of(buffer, line, most)
  local indent = vim.api.nvim_buf_call(buffer, function()
    return vim.fn.indent(line)
  end)
  return (' '):rep(math.min(indent, most or indent))
end

--- Shows `rows` in `buffer` as virtual lines above `line`, from 1, each after
--- `prefix`, in `HIGHLIGHT`. Returns the extmark's id.
---
---@param buffer integer
---@param line integer
---@param prefix string
---@param rows string[]
---@return integer
local function show_above(buffer, line, prefix, rows)
  vim.api.nvim_set_hl(0, HIGHLIGHT, { link = 'Comment', default = true })
  return vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, line - 1, 0, {
    virt_lines = vim.tbl_map(function(row)
      return { { prefix .. row, HIGHLIGHT } }
    end, rows),
    virt_lines_above = true,
    invalidate = true,
    undo_restore = false,
  })
end

--- Shows each of `explanations` in `buffer` as virtual lines above its
--- line, indented as that line but by half the window's text width at most,
--- each starting with `MARK`, and the text wrapped (`wrapped()`) at the text
--- width of a window showing it (`text_width()`) less that indent.
---
---@param buffer integer
---@param window integer the window the explanations were asked in
---@param explanations aineo.explain.Explanation[]
function M.place(buffer, window, explanations)
  local width = text_width(buffer, window)
  for _, explanation in ipairs(explanations) do
    local prefix = indent_of(buffer, explanation.line, math.floor(width / 2)) .. MARK
    local room = math.max(width - vim.fn.strdisplaywidth(prefix), NARROWEST)
    show_above(buffer, explanation.line, prefix, wrapped(explanation.text, room))
  end
end

--- Shows in `buffer`, above `line`, from 1, and indented as it, the virtual
--- line that says a request is explaining. Returns its id, for `remove()`.
---
---@param buffer integer
---@param line integer
---@return integer
function M.show_explaining(buffer, line)
  return show_above(buffer, line, indent_of(buffer, line) .. MARK, { 'explaining…' })
end

--- Whether `buffer` shows any virtual line of the explain home.
---
---@param buffer integer
---@return boolean
function M.is_showing(buffer)
  return #vim.api.nvim_buf_get_extmarks(buffer, NAMESPACE, 0, -1, { limit = 1 }) > 0
end

--- Removes every virtual line of the explain home from `buffer`, or those
--- above the lines from `first` to `last`, from 1, when they are given.
---
---@param buffer integer
---@param first? integer
---@param last? integer
function M.clear(buffer, first, last)
  vim.api.nvim_buf_clear_namespace(buffer, NAMESPACE, first and first - 1 or 0, last or -1)
end

--- Removes the virtual lines of the extmark `id` from `buffer`, unless the
--- buffer is gone.
---
---@param buffer integer
---@param id integer
function M.remove(buffer, id)
  if vim.api.nvim_buf_is_valid(buffer) then
    vim.api.nvim_buf_del_extmark(buffer, NAMESPACE, id)
  end
end

return M
