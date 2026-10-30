--- Which rules of a test layout hold for a file, in the order of trust:
--- the user's correction, the agent's rules, the presets the repository
--- shows, and the language's default.

local finding = require('aineo.test_layout.finding')
local rules = require('aineo.test_layout.rules')

local M = {}

--- What the store keeps of a repository's layout.
---@class aineo.test_layout.Stored
---@field agent? { rules: aineo.test_layout.Statement[], framework?: string } the agent's rules
---@field user? { pairs: table<string, string>, rules: { preset: string, rule: integer, test: integer }[] } the user's corrections: each source's test file, and the preset templates they fit

--- The presets a rule set is chosen from, and each language's defaults.
---@class aineo.test_layout.Catalogue
---@field presets aineo.test_layout.Preset[] every preset, in the catalogue's order
---@field defaults fun(extension: string, view: aineo.test_layout.View): string[] the ids of the default presets of the language of `extension`

--- The preset of `catalogue` whose id is `id`, or nil.
---
---@param catalogue aineo.test_layout.Catalogue
---@param id string
---@return aineo.test_layout.Preset?
local function preset_of(catalogue, id)
  return vim.iter(catalogue.presets):find(function(preset)
    return preset.id == id
  end)
end

--- The rules of the user's corrections, `user`: each pair as a rule of its
--- own, read from the repository's root and pinned — its test file is its
--- source's whether it exists or not — then each preset template a
--- correction fitted, as the user's rule.
---
---@param user? { pairs: table<string, string>, rules: { preset: string, rule: integer, test: integer }[] }
---@param catalogue aineo.test_layout.Catalogue
---@return aineo.test_layout.Rule[]
local function user_rules(user, catalogue)
  local found = {}
  local sources = vim.tbl_keys(user and user.pairs or {})
  table.sort(sources)
  for _, source in ipairs(sources) do
    local rule =
      rules.of_statement({ source = source, test = user.pairs[source] }, 'user', 'your correction')
    rule.from_root = true
    rule.pinned = true
    table.insert(found, rule)
  end
  for _, fitted in ipairs(user and user.rules or {}) do
    local preset = preset_of(catalogue, fitted.preset)
    local statement = preset and preset.rules[fitted.rule]
    local tests = statement and statement.test
    tests = type(tests) == 'string' and { tests } or tests
    if tests and tests[fitted.test] then
      local first = vim.tbl_extend('force', statement, { test = tests[fitted.test] })
      local fitted_preset = vim.tbl_extend('force', preset, { rules = { first } })
      vim.list_extend(
        found,
        rules.of_preset(fitted_preset, 'user', ('your rule (%s)'):format(preset.id))
      )
    end
  end
  return found
end

--- Why the agent's kept statement `statement` is skipped — what
--- `rules.statements_problem()` refuses of it now, such as a glob kept by
--- an older aineo that `vim.glob` cannot read — without the `rules[1].`
--- that problem begins with; nil when it is read.
---
---@param statement aineo.test_layout.Statement
---@param catalogue aineo.test_layout.Catalogue
---@return string?
local function skip_reason(statement, catalogue)
  local problem = rules.statements_problem({ statement }, catalogue)
  return problem and (problem:gsub('^rules%[1%]%.?', ''))
end

--- The rules of the agent's statements, `agent`, in their order, each
--- described by its position, and by the preset it names, if it does; a
--- statement `skip_reason()` skips has none.
---
---@param agent? { rules: aineo.test_layout.Statement[], framework?: string }
---@param catalogue aineo.test_layout.Catalogue
---@return aineo.test_layout.Rule[][] the rules of each statement
local function agent_rules(agent, catalogue)
  local stated = {}
  for position, statement in ipairs(agent and agent.rules or {}) do
    local description = ('agent rule %d'):format(position)
    if skip_reason(statement, catalogue) then
      table.insert(stated, {})
    elseif statement.preset then
      local preset = preset_of(catalogue, statement.preset)
      table.insert(
        stated,
        preset
            and rules.of_preset(
              preset,
              'agent',
              ('%s (%s)'):format(description, preset.id),
              { kind = statement.kind, create = statement.create }
            )
          or {}
      )
    else
      local rule = rules.of_statement(statement, 'agent', description)
      rule.framework = rule.framework or agent.framework
      table.insert(stated, { rule })
    end
  end
  return stated
