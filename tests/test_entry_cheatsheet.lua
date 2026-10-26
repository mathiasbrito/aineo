local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.o.termguicolors = true
    end,
    post_once = stop_the_child,
  },
})

--- What `:Aineo cheatsheet` tells the user when no aineo tab exists.
local NO_TAB = 'aineo: there is no aineo tab to show the cheatsheet in'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `cheatsheet-`
---@param settings? table more of `vim.g.aineo`
local function open_layout(name, settings)
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- The window of the cheatsheet in the child, `nil` when none shows.
---
---@return integer|nil
local function sheet_window()
  return child.lua_get([[(function()
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype == 'aineo-cheatsheet'
    end)
  end)()]])
end

--- The window of the office in the child, `nil` when none shows.
---
---@return integer|nil
local function office_window()
  return child.lua_get([[(function()
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype == 'aineo-office'
    end)
  end)()]])
end

--- The text of the cheatsheet in the child, its lines joined by newlines.
---
---@return string
local function sheet_text()
  return child.lua_get(
    [[table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false), '\n')]],
    { sheet_window() }
  )
end

--- Whether the cheatsheet is gone from the child, once its window has had
--- the time to close.
---
---@return boolean
local function sheet_has_closed()
  return layout.wait_until(
    child,
    [[vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(window)
    return vim.bo[vim.api.nvim_win_get_buf(window)].filetype ~= 'aineo-cheatsheet'
  end)]]
  )
end

--- Each way to ask for the cheatsheet, as a set's `parametrize`: its name,
--- and the function that asks.
local DOORS = {
  {
    'the command :Aineo cheatsheet',
    function()
      entry.command(child, 'Aineo cheatsheet')
    end,
  },
  {
    'pressing <Plug>(aineo-cheatsheet)',
    function()
      entry.press(child, '<Plug>(aineo-cheatsheet)')
    end,
  },
  {
    'pressing \\?',
    function()
      entry.press(child, '\\?')
    end,
  },
}

T['showing the cheatsheet'] = MiniTest.new_set({ parametrize = DOORS })

T['showing the cheatsheet']['opens a window over exactly the cells of the right column'] = function(
  _,
  ask
)
  open_layout('cheatsheet-covers')
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  ask()

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { sheet_window() })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
end

T['showing the cheatsheet']['moves the cursor into it'] = function(_, ask)
  open_layout('cheatsheet-cursor')

  ask()

  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), sheet_window())
end

T['showing the cheatsheet']['closes it when it is asked for again, the cursor back where it was'] = function(
  _,
  ask
)
  open_layout('cheatsheet-twice')
  local before = child.lua_get([[vim.api.nvim_get_current_win()]])

  ask()
  ask()

  eq(sheet_window(), vim.NIL)
  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), before)
end

T['showing the cheatsheet']['tells the user when there is no aineo tab, and shows nothing'] = function(
  _,
  ask
)
  ask()

  eq(entry.messages(child), { { message = NO_TAB, level = vim.log.levels.WARN } })
  eq(sheet_window(), vim.NIL)
end

T['closing the cheatsheet'] =
  MiniTest.new_set({ parametrize = { { 'q' }, { '<Esc>' }, { '\\?' } } })

T['closing the cheatsheet']['by a key gives the right column back as it was, with the cursor where it was'] = function(
  key
)
  open_layout('cheatsheet-restores')
  local before = child.lua_get(entry.WINDOWS)
  local cursor = child.lua_get([[vim.api.nvim_get_current_win()]])
  entry.press(child, '\\?')

  child.type_keys(key)

  eq(sheet_has_closed(), true)
  eq(child.lua_get(entry.WINDOWS), before)
  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), cursor)
end

T['the keys on the sheet'] = MiniTest.new_set()

