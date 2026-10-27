local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The help file under test, in this checkout.
local HELP_FILE = vim.fs.joinpath(vim.uv.cwd(), 'doc', 'aineo.txt')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_case = child.stop } })

--- A copy of the help file in a `doc/` directory of its own under `.tests/`,
--- so that its tags file is generated there and never in the checkout's
--- `doc/`.
---
---@return string directory the copy's runtime directory, holding `doc/aineo.txt`
local function copied_help()
  local directory = fixture.directory('doc-help')
  local copy = vim.fs.joinpath(directory, 'doc', 'aineo.txt')
  vim.fn.mkdir(vim.fs.dirname(copy), 'p')
  assert(vim.fn.writefile(vim.fn.readfile(HELP_FILE, 'b'), copy, 'b') == 0, 'cannot copy ' .. copy)
  return directory
end

--- Starts `child` afresh with the copied help first on 'runtimepath' and its
--- tags generated, and returns whether `:helptags` succeeded and, when it
--- did not, its error.
---
---@return { generated: boolean, failure?: string }
local function start_with_help()
  local directory = copied_help()
  children.restart(child)
  return child.lua(
    [[
      local directory = ...
      vim.opt.runtimepath:prepend(directory)
      local generated, failure = pcall(vim.cmd.helptags, vim.fs.joinpath(directory, 'doc'))
      return { generated = generated, failure = (not generated) and tostring(failure) or nil }
    ]],
    { directory }
  )
end

--- Where `:help <tag>` lands in `child`: the help file's name and the line
--- the cursor is on; when `:help` finds nothing, no file but its error.
local HELP_LANDING = [[
  local tag = ...
  local found, failure = pcall(vim.cmd.help, tag)
  if not found then
    return { file = 'no help: ' .. tostring(failure), line = '' }
  end
  return { file = vim.fn.expand('%:t'), line = vim.api.nvim_get_current_line() }
]]

T['the help'] = MiniTest.new_set()

T['the help']['generates its tags without an error'] = function()
  local helptags = start_with_help()

  eq(helptags, { generated = true })
end

T['the help']['opens at its introduction on :help aineo'] = function()
  start_with_help()

  local landing = child.lua(HELP_LANDING, { 'aineo' })

  eq(landing.file, 'aineo.txt')
  eq(vim.endswith(landing.line, '*aineo*'), true)
end

