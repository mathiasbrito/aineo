--- The follower of `aineo.transcript`: follows the transcript of a session and
--- those of its subagents.

local consumer = require('aineo.transcript.consumer')
local continuation = require('aineo.transcript.continuation')
local file_follower = require('aineo.transcript.file_follower')
local signals = require('aineo.transcript.signals')
local subagents = require('aineo.transcript.subagents')

local M = {}

---@class aineo.transcript.SessionFollower : aineo.transcript.Follower
---@field sessions string[] the sessions of the chain followed: the one of `options.path` first, the one of the file followed last

---@class aineo.transcript.FollowOptions
---@field path string the session's transcript file, which need not exist yet
---@field on_signal fun(signal: aineo.transcript.Signal) called for each signal, with the editor's API usable; a raise in it is caught and told once (`consumer.protect()`)
---@field on_unreadable_line? fun(length: integer) called with the length in bytes of each line that is not JSON or is too long, never with its text
---@field since? number when the tab began following the session, in seconds since 1970; with it, a transcript that says the session was continued in another, in a line stamped at or after it, is followed to that one (`continuation.resolve()`); without it the transcript is followed as it is

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
--- the rules for the file and for each subagent). When that transcript says
--- the session was continued in another, since `options.since`, it follows the
--- transcript and the subagents of that one instead (`continuation.resolve()`).
--- A continued-in line written between that search and the replay of the tail
--- is told as news, once the follower is on its file, for the caller to follow
--- again.
---
---@param options aineo.transcript.FollowOptions
---@return aineo.transcript.SessionFollower follower
function M.follow(options)
  vim.validate('options.path', options.path, 'string')
  vim.validate('options.on_signal', options.on_signal, 'function')
  vim.validate('options.on_unreadable_line', options.on_unreadable_line, 'function', true)
  vim.validate('options.since', options.since, 'number', true)

  local on_signal = consumer.protect(options.on_signal)
  local path, sessions = continuation.resolve(options.path, options.since)
  local session = file_follower.follow_file({
    path = path,
    agent = signals.MAIN_AGENT,
    on_signal = on_signal,
    on_unreadable_line = options.on_unreadable_line,
  })
  local subagents_followed = subagents.follow_subagents({
    folder = subagents_folder(path),
    on_signal = on_signal,
    on_unreadable_line = options.on_unreadable_line,
  })

  local resolved_again = continuation.resolve(options.path, options.since)
  if resolved_again ~= path then
    on_signal({
      agent = signals.MAIN_AGENT,
      kind = 'session_continued',
      session = vim.fn.fnamemodify(resolved_again, ':t:r'),
    })
  end

  return {
    sessions = sessions,
    stop = function()
      session.stop()
      subagents_followed.stop()
    end,
  }
end

return M
