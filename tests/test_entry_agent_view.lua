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

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- A session of the form Claude Code gives, kept as a tab's own.
local KEPT = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

--- What the settings `argv` gives inline after `--settings` say of Claude
--- Code's agent view (`disableAgentView`).
---
---@param argv string[]
---@return any
local function agent_view_disabled(argv)
  local given = claude_session.decoded_words_after(argv, '--settings')[1] or {}
  return given.disableAgentView
end

T['a tab’s Claude Code'] = MiniTest.new_set()

T['a tab’s Claude Code']['runs with agent view turned off when the first tab opens'] = function()
  local _, fake = tabs.open_first_tab(child, 'agent-view-open')

  eq(agent_view_disabled(tabs.start_arguments_in_tab(child, fake, 1)), true)
end

T['a tab’s Claude Code']['runs with agent view turned off in a tab of :Aineo tab new'] = function()
  tabs.open_first_tab(child, 'agent-view-tab')
  local second = tabs.fake('agent-view-tab-second')
  tabs.use_next_fake(child, second)

  child.cmd('Aineo tab new')

  eq(agent_view_disabled(tabs.start_arguments_in_tab(child, second, 2)), true)
end

T['a tab’s Claude Code']['runs with agent view turned off on the new session of :Aineo new after an exit'] = function()
  tabs.use_own_state(child, 'agent-view-new')
  entry.use_fake(child, tabs.fake('agent-view-new-first', 'exit'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')
  local fresh = tabs.fake('agent-view-new-second')
  tabs.use_next_fake(child, fresh)

  child.cmd('Aineo new')

  local argv = tabs.start_arguments_in_tab(child, fresh, 1)
  eq({ #claude_session.words_after(argv, '--session-id'), agent_view_disabled(argv) }, { 1, true })
end

T['a tab’s Claude Code']['runs with agent view turned off on the session it resumes at a restart'] = function()
  local state = tabs.use_own_state(child, 'agent-view-restart')
  local folder = child.fn.getcwd()
  tabs.keep_tab_list(state, folder, { sessions = { KEPT }, current = 1 })
  tabs.keep_session_id(state, folder, KEPT)
  local fake = tabs.fake('agent-view-restart')
  entry.use_fake(child, fake)

  child.cmd('Aineo open')

  local argv = tabs.start_arguments_in_tab(child, fake, 1)
  eq(
    { claude_session.words_after(argv, '--resume'), agent_view_disabled(argv) },
    { { KEPT }, true }
  )
end

return T