end

--- Whether `view`'s repository holds `marker`: a file a glob names, or a
--- file a glob names that holds a text.
---
---@param view aineo.test_layout.View
---@param marker string|{ file: string, holds: string }
---@return boolean
local function holds_marker(view, marker)
  local glob = type(marker) == 'table' and marker.file or marker
  local pattern = vim.glob.to_lpeg(glob)
  for _, file in ipairs(view.files) do
    if pattern:match(file) then
      if type(marker) ~= 'table' then
        return true
      end
      local text = view.read(file)
      if text and text:find(marker.holds, 1, true) then
        return true
      end
    end
  end
  return false
end

--- Whether `preset` is for sources of `extension`.
---
---@param preset aineo.test_layout.Preset
---@param extension string
---@return boolean
local function is_for(preset, extension)
  return vim.tbl_contains(preset.extensions, extension)
end

--- How many existing sources `rules_of_one`, the rules of one preset or
--- one statement, pair with existing test files.
---
---@param rules_of_one aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@return integer
local function paired_count(rules_of_one, view)
  local count = 0
  for _, rule in ipairs(rules_of_one) do
    count = count + #finding.paired_sources(rule, view)
  end
  return count
end

--- A preset of `catalogue` in force for files of one extension, its rules,
--- whether the repository holds one of its markers, and how many sources
--- it pairs.
---@class aineo.test_layout.Ranked
---@field preset aineo.test_layout.Preset
---@field marked boolean
---@field pairs integer

--- The presets of `catalogue` for sources of `extension` that `view`'s
--- repository shows — one of their markers is present — and the language's
--- defaults, ranked by how many sources each pairs with test files, then a
--- marked preset before a default, then in the catalogue's order. Kept in
--- `view.ranked`, by extension, when the view has that table, and read
--- from it the next time.
---
---@param view aineo.test_layout.View
---@param catalogue aineo.test_layout.Catalogue
---@param extension string
---@return aineo.test_layout.Ranked[]
local function ranked_presets(view, catalogue, extension)
  if view.ranked and view.ranked[extension] then
    return view.ranked[extension]
  end
  local defaults = {}
  for _, id in ipairs(catalogue.defaults(extension, view)) do
    defaults[id] = true
  end
  local ranked = {}
  for order, preset in ipairs(catalogue.presets) do
    local marked = is_for(preset, extension)
      and vim.iter(preset.markers):any(function(marker)
        return holds_marker(view, marker)
      end)
    if marked or defaults[preset.id] then
      table.insert(ranked, {
        preset = preset,
        marked = marked,
        order = order,
        pairs = paired_count(rules.of_preset(preset, 'preset'), view),
      })
    end
  end
  table.sort(ranked, function(left, right)
    if left.pairs ~= right.pairs then
      return left.pairs > right.pairs
    end
    if left.marked ~= right.marked then
      return left.marked
    end
    return left.order < right.order
  end)
  if view.ranked then
    view.ranked[extension] = ranked
  end
  return ranked
end

--- The rules of `ranked`, a ranked preset: the repository's when it holds
--- one of its markers or it pairs a source, else the default's.
---
---@param ranked aineo.test_layout.Ranked
---@return aineo.test_layout.Rule[]
local function preset_rules(ranked)
  local shown = ranked.marked or ranked.pairs > 0
  return rules.of_preset(ranked.preset, shown and 'repository' or 'preset')
end

