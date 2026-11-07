local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local projects = require('aineo.projects')

local T = MiniTest.new_set()

--- How long a case waits for an answer, in milliseconds.
local PATIENCE_MS = 2000

--- A stand-in for the git home's `find_repository()` that finds the
--- repositories of `repositories`, by the folder git would be asked in, and
--- records the folders it was asked in.
---
---@param repositories table<string, aineo.git.Repository>
---@return fun(directory: string, done: fun(failure: table|nil, repository: aineo.git.Repository|nil)) find
---@return string[] asked
local function fake_find(repositories)
  local asked = {}
  local function find(directory, done)
    table.insert(asked, directory)
    vim.schedule(function()
      local repository = repositories[directory]
      if repository then
        done(nil, repository)
      else
        done({ reason = 'not_a_repository', message = 'not a git repository' })
      end
    end)
  end
  return find, asked
end

--- The checkout of the repository whose common git directory is `common`,
--- at `top`.
---
---@param top string
---@param common string
---@return aineo.git.Repository
local function repository_at(top, common)
  return { top = top, git_directory = common, common_directory = common }
end

--- Looks `path` up with `method` and waits for the answer.
---
---@param checkouts aineo.projects.Checkouts
---@param path string
---@param method? 'lookup'|'lookup_folder'|'lookup_checkout' `'lookup'` when not given
---@return aineo.projects.Project|nil
local function looked_up(checkouts, path, method)
  local answered, project = false, nil
  checkouts[method or 'lookup'](path, function(found)
    answered, project = true, found
  end)
  assert(vim.wait(PATIENCE_MS, function()
    return answered
  end, 5))
  return project
end

T['a lookup'] = MiniTest.new_set()

