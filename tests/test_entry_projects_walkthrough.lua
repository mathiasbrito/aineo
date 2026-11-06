local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local projects = dofile('tests/helpers/projects_session.lua')
local send = dofile('tests/helpers/send.lua')
local walkthrough_session = dofile('tests/helpers/walkthrough_session.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_once = projects.use_isolated_git,
    pre_case = function()
      projects.stop(child)
      entry.restart(child)
      child.o.columns = 200
      child.o.lines = 50
    end,
    post_once = function()
      projects.stop(child)
    end,
  },
})

local CODE = walkthrough_session.CODE

--- Opens aineo in the repository `aineo` of the group `name`, which holds
--- `src/main.lua`, with the repository `notes-api` beside it, which holds
--- `src/code.lua`, and makes `notes-api` a project by an edit of another of
--- its files. Returns where they are and the start token.
---
---@param name string
---@return { main: string, other: string, token: string }
local function open_with_a_second_project(name)
  local main = projects.repository(name, 'aineo', { ['src/main.lua'] = CODE })
  local other = projects.repository(name, 'notes-api', {
    ['src/code.lua'] = CODE,
    ['src/edited.lua'] = CODE,
  })
  local fake, session = projects.open_in(child, name, main)
  local transcript = projects.name_transcript(child, session)
  projects.edit(transcript, vim.fs.joinpath(other, 'src/edited.lua'))
  projects.wait_until('notes-api is a project of the tab', function()
    return child.lua_get(
      [[#require('aineo.entry.projects').folders(require('aineo.entry.registry').tab_list[1]) ]]
    ) >= 2
  end)
  return { main = main, other = other, token = claude_session.start_token(fake, 1) }
end

--- A plan over the files `files`, each a step.
---
---@param files string[]
---@return table
local function plan_over(files)
  local steps = {}
  for position, file in ipairs(files) do
    table.insert(steps, { title = 'Step ' .. position, file = file, introduces = { 'value' } })
  end
  return {
    title = 'Across two repositories',
    summary = 'How the two repositories fit.',
    covers = { 'Both repositories' },
    steps = steps,
  }
end

--- The plan of the case: the first step in the session's repository, the
--- second in the other.
---
---@param here { main: string, other: string }
---@return table
local function plan_across(here)
  return plan_over({
    vim.fs.joinpath(here.main, 'src/main.lua'),
    vim.fs.joinpath(here.other, 'src/code.lua'),
  })
end

--- Offers the child a call of the walkthrough tool, as the relay does.
---
---@param receiver 'receive_walkthrough_plan'|'receive_walkthrough_step'
---@param token string
---@param call table
---@return table
local function offer(receiver, token, call)
  return walkthrough_session.offer(child, receiver, token, call)
end

--- The lines of the walkthrough pane's buffer.
---
---@return string[]
local function pane_lines()
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.fn.bufnr('^aineo://walkthrough$'), 0, -1, false)]]
  )
end

--- Whether a line of the walkthrough pane contains `part`.
---
---@param part string
---@return boolean
local function pane_has(part)
  return vim.iter(pane_lines()):any(function(line)
    return line:find(part, 1, true) ~= nil
  end)
end

--- The lines with a band over them (`aineo_explain_walk`) or marked
--- (`aineo_explain_walk_range`), in the buffer of `path`.
---
---@param namespace string
---@param path string
---@return integer[]
local function lines_in(namespace, path)
  return child.lua_get(
    [[(function(namespace, path)
      local id = vim.api.nvim_get_namespaces()[namespace]
      local buffer = vim.fn.bufnr(path)
      local lines = {}
      if id and buffer ~= -1 then
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, id, 0, -1, {})) do
          table.insert(lines, mark[2] + 1)
        end
      end
      return lines
    end)(...)]],
    { namespace, path }
  )
end

--- Puts the cursor on the first line of the walkthrough pane that holds
--- `text`, and presses Enter there.
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
        if line:find(text, 1, true) then
          vim.api.nvim_win_set_cursor(window, { row, 0 })
          break
        end
      end
    ]],
    { text }
  )
  entry.press(child, '<CR>')
end

--- What the message `message` is when it is written to Claude Code's
--- terminal as a message of the user.
---
---@param message string
---@return string
local function paste(message)
  return '\27[200~' .. message .. '\27[201~\r'
end

--- Waits until the child has written `count` times to a channel and returns
--- what it wrote.
---
---@param count integer
---@return string[]
local function writes_after_waiting_for(count)
  vim.wait(projects.PATIENCE_MS, function()
    return #send.writes(child) >= count
  end, 20)
  return send.writes(child)
end

T['a plan over two repositories'] = MiniTest.new_set()