--- Every tag the help must hold: each command, `<Plug>` mapping, prefix key
--- and setting, and each section a user is sent to.
local TAGS = {
  ':Aineo',
  ':Aineo-send',
  ':Aineo-open',
  ':Aineo-report',
  ':Aineo-input',
  ':Aineo-claude',
  ':Aineo-pane',
  ':Aineo-run',
  ':Aineo-find',
  ':Aineo-zoom',
  ':Aineo-zoom-full',
  ':Aineo-explain',
  '<Plug>(aineo-send)',
  '<Plug>(aineo-open)',
  '<Plug>(aineo-report)',
  '<Plug>(aineo-input)',
  '<Plug>(aineo-claude)',
  '<Plug>(aineo-pane-agent)',
  '<Plug>(aineo-pane-changes)',
  '<Plug>(aineo-pane-terminal)',
  '<Plug>(aineo-pane-run)',
  '<Plug>(aineo-run-shell)',
  '<Plug>(aineo-find)',
  '<Plug>(aineo-zoom)',
  '<Plug>(aineo-zoom-full)',
  '<Plug>(aineo-explain)',
  '<Plug>(aineo-explain-tools)',
  '<Plug>(aineo-explain-issues)',
  '<Plug>(aineo-explain-issues-tools)',
  '<Plug>(aineo-explain-deep)',
  '<Plug>(aineo-explain-deep-issues)',
  'aineo-\\s',
  'aineo-\\o',
  'aineo-\\r',
  'aineo-\\i',
  'aineo-\\c',
  'aineo-\\pa',
  'aineo-\\g',
  'aineo-\\pt',
  'aineo-\\x',
  'aineo-\\X',
  'aineo-\\f',
  'aineo-\\z',
  'aineo-\\Z',
  'aineo-v_\\s',
  'aineo-\\v',
  'aineo-\\V',
  'aineo-v_\\v',
  'aineo-v_\\V',
  'aineo-terminal-keys',
  'aineo-<C-\\>i',
  'aineo-<C-\\>pt',
  'aineo-<C-\\>x',
  'aineo-<C-\\>X',
  'aineo-run',
  'aineo-run-tools',
  'aineo-<C-\\>f',
  'aineo-<C-\\>z',
  'aineo-<C-\\>Z',
  'aineo-zoom',
  'aineo-zoom-full',
  'g:aineo',
  'aineo.setup()',
  'aineo-config-prefix',
  'aineo-config-terminal_prefix',
  'aineo-config-autostart',
  'aineo-config-claude.cmd',
  'aineo-config-claude.hide_multiplexer',
  'aineo-config-layout.report_height',
  'aineo-config-changes.working_branch',
  'aineo-config-tabs.padding',
  'aineo-config-tabs.always_show',
  'aineo-config-find.picker',
  'aineo-config-office.idle_ms',
  'aineo-config-office.pack',
  'aineo-config-office.pieces',
  'aineo-config-explain.model',
  'aineo-config-explain.timeout_ms',
  'aineo-config-explain.deep_model',
  'aineo-config-explain.deep_effort',
  'aineo-config-explain.deep_timeout_ms',
  'aineo-config-office.commands',
  'aineo-config-office.commands.tests',
  'aineo-config-office.commands.committing',
  'aineo-config-office.commands.searching',
  'aineo-config-office.commands.reading',
  'aineo-explain',
  'aineo-explain-deep',
  'aineo-explain-fix',
  'aineo-write',
  'hl-AineoExplain',
  'hl-AineoExplainGutter',
  'hl-AineoExplainGutterFill',
  'hl-AineoExplainNr',
  'hl-AineoExplainIssue',
  'hl-AineoExplainIssueGutter',
  'hl-AineoExplainIssueGutterFill',
  'hl-AineoExplainIssueNr',
  'hl-AineoFix',
  'hl-AineoFixGutter',
  'hl-AineoFixGutterFill',
  'hl-AineoFixOld',
  'hl-AineoFixWhy',
  'hl-AineoFixWhyGutter',
  'hl-AineoFixWhyGutterFill',
  'hl-AineoWrite',
  'hl-AineoWriteGutter',
  'hl-AineoWriteGutterFill',
  'aineo-find',
  'aineo-office',
  ':Aineo-office-check',
  'aineo-office-packs',
  'aineo-office-pack-lua',
  'aineo-office-characters',
  'aineo-office-effects',
  'aineo-office-art',
  'aineo-office-floor',
  'aineo-office-activities',
  'aineo-office-triggers',
  'aineo-office-check',
  'aineo-office-cards',
  'aineo-office-states',
  'aineo-office-session',
  'aineo-office-poses',
  'aineo-office-live',
  'aineo-office-steps',
  'aineo-office-spots',
  'aineo-office-desks',
  'aineo-office-random-life',
  'aineo-office-things',
  'aineo-office-cat',
  'aineo-office-pack-states',
  'aineo-office-tiny',
  'aineo-office-default',
  'aineo-office-space-station',
  'aineo-office-making',
  'aineo-office-sharing',
  'aineo-office-hooks',
  'aineo-office-limits',
  'hl-AineoOfficeCardDone',
  'hl-AineoOfficeCardProgress',
  'hl-AineoOfficeCardProblem',
  'hl-AineoOfficeCardMore',
  'aineo-tabline',
  'aineo-layout',
  'aineo-panes',
  'aineo-changes',
  'aineo-mappings',
  'aineo-keys',
  'aineo-send',
  'aineo-report',
  'aineo-report-days',
  'hl-AineoReportDay',
  'aineo-autostart',
  'aineo-health',
  'g:aineo_startup',
  'aineo-limits',
}

