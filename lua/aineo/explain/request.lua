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

--- The JSON Schema the answer of a fix must match: an object holding a
--- summary of the whole fix and its list of edits, each the first and last
--- line it replaces, the old lines and the new, and why, and nothing else.
--- Written as text so that its keys keep one order.
M.FIX_SCHEMA = '{"type":"object","properties":{"summary":{"type":"string"},'
  .. '"edits":{"type":"array","items":{"type":"object","properties":{'
  .. '"line":{"type":"integer"},"last":{"type":"integer"},'
  .. '"old":{"type":"array","items":{"type":"string"}},'
  .. '"new":{"type":"array","items":{"type":"string"}},'
  .. '"why":{"type":"string"}},'
  .. '"required":["line","last","old","new","why"],"additionalProperties":false}}},'
  .. '"required":["summary","edits"],"additionalProperties":false}'

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

--- How Claude Code is run for one request.
---@class aineo.explain.Options
---@field model string
---@field tools boolean whether it may read the project with read-only tools
---@field effort? string the effort it works at, as `--effort` takes it; its own default when absent
---@field schema? string the JSON Schema its answer matches; `SCHEMA`, the explanations', when absent

--- The words that start Claude Code for one request: the program of
--- `command` (`program_of()`) in print mode, answering one JSON result that
--- holds the structured output `options.schema` describes, else `SCHEMA`,
--- keeping no session, using no MCP server, loading the user's own settings
--- alone, never the project's, and the model `options.model`; with no tool,
--- or, when
--- `options.tools` is set, with the read-only tools alone (`READ_ONLY_TOOLS`),
--- each allowed without asking; at `options.effort` when it is set.
---
---@param command string[] the words that run Claude Code, `claude.cmd`
---@param options aineo.explain.Options
---@return string[]
function M.arguments(command, options)
  local words = vim.list_extend(program_of(command), {
    '-p',
    '--output-format',
    'json',
    '--json-schema',
    options.schema or M.SCHEMA,
    '--no-session-persistence',
    '--strict-mcp-config',
    '--model',
    options.model,
    '--setting-sources',
    'user',
    '--tools',
  })
  if options.tools then
    vim.list_extend(words, { READ_ONLY_TOOLS, '--allowedTools', READ_ONLY_TOOLS })
  else
    table.insert(words, '')
  end
  if options.effort then
    vim.list_extend(words, { '--effort', options.effort })
  end
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
---@field steer? string the text of a deep request, as the user edited it

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

--- `pattern`, a head from `ASKS` or `DEEP_DEFAULT_STEERS`, with the file of
--- `code`, its language — `unknown` when the buffer has no `'filetype'` —
--- and the first and last line asked for put in.
---
---@param pattern string
---@param code aineo.explain.Code
---@return string
local function head_of(pattern, code)
  return pattern:format(
    code.path,
    code.language ~= '' and code.language or 'unknown',
    code.first,
    code.last
  )
end

--- The rule that ties each item of an answer to the first line it concerns,
--- by the kind's name, as `string.format()` patterns given the first and last
--- line's numbers.
local TIES = {
  explanations = 'Tie each explanation to the first line it explains: its line is that line’s number,'
    .. ' from %d to %d.',
  issues = 'Tie each issue to the first line it concerns: its line is that line’s number,'
    .. ' from %d to %d.',
}

--- What a deep prompt says first of the code asked about, as a `string.format()`
--- pattern given the file and the first and last line's numbers.
local CODE_ASKED_ABOUT = 'The code asked about is the file %s, lines %d to %d. '

--- What tells Claude Code to give each issue as an item of the answer's list.
local ISSUES_AS_ITEMS = 'Give each issue as an item of the answer’s list.'

--- What the prompt of each kind of request says, by the kind's name, as
--- `string.format()` patterns: `head` names the file, its language and the
--- first and last line asked for, and `answer` says what to answer for those
--- lines, given the first and last line's numbers.
local ASKS = {
  explanations = {
    head = 'Explain the code of the file %s (language: %s), lines %d to %d as numbered below.',
    answer = 'Write brief explanations of the parts of those lines worth explaining, not one for every line. '
      .. TIES.explanations,
  },
  issues = {
    head = 'Review the code of the file %s (language: %s), lines %d to %d as numbered below,'
      .. ' for potential issues.',
    answer = 'List the potential issues in those lines: bugs, unhandled cases, error handling gaps,'
      .. ' and security or performance risks. '
      .. TIES.issues
      .. ' Be brief, make no style remarks, and answer an empty list when you find none. '
      .. ISSUES_AS_ITEMS,
  },
}

--- What a deep prompt always says after the text the user edited, by the
--- kind's name, as `string.format()` patterns given the file, the first and
--- last line, and those two again: which code is asked about, whatever the
--- text above says, then the tie to the first line (`TIES`) and, for issues,
--- the items of the list.
local DEEP_FIXED_RULES = {
  explanations = CODE_ASKED_ABOUT .. TIES.explanations,
  issues = CODE_ASKED_ABOUT .. TIES.issues .. ' ' .. ISSUES_AS_ITEMS,
}

