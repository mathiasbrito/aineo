--- Finding the test file of a source, and the source of a test file, by the
--- rules in force, in a view of the repository's files.

local modules = require('aineo.test_layout.modules')
local template = require('aineo.test_layout.template')

local M = {}

--- A rule of a test layout, as the finding uses it.
---@class aineo.test_layout.Rule
---@field source? string the source template
---@field tests? string[] the test templates, the first used to create
---@field inline? boolean whether the test is the source file itself
---@field folder? string the folder of tests tied to no one source, used only to create
---@field kind? string unit, integration, e2e…
---@field create? boolean whether this rule creates a new test file before the others
---@field discover? string[] the globs that name the test files, relative to the unit root
---@field framework? string the test framework
---@field companions? string[] the file names created beside a new test file's folder when its siblings' folders have them
---@field extensions? string[] the extensions of the sources a preset's rule is for
---@field from_root? boolean whether the templates are read from the repository's root rather than the unit's
---@field pinned? boolean whether the rule's test file is the place of its source whether it exists or not: the user's correction
---@field origin 'user'|'agent'|'repository'|'preset' who stated the rule
---@field description string the rule's name for the user, such as a preset's id

--- What finding reads of a repository: its folder, its files, relative
--- to that folder with `/` separators, as a list and as a set, a text
--- search over its files and a reader of one file.
---@class aineo.test_layout.View
---@field root string the absolute path of the worktree's folder
---@field files string[] the tracked files and the untracked ones not ignored
---@field has table<string, true> the same files, as a set
---@field grep fun(patterns: string[]): { path: string, text: string }[] the lines holding any of the fixed strings `patterns`, each with its file
---@field read fun(relative: string): string? the text of a file, nil when it cannot be read
---@field ranked? table<string, table> the presets ranked for each extension, kept with the view (`aineo.test_layout.trust`)

--- Where the test file of a source is, or the source of a test file.
---@class aineo.test_layout.Place
---@field path string the absolute path of the file
---@field exists boolean whether the file exists
---@field candidates string[] the absolute paths of the existing files that could be it, best first
---@field origin 'user'|'agent'|'repository'|'preset' who stated the rule that gave it
---@field rule string the rule's description
---@field kind? string
---@field inline boolean whether the test is the source file itself
---@field framework? string
---@field sibling? string an existing test file nearest to `path`
---@field companions string[] the absolute paths of the files to create with the first write
---@field root? string the folder of the worktree the place was read in, which the entry point adds

--- The absolute path of `relative`, a path in `view`'s repository.
---
---@param view aineo.test_layout.View
---@param relative string
---@return string
local function absolute(view, relative)
  return view.root .. '/' .. relative
end

--- The files whose folder is the root of a unit — a package, a module, a
--- project of a monorepo — whose templates are read from that folder.
local MANIFESTS = {
  'pyproject.toml',
  'setup.py',
  'setup.cfg',
  'go.mod',
  'pom.xml',
  'build.gradle',
  'build.gradle.kts',
  'package.json',
}

--- The build files of C and C++, whose folder is a unit root only when no
--- folder above it holds one: a project nests them in its own folders.
local BUILD_FILES = { 'CMakeLists.txt', 'meson.build', 'Makefile' }

--- Whether `folder`, relative to `view`'s root (`''` for the root), holds
--- one of `files`.
---
---@param view aineo.test_layout.View
---@param folder string
---@param files string[]
---@return boolean
local function holds_one_of(view, folder, files)
  return vim.iter(files):any(function(file)
    return view.has[folder == '' and file or folder .. '/' .. file] == true
  end)
end

--- The folder of the unit `path` belongs to, relative to `view`'s root:
--- the nearest folder above it that holds one of the `MANIFESTS`, or the
--- outermost that holds one of the `BUILD_FILES`, whichever is nearer;
--- `''`, the repository's root, when none does.
---
---@param view aineo.test_layout.View
---@param path string
---@return string
function M.unit_of(view, path)
  local folders = {}
  local folder = vim.fs.dirname(path)
  while folder ~= '.' and folder ~= '' do
    table.insert(folders, folder)
    folder = vim.fs.dirname(folder)
  end
  table.insert(folders, '')
  local outermost_build
  for _, above in ipairs(folders) do
    if holds_one_of(view, above, BUILD_FILES) then
      outermost_build = above
    end
  end
  for _, above in ipairs(folders) do
    if above == outermost_build or holds_one_of(view, above, MANIFESTS) then
      return above
    end
  end
  return ''