--- The tags the running plugin says the help must hold, sorted: one per
--- subcommand `:Aineo` completes, per `<Plug>(aineo-…)` mapping, per prefix
--- key mapped to one — `aineo-{keys}` in Normal mode, `aineo-v_{keys}` in
--- Visual mode, after Vim's own `v_` tags — per twin of a prefix key, one
--- `aineo-{keys}` for both Terminal and Insert mode, and per setting the
--- configuration resolves.
local TAGS_THE_PLUGIN_DEFINES = [[
  local tags = {}
  for _, subcommand in ipairs(vim.fn.getcompletion('Aineo ', 'cmdline')) do
    table.insert(tags, ':Aineo-' .. subcommand)
  end
  for mode, key_tag in pairs({ n = 'aineo-', x = 'aineo-v_', t = 'aineo-', i = 'aineo-' }) do
    for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
      if vim.startswith(mapping.lhs, '<Plug>(aineo-') then
        table.insert(tags, mapping.lhs)
      elseif mapping.rhs and mapping.rhs:find('<Plug>(aineo-', 1, true) then
        table.insert(tags, key_tag .. mapping.lhs:gsub('<C%-Bslash>', '<C-\\>'))
      end
    end
  end
  local function add_settings(path, value)
    for key, inner in pairs(value) do
      local name = path == '' and key or (path .. '.' .. key)
      if type(inner) == 'table' and not vim.islist(inner) then
        add_settings(name, inner)
      else
        table.insert(tags, 'aineo-config-' .. name)
      end
    end
  end
  add_settings('', require('aineo.config').resolve_config(nil, nil))
  table.sort(tags)
  return vim.fn.uniq(tags)
]]

--- How many tags the plugin defines at least, so that a lost mapping or
--- setting cannot pass for a smaller help: 9 subcommands of `:Aineo`, 10
--- `<Plug>` mappings, 9 prefix keys and `aineo-v_\s`, 8 twins and 5
--- settings.
local TAGS_THE_PLUGIN_DEFINES_AT_LEAST = 42

--- The tags of `tags` that `:help` does not take to a line of the help
--- holding them, in `child`.
local TAGS_MISSING = [[
  local missing = {}
  for _, tag in ipairs(...) do
    local found = pcall(vim.cmd.help, tag)
    if not found or not vim.api.nvim_get_current_line():find('*' .. tag .. '*', 1, true) then
      table.insert(missing, tag)
    end
  end
  return missing
]]

T['the help']['has a tag for every command, mapping, key and setting the plugin defines'] = function()
  start_with_help()
  local tags = child.lua(TAGS_THE_PLUGIN_DEFINES)

  local missing = child.lua(TAGS_MISSING, { tags })

  eq(#tags >= TAGS_THE_PLUGIN_DEFINES_AT_LEAST, true)
  eq(missing, {})
end

T['the help']['has the tag'] = MiniTest.new_set({
  parametrize = vim.tbl_map(function(tag)
    return { tag }
  end, TAGS),
})

T['the help']['has the tag']['on the line :help takes you to'] = function(tag)
  start_with_help()

  local landing = child.lua(HELP_LANDING, { tag })

  eq(landing.file, 'aineo.txt')
  eq(landing.line:find('*' .. tag .. '*', 1, true) ~= nil, true)
end

--- The lines of the help file wider than its `textwidth`, 78 columns.
---
---@return string[]
local function lines_wider_than_textwidth()
  return vim.tbl_filter(function(line)
    return vim.fn.strdisplaywidth(line) > 78
  end, vim.fn.readfile(HELP_FILE))
end

T['the help']['fits in 78 columns'] = function()
  eq(lines_wider_than_textwidth(), {})
end

T['the help']['is a help file: its own tag first, its modeline last'] = function()
  local lines = vim.fn.readfile(HELP_FILE)

  eq(vim.startswith(lines[1], '*aineo.txt*'), true)
  eq(lines[#lines], ' vim:tw=78:ts=8:ft=help:norl:')
end

return T