--- The text of a deep prompt that the user edits, by the kind's name, as
--- `string.format()` patterns: the head of `ASKS` and a line that says what
--- to answer, given the file, its language and the first and last line's
--- numbers.
local DEEP_DEFAULT_STEERS = {
  explanations = {
    head = 'Explain the code of the file %s (language: %s), lines %d to %d as numbered below,'
      .. ' thoroughly.',
    answer = 'Explain what the code does and why, the call paths and data flow it takes part in,'
      .. ' found by reading the project with the tools, and what is non-obvious.',
  },
  issues = {
    head = ASKS.issues.head,
    answer = 'For each potential issue, say why it holds, how it would show up, and the evidence'
      .. ' in the project, found by reading it with the tools. Make no style remarks,'
      .. ' and answer an empty list when you find none.',
  },
}

--- The text a deep prompt starts with before the user edits it: the file,
--- its language — `unknown` when the buffer has no `'filetype'` — and the
--- lines to look at, then what to answer for them, as `code.kind` asks.
---
---@param code aineo.explain.Code
---@return string
function M.default_steer(code)
  local steer = DEEP_DEFAULT_STEERS[code.kind]
  return table.concat({ head_of(steer.head, code), steer.answer }, '\n')
end

--- The prompt Claude Code reads for `code`. With no `code.steer`: the file,
--- its language — `unknown` when the buffer has no `'filetype'` — and the
--- lines to look at, what to answer for them as `code.kind` asks (`ASKS`),
--- then every line of the buffer, numbered (`numbered()`). With `code.steer`,
--- a deep request's: that text as the user edited it, what a deep prompt
--- always says (`DEEP_FIXED_RULES`), then the numbered lines.
---
---@param code aineo.explain.Code
---@return string
function M.prompt(code)
  if code.steer then
    return table.concat({
      code.steer,
      '',
      DEEP_FIXED_RULES[code.kind]:format(code.path, code.first, code.last, code.first, code.last),
      '',
      table.concat(numbered(code.lines), '\n'),
    }, '\n')
  end
  local asks = ASKS[code.kind]
  return table.concat({
    head_of(asks.head, code),
    '',
    asks.answer:format(code.first, code.last),
    '',
    table.concat(numbered(code.lines), '\n'),
  }, '\n')
end

--- The code a fix is asked for.
---@class aineo.explain.FixCode
---@field path string the file's path from the folder Claude Code runs in
---@field language string the buffer's `'filetype'`, empty when it has none
---@field issue_line integer the line the issue is shown above, from 1
---@field issue string the issue's text
---@field lines string[] every line of the buffer, as it stands
---@field steer? string the text the prompt starts with, as the user edited it

--- The text a fix's prompt starts with before the user edits it, as a
--- `string.format()` pattern given the issue's line, the file and its
--- language: its first line names them, the second asks for the change.
local FIX_DEFAULT_STEER = 'Propose a fix for the issue at line %d of the file %s (language: %s),'
  .. ' as numbered below.'
  .. '\nMake the smallest change that fixes it, reading the project with the tools where it helps.'

--- What a fix's prompt always says after the text the user may edit, as a
--- `string.format()` pattern given the issue's line, the file and the
--- issue's text: which issue to fix, whatever the text above says, then how
--- to answer, which `aineo.explain.placement` holds the answer to.
local FIX_RULES = 'The issue to fix is at line %d of the file %s: %s'
  .. '\n\n'
  .. 'Answer in summary the whole fix in one sentence, and the edits that make it.'
  .. ' Fix only this file.'
  .. ' Each edit gives in line and last the first and last line it replaces, and repeats in old'
  .. ' exactly those lines of the numbered text below, verbatim with their indentation and'
  .. ' without their numbers; new holds the lines that replace them, and why says what the'
  .. ' change does and why it fixes the issue.'
  .. ' Each edit has at least one old line: to insert lines, replace an anchor line with itself'
  .. ' and the new lines.'
  .. ' Edits do not overlap.'
  .. ' Make the smallest change that fixes the issue.'
  .. ' When no fix is needed or possible, answer no edits and say why in the summary.'

--- The text a fix's prompt starts with before the user edits it: the issue's
--- line, the file and its language — `unknown` when the buffer has no
--- `'filetype'` — then what to change.
---
---@param fix aineo.explain.FixCode
---@return string
function M.default_fix_steer(fix)
  return FIX_DEFAULT_STEER:format(
    fix.issue_line,
    fix.path,
    fix.language ~= '' and fix.language or 'unknown'
  )
end

--- The prompt Claude Code reads for `fix`: `fix.steer`, else the default text
--- (`default_fix_steer()`), then what a fix's prompt always says
--- (`FIX_RULES`), then every line of the buffer, numbered (`numbered()`).
---
---@param fix aineo.explain.FixCode
---@return string
function M.fix_prompt(fix)
  return table.concat({
    fix.steer or M.default_fix_steer(fix),
    '',
    FIX_RULES:format(fix.issue_line, fix.path, fix.issue),
    '',
    table.concat(numbered(fix.lines), '\n'),
  }, '\n')
end

return M
