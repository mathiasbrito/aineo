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

--- The JSON Schema the answer of a list of tests must match: an object
--- holding the list of tests, each its name and what it checks, and
--- nothing else. Written as text so that its keys keep one order.
M.TESTS_SCHEMA = '{"type":"object","properties":{"tests":{"type":"array","items":'
  .. '{"type":"object","properties":{"name":{"type":"string"},"checks":{"type":"string"}},'
  .. '"required":["name","checks"],"additionalProperties":false}}},'
  .. '"required":["tests"],"additionalProperties":false}'

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

--- The code written for a request.
---@class aineo.explain.WriteCode
---@field path string the file's path from the folder Claude Code runs in
---@field language string the buffer's `'filetype'`, empty when it has none
---@field first integer the first line of the request, from 1, or the line the code goes after
---@field last integer the last line of the request, or the line the code goes after
---@field request? string the request the user typed, the code going after the line `first`, or in its place when it is blank; absent when the lines `first` to `last` hold the request, which the code replaces
---@field blank? boolean whether the line `first`, which the code for the request typed goes to, is blank: the code then replaces it
---@field whole_file? boolean whether the code may also edit other places of the file, each a further edit (`WHOLE_FILE_RULES`)
---@field anywhere? boolean whether the code goes wherever it belongs in the file, `request` saying what to write and where (`ANYWHERE_RULES`), with no line asked about
---@field brief? string[] what else Claude Code is shown, each a part of the prompt of its own, before the lines of the file
---@field lines string[] every line of the buffer, as it stands

--- What a prompt for code written in place of the lines that hold its
--- request says first, as a `string.format()` pattern given the file, its
--- language and the first and last line of the request.
local WRITE_IN_PLACE_HEAD = 'Write code in the file %s (language: %s) for the request lines %d to %d hold,'
  .. ' as numbered below: those lines are the request, to be replaced by the code that fulfils it.'

--- What a prompt for code written in place of its request always says
--- after its head, as a `string.format()` pattern given the first and last
--- line of the request and the first again: how to answer, which
--- `aineo.explain.write` holds the answer to.
local WRITE_IN_PLACE_RULES = 'Answer in summary what the code does in one sentence,'
  .. ' and one edit that replaces the request with it.'
  .. ' Write only into this file.'
  .. ' The edit gives in line and last the lines %d and %d, and repeats in old exactly those lines'
  .. ' of the numbered text below, verbatim with their indentation and without their numbers;'
  .. ' new holds the lines of the code, in the language of the file and its style,'
  .. ' the first indented as line %d is,'
  .. ' and why says what the code does.'
  .. ' When the request cannot be fulfilled in this file, answer no edits and say why in the summary.'

--- What a prompt for code written after a line says first, as a
--- `string.format()` pattern given the file, its language and the line.
local WRITE_BELOW_HEAD = 'Write code in the file %s (language: %s) for the request below,'
  .. ' to be inserted after line %d as numbered below.'

--- What a prompt for code written after a line always says after the
--- request, as a `string.format()` pattern given the line twice: how
--- to answer, which `aineo.explain.write` holds the answer to.
local WRITE_BELOW_RULES = 'Answer in summary what the code does in one sentence,'
  .. ' and one edit that inserts it.'
  .. ' Write only into this file.'
  .. ' The edit gives in line and last the line %d, and repeats in old exactly that line'
  .. ' of the numbered text below, verbatim with its indentation and without its number;'
  .. ' new holds that line unchanged, then the lines of the code, in the language of the file'
  .. ' and its style, indented as the code around line %d is,'
  .. ' and why says what the code does.'
  .. ' When the request cannot be fulfilled in this file, answer no edits and say why in the summary.'

--- What a prompt for code written in place of a blank line says first, as
--- a `string.format()` pattern given the file, its language and the line.
local WRITE_IN_BLANK_HEAD = 'Write code in the file %s (language: %s) for the request below,'
  .. ' to replace line %d as numbered below, which is blank.'