end

--- `pattern`, a template of `rule`, read from the unit's folder: begun with
--- `{unit}/` unless it begins with `{unit}` already, or `rule` reads its
--- templates from the repository's root (`from_root`).
---
---@param rule aineo.test_layout.Rule
---@param pattern string
---@return string
local function from_unit(rule, pattern)
  if rule.from_root or vim.startswith(pattern, '{unit}') then
    return pattern
  end
  return '{unit}/' .. pattern
end

--- The path the template `to` gives for `path` when the template `from`
--- matches it, both templates of `rule` read from the folder of `path`'s
--- unit (`from_unit()`); nil when `from` does not match.
---
---@param view aineo.test_layout.View
---@param rule aineo.test_layout.Rule
---@param from string
---@param to string
---@param path string
---@return string?
local function translate(view, rule, from, to, path)
  return template.translate(
    from_unit(rule, from),
    from_unit(rule, to),
    path,
    { unit = M.unit_of(view, path) }
  )
end

--- Whether `rule`'s source template matches `path`, read from the folder
--- of its unit; never a file whose extension is not among the rule's
--- extensions, when it has some — a preset's, or a correction's family.
---
---@param view aineo.test_layout.View
---@param rule aineo.test_layout.Rule
---@param path string
---@return boolean
local function matches_source(view, rule, path)
  local extension = path:match('%.([^./]+)$') or ''
  if rule.extensions and not vim.tbl_contains(rule.extensions, extension) then
    return false
  end
  return template.match(from_unit(rule, rule.source), path, { unit = M.unit_of(view, path) }) ~= nil
end

--- The paths of the test files `rule`, which matches `source`, gives it,
--- in the order of its test templates: the source itself for an inline
--- rule.
---
---@param view aineo.test_layout.View
---@param rule aineo.test_layout.Rule
---@param source string
---@return string[]
local function test_paths(view, rule, source)
  if rule.inline then
    return { source }
  end
  return vim.tbl_map(function(test)
    return translate(view, rule, rule.source, test, source)
  end, rule.tests)
end

--- The test files `rule` gives `source`, a path relative to `view`'s
--- root, in the order of its test templates; none when its source template
--- does not match `source` or it has no test template.
---
---@param view aineo.test_layout.View
---@param rule aineo.test_layout.Rule
---@param source string
---@return string[]
function M.tests_of(view, rule, source)
  if not (rule.source and rule.tests and matches_source(view, rule, source)) then
    return {}
  end
  return test_paths(view, rule, source)
end

--- The compiled form of each discovery glob met so far, by glob.
---@type table<string, vim.lpeg.Pattern>
local compiled_globs = {}

--- Whether the discovery glob `glob` names `path`, a path relative to the
--- root of its unit.
---
---@param glob string
---@param path string
---@return boolean
local function glob_names(glob, path)
  compiled_globs[glob] = compiled_globs[glob] or vim.glob.to_lpeg(glob)
  return compiled_globs[glob]:match(path) ~= nil
end

