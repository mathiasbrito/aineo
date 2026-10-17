local MiniTest = require('mini.test')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['picker_in_use()'] = MiniTest.new_set()

--- Which of the fake pickers are installed, and the one `auto` takes.
local AUTO_TAKES = {
  { { 'snacks', 'fzf-lua', 'telescope', 'mini.pick' }, 'snacks' },
  { { 'fzf-lua', 'telescope', 'mini.pick' }, 'fzf-lua' },
  { { 'telescope', 'mini.pick' }, 'telescope' },
  { { 'mini.pick' }, 'mini.pick' },
  { {}, vim.NIL },
}

T['picker_in_use()']['takes, for auto, the first installed of snacks, fzf-lua, telescope and mini.pick'] =
  MiniTest.new_set({ parametrize = AUTO_TAKES })

T['picker_in_use()']['takes, for auto, the first installed of snacks, fzf-lua, telescope and mini.pick']['installed'] = function(
  installed,
  taken
)
  find_pickers.install(child, installed)

  eq(child.lua_get("require('aineo.find').picker_in_use('auto')"), taken)
end

T['picker_in_use()']['takes the picker that is forced when it is installed, whatever else is'] =
  MiniTest.new_set({
    parametrize = {
      { 'snacks' },
      { 'fzf-lua' },
      { 'telescope' },
      { 'mini.pick' },
    },
  })

T['picker_in_use()']['takes the picker that is forced when it is installed, whatever else is']['forced'] = function(
  forced
)
  find_pickers.install(child, find_pickers.NAMES)

  eq(child.lua_get("require('aineo.find').picker_in_use(...)", { forced }), forced)
end

T['picker_in_use()']['takes none when the picker that is forced is not installed, though another is'] =
  MiniTest.new_set({
    parametrize = {
      { 'snacks', { 'fzf-lua', 'telescope', 'mini.pick' } },
      { 'fzf-lua', { 'snacks', 'telescope', 'mini.pick' } },
      { 'telescope', { 'snacks', 'fzf-lua', 'mini.pick' } },
      { 'mini.pick', { 'snacks', 'fzf-lua', 'telescope' } },
    },
  })

T['picker_in_use()']['takes none when the picker that is forced is not installed, though another is']['forced'] = function(
  forced,
  installed
)
  find_pickers.install(child, installed)

  eq(child.lua_get("require('aineo.find').picker_in_use(...)", { forced }), vim.NIL)
end

T['start()'] = MiniTest.new_set()

--- Each picker, the options its call is given for the directory `/tmp/root`.
local OPTIONS_OF_THE_CALL = {
  { 'snacks', { cwd = '/tmp/root' } },
  { 'fzf-lua', { cwd = '/tmp/root' } },
  { 'telescope', { cwd = '/tmp/root' } },
  { 'mini.pick', { source = { cwd = '/tmp/root' } } },
}

T['start()']['asks the picker for the files under the directory, whichever picker is forced'] =
  MiniTest.new_set({ parametrize = OPTIONS_OF_THE_CALL })

T['start()']['asks the picker for the files under the directory, whichever picker is forced']['picker'] = function(
  picker,
  options
)
  find_pickers.install(child, find_pickers.NAMES)

  child.lua(
    "require('aineo.find').find_file({ directory = '/tmp/root', picker = ... })",
    { picker }
  )

  eq(find_pickers.calls(child), { { picker = picker, options = options } })
end

T['start()']['asks the first installed picker, and no other, when the picker is auto'] = function()
  find_pickers.install(child, { 'fzf-lua', 'telescope', 'mini.pick' })

  child.lua("require('aineo.find').find_file({ directory = '/tmp/root', picker = 'auto' })")

  eq(find_pickers.calls(child), { { picker = 'fzf-lua', options = { cwd = '/tmp/root' } } })
end

T['start() with no picker installed'] = MiniTest.new_set()

