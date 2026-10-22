--- Drives the explain home in a child Neovim for the suites that work on what
--- an answer left on screen: starts the child with a file in a project of its
--- own, has the fake `claude` answer explanations or issues for chosen lines,
--- asks for them, and reads back what the user was told.

local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local M = {}

--- How long a case waits for the child to reach a state, in milliseconds.
M.PATIENCE_MS = 10000

local CHECKOUT = vim.fn.fnamemodify('.', ':p'):gsub('/$', '')

--- The fake `claude`, run in the real one's place.
M.FAKE_CLAUDE = { 'sh', CHECKOUT .. '/tests/helpers/fake_claude_print.sh' }

--- The namespaces of the two kinds of answer, by the name of the kind.
local NAMESPACES = { explanations = 'aineo_explain', issues = 'aineo_explain_issues' }

--- How many answers have been made, so that each is read from a file of its own.
local answers_made = 0

--- Starts `child` afresh, its screen 80 columns wide, with the file
--- `src/code.lua` of `lines` open in a git project made for `name`, `aineo`
--- configured as `config` says before the plugin maps its keys, and the notifications it shows kept for
--- `told()`. Returns the project's folder.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param name string the project's name, unique to the suite
---@param lines string[] the file's lines
---@param config? table more of `vim.g.aineo`
---@return string folder
function M.start(child, name, lines, config)
  local settings = vim.tbl_deep_extend('force', { autostart = false }, config or {})
  children.restart(child, { '--cmd', 'lua vim.g.aineo = ' .. vim.inspect(settings) })
  child.o.columns = 80
  child.o.lines = 40
  local folder = git_repo.create_unborn(name)
  git_repo.write(folder, 'src/code.lua', lines)
  local record = fixture.directory(name .. '-record') .. '/fake.jsonl'
  child.lua(
    [[
    vim.env.AINEO_FAKE_CLAUDE_RECORD = ...
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
  ]],
    { record }
  )
  child.cmd('edit ' .. folder .. '/src/code.lua')
  return folder
end

--- Has the fake `claude` answer a successful result whose structured output
--- holds `explanations`, from a file of its own.
---
---@param child table
---@param explanations { line: integer, text: string }[]
local function answer(child, explanations)
  answers_made = answers_made + 1
  local path =
    fixture.write(('explain-child/answer-%d-%d.json'):format(vim.fn.getpid(), answers_made), {
      vim.json.encode({
        type = 'result',
        subtype = 'success',
        is_error = false,
        result = '',
        structured_output = { explanations = explanations },
      }),
    })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT = ...', { path })
end

M.answer = answer

--- How many extmarks the child holds in the namespace of `kind` that show an
--- answer, and how many that say a request is working.
---
---@param child table
---@param kind 'explanations'|'issues'
---@return integer shown
---@return integer working
local function counts(child, kind)
  local found = child.lua(
    [[
    local namespace = vim.api.nvim_get_namespaces()[...]
    local shown, working = 0, 0
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace or -1, 0, -1, { details = true })) do
      if vim.inspect(mark[4].virt_lines):find('…', 1, true) then
        working = working + 1
      else
        shown = shown + 1
      end
    end
    return { shown, working }
  ]],
    { NAMESPACES[kind] }
  )
  return found[1], found[2]
end

--- Asks the explain home, afresh, about the lines `range` names of the
--- child's current buffer, or all of them, for `kind`, with the fake `claude`.
---
---@param child table
---@param kind 'explanations'|'issues'
---@param range? integer[] the first and last line
local function ask(child, kind, range)
  child.lua(
    [[
    local kind, command, range = ...
    require('aineo.explain').ask({
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      range = range,
      tools = false,
      kind = kind,
      fresh = true,
      command = command,
      model = 'sonnet',
      timeout_ms = 180000,
    })
  ]],
    { kind, M.FAKE_CLAUDE, range }
  )
end

--- Has the fake `claude` answer `found`, each a line and a text, asks the
--- explain home about the lines `range` names of the child's current
--- buffer, or all of them, for `kind`, and waits until the request has
--- ended and the child shows at least one virtual line for each answer, or
--- `PATIENCE_MS` is over.
---
---@param child table
---@param kind 'explanations'|'issues'
---@param found { line: integer, text: string }[]
---@param range? integer[] the first and last line
function M.place(child, kind, found, range)
  answer(child, found)
  ask(child, kind, range)
  vim.wait(M.PATIENCE_MS, function()
    local shown, working = counts(child, kind)
    return shown >= #found and working == 0
  end, 20)
end

--- Waits until the child shows at least `count` virtual lines of `kind` and
--- none says a request is working, or `PATIENCE_MS` is over.
---
---@param child table
---@param kind 'explanations'|'issues'
---@param count integer
function M.wait_for(child, kind, count)
  vim.wait(M.PATIENCE_MS, function()
    local shown, working = counts(child, kind)
    return shown >= count and working == 0
  end, 20)
end

--- Has the fake `claude` answer `found` after `delay_ms`, and asks the
--- explain home about the child's current buffer for `kind`, without waiting
--- for the answer: the request runs for `delay_ms`.
---
---@param child table
---@param kind 'explanations'|'issues'
---@param found { line: integer, text: string }[]
---@param delay_ms integer
function M.begin_slowly(child, kind, found, delay_ms)
  answer(child, found)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = ...', { tostring(delay_ms) })
  ask(child, kind)
end

--- The floating windows of the child, each as the part of its configuration
--- that matters, its text and the 'winhighlight' it shows with.
---
---@param child table
---@return { win: integer, anchor: string, row: integer, col: integer, text: string, winhighlight: string }[]
function M.floats(child)
  return child.lua_get([[(function()
    local floats = {}
    for _, window in ipairs(vim.api.nvim_list_wins()) do
      local config = vim.api.nvim_win_get_config(window)
      if config.relative ~= '' then
        table.insert(floats, {
          win = config.win,
          anchor = config.anchor,
          row = config.row,
          col = config.col,
          text = table.concat(
            vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false),
            '\n'
          ),
          winhighlight = vim.wo[window].winhighlight,
        })
      end
    end
    return floats
  end)()]])
end

--- The text of the child's only floating window once `predicate` holds for
--- it, or after `PATIENCE_MS`; an empty string when there is none.
---
---@param child table
---@param predicate fun(text: string): boolean
---@return string
function M.badge_text_once(child, predicate)
  local text = ''
  vim.wait(M.PATIENCE_MS, function()
    local floats = M.floats(child)
    text = floats[1] and floats[1].text or ''
    return predicate(text)
  end, 20)
  return text
end

--- What the child was told through `vim.notify()` since `start()`: each
--- message and its level.
---
---@param child table
---@return { message: string, level: integer }[]
function M.told(child)
  return child.lua_get('_G.told')
end

return M
