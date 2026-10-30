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

return M
