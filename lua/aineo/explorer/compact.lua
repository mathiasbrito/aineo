--- The explorer's compact chains: a folder whose only entry, as the tree
--- shows it, is a folder shows on one line with it, `a/b/c/`, and so on down
--- the chain.

local M = {}

--- The chain of folders that shows on the line of `folder`: `folder`, then
--- the only entry it shows while that is a folder, then that folder's, down
--- to the first folder that shows no entry, more than one, or a file.
---
---@param folder aineo.explorer.Entry a folder
---@param shown_entries fun(path: string): aineo.explorer.Entry[] the entries of a folder as the tree shows them
---@return aineo.explorer.Entry[] chain from `folder` down, at least `folder`
function M.chain(folder, shown_entries)
  local chain = { folder }
  local current = folder
  while true do
    local entries = shown_entries(current.path)
    if #entries ~= 1 or entries[1].kind ~= 'folder' then
      return chain
    end
    current = entries[1]
    table.insert(chain, current)
  end
end

--- The name `chain` shows as: the names of its folders, `quote`d, joined by
--- `/`.
---
---@param chain aineo.explorer.Entry[]
---@param quote fun(name: string): string
---@return string
function M.label(chain, quote)
  return table.concat(
    vim.tbl_map(function(folder)
      return quote(folder.name)
    end, chain),
    '/'
  )
end

return M
