local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local explained = dofile('tests/helpers/explain_child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local send = dofile('tests/helpers/send.lua')
local walkthrough_session = dofile('tests/helpers/walkthrough_session.lua')

local eq = MiniTest.expect.equality

local explain = require('aineo.explain')

local child = MiniTest.new_child_neovim()

--- The project every case's child works in, made once for the file.
local project

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      project = walkthrough_session.make_project('walkthrough-pane')
    end,
    pre_case = function()
      walkthrough_session.restart(child, project)
    end,
    post_once = function()
      walkthrough_session.stop(child)
    end,
  },
})

--- Opens the layout in the child under `name` and returns the start token.
---
---@param name string
---@param settings? table more of `vim.g.aineo`
---@return string token
local function open_layout(name, settings)
  return walkthrough_session.open_layout(child, 'walkthrough-pane-' .. name, settings)
end

--- Sends the plan `call` as the agent of the Claude Code with `token` does.
---
---@param token string
---@param call? table the plan; the default one when not given
---@return { text: string, is_error: boolean }|false|{ raised: string }
local function plan(token, call)
  return walkthrough_session.offer(
    child,
    'receive_walkthrough_plan',
    token,
    call or walkthrough_session.plan_for(project)
  )
end

--- Shows the step `number` as the agent does, of the file `path`.
---
---@param token string
---@param path string
---@param number integer
---@return { text: string, is_error: boolean }|false|{ raised: string }
local function step(token, path, number)
  return walkthrough_session.offer(
    child,
    'receive_walkthrough_step',
    token,
    walkthrough_session.step_for(project, path, number)
  )
end

--- The walkthrough pane's buffer in the child, nil before there is one.
local PANE_BUFFER = [[(function()
  local buffer = vim.fn.bufnr('^aineo://walkthrough$')
  return buffer ~= -1 and buffer or nil
end)()]]

--- The 'statusline' of the window showing the walkthrough pane's buffer.
local PANE_STATUSLINE = ([=[vim.wo[vim.fn.win_findbuf(%s)[1]].statusline]=]):format(PANE_BUFFER)

--- The lines the walkthrough pane's buffer holds.
---
---@return string[]
local function pane_lines()
  return child.lua_get(('vim.api.nvim_buf_get_lines(%s, 0, -1, false)'):format(PANE_BUFFER))
end

--- The window showing the walkthrough pane's buffer, nil when none does.
---
---@return integer?
local function pane_window()
  return child.lua_get(('vim.fn.win_findbuf(%s)[1]'):format(PANE_BUFFER))
end

--- The width of the walkthrough pane's window.
---
---@return integer
local function pane_width()
  return child.api.nvim_win_get_width(pane_window())
end

--- The plan `walkthrough_session.plan_for()` gives, as the pane shows it:
--- the files from the project's root.
---
---@return aineo.mcp.WalkthroughPlanCall
local function displayed_plan()
  return {
    title = 'The values',
    summary = 'How the values are defined and returned.',
    covers = { 'Defining the values', 'Returning one' },
    steps = {
      { title = 'The definitions', file = 'src/code.lua', introduces = { 'value' } },
      { title = 'The result', file = 'src/other.lua', introduces = { 'return' } },
    },
  }
end

--- The page of the displayed plan for a window `width` cells wide, `shown`
--- the step on show.
---
---@param shown? integer
---@param width integer
---@return string[]
local function page(shown, width)
  return explain.render_walkthrough_plan(displayed_plan(), shown, width).lines
end

--- The pane shown by the layout in the child's right column.
---
---@return string
local function shown_pane()
  return child.lua_get([[require('aineo.layout').shown_pane()]])
end

--- What the child's windows show, left to right and then top to bottom.
---
---@return string[]
local function windows()
  return entry.windows(child)
end

--- Waits until the walkthrough pane's lines are `expected`, or the time a
--- case waits is over, and returns what they are.
---
---@param expected string[]
---@return string[]
local function pane_lines_after_waiting_for(expected)
  vim.wait(explained.PATIENCE_MS, function()
    return vim.deep_equal(pane_lines(), expected)
  end, 20)
  return pane_lines()
end

T['a plan'] = MiniTest.new_set()

T['a plan']['is shown in the walkthrough pane at once, as the page for the window’s width'] = function()
  local token = open_layout('shown')

  plan(token)

  eq(shown_pane(), 'walkthrough')
  eq(pane_lines(), page(nil, pane_width()))
end

