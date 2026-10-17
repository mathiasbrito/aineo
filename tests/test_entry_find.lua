local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What the file finder tells the user when no aineo tab exists.
local NO_TAB = 'aineo: there is no aineo tab to find a file in'

--- A repository with a file at its top and one in a directory of it, and the
--- directory.
---
---@param name string the case's own name for its fixture
---@return string top
---@return string directory
local function repository_with_a_directory(name)
  local top = git_repo.create(name, {
    ['top.txt'] = { 'at the top' },
    ['sub/note.txt'] = { 'in a directory' },
  })
  return top, vim.fs.joinpath(top, 'sub')
end

--- Starts `child` in `directory`, as the folder aineo starts in, with the
--- fake `claude` and the fake pickers `pickers` installed, the one called
--- opening `picked`, and opens the layout; waits until Claude Code is ready.
--- `settings` are more of `vim.g.aineo`.
---
---@param name string the case's own name for its files
---@param directory string
---@param pickers string[] the fake pickers installed
---@param picked? string the path the fake pickers open
---@param settings? table
local function open_layout_in(name, directory, pickers, picked, settings)
  entry.restart(child)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.cmd('cd ' .. vim.fn.fnameescape(directory))
  entry.use_fake(child, claude_session.fake(name, 'ready'), settings)
  find_pickers.install(child, pickers, picked)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Waits until a fake picker has been called, and returns what the calls were.
---
---@return { picker: string, options: table }[]
local function picker_calls()
  git_repo.wait_until('a picker to be called', function()
    return #find_pickers.calls(child) > 0
  end)
  return find_pickers.calls(child)
end

--- Each way to ask for the file finder from Normal mode, as a set's
--- `parametrize`: its name, and the function that does it.
local FIND_DOORS = {
  {
    'pressing \\f',
    function()
      entry.press(child, '\\f')
    end,
  },
  {
    'pressing <Plug>(aineo-find)',
    function()
      entry.press(child, '<Plug>(aineo-find)')
    end,
  },
  {
    'running :Aineo find',
    function()
      entry.command(child, 'Aineo find')
    end,
  },
}

T['Find'] = MiniTest.new_set()

T['Find']['asks the picker for the files under the top of the repository Claude Code started in, by'] =
  MiniTest.new_set({ parametrize = FIND_DOORS })

T['Find']['asks the picker for the files under the top of the repository Claude Code started in, by']['door'] = function(
  _,
  door
)
  local top, directory = repository_with_a_directory('entry-find-top')
  open_layout_in('entry-find-top', directory, { 'telescope' })

  door()

  eq(picker_calls(), { { picker = 'telescope', options = { cwd = top } } })
end

T['Find']['asks the picker for the files under the folder Claude Code started in when it is in no repository'] = function()
  local directory = git_repo.directory('entry-find-folder')
  open_layout_in('entry-find-folder', directory, { 'telescope' })

  entry.press(child, '\\f')

  eq(picker_calls(), { { picker = 'telescope', options = { cwd = directory } } })
end

T['Find']['asks the picker for the folder Claude Code started in, whatever the editor’s directory is by then'] = function()
  local top, directory = repository_with_a_directory('entry-find-cd')
  open_layout_in('entry-find-cd', directory, { 'telescope' })
  child.cmd('cd ' .. vim.fn.fnameescape(git_repo.directory('entry-find-cd-elsewhere')))

  entry.press(child, '\\f')

  eq(picker_calls(), { { picker = 'telescope', options = { cwd = top } } })
end

T['Find']['asks the picker the setting forces, whichever others are installed'] = function()
  local top, directory = repository_with_a_directory('entry-find-forced')
  open_layout_in(
    'entry-find-forced',
    directory,
    find_pickers.NAMES,
    nil,
    { find = { picker = 'fzf-lua' } }
  )

  entry.press(child, '\\f')

  eq(picker_calls(), { { picker = 'fzf-lua', options = { cwd = top } } })
end

T['Find']['asks the first of the installed pickers when the setting is not given'] = function()
  local top, directory = repository_with_a_directory('entry-find-auto')
  open_layout_in('entry-find-auto', directory, { 'fzf-lua', 'telescope' })

  entry.press(child, '\\f')

  eq(picker_calls(), { { picker = 'fzf-lua', options = { cwd = top } } })
end

--- How each mode a twin is pressed in is entered: `t`, Terminal mode in
--- Claude's window, by `\c`; `i`, Insert mode in Input, by `\i` and then
--- `startinsert`.
local ENTER = {
  t = function()
    entry.press(child, '\\c')
  end,
  i = function()
    entry.press(child, '\\i')
    child.cmd('startinsert')
  end,
}

