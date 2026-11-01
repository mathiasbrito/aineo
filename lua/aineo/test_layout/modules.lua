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

--- The name `require` takes for the Lua source `path`, relative to the
--- root of its unit: its path below `lua/` or `src/`, without the
--- extension and with dots for slashes, a folder's `init.lua` by the
--- folder's name; nil when that leaves no name.
---
---@param path string
---@return string?
local function lua_module_name(path)
  local below = path:gsub('^lua/', ''):gsub('^src/', ''):gsub('%.lua$', ''):gsub('/init$', '')
  return below ~= 'init' and (below:gsub('/', '.')) or nil
end

--- The fixed strings to search for the test files that may import `path`,
--- a source relative to the root of its unit, by language: the stem for
--- Python, Java, JavaScript and TypeScript, the end of a Go import path
--- (`<package folder>"`), the stem's headers for C and C++, the name
--- `require` takes for Lua; none for another language. Each file found is
--- then read by `imports()`.
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
  if extension == 'lua' then
    local name = lua_module_name(path)
    return name and { name } or {}
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
---@field lua_module? string a Lua module's path, `a/b/c`: the source's path ends with `a/b/c.lua` or `a/b/c/init.lua`
---@field outside? string a top folder whose files are not the source, such as the folder of the tests

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

--- Where the long bracket opened at `position` of `text` (`[[`, `[=[`…)
--- ends: the position after its closer, or after the text when it is not
--- closed, with its content; nil when none opens there.
---
---@param text string
---@param position integer
---@return integer? after
---@return string? content
local function long_bracket_end(text, position)
  local level = text:match('^%[(=*)%[', position)
  if not level then
    return nil
  end
  local opened = position + #level + 2
  local closer = text:find(']' .. level .. ']', opened, true)
  if not closer then
    return #text + 1, text:sub(opened)
  end
  return closer + #level + 2, text:sub(opened, closer - 1)
end

--- Where the quoted string opened at `position` of `text` ends: the
--- position after its closing quote, or at the end of its line when it is
--- not closed there; with its content.
---
---@param text string
---@param position integer
---@return integer after
---@return string content
local function quoted_end(text, position)
  local quote = text:sub(position, position)
  local at = position + 1
  while true do
    local stop = text:find('[\\\n' .. quote .. ']', at)
    if not stop or text:sub(stop, stop) == '\n' then
      local after = stop or #text + 1
      return after, text:sub(position + 1, after - 1)
    end
    if text:sub(stop, stop) == quote then
      return stop + 1, text:sub(position + 1, stop - 1)
    end
    at = stop + 2
  end
end

--- Where a Lua string literal begins at `position` of `text`: its content
--- and the position after it; nil when no string begins there.
---
---@param text string
---@param position integer
---@return string? content
---@return integer? after
local function string_literal_at(text, position)
  local first = text:sub(position, position)
  if first == '"' or first == "'" then
    local after, content = quoted_end(text, position)
    return content, after
  end
  local after, content = long_bracket_end(text, position)
  return content, after
end

