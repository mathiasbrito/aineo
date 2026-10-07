--- The name and the folder of a Claude Code session, kept on its terminal
--- buffer for status lines: `b:aineo_session_name` and
--- `b:aineo_session_folder`.

local M = {}

--- The name a session has while Claude Code gives it none.
local UNNAMED = 'Claude Code'

--- The `charclass()` of a word character, and of an emoji, which is not one.
local WORD_CLASS = 2
local EMOJI_CLASS = 3

--- Whether the Latin-1 character numbered `code`, from U+0080 to U+00FF, is
--- a letter: ª, µ, º, and À to ÿ but for × and ÷.
---
---@param code integer
---@return boolean
local function is_latin1_letter(code)
  return code == 0xAA
    or code == 0xB5
    or code == 0xBA
    or (code >= 0xC0 and code ~= 0xD7 and code ~= 0xF7)
end

--- Whether `character`, one character, is a letter or a digit: an ASCII
--- letter or digit, a Latin-1 letter (`is_latin1_letter()`), or a wider
--- character Vim's `charclass()` puts among the word characters or in a
--- script class of its own, as it does a Greek or Cyrillic letter (2) or a
--- CJK one. Emoji (3), punctuation and symbols (1) and blanks (0) are not.
--- No buffer's 'iskeyword' counts: `charclass()` reads it below U+0100
--- only, where it is not asked.
---
---@param character string
---@return boolean
local function is_letter_or_digit(character)
  if #character == 1 then
    return character:find('^%w') ~= nil
  end
  local code = vim.fn.char2nr(character)
  if code < 0x100 then
    return is_latin1_letter(code)
  end
  local class = vim.fn.charclass(character)
  return class == WORD_CLASS or class > EMOJI_CLASS
end

--- `title` without the status glyph Claude Code puts first: its first
--- character, when that is neither a letter nor a digit and a space or
--- nothing follows it, left out with that space, once. Claude Code 2.1.292
--- titles a session `✳ <name>`.
---
---@param title string
---@return string
local function without_status_glyph(title)
  local first = vim.fn.strcharpart(title, 0, 1)
  local rest = title:sub(#first + 1)
  if
    first ~= ''
    and not is_letter_or_digit(first)
    and (rest == '' or vim.startswith(rest, ' '))
  then
    return rest:sub(2)
  end
  return title
end

--- The session's name a terminal title `title` gives: the title without its
--- status glyph (`without_status_glyph()`), or `UNNAMED` when nothing
--- remains, when there is no title, and when the title is still a terminal
--- buffer's own name, `term://…`, which Neovim gives `b:term_title` until
--- the program sets one.
---
---@param title string?
---@return string
local function name_from_title(title)
  if title == nil or vim.startswith(title, 'term://') then
    return UNNAMED
  end
  local name = without_status_glyph(title)
  return name == '' and UNNAMED or name
end

--- Sets `b:aineo_session_name` of `buffer` to the name `title` gives
--- (`name_from_title()`) and, when that changed it, has every status line
--- drawn again, from a scheduled callback: Neovim draws a status line again
--- by itself on a new title, but not on an empty one.
---
---@param buffer integer
---@param title string?
local function keep_name(buffer, title)
  local name = name_from_title(title)
  if vim.b[buffer].aineo_session_name == name then
    return
  end
  vim.b[buffer].aineo_session_name = name
  vim.schedule(function()
    vim.cmd.redrawstatus({ bang = true })
  end)
end

--- Calls `on_title(title)` with each new value of `b:term_title` of
--- `buffer`, `nil` once it is removed — an empty title included, which fires
--- no `TermRequest`. A dictionary watcher sees every change; it is added from
--- Vimscript, which alone can name `buffer`'s own `b:` dictionary, the
--- callback reaching it as a buffer variable that is removed at once.
---
---@param buffer integer
---@param on_title fun(title: string?)
local function watch_title(buffer, on_title)
  vim.api.nvim_buf_call(buffer, function()
    vim.b.aineo_title_watcher = function(_, _, change)
      on_title(change.new)
    end
    vim.cmd([[call dictwatcheradd(b:, 'term_title', b:aineo_title_watcher)]])
    vim.cmd.unlet('b:aineo_title_watcher')
  end)
end

--- `text` as a status line format that draws it character for character:
--- each `%` doubled.
---
---@param text string
---@return string
local function literal(text)
  return (text:gsub('%%', '%%%%'))
end

--- The status line format that draws, for `window`, the name and the folder
--- of the terminal it shows: `<name> — <folder>`, each as written, whatever
--- it holds — a `%`, digits alone, a leading comma or space. A status line
--- too narrow for both cuts the folder first, from its start, and the name
--- only once no folder is left to cut.
---
---@param window integer
---@return string
function M.statusline_format(window)
  local buffer = vim.api.nvim_win_get_buf(window)
  local name = tostring(vim.b[buffer].aineo_session_name or '')
  local folder = tostring(vim.b[buffer].aineo_session_folder or '')
  return literal(name) .. ' — %<' .. literal(folder)
end

--- Gives `buffer`, the terminal of a Claude Code that has exited, the name
--- `Claude Code`, as the empty title Claude Code sets as it exits does: one
--- that was killed or hung up leaves its last title in place. A terminal
--- already wiped, which hung its Claude Code up, is left as it is.
---
---@param buffer integer
function M.forget_name(buffer)
  if vim.api.nvim_buf_is_valid(buffer) then
    keep_name(buffer, nil)
  end
end

--- Keeps the session's name and folder on `buffer`, the terminal Claude Code
--- is about to run in, for its whole life: the name as each title Claude
--- Code sets gives it (`name_from_title()`), `Claude Code` until then, and
--- the folder `directory`, the one Claude Code starts in, written from the
--- home directory (`fnamemodify(…, ':~')`).
---
---@param buffer integer
---@param directory string
function M.keep_name_and_folder(buffer, directory)
  vim.b[buffer].aineo_session_name = UNNAMED
  vim.b[buffer].aineo_session_folder = vim.fn.fnamemodify(directory, ':~')
  watch_title(buffer, function(title)
    keep_name(buffer, title)
  end)
end

return M
