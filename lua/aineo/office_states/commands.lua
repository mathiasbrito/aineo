--- Classing a shell command by what it does: running tests, committing,
--- searching, reading, or none of those. A command is a chain, and the class
--- comes from any of its segments. Pure.

local matching = require('aineo.office_states.matching')

local M = {}

--- The classes in the order they are tried, each with the state of an agent
--- running a command of it: the first class that any segment matches wins.
local CLASSES = {
  { name = 'tests', state = 'running_tests' },
  { name = 'committing', state = 'committing' },
  { name = 'searching', state = 'searching' },
  { name = 'reading', state = 'reading' },
}

--- The state of an agent running a command of no class.
local STATE_OF_UNCLASSED_COMMAND = 'running_a_command'

--- The matches that make a command of each class: `tests`, `committing`,
--- `searching` and `reading`, each a list of rules (`aineo.office_states.Rule`);
--- a class left out has none.
---@alias aineo.office_states.CommandClasses table<string, aineo.office_states.Rule[]>

--- Removes the assignments, such as `DEBUG=1 `, a segment starts with.
---
---@param segment string
---@return string
local function without_leading_assignments(segment)
  local stripped = segment
  repeat
    segment = stripped
    stripped = segment:gsub('^[%a_][%w_]*=%S*%s*', '')
  until stripped == segment
  return stripped
end

--- Whether `segment` only changes the directory.
---
---@param segment string
---@return boolean
local function is_cd(segment)
  return segment == 'cd' or segment:find('^cd%s') ~= nil
end

--- The word that ends the heredoc `line` starts, and whether the end may be
--- indented by tabs (`<<-`); none when the line starts no heredoc. A
--- here-string (`<<<`) and a shift (`1<<3`) start none: a heredoc's word
--- begins with a letter or `_`.
---
---@param line string
---@return string|nil word
---@return boolean|nil strips_tabs
local function heredoc_word(line)
  local without_here_strings = line:gsub('<<<', '')
  local dash, _, word = without_here_strings:match('<<(%-?)%s*(["\']?)([%a_][%w_]*)%2')
  return word, dash == '-'
end

--- `command` without the bodies of its heredocs: what a command is fed is
--- text, not commands. The line that starts a heredoc stays, and so do the
--- lines after its end word; a heredoc that never ends takes the rest. Quoted
--- text stays, since `bash -c "make test"` runs it.
---
---@param command string
---@return string
local function without_heredoc_bodies(command)
  local kept = {}
  local ends_with, strips_tabs
  for _, line in ipairs(vim.split(command, '\n', { plain = true })) do
    if ends_with then
      local candidate = strips_tabs and line:gsub('^\t+', '') or line
      if candidate == ends_with then
        ends_with = nil
      end
    else
      table.insert(kept, line)
      ends_with, strips_tabs = heredoc_word(line)
    end
  end
  return table.concat(kept, '\n')
end

--- The parts of `command` that are commands in their own right, in order:
--- the chain split at `&&`, `||`, `;`, `|` and new lines, without the `cd`
--- segments and the assignments a segment starts with.
---
---@param command string
---@return string[] segments
local function segments_of(command)
  local separated = command:gsub('&&', '\n'):gsub('[|;]', '\n')
  local segments = {}
  for _, part in ipairs(vim.split(separated, '\n', { plain = true })) do
    local segment = without_leading_assignments(vim.trim(part))
    if segment ~= '' and not is_cd(segment) then
      table.insert(segments, segment)
    end
  end
  return segments
end

--- Whether any of `segments` matches any of `rules`.
---
---@param segments string[]
---@param rules aineo.office_states.Rule[]
---@return boolean
local function any_segment_matches(segments, rules)
  return vim.iter(segments):any(function(segment)
    return vim.iter(rules):any(function(rule)
      return matching.matches(rule, segment)
    end)
  end)
end

--- The state of an agent running `command`: the state of the first class, in
--- the order tests, committing, searching, reading, that any segment of the
--- command matches; running a command when none does, or when `command` is no
--- text. The bodies of heredocs are not read, and only the first
--- `matching.LONGEST_TEXT` bytes of the rest.
---
---@param command any the call's `command`
---@param classes aineo.office_states.CommandClasses
---@return string state
function M.state_of_command(command, classes)
  if type(command) ~= 'string' then
    return STATE_OF_UNCLASSED_COMMAND
  end
  local segments = segments_of(matching.shortened(without_heredoc_bodies(command)))
  for _, class in ipairs(CLASSES) do
    if any_segment_matches(segments, classes[class.name] or {}) then
      return class.state
    end
  end
  return STATE_OF_UNCLASSED_COMMAND
end

return M