--- What a prompt for code written in place of a blank line always says
--- after the request, as a `string.format()` pattern given the line twice:
--- how to answer, which `aineo.explain.write` holds the answer to.
local WRITE_IN_BLANK_RULES = 'Answer in summary what the code does in one sentence,'
  .. ' and one edit that replaces that line with it.'
  .. ' Write only into this file.'
  .. ' The edit gives in line and last the line %d, and repeats in old exactly that line'
  .. ' of the numbered text below, verbatim with its white space and without its number;'
  .. ' new holds the lines of the code alone, in the language of the file and its style,'
  .. ' indented as the code around line %d is,'
  .. ' and why says what the code does.'
  .. ' When the request cannot be fulfilled in this file, answer no edits and say why in the summary.'

--- What a prompt for code that may edit the whole file says after the
--- rules of the edit asked for: which other edits the code may need, where
--- they go and how each is answered, which `aineo.explain.write` holds the
--- answer to.
local WHOLE_FILE_RULES = 'The code may also need edits elsewhere in this file:'
  .. ' an import at the top, a variable or constant at module scope, a helper function,'
  .. ' a changed signature.'
  .. ' Give each as a further edit after that first one,'
  .. ' placed where the file’s own conventions put it:'
  .. ' never a local import inside a function or a branch when the file imports at the top.'
  .. ' Each further edit gives in line and last the first and last lines it replaces,'
  .. ' and repeats in old exactly those lines of the numbered text below,'
  .. ' verbatim with their indentation and without their numbers;'
  .. ' new holds the lines that replace them, and, to add lines, starts with the line they go after.'
  .. ' No two edits share a line, and there are at most 20 edits.'
  .. ' Edit no other file.'

--- How code written wherever it belongs in a file is answered, which
--- `aineo.explain.write` holds the answer to.
local ANYWHERE_RULES = 'Answer in summary what the code does in one sentence,'
  .. ' and the edits that write it into this file, each where the file’s own conventions put it,'
  .. ' with any import, fixture or helper it needs.'
  .. ' Write only into this file.'
  .. ' Each edit gives in line and last the first and last lines it replaces,'
  .. ' and repeats in old exactly those lines of the numbered text below,'
  .. ' verbatim with their indentation and without their numbers;'
  .. ' new holds the lines that replace them, and, to add lines, starts with the line they go after;'
  .. ' an empty file has one empty line 1, which an edit replaces.'
  .. ' No two edits share a line, and there are at most 20 edits.'
  .. ' When it cannot be done in this file, answer no edits and say why in the summary.'

--- `parts`, the head, request and rules of a prompt for `code`, followed
--- by `WHOLE_FILE_RULES` when code asked at a line may edit the whole file, then by
--- each part of `code.brief`, then by every line of the buffer, numbered
--- (`numbered()`), each after an empty line.
---
---@param code aineo.explain.WriteCode
---@param parts string[]
---@return string[]
local function with_whole_file_rules(code, parts)
  if code.whole_file and not code.anywhere then
    vim.list_extend(parts, { '', WHOLE_FILE_RULES })
  end
  for _, part in ipairs(code.brief or {}) do
    vim.list_extend(parts, { '', part })
  end
  return vim.list_extend(parts, { '', table.concat(numbered(code.lines), '\n') })
end

--- The prompt Claude Code reads to write code for `code.request`, the
--- request typed: after the line `code.first`, or in its place when
--- `code.blank`: the file, its language — `unknown` when the buffer has no
--- `'filetype'` — and that line, the request as typed, how to answer
--- (`WRITE_BELOW_RULES`, `WRITE_IN_BLANK_RULES`), what else the code may
--- edit when it may edit the whole file, then every line of the buffer,
--- numbered (`with_whole_file_rules()`).
---
---@param code aineo.explain.WriteCode
---@return string
local function write_typed_prompt(code)
  local head = code.blank and WRITE_IN_BLANK_HEAD or WRITE_BELOW_HEAD
  local rules = code.blank and WRITE_IN_BLANK_RULES or WRITE_BELOW_RULES
  return table.concat(
    with_whole_file_rules(code, {
      head:format(code.path, code.language ~= '' and code.language or 'unknown', code.first),
      '',
      code.request,
      '',
      rules:format(code.first, code.first),
    }),
    '\n'
  )
end