--- The literal module name `require` takes when `position` follows the
--- word in `text`: `require 'a.b'`, `require("a.b")`, `require [[a.b]]`,
--- with a literal alone between the parentheses; nil for any other
--- argument or a name that is no module path.
---
---@param text string
---@param position integer
---@return string?
local function required_name_at(text, position)
  local at = text:find('%S', position) or #text + 1
  local parenthesised = text:sub(at, at) == '('
  if parenthesised then
    at = text:find('%S', at + 1) or #text + 1
  end
  local name, after = string_literal_at(text, at)
  if not name then
    return nil
  end
  if parenthesised and text:sub(text:find('%S', after) or #text + 1):sub(1, 1) ~= ')' then
    return nil
  end
  return name:match('^[%w_%-]+[%w_%-%.]*$') and name or nil
end

--- The modules a Lua test at `test` requires by a literal name, each as
--- the path the source's path ends with, as a file (`a/b/c.lua`) or as a
--- folder's `init.lua` (`lua_module`), each with the top folder of the test's unit it
--- sits in (`outside`); a `require` in a comment or a string, called as a
--- field or a method, or with any other argument, names none.
---
---@param test string
---@param text string
---@param unit string the folder of the unit the test belongs to, `''` for the repository's root
---@return aineo.test_layout.Imported[]
local function lua_imports(test, text, unit)
  local found = {}
  local in_unit = unit == '' and test or test:sub(#unit + 2)
  local top = in_unit:match('^([^/]+)/')
  top = top and (unit == '' and top or unit .. '/' .. top)
  local position = 1
  while position <= #text do
    local word_start, word_end = text:find('^[%a_][%w_]*', position)
    local first = text:sub(position, position)
    if text:find('^%-%-', position) then
      position = long_bracket_end(text, position + 2)
        or (text:find('\n', position, true) or #text) + 1
    elseif first == '"' or first == "'" then
      position = quoted_end(text, position)
    elseif long_bracket_end(text, position) then
      position = long_bracket_end(text, position)
    elseif word_start then
      local before = text:sub(position - 1, position - 1)
      local name = text:sub(word_start, word_end) == 'require'
        and before ~= '.'
        and before ~= ':'
        and required_name_at(text, word_end + 1)
      if name then
        table.insert(found, { lua_module = (name:gsub('%.', '/')), outside = top })
      end
      position = word_end + 1
    else
      position = position + 1
    end
  end
  return found
end

--- Every source `text`, the text of the test file at `test`, imports, as
--- its language writes an import, in the order of the text.
---
---@param test string
---@param text string
---@param unit string
---@return aineo.test_layout.Imported[]
local function read_imports(test, text, unit)
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
  if extension == 'lua' then
    return lua_imports(test, text, unit)
  end
  return {}
end

--- The most distinct imports of one test file that are read.
local MOST_IMPORTS = 64

--- What tells two imports apart: the path, folder or module each names.
---
---@param imported aineo.test_layout.Imported
---@return string
local function import_key(imported)
  return table.concat({
    imported.ends_with or '',
    imported.lua_module or '',
    imported.folder or '',
    imported.without_extension or '',
    imported.included or '',
    imported.resolved or '',
  }, '\0')
end

--- The first `most` of `imports` that differ from every one before them.
---
---@param imports aineo.test_layout.Imported[]
---@param most integer
---@return aineo.test_layout.Imported[]
local function first_distinct(imports, most)
  local kept, seen = {}, {}
  for _, imported in ipairs(imports) do
    local key = import_key(imported)
    if not seen[key] then
      seen[key] = true
      table.insert(kept, imported)
      if #kept == most then
        break
      end
    end
  end
  return kept
end

--- The sources `text`, the text of the test file at `test` (relative to
--- the repository's root), imports, as its language writes an import:
--- Python's modules, Go's packages, Java's classes, the headers C and C++
--- include in quotes, the relative imports of JavaScript and TypeScript,
--- the literal `require` of Lua; none for another language. Each differs
--- from the others, and only the first 64 are given, so that a crafted
--- test file cannot make the search for its sources run long.
---
---@param test string
---@param text string
---@param unit? string the folder of the unit the test belongs to, `''` (the default) for the repository's root
---@return aineo.test_layout.Imported[]
function M.imported(test, text, unit)
  return first_distinct(read_imports(test, text, unit or ''), MOST_IMPORTS)
end

--- Whether `path`, a file relative to the repository's root, is the source
--- `imported` names: its path ends with the path named, or with the
--- Lua module's path as a file or as a folder's `init.lua`; or it is of the
--- extensions named and is in the folder named, is the path named without
--- its extension or that folder's `index`, or is the header included,
--- resolved from the test's folder or ending the source's path.
---
---@param path string
---@param imported aineo.test_layout.Imported
---@return boolean
function M.is_imported(path, imported)
  if imported.lua_module then
    local file = imported.lua_module .. '.lua'
    local folder_init = imported.lua_module .. '/init.lua'
    return path == file
      or path == folder_init
      or vim.endswith(path, '/' .. file)
      or vim.endswith(path, '/' .. folder_init)
  end
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

--- Whether `path`, a file relative to the repository's root, is the source
--- `imported` names (`is_imported()`) and no file of the folder the test
--- sits in (`outside`): a helper the test requires is not the code under
--- test.
---
---@param path string
---@param imported aineo.test_layout.Imported
---@return boolean
function M.is_imported_source(path, imported)
  local in_tests_folder = imported.outside ~= nil and vim.startswith(path, imported.outside .. '/')
  return not in_tests_folder and M.is_imported(path, imported)
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