T['a lookup']['answers the project of the checkout the folder of a file is in'] = function()
  local top = fixture.directory('projects_checkouts_found')
  vim.fn.mkdir(vim.fs.joinpath(top, 'src'), 'p')
  local find = fake_find({ [vim.fs.joinpath(top, 'src')] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  local project = looked_up(checkouts, vim.fs.joinpath(top, 'src', 'app.py'))

  eq(project, { key = top .. '/.git', top = top })
end

T['a lookup']['asks in the nearest folder that exists when the file is in one not made yet'] = function()
  local top = fixture.directory('projects_checkouts_new_folder')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  looked_up(checkouts, vim.fs.joinpath(top, 'new', 'deeper', 'file.lua'))

  eq(asked, { top })
end

T['a lookup']['answers nil for a folder that is in no repository'] = function()
  local folder = fixture.directory('projects_checkouts_none')
  local find = fake_find({})
  local checkouts = projects.new_checkouts(find)

  eq(looked_up(checkouts, vim.fs.joinpath(folder, 'note.txt')), nil)
end

T['a lookup']['answers nil when no folder above the file exists'] = function()
  local find = fake_find({})
  local checkouts = projects.new_checkouts(find)

  eq(looked_up(checkouts, '/aineo-no-such-folder-at-all/a/b.txt'), nil)
end

T['a lookup']['asks git once for a folder however many files of it are looked up'] = function()
  local top = fixture.directory('projects_checkouts_remembered')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  looked_up(checkouts, vim.fs.joinpath(top, 'a.lua'))
  looked_up(checkouts, vim.fs.joinpath(top, 'b.lua'))

  eq(asked, { top })
end

--- A clock a case moves by hand, in milliseconds.
---
---@return fun(): integer now
---@return fun(milliseconds: integer) advance
local function hand_clock()
  local now = 1000
  return function()
    return now
  end, function(milliseconds)
    now = now + milliseconds
  end
end

T['a lookup']['remembers a folder that is in no repository for a while'] = function()
  local folder = fixture.directory('projects_checkouts_remembered_none')
  local find, asked = fake_find({})
  local now, advance = hand_clock()
  local checkouts = projects.new_checkouts(find, now)

  looked_up(checkouts, vim.fs.joinpath(folder, 'a.lua'))
  advance(29000)
  looked_up(checkouts, vim.fs.joinpath(folder, 'b.lua'))

  eq(asked, { folder })
end

T['a lookup']['asks again for a folder that was in no repository once 30 seconds have passed'] = function()
  local folder = fixture.directory('projects_checkouts_forgotten_none')
  local repositories = {}
  local find, asked = fake_find(repositories)
  local now, advance = hand_clock()
  local checkouts = projects.new_checkouts(find, now)
  looked_up(checkouts, vim.fs.joinpath(folder, 'a.lua'))
  repositories[folder] = repository_at(folder, folder .. '/.git')

  advance(30000)
  local project = looked_up(checkouts, vim.fs.joinpath(folder, 'b.lua'))

  eq(asked, { folder, folder })
  eq(project, { key = folder .. '/.git', top = folder })
end

T['a lookup']['remembers a repository found, however long ago'] = function()
  local top = fixture.directory('projects_checkouts_remembered_found')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local now, advance = hand_clock()
  local checkouts = projects.new_checkouts(find, now)
  looked_up(checkouts, vim.fs.joinpath(top, 'a.lua'))

  advance(3600000)
  looked_up(checkouts, vim.fs.joinpath(top, 'b.lua'))

  eq(asked, { top })
end

T['a lookup']['asks git once for a folder when files of it are looked up before the first answer'] = function()
  local top = fixture.directory('projects_checkouts_pending')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)
  local answers = {}

  for _, name in ipairs({ 'a.lua', 'b.lua', 'c.lua' }) do
    checkouts.lookup(vim.fs.joinpath(top, name), function(project)
      table.insert(answers, project)
    end)
  end
  vim.wait(PATIENCE_MS, function()
    return #answers == 3
  end, 5)

  eq(asked, { top })
  eq(#answers, 3)
  eq(answers[3], { key = top .. '/.git', top = top })
end

T['a lookup']['asks for each folder of a repository on its own'] = function()
  local top = fixture.directory('projects_checkouts_two_folders')
  vim.fn.mkdir(vim.fs.joinpath(top, 'src'), 'p')
  local repository = repository_at(top, top .. '/.git')
  local find, asked = fake_find({ [top] = repository, [vim.fs.joinpath(top, 'src')] = repository })
  local checkouts = projects.new_checkouts(find)

  looked_up(checkouts, vim.fs.joinpath(top, 'a.lua'))
  looked_up(checkouts, vim.fs.joinpath(top, 'src', 'b.lua'))

  eq(#asked, 2)
end

T['a lookup']['answers the project of a linked worktree by the repository’s common directory'] = function()
  local main = fixture.directory('projects_checkouts_linked')
  local linked = vim.fs.joinpath(main, 'linked')
  vim.fn.mkdir(linked, 'p')
  local find = fake_find({
    [linked] = {
      top = linked,
      git_directory = main .. '/.git/worktrees/linked',
      common_directory = main .. '/.git',
    },
  })
  local checkouts = projects.new_checkouts(find)

  eq(
    looked_up(checkouts, vim.fs.joinpath(linked, 'x.lua')),
    { key = main .. '/.git', top = linked }
  )
end

T['a lookup of a folder'] = MiniTest.new_set()

T['a lookup of a folder']['answers the project of the checkout the folder is in'] = function()
  local top = fixture.directory('projects_checkouts_folder')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  local project = looked_up(checkouts, top, 'lookup_folder')

  eq(project, { key = top .. '/.git', top = top })
  eq(asked, { top })
end

T['a lookup of a folder']['shares what a lookup of a file in the folder remembered'] = function()
  local top = fixture.directory('projects_checkouts_folder_shared')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)
  looked_up(checkouts, vim.fs.joinpath(top, 'a.lua'))

  looked_up(checkouts, top, 'lookup_folder')

  eq(asked, { top })
end

T['a lookup of a folder']['asks in the nearest folder above it that exists when it is gone'] = function()
  local top = fixture.directory('projects_checkouts_folder_gone')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  looked_up(checkouts, vim.fs.joinpath(top, 'removed-worktree'), 'lookup_folder')

  eq(asked, { top })
end

T['a lookup of a checkout'] = MiniTest.new_set()

T['a lookup of a checkout']['answers the project when the folder is the top of a checkout'] = function()
  local top = fixture.directory('projects_checkouts_checkout')
  local find = fake_find({ [top] = repository_at(vim.uv.fs_realpath(top), top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  local project = looked_up(checkouts, top, 'lookup_checkout')

  eq(project, { key = top .. '/.git', top = vim.uv.fs_realpath(top) })
end

T['a lookup of a checkout']['answers nil for a folder that is not there, without walking up'] = function()
  local top = fixture.directory('projects_checkouts_checkout_gone')
  local find, asked = fake_find({ [top] = repository_at(top, top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  local project = looked_up(checkouts, vim.fs.joinpath(top, 'removed'), 'lookup_checkout')

  eq(project, nil)
  eq(asked, {})
end

T['a lookup of a checkout']['answers nil for a folder inside a checkout that is not its top'] = function()
  local top = fixture.directory('projects_checkouts_checkout_inside')
  vim.fn.mkdir(vim.fs.joinpath(top, 'src'), 'p')
  local inside = vim.fs.joinpath(top, 'src')
  local find = fake_find({ [inside] = repository_at(vim.uv.fs_realpath(top), top .. '/.git') })
  local checkouts = projects.new_checkouts(find)

  eq(looked_up(checkouts, inside, 'lookup_checkout'), nil)
end

T['a lookup of a checkout']['asks again for a folder remembered to be in no repository'] = function()
  local top = fixture.directory('projects_checkouts_checkout_again')
  local repositories = {}
  local find, asked = fake_find(repositories)
  local now = hand_clock()
  local checkouts = projects.new_checkouts(find, now)
  looked_up(checkouts, vim.fs.joinpath(top, 'a.lua'))
  repositories[top] = repository_at(vim.uv.fs_realpath(top), top .. '/.git')

  local project = looked_up(checkouts, top, 'lookup_checkout')

  eq(asked, { top, top })
  eq(project, { key = top .. '/.git', top = vim.uv.fs_realpath(top) })
end

T['a lookup of a checkout']['asks again for a folder remembered to hold a repository, and answers what it holds now'] = function()
  local top = fixture.directory('projects_checkouts_checkout_remade')
  local real = vim.uv.fs_realpath(top)
  local repositories = { [top] = repository_at(real, top .. '/.git') }
  local find, asked = fake_find(repositories)
  local checkouts = projects.new_checkouts(find)
  looked_up(checkouts, vim.fs.joinpath(top, 'a.lua'))
  repositories[top] = repository_at(real, top .. '/other/.git')

  local project = looked_up(checkouts, top, 'lookup_checkout')

  eq(asked, { top, top })
  eq(project, { key = top .. '/other/.git', top = real })
end

T['a lookup of a checkout']['tells the checkout a folder is inside when it is not the top'] = function()
  local top = fixture.directory('projects_checkouts_checkout_enclosing')
  vim.fn.mkdir(vim.fs.joinpath(top, 'src'), 'p')
  local inside = vim.fs.joinpath(top, 'src')
  local find = fake_find({ [inside] = repository_at(vim.uv.fs_realpath(top), top .. '/.git') })
  local checkouts = projects.new_checkouts(find)
  local answered, project, enclosing = false, nil, nil

  checkouts.lookup_checkout(inside, function(found, within)
    answered, project, enclosing = true, found, within
  end)
  vim.wait(PATIENCE_MS, function()
    return answered
  end, 5)

  eq({ project, enclosing }, { nil, { key = top .. '/.git', top = vim.uv.fs_realpath(top) } })
end

return T
