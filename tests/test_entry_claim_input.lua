local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

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
  child.stop()
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

--- A session id of the form Claude Code gives, which no Claude Code of the
--- child runs.
local CLAIMED = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- What the cases type into Input before a claim.
local TYPED = 'Typed for my own session'

--- The draft the claimed session keeps, when a case gives it one.
local CLAIMED_DRAFT = 'Kept for the claimed session'

--- The question a claim of `CLAIMED` asks when Input's text and its draft
--- differ: the ways of carrying Input's text it offers, their labels, and
--- its prompt.
local QUESTION = {
  items = { 'replace', 'merge' },
  labels = {
    "Replace: Input's text becomes its draft",
    "Merge: its draft, a blank line, then Input's text",
  },
  prompt = 'Input holds text, and session ' .. CLAIMED .. ' has a draft of its own',
}

--- The lines of the layout's Input, read in the child.
local INPUT_LINES =
  "vim.api.nvim_buf_get_lines(require('aineo.layout').input_buffer(), 0, -1, true)"

--- Makes `vim.ui.select` in the child note each question it is asked in
--- `_G.questions`, as its items, the label it shows for each and its prompt,
--- and answer it at once with the item `answer`, or as Esc does when
--- `answer` is nil.
---
---@param answer string?
local function answer_questions_with(answer)
  child.lua(
    [[
      _G.questions = {}
      local answer = ...
      vim.ui.select = function(items, options, on_choice)
        table.insert(_G.questions, {
          items = items,
          labels = vim.tbl_map(options.format_item, items),
          prompt = options.prompt,
        })
        on_choice(answer)
      end
    ]],
    { answer }
  )
end

--- The questions `vim.ui.select` was asked in the child since
--- `answer_questions_with()`.
---
---@return { items: string[], labels: string[], prompt: string }[]
local function questions()
  return child.lua_get('_G.questions')
end

--- Gives the child a state directory of its own for the case `name`, opens
--- aineo there running a fake Claude Code, and waits until it is ready;
--- returns the state directory and the session it started on.
---
---@param name string
---@return string state
---@return string own
local function open_until_ready(name)
  local home = fixture.directory(name)
  child.lua('vim.env.XDG_STATE_HOME = ...', { home })
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return vim.fs.joinpath(home, 'nvim'), claude_session.followed_session_id(child)
end

--- The file that keeps Input's draft of the Claude session `id` under
--- `state`.
---
---@param state string
---@param id string
---@return string
local function draft_file(state, id)
  return vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(id) .. '.txt')
end

--- Writes `lines` as the draft of the Claude session `id` under `state`, as
--- an earlier editor left it.
---
---@param state string
---@param id string
---@param lines string[]
local function leave_draft(state, id, lines)
  local file = draft_file(state, id)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  assert(vim.fn.writefile(lines, file) == 0, 'cannot write ' .. file)
end

--- The lines of the draft of the Claude session `id` under `state`, or nil
--- when it has none.
---
---@param state string
---@param id string
---@return string[]?
local function draft_lines(state, id)
  local file = draft_file(state, id)
  return vim.fn.filereadable(file) == 1 and vim.fn.readfile(file) or nil
end

T[':Aineo claim {id}'] = MiniTest.new_set()

T[':Aineo claim {id}']['with Input empty shows the claimed session’s draft, asking nothing'] = function()
  local state = open_until_ready('entry-claim-input-empty')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  answer_questions_with('merge')

  child.cmd('Aineo claim ' .. CLAIMED)

  eq({
    questions = #questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
  }, {
    questions = 0,
    input = { CLAIMED_DRAFT },
    claimed = { CLAIMED_DRAFT },
  })
end

T[':Aineo claim {id}']['with text in Input and no draft of the claimed session keeps the text, which both sessions keep, asking nothing'] = function()
  local state, own = open_until_ready('entry-claim-input-no-draft')
  entry.set_input(child, { TYPED })
  answer_questions_with('replace')

  child.cmd('Aineo claim ' .. CLAIMED)

  eq({
    questions = #questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
    own = draft_lines(state, own),
  }, {
    questions = 0,
    input = { TYPED },
    claimed = { TYPED },
    own = { TYPED },
  })
end

T[':Aineo claim {id}']['with text in Input and another draft of the claimed session asks once, and Replace keeps the text as both sessions’ draft'] = function()
  local state, own = open_until_ready('entry-claim-input-replace')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  entry.set_input(child, { TYPED })
  answer_questions_with('replace')

  child.cmd('Aineo claim ' .. CLAIMED)

  eq({
    questions = questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
    own = draft_lines(state, own),
  }, {
    questions = { QUESTION },
    input = { TYPED },
    claimed = { TYPED },
    own = { TYPED },
  })
