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

--- The fixed strings a test file holds when it names `path`, a source
--- relative to the root of its unit, by language: Python's dotted module
--- (`src/` dropped), the end of a Go import path (`/<package folder>"`),
--- a Java class's name, a C or C++ `#include` of the stem's header, and a
--- JavaScript or TypeScript import path that ends in the stem; none for
--- another language.
---
---@param path string
---@return string[]
function M.patterns(path)
  local stem, extension = vim.fs.basename(path):match('^(.+)%.([^.]+)$')
  if not stem then
    return {}
  end
  if extension == 'py' then
    local module = path:gsub('^src/', ''):gsub('%.py$', ''):gsub('/', '.')
    return { module }
  end
  if extension == 'go' then
    local folder = vim.fs.dirname(path)
    return folder ~= '.' and { '/' .. vim.fs.basename(folder) .. '"' } or {}
  end
  if extension == 'java' then
    return { stem }
  end
  if C_FAMILY[extension] then
    return { stem .. '.h"', stem .. '.hpp"' }
  end
  if SCRIPT_FAMILY[extension] then
    return { '/' .. stem .. "'", '/' .. stem .. '"' }
  end
  return {}
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
