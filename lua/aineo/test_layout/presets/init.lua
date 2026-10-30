--- The catalogue of known test layouts, one file of presets per language:
--- each preset's rules, discovery globs, marker files and documentation,
--- and each language's default.

local M = {}

--- The languages, in the catalogue's order.
local LANGUAGES = {
  require('aineo.test_layout.presets.python'),
  require('aineo.test_layout.presets.javascript'),
  require('aineo.test_layout.presets.go'),
  require('aineo.test_layout.presets.java'),
  require('aineo.test_layout.presets.c'),
  require('aineo.test_layout.presets.cpp'),
}

--- Every preset, language after language.
---@type aineo.test_layout.Preset[]
M.presets = {}
for _, language in ipairs(LANGUAGES) do
  vim.list_extend(M.presets, language.presets)
end

--- Whether `language` has a preset for sources of `extension`.
---
---@param language { presets: aineo.test_layout.Preset[] }
---@param extension string
---@return boolean
local function covers(language, extension)
  return vim.iter(language.presets):any(function(preset)
    return vim.tbl_contains(preset.extensions, extension)
  end)
end

--- Whether `view`'s repository has a file under the folder `folder` of its
--- root.
---
---@param view aineo.test_layout.View
---@param folder string
---@return boolean
local function has_folder(view, folder)
  return vim.iter(view.files):any(function(file)
    return vim.startswith(file, folder .. '/')
  end)
end

--- The ids of the default presets of the language of `extension`, for
--- `view`'s repository: the first of the language's defaults whose folder,
--- when it names one, the repository has; none for a language with no
--- preset.
---
---@param extension string
---@param view aineo.test_layout.View
---@return string[]
function M.defaults(extension, view)
  for _, language in ipairs(LANGUAGES) do
    if covers(language, extension) then
      for _, default in ipairs(language.defaults) do
        if not default.folder or has_folder(view, default.folder) then
          return { default.id }
        end
      end
    end
  end
  return {}
end

--- The ids of every preset, in the catalogue's order.
---
---@return string[]
function M.ids()
  return vim.tbl_map(function(preset)
    return preset.id
  end, M.presets)
end

return M
