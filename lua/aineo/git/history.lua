--- Lists the commits of a repository since a base, or between two commits.

local process = require('aineo.git.process')

local M = {}

--- A commit, as the home lists it.
---@class aineo.git.Commit
---@field id string its full id
---@field subject string the first line of its message
---@field author string its author's name, as recorded
---@field authored_at integer when its author wrote it, in seconds since the epoch

--- The commits since a base.
---@class aineo.git.CommitsSince
---@field commits aineo.git.Commit[] the commits reachable from `HEAD` and not from the base, newest first
---@field base_is_ancestor boolean whether the base is still an ancestor of `HEAD`: false once a reset or a checkout left it behind

--- The code `git merge-base --is-ancestor` exits with when the first commit
--- is an ancestor of the second.
local IS_ANCESTOR_CODE = 0

--- The code it exits with when the first is not: an answer, not a failure.
local NOT_ANCESTOR_CODE = 1

--- What `git log -z` writes for each commit: its id, the time its author
--- wrote it and the author's name, a line break, then its subject. A name
--- holds no line break, and a subject, the first paragraph of a message
--- on one line, holds none either, so the first line break ends the name.
local LOG_FORMAT = '--format=%H %at %an%n%s'

--- The commits `git log -z` gave as `output` in `LOG_FORMAT`, in its order.
---
---@param output string
---@return aineo.git.Commit[]
local function parse_log(output)
  local commits = {}
  for _, record in ipairs(vim.split(output, '\0', { plain = true, trimempty = true })) do
    local id, authored_at, author, subject = record:match('^(%x+) (%d+) ([^\n]*)\n(.*)$')
    table.insert(commits, {
      id = id,
      subject = subject,
      author = author,
      authored_at = tonumber(authored_at),
    })
  end
  return commits
end

--- Lists the commits of `found` since the commit `base`, and calls
--- `done(nil, commits_since)`, or `done(failure)`. Before the first commit
--- there are none.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param base string|nil the full id of the commit the commits are counted from; nil counts every commit
---@param done fun(failure: aineo.git.Failure|nil, commits_since: aineo.git.CommitsSince|nil)
function M.commits_since(run, found, base, done)
  run(
    {
      directory = found.top,
      arguments = {
        'log',
        '-z',
        LOG_FORMAT,
        '--no-show-signature',
        '--encoding=UTF-8',
        '--ignore-missing',
        '--end-of-options',
        base and base .. '..HEAD' or 'HEAD',
        '--',
      },
    },
    process.or_fail(done, function(log)
      if not base then
        done(nil, { commits = parse_log(log.stdout), base_is_ancestor = true })
        return
      end
      run(
        {
          directory = found.top,
          arguments = { 'merge-base', '--is-ancestor', base, 'HEAD' },
          answers = { IS_ANCESTOR_CODE, NOT_ANCESTOR_CODE },
        },
        process.or_fail(done, function(ancestry)
          done(nil, {
            commits = parse_log(log.stdout),
            base_is_ancestor = ancestry.code == IS_ANCESTOR_CODE,
          })
        end)
      )
    end)
  )
end

--- Lists the commits of `found` reachable from the commit `to` and not from
--- the commit `from`, newest first, and calls `done(nil, commits)`, or
--- `done(failure)`. A commit a rebase merge made counts under its new id.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param from string|nil the full id of the commit the commits are counted from; nil counts every commit of `to`
---@param to string the full id of the commit the commits are counted to
---@param done fun(failure: aineo.git.Failure|nil, commits: aineo.git.Commit[]|nil)
function M.commits_between(run, found, from, to, done)
  run(
    {
      directory = found.top,
      arguments = {
        'log',
        '-z',
        LOG_FORMAT,
        '--no-show-signature',
        '--encoding=UTF-8',
        '--end-of-options',
        from and from .. '..' .. to or to,
        '--',
      },
    },
    process.or_fail(done, function(log)
      done(nil, parse_log(log.stdout))
    end)
  )
end

