local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for its commit graph with the limit that follows
--- it, and returns what `_G.await` saw of the second.
local COMMIT_GRAPH = [[
  local directory, limit = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.commit_graph(found.result, limit, done)
  end)
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

--- The time the commit `Begin` of `git_repo.create_graph()` is written at,
--- and each later one, a minute apart.
local AT = git_repo.GRAPH_STARTS_AT

--- The commit of the graph whose full id is `id`, as the home gives it, in
--- the repository `top`, its age told as git tells it now.
---
---@param top string
---@param id string
---@param fields { author: string, at: integer, subject: string, refs?: string }
---@return table
local function graph_commit(top, id, fields)
  return {
    id = id,
    abbreviated_id = id:sub(1, 7),
    authored_at = fields.at,
    age = git_repo.relative_age(top, id),
    author = fields.author,
    refs = fields.refs,
    subject = fields.subject,
  }
end

T['the commit graph'] = MiniTest.new_set()

T['the commit graph']['lists every branch’s commits under the graph git draws, each with its fields'] = function()
  local top, commits = git_repo.create_graph('graph-all')

  local seen = child.lua(COMMIT_GRAPH, { top, 1000 })

  eq(seen.failure, nil)
  eq(seen.result, {
    cut = false,
    lines = {
      {
        graph = '* ',
        commit = graph_commit(top, commits.other, {
          author = 'Carol',
          at = AT + 240,
          subject = 'Other work',
          refs = 'tag: v1, other',
        }),
      },
      {
        graph = '| * ',
        commit = graph_commit(top, commits.merge, {
          author = 'Ada',
          at = AT + 180,
          subject = 'Merge side',
          refs = 'HEAD -> main',
        }),
      },
      { graph = '|/| ' },
      {
        graph = '| * ',
        commit = graph_commit(top, commits.side, {
          author = 'Bartholomew',
          at = AT + 60,
          subject = 'Side work',
          refs = 'side',
        }),
      },
      {
        graph = '* | ',
        commit = graph_commit(top, commits.main, {
          author = 'Ada',
          at = AT + 120,
          subject = 'Main work',
        }),
      },
      { graph = '|/  ' },
      {
        graph = '* ',
        commit = graph_commit(top, commits.begin, {
          author = 'Ada',
          at = AT,
          subject = 'Begin',
        }),
      },
    },
  })
end

T['the commit graph']['stops at the limit’s last commit and says older ones were left out'] = function()
  local top, commits = git_repo.create_graph('graph-limit')

  local seen = child.lua(COMMIT_GRAPH, { top, 2 })

  eq(seen.result, {
    cut = true,
    lines = {
      {
        graph = '* ',
        commit = graph_commit(top, commits.other, {
          author = 'Carol',
          at = AT + 240,
          subject = 'Other work',
          refs = 'tag: v1, other',
        }),
      },
      {
        graph = '| * ',
        commit = graph_commit(top, commits.merge, {
          author = 'Ada',
          at = AT + 180,
          subject = 'Merge side',
          refs = 'HEAD -> main',
        }),
      },
    },
  })
end

T['the commit graph']['leaves nothing out when the repository has exactly the limit’s commits'] = function()
  local top, commits = git_repo.create_graph('graph-exact')

  local seen = child.lua(COMMIT_GRAPH, { top, 5 })

  eq({ cut = seen.result.cut, lines = #seen.result.lines }, { cut = false, lines = 7 })
  eq(seen.result.lines[7].commit.id, commits.begin)
end

T['the commit graph']['has no line before the first commit'] = function()
  local top = git_repo.create_unborn('graph-unborn')

  local seen = child.lua(COMMIT_GRAPH, { top, 1000 })

  eq({ failure = seen.failure, result = seen.result }, { result = { cut = false, lines = {} } })
end

return T