T['a plan over two repositories']['is taken, for files the second repository holds whether changed or not'] = function()
  local here = open_with_a_second_project('projects-walk-plan')

  local answer = offer('receive_walkthrough_plan', here.token, plan_across(here))

  eq(answer.is_error, false)
end

T['a plan over two repositories']['names a file of the second repository with its project, and the session’s own plain'] = function()
  local here = open_with_a_second_project('projects-walk-names')

  offer('receive_walkthrough_plan', here.token, plan_across(here))

  eq(pane_has('notes-api: src/code.lua'), true)
  eq(pane_has('src/main.lua'), true)
  eq(pane_has('aineo: src/main.lua'), false)
end

T['a plan over two repositories']['is refused for a file of a repository that is no project, telling to call announce_work'] = function()
  local here = open_with_a_second_project('projects-walk-refused')
  local stranger = projects.repository('projects-walk-refused', 'stranger', { ['x.lua'] = CODE })

  local answer = offer('receive_walkthrough_plan', here.token, plan_over({ stranger .. '/x.lua' }))

  eq(answer.is_error, true)
  eq(
    answer.text:find(
      'call announce_work for its checkout first, also for code you only read',
      1,
      true
    ) ~= nil,
    true
  )
end

T['a step in the second repository'] = MiniTest.new_set()

T['a step in the second repository']['opens in the middle window with its bands and marks'] = function()
  local here = open_with_a_second_project('projects-walk-step')
  offer('receive_walkthrough_plan', here.token, plan_across(here))
  local file = vim.fs.joinpath(here.other, 'src/code.lua')

  local answer = offer(
    'receive_walkthrough_step',
    here.token,
    walkthrough_session.step_for(here.other, 'src/code.lua', 2)
  )

  eq(answer.is_error, false)
  eq(lines_in('aineo_explain_walk', file), { 2 })
  eq(lines_in('aineo_explain_walk_range', file), { 2, 3 })
  eq(vim.tbl_contains(entry.windows(child), file), true)
end

T['a step in the second repository']['marks the step on show in the pane'] = function()
  local here = open_with_a_second_project('projects-walk-marked')
  offer('receive_walkthrough_plan', here.token, plan_across(here))

  offer(
    'receive_walkthrough_step',
    here.token,
    walkthrough_session.step_for(here.other, 'src/code.lua', 2)
  )

  projects.wait_until('the pane marks step 2', function()
    return pane_has('▸')
  end)
end

T['moving across the repositories'] = MiniTest.new_set()

T['moving across the repositories']['goes back to a step in the first with Enter on its line'] = function()
  local here = open_with_a_second_project('projects-walk-enter')
  offer('receive_walkthrough_plan', here.token, plan_across(here))
  offer(
    'receive_walkthrough_step',
    here.token,
    walkthrough_session.step_for(here.other, 'src/code.lua', 2)
  )
  send.watch_writes(child)

  press_enter_on('Step 1')

  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 1') })
end

T['moving across the repositories']['goes on to a step in the second with Enter on its line'] = function()
  local here = open_with_a_second_project('projects-walk-enter-second')
  offer('receive_walkthrough_plan', here.token, plan_across(here))
  send.watch_writes(child)

  press_enter_on('notes-api: src/code.lua')

  eq(writes_after_waiting_for(1), { paste('Go to walkthrough step 2') })
end

T['moving across the repositories']['asks for the next and the previous step with \\vn and \\vp from a step in the second'] = function()
  local here = open_with_a_second_project('projects-walk-keys')
  offer('receive_walkthrough_plan', here.token, plan_across(here))
  offer(
    'receive_walkthrough_step',
    here.token,
    walkthrough_session.step_for(here.other, 'src/code.lua', 2)
  )
  send.watch_writes(child)

  entry.press(child, '\\vp')

  eq(writes_after_waiting_for(1), { paste('Previous walkthrough step') })
end

T['moving across the repositories']['shows the step in the first after the one in the second, its bands in the first file alone'] = function()
  local here = open_with_a_second_project('projects-walk-back')
  offer('receive_walkthrough_plan', here.token, plan_across(here))
  local second = vim.fs.joinpath(here.other, 'src/code.lua')
  local first = vim.fs.joinpath(here.main, 'src/main.lua')
  offer(
    'receive_walkthrough_step',
    here.token,
    walkthrough_session.step_for(here.other, 'src/code.lua', 2)
  )

  local answer = offer(
    'receive_walkthrough_step',
    here.token,
    walkthrough_session.step_for(here.main, 'src/main.lua', 1)
  )

  eq(answer.is_error, false)
  eq(lines_in('aineo_explain_walk', first), { 2 })
  eq(lines_in('aineo_explain_walk', second), {})
end

return T