--- A commit of the commit graph, as the home lists it: a commit, and how
--- git tells it in its graph.
---@class aineo.git.GraphCommit: aineo.git.Commit
---@field abbreviated_id string its id as `--abbrev-commit` shortens it
---@field age string how long ago its author wrote it, as `--date=relative` tells it: `3 hours ago`
---@field refs? string the names that point at it, as `%D` gives them: `HEAD -> main, tag: v1, origin/main`; nil when none does

--- One line of the commit graph: what git draws of the graph on it, and the
--- commit it shows, when it shows one.
---@class aineo.git.GraphLine
---@field graph string the graph's part of the line, as git draws it: `| * ` before a commit, `|/| ` on a line that shows none
---@field commit? aineo.git.GraphCommit the commit the line shows; nil on a line of the graph alone

--- The commit graph of a repository.
---@class aineo.git.CommitGraph
---@field lines aineo.git.GraphLine[] its lines, as git draws them, newest commit first
---@field cut boolean whether older commits were left out, past the limit

--- Where a commit's fields begin, after the graph, and what ends each: a
--- byte no graph, id, time, age, name, reference or subject holds — git
--- refuses it in a commit's message and in an identity, and a reference's
--- name holds none.
local FIELD = '\0'

--- What `git log --graph` writes after the graph for each commit: its id,
--- abbreviated id, author time, relative age, author's name, the names
--- that point at it and its subject, each after `FIELD`. None holds a line
--- break: a subject is the first paragraph on one line.
local GRAPH_FORMAT = '--format=format:%x00%H%x00%h%x00%at%x00%ar%x00%an%x00%D%x00%s'

--- The line of the graph `line`, as git wrote it in `GRAPH_FORMAT`.
---
---@param line string
---@return aineo.git.GraphLine
local function parse_graph_line(line)
  local start = line:find(FIELD, 1, true)
  if not start then
    return { graph = line }
  end
  local fields = vim.split(line:sub(start + 1), FIELD, { plain = true })
  local id, abbreviated_id, authored_at, age, author, refs, subject = unpack(fields)
  return {
    graph = line:sub(1, start - 1),
    commit = {
      id = id,
      abbreviated_id = abbreviated_id,
      authored_at = tonumber(authored_at),
      age = age,
      author = author,
      refs = refs ~= '' and refs or nil,
      subject = subject,
    },
  }
end

--- The commit graph git wrote as `output` in `GRAPH_FORMAT`, having been
--- asked for one commit more than `limit`: its lines up to the `limit`th
--- commit's — the graph's lines after it, which lead to the commit left
--- out, left out too — and whether the one more came, which says older
--- commits were left out.
---
---@param output string
---@param limit integer
---@return aineo.git.CommitGraph
local function parse_graph(output, limit)
  local lines, commits, last_commit_line = {}, 0, 0
  for _, written in ipairs(vim.split(output, '\n', { plain = true, trimempty = true })) do
    local line = parse_graph_line(written)
    if line.commit then
      commits = commits + 1
      if commits > limit then
        return { lines = vim.list_slice(lines, 1, last_commit_line), cut = true }
      end
      last_commit_line = #lines + 1
    end
    table.insert(lines, line)
  end
  return { lines = lines, cut = false }
end

--- Draws the commit graph of `found` — every branch, tag and remote-tracking
--- branch, as `git log --graph --all --abbrev-commit --date=relative` draws
--- it — of its newest `limit` commits, and calls `done(nil, graph)`, or
--- `done(failure)`. Before the first commit it has no line. It holds no
--- colour, whatever colour the user's git settings ask for.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param limit integer how many commits to draw, at least 1
---@param done fun(failure: aineo.git.Failure|nil, graph: aineo.git.CommitGraph|nil)
function M.commit_graph(run, found, limit, done)
  run(
    {
      directory = found.top,
      arguments = {
        'log',
        '--graph',
        '--all',
        '--abbrev-commit',
        '--date=relative',
        GRAPH_FORMAT,
        '--no-color',
        '--no-show-signature',
        '--encoding=UTF-8',
        '--max-count=' .. (limit + 1),
        '--end-of-options',
        '--',
      },
    },
    process.or_fail(done, function(log)
      done(nil, parse_graph(log.stdout, limit))
    end)
  )
end

return M