T['a plan']['shows the files from the project’s root, under the steps'] = function()
  local token = open_layout('files')

  plan(token)

  eq(vim.tbl_contains(pane_lines(), '       src/code.lua'), true)
  eq(vim.tbl_contains(pane_lines(), '       src/other.lua'), true)
end

T['a plan']['takes the Report’s window and width, Input kept below it'] = function()
  local token = open_layout('window')
  local report_width = child.lua_get([[(function()
    local report = require('aineo.entry.registry').tab_list[1].homes.report.report_buffer()
    return vim.api.nvim_win_get_width(vim.fn.win_findbuf(report)[1])
  end)()]])

  plan(token)

  eq(windows(), { 'terminal', 'aineo://walkthrough', 'aineo://input' })
  eq(pane_width(), report_width)
end

T['a plan']['is answered with the steps shown and that step 1 comes next'] = function()
  local token = open_layout('answer')

  local answer = plan(token)

  eq(answer, {
    text = 'Showing the plan "The values", 2 steps, in the walkthrough pane. Show step 1 now;'
      .. ' show the others only when the user asks to move on.',
    is_error = false,
  })
end

T['a plan']['sent again replaces the one shown'] = function()
  local token = open_layout('replaced')
  plan(token)

  plan(
    token,
    walkthrough_session.plan_for(
      project,
      { title = 'Another walkthrough', summary = 'A different one.' }
    )
  )

  eq(pane_lines()[1], ' Another walkthrough')
  eq(pane_lines()[3], ' A different one.')
end

T['a plan']['is refused, and shown nowhere, for a file that is not on disk'] = function()
  local token = open_layout('missing')
  local steps = walkthrough_session.plan_for(project).steps
  steps[2].file = project .. '/src/missing.lua'

  local answer = plan(token, walkthrough_session.plan_for(project, { steps = steps }))

  eq(answer, {
    text = ('refused: steps[2].file: %s/src/missing.lua is not on disk'):format(project),
    is_error = true,
  })
  eq(shown_pane(), 'agent')
end

T['a plan']['is refused for a file of a repository the editor does not have open'] = function()
  local token = open_layout('not-open')
  local other = git_repo.create('walkthrough-pane-other', { ['a.lua'] = walkthrough_session.CODE })
  local steps = walkthrough_session.plan_for(project).steps
  steps[1].file = other .. '/a.lua'

  local answer = plan(token, walkthrough_session.plan_for(project, { steps = steps }))

  eq(answer, {
    text = ('refused: steps[1].file: %s/a.lua is in no repository the editor has open'):format(
      other
    ),
    is_error = true,
  })
end

T['a plan']['that is refused leaves the plan shown as it was'] = function()
  local token = open_layout('refused-keeps')
  plan(token)
  local before = pane_lines()
  local steps = walkthrough_session.plan_for(project).steps
  steps[1].file = project .. '/src/missing.lua'

  plan(token, walkthrough_session.plan_for(project, { steps = steps }))

  eq(pane_lines(), before)
end

T['a plan']['is kept, and not shown, by a tab whose layout is not open in a tab page'] = function()
  open_layout('unbound')

  local outcome = child.lua(
    [[
      local project = ...
      local shown = false
      local tab = {
        key = 'stand-in',
        homes = {},
        is_bound = function() return false end,
        show_pane = function() shown = true end,
      }
      local answer = require('aineo.entry.walkthrough_plan').take_plan(tab, {
        title = 'The values',
        summary = 'How the values are defined.',
        covers = { 'Defining the values' },
        steps = { { title = 'The definitions', file = project .. '/src/code.lua', introduces = {} } },
      }, { project })
      return { is_error = answer.is_error, shown = shown, buffer = require('aineo.entry.walkthrough_plan').buffer_of(tab) ~= nil }
    ]],
    { project }
  )

  eq(outcome, { is_error = false, shown = false, buffer = true })
end

--- Runs, in the child, `body`, a Lua chunk given a stand-in tab whose layout
--- shows the walkthrough pane and whose `show_pane` raises `no room`, and
--- `project`; returns what the child told the user, in order.
---
---@param body string
---@return string[] told
local function told_by_a_tab_that_cannot_show_a_pane(body)
  child.lua(
    [[
      local project, body = ...
      _G.told = {}
      vim.notify = function(message) table.insert(_G.told, message) end
      local tab = {
        key = 'stand-in',
        homes = { layout = { shown_pane = function() return 'walkthrough' end } },
        is_bound = function() return true end,
        show_pane = function() error('no room', 0) end,
      }
      load(body)(tab, project)
    ]],
    { project, body }
  )
  return child.lua_get('_G.told')
