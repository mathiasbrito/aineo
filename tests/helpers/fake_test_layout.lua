--- A stand-in of `aineo.test_layout`, built in a child Neovim from tables of
--- places, for the suites that write tests and implementations: it answers
--- where a source's test file is, and a test file's source, from the tables
--- it was given, and records each correction the user makes.

local M = {}

--- What the stand-in answers, by absolute path.
---@class tests.FakeTestLayoutSpec
---@field tests table<string, table> the place `test_for()` answers for each source
---@field sources table<string, table> the place `source_for()` answers for each test file

--- A stand-in that answers from `spec`: `test_for()` and `source_for()` a
--- copy of the place given for the path, `nil` and a problem for any other;
--- `is_test()` whether `spec.sources` names the path; `correct()` records
--- each pair it is given in `corrected`, and from then on answers the test
--- file given for that source, existing when it is on disk, but refuses,
--- with a problem, a test file in a folder named `outside`, and keeps one
--- in a folder named `lost` while placing none for that source from then
--- on; `describe()` a
--- line naming the rule of the place; `forget()` records each repository
--- root it is given in `forgotten`.
---
---@param spec tests.FakeTestLayoutSpec
---@return table
function M.new(spec)
  local layout = { corrected = {}, forgotten = {} }
  function layout.test_for(path)
    local place = spec.tests[path]
    if not place then
      return nil, 'no rule pairs ' .. path
    end
    return vim.deepcopy(place)
  end
  function layout.source_for(path)
    local place = spec.sources[path]
    if not place then
      return nil, 'no rule pairs ' .. path
    end
    return vim.deepcopy(place)
  end
  function layout.is_test(path)
    return spec.sources[path] ~= nil
  end
  function layout.correct(source, test)
    if test:find('/outside/', 1, true) then
      return false, test .. ' is outside the worktree of its source'
    end
    table.insert(layout.corrected, { source, test })
    if test:find('/lost/', 1, true) then
      spec.tests[source] = nil
      return true
    end
    spec.tests[source] = vim.tbl_extend('force', spec.tests[source] or {}, {
      path = test,
      exists = vim.uv.fs_stat(test) ~= nil,
      candidates = { test },
      origin = 'user',
      rule = 'the user',
    })
    return true
  end
  function layout.forget(repository_root)
    table.insert(layout.forgotten, repository_root)
  end
  function layout.describe(path)
    local place = spec.tests[path] or spec.sources[path]
    return place and ('%s (%s)'):format(place.rule or 'fake rule', place.origin or 'preset')
      or 'no rule'
  end
  return layout
end

return M