--- The Lua that replaces `vim.ui.select()` in the child with a recorder: each
--- call is kept in `_G.selections` as its items and prompt, and the choice
--- is made by calling `_G.choose(index)`, which hands the item at `index` of
--- the last call to its callback, as picking it would.
local RECORD_SELECTIONS = [[
  _G.selections, _G.callbacks = {}, {}
  vim.ui.select = function(items, options, on_choice)
    table.insert(_G.selections, { items = items, prompt = options.prompt })
    table.insert(_G.callbacks, on_choice)
  end
  function _G.choose(index)
    _G.callbacks[#_G.callbacks](_G.selections[#_G.selections].items[index], index)
  end
]]

--- Starts the finder in `child` for `directory` with `picker`, no third-party
--- picker installed, and waits until it has offered its files through
--- `vim.ui.select()`; returns the items it offered.
---
---@param directory string
---@param picker? string `auto` when not given
---@return string[]
local function offered_files(directory, picker)
  find_pickers.install(child, {})
  child.lua(RECORD_SELECTIONS)
  child.lua(
    [=[
      local directory, picker = ...
      require('aineo.find').find_file({ directory = directory, picker = picker })
    ]=],
    { directory, picker or 'auto' }
  )
  git_repo.wait_until('the files to be offered', function()
    return child.lua_get('#_G.selections') > 0
  end)
  return child.lua_get('_G.selections[1].items')
end

T['start() with no picker installed']['offers the files of the repository through vim.ui.select, the untracked ones and not the ignored'] = function()
  local top = git_repo.create('find-repository', {
    ['tracked.txt'] = { 'one' },
    ['src/nested file.lua'] = { 'two' },
    ['.gitignore'] = { 'ignored.log' },
  })
  git_repo.write(top, 'untracked.txt', { 'three' })
  git_repo.write(top, 'ignored.log', { 'four' })

  local files = offered_files(top)

  eq(files, { '.gitignore', 'src/nested file.lua', 'tracked.txt', 'untracked.txt' })
end

T['start() with no picker installed']['offers the files found walking a directory that is in no repository, leaving .git out'] = function()
  local directory = git_repo.directory('find-walk')
  git_repo.write(directory, 'a.txt', { 'one' })
  git_repo.write(directory, 'sub/deeper/b.txt', { 'two' })
  git_repo.write(directory, '.git/config', { 'not a repository' })

  local files = offered_files(directory)

  eq(files, { 'a.txt', 'sub/deeper/b.txt' })
end

--- The notifications `child` has been given, each as its message and level.
local NOTIFICATIONS = '_G.notifications'

--- Records the notifications `child` is given in `_G.notifications`.
local function record_notifications()
  child.lua([[
    _G.notifications = {}
    vim.notify = function(message, level)
      table.insert(_G.notifications, { message = message, level = level })
    end
  ]])
end

T['start() with no picker installed']['tells the user once that the picker forced is not installed, and offers the files all the same'] = function()
  local top = git_repo.create('find-forced', { ['a.txt'] = { 'one' } })
  record_notifications()

  local files = offered_files(top, 'telescope')

  eq({ child.lua_get(NOTIFICATIONS), files }, {
    {
      {
        message = 'aineo: find.picker is telescope, which is not installed: the files are listed with vim.ui.select',
        level = vim.log.levels.WARN,
      },
    },
    { 'a.txt' },
  })
end

--- Waits until `child` has been given a notification.
local function wait_for_a_notification()
  git_repo.wait_until('a notification', function()
    return child.lua_get('#_G.notifications') > 0
  end)
end

T['start() with no picker installed']['tells the user once, and offers nothing, when the directory holds no file'] = function()
  local directory = git_repo.directory('find-empty')
  find_pickers.install(child, {})
  child.lua(RECORD_SELECTIONS)
  record_notifications()

  child.lua("require('aineo.find').find_file({ directory = ..., picker = 'auto' })", { directory })
  wait_for_a_notification()

  eq({ child.lua_get(NOTIFICATIONS), child.lua_get('#_G.selections') }, {
    { { message = 'aineo: no file under ' .. directory, level = vim.log.levels.INFO } },
    0,
  })
end

--- The number of files the finder lists at most.
local MOST_FILES = 20000

--- Makes `count` empty files in `directory`, from `child`.
---
---@param directory string
---@param count integer
local function make_files(directory, count)
  child.lua(
    [=[
      local directory, count = ...
      for number = 1, count do
        io.open(('%s/file-%05d'):format(directory, number), 'w'):close()
      end
    ]=],
    { directory, count }
  )
end

T['start() with no picker installed']['offers the first files only, and tells the user once, when the directory holds more'] = function()
  local directory = git_repo.directory('find-many')
  make_files(directory, MOST_FILES + 1)
  record_notifications()

  local files = offered_files(directory)

  eq({ #files, child.lua_get(NOTIFICATIONS) }, {
    MOST_FILES,
    {
      {
        message = ('aineo: the list stops at the first %d files under %s'):format(
          MOST_FILES,
          directory
        ),
        level = vim.log.levels.INFO,
      },
    },
  })
end

T['start() with no picker installed']['tells nothing when the picker is auto'] = function()
  local top = git_repo.create('find-auto', { ['a.txt'] = { 'one' } })
  record_notifications()

  offered_files(top, 'auto')

  eq(child.lua_get(NOTIFICATIONS), {})
end

T['start() with no picker installed']['opens the file picked in the window the search began in, modifiable, where it has the cursor'] = function()
  local top = git_repo.create('find-pick', { ['a.txt'] = { 'one' }, ['b.txt'] = { 'two' } })
  child.cmd('vsplit')
  local began_in = child.api.nvim_get_current_win()
  offered_files(top)
  child.cmd('wincmd l')

  child.lua('_G.choose(2)')

  eq({
    child.api.nvim_get_current_win() == began_in,
    child.api.nvim_buf_get_name(0),
    child.bo.modifiable,
    child.bo.readonly,
  }, { true, vim.fs.joinpath(top, 'b.txt'), true, false })
end

return T