--- The rules in force for `path`, a file relative to `view`'s root, from
--- `stored` and `catalogue`, in the order of trust: the user's
--- corrections; the agent's rules; the presets for `path`'s extension that
--- the repository shows, ranked by how many sources each pairs with test
--- files; the language's default presets. An agent's rule that pairs no
--- source while a preset pairs some is kept, after the presets that pair
--- some.
---
---@param view aineo.test_layout.View
---@param stored aineo.test_layout.Stored
---@param catalogue aineo.test_layout.Catalogue
---@param path string
---@return aineo.test_layout.Rule[]
function M.rules_for(view, stored, catalogue, path)
  local extension = path:match('%.([^./]+)$') or ''
  local ranked = ranked_presets(view, catalogue, extension)
  local pairing = vim.tbl_filter(function(preset)
    return preset.pairs > 0
  end, ranked)
  local in_force = user_rules(stored.user, catalogue)
  local demoted = {}
  for _, stated in ipairs(agent_rules(stored.agent, catalogue)) do
    local is_demoted = #pairing > 0 and paired_count(stated, view) == 0
    vim.list_extend(is_demoted and demoted or in_force, stated)
  end
  for _, preset in ipairs(pairing) do
    vim.list_extend(in_force, preset_rules(preset))
  end
  vim.list_extend(in_force, demoted)
  for _, preset in ipairs(ranked) do
    if preset.pairs == 0 then
      vim.list_extend(in_force, preset_rules(preset))
    end
  end
  return in_force
end

--- What the reply to an agent's rules says of one of them.
---@class aineo.test_layout.Assessment
---@field description string the rule's description, such as `agent rule 2 (python.pytest.flat)`
---@field pairs integer how many existing sources it pairs with existing tests
---@field contradictions integer how many of those tests another rule pairs with a different source
---@field after string[] the ids of the presets it is kept after, as it pairs nothing while they pair sources

--- The extensions of the files of `view` that a source template of
--- `rules_of_one` matches.
---
---@param rules_of_one aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@return string[]
local function matched_extensions(rules_of_one, view)
  local found = {}
  for _, file in ipairs(view.files) do
    local extension = file:match('%.([^./]+)$')
    if extension and not found[extension] then
      for _, rule in ipairs(rules_of_one) do
        if #finding.tests_of(view, rule, file) > 0 then
          found[extension] = true
        end
      end
    end
  end
  local extensions = vim.tbl_keys(found)
  table.sort(extensions)
  return extensions
end

--- The groups of rules that could pair a test of `view` with a source:
--- the user's, each agent statement's, and every preset the repository
--- shows or defaults to for the extensions it has; each group with a key.
---
---@param view aineo.test_layout.View
---@param stored aineo.test_layout.Stored
---@param catalogue aineo.test_layout.Catalogue
---@param stated aineo.test_layout.Rule[][] the rules of each agent statement
---@return { key: string, rules: aineo.test_layout.Rule[] }[]
local function rule_groups(view, stored, catalogue, stated)
  local groups = { { key = 'user', rules = user_rules(stored.user, catalogue) } }
  for position, rules_of_one in ipairs(stated) do
    table.insert(groups, { key = 'agent ' .. position, rules = rules_of_one })
  end
  local seen = {}
  for _, extension in ipairs(matched_extensions(vim.iter(stated):flatten():totable(), view)) do
    for _, ranked in ipairs(ranked_presets(view, catalogue, extension)) do
      if not seen[ranked.preset.id] then
        seen[ranked.preset.id] = true
        table.insert(groups, { key = ranked.preset.id, rules = preset_rules(ranked) })
      end
    end
  end
  return groups
end