end

T[':Aineo claim {id}']['with text in Input and another draft of the claimed session, answered Merge, shows and keeps that draft, a blank line, then the text, which the session left keeps'] = function()
  local state, own = open_until_ready('entry-claim-input-merge')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  entry.set_input(child, { TYPED })
  answer_questions_with('merge')

  child.cmd('Aineo claim ' .. CLAIMED)

  eq({
    questions = questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
    own = draft_lines(state, own),
  }, {
    questions = { QUESTION },
    input = { CLAIMED_DRAFT, '', TYPED },
    claimed = { CLAIMED_DRAFT, '', TYPED },
    own = { TYPED },
  })
end

T[':Aineo claim {id}']['with text in Input and another draft of the claimed session, the question cancelled, shows that draft and says the text stayed the left session’s'] = function()
  local state, own = open_until_ready('entry-claim-input-cancelled')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  entry.set_input(child, { TYPED })
  answer_questions_with(nil)

  child.cmd('Aineo claim ' .. CLAIMED)

  eq({
    questions = questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
    own = draft_lines(state, own),
    messages = entry.messages(child),
  }, {
    questions = { QUESTION },
    input = { CLAIMED_DRAFT },
    claimed = { CLAIMED_DRAFT },
    own = { TYPED },
    messages = {
      {
        message = "aineo: Input's text was not carried over; it stays the draft of session " .. own,
        level = vim.log.levels.INFO,
      },
    },
  })
end

T[':Aineo claim {id}']['with the question cancelled before any session was followed says the text stayed the folder’s'] = function()
  local home = fixture.directory('entry-claim-input-folder')
  child.lua('vim.env.XDG_STATE_HOME = ...', { home })
  leave_draft(vim.fs.joinpath(home, 'nvim'), CLAIMED, { CLAIMED_DRAFT })
  entry.use_fake(child, claude_session.fake('entry-claim-input-folder', 'trust'))
  child.cmd('Aineo open')
  entry.set_input(child, { TYPED })
  answer_questions_with(nil)

  child.cmd('Aineo claim ' .. CLAIMED)

  eq(entry.messages(child), {
    {
      message = "aineo: Input's text was not carried over; it stays the draft of this folder",
      level = vim.log.levels.INFO,
    },
  })
end

T[':Aineo claim {id}']['answered once its tab page has closed claims nothing and carries nothing'] = function()
  local state = open_until_ready('entry-claim-input-closed')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  entry.set_input(child, { TYPED })
  child.lua([[
    vim.ui.select = function(_, _, on_choice)
      _G.answer_later = on_choice
    end
  ]])
  child.cmd('Aineo claim ' .. CLAIMED)
  child.cmd('tabnew')
  child.cmd('1tabclose')

  local answered = child.lua_get("pcall(_G.answer_later, 'replace')")

  eq({
    answered = answered,
    claimant = child.lua_get(
      "require('aineo.mcp').session_claimant(vim.fn.stdpath('state'), ...)",
      { CLAIMED }
    ),
    claimed = draft_lines(state, CLAIMED),
  }, {
    answered = true,
    claimant = vim.NIL,
    claimed = { CLAIMED_DRAFT },
  })
end

--- The messages the child has told the user at `level` since its start.
---
---@param level integer
---@return string[]
local function messages_at(level)
  return child.lua_get(
    [[(function(level)
      return vim.iter(_G.entry_test_messages):filter(function(told)
        return told.level == level
      end):map(function(told)
        return told.message
      end):totable()
    end)(...)]],
    { level }
  )
end

T[':Aineo claim {id}']['with the question cancelled while Input’s text cannot be saved says the text is in Input only'] = function()
  local state, own = open_until_ready('entry-claim-input-unsaved')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  local drafts = vim.fs.dirname(draft_file(state, CLAIMED))
  entry.set_input(child, { TYPED })
  vim.uv.fs_chmod(drafts, tonumber('500', 8))
  MiniTest.finally(function()
    vim.uv.fs_chmod(drafts, tonumber('700', 8))
  end)
  answer_questions_with(nil)

  child.cmd('Aineo claim ' .. CLAIMED)
  vim.uv.fs_chmod(drafts, tonumber('700', 8))

  eq({
    input = child.lua_get(INPUT_LINES),
    own = draft_lines(state, own),
    told = messages_at(vim.log.levels.INFO),
  }, {
    input = { TYPED },
    own = nil,
    told = { "aineo: Input's text was not carried over, nor saved; it is in Input only" },
  })