end

T['a walkthrough that ends'] = MiniTest.new_set()

T['a plan']['that cannot be shown tells the user, and is kept'] = function()
  open_layout('cannot-show')

  local told = told_by_a_tab_that_cannot_show_a_pane([[
    local tab, project = ...
    require('aineo.entry.walkthrough_plan').take_plan(tab, {
      title = 'The values',
      summary = 'How the values are defined.',
      covers = { 'Defining the values' },
      steps = { { title = 'The definitions', file = project .. '/src/code.lua', introduces = {} } },
    }, { project })
  ]])

  eq(told, { 'aineo: the walkthrough pane could not be shown: no room' })
end

T['a walkthrough that ends']['when the Report cannot be given back tells the user, and still ends'] = function()
  open_layout('cannot-end')

  local told = told_by_a_tab_that_cannot_show_a_pane([[
    local tab, project = ...
    local plans = require('aineo.entry.walkthrough_plan')
    plans.take_plan(tab, {
      title = 'The values',
      summary = 'How the values are defined.',
      covers = { 'Defining the values' },
      steps = { { title = 'The definitions', file = project .. '/src/code.lua', introduces = {} } },
    }, { project })
    _G.told = {}
    require('aineo.entry.walkthrough').clear(tab)
    plans.focus(tab)
  ]])

  eq(told, {
    'aineo: the walkthrough pane could not be shown: no room',
    'aineo: no walkthrough plan is shown in this tab: the agent sends one with walkthrough_plan',
  })
end

T['a step'] = MiniTest.new_set()

T['a step']['moves the mark: the steps before are done, the one shown is marked'] = function()
  local token = open_layout('step-moves')
  plan(token)

  step(token, 'src/code.lua', 1)
  local after_the_first = pane_lines()
  step(token, 'src/other.lua', 2)

  eq(after_the_first, page(1, pane_width()))
  eq(pane_lines(), page(2, pane_width()))
end

T['a step']['sent before any plan changes nothing in the pane, and shows none'] = function()
  local token = open_layout('step-no-plan')

  step(token, 'src/code.lua', 1)

  eq(shown_pane(), 'agent')
  eq(child.lua_get(PANE_BUFFER), vim.NIL)
end

T['a step']['does not bring the pane back after the user chose another'] = function()
  local token = open_layout('step-keeps-choice')
  plan(token)
  entry.press(child, '\\pa')

  step(token, 'src/code.lua', 1)

  eq(shown_pane(), 'agent')
end

T['a plan']['sent while a step is shown keeps that step marked'] = function()
  local token = open_layout('plan-after-step')
  plan(token)
  step(token, 'src/code.lua', 1)

  plan(token)

  eq(pane_lines(), page(1, pane_width()))
end

T['a plan']['sent after a step was shown marks that step'] = function()
  local token = open_layout('plan-after-step-shown')
  step(token, 'src/code.lua', 1)

  plan(token)

  eq(pane_lines(), page(1, pane_width()))
end

T['a plan']['sent after the walkthrough ended marks no step'] = function()
  local token = open_layout('plan-after-end')
  step(token, 'src/code.lua', 1)
  walkthrough_session.offer(
    child,
    'receive_walkthrough_step',
    token,
    walkthrough_session.step_for(project, 'src/code.lua', 1, { ranges = {} })
  )

  plan(token)

  eq(pane_lines(), page(nil, pane_width()))
end

T['the end of the walkthrough'] = MiniTest.new_set({
  parametrize = { { 'a call with no ranges' }, { '\\vq' }, { 'a session switch' } },
})

T['the end of the walkthrough']['gives the right column back to the Report, and forgets the plan'] = function(
  how
)
  local token = open_layout('end')
  plan(token)
  step(token, 'src/code.lua', 1)
  send.watch_writes(child)

  if how == 'a call with no ranges' then
    walkthrough_session.offer(
      child,
      'receive_walkthrough_step',
      token,
      walkthrough_session.step_for(project, 'src/code.lua', 1, { ranges = {} })
    )
  elseif how == '\\vq' then
    entry.press(child, '\\vq')
  else
    child.lua([[
        local tab = require('aineo.entry.registry').tab_list[1]
        require('aineo.entry.walkthrough').end_for_session_switch(tab)
      ]])
  end

  eq(shown_pane(), 'agent')
  eq(vim.list_slice(windows(), 3), { 'aineo://report', 'aineo://input' })
  entry.press(child, '\\pw')
  eq(shown_pane(), 'agent')
