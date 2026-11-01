--- How a test file of each language imports the sources it tests — an
--- import, an include — read both ways: the test files that import a
--- source, when no template pairs it with one, and the sources a test file
--- imports, when no rule gives it a source.

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

--- The extensions of the Go sources.
local GO_FAMILY = { go = true }

--- The headers a C or C++ source may be included by.
local HEADER_EXTENSIONS = { h = true, hpp = true, hh = true }

--- `path` without its extension, and the extension; the path whole and nil
--- when its file name has none.
---
---@param path string
---@return string without
---@return string? extension
local function split_extension(path)
  local without, extension = path:match('^(.*[^/])%.([^./]+)$')
  if not without then
    return path, nil
  end
  return without, extension
end

--- The fixed strings to search for the test files that may import `path`,
--- a source relative to the root of its unit, by language: the stem for
--- Python, Java, JavaScript and TypeScript, the end of a Go import path
--- (`<package folder>"`), the stem's headers for C and C++; none for
--- another language. Each file found is then read by `imports()`.
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
    return { stem .. '.h', stem .. '.hpp', stem .. '.hh' }
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
--- source's path ends with, a folder, a path without its extension, or an
--- include, written and resolved; with the extensions it may have.
---@class aineo.test_layout.Imported
---@field ends_with? string a path relative to some folder, its extension included
---@field folder? string the name of the source's folder
---@field without_extension? string the source's path from the repository's root, without its extension
---@field included? string the path a quoted `#include` names, without its extension
---@field resolved? string that path from the test's folder, without its extension
---@field extensions? table<string, true>

--- The modules a Python test imports: `import a.b, c` names `a/b.py` and
--- `c.py`; `from m import x, y` names `m.py`, `m/x.py` and `m/y.py`; a
--- relative import names none.
---
---@param text string
---@return aineo.test_layout.Imported[]
local function python_imports(text)
  local found = {}
  local function add(module)
    if module ~= '' and not vim.startswith(module, '.') then
      table.insert(found, { ends_with = module:gsub('%.', '/') .. '.py' })
    end
  end
  for line in vim.gsplit(text, '\n', { plain = true }) do
    local from, listed = line:match('^%s*from%s+([%w_%.]+)%s+import%s+(.+)$')
    listed = listed or line:match('^%s*import%s+(.+)$')
    if from and not vim.startswith(from, '.') then
      add(from)
    end
    for item in (listed or ''):gsub('[()]', ''):gmatch('[^,]+') do
      local name = vim.trim(item):match('^([%w_%.]+)')
      if name and from and not vim.startswith(from, '.') then
        add(from .. '.' .. name)
      elseif name and not from then
        add(name)
      end
    end
  end
  return found
end

--- The packages a Go test imports — on an `import "…"` line, or a line of
--- an `import ( … )` block — each by the last folder of its import path. A
--- quoted string anywhere else names none.
---
---@param text string
---@return aineo.test_layout.Imported[]
local function go_imports(text)
  local found = {}
  local in_block = false
  for line in vim.gsplit(text, '\n', { plain = true }) do
    local path
    if in_block then
      if line:match('^%s*%)') then
        in_block = false
      else
        path = line:match('^%s*[%w_%.]*%s*"([^"]+)"')
      end
    elseif line:match('^%s*import%s*%(') then
      in_block = true
    else
      path = line:match('^%s*import%s+[%w_%.]*%s*"([^"]+)"')
    end
    if path then
      table.insert(found, { folder = vim.fs.basename(path), extensions = GO_FAMILY })
    end
  end
  return found
end

--- The classes a Java test imports, each by its path; a static import
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

--- The headers a C or C++ test at `test` includes in quotes, each as
--- written and resolved from the test's folder, without its extension; an
--- include in angle brackets names none.
---
---@param test string
---@param text string
---@return aineo.test_layout.Imported[]
local function c_includes(test, text)
  local found = {}
  for line in vim.gsplit(text, '\n', { plain = true }) do
    local header = line:match('^%s*#%s*include%s*"([^"]+)"')
    local included, extension = split_extension(header or '')
    if header and HEADER_EXTENSIONS[extension] then
      table.insert(found, {
        included = included,
        resolved = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(test), included)),
        extensions = C_FAMILY,
      })
    end
  end
  return found
end

--- The modules a JavaScript or TypeScript test at `test` imports or
--- requires by a relative path (`./`, `../`), each resolved from the test's
--- folder, without its extension; a bare specifier, a package or a
--- built-in, names none.
---
---@param test string
---@param text string
---@return aineo.test_layout.Imported[]
local function script_imports(test, text)
  local found = {}
  local function add(specifier)
    if vim.startswith(specifier, './') or vim.startswith(specifier, '../') then
      local path = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(test), specifier))
      local without, extension = split_extension(path)
      table.insert(found, {
        without_extension = SCRIPT_FAMILY[extension or ''] and without or path,
        extensions = SCRIPT_FAMILY,
      })
    end
  end
  for _, pattern in ipairs({
    'from%s*[\'"]([^\'"]+)[\'"]',
    'require%(%s*[\'"]([^\'"]+)[\'"]',
    'import%s*%(?%s*[\'"]([^\'"]+)[\'"]',
  }) do
    for specifier in text:gmatch(pattern) do
      add(specifier)
    end
  end
  return found
end

--- The sources `text`, the text of the test file at `test` (relative to
--- the repository's root), imports, as its language writes an import:
--- Python's modules, Go's packages, Java's classes, the headers C and C++
--- include in quotes, the relative imports of JavaScript and TypeScript;
--- none for another language.
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
    return c_includes(test, text)
  end
  if SCRIPT_FAMILY[extension] then
    return script_imports(test, text)
  end
  return {}
end

--- Whether `path`, a file relative to the repository's root, is the source
--- `imported` names: its path ends with the path named; or it is of the
--- extensions named and is in the folder named, is the path named without
--- its extension or that folder's `index`, or is the header included,
--- resolved from the test's folder or ending the source's path.
---
---@param path string
---@param imported aineo.test_layout.Imported
---@return boolean
function M.is_imported(path, imported)
  if imported.ends_with then
    return path == imported.ends_with or vim.endswith(path, '/' .. imported.ends_with)
  end
  local without, extension = split_extension(path)
  if not (extension and imported.extensions[extension]) then
    return false
  end
  if imported.folder then
    return vim.fs.basename(vim.fs.dirname(path)) == imported.folder
  end
  if imported.included then
    return without == imported.resolved
      or without == imported.included
      or vim.endswith(without, '/' .. imported.included)
  end
  return without == imported.without_extension or without == imported.without_extension .. '/index'
end

--- Whether the test file at `test`, of text `text`, imports `source`, both
--- relative to the repository's root (`imported()`, `is_imported()`); a
--- Java test also when it names the source's class as a whole word, as a
--- test of the same package does without an import.
---
---@param source string
---@param test string
---@param text string
---@return boolean
function M.imports(source, test, text)
  local stem, extension = vim.fs.basename(source):match('^(.+)%.([^.]+)$')
  if extension == 'java' and text:find('%f[%w_]' .. vim.pesc(stem) .. '%f[^%w_]') then
    return true
  end
  return vim.iter(M.imported(test, text)):any(function(imported)
    return M.is_imported(source, imported)
  end)
end

return M