end

T[':Aineo claim {id}']['of the session Input follows already asks nothing and tells nothing, a change not saved yet included'] = function()
  local state = open_until_ready('entry-claim-input-again')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  answer_questions_with('merge')
  child.cmd('Aineo claim ' .. CLAIMED)
  entry.set_input(child, { CLAIMED_DRAFT, 'and more typed' })
  answer_questions_with(nil)

  child.cmd('Aineo claim ' .. CLAIMED)

  eq({
    questions = #questions(),
    input = child.lua_get(INPUT_LINES),
    messages = entry.messages(child),
  }, {
    questions = 0,
    input = { CLAIMED_DRAFT, 'and more typed' },
    messages = {},
  })
end

T[':Aineo claim'] = MiniTest.new_set()

T[':Aineo claim']['with no word, from a claim, shows the own session’s draft, carrying nothing and asking nothing'] = function()
  local state, own = open_until_ready('entry-claim-input-return')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  answer_questions_with(nil)
  child.cmd('Aineo claim ' .. CLAIMED)
  entry.set_input(child, { TYPED })
  answer_questions_with('replace')

  child.cmd('Aineo claim')

  eq({
    questions = #questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
    own = draft_lines(state, own),
  }, {
    questions = 0,
    input = { '' },
    claimed = { TYPED },
    own = nil,
  })
end

T['a session another Claude Code process switches to'] = MiniTest.new_set()

--- A session id of the form Claude Code gives, for a session another
--- process switches to from the tab's own session's conversation.
local FORK = '7d1f0b9e-3c2a-4e5f-9a8b-6c4d2e1f0a3b'

T['a session another Claude Code process switches to']['under the tab’s start token, while a claim of another session holds, starts from its own draft and carries nothing'] = function()
  local state = open_until_ready('entry-claim-input-fork-claimed')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  leave_draft(state, FORK, { 'Kept for the fork' })
  answer_questions_with('merge')
  child.cmd('Aineo claim ' .. CLAIMED)

  child.lua(
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'resume', claude.start_token(), nil, 1, nil)
    ]],
    { FORK }
  )

  eq({
    questions = #questions(),
    input = child.lua_get(INPUT_LINES),
    fork = draft_lines(state, FORK),
    claimed = draft_lines(state, CLAIMED),
  }, {
    questions = 0,
    input = { 'Kept for the fork' },
    fork = { 'Kept for the fork' },
    claimed = { CLAIMED_DRAFT },
  })
end

T['a session another Claude Code process switches to']['under the tab’s start token takes Input’s text in place of its draft, which the session left keeps, asking nothing'] = function()
  local state, own = open_until_ready('entry-claim-input-fork')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  entry.set_input(child, { TYPED })
  answer_questions_with('merge')

  child.lua(
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'resume', claude.start_token(), nil, 1, nil)
    ]],
    { CLAIMED }
  )

  eq({
    questions = #questions(),
    input = child.lua_get(INPUT_LINES),
    claimed = draft_lines(state, CLAIMED),
    own = draft_lines(state, own),
  }, {
    questions = 0,
    input = { TYPED },
    claimed = { TYPED },
    own = { TYPED },
  })
end

T['a new session another Claude Code process starts'] =
  MiniTest.new_set({ parametrize = { { 'startup' }, { 'fork' } } })

T['a new session another Claude Code process starts']['under the tab’s start token is not followed, nor is Input’s text carried to it'] = function(
  source
)
  local state = open_until_ready('entry-claim-input-new-elsewhere')
  leave_draft(state, CLAIMED, { CLAIMED_DRAFT })
  leave_draft(state, FORK, { 'Kept for the fork' })
  entry.set_input(child, { TYPED })

  child.lua(
    [[
      local claude = require('aineo.claude')
      local new, switched, source = ...
      claude.receive_session_event('SessionStart', new, source, claude.start_token(), nil, 1, nil)
      claude.receive_session_event('SessionStart', switched, 'resume', claude.start_token(), nil, 1, nil)
    ]],
    { CLAIMED, FORK, source }
  )
  vim.wait(claude_session.PATIENCE_MS, function()
    return vim.deep_equal(draft_lines(state, FORK), { TYPED })
  end, 20)

  eq({
    new = draft_lines(state, CLAIMED),
    switched = draft_lines(state, FORK),
  }, {
    new = { CLAIMED_DRAFT },
    switched = { TYPED },
  })
end

return T