end

T['the end of the walkthrough']['leaves the pane the user chose in its place'] = function()
  local token = open_layout('end-keeps-choice')
  plan(token)
  step(token, 'src/code.lua', 1)
  entry.press(child, '\\g')

  entry.press(child, '\\vq')

  eq(shown_pane(), 'changes')
end

T['\\pw'] = MiniTest.new_set()

T['\\pw']['shows the walkthrough pane with the plan and moves into it, \\pa gives the Report back'] = function()
  local token = open_layout('pw')
  plan(token)
  entry.press(child, '\\pa')
  eq(shown_pane(), 'agent')

  entry.press(child, '\\pw')

  eq(shown_pane(), 'walkthrough')
  eq(child.lua_get('vim.api.nvim_get_current_win()'), pane_window())
  eq(pane_lines(), page(nil, pane_width()))
  entry.press(child, '\\pa')
  eq(shown_pane(), 'agent')
  eq(windows(), { 'terminal', 'aineo://report', 'aineo://input' })
end

T['\\pw']['says there is no plan, and changes nothing, while no plan was sent'] = function()
  open_layout('pw-none')

  entry.press(child, '\\pw')

  eq(shown_pane(), 'agent')
  eq(entry.messages(child), {
    {
      message = 'aineo: no walkthrough plan is shown in this tab: the agent sends one with walkthrough_plan',
      level = vim.log.levels.INFO,
    },
  })
end

T['\\pw']['is also :Aineo pane walkthrough'] = function()
  local token = open_layout('pw-command')
  plan(token)
  entry.press(child, '\\pa')

  child.cmd('Aineo pane walkthrough')

  eq(shown_pane(), 'walkthrough')
end

--- The bytes Send writes for `message`: one bracketed paste and its Enter.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- Waits until the child has written `count` times to a channel, or the
--- time a case waits is over, and returns what it wrote.
---
---@param count integer
---@return string[]
local function writes_after_waiting_for(count)
  vim.wait(explained.PATIENCE_MS, function()
    return #send.writes(child) >= count
  end, 20)
  return send.writes(child)
end

--- Puts the cursor on the first line of the walkthrough pane's buffer that
--- reads `text`, in its window, and presses Enter there.
---
---@param text string
local function press_enter_on(text)
  child.lua(
    [[
      local text = ...
      local buffer = vim.fn.bufnr('^aineo://walkthrough$')
      local window = vim.fn.win_findbuf(buffer)[1]
      vim.api.nvim_set_current_win(window)
      for row, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
        if line == text then
          vim.api.nvim_win_set_cursor(window, { row, 0 })
          break
        end
      end
    ]],
    { text }
  )
  entry.press(child, '<CR>')
end

T['Enter'] = MiniTest.new_set()

T['Enter']['on a step sends “Go to walkthrough step N” to the session as a message of the user'] = function()
  local token = open_layout('enter-step')
  plan(token)
  send.watch_writes(child)

  press_enter_on('   2  The result')

  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 2') })
end

T['Enter']['on the file of a step goes to that step too'] = function()
  local token = open_layout('enter-file')
  plan(token)
  send.watch_writes(child)

  press_enter_on('       src/other.lua')

  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 2') })
end

T['Enter']['on a concept sends the step that introduces it'] = function()
  local token = open_layout('enter-concept')
  plan(token)
  send.watch_writes(child)

  press_enter_on(' return  step 2')

  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 2') })
end

T['Enter']['on a line that goes nowhere says so, and sends nothing'] = function()
  local token = open_layout('enter-nowhere')
  plan(token)
  send.watch_writes(child)

  press_enter_on(' Covers')
  vim.wait(200)

  eq(send.writes(child), {})
  eq(entry.messages(child), {
    { message = 'aineo: nothing to go to on this line', level = vim.log.levels.INFO },
  })
end

T['Enter']['waits for the turn of the agent, as \\vn does, and goes when it ends'] = function()
  local token = open_layout('enter-wait')
  plan(token)
  send.watch_writes(child)
  walkthrough_session.be_busy(child, true)

  press_enter_on('   2  The result')
  local before_the_end = send.writes(child)
  walkthrough_session.be_busy(child, false)

  eq(before_the_end, {})
  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 2') })
  eq(entry.messages(child), {
    {
      message = 'aineo: the agent is working: "Go to walkthrough step 2" goes when its turn ends',
      level = vim.log.levels.INFO,
    },
  })
