--- The preview of an office pack: a scripted show of every state of the
--- office's vocabulary in turn, each with a line naming it over the picture,
--- for the author of a pack to see what the pack draws. The agents are
--- scripted here, not heard from a transcript: the preview reads no file and
--- calls nothing. The vocabulary is required when a preview is made, so that
--- loading this module loads no other home.

local text_module = require('aineo.office.text')

local M = {}

--- How long the preview shows each state when it is not told, in seconds.
M.DEFAULT_SECONDS_PER_STATE = 9

--- The empty cells kept between the line that names the state and the edge
--- of the office.
local MARGIN_CELLS = 1

--- The group of the line that names the state; linked to the group a
--- colorscheme already colours titles with.
local CAPTION_GROUP = 'AineoOfficePreviewCaption'

--- The tasks the main agent has while it plans, which the whiteboard shows.
local PLANNING_TASKS = {
  { subject = 'Read the spec', done = true },
  { subject = 'Write the test', done = true },
  { subject = 'Make it pass', done = false },
  { subject = 'Review', done = false },
}

--- What the agent on the web looks for, shown on its monitor.
local WEB_CLUE = 'neovim.io'

--- How long after the scene begins the test run's verdict shows, and the
--- printer prints, in seconds.
local VERDICT_AFTER_SECONDS = 3
local REPORT_AFTER_SECONDS = 1

--- The other agents some states need to be seen well, by the main agent's
--- state: a subagent arriving as the main agent delegates, subagents at work
--- as it waits for them, and everyone idle for the random life to play.
local COMPANIONS = {
  delegating = { { id = 'explore', state = 'arriving' } },
  waiting_for_subagents = {
    { id = 'explore', state = 'reading' },
    { id = 'general', state = 'searching' },
  },
  idle = { { id = 'explore', state = 'idle' }, { id = 'general', state = 'idle' } },
}

---@class aineo.office.PreviewOptions
---@field start number when the preview begins, on the office's clock, in seconds
---@field seconds_per_state? number how long each state shows; `DEFAULT_SECONDS_PER_STATE` when not given

---@class aineo.office.Preview
---@field agents fun(now: number): aineo.office_states.Agent[] the agents of the scene at `now`, the main agent first
---@field caption fun(now: number): string the words that name the scene at `now`
---@field overlay fun(picture: aineo.office_scene.Picture, now: number): aineo.office_scene.Picture the picture with the caption drawn over its first row

--- Makes the highlight group of the caption, unless the user or a
--- colorscheme made it. Remade after a colorscheme clears it.
function M.define_group()
  vim.api.nvim_set_hl(0, CAPTION_GROUP, { link = 'Title', default = true })
end

--- The states of the vocabulary that have a number, in order: the 24 states,
--- not the parents.
---
---@return string[]
local function numbered_states()
  local names = {}
  for _, state in ipairs(require('aineo.office_states').vocabulary()) do
    if state.number then
      table.insert(names, state.name)
    end
  end
  return names
end

--- What the main agent knows in the scene of `state`, which began at `since`:
--- the tasks it plans, what it looks up on the web, how its tests ended, when
--- it reported.
---
---@param state string
---@param since number
---@return aineo.office_states.AgentDetails
local function main_details(state, since)
  local details = { tasks = {} }
  if state == 'planning' then
    details.tasks = PLANNING_TASKS
  elseif state == 'on_the_web' then
    details.web_clue = WEB_CLUE
  elseif state == 'running_tests' then
    details.test_verdict = { passed = true, at = since + VERDICT_AFTER_SECONDS }
  elseif state == 'reporting' then
    details.reported_at = since + REPORT_AFTER_SECONDS
  end
  return details
end

--- The agents of the scene of `state`, which began at `since`: the main agent
--- in the state and the companions the state has.
---
---@param state string
---@param since number
---@return aineo.office_states.Agent[]
local function scene_agents(state, since)
  local agents =
    { { id = 'main', state = state, since = since, details = main_details(state, since) } }
  for _, companion in ipairs(COMPANIONS[state] or {}) do
    table.insert(agents, {
      id = companion.id,
      state = companion.state,
      since = since,
      details = { tasks = {} },
    })
  end
  return agents
end

--- A preview that shows each state of the vocabulary in turn, from
--- `options.start`, and starts over after the last.
---
---@param options aineo.office.PreviewOptions
---@return aineo.office.Preview
function M.new_preview(options)
  local states = numbered_states()
  local seconds = options.seconds_per_state or M.DEFAULT_SECONDS_PER_STATE

  --- The number of the scene at `now`, from 0 and growing without end, and
  --- the time it began.
  ---
  ---@param now number
  ---@return integer scene
  ---@return number began
  local function scene_at(now)
    local scene = math.floor((now - options.start) / seconds)
    return scene, options.start + scene * seconds
  end

  local preview = {}

  function preview.agents(now)
    local scene, began = scene_at(now)
    return scene_agents(states[scene % #states + 1], began)
  end

  function preview.caption(now)
    local scene = scene_at(now)
    local index = scene % #states + 1
    return ('preview %d/%d · %s'):format(index, #states, states[index])
  end

  function preview.overlay(picture, now)
    local width = vim.fn.strdisplaywidth(picture.rows[1].text)
    local caption = text_module.cut_to_cells(preview.caption(now), width - 2 * MARGIN_CELLS)
    local rows = vim.list_slice(picture.rows)
    rows[1] = text_module.put_over(
      rows[1],
      MARGIN_CELLS,
      vim.fn.strdisplaywidth(caption),
      caption,
      CAPTION_GROUP
    )
    return vim.tbl_extend('force', picture, { rows = rows })
  end

  return preview
end

return M
