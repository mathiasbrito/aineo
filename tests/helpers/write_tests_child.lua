--- Drives the explain home in a child Neovim for the suites that write tests
--- and implementations: starts the child in a git project of its own with
--- chosen files, a stand-in of `aineo.test_layout` (`fake_test_layout.lua`)
--- in `_G.layout`, the fake `claude` recording what it is asked, and reads
--- back what the user was told.

local children = dofile('tests/helpers/child.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local M = {}

M.PATIENCE_MS = explained.PATIENCE_MS
M.FAKE_CLAUDE = explained.FAKE_CLAUDE

local CHECKOUT = vim.fn.fnamemodify('.', ':p'):gsub('/$', '')

--- The keys of written code a request maps while its proposals show.
M.KEYS = {
  accept = '\\Wa',
  reject = '\\Wr',
  diff = '\\Wd',
  accept_all = '\\WA',
  reject_all = '\\WR',
  next = ']w',
  previous = '[w',
  steer = '\\Ws',
}

--- `place` with its paths, relative to `folder`, made absolute.
---
---@param folder string
---@param place table
---@return table
local function absolute_place(folder, place)
  local function absolute(path)
    return folder .. '/' .. path
  end
  return vim.tbl_extend('force', place, {
    path = absolute(place.path),
    candidates = vim.tbl_map(absolute, place.candidates or { place.path }),
    sibling = place.sibling and absolute(place.sibling) or nil,
    companions = vim.tbl_map(absolute, place.companions or {}),
  })
end

--- `places`, keyed by paths relative to `folder`, keyed and holding paths
--- made absolute.
---
---@param folder string
---@param places table<string, table>
---@return table<string, table>
local function absolute_places(folder, places)
  local found = {}
  for path, place in pairs(places or {}) do
    found[folder .. '/' .. path] = absolute_place(folder, place)
  end
  return found
end

--- Starts `child` afresh, its screen 200 columns by 50 rows, in a git
--- project made for `name` holding `files` (lines by path from the
--- project), with the stand-in layout `layout` answers (places by path
--- from the project, as `fake_test_layout.lua` takes them) in
--- `_G.layout`, the notifications it shows kept for `told()`, and `open`
--- edited. Returns the project's folder and the record of the fake
--- `claude`.
---
---@param child table
---@param name string
---@param files table<string, string[]>
---@param layout { tests?: table, sources?: table }
---@param open string the file to edit, from the project
---@return string folder
---@return string record
function M.start(child, name, files, layout, open)
  children.restart(child, { '--cmd', 'lua vim.g.aineo = { autostart = false }' })
  child.o.columns = 200
  child.o.lines = 50
  local folder = git_repo.create_unborn(name)
  for path, lines in pairs(files) do
    git_repo.write(folder, path, lines)
  end
  local record = fixture.directory(name .. '-record') .. '/fake.jsonl'
  child.lua(
    [[
    local record, helper, spec = ...
    vim.env.AINEO_FAKE_CLAUDE_RECORD = record
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
    _G.layout = dofile(helper).new(spec)
  ]],
    {
      record,
      CHECKOUT .. '/tests/helpers/fake_test_layout.lua',
      {
        tests = absolute_places(folder, layout.tests),
        sources = absolute_places(folder, layout.sources),
      },
    }
  )
  child.cmd('edit ' .. folder .. '/' .. open)
  return folder, record
end

--- Has the fake `claude` answer a successful result whose structured output
--- is `object`.
---
---@param child table
---@param object table
function M.answer_with(child, object)
  explained.answer_with(child, object)
end

--- Types `keys` in the child and waits until it has settled.
---
---@param child table
---@param ... string
function M.press(child, ...)
  child.type_keys(...)
  vim.wait(M.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- The requests the fake `claude` recorded in `record`, decoded, once it
--- has recorded at least `count` of them, or after `PATIENCE_MS`: each its
--- arguments and what it read.
---
---@param record string
---@param count integer
---@return { argv: string[], stdin: string }[]
function M.requests(record, count)
  local lines = {}
  vim.wait(M.PATIENCE_MS, function()
    lines = vim.uv.fs_stat(record) and vim.fn.readfile(record) or {}
    return #lines >= 2 * count
  end, 20)
  local requests = {}
  for index = 1, #lines - 1, 2 do
    table.insert(requests, {
      argv = vim.json.decode(lines[index]).argv,
      stdin = vim.json.decode(lines[index + 1]).stdin,
    })
  end
  return requests
end

--- Calls the explain home's `function_name` in the child with an order of
--- the current buffer and window, the cursor's line, the stand-in layout,
--- the fake `claude`, the model `haiku`, a long timeout, the keys of
--- written code and `\WT` as what asks again, as `fields` override them.
---
---@param child table
---@param function_name string
---@param fields? table
function M.order(child, function_name, fields)
  child.lua(
    [[
    local name, fields, command, keys = ...
    require('aineo.explain')[name](vim.tbl_extend('force', {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = vim.fn.line('.'),
      layout = _G.layout,
      command = command,
      model = 'haiku',
      timeout_ms = 180000,
      keys = keys,
      ask_key = '\\WT',
    }, fields))
  ]],
    { function_name, fields or vim.empty_dict(), M.FAKE_CLAUDE, M.KEYS }
  )
end

--- Waits until `predicate`, a Lua expression the child evaluates, is true,
--- or `PATIENCE_MS` is over; returns its last value.
---
---@param child table
---@param predicate string
---@return any
function M.wait_until(child, predicate)
  local value
  vim.wait(M.PATIENCE_MS, function()
    value = child.lua_get(predicate)
    return value
  end, 20)
  return value
end

--- What the child was told through `vim.notify()` since `start()`, the
--- messages alone.
---
---@param child table
---@return string[]
function M.told(child)
  return vim.tbl_map(function(entry)
    return entry.message
  end, child.lua_get('_G.told'))
end

return M
