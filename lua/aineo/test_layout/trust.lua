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
--- own, read from the repository's root, then each preset template a
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

--- The rules of the agent's statements, `agent`, in their order, each
--- described by its position, and by the preset it names, if it does.
---
---@param agent? { rules: aineo.test_layout.Statement[], framework?: string }
---@param catalogue aineo.test_layout.Catalogue
---@return aineo.test_layout.Rule[][] the rules of each statement
local function agent_rules(agent, catalogue)
  local stated = {}
  for position, statement in ipairs(agent and agent.rules or {}) do
    local description = ('agent rule %d'):format(position)
    if statement.preset then
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
--- marked preset before a default, then in the catalogue's order.
---
---@param view aineo.test_layout.View
---@param catalogue aineo.test_layout.Catalogue
---@param extension string
---@return aineo.test_layout.Ranked[]
local function ranked_presets(view, catalogue, extension)
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

return M
