--- The text by which a test file of each language names the source it
--- tests — an import, an include — searched for when no template pairs
--- the source with a test file.

local M = {}

--- The extensions of the C and C++ sources and headers.
local C_FAMILY = { c = true, h = true, cc = true, cpp = true, cxx = true, hpp = true, hh = true }

--- The extensions of the JavaScript and TypeScript sources.
local SCRIPT_FAMILY = {
  js = true,
  jsx = true,
  mjs = true,
  cjs = true,
  ts = true,
  tsx = true,
  mts = true,
  cts = true,
}

--- The headers a C or C++ source may be included by.
local HEADER_EXTENSIONS = { 'h', 'hpp', 'hh' }

--- The fixed strings to search for the test files that may import `path`,
--- a source relative to the root of its unit, by language: the stem for
--- Python, Java, JavaScript and TypeScript, the end of a Go import path
--- (`<package folder>"`), the stem's headers for C and C++; none for
--- another language. Each line found is then read by `imports()`.
---
---@param path string
---@return string[]
function M.patterns(path)
  local stem, extension = vim.fs.basename(path):match('^(.+)%.([^.]+)$')
  if not stem then
    return {}
  end
  if extension == 'py' or extension == 'java' or SCRIPT_FAMILY[extension] then
    return { stem }
  end
  if extension == 'go' then
    local folder = vim.fs.dirname(path)
    return folder ~= '.' and { vim.fs.basename(folder) .. '"' } or {}
  end
  if C_FAMILY[extension] then
    return vim.tbl_map(function(header)
      return stem .. '.' .. header
    end, HEADER_EXTENSIONS)
  end
  return {}
end

--- The names `line` imports in a Python `import a, b as c` or `from m
--- import x, y as z`: the module of `from`, if any, and each name listed.
---
---@param line string
---@return string? from
---@return string[] names
local function python_import(line)
  local from, listed = line:match('^%s*from%s+([%w_%.]+)%s+import%s+(.+)$')
  listed = listed or line:match('^%s*import%s+(.+)$')
  if not listed then
    return nil, {}
  end
  local names = {}
  for item in listed:gsub('[()]', ''):gmatch('[^,]+') do
    local name = vim.trim(item):match('^([%w_%.]+)')
    if name then
      table.insert(names, name)
    end
  end
  return from, names
end

--- Whether `line` of a Python test imports the module `module` (`a.b.mod`):
--- `import a.b.mod`, `from a.b.mod import …`, or `from a.b import mod`.
---
---@param module string
---@param line string
---@return boolean
local function python_imports_module(module, line)
  local from, names = python_import(line)
  if from == module then
    return true
  end
  local package, stem = module:match('^(.*)%.([^.]+)$')
  for _, name in ipairs(names) do
    if (not from and name == module) or (from and from == package and name == stem) then
      return true
    end
  end
  return false
end

--- The specifiers `line` of a JavaScript or TypeScript test imports or
--- requires.
---
---@param line string
---@return string[]
local function script_specifiers(line)
  local found = {}
  for _, pattern in ipairs({
    'from%s*[\'"]([^\'"]+)[\'"]',
    'require%(%s*[\'"]([^\'"]+)[\'"]',
    'import%s*%(?%s*[\'"]([^\'"]+)[\'"]',
  }) do
    for specifier in line:gmatch(pattern) do
      table.insert(found, specifier)
    end
  end
  return found
end

--- Whether `line`, a line of a test file, imports `path`, a source relative
--- to the root of its unit, as its language reads an import: Python `import
--- a.b.mod`, `from a.b.mod import`, `from a.b import mod` (`src/` dropped
--- from the module); Go an import path whose last folder is the source's
--- folder; Java `import p.Foo;` or the class's name as a whole word; C and
--- C++ an `#include` of the stem's header, `name.h` or `…/name.h` (`.h`,
--- `.hpp`, `.hh`); JavaScript and TypeScript an import or `require` whose
--- last segment is the stem, with or without an extension.
---
---@param path string
---@param line string
---@return boolean
function M.imports(path, line)
  local stem, extension = vim.fs.basename(path):match('^(.+)%.([^.]+)$')
  if not stem then
    return false
  end
  if extension == 'py' then
    local module = path:gsub('^src/', ''):gsub('%.py$', ''):gsub('/', '.')
    return python_imports_module(module, line)
  end
  if extension == 'go' then
    local folder = vim.fs.basename(vim.fs.dirname(path))
    for import in line:gmatch('"([^"]+)"') do
      if vim.fs.basename(import) == folder then
        return true
      end
    end
    return false
  end
  if extension == 'java' then
    return line:find('%f[%w_]' .. vim.pesc(stem) .. '%f[^%w_]') ~= nil
  end
  if C_FAMILY[extension] then
    local included = line:match('^%s*#%s*include%s*["<]([^">]+)[">]')
    return included ~= nil
      and vim.iter(HEADER_EXTENSIONS):any(function(header)
        local name = stem .. '.' .. header
        return included == name or vim.endswith(included, '/' .. name)
      end)
  end
  if SCRIPT_FAMILY[extension] then
    return vim.iter(script_specifiers(line)):any(function(specifier)
      local last = vim.fs.basename(specifier)
      local without = last:match('^(.+)%.([^.]+)$')
      return last == stem or (without == stem and SCRIPT_FAMILY[last:match('%.([^.]+)$')] == true)
    end)
  end
  return false
end