--- The keys the sheet's text shows for the prefix mappings of `child`: every
--- Normal-mode mapping of the child whose right-hand side is an aineo
--- `<Plug>` mapping, as `lhs` and `plug`, but those of the tab keys 2 to 8,
--- which the sheet shows as the range `\1…\9`.
---
---@return { lhs: string, plug: string }[]
local function mapped_to_aineo()
  return child.lua_get([[(function()
    local mapped = {}
    for _, mapping in ipairs(vim.api.nvim_get_keymap('n')) do
      local plug = (mapping.rhs or ''):match('^<Plug>%(aineo%-(.+)%)$')
      if plug and not plug:match('^tab%-[2-8]$') then
        table.insert(mapped, { lhs = mapping.lhs, plug = plug })
      end
    end
    return mapped
  end)()]])
end

T['the keys on the sheet']['show every key aineo maps'] = function()
  open_layout('cheatsheet-all-mapped')
  local mapped = mapped_to_aineo()
  entry.press(child, '\\?')
  local text = sheet_text()

  local missing = vim.tbl_filter(function(mapping)
    return not text:find(mapping.lhs, 1, true)
  end, mapped)

  eq(#mapped > 30, true)
  eq(missing, {})
end

T['the keys on the sheet']['are each mapped, for every key of the sheet that aineo maps itself'] = function()
  open_layout('cheatsheet-all-listed')

  local unmapped = child.lua_get([[(function()
    local unmapped = {}
    for _, row in ipairs(require('aineo.keys').rows()) do
      if row.scope == 'global' then
        for mode in row.modes:gmatch('.') do
          local rhs = vim.fn.maparg('\\' .. row.suffix, mode)
          if rhs ~= '<Plug>(aineo-' .. row.plug .. ')' then
            table.insert(unmapped, mode .. ' \\' .. row.suffix)
          end
        end
      end
    end
    return unmapped
  end)()]])

  eq(unmapped, {})
end

T['the keys on the sheet']['are each of the sheet’s rows, one for each key aineo maps itself'] = function()
  open_layout('cheatsheet-rows')
  entry.press(child, '\\?')
  local text = sheet_text()

  local absent = child.lua_get(
    [[(function(text)
      local absent = {}
      for _, row in ipairs(require('aineo.keys').rows()) do
        local shown = row.suffix and ('\\' .. row.suffix) or row.key
        if not row.folded_into and not text:find(shown, 1, true) then
          table.insert(absent, shown)
        end
      end
      return absent
    end)(...)]],
    { text }
  )

  eq(absent, {})
end

T['the keys on the sheet']['show the tab keys 1 to 9 as a range'] = function()
  open_layout('cheatsheet-range')

  entry.press(child, '\\?')

  eq(sheet_text():find('\\1…\\9', 1, true) ~= nil, true)
end

T['the keys on the sheet']['follow the prefix the configuration names'] = function()
  entry.restart(child, { '--cmd', "let g:aineo = { 'prefix': ',' }" })
  open_layout('cheatsheet-prefix', { prefix = ',' })

  entry.press(child, ',?')

  local text = sheet_text()
  eq(text:find(',o', 1, true) ~= nil, true)
  eq(text:find('\\o', 1, true), nil)
end

T['the keys on the sheet']['of a fix and of explaining follow the prefix too'] = function()
  entry.restart(child, { '--cmd', "let g:aineo = { 'prefix': ',' }" })
  open_layout('cheatsheet-prefix-fix', { prefix = ',' })

  entry.press(child, ',?')

  local text = sheet_text()
  eq(text:find(',Va', 1, true) ~= nil, true)
  eq(text:find(',vc', 1, true) ~= nil, true)
  eq(text:find('\\', 1, true), nil)
end

T['the keys on the sheet']['are the <Plug> mappings when the prefix is false'] = function()
  entry.restart(child, { '--cmd', 'lua vim.g.aineo = { prefix = false }' })
  open_layout('cheatsheet-no-prefix', { prefix = false })

  entry.command(child, 'Aineo cheatsheet')

  local text = sheet_text()
  eq(text:find('<Plug>(aineo-open)', 1, true) ~= nil, true)
  eq(text:find('\\o', 1, true), nil)
end

T['the keys on the sheet']['are the keys the user mapped to the <Plug> mappings, when the prefix is false'] = function()
  entry.restart(child, { '--cmd', 'lua vim.g.aineo = { prefix = false }' })
  open_layout('cheatsheet-own-map', { prefix = false })
  child.cmd('nmap gQ <Plug>(aineo-open)')

  entry.command(child, 'Aineo cheatsheet')

  local text = sheet_text()
  eq(text:find('gQ', 1, true) ~= nil, true)
  eq(text:find('<Plug>(aineo-open)', 1, true), nil)
end

T['the keys on the sheet']['name the keys of a fix after the prefix, or their <Plug> mappings without one'] = function()
  open_layout('cheatsheet-fix-keys')
  entry.press(child, '\\?')
  eq(sheet_text():find('\\Va', 1, true) ~= nil, true)
  entry.press(child, '\\?')

  child.lua([[vim.g.aineo = vim.tbl_extend('force', vim.g.aineo, { prefix = false })]])
  entry.command(child, 'Aineo cheatsheet')

  eq(sheet_text():find('<Plug>(aineo-fix-accept)', 1, true) ~= nil, true)
end

T['the keys on the sheet']['come with the command that does the same, dimmed'] = function()
  open_layout('cheatsheet-commands')

  entry.press(child, '\\?')

  local dimmed = child.lua_get(
    [[(function(window)
      local buffer = vim.api.nvim_win_get_buf(window)
      local found = {}
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, { details = true })) do
        if mark[4].hl_group == 'AineoCheatCommand' then
          local line = vim.api.nvim_buf_get_lines(buffer, mark[2], mark[2] + 1, false)[1]
          table.insert(found, line:sub(mark[3] + 1, mark[4].end_col))
        end
      end
      return found
    end)(...)]],
    { sheet_window() }
  )
  eq(vim.tbl_contains(dimmed, ':Aineo open'), true)
  eq(vim.tbl_contains(dimmed, ':Aineo pane agent'), true)
