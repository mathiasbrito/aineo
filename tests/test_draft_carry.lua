local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The working directory the cases keep a draft for: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/aineo'

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- The file that keeps the draft for the Claude session `session` under the
--- state directory `state`.
---
---@param state string
---@param session string
---@return string
local function session_draft_file(state, session)
  return vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(session) .. '.txt')
end

--- Writes `text` as the whole of `file`, making its directory.
---
---@param file string
---@param text string
local function plant_draft(file, text)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  vim.fn.writefile(vim.split(text, '\n', { plain = true }), file, 'b')
end

--- The whole text of the file at `path`, or nil when it cannot be read.
---
---@param path string
---@return string|nil
local function read_text(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- Gives the child's draft home its environment, the state directory `state`
--- and `WORKING_DIRECTORY`, with the file writes `_G.draft_files` when a case
--- has set them there, hands it a new, empty scratch buffer shown in the
--- current window, as the layout's Input is — `_G.input` there — and makes it
--- follow the Claude session `session`.
---
---@param state string
---@param session string
local function keep_input_following(state, session)
  child.lua(
    [[
      local state, working_directory, session = ...
      local draft = require('aineo.draft')
      draft.set_draft_environment({
        state_directory = state,
        working_directory = working_directory,
        files = _G.draft_files,
      })
      _G.input = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, _G.input)
      draft.keep_draft(_G.input)
      draft.follow_draft_session(session)
    ]],
    { state, WORKING_DIRECTORY, session }
  )
end

--- Replaces the text of the kept buffer, `_G.input` in the child, with
--- `lines`, as a change through the API does.
---
---@param lines string[]
local function set_input(lines)
  child.lua('vim.api.nvim_buf_set_lines(_G.input, 0, -1, true, ...)', { lines })
end

--- The lines of the kept buffer, `_G.input` in the child.
---
---@return string[]
local function input_lines()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.input, 0, -1, true)')
end

--- Tells the child's draft home to follow the Claude session `session` as a
--- claim's, carrying Input's text as `carry` says.
---
---@param session string
---@param carry string?
local function claim_carrying(session, carry)
  child.lua(
    "require('aineo.draft').follow_draft_session(..., { claim = true, carry = select(2, ...) })",
    { session, carry }
  )
end

T['a claim carrying Input'] = MiniTest.new_set()

T['a claim carrying Input']["to a session with no draft keeps Input's text, which becomes that session's draft and stays the left one's"] = function()
  local state = fixture.directory('draft-carry-no-draft')
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  claim_carrying('session-claimed', 'replace')

  eq({
    input = input_lines(),
    claimed = read_text(session_draft_file(state, 'session-claimed')),
    left = read_text(session_draft_file(state, 'session-left')),
  }, {
    input = { 'Typed for the left session' },
    claimed = 'Typed for the left session\n',
    left = 'Typed for the left session\n',
  })
end

T['a claim carrying Input']["to replace a session's other draft keeps Input's text, which takes that draft's place"] = function()
  local state = fixture.directory('draft-carry-replace')
  plant_draft(session_draft_file(state, 'session-claimed'), 'Kept for the claimed session\n')
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  claim_carrying('session-claimed', 'replace')

  eq({
    input = input_lines(),
    claimed = read_text(session_draft_file(state, 'session-claimed')),
    left = read_text(session_draft_file(state, 'session-left')),
  }, {
    input = { 'Typed for the left session' },
    claimed = 'Typed for the left session\n',
    left = 'Typed for the left session\n',
  })
end

T['a claim carrying Input']["to merge with a session's other draft makes that draft, a blank line, then Input's text, Input's and the session's, and leaves Input's text the left one's"] = function()
  local state = fixture.directory('draft-carry-merge')
  plant_draft(session_draft_file(state, 'session-claimed'), 'Kept for the claimed session\n')
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  claim_carrying('session-claimed', 'merge')

  eq({
    input = input_lines(),
    claimed = read_text(session_draft_file(state, 'session-claimed')),
    left = read_text(session_draft_file(state, 'session-left')),
  }, {
    input = { 'Kept for the claimed session', '', 'Typed for the left session' },
    claimed = 'Kept for the claimed session\n\nTyped for the left session\n',
    left = 'Typed for the left session\n',
  })
end

T['a claim carrying Input']["with Input empty shows the session's draft, which it leaves as it is"] = function()
  local state = fixture.directory('draft-carry-empty')
  plant_draft(session_draft_file(state, 'session-claimed'), 'Kept for the claimed session\n')
  keep_input_following(state, 'session-left')

  claim_carrying('session-claimed', 'replace')

  eq({
    input = input_lines(),
    claimed = read_text(session_draft_file(state, 'session-claimed')),
  }, {
    input = { 'Kept for the claimed session' },
    claimed = 'Kept for the claimed session\n',
  })
end