--- The extensions a source of the same language as a file of `extension`
--- may have: the C and C++ sources and headers together, the JavaScript and
--- TypeScript ones together, else `extension` alone.
---
---@param extension string
---@return table<string, true>
function M.family(extension)
  if C_FAMILY[extension] then
    return C_FAMILY
  end
  if SCRIPT_FAMILY[extension] then
    return SCRIPT_FAMILY
  end
  return { [extension] = true }
end

--- A source a test file imports, as the test file names it: a path the
--- source's path ends with, a stem, a folder, or a path without its
--- extension; with the extensions it may have, for the last three.
---@class aineo.test_layout.Imported
---@field ends_with? string a path relative to some folder, its extension included
---@field stem? string the source's file name without its extension
---@field folder? string the name of the source's folder
---@field without_extension? string the source's path from the repository's root, without its extension
---@field extensions? table<string, true>

--- The extensions of the Go sources.
local GO_FAMILY = { go = true }

--- The sources a Python test file's `import` and `from … import` lines
--- name, by dotted module; a relative import names none.
---
---@param text string
---@return aineo.test_layout.Imported[]
local function python_imports(text)
  local found = {}
  for line in vim.gsplit(text, '\n', { plain = true }) do
    local module = line:match('^%s*from%s+([%w_%.]+)%s+import')
      or line:match('^%s*import%s+([%w_%.]+)')
    if module and not vim.startswith(module, '.') then
      table.insert(found, { ends_with = module:gsub('%.', '/') .. '.py' })
    end
  end
  return found
end

--- The packages a Go test file imports, each by the last folder of its
--- import path.
---
---@param text string
---@return aineo.test_layout.Imported[]
local function go_imports(text)
  local found = {}
  for line in vim.gsplit(text, '\n', { plain = true }) do
    local path = line:match('^%s*import%s+[%w_%.]*%s*"([^"]+)"')
      or line:match('^%s*[%w_%.]*%s*"([^"]+)"%s*$')
    if path then
      table.insert(found, { folder = vim.fs.basename(path), extensions = GO_FAMILY })
    end
  end
  return found
end

--- The classes a Java test file imports, each by its path; a static import
--- names none.
---
---@param text string
---@return aineo.test_layout.Imported[]
local function java_imports(text)
  local found = {}
  for line in vim.gsplit(text, '\n', { plain = true }) do
    local class = line:match('^%s*import%s+([%w_%.]+)%s*;')
    if class then
      table.insert(found, { ends_with = class:gsub('%.', '/') .. '.java' })
    end
  end
  return found
end

--- The headers a C or C++ test file includes in quotes, each by its stem,
--- with the sources and headers of that stem.
---
---@param text string
---@return aineo.test_layout.Imported[]
local function c_includes(text)
  local found = {}
  for header in text:gmatch('#%s*include%s*"([^"]+)"') do
    local stem = vim.fs.basename(header):match('^(.+)%.[^.]+$') or vim.fs.basename(header)
    table.insert(found, { stem = stem, extensions = C_FAMILY })
  end
  return found
end

--- The modules a JavaScript or TypeScript test file at `test` imports or
--- requires by a relative path, each resolved from the test's folder,
--- without its extension.
---
---@param test string
---@param text string
---@return aineo.test_layout.Imported[]
local function script_imports(test, text)
  local found = {}
  local function add(specifier)
    if vim.startswith(specifier, '.') then
      local path = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(test), specifier))
      local extension = path:match('%.([^./]+)$')
      if extension and SCRIPT_FAMILY[extension] then
        path = path:sub(1, -#extension - 2)
      end
      table.insert(found, { without_extension = path, extensions = SCRIPT_FAMILY })
    end
  end
  for specifier in text:gmatch('from%s*[\'"]([^\'"]+)[\'"]') do
    add(specifier)
  end
  for specifier in text:gmatch('require%(%s*[\'"]([^\'"]+)[\'"]') do
    add(specifier)
  end
  for specifier in text:gmatch('import%s*[\'"]([^\'"]+)[\'"]') do
    add(specifier)
  end
  return found
end

--- The sources `text`, the text of the test file at `test` (relative to
--- the repository's root), imports, as its language reads them: Python's
--- modules, Go's packages, Java's classes, the headers C and C++ include in
--- quotes, the relative imports of JavaScript and TypeScript; none for
--- another language. The reverse of `patterns()`.
---
---@param test string
---@param text string
---@return aineo.test_layout.Imported[]
function M.imported(test, text)
  local extension = test:match('%.([^./]+)$') or ''
  if extension == 'py' then
    return python_imports(text)
  end
  if extension == 'go' then
    return go_imports(text)
  end
  if extension == 'java' then
    return java_imports(text)
  end
  if C_FAMILY[extension] then
    return c_includes(text)
  end
  if SCRIPT_FAMILY[extension] then
    return script_imports(test, text)
  end
  return {}
end

--- Whether `path`, a file relative to the repository's root, is the source
--- `imported` names.
---
---@param path string
---@param imported aineo.test_layout.Imported
---@return boolean
function M.is_imported(path, imported)
  local stem, extension = vim.fs.basename(path):match('^(.+)%.([^.]+)$')
  if imported.ends_with then
    return path == imported.ends_with or vim.endswith(path, '/' .. imported.ends_with)
  end
  if not (extension and imported.extensions[extension]) then
    return false
  end
  if imported.stem then
    return stem == imported.stem
  end
  if imported.folder then
    return vim.fs.basename(vim.fs.dirname(path)) == imported.folder
  end
  return path:sub(1, -#extension - 2) == imported.without_extension
end

return M
