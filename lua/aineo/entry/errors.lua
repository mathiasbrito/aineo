--- How aineo's composition root tells the user an error an action raised:
--- once, with one error notification, on one line.

local M = {}

--- What Neovim puts before an error it passes on, outermost first: the
--- words it wraps an error raised in Lua in (`Lua: `), the position of the
--- Lua code that raised it — `<file>.lua:<line>: `, the file's path holding
--- no white space, or for Neovim's own modules `vim/<module>:<line>: ` or
--- `[string "vim/<module>"]:<line>: ` — and the mark of an error a Vim
--- function raised. A file's position is never looked for past a space, so
--- the words of an error before a position they name are kept.
local ERROR_FRAMING = {
  '^Lua: ',
  '^%S-%.lua:%d+: ',
  '^vim/[%w_/]+:%d+: ',
  '^%[string "vim/[^"]*"%]:%d+: ',
  '^Vim:',
}

--- The error `message` tells, on one line: its first line, without the
--- stack traceback that may follow it and without what Neovim put before it
--- (`ERROR_FRAMING`), stripped until none is left at its start — Neovim
--- frames an error again after the position of the Lua that called the API
--- function which raised it. An error whose own words begin with such words
--- loses them too.
---
---@param message string
---@return string
local function error_line(message)
  local line = message:match('^[^\n]*')
  repeat
    local before = line
    for _, framing in ipairs(ERROR_FRAMING) do
      line = line:gsub(framing, '')
    end
  until line == before
  return line
end

--- Tells the user, with one error notification, the error `failure` that an
--- action raised, on one line (`error_line()`), and returns that line.
---
---@param failure any what the action raised
---@return string line
function M.tell_error(failure)
  local line = error_line(tostring(failure))
  vim.notify('aineo: ' .. line, vim.log.levels.ERROR)
  return line
end

--- Runs `action`, and tells the user once, with one error notification, the
--- error it raises (`tell_error()`). Returns whether `action` ran without an
--- error and, when it did not, the line the user was told.
---
---@param action fun()
---@return boolean succeeded
---@return string|nil failure
local function run(action)
  local succeeded, failure = pcall(action)
  if succeeded then
    return true
  end
  return false, M.tell_error(failure)
end

M.run = run

return M