end

T['Enter']['never leaves two messages waiting: the last replaces the one before'] = function()
  local token = open_layout('enter-two')
  plan(token)
  send.watch_writes(child)
  walkthrough_session.be_busy(child, true)

  press_enter_on('   2  The result')
  press_enter_on('   1  The definitions')
  walkthrough_session.be_busy(child, false)

  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 1') })
end

T['the pane'] = MiniTest.new_set()

--- The summary of the plan the resize case sends: long enough to be wrapped
--- differently at the two widths the case shows the pane in.
local LONG_SUMMARY = ('The values are defined, combined and returned. '):rep(8)

T['the pane']['lays its page out again, wrapped to the new width, when the window is resized'] = function()
  local token = open_layout('resize')
  plan(token, walkthrough_session.plan_for(project, { summary = LONG_SUMMARY }))
  local before = pane_lines()
  child.o.columns = 120
  local displayed = displayed_plan()
  displayed.summary = LONG_SUMMARY
  local expected = explain.render_walkthrough_plan(displayed, nil, pane_width())

  local lines = pane_lines_after_waiting_for(expected.lines)

  eq(lines, expected.lines)
  eq(lines ~= before, true)
end

T['the pane']['draws its winbar and its hint line, and no numbers or signs'] = function()
  local token = open_layout('options')
  plan(token)
  step(token, 'src/code.lua', 1)

  local options = child.lua_get([[(function()
      local window = vim.fn.win_findbuf(vim.fn.bufnr('^aineo://walkthrough$'))[1]
      return {
        winbar = vim.wo[window].winbar,
        statusline = vim.wo[window].statusline,
        number = vim.wo[window].number,
        signcolumn = vim.wo[window].signcolumn,
        wrap = vim.wo[window].wrap,
        cursorline = vim.wo[window].cursorline,
      }
    end)()]])

  eq(options, {
    winbar = ' %#Title#Walkthrough%* · step 1 of 2',
    statusline = ' Enter go to step · \\vn next · \\vp previous · \\vq end',
    number = false,
    signcolumn = 'no',
    wrap = false,
    cursorline = true,
  })
end

--- The options of the window showing the Report that the walkthrough pane
--- sets in its own window.
local REPORT_WINDOW_OPTIONS = [[(function()
  local report = require('aineo.entry.registry').tab_list[1].homes.report.report_buffer()
  local window = vim.fn.win_findbuf(report)[1]
  if not window then
    return vim.NIL
  end
  local options = {}
  for _, name in ipairs({ 'winbar', 'statusline', 'number', 'signcolumn', 'wrap', 'cursorline' }) do
    options[name] = vim.wo[window][name]
  end
  return options
end)()]]

T['the pane']['leaves the Report’s window with the options it had, once the Report returns'] = function()
  local token = open_layout('options-leave')
  local before = child.lua_get(REPORT_WINDOW_OPTIONS)
  plan(token)
  step(token, 'src/code.lua', 1)
  entry.press(child, '\\pa')

  eq(child.lua_get(REPORT_WINDOW_OPTIONS), before)
end

T['the pane']['writes the keys of its hint with the prefix the user chose'] = function()
  local token = open_layout('hint-prefix', { prefix = ',' })
  plan(token)

  eq(child.lua_get(PANE_STATUSLINE), ' Enter go to step · ,vn next · ,vp previous · ,vq end')
end

T['the pane']['names no keys in its hint when the user maps none'] = function()
  local token = open_layout('hint-no-prefix', { prefix = false })
  plan(token)

  eq(child.lua_get(PANE_STATUSLINE), ' Enter go to step')
end

T['the pane']['is wiped when its tab is released'] = function()
  local token = open_layout('released')
  plan(token)

  child.lua([[require('aineo.entry.registry').tab_list[1].release()]])

  eq(child.lua_get(PANE_BUFFER), vim.NIL)
end

T['the pane']['is let go with its tab: its buffer is wiped'] = function()
  local token = open_layout('let-go')
  plan(token)

  child.lua(
    [[require('aineo.entry.walkthrough_plan').let_go(require('aineo.entry.registry').tab_list[1])]]
  )

  eq(child.lua_get(PANE_BUFFER), vim.NIL)
end

return T
