local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

--- Takes on the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`) in this file's own Neovim, which every child it
--- starts inherits.
local function isolate_git()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = isolate_git,
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- The files of the repository most cases explore.
local FILES = {
  ['README.md'] = { 'readme' },
  ['src/main.lua'] = { 'main' },
  ['src/lib/util.lua'] = { 'util' },
  ['docs/guide.md'] = { 'guide' },
  ['.gitignore'] = { '*.log', 'build/' },
}

--- Makes the repository `explorer-<name>` holding `files` (`FILES` without
--- it), moves the child's working directory there and opens the layout with
--- aineo running the fake `claude` in its `ready` mode, once Claude Code is
--- ready; returns the repository's top.
---
---@param name string
---@param files? table<string, string[]>
---@return string top
local function open_in_repository(name, files)
  local top = git_repo.create('explorer-' .. name, files or FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local fake = claude_session.fake('explorer-' .. name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return top
end

--- The lines of the explorer's buffer in the child, the header first.
---
---@return string[]
local function explorer_lines()
  return child.lua_get([[(function()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buffer) == 'aineo://explorer' then
        return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
      end
    end
    return {}
  end)()]])
end

--- Waits, at most `PATIENCE_MS`, until the explorer's lines below its header
--- are `expected`, and returns them as they are then.
---
---@param expected string[]
---@return string[]
local function wait_for_tree(expected)
  local lines
  vim.wait(PATIENCE_MS, function()
    lines = vim.list_slice(explorer_lines(), 2)
    return vim.deep_equal(lines, expected)
  end, 20)
  return lines
end

--- The tree of `FILES`, nothing unfolded.
local FOLDED_TREE = {
  '▸   docs/',
  '▸   src/',
  '    .gitignore',
  '    README.md',
}

--- Each door to the explorer pane, as a set's `parametrize`: its name, and
--- the function that opens it.
local DOORS = {
  {
    'pressing \\e',
    function()
      entry.press(child, '\\e')
    end,
  },
  {
    'pressing <Plug>(aineo-pane-explorer)',
    function()
      entry.press(child, '<Plug>(aineo-pane-explorer)')
    end,
  },
  {
    'running :Aineo pane explorer',
    function()
      entry.command(child, 'Aineo pane explorer')
    end,
  },
  {
    'pressing <C-\\>e in Claude’s Terminal mode',
    function()
      entry.press(child, '\\c')
      child.type_keys('<C-\\>e')
    end,
  },
}

T['the explorer pane'] = MiniTest.new_set({ parametrize = DOORS })

T['the explorer pane']['shows the tree of the folder Claude works in, the cursor in it, by'] = function(
  _,
  door
)
  open_in_repository('doors')

  door()

  eq(wait_for_tree(FOLDED_TREE), FOLDED_TREE)
  eq(entry.windows(child), { 'terminal', 'aineo://explorer' })
  eq(entry.current_window(child), 'aineo://explorer')
  eq(entry.messages(child), {})
end

--- Each other pane, as a set's `parametrize`: its name, the keys that show
--- it, and what the layout's windows show under it (`entry.windows()`).
local OTHER_PANES = {
  { 'agent', '\\pa', { 'terminal', 'aineo://report', 'aineo://input' } },
  { 'changes', '\\g', { 'terminal', 'aineo://changes-files', 'aineo://changes-commits' } },
  { 'terminal', '\\pt', { 'terminal', 'terminal' } },
  { 'run', '\\x', { 'terminal', 'terminal' } },
}

--- Makes `vim.ui.input` in the child answer `answer`, as the run pane's
--- `\x` asks for its command.
---
---@param answer string
local function answer_input_with(answer)
  child.lua(
    [[
      local answer = ...
      vim.ui.input = function(_, on_confirm)
        on_confirm(answer)
      end
    ]],
    { answer }
  )
end

T['the explorer pane and another'] = MiniTest.new_set({ parametrize = OTHER_PANES })

T['the explorer pane and another']['swap places, each showing whole, for the pane'] = function(
  _,
  keys,
  other_windows
)
  open_in_repository('swap')
  child.o.shell = '/bin/sh'
  answer_input_with('sleep 30')
  entry.press(child, '\\e')
  wait_for_tree(FOLDED_TREE)

  entry.press(child, keys)
  local under_other = entry.windows(child)
  entry.press(child, '\\e')

  eq(under_other, other_windows)
  eq(entry.windows(child), { 'terminal', 'aineo://explorer' })
  eq(entry.messages(child), {})
end

--- The text height of each window right of Claude's column in the child's
--- current tab, top to bottom, and the height of Claude's window.
local HEIGHTS = [[(function()
  local column, claude = {}, nil
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local position = vim.api.nvim_win_get_position(window)
    if position[2] == 0 then
      claude = vim.api.nvim_win_get_height(window)
    elseif vim.api.nvim_win_get_config(window).relative == '' then
      table.insert(column, { row = position[1], height = vim.api.nvim_win_get_height(window) })
    end
  end
  table.sort(column, function(a, b)
    return a.row < b.row
  end)
  return { claude = claude, column = vim.tbl_map(function(window)
    return window.height
  end, column) }
end)()]]

--- Opens the layout in the repository `explorer-<name>` (`open_in_repository()`),
--- shows the explorer pane and waits for its folded tree; returns the
--- repository's top.
---
---@param name string
---@param files? table<string, string[]>
---@param folded? string[] the folded tree of `files`; `FOLDED_TREE` without it
---@return string top
local function explore(name, files, folded)
  local top = open_in_repository(name, files)
  entry.press(child, '\\e')
  wait_for_tree(folded or FOLDED_TREE)
  return top
end

--- Puts the cursor of the child's current window on the line that ends with
--- `text`.
---
---@param text string
local function put_cursor_on(text)
  child.lua(
    [[
      local text = ...
      for line, shown in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if vim.endswith(shown, text) then
          vim.api.nvim_win_set_cursor(0, { line, 0 })
          return
        end
      end
      error('no line ends with ' .. text)
    ]],
    { text }
  )
end

--- The text of the line the cursor is on in the child's current window.
---
---@return string
local function line_at_cursor()
  return child.lua_get('vim.api.nvim_get_current_line()')
end

T['a folder'] = MiniTest.new_set({ parametrize = { { 'l' }, { '<CR>' } } })

T['a folder']['unfolds and folds again, by'] = function(key)
  explore('unfold-' .. (key == 'l' and 'l' or 'enter'))
  put_cursor_on('src/')

  entry.press(child, key)
  local unfolded = vim.list_slice(explorer_lines(), 2)
  entry.press(child, key)

  eq(unfolded, {
    '▸   docs/',
    '▾   src/',
    '  ▸   lib/',
    '      main.lua',
    '    .gitignore',
    '    README.md',
  })
  eq(vim.list_slice(explorer_lines(), 2), FOLDED_TREE)
end

T['h'] = MiniTest.new_set()

T['h']['on a file folds its folder and moves the cursor there'] = function()
  explore('fold-parent')
  put_cursor_on('src/')
  entry.press(child, 'l')
  put_cursor_on('main.lua')

  entry.press(child, 'h')

  eq(vim.list_slice(explorer_lines(), 2), FOLDED_TREE)
  eq(line_at_cursor(), '▸   src/')
end

T['h']['on an unfolded folder folds it'] = function()
  explore('fold-folder')
  put_cursor_on('src/')
  entry.press(child, 'l')

  entry.press(child, 'h')

  eq(vim.list_slice(explorer_lines(), 2), FOLDED_TREE)
  eq(line_at_cursor(), '▸   src/')
end

--- Waits, at most `PATIENCE_MS`, until the child's current window shows a
--- buffer named `name`, and returns what it shows then.
---
---@param name string
---@return string
local function wait_for_current_window(name)
  vim.wait(PATIENCE_MS, function()
    return entry.current_window(child) == name
  end, 20)
  return entry.current_window(child)
end

T['a file'] = MiniTest.new_set()

T['a file']['opens in the file column with Enter, the cursor moving there'] = function()
  local top = explore('open')
  put_cursor_on('src/')
  entry.press(child, 'l')
  put_cursor_on('main.lua')
  local main = vim.fs.joinpath(top, 'src', 'main.lua')

  entry.press(child, '<CR>')

  eq(wait_for_current_window(main), main)
  eq(entry.windows(child), { 'terminal', main, 'aineo://explorer' })
end

T['a file']['that is not text goes to the operating system with Enter'] = function()
  local top =
    explore('open-binary', vim.tbl_extend('force', FILES, { ['image.bin'] = { 'a\nb' } }), {
      '▸   docs/',
      '▸   src/',
      '    .gitignore',
      '    image.bin',
      '    README.md',
    })
  child.lua([[
    _G.opened = {}
    vim.ui.open = function(path)
      table.insert(_G.opened, path)
      return nil, nil
    end
  ]])
  put_cursor_on('image.bin')

  entry.press(child, '<CR>')

  eq(child.lua_get('_G.opened'), { vim.fs.joinpath(top, 'image.bin') })
  eq(entry.current_window(child), 'aineo://explorer')
end

T['git’s marks'] = MiniTest.new_set()

T['git’s marks']['show modified, untracked and deleted files, and folders holding a change'] = function()
  local top = git_repo.create('explorer-marks', FILES)
  git_repo.write(top, 'README.md', { 'changed' })
  git_repo.write(top, 'new.txt', { 'new' })
  git_repo.write(top, 'src/lib/util.lua', { 'changed' })
  vim.fn.delete(vim.fs.joinpath(top, 'docs', 'guide.md'))
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-marks', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  local expected = {
    '▸ • docs/',
    '▸ • src/',
    '    .gitignore',
    '  ? new.txt',
    '  M README.md',
  }
  eq(wait_for_tree(expected), expected)
  put_cursor_on('docs/')
  entry.press(child, 'l')

  eq(vim.list_slice(explorer_lines(), 2, 3), { '▾ • docs/', '    D guide.md' })
end

T['a change on disk'] = MiniTest.new_set()

T['a change on disk']['reads the tree again, the folds and the cursor’s entry kept'] = function()
  local top = explore('refresh')
  put_cursor_on('src/')
  entry.press(child, 'l')
  put_cursor_on('main.lua')

  git_repo.write(top, 'src/added.lua', { 'added' })
  git_repo.write(top, 'src/main.lua', { 'changed' })

  local expected = {
    '▸   docs/',
    '▾ • src/',
    '  ▸   lib/',
    '    ? added.lua',
    '    M main.lua',
    '    .gitignore',
    '    README.md',
  }
  eq(wait_for_tree(expected), expected)
  eq(line_at_cursor(), '    M main.lua')
end

T['a change on disk']['while the pane is hidden is read once the pane shows again'] = function()
  local top = explore('hidden')
  entry.press(child, '\\pa')

  git_repo.write(top, 'later.txt', { 'later' })
  vim.wait(2000)
  local while_hidden = vim.list_slice(explorer_lines(), 2)
  entry.press(child, '\\e')

  local expected =
    { '▸   docs/', '▸   src/', '    .gitignore', '  ? later.txt', '    README.md' }
  eq(while_hidden, FOLDED_TREE)
  eq(wait_for_tree(expected), expected)
end

T['R'] = MiniTest.new_set()

--- Makes the folder `explorer-<name>`, outside any repository, holding
--- `files`, opens the layout there as `open_in_repository()` does, shows the
--- explorer pane and waits for `folded`, its folded tree; returns the folder.
---
---@param name string
---@param files table<string, string[]>
---@param folded string[]
---@return string folder
local function explore_folder(name, files, folded)
  local folder = fixture.directory('explorer-' .. name)
  for path, lines in pairs(files) do
    fixture.write(vim.fs.joinpath('explorer-' .. name, path), lines)
  end
  child.cmd('cd ' .. vim.fn.fnameescape(folder))
  entry.use_fake(child, claude_session.fake('explorer-' .. name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  wait_for_tree(folded)
  return folder
end

--- A folder outside git: the files of `FILES`, and a `.git` folder that is
--- no repository's.
local PLAIN_FILES = vim.tbl_extend('force', FILES, { ['.git/stray'] = { 'stray' } })

T['R']['reads the tree again'] = function()
  local folder = explore_folder('reread', PLAIN_FILES, FOLDED_TREE)
  vim.fn.writefile({ 'later' }, vim.fs.joinpath(folder, 'later.txt'))

  entry.press(child, 'R')

  local expected =
    { '▸   docs/', '▸   src/', '    .gitignore', '    later.txt', '    README.md' }
  eq(wait_for_tree(expected), expected)
end

T['a folder outside git'] = MiniTest.new_set()

T['a folder outside git']['lists a folder when it unfolds, .git hidden, with no mark'] = function()
  local folder = explore_folder('plain', PLAIN_FILES, FOLDED_TREE)
  vim.fn.writefile({ 'later' }, vim.fs.joinpath(folder, 'src', 'later.lua'))
  put_cursor_on('src/')

  entry.press(child, 'l')

  eq(vim.list_slice(explorer_lines(), 2), {
    '▸   docs/',
    '▾   src/',
    '  ▸   lib/',
    '      later.lua',
    '      main.lua',
    '    .gitignore',
    '    README.md',
  })
end

T['a folder outside git']['says once for the tab that nothing is ignored there, I pressed twice'] = function()
  explore_folder('plain-ignored', PLAIN_FILES, FOLDED_TREE)

  entry.press(child, 'I')
  entry.press(child, 'I')

  eq(entry.messages(child), {
    {
      message = 'aineo: the explorer shows a folder outside git, where nothing is ignored',
      level = vim.log.levels.INFO,
    },
  })
  eq(explorer_lines()[1]:find('ignored hidden', 1, true) ~= nil, true)
end

T['ignored entries'] = MiniTest.new_set()

T['ignored entries']['are hidden, and shown and hidden again by I'] = function()
  local top = git_repo.create('explorer-ignored', FILES)
  git_repo.write(top, 'debug.log', { 'log' })
  git_repo.write(top, 'build/out.o', { 'out' })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-ignored', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  wait_for_tree(FOLDED_TREE)
  local shown = {
    '▸   build/',
    '▸   docs/',
    '▸   src/',
    '    .gitignore',
    '    debug.log',
    '    README.md',
  }

  entry.press(child, 'I')
  local after_one = wait_for_tree(shown)
  local header = explorer_lines()[1]
  put_cursor_on('build/')
  entry.press(child, 'l')
  local unfolded = vim.list_slice(explorer_lines(), 2, 3)
  entry.press(child, 'I')

  eq(after_one, shown)
  eq(header:find('ignored shown', 1, true) ~= nil, true)
  eq(unfolded, { '▾   build/', '      out.o' })
  eq(wait_for_tree(FOLDED_TREE), FOLDED_TREE)
end

T['dotfiles'] = MiniTest.new_set()

T['dotfiles']['are shown, and hidden and shown again by H'] = function()
  explore('dotfiles')

  entry.press(child, 'H')
  local hidden = vim.list_slice(explorer_lines(), 2)
  local header = explorer_lines()[1]
  entry.press(child, 'H')

  eq(hidden, { '▸   docs/', '▸   src/', '    README.md' })
  eq(header:find('dotfiles hidden', 1, true) ~= nil, true)
  eq(vim.list_slice(explorer_lines(), 2), FOLDED_TREE)
end

T['the filter'] = MiniTest.new_set()

T['the filter']['shows the files whose path holds it, and an empty one shows every file again'] = function()
  explore('filter')
  child.lua([[
    _G.filter_answers = { 'UTIL', '' }
    vim.ui.input = function(_, on_confirm)
      on_confirm(table.remove(_G.filter_answers, 1))
    end
  ]])

  entry.press(child, 'f')
  local filtered = explorer_lines()
  entry.press(child, 'f')

  eq(filtered, {
    vim.fn.fnamemodify(child.lua_get('vim.fn.getcwd()'), ':~')
      .. '  ·  ignored hidden  ·  dotfiles shown  ·  filter “UTIL”',
    '▾   src/',
    '  ▾   lib/',
    '        util.lua',
  })
  eq(vim.list_slice(explorer_lines(), 2), FOLDED_TREE)
end

T['@'] = MiniTest.new_set()

--- What the fake has received since its first `before` bytes, once `length`
--- bytes or more arrived or a second passed.
---
---@param fake table
---@param before integer
---@param length integer
---@return string
local function received_after(fake, before, length)
  return claude_session.wait_for_received_after(fake, before, length, 1000)
end

T['@']['pastes the folder’s path into Claude’s prompt, with no Enter, the cursor staying'] = function()
  local top = git_repo.create('explorer-paste', FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local fake = claude_session.fake('explorer-paste', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  wait_for_tree(FOLDED_TREE)
  put_cursor_on('src/')
  local before = #claude_session.received(fake)
  local expected = '\27[200~@src/ \27[201~'

  entry.press(child, '@')

  eq(received_after(fake, before, #expected + 1), expected)
  eq(entry.current_window(child), 'aineo://explorer')
  eq(line_at_cursor(), '▸   src/')
end

T['@']['pastes a file’s path from the folder Claude works in'] = function()
  local top = git_repo.create('explorer-paste-file', FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local fake = claude_session.fake('explorer-paste-file', 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  wait_for_tree(FOLDED_TREE)
  put_cursor_on('src/')
  entry.press(child, 'l')
  put_cursor_on('main.lua')
  local before = #claude_session.received(fake)
  local expected = '\27[200~@src/main.lua \27[201~'

  entry.press(child, '@')

  eq(received_after(fake, before, #expected + 1), expected)
end

T['@']['pastes nothing, and says so once, while Claude is not ready'] = function()
  local top = git_repo.create('explorer-paste-trust', FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local fake = claude_session.fake('explorer-paste-trust', 'trust')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'starting')
  entry.press(child, '\\e')
  wait_for_tree(FOLDED_TREE)
  put_cursor_on('README.md')
  local before = #claude_session.received(fake)

  entry.press(child, '@')

  eq(received_after(fake, before, 1), '')
  eq(entry.messages(child), {
    {
      message = 'aineo: nothing sent — Claude is not ready: it is starting, or a dialog in its window awaits your answer',
      level = vim.log.levels.WARN,
    },
  })
end

--- Opens the layout in the repository `explorer-<name>` holding `FILES` after
--- `change(top)` changed it on disk, shows the explorer and waits for
--- `expected`; returns the repository's top.
---
---@param name string
---@param change fun(top: string)
---@param expected string[]
---@return string top
local function explore_changed(name, change, expected)
  local top = git_repo.create('explorer-' .. name, FILES)
  change(top)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-' .. name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  wait_for_tree(expected)
  return top
end

T['the current file'] = MiniTest.new_set()

--- The line of the explorer's buffer the followed file's highlight is on,
--- from 1, nil when none is.
local FOLLOWED_LINE = [[(function()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buffer) == 'aineo://explorer' then
      local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
        if mark[4].line_hl_group == 'AineoExplorerFollowed' then
          return mark[2] + 1
        end
      end
    end
  end
  return nil
end)()]]

T['the current file']['is unfolded to and highlighted, the cursors staying where they are'] = function()
  local top = explore('follow')
  put_cursor_on('README.md')
  entry.press(child, '<CR>')
  wait_for_current_window(vim.fs.joinpath(top, 'README.md'))

  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'src', 'lib', 'util.lua')))

  local expected = {
    '▸   docs/',
    '▾   src/',
    '  ▾   lib/',
    '        util.lua',
    '      main.lua',
    '    .gitignore',
    '    README.md',
  }
  eq(wait_for_tree(expected), expected)
  eq(child.lua_get(FOLLOWED_LINE), 5)
  eq(entry.current_window(child), vim.fs.joinpath(top, 'src', 'lib', 'util.lua'))
  eq(
    child.lua_get([[(function()
      local window = vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1]
      local line = vim.api.nvim_win_get_cursor(window)[1]
      return vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://explorer'), line - 1, line, false)[1]
    end)()]]),
    '    README.md'
  )
end

T['the current file']['in a folder git ignores whole, ignored entries shown, is unfolded to'] = function()
  local top = explore_changed('follow-ignored', function(repository)
    git_repo.write(repository, 'build/out.js', { 'out' })
  end, FOLDED_TREE)
  entry.press(child, 'I')
  wait_for_tree({ '▸   build/', '▸   docs/', '▸   src/', '    .gitignore', '    README.md' })
  put_cursor_on('README.md')
  entry.press(child, '<CR>')
  wait_for_current_window(vim.fs.joinpath(top, 'README.md'))
  -- The explorer reads its tree again as its window gets its buffer back;
  -- the follow below is to be seen without that read.
  vim.wait(1500)

  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'build', 'out.js')))

  eq(vim.list_slice(explorer_lines(), 2), {
    '▾   build/',
    '      out.js',
    '▸   docs/',
    '▸   src/',
    '    .gitignore',
    '    README.md',
  })
  eq(child.lua_get(FOLLOWED_LINE), 3)
end

T['the current file']['outside the folder shown changes nothing'] = function()
  explore('follow-outside')
  local outside = fixture.write('explorer-follow-outside-file.txt', { 'outside' })
  put_cursor_on('README.md')
  entry.press(child, '<CR>')

  child.cmd('edit ' .. vim.fn.fnameescape(outside))

  vim.wait(300)
  eq(vim.list_slice(explorer_lines(), 2), FOLDED_TREE)
  eq(child.lua_get(FOLLOWED_LINE), 5)
end

T['a name with a line feed'] = MiniTest.new_set()

T['a name with a line feed']['shows quoted, and following a file raises nothing'] = function()
  local top = git_repo.create('explorer-line-feed', FILES)
  local handle = assert(io.open(vim.fs.joinpath(top, 'bad\nname.txt'), 'w'))
  handle:write('x')
  handle:close()
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-line-feed', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  local expected = {
    '▸   docs/',
    '▸   src/',
    '    .gitignore',
    '  ? "bad\\nname.txt"',
    '    README.md',
  }
  eq(wait_for_tree(expected), expected)
  put_cursor_on('README.md')
  child.lua('vim.v.errmsg = ""')

  entry.press(child, '<CR>')

  eq(wait_for_current_window(vim.fs.joinpath(top, 'README.md')), vim.fs.joinpath(top, 'README.md'))
  eq(child.lua_get('vim.v.errmsg'), '')
  eq(entry.messages(child), {})
end

T['a submodule and a nested repository'] = MiniTest.new_set()

T['a submodule and a nested repository']['show as folders listed from disk, Enter opening no folder'] = function()
  local top = git_repo.create('explorer-nested', { ['a.txt'] = { 'a' } })
  local other = git_repo.create('explorer-nested-other', { ['s.txt'] = { 's' } })
  git_repo.git(top, {
    '-c',
    'protocol.file.allow=always',
    'submodule',
    'add',
    '--quiet',
    other,
    'vendor/lib',
  })
  git_repo.commit_all(top, 'Add the submodule')
  local nested = vim.fs.joinpath(top, 'nested')
  vim.fn.mkdir(nested, 'p')
  git_repo.git(nested, { 'init', '--quiet' })
  git_repo.write(nested, 'n.txt', { 'n' })
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-nested', 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
  wait_for_tree({ '▸ ? nested/', '▸   vendor/', '    .gitmodules', '    a.txt' })
  put_cursor_on('vendor/')
  entry.press(child, 'l')
  put_cursor_on('lib/')

  entry.press(child, '<CR>')
  put_cursor_on('nested/')
  entry.press(child, '<CR>')

  eq(vim.list_slice(explorer_lines(), 2), {
    '▾ ? nested/',
    '      n.txt',
    '▾   vendor/',
    '  ▾   lib/',
    '        s.txt',
    '    .gitmodules',
    '    a.txt',
  })
  eq(entry.current_window(child), 'aineo://explorer')
end

T['the folder shown'] = MiniTest.new_set()

T['the folder shown']['is the one Claude works in, wherever the editor moved since'] = function()
  local top = open_in_repository('cwd-elsewhere')
  child.cmd('cd ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'src')))

  entry.press(child, '\\e')

  eq(wait_for_tree(FOLDED_TREE), FOLDED_TREE)
end

T['the filter']['is kept as the tree is read again after a change on disk'] = function()
  local top = explore('filter-refresh')
  child.lua([[
    vim.ui.input = function(_, on_confirm)
      on_confirm('main')
    end
  ]])
  entry.press(child, 'f')

  git_repo.write(top, 'src/main.lua', { 'changed' })

  local expected = { '▾ • src/', '    M main.lua' }
  eq(wait_for_tree(expected), expected)
  eq(explorer_lines()[1]:find('filter “main”', 1, true) ~= nil, true)
end

T['a file']['deleted opens nothing with Enter, and says so'] = function()
  explore_changed('open-deleted', function(top)
    vim.fn.delete(vim.fs.joinpath(top, 'README.md'))
  end, { '▸   docs/', '▸   src/', '    .gitignore', '  D README.md' })
  child.lua([[
    _G.opened = {}
    vim.ui.open = function(path)
      table.insert(_G.opened, path)
      return nil, nil
    end
  ]])
  put_cursor_on('README.md')

  entry.press(child, '<CR>')

  eq(child.lua_get('_G.opened'), {})
  eq(entry.current_window(child), 'aineo://explorer')
  eq(entry.messages(child), {
    {
      message = 'aineo: README.md is deleted; \\g shows its diff',
      level = vim.log.levels.INFO,
    },
  })
end

T['a file']['turned into a link to a folder opens nothing with Enter'] = function()
  explore_changed('open-folder-link', function(top)
    vim.fn.delete(vim.fs.joinpath(top, 'README.md'))
    vim.uv.fs_symlink('src', vim.fs.joinpath(top, 'README.md'))
  end, { '▸   docs/', '▸   src/', '    .gitignore', '  T README.md' })
  child.lua([[
    _G.opened = {}
    vim.ui.open = function(path)
      table.insert(_G.opened, path)
      return nil, nil
    end
  ]])
  put_cursor_on('README.md')

  entry.press(child, '<CR>')

  eq(child.lua_get('_G.opened'), {})
  eq(entry.current_window(child), 'aineo://explorer')
  eq(entry.messages(child), {
    {
      message = 'aineo: README.md is a folder on disk, not a file to open',
      level = vim.log.levels.INFO,
    },
  })
end

T['the explorer pane, zoomed,'] = MiniTest.new_set()

T['the explorer pane, zoomed,']['keeps the column’s whole height, telling nothing'] = function()
  open_in_repository('zoom')
  entry.press(child, '\\e')
  local before = child.lua_get(HEIGHTS)

  entry.press(child, '\\z')

  eq(child.lua_get(HEIGHTS), before)
  eq(before.column, { before.claude })
  eq(entry.messages(child), {})
end

T['the explorer pane, zoomed,']['takes the whole tab page with \\Z, and gives it back'] = function()
  open_in_repository('zoom-full')
  entry.press(child, '\\e')
  local before = child.lua_get(HEIGHTS)
  local columns = child.o.columns

  entry.press(child, '\\Z')
  local width = child.lua_get('vim.api.nvim_win_get_width(0)')
  entry.press(child, '\\Z')

  eq(width >= columns - 2, true)
  eq(child.lua_get(HEIGHTS), before)
  eq(entry.current_window(child), 'aineo://explorer')
end

return T