--- What the reply to the agent's rules of `stored` says of each, in their
--- order: how many existing sources it pairs with existing tests; how many
--- of those tests another rule in force — the user's, another statement's,
--- a preset's — pairs with a different source; and, for one that pairs
--- nothing while presets for the files it matches pair some, those
--- presets, which it is kept after (`rules_for()`). Each rule's pairs are
--- read once.
---
---@param view aineo.test_layout.View
---@param stored aineo.test_layout.Stored
---@param catalogue aineo.test_layout.Catalogue
---@return aineo.test_layout.Assessment[]
function M.assess(view, stored, catalogue)
  local stated = agent_rules(stored.agent, catalogue)
  local groups = rule_groups(view, stored, catalogue, stated)
  local pairs_of_rule = {}
  local function paired(rule)
    pairs_of_rule[rule] = pairs_of_rule[rule] or finding.paired_sources(rule, view)
    return pairs_of_rule[rule]
  end
  local sources_of_test = {}
  for _, group in ipairs(groups) do
    for _, rule in ipairs(group.rules) do
      for _, pair in ipairs(paired(rule)) do
        sources_of_test[pair.test] = sources_of_test[pair.test] or {}
        table.insert(sources_of_test[pair.test], { key = group.key, source = pair.source })
      end
    end
  end
  local assessments = {}
  for position, rules_of_one in ipairs(stated) do
    local key = 'agent ' .. position
    local pairs_count, contradictions = 0, 0
    for _, rule in ipairs(rules_of_one) do
      for _, pair in ipairs(paired(rule)) do
        pairs_count = pairs_count + 1
        local contradicted = vim.iter(sources_of_test[pair.test]):any(function(other)
          return other.key ~= key and other.source ~= pair.source
        end)
        contradictions = contradictions + (contradicted and 1 or 0)
      end
    end
    local after = {}
    for _, extension in ipairs(pairs_count == 0 and matched_extensions(rules_of_one, view) or {}) do
      for _, ranked in ipairs(ranked_presets(view, catalogue, extension)) do
        if ranked.pairs > 0 and not vim.tbl_contains(after, ranked.preset.id) then
          table.insert(after, ranked.preset.id)
        end
      end
    end
    table.insert(assessments, {
      description = rules_of_one[1] and rules_of_one[1].description
        or ('agent rule %d'):format(position),
      pairs = pairs_count,
      contradictions = contradictions,
      after = after,
    })
  end
  return assessments
end

--- The rules in force for any file of `view`'s repository, each named once
--- in the order of trust: the user's, the agent's, then for each extension
--- of the repository's files the presets it shows or defaults to, ranked
--- (`rules_for()`).
---
---@param view aineo.test_layout.View
---@param stored aineo.test_layout.Stored
---@param catalogue aineo.test_layout.Catalogue
---@return { description: string, origin: string }[]
function M.in_force(view, stored, catalogue)
  local named, seen = {}, {}
  local function name(rule)
    if not seen[rule.description] then
      seen[rule.description] = true
      table.insert(named, { description = rule.description, origin = rule.origin })
    end
  end
  vim.iter(user_rules(stored.user, catalogue)):each(name)
  vim.iter(agent_rules(stored.agent, catalogue)):flatten():each(name)
  local extensions = {}
  for _, file in ipairs(view.files) do
    local extension = file:match('%.([^./]+)$')
    if extension and not extensions[extension] then
      extensions[extension] = true
      for _, ranked in ipairs(ranked_presets(view, catalogue, extension)) do
        vim.iter(preset_rules(ranked)):each(name)
      end
    end
  end
  return named
end

--- The agent's kept statements that are skipped, each as `agent rule <n>:
--- <why>` (`skip_reason()`), in their order.
---
---@param stored aineo.test_layout.Stored
---@param catalogue aineo.test_layout.Catalogue
---@return string[]
function M.skipped(stored, catalogue)
  local named = {}
  for position, statement in ipairs(stored.agent and stored.agent.rules or {}) do
    local reason = skip_reason(statement, catalogue)
    if reason then
      table.insert(named, ('agent rule %d: %s'):format(position, reason))
    end
  end
  return named
end

--- The preset template that gives `test` for `source`, both relative to
--- `view`'s root, as the user's correction states them: the first preset
--- of `catalogue` for `source`'s extension, its rule and its test
--- template, by their positions; nil when none does.
---
---@param view aineo.test_layout.View
---@param catalogue aineo.test_layout.Catalogue
---@param source string
---@param test string
---@return { preset: string, rule: integer, test: integer }?
function M.fitting_template(view, catalogue, source, test)
  local extension = source:match('%.([^./]+)$') or ''
  for _, preset in ipairs(catalogue.presets) do
    if is_for(preset, extension) then
      for position, rule in ipairs(rules.of_preset(preset, 'preset')) do
        local tests = finding.tests_of(view, rule, source)
        for alternative, path in ipairs(tests) do
          if path == test then
            return { preset = preset.id, rule = position, test = alternative }
          end
        end
      end
    end
  end
  return nil
end

return M