--- `path` relative to the folder `unit`, `''` for the repository's root.
---
---@param unit string
---@param path string
---@return string
local function within_unit(unit, path)
  return unit == '' and path or path:sub(#unit + 2)
end

--- Whether `path`, relative to `view`'s root, is a test file by `rules`:
--- a discovery glob of one of them names it, read from the folder of its
--- unit, or a test template of one of them matches it.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param path string
---@return boolean
function M.is_test(rules, view, path)
  local unit = M.unit_of(view, path)
  local in_unit = within_unit(unit, path)
  for _, rule in ipairs(rules) do
    for _, glob in ipairs(rule.discover or {}) do
      if glob_names(glob, in_unit) then
        return true
      end
    end
    for _, test in ipairs(rule.tests or {}) do
      if template.match(from_unit(rule, test), path, { unit = unit }) then
        return true
      end
    end
  end
  return false
end

--- A file that could be the test file of a source, the rule that names it,
--- and that rule's position among the rules.
---@class aineo.test_layout.Match
---@field path string relative to the repository's root
---@field rule aineo.test_layout.Rule
---@field position integer

--- Orders `matches` by the position of their rules, then shortest path
--- first.
---
---@param matches aineo.test_layout.Match[]
local function sort_best_first(matches)
  table.sort(matches, function(left, right)
    if left.position ~= right.position then
      return left.position < right.position
    end
    return #left.path < #right.path
  end)
end

--- The existing test files the test templates of `matching`, the rules
--- whose source template matches `source`, name for it, best first: in the
--- order of the rules, then shortest path first; each file once, with the
--- first rule that names it.
---
---@param view aineo.test_layout.View
---@param matching aineo.test_layout.Rule[]
---@param source string
---@return aineo.test_layout.Match[]
local function template_matches(view, matching, source)
  local found, seen = {}, {}
  for position, rule in ipairs(matching) do
    for _, path in ipairs(test_paths(view, rule, source)) do
      if view.has[path] and not seen[path] then
        seen[path] = true
        table.insert(found, { path = path, rule = rule, position = position })
      end
    end
  end
  sort_best_first(found)
  return found
end

--- The test files, by `rules`, that import `source` as its language writes
--- an import: the files one text search finds for its fixed strings, each
--- read whole (`view.read`) by `modules.imports()`; shortest path first,
--- each once, named by a rule of the repository's that carries the
--- framework of `creating`, the rule that creates a test file of `source`.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param source string
---@param creating aineo.test_layout.Rule
---@return aineo.test_layout.Match[]
local function text_matches(rules, view, source, creating)
  local patterns = modules.patterns(within_unit(M.unit_of(view, source), source))
  if #patterns == 0 then
    return {}
  end
  local naming = {
    origin = 'repository',
    description = 'names the source',
    framework = creating.framework,
  }
  local found, seen = {}, {}
  for _, hit in ipairs(view.grep(patterns)) do
    local path = hit.path
    if not seen[path] and path ~= source and M.is_test(rules, view, path) then
      seen[path] = true
      if modules.imports(source, path, view.read(path) or '') then
        table.insert(found, { path = path, rule = naming, position = 1 })
      end
    end
  end
  sort_best_first(found)
  return found
end

--- How many leading folders `left` and `right`, two paths, share.
---
---@param left string
---@param right string
---@return integer
local function shared_folders(left, right)
  local left_folders = vim.split(vim.fs.dirname(left), '/', { plain = true })
  local right_folders = vim.split(vim.fs.dirname(right), '/', { plain = true })
  local shared = 0
  while left_folders[shared + 1] and left_folders[shared + 1] == right_folders[shared + 1] do
    shared = shared + 1
  end
  return shared
end

--- The existing test file by `rules` nearest to `path`, a new test file:
--- the one that shares the most leading folders with it, then the shortest,
--- then the first by name; nil when there is none.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param path string
---@return string?
local function nearest_test(rules, view, path)
  local nearest, nearest_shared
  for _, file in ipairs(view.files) do
    if file ~= path and M.is_test(rules, view, file) then
      local shared = shared_folders(path, file)
      local better = not nearest
        or shared > nearest_shared
        or (shared == nearest_shared and #file < #nearest)
        or (shared == nearest_shared and #file == #nearest and file < nearest)
      if better then
        nearest, nearest_shared = file, shared
      end
    end
  end
  return nearest
end

--- The companion files of `rule` a new test file at `path` needs, whose
--- nearest existing test is `sibling`: for each companion the sibling's
--- folder has, the companion in the new file's folder and in each folder
--- above it up to the first that has it, or to the root of `path`'s unit.
---
---@param rule aineo.test_layout.Rule
---@param view aineo.test_layout.View
---@param path string
---@param sibling? string
---@return string[] the companions, relative to `view`'s root
local function companions_of(rule, view, path, sibling)
  local needed = {}
  local unit = M.unit_of(view, path)
  for _, companion in ipairs(sibling and rule.companions or {}) do
    if view.has[vim.fs.joinpath(vim.fs.dirname(sibling), companion)] then
      local folder = vim.fs.dirname(path)
      while folder ~= '.' and folder ~= unit and not view.has[folder .. '/' .. companion] do
        table.insert(needed, folder .. '/' .. companion)
        folder = vim.fs.dirname(folder)
      end
    end
  end
  return needed
end

--- Where the test file of `source`, a path relative to `view`'s root, is
--- by `rules`, in order, or nil and why not — no rule matches it, or it is
--- a test file itself (an inline rule aside).
---
--- The place is the best existing candidate — those the rules' templates
--- name, in the order of the rules then shortest path first, else those
--- whose text names the source (`text_matches()`) — or the file the
--- creating rule gives (the first marked `create`, else the first that
--- matches), with its sibling and companions; when the first rule that
--- matches is pinned, the user's correction, its file is the place whether
--- it exists or not.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param source string
---@return aineo.test_layout.Place?
---@return string? problem
function M.test_for(rules, view, source)
  local matching = vim.tbl_filter(function(rule)
    return rule.source ~= nil
      and (rule.tests ~= nil or rule.inline == true)
      and matches_source(view, rule, source)
  end, rules)
  if #matching == 0 then
    return nil, 'no rule of the project matches ' .. source
  end
  if not matching[1].inline and M.is_test(rules, view, source) then
    return nil, source .. ' is a test file'
  end
  local creating = vim.iter(matching):find(function(candidate)
    return candidate.create == true
  end) or matching[1]
  local found = template_matches(view, matching, source)
  if #found == 0 then
    found = text_matches(rules, view, source, creating)
  end
  local best = found[1]
  if matching[1].pinned then
    local pinned = test_paths(view, matching[1], source)[1]
    best = view.has[pinned] and { path = pinned, rule = matching[1] } or nil
    creating = matching[1]
  end
  local rule = best and best.rule or creating
  local path = best and best.path or test_paths(view, creating, source)[1]
  local sibling = not best and nearest_test(rules, view, path) or nil
  return {
    path = absolute(view, path),
    exists = best ~= nil,
    candidates = vim.tbl_map(function(candidate)
      return absolute(view, candidate.path)
    end, found),
    origin = rule.origin,
    rule = rule.description,
    kind = rule.kind,
    inline = rule.inline == true,
    framework = rule.framework,
    sibling = sibling and absolute(view, sibling),
    companions = vim.tbl_map(function(companion)
      return absolute(view, companion)
    end, best and {} or companions_of(rule, view, path, sibling)),
  }
end

--- Each existing source `rule` pairs with an existing test file, with that
--- file: the first of its test templates that names one. A source is a file
--- of `rule`'s extensions, when it has some, that its source template
--- matches and that is no test file by `rule` itself.
---
---@param rule aineo.test_layout.Rule
---@param view aineo.test_layout.View
---@return { source: string, test: string }[]
function M.paired_sources(rule, view)
  local extensions = rule.extensions and {}
  for _, extension in ipairs(rule.extensions or {}) do
    extensions[extension] = true
  end
  local pairs_found = {}
  for _, file in ipairs(rule.source and rule.tests and view.files or {}) do
    local of_extension = not extensions or extensions[file:match('%.([^./]+)$') or '']
    if
      of_extension
      and matches_source(view, rule, file)
      and not M.is_test({ rule }, view, file)
    then
      local test = vim.iter(test_paths(view, rule, file)):find(function(path)
        return view.has[path] == true
      end)
      if test then
        table.insert(pairs_found, { source = file, test = test })
      end
    end
  end
  return pairs_found
end

--- The sources the two-way test templates of `rules` (`template`'s
--- `is_two_way()`) give `test`, each with its rule and the rule's position
--- among those that give one, in the order of the rules and their
--- templates, each source once; a pair that is one-way is skipped.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param test string
---@return aineo.test_layout.Match[]
local function reverse_matches(rules, view, test)
  local given, seen = {}, {}
  for _, rule in ipairs(rules) do
    for _, pattern in ipairs(rule.source and rule.tests or {}) do
      local source = template.is_two_way(rule.source, pattern)
        and translate(view, rule, pattern, rule.source, test)
      if source and not seen[source] then
        seen[source] = true
        table.insert(given, { path = source, rule = rule, position = #given + 1 })
      end
    end
  end
  return given
end

--- The first of `rules` whose test templates match `test`, and the
--- bindings of the first that does; nil when none does.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param test string
---@return aineo.test_layout.Rule?
---@return table<string, string>?
local function rule_naming(rules, view, test)
  for _, rule in ipairs(rules) do
    for _, pattern in ipairs(rule.source and rule.tests or {}) do
      local bindings =
        template.match(from_unit(rule, pattern), test, { unit = M.unit_of(view, test) })
      if bindings then
        return rule, bindings
      end
    end
  end
  return nil
end

--- The existing files of `view`, test files by `rules` and `test` aside,
--- that `is_source` holds for, shortest path first, then by name.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param test string
---@param is_source fun(path: string): boolean
---@return string[]
local function sources_where(rules, view, test, is_source)
  local found = vim.tbl_filter(function(file)
    return file ~= test and is_source(file) and not M.is_test(rules, view, file)
  end, view.files)
  table.sort(found, function(left, right)
    if #left ~= #right then
      return #left < #right
    end
    return left < right
  end)
  return found
end

--- The existing sources of `test` when no rule gives it a source in
--- reverse, with the rule whose test template matches it (A681): first the
--- files whose stem is the `{name}` that template binds, of the test's
--- language (`modules.family()`), then the files the test imports
--- (`modules.imported()`), each shortest path first; none when no rule's
--- test template matches it.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param test string
---@return string[] sources
---@return aineo.test_layout.Rule? rule
local function way_back(rules, view, test)
  local rule, bindings = rule_naming(rules, view, test)
  if not rule then
    return {}, nil
  end
  local family = modules.family(test:match('%.([^./]+)$') or '')
  local by_stem = sources_where(rules, view, test, function(file)
    local stem, extension = vim.fs.basename(file):match('^(.+)%.([^.]+)$')
    return stem ~= nil and stem == bindings.name and family[extension] == true
  end)
  local imported = modules.imported(test, view.read(test) or '')
  local by_import = sources_where(rules, view, test, function(file)
    return not vim.tbl_contains(by_stem, file)
      and vim.iter(imported):any(function(source)
        return modules.is_imported(file, source)
      end)
  end)
  return vim.list_extend(by_stem, by_import), rule
end

--- Where the source of `test`, a test file relative to `view`'s root, is
--- by `rules`, in order, or nil and why not: the existing sources the
--- two-way pairs of templates give it, best first, else the source the
--- first of them gives. When no two-way pair gives one, the sources found
--- by the stem the rule's template binds, then by the test's imports
--- (`way_back()`), with that rule. The place has no `sibling`, and no
--- companions.
---
---@param rules aineo.test_layout.Rule[]
---@param view aineo.test_layout.View
---@param test string
---@return aineo.test_layout.Place?
---@return string? problem
function M.source_for(rules, view, test)
  local given = reverse_matches(rules, view, test)
  if #given == 0 then
    local sources, rule = way_back(rules, view, test)
    if #sources == 0 then
      return nil, 'no rule of the project gives a source of ' .. test
    end
    given = {}
    for position, source in ipairs(sources) do
      given[position] = { path = source, rule = rule, position = position }
    end
  end
  local found = vim.tbl_filter(function(match)
    return view.has[match.path] == true
  end, given)
  sort_best_first(found)
  local best = found[1] or given[1]
  return {
    path = absolute(view, best.path),
    exists = found[1] ~= nil,
    candidates = vim.tbl_map(function(candidate)
      return absolute(view, candidate.path)
    end, found),
    origin = best.rule.origin,
    rule = best.rule.description,
    kind = best.rule.kind,
    inline = false,
    framework = best.rule.framework,
    companions = {},
  }
end

return M
