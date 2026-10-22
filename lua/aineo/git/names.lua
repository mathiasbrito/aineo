--- The names that point at commits: the branches, remote-tracking branches
--- and tags whose tip is exactly a commit.

local process = require('aineo.git.process')

local M = {}

--- The kinds of reference that name a commit, in the order their names are
--- listed, each with the prefix of its full name.
---@type { prefix: string }[]
local KINDS = {
  { prefix = 'refs/heads/' },
  { prefix = 'refs/remotes/' },
  { prefix = 'refs/tags/' },
}

--- What `git for-each-ref` is asked to print for each reference: its full
--- name, the id of the object it names, the id of the commit an annotated tag
--- points at, and the reference a symbolic one points to.
local FORMAT = '--format=%(refname)%00%(objectname)%00%(*objectname)%00%(symref)'

--- The names `git for-each-ref` gave as `output`, for the commits `ids`: a
--- line each, the fields of `FORMAT` NUL separated. Each commit's names are
--- grouped by kind (`KINDS`), those of a kind in git's order; a symbolic
--- reference, a remote's `HEAD`, is left out, as it only repeats a branch,
--- while a branch or tag whose name ends in `/HEAD` is named. A name holds
--- no line break, which git refuses in one.
---
---@param output string
---@param ids string[]
---@return table<string, string[]>
local function parse_references(output, ids)
  local wanted = {}
  for _, id in ipairs(ids) do
    wanted[id] = true
  end
  local by_kind = {}
  for _, line in ipairs(vim.split(output, '\n', { plain = true, trimempty = true })) do
    local reference, object, peeled, symbolic = line:match('^(.-)%z(%x+)%z(%x*)%z(.*)$')
    local id = wanted[peeled] and peeled or object
    if reference and wanted[id] and symbolic == '' then
      for kind_index, kind in ipairs(KINDS) do
        if vim.startswith(reference, kind.prefix) then
          by_kind[id] = by_kind[id] or { {}, {}, {} }
          table.insert(by_kind[id][kind_index], reference:sub(#kind.prefix + 1))
        end
      end
    end
  end
  local names = {}
  for id, kinds in pairs(by_kind) do
    names[id] = vim.list_extend(vim.list_extend(kinds[1], kinds[2]), kinds[3])
  end
  return names
end

--- Reads the names of the commits `ids`, full ids, in `found`, with one
--- `git for-each-ref`, and calls `done(nil, names)`: for each commit with
--- any, its local branches, then its remote-tracking branches, then its
--- tags (an annotated tag names the commit it tags), each kind in name
--- order, each by its name without the kind's prefix; a remote's `HEAD`, a
--- symbolic reference, is left out, and so is every other reference. A commit nothing points at
--- has no entry. With no commit asked about, git is not run. Calls
--- `done(failure)` when git fails.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param ids string[]
---@param done fun(failure: aineo.git.Failure|nil, names: table<string, string[]>|nil)
function M.names_at(run, found, ids, done)
  if #ids == 0 then
    done(nil, {})
    return
  end
  local arguments = { 'for-each-ref', FORMAT }
  for _, id in ipairs(ids) do
    table.insert(arguments, '--points-at=' .. id)
  end
  run(
    { directory = found.top, arguments = arguments },
    process.or_fail(done, function(output)
      done(nil, parse_references(output.stdout, ids))
    end)
  )
end

return M
