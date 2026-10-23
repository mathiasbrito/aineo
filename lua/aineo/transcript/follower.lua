--- The follower of `aineo.transcript`: follows the transcript of a session and
--- those of its subagents.

local consumer = require('aineo.transcript.consumer')
local file_follower = require('aineo.transcript.file_follower')
local signals = require('aineo.transcript.signals')
local subagents = require('aineo.transcript.subagents')

local M = {}

---@class aineo.transcript.FollowOptions
---@field path string the session's transcript file, which need not exist yet
---@field on_signal fun(signal: aineo.transcript.Signal) called for each signal, with the editor's API usable; a raise in it is caught and told once (`consumer.protect()`)
---@field on_unreadable_line? fun(length: integer) called with the length in bytes of each line that is not JSON or is too long, never with its text

--- The folder in which Claude Code writes the subagents' transcripts of the
--- session whose own transcript is the file `path`: `<session id>/subagents`
--- beside it.
---
---@param path string
---@return string
local function subagents_folder(path)
  return vim.fs.joinpath(vim.fn.fnamemodify(path, ':r'), 'subagents')
end

--- Starts following the session whose transcript is `options.path` and its
--- subagents (`aineo.transcript.follow_file()` and `follow_subagents()` give
--- the rules for the file and for each subagent).
---
---@param options aineo.transcript.FollowOptions
---@return aineo.transcript.Follower follower
function M.follow(options)
  vim.validate('options.path', options.path, 'string')
  vim.validate('options.on_signal', options.on_signal, 'function')
  vim.validate('options.on_unreadable_line', options.on_unreadable_line, 'function', true)

  local on_signal = consumer.protect(options.on_signal)
  local session = file_follower.follow_file({
    path = options.path,
    agent = signals.MAIN_AGENT,
    on_signal = on_signal,
    on_unreadable_line = options.on_unreadable_line,
  })
  local subagents_followed = subagents.follow_subagents({
    folder = subagents_folder(options.path),
    on_signal = on_signal,
    on_unreadable_line = options.on_unreadable_line,
  })

  return {
    stop = function()
      session.stop()
      subagents_followed.stop()
    end,
  }
end

return M