T['Find']['is asked for by the twin of its key, in Terminal mode and in Insert mode'] =
  MiniTest.new_set({ parametrize = { { 't' }, { 'i' } } })

T['Find']['is asked for by the twin of its key, in Terminal mode and in Insert mode']['mode'] = function(
  mode
)
  local top, directory = repository_with_a_directory('entry-find-twin')
  open_layout_in('entry-find-twin', directory, { 'telescope' })
  ENTER[mode]()
  eq(child.api.nvim_get_mode().mode, mode)

  child.type_keys('<C-\\>f')

  eq(picker_calls(), { { picker = 'telescope', options = { cwd = top } } })
end

T['A file picked'] = MiniTest.new_set()

--- What the finder tells the user when asked from a floating window.
local FROM_A_FLOAT = 'aineo: a file is found from a window of the tab, not from a floating one'

--- Opens a floating window in `child`'s current tab page, with the cursor in
--- it.
local function enter_a_float()
  child.lua([[
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(buffer, true, {
      relative = 'editor',
      row = 1,
      col = 1,
      width = 20,
      height = 3,
    })
  ]])
end

T['Find']['tells the user once, and asks no picker, when asked from a floating window'] = function()
  local _, directory = repository_with_a_directory('entry-find-float')
  open_layout_in('entry-find-float', directory, { 'telescope' })
  enter_a_float()
  local float = child.api.nvim_get_current_win()

  entry.press(child, '\\f')

  eq({
    entry.messages(child),
    find_pickers.calls(child),
    child.api.nvim_get_current_win() == float,
  }, { { { message = FROM_A_FLOAT, level = vim.log.levels.WARN } }, {}, true })
end

T['Find']['leaves the picker it started open when asked again from inside it'] = function()
  local top, directory = repository_with_a_directory('entry-find-again')
  open_layout_in('entry-find-again', directory, { 'telescope' })
  child.lua([[
    local git = require('aineo.git')
    local find_repository = git.find_repository
    _G.roots_asked = 0
    git.find_repository = function(...)
      _G.roots_asked = _G.roots_asked + 1
      return find_repository(...)
    end
  ]])
  entry.press(child, '\\f')
  eq(picker_calls(), { { picker = 'telescope', options = { cwd = top } } })
  enter_a_float()
  local float = child.api.nvim_get_current_win()

  entry.press(child, '\\f')

  eq({
    child.lua_get('_G.roots_asked'),
    child.api.nvim_win_is_valid(float),
    child.api.nvim_get_current_win() == float,
  }, { 1, true, true })
end

--- The Lua that replaces `vim.ui.select()` in the child with a recorder:
--- each call's items are kept in `_G.selections`.
local RECORD_SELECTIONS = [[
  _G.selections = {}
  vim.ui.select = function(items)
    table.insert(_G.selections, items)
  end
]]

--- Waits until `child`'s `vim.ui.select()` has been called, and returns the
--- items of the call.
---
---@return string[]
local function selected_from()
  git_repo.wait_until('the files to be offered', function()
    return child.lua_get('#_G.selections') > 0
  end)
  return child.lua_get('_G.selections[1]')
end

T['Find']['lists the files of the repository found through the git home, whatever GIT_DIR names in the editor’s environment, when no picker is installed'] = function()
  local top = git_repo.create('entry-find-git-dir', {
    ['top.txt'] = { 'at the top' },
    ['.gitignore'] = { 'ignored.log' },
  })
  git_repo.write(top, 'ignored.log', { 'ignored' })
  local other = git_repo.create('entry-find-git-dir-other', { ['alien.txt'] = { 'elsewhere' } })
  open_layout_in('entry-find-git-dir', top, {})
  child.lua(RECORD_SELECTIONS)
  child.lua('vim.env.GIT_DIR = ...', { vim.fs.joinpath(other, '.git') })

  entry.press(child, '\\f')

  eq(selected_from(), { '.gitignore', 'top.txt' })
end

T['Find']['lists the files found walking a folder in no repository, and tells nothing of git, when no picker is installed'] = function()
  local directory = git_repo.directory('entry-find-walk')
  git_repo.write(directory, 'a.txt', { 'one' })
  open_layout_in('entry-find-walk', directory, {})
  child.lua(RECORD_SELECTIONS)

  entry.press(child, '\\f')

  eq({ selected_from(), entry.messages(child) }, { { 'a.txt' }, {} })
end