--- Tells the child's draft home to follow the Claude session `session` as a
--- claim's, carrying Input's text as `carry` says, and returns whether the
--- follow raised nothing, with every message it told the user meanwhile.
---
---@param session string
---@param carry string
---@return { followed: boolean, messages: string[] }
local function claim_carrying_noting_messages(session, carry)
  return child.lua_get(
    [[(function(session, carry)
      local messages = {}
      vim.notify = function(message)
        table.insert(messages, message)
      end
      local followed = pcall(
        require('aineo.draft').follow_draft_session,
        session,
        { claim = true, carry = carry }
      )
      return { followed = followed, messages = messages }
    end)(...)]],
    { session, carry }
  )
end

T['a claim carrying Input']['to a session whose draft cannot be read replaces nothing, and tells it as a follow does'] = function()
  local state = fixture.directory('draft-carry-unreadable')
  local claimed = session_draft_file(state, 'session-claimed')
  plant_draft(claimed, 'Kept for the claimed session\n')
  vim.uv.fs_chmod(claimed, 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(claimed, tonumber('600', 8))
  end)
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  local outcome = claim_carrying_noting_messages('session-claimed', 'replace')
  vim.uv.fs_chmod(claimed, tonumber('600', 8))

  eq({
    followed = outcome.followed,
    messages = #outcome.messages,
    claimed = read_text(claimed),
    left = read_text(session_draft_file(state, 'session-left')),
  }, {
    followed = true,
    messages = 1,
    claimed = 'Kept for the claimed session\n',
    left = 'Typed for the left session\n',
  })
end

--- Makes the child's draft home, once given its environment, refuse to open
--- for writing any file whose path holds `refused`, as a file system that
--- refuses it would; it opens every other as the home does.
---
---@param refused string
local function refuse_writes_to(refused)
  child.lua(
    [[
      local refused = ...
      _G.draft_files = {
        open_file = function(path)
          if path:find(refused, 1, true) then
            return nil, 'EACCES: permission denied'
          end
          return vim.uv.fs_open(path, 'w', tonumber('600', 8))
        end,
      }
    ]],
    { refused }
  )
end

T['a claim carrying Input']["whose write is refused tells it once, and shows the session's draft, Input's text staying the left one's"] = function()
  local state = fixture.directory('draft-carry-refused')
  local claimed = session_draft_file(state, 'session-claimed')
  plant_draft(claimed, 'Kept for the claimed session\n')
  refuse_writes_to(vim.fn.sha256('session-claimed'))
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  local outcome = claim_carrying_noting_messages('session-claimed', 'replace')

  eq({
    followed = outcome.followed,
    messages = outcome.messages,
    input = input_lines(),
    claimed = read_text(claimed),
    left = read_text(session_draft_file(state, 'session-left')),
  }, {
    followed = true,
    messages = {
      ("aineo: cannot keep Input's draft in %s: EACCES: permission denied"):format(claimed),
    },
    input = { 'Kept for the claimed session' },
    claimed = 'Kept for the claimed session\n',
    left = 'Typed for the left session\n',
  })
end

--- Whether the child's draft home says Input's text differs from the draft
--- of the Claude session `session`.
---
---@param session string
---@return boolean
local function differs_from_draft_of(session)
  return child.lua_get("require('aineo.draft').input_differs_from_draft(...)", { session })
end

T['a claim carrying Input']['refuses a carry other than replace or merge, naming it, and follows nothing'] = function()
  local state = fixture.directory('draft-carry-refuses')
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  local refusal = child.lua_get([[(function()
    local followed, failure = pcall(
      require('aineo.draft').follow_draft_session,
      'session-claimed',
      { claim = true, carry = 'swap' }
    )
    return { followed = followed, named = tostring(failure):find('carry', 1, true) ~= nil }
  end)()]])

  eq({
    refusal = refusal,
    input = input_lines(),
    claimed = read_text(session_draft_file(state, 'session-claimed')),
  }, {
    refusal = { followed = false, named = true },
    input = { 'Typed for the left session' },
    claimed = nil,
  })
end

T['whether Input differs from a draft'] = MiniTest.new_set()

T['whether Input differs from a draft']['is told from Input’s text and the session’s kept draft'] =
  MiniTest.new_set({
    parametrize = {
      { { 'Typed for the left session' }, 'Kept for the claimed session\n', true },
      { { 'Typed for the left session' }, 'Typed for the left session\n', false },
      { { 'Typed for the left session' }, '', false },
      { { '' }, 'Kept for the claimed session\n', false },
    },
  })

T['whether Input differs from a draft']['is told from Input’s text and the session’s kept draft']['as'] = function(
  lines,
  draft,
  expected
)
  local state = fixture.directory('draft-carry-differs')
  plant_draft(session_draft_file(state, 'session-claimed'), draft)
  keep_input_following(state, 'session-left')
  set_input(lines)

  eq(differs_from_draft_of('session-claimed'), expected)
end

T['whether Input differs from a draft']['is false for a session with no draft kept'] = function()
  local state = fixture.directory('draft-carry-differs-none')
  keep_input_following(state, 'session-left')
  set_input({ 'Typed for the left session' })

  eq(differs_from_draft_of('session-claimed'), false)
end

return T
