--- The follower of the subagents of one session, for `aineo.transcript`: Claude
--- Code writes each subagent's transcript as `agent-<id>.jsonl` in the
--- session's `subagents` folder, with `agent-<id>.meta.json` beside it. This
--- follows the folder: a subagent arrives with its transcript and leaves when
--- its meta file says it is over.
---
--- It reads the folder's listing, the meta files and the transcripts, and
--- nothing else; it never writes them.

local file_follower = require('aineo.transcript.file_follower')
local watching = require('aineo.transcript.watching')

local M = {}

--- A subagent's transcript's file name, with the subagent's id as its capture.
local TRANSCRIPT_NAME_PATTERN = '^agent%-([%w_%-]+)%.jsonl$'

--- How many subagents the follower follows at once; a folder that holds more
--- has the first of them, by id, followed. Each followed subagent holds a
--- watch and a timer.
local MAX_RUNNING_SUBAGENTS = 64

--- The longest meta file the follower reads; a longer one counts as unreadable.
local MAX_META_BYTES = 64 * 1024

---@class aineo.transcript.SubagentsOptions
---@field folder string the session's `subagents` folder, which need not exist yet
---@field on_signal fun(signal: aineo.transcript.Signal) called for each signal, with the editor's API usable
---@field on_unreadable_line? fun(length: integer) called with the length in bytes of each line that is not JSON or is too long, never with its text

--- The ids of the subagents whose transcripts the folder holds, sorted.
---
---@param folder string
---@return string[] ids
local function ids_in(folder)
  local ids = {}
  local entries = vim.uv.fs_scandir(folder)
  if not entries then
    return ids
  end
  local name, entry_type = vim.uv.fs_scandir_next(entries)
  while name do
    local id = entry_type == 'file' and name:match(TRANSCRIPT_NAME_PATTERN)
    if id then
      table.insert(ids, id)
    end
    name, entry_type = vim.uv.fs_scandir_next(entries)
  end
  table.sort(ids)
  return ids
end

--- Whether the meta file at `path` says its subagent is over: it carries
--- `finished` or `stoppedByUser`. A meta file that is missing, not a regular
--- file (opening a named pipe would hold the editor), too long or not JSON
--- says nothing, so its subagent is taken to run.
---
---@param path string
---@return boolean
local function is_over(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return false
  end
  local file = io.open(path, 'rb')
  if not file then
    return false
  end
  local text = file:read(MAX_META_BYTES + 1) or ''
  file:close()
  local decoded, meta = pcall(vim.json.decode, text, { luanil = { object = true } })
  if not decoded or type(meta) ~= 'table' then
    return false
  end
  return meta.finished == true or meta.stoppedByUser == true
end

--- Starts following the subagents in `options.folder`.
---
--- Each subagent that runs when this starts arrives as a `subagent_started`
--- signal and its transcript's tail, all marked `replayed = true`; one that is
--- over by then is not heard of. Each subagent that arrives later gives a
--- `subagent_started` signal and then, as they are written, the signals of its
--- lines from the first. A subagent whose meta file says it is over gives the
--- signals of the lines it wrote last, then `subagent_finished`, and is
--- followed no more. A subagent whose meta file has not been written is taken
--- to run.
---
--- Signals are delivered from the editor's main loop, never from a fast event.
---
---@param options aineo.transcript.SubagentsOptions
---@return aineo.transcript.Follower
function M.follow_subagents(options)
  vim.validate('options.folder', options.folder, 'string')
  vim.validate('options.on_signal', options.on_signal, 'function')
  vim.validate('options.on_unreadable_line', options.on_unreadable_line, 'function', true)

  local stopped = false
  ---@type table<string, aineo.transcript.FileFollower> the subagents that run
  local running = {}
  local running_count = 0
  ---@type table<string, true> the subagents that were over when first seen, or are now
  local over = {}
  ---@type table<string, true> the subagents the folder held when the follower started
  local present_at_start = {}

  ---@param id string
  ---@return string
  local function transcript_path(id)
    return vim.fs.joinpath(options.folder, ('agent-%s.jsonl'):format(id))
  end

  ---@param id string
  ---@return string
  local function meta_path(id)
    return vim.fs.joinpath(options.folder, ('agent-%s.meta.json'):format(id))
  end

  --- Starts the subagent `id`, whose transcript is `past` when it was there
  --- before the follower started, even if the subagent is admitted later,
  --- when a slot frees.
  ---
  ---@param id string
  ---@param past boolean
  local function arrive(id, past)
    options.on_signal({ agent = id, kind = 'subagent_started', replayed = past or nil })
    if stopped then
      return
    end
    running_count = running_count + 1
    running[id] = file_follower.follow_file({
      path = transcript_path(id),
      agent = id,
      on_signal = options.on_signal,
      on_unreadable_line = options.on_unreadable_line,
      replay_existing = past,
    })
  end

  --- Ends the subagent `id` after the last lines it wrote, and tells so unless
  --- a callback stopped the follower meanwhile.
  ---
  ---@param id string
  local function leave(id)
    local follower = running[id]
    running[id] = nil
    running_count = running_count - 1
    over[id] = true
    follower.read_to_end()
    follower.stop()
    if not stopped then
      options.on_signal({ agent = id, kind = 'subagent_finished' })
    end
  end

  --- Looks at the folder: starts the subagents it holds that are new and
  --- running (up to `MAX_RUNNING_SUBAGENTS`), ends those whose meta file says
  --- they are over.
  ---
  ---@param past boolean whether what the folder holds was there before the follower started
  local function look(past)
    for _, id in ipairs(ids_in(options.folder)) do
      if stopped then
        return
      end
      if past then
        present_at_start[id] = true
      end
      if running[id] and is_over(meta_path(id)) then
        leave(id)
      elseif not running[id] and not over[id] and running_count < MAX_RUNNING_SUBAGENTS then
        if is_over(meta_path(id)) then
          over[id] = true
        else
          arrive(id, present_at_start[id] == true)
        end
      end
    end
  end

  look(true)

  local watch = watching.watch(options.folder, function()
    look(false)
  end)

  return {
    stop = function()
      stopped = true
      watch.stop()
      for _, follower in pairs(running) do
        follower.stop()
      end
      running = {}
    end,
  }
end

return M
