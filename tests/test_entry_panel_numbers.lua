local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

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

--- Stops the child, once the fake Claude Codes it runs, if any, have ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

--- The user's settings in the child: line numbers, a sign column, a fold
--- column and a status column, as global options.
local USERS_SETTINGS = [[
  vim.o.number = true
  vim.o.relativenumber = true
  vim.o.signcolumn = 'yes'
  vim.o.foldcolumn = '2'
  vim.o.statuscolumn = '%s%l '
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.lua(USERS_SETTINGS)
    end,
    post_once = stop_the_child,
  },
})

--- The columns a window's gutter takes (`textoff`) in each window of the tab
--- page numbered `number` that does not float, by what the window shows:
--- `'terminal'` or the buffer's name.
local TEXTOFFS_OF_TAB = [[(function(number)
  vim.cmd('redraw')
  local page = vim.api.nvim_list_tabpages()[number]
  local offs = {}
  local tiled = vim.tbl_filter(function(window)
    return vim.api.nvim_win_get_config(window).relative == ''
  end, vim.api.nvim_tabpage_list_wins(page))
  for _, window in ipairs(tiled) do
    local buffer = vim.api.nvim_win_get_buf(window)
    local name = vim.bo[buffer].buftype == 'terminal' and 'terminal'
      or (vim.api.nvim_buf_get_name(buffer):gsub('%-%d+$', ''))
    offs[name] = vim.fn.getwininfo(window)[1].textoff
  end
  return offs
end)(...)]]

--- The columns the gutter takes in each window of the tab page `number`.
---
---@param number integer
---@return table<string, integer>
local function textoffs_of_tab(number)
  return child.lua_get(TEXTOFFS_OF_TAB, { number })
end

--- The columns the gutter takes in a window that is no panel, as the user's
--- settings make it.
---
---@return integer
local function users_textoff()
  return child.lua_get([[(function()
    vim.cmd('tabnew')
    vim.cmd('redraw')
    local off = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
    vim.cmd('tabclose')
    return off
  end)()]])
end

--- What the panels of the layout of the agent pane take for a gutter when
--- they show none.
local NONE = { terminal = 0, ['aineo://report'] = 0, ['aineo://input'] = 0 }

--- What they take when they show the user's own, `off` columns each.
---
---@param off integer
---@return table<string, integer>
local function users(off)
  return { terminal = off, ['aineo://report'] = off, ['aineo://input'] = off }
end

--- Opens the layout in the child with aineo running the fake `claude` under
--- `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `panel-numbers-`
---@param settings? table more of `vim.g.aineo`
local function open_layout(name, settings)
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

T['the panels'] = MiniTest.new_set()

T['the panels']['show no gutter by default, whatever the user’s settings'] = function()
  open_layout('panel-numbers-default')

  eq(textoffs_of_tab(1), NONE)
end

T['the panels']['of the explorer column show no gutter either'] = function()
  open_layout('panel-numbers-explorer', { layout = { explorer_column = 'left' } })

  eq(textoffs_of_tab(1), vim.tbl_extend('force', NONE, { ['aineo://explorer'] = 0 }))
end

--- Each way to show the gutter of the panels, as a set's `parametrize`: the
--- name of the way, and the function that does it.
local WAYS_TO_TURN_THEM_ON = {
  {
    'running :Aineo panel-numbers',
    function()
      entry.command(child, 'Aineo panel-numbers')
    end,
  },
  {
    'pressing <Plug>(aineo-panel-numbers)',
    function()
      entry.press(child, '<Plug>(aineo-panel-numbers)')
    end,
  },
  {
    'pressing the key \\tn',
    function()
      entry.press(child, '\\tn')
    end,
  },
}

T['turning the panels’ numbers on'] = MiniTest.new_set()

T['turning the panels’ numbers on']['gives every panel the user’s own gutter, by'] =
  MiniTest.new_set({ parametrize = WAYS_TO_TURN_THEM_ON })

T['turning the panels’ numbers on']['gives every panel the user’s own gutter, by']['a way'] = function(
  _,
  way
)
  open_layout('panel-numbers-on')
  local off = users_textoff()

  way()

  eq(textoffs_of_tab(1), users(off))
  eq(entry.messages(child), {})
end

T['turning the panels’ numbers on']['takes the gutter out again when pressed twice'] = function()
  open_layout('panel-numbers-twice')

  entry.command(child, 'Aineo panel-numbers')
  entry.command(child, 'Aineo panel-numbers')

  eq(textoffs_of_tab(1), NONE)
end

T['turning the panels’ numbers on']['gives the explorer column the user’s gutter too'] = function()
  open_layout('panel-numbers-on-explorer', { layout = { explorer_column = 'left' } })
  local off = users_textoff()

  entry.command(child, 'Aineo panel-numbers')

  eq(textoffs_of_tab(1), vim.tbl_extend('force', users(off), { ['aineo://explorer'] = off }))
end

T['turning the panels’ numbers on']['leaves the line numbers of a window that is no panel alone'] = function()
  open_layout('panel-numbers-other-window')

  entry.command(child, 'Aineo panel-numbers')

  eq(users_textoff() > 0, true)
end

T['turning the panels’ numbers on']['works in every aineo tab at once, both ways'] = function()
  tabs.open_first_tab(child, 'panel-numbers-tabs')
  tabs.use_next_fake(child, tabs.fake('panel-numbers-tabs-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  local off = users_textoff()

  entry.command(child, 'Aineo panel-numbers')
  local shown = { textoffs_of_tab(1), textoffs_of_tab(2) }
  child.cmd('tabfirst')
  entry.command(child, 'Aineo panel-numbers')
  local hidden = { textoffs_of_tab(1), textoffs_of_tab(2) }

  eq(shown, { users(off), users(off) })
  eq(hidden, { NONE, NONE })
end

T['turning the panels’ numbers on']['shows them in a tab made later'] = function()
  tabs.open_first_tab(child, 'panel-numbers-later')
  local off = users_textoff()
  entry.command(child, 'Aineo panel-numbers')

  tabs.use_next_fake(child, tabs.fake('panel-numbers-later-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')

  eq(textoffs_of_tab(2), users(off))
end

T['turning the panels’ numbers on']['leaves Claude’s own line numbers to :Aineo claude-numbers'] = function()
  open_layout('panel-numbers-claude-numbers')
  entry.command(child, 'Aineo claude-numbers')
  local claude_numbers = child.lua_get([[(function()
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(window)].buftype == 'terminal' then
          return vim.wo[window].number
        end
      end
    end)()]])

  entry.command(child, 'Aineo panel-numbers')
  entry.command(child, 'Aineo panel-numbers')

  eq(claude_numbers, true)
  eq(textoffs_of_tab(1).terminal > 0, true)
end

T['the setting layout.panel_numbers'] = MiniTest.new_set()

T['the setting layout.panel_numbers']['shows the panels’ gutters from the start when true'] = function()
  open_layout('panel-numbers-setting', { layout = { panel_numbers = true } })

  eq(textoffs_of_tab(1), users(users_textoff()))
end

T['the setting layout.panel_numbers']['is undone by :Aineo panel-numbers'] = function()
  open_layout('panel-numbers-setting-off', { layout = { panel_numbers = true } })

  entry.command(child, 'Aineo panel-numbers')

  eq(textoffs_of_tab(1), NONE)
end

T['the setting explorer.numbers'] = MiniTest.new_set()

T['the setting explorer.numbers']['is the old name of layout.panel_numbers'] = function()
  open_layout('panel-numbers-old-name', { explorer = { numbers = true } })

  eq(textoffs_of_tab(1), users(users_textoff()))
end

return T