end

T['the keys on the sheet']['are in groups, those of the buffers they act in last'] = function()
  open_layout('cheatsheet-groups')
  child.o.columns = 140

  entry.press(child, '\\?')

  local text = sheet_text()
  local positions = vim.tbl_map(function(title)
    return text:find(title, 1, true)
  end, {
    'Layout and tabs',
    'Claude and sessions',
    'Agent pane',
    'Changes and diff',
    'Run and terminal',
    'Explorer',
    'Explain and fix',
    'Office and zoom',
    'While a fix shows',
    'In the steering float',
    'Jumping between explanations',
    'In the changes pane',
    'In the explorer',
  })
  eq(#positions, 13)
  eq(positions, vim.fn.sort(positions, 'n'))
end

T['the cheatsheet and the office'] = MiniTest.new_set()

T['the cheatsheet and the office']['close the office when the cheatsheet opens'] = function()
  open_layout('cheatsheet-closes-office')
  entry.command(child, 'Aineo office')
  eq(office_window() ~= vim.NIL, true)

  entry.press(child, '\\?')

  eq(sheet_window() ~= vim.NIL, true)
  eq(office_window(), vim.NIL)
end

T['the cheatsheet and the office']['close the cheatsheet when the office opens'] = function()
  open_layout('cheatsheet-closed-by-office')
  entry.press(child, '\\?')

  entry.command(child, 'Aineo office')

  eq(sheet_has_closed(), true)
  eq(office_window() ~= vim.NIL, true)
end

T['the cheatsheet and the office']['keep the office from showing by itself over an open cheatsheet'] = function()
  open_layout('cheatsheet-idle', { office = { idle_ms = 100 } })
  entry.press(child, '\\?')

  local office_showed = vim.wait(600, function()
    return office_window() ~= vim.NIL
  end, 50)

  eq(office_showed, false)
  eq(sheet_window() ~= vim.NIL, true)
end

return T