--- The prompt Claude Code reads to write code for `code`: for code written
--- wherever it belongs, the request, which says what to write and where,
--- how to answer (`ANYWHERE_RULES`), what else Claude Code is shown and
--- every line of the buffer, numbered (`with_whole_file_rules()`); for the
--- request typed, the code going after a line or in place of a blank one
--- (`write_typed_prompt()`); else for
--- the request that the lines `code.first` to `code.last` hold: the file,
--- its language — `unknown` when the buffer has no `'filetype'` — and those
--- lines, which the code replaces, how to answer (`WRITE_IN_PLACE_RULES`),
--- what else the code may edit when it may edit the whole file, then every
--- line of the buffer, numbered (`with_whole_file_rules()`).
---
---@param code aineo.explain.WriteCode
---@return string
function M.write_prompt(code)
  if code.anywhere then
    return table.concat(with_whole_file_rules(code, { code.request, '', ANYWHERE_RULES }), '\n')
  end
  if code.request then
    return write_typed_prompt(code)
  end
  return table.concat(
    with_whole_file_rules(code, {
      WRITE_IN_PLACE_HEAD:format(
        code.path,
        code.language ~= '' and code.language or 'unknown',
        code.first,
        code.last
      ),
      '',
      WRITE_IN_PLACE_RULES:format(code.first, code.last, code.first),
    }),
    '\n'
  )
end

--- A file a prompt shows as it reads.
---@class aineo.explain.ShownFile
---@field path string its path from the folder Claude Code runs in
---@field lines string[]

--- The tests a list of tests is asked for.
---@class aineo.explain.TestsCode
---@field path string the source's path from the folder Claude Code runs in
---@field language string the source buffer's `'filetype'`, empty when it has none
---@field first integer the first line of the code to test, from 1
---@field last integer the last line of the code to test
---@field test_path string the test file's path from the folder Claude Code runs in
---@field framework? string the test framework the test file is written for
---@field test_file? aineo.explain.ShownFile the test file, when it exists
---@field sibling? aineo.explain.ShownFile a test file of the project, shown for a test file that does not exist yet
---@field lines string[] every line of the source buffer, as it stands

--- What a prompt for a list of tests says first, as a `string.format()`
--- pattern given the first and last line of the code, the file and its
--- language.
local TESTS_HEAD = 'List the tests worth writing for the code that lines %d to %d of the file %s'
  .. ' (language: %s) hold, as numbered below.'

--- How a list of tests is answered.
local TESTS_RULES = 'Answer in tests one entry for each test: in name the name the test file would give it,'
  .. ' and in checks what it checks, on one line. Answer no tests when none is worth writing.'

--- Where the tests of `code` go: the test file, and its framework when it
--- is known.
---
---@param code aineo.explain.TestsCode
---@return string
local function test_file_line(code)
  if code.framework then
    return ('The tests go in the test file %s, written for %s.'):format(
      code.test_path,
      code.framework
    )
  end
  return ('The tests go in the test file %s.'):format(code.test_path)
end

--- What a prompt about tests shows of the test file of `code`: its lines
--- as it reads; else, for a test file that does not exist yet, that it
--- does not, and the lines of another test file of the project, whose
--- header and style it follows, when there is one.
---
---@param code aineo.explain.TestsCode
---@return string[]
local function test_file_part(code)
  if code.test_file then
    return vim.list_extend(
      { ('The test file %s reads:'):format(code.test_path), '' },
      code.test_file.lines
    )
  end
  local missing = ('The test file %s does not exist yet.'):format(code.test_path)
  if not code.sibling then
    return { missing }
  end
  return vim.list_extend({
    missing .. (' The test file %s of the project reads, its header and style to follow:'):format(
      code.sibling.path
    ),
    '',
  }, code.sibling.lines)
end

--- The prompt Claude Code reads to list the tests worth writing for the
--- lines `code.first` to `code.last` of a source: the lines, the file and
--- its language — `unknown` when the buffer has no `'filetype'` — where the
--- tests go (`test_file_line()`), how to answer (`TESTS_RULES`), the test
--- file or another of the project (`test_file_part()`), then every line of
--- the source, numbered.
---
---@param code aineo.explain.TestsCode
---@return string
function M.tests_prompt(code)
  local parts = {
    TESTS_HEAD:format(
      code.first,
      code.last,
      code.path,
      code.language ~= '' and code.language or 'unknown'
    ),
    test_file_line(code),
    TESTS_RULES,
    '',
  }
  vim.list_extend(parts, test_file_part(code))
  vim.list_extend(parts, { '' })
  return table.concat(vim.list_extend(parts, numbered(code.lines)), '\n')
end

return M
