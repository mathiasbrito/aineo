--- What `\Vq` does for the tab the user is in: ends its walkthrough as `\vq`
--- does, and asks its Claude Code to write the whole walkthrough as a record,
--- an HTML file and a PDF at a path aineo chooses
--- (`aineo.entry.walkthrough_record_path`), with the words
--- `aineo.entry.walkthrough_record_instruction` holds, sent as the messages
--- of `\vn` are (`aineo.entry.walkthrough_moves`). When the agent's turn that
--- follows ends, tells the user, once, what was written.

local settings = require('aineo.entry.settings')
local walkthrough_moves = require('aineo.entry.walkthrough_moves')
local walkthrough_plan = require('aineo.entry.walkthrough_plan')
local walkthrough_record_instruction = require('aineo.entry.walkthrough_record_instruction')
local walkthrough_record_path = require('aineo.entry.walkthrough_record_path')

local M = {}

--- What a tab needs for its record: what the plan's pane needs of it, and the
--- folder its Claude Code works in, which a tab that shows a walkthrough step
--- has started its Claude Code in.
---@class aineo.entry.WalkthroughRecordTab : aineo.entry.WalkthroughPlanTab
---@field claude_directory fun(): string

--- What the user is told the instruction by while it waits for the agent's
--- turn to end.
local INSTRUCTION_NAME = 'Write the walkthrough record'

--- What the user is told when the PDF is there, the HTML it was made from
--- there or not.
local WRITTEN = 'aineo: the walkthrough record is written: %s'

--- What the user is told, as a warning, when only the HTML is there.
local HTML_ONLY =
  'aineo: the walkthrough record has no PDF, no PDF tool was found: its HTML is at %s'

--- What the user is told, as a warning, when neither file is there.
local NOT_WRITTEN = 'aineo: the walkthrough record was not written: there is no file at %s'

--- The record each tab has asked for and not yet told of, by tab: the PDF's
--- path, and whether the agent was seen working since the instruction went.
---@type table<aineo.entry.WalkthroughRecordTab, { path: string, working: boolean }>
local awaited = setmetatable({}, { __mode = 'k' })

--- The tabs whose turns are followed (`follow_turns_of()`).
---@type table<aineo.entry.WalkthroughRecordTab, boolean>
local followed = setmetatable({}, { __mode = 'k' })

--- Whether a file is there.
---
---@param path string
---@return boolean
local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

--- Tells the user what was written of the record `pdf_path` names, from the
--- files that are there: the PDF, else the HTML beside it, else nothing.
---
---@param pdf_path string
local function tell_what_was_written(pdf_path)
  local html_path = walkthrough_record_path.html_beside(pdf_path)
  if exists(pdf_path) then
    vim.notify(WRITTEN:format(pdf_path), vim.log.levels.INFO)
  elseif exists(html_path) then
    vim.notify(HTML_ONLY:format(html_path), vim.log.levels.WARN)
  else
    vim.notify(NOT_WRITTEN:format(pdf_path), vim.log.levels.WARN)
  end
end

--- Has the end of the turn that follows the instruction sent to `tab`'s agent
--- noted, once for each tab: the end of a turn in which the agent was seen
--- working since the instruction went tells the user what was written. The
--- turn that sends an instruction held back is not that turn.
---
---@param tab aineo.entry.WalkthroughRecordTab
local function follow_turns_of(tab)
  if followed[tab] then
    return
  end
  followed[tab] = true
  tab.on_busy_change(function(busy)
    local record = awaited[tab]
    if not record then
      return
    end
    if busy then
      record.working = true
    elseif record.working then
      awaited[tab] = nil
      tell_what_was_written(record.path)
    end
  end)
end

--- The message that asks `tab`'s agent for the record at a path no record
--- has: its words, the name the user is told it by, and, once it was sent,
--- the note that the turn that follows tells what was written.
---
---@param tab aineo.entry.WalkthroughRecordTab
---@return aineo.entry.WalkthroughMessage
local function message_asking_for_the_record(tab)
  local path = walkthrough_record_path.path_for({
    folder = tab.claude_directory(),
    record_folder = settings.resolved().walkthrough.record_folder,
    date = os.date('%Y-%m-%d'),
    title = walkthrough_plan.title_of(tab),
    is_taken = exists,
  })
  follow_turns_of(tab)
  return {
    text = walkthrough_record_instruction.text(path),
    name = INSTRUCTION_NAME,
    on_sent = function()
      awaited[tab] = { path = path, working = false }
    end,
  }
end

--- Ends the walkthrough of `tab` and asks its agent for the record of it.
--- Tells the user, and does nothing else, when the tab shows no walkthrough
--- step.
---
---@param tab aineo.entry.WalkthroughRecordTab? the tab the user is in, nil outside the tabs of aineo
function M.ask(tab)
  walkthrough_moves.end_with_message(tab, function()
    return message_asking_for_the_record(tab)
  end)
end

--- What `\Vq` does: asks for the record of the walkthrough of the aineo tab
--- the current tab page holds (`ask()`).
function M.ask_in_current_tab()
  M.ask(require('aineo.entry.registry').tab_of_current_page())
end

return M
