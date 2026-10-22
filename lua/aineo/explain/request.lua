--- What the explain home hands the Claude Code it starts for one request: the
--- words that start it.

local M = {}

--- The JSON Schema the answer must match: an object holding the list of
--- explanations, each the number of the first line it explains and its text,
--- and nothing else. Written as text so that its keys keep one order.
M.SCHEMA = '{"type":"object","properties":{"explanations":{"type":"array","items":'
  .. '{"type":"object","properties":{"line":{"type":"integer"},"text":{"type":"string"}},'
  .. '"required":["line","text"],"additionalProperties":false}}},'
  .. '"required":["explanations"],"additionalProperties":false}'

--- The read-only tools a request with tools may use, each without asking.
local READ_ONLY_TOOLS = 'Read,Grep,Glob'

--- The words of `command` before its first flag, a word that starts with
--- `-`: the program and the words that wrap it. Every flag of the command,
--- and the words after it, are left out, so that none of them (an MCP
--- configuration, settings, a verbose output) reaches a request.
---
---@param command string[]
---@return string[]
local function program_of(command)
  local program = {}
  for _, word in ipairs(command) do
    if vim.startswith(word, '-') then
      break
    end
    table.insert(program, word)
  end
  return program
end

--- The words that start Claude Code for one request: the program of
--- `command` (`program_of()`) in print mode, answering one JSON result that
--- holds the structured output `SCHEMA` describes, keeping no session, using
--- no MCP server, loading the user's own settings alone, never the
--- project's, and the model `model`; with no tool, or, when `tools` is set,
--- with the read-only tools alone (`READ_ONLY_TOOLS`), each allowed without
--- asking.
---
---@param command string[] the words that run Claude Code, `claude.cmd`
---@param model string
---@param tools boolean
---@return string[]
function M.arguments(command, model, tools)
  local words = vim.list_extend(program_of(command), {
    '-p',
    '--output-format',
    'json',
    '--json-schema',
    M.SCHEMA,
    '--no-session-persistence',
    '--strict-mcp-config',
    '--model',
    model,
    '--setting-sources',
    'user',
    '--tools',
  })
  if tools then
    return vim.list_extend(words, { READ_ONLY_TOOLS, '--allowedTools', READ_ONLY_TOOLS })
  end
  table.insert(words, '')
  return words
end

--- The code a request asks about.
---@class aineo.explain.Code
---@field path string the file's path from the folder Claude Code runs in
---@field language string the buffer's `'filetype'`, empty when it has none
---@field first integer the first line to explain, from 1
---@field last integer the last line to explain
---@field kind 'explanations'|'issues' what to ask for: explanations of the lines, or their potential issues
---@field lines string[] every line of the buffer, as it stands

--- `lines`, each after its number from 1, the numbers aligned to the right.
---
---@param lines string[]
---@return string[]
local function numbered(lines)
  local format = ('%%%dd | %%s'):format(#tostring(#lines))
  local result = {}
  for number, line in ipairs(lines) do
    result[number] = format:format(number, line)
  end
  return result
end

--- What the prompt of each kind of request says, by the kind's name, as
--- `string.format()` patterns: `head` names the file, its language and the
--- first and last line asked for, and `answer` says what to answer for those
--- lines, given the first and last line's numbers.
local ASKS = {
  explanations = {
    head = 'Explain the code of the file %s (language: %s), lines %d to %d as numbered below.',
    answer = 'Write brief explanations of the parts of those lines worth explaining, not one for every line.'
      .. ' Tie each explanation to the first line it explains: its line is that line’s number,'
      .. ' from %d to %d.',
  },
  issues = {
    head = 'Review the code of the file %s (language: %s), lines %d to %d as numbered below,'
      .. ' for potential issues.',
    answer = 'List the potential issues in those lines: bugs, unhandled cases, error handling gaps,'
      .. ' and security or performance risks. Tie each issue to the first line it concerns:'
      .. ' its line is that line’s number, from %d to %d. Be brief, make no style remarks,'
      .. ' and answer an empty list when you find none.'
      .. ' Give each issue as an item of the answer’s list.',
  },
}

--- The prompt Claude Code reads for `code`: the file, its language —
--- `unknown` when the buffer has no `'filetype'` — and the lines to look at,
--- what to answer for them as `code.kind` asks (`ASKS`), then every line of
--- the buffer, numbered (`numbered()`).
---
---@param code aineo.explain.Code
---@return string
function M.prompt(code)
  local asks = ASKS[code.kind]
  return table.concat({
    asks.head:format(
      code.path,
      code.language ~= '' and code.language or 'unknown',
      code.first,
      code.last
    ),
    '',
    asks.answer:format(code.first, code.last),
    '',
    table.concat(numbered(code.lines), '\n'),
  }, '\n')
end

return M