T['Find']['acts on the aineo tab used last, and moves to it, from a tab page that is none of aineo’s'] = function()
  local top, directory = repository_with_a_directory('entry-find-other-page')
  open_layout_in('entry-find-other-page', directory, { 'telescope' })
  local aineo_page = child.api.nvim_get_current_tabpage()
  child.cmd('tabnew')

  entry.press(child, '\\f')

  eq({ picker_calls(), child.api.nvim_get_current_tabpage() == aineo_page }, {
    { { picker = 'telescope', options = { cwd = top } } },
    true,
  })
end

T['Find']['tells the user once there is no aineo tab to find a file in, and asks no picker'] = function()
  entry.restart(child)
  find_pickers.install(child, { 'telescope' })

  entry.press(child, '\\f')

  eq(
    { entry.messages(child), find_pickers.calls(child) },
    { { { message = NO_TAB, level = vim.log.levels.WARN } }, {} }
  )
end

--- Where a search is started from, as a set's `parametrize`: its name, and
--- the function that moves the cursor there and asks for the search.
local STARTED_FROM = {
  {
    'Claude’s terminal, in Terminal mode',
    function()
      entry.press(child, '\\c')
      child.type_keys('<C-\\>f')
    end,
  },
  {
    'the Report',
    function()
      entry.press(child, '\\r')
      entry.press(child, '\\f')
    end,
  },
  {
    'Input',
    function()
      entry.press(child, '\\i')
      entry.press(child, '\\f')
    end,
  },
}

T['A file picked']['opens in the file column, modifiable, with the cursor in it in Normal mode, the search started from'] =
  MiniTest.new_set({ parametrize = STARTED_FROM })

T['A file picked']['opens in the file column, modifiable, with the cursor in it in Normal mode, the search started from']['window'] = function(
  _,
  start_from_there
)
  local top, directory = repository_with_a_directory('entry-find-lands')
  local note = vim.fs.joinpath(top, 'sub', 'note.txt')
  open_layout_in('entry-find-lands', directory, { 'telescope' }, note)

  start_from_there()
  picker_calls()

  git_repo.wait_until('the file column', function()
    return entry.current_window(child) == note
  end)
  eq({
    entry.windows(child),
    child.api.nvim_get_mode().mode,
    child.bo.modifiable,
    child.bo.readonly,
  }, { { 'terminal', note, 'aineo://report', 'aineo://input' }, 'n', true, false })
end

T['A file picked']['is written by :w once changed'] = function()
  local top, directory = repository_with_a_directory('entry-find-writes')
  local note = vim.fs.joinpath(top, 'sub', 'note.txt')
  open_layout_in('entry-find-writes', directory, { 'telescope' }, note)
  entry.press(child, '\\f')
  picker_calls()
  git_repo.wait_until('the file column', function()
    return entry.current_window(child) == note
  end)

  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed in the file column' })
  child.cmd('write')

  eq(vim.fn.readfile(note), { 'changed in the file column' })
end

T['Find']['tells the user once which setting is wrong, and asks no picker, when find.picker is not one it knows'] = function()
  local _, directory = repository_with_a_directory('entry-find-wrong')
  open_layout_in('entry-find-wrong', directory, { 'telescope' })
  child.lua("vim.g.aineo = { find = { picker = 'ctrlp' } }")

  entry.press(child, '\\f')

  eq({ entry.messages(child), find_pickers.calls(child) }, {
    {
      {
        message = 'aineo: find.picker: expected one of auto, snacks, fzf-lua, telescope, mini.pick, got ctrlp',
        level = vim.log.levels.ERROR,
      },
    },
    {},
  })
end

T['Find']['asks no picker when the cursor has left its window before the root is known'] = function()
  local _, directory = repository_with_a_directory('entry-find-left')
  open_layout_in('entry-find-left', directory, { 'telescope' })
  child.lua([[
    local git = require('aineo.git')
    local find_repository = git.find_repository
    git.find_repository = function(folder, done, options)
      _G.release = function()
        find_repository(folder, function(...)
          done(...)
          _G.root_known = true
        end, options)
      end
    end
  ]])
  entry.press(child, '\\i')
  entry.press(child, '\\f')
  entry.press(child, '\\r')

  child.lua('_G.release()')
  git_repo.wait_until('the root to be known', function()
    return child.lua_get('_G.root_known') == true
  end)

  eq(find_pickers.calls(child), {})
end

T[':Aineo find'] = MiniTest.new_set()

T[':Aineo find']['takes no word: with one it tells the user what :Aineo takes, and asks no picker'] = function()
  local _, directory = repository_with_a_directory('entry-find-word')
  open_layout_in('entry-find-word', directory, { 'telescope' })

  entry.command(child, 'Aineo find now')

  eq(
    { entry.messages(child), find_pickers.calls(child) },
    { { { message = entry.USAGE, level = vim.log.levels.ERROR } }, {} }
  )
end

return T
