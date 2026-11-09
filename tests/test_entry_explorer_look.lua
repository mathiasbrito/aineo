local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
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

--- Takes on the git isolation of the git home's suites in this file's own
--- Neovim, which every child it starts inherits.
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
}

--- The cells the explorer's header leaves for what follows the folder in it
--- (a branch, a summary of the changes, the toggles and a filter).
local HEADER_ROOM = 90

--- The cells the folder of the explorer takes in its header in the case
--- `name`, at most: the repository's folder under the checkout's fixtures,
--- whatever the length of the checkout's path.
---
---@param name string
---@return integer
local function title_width(name)
  local folder = vim.fs.joinpath(vim.uv.cwd(), '.tests', 'fixtures', 'git-look-' .. name, 'repo')
  return vim.api.nvim_strwidth(vim.fn.fnamemodify(folder, ':~'))
end

--- Makes the repository `look-<name>` holding `files` (`FILES` without it),
--- lets `change` edit it, moves the child's working directory there, opens
--- the layout with aineo running the fake `claude` in its `ready` mode, once
--- Claude Code is ready, and shows the explorer; returns the repository's
--- top.
---
---@param name string
---@param files? table<string, string[]>
---@param change? fun(top: string)
---@param settings? table more of `vim.g.aineo`
---@return string top
local function explore(name, files, change, settings)
  child.o.columns = 2 * (title_width(name) + HEADER_ROOM)
  local top = git_repo.create('look-' .. name, files or FILES)
  if change then
    change(top)
  end
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('look-' .. name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')
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

--- Waits, at most `PATIENCE_MS`, until `predicate` holds of the lines below
--- the explorer's header, and returns them as they are then.
---
---@param predicate fun(lines: string[]): boolean
---@return string[]
local function wait_for_lines(predicate)
  local lines
  vim.wait(PATIENCE_MS, function()
    lines = vim.list_slice(explorer_lines(), 2)
    return predicate(lines)
  end, 20)
  return lines
end

--- Waits until the explorer holds exactly `expected` below its header.
---
---@param expected string[]
---@return string[]
local function wait_for_tree(expected)
  return wait_for_lines(function(lines)
    return vim.deep_equal(lines, expected)
  end)
end

--- The virtual text of the explorer's buffer in the child, as
--- `{ line, column, position, text, groups }`: the line from 1, the column in
--- bytes from 0, the chunks' texts joined, their groups in order.
local VIRTUAL_TEXT = [[(function()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buffer) == 'aineo://explorer' then
      local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
      local found = {}
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
        if mark[4].virt_text then
          local texts, groups = {}, {}
          for _, chunk in ipairs(mark[4].virt_text) do
            table.insert(texts, chunk[1])
            table.insert(groups, chunk[2])
          end
          table.insert(found, {
            line = mark[2] + 1,
            column = mark[3],
            position = mark[4].virt_text_pos,
            text = table.concat(texts),
            groups = groups,
          })
        end
      end
      return found
    end
  end
  return {}
end)()]]

--- The virtual text in the child at `position`, as `{ line, text }`.
---
---@param position string
---@return table[]
local function virtual_at(position)
  local found = {}
  for _, item in ipairs(child.lua_get(VIRTUAL_TEXT)) do
    if item.position == position then
      table.insert(found, { item.line, item.text })
    end
  end
  return found
end

--- Puts the cursor of the explorer on the line that ends in `name`.
---
---@param name string
local function put_cursor_on(name)
  child.lua(
    [[
      local name = ...
      for line, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if vim.endswith(text, name) then
          vim.api.nvim_win_set_cursor(0, { line, 0 })
          return
        end
      end
    ]],
    { name }
  )
end

T['the guides'] = MiniTest.new_set()

T['the guides']['lie over the indent of the entries below the root, in the guide group, the text unchanged'] = function()
  explore('guides')
  wait_for_lines(function(lines)
    return #lines == 3
  end)
  put_cursor_on('src/')
  entry.press(child, 'l')
  put_cursor_on('lib/')
  entry.press(child, 'l')

  local lines = wait_for_lines(function(shown)
    return #shown == 6
  end)

  eq(lines, {
    '▸   docs/',
    '▾   src/',
    '  ▾   lib/',
    '        util.lua',
    '      main.lua',
    '    README.md',
  })
  eq(virtual_at('overlay'), { { 4, '├ ' }, { 5, '│ └ ' }, { 6, '└ ' } })
  eq(child.lua_get(VIRTUAL_TEXT)[1].groups, { 'AineoExplorerGuide' })
end

T['the guides']['are linked to NonText by default'] = function()
  explore('guide-group')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })

  local link = child.lua_get("vim.api.nvim_get_hl(0, { name = 'AineoExplorerGuide' }).link")

  eq(link, 'NonText')
end

--- The files of the repository the chain cases explore: a chain two
--- folders deep, beside a folder holding two entries.
local CHAIN_FILES = {
  ['lua/aineo/explorer/home.lua'] = { 'home' },
  ['lua/aineo/explorer/tree.lua'] = { 'tree' },
  ['README.md'] = { 'readme' },
  ['x/a/b/f.lua'] = { 'f' },
  ['x/y.lua'] = { 'y' },
}

T['a chain of single-child folders'] = MiniTest.new_set()

T['a chain of single-child folders']['shows on one line, and l or Enter unfolds and folds its deepest folder'] =
  MiniTest.new_set({ parametrize = { { 'l' }, { '<CR>' } } })

T['a chain of single-child folders']['shows on one line, and l or Enter unfolds and folds its deepest folder']['by'] = function(
  key
)
  explore('chain-' .. (key == 'l' and 'l' or 'enter'), CHAIN_FILES)
  local folded = {
    '▸   lua/aineo/explorer/',
    '▸   x/',
    '    README.md',
  }
  eq(wait_for_tree(folded), folded)

  put_cursor_on('lua/aineo/explorer/')
  entry.press(child, key)
  local unfolded = vim.list_slice(explorer_lines(), 2, 4)
  entry.press(child, key)

  eq(unfolded, { '▾   lua/aineo/explorer/', '      home.lua', '      tree.lua' })
  eq(vim.list_slice(explorer_lines(), 2), folded)
end

T['a chain of single-child folders']['is folded by h from a file in it, the cursor on its line'] = function()
  explore('chain-h', CHAIN_FILES)
  wait_for_lines(function(lines)
    return #lines == 3
  end)
  put_cursor_on('lua/aineo/explorer/')
  entry.press(child, 'l')
  put_cursor_on('tree.lua')

  entry.press(child, 'h')

  eq(vim.list_slice(explorer_lines(), 2, 2), { '▸   lua/aineo/explorer/' })
  eq(child.lua_get('vim.api.nvim_get_current_line()'), '▸   lua/aineo/explorer/')
end

T['a chain of single-child folders']['folded is left by h for the folder that holds it'] = function()
  explore('chain-h-up', CHAIN_FILES)
  wait_for_lines(function(lines)
    return #lines == 3
  end)
  put_cursor_on('x/')
  entry.press(child, 'l')
  local unfolded = wait_for_lines(function(lines)
    return #lines == 5
  end)
  put_cursor_on('a/b/')

  entry.press(child, 'h')

  eq(
    unfolded,
    { '▸   lua/aineo/explorer/', '▾   x/', '  ▸   a/b/', '      y.lua', '    README.md' }
  )
  eq(vim.list_slice(explorer_lines(), 2), {
    '▸   lua/aineo/explorer/',
    '▸   x/',
    '    README.md',
  })
  eq(child.lua_get('vim.api.nvim_get_current_line()'), '▸   x/')
end

T['a chain of single-child folders']['has @ paste the deepest folder’s path'] = function()
  explore('chain-paste', CHAIN_FILES)
  wait_for_lines(function(lines)
    return #lines == 3
  end)
  put_cursor_on('lua/aineo/explorer/')
  child.lua([[
    _G.pasted = {}
    require('aineo.send').paste = function(text)
      table.insert(_G.pasted, text)
    end
  ]])

  entry.press(child, '@')

  eq(child.lua_get('_G.pasted'), { '@lua/aineo/explorer/ ' })
end

T['a chain of single-child folders']['is unfolded to by the file in the file column'] = function()
  local top = explore('chain-follow', CHAIN_FILES)
  wait_for_lines(function(lines)
    return #lines == 3
  end)

  child.cmd(
    'edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'lua', 'aineo', 'explorer', 'tree.lua'))
  )

  local followed = wait_for_lines(function(lines)
    return #lines == 5
  end)
  eq(followed, {
    '▾   lua/aineo/explorer/',
    '      home.lua',
    '      tree.lua',
    '▸   x/',
    '    README.md',
  })
end

T['a chain of single-child folders']['read from the disk as its first folder unfolds is unfolded to its deepest folder'] = function()
  explore('chain-disk', { ['a.txt'] = { 'a' }, ['.gitignore'] = { 'build/' } }, function(top)
    vim.fn.mkdir(vim.fs.joinpath(top, 'build', 'out'), 'p')
    git_repo.write(top, 'build/out/x.o', { 'x' })
  end)
  wait_for_lines(function(lines)
    return #lines == 2
  end)
  entry.press(child, 'I')
  wait_for_tree({ '▸   build/', '    .gitignore', '    a.txt' })
  put_cursor_on('build/')

  entry.press(child, '<CR>')

  eq(vim.list_slice(explorer_lines(), 2), {
    '▾   build/out/',
    '      x.o',
    '    .gitignore',
    '    a.txt',
  })
end

--- Changes three files of `FILES`' repository and adds an untracked one.
---
---@param top string
local function change_some_files(top)
  git_repo.write(top, 'README.md', { 'readme', 'second', 'third' })
  git_repo.write(top, 'src/lib/util.lua', { 'changed' })
  git_repo.write(top, 'docs/guide.md', { 'guide', 'more' })
  git_repo.write(top, 'new.txt', { 'new' })
end

T['the counts'] = MiniTest.new_set()

T['the counts']['follow the mark of a folder holding changes, and show the lines of a changed file at the right'] = function()
  explore('counts', FILES, change_some_files)
  local folded = wait_for_lines(function(lines)
    return #lines == 5
  end)
  put_cursor_on('docs/')
  entry.press(child, 'l')

  eq(folded, { '▸ • docs/', '▸ • src/', '  ? new.txt', '  M README.md' })
  eq(
    vim.tbl_filter(function(item)
      return item[2]:match('^%d+$') ~= nil
    end, virtual_at('inline')),
    { { 2, '1' }, { 4, '1' } }
  )
  eq(virtual_at('right_align'), { { 3, '+1 −0' }, { 6, '+2 −0' } })
end

T['the counts']['read the lines of the changed files in one call of the git home for each read'] = function()
  explore('counts-calls', FILES, change_some_files)
  wait_for_lines(function(lines)
    return #lines == 5
  end)
  child.lua([[
    _G.line_count_reads = 0
    local git = require('aineo.git')
    local read = git.line_counts
    git.line_counts = function(...)
      _G.line_count_reads = _G.line_count_reads + 1
      return read(...)
    end
  ]])

  entry.press(child, 'R')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.line_count_reads') > 0
  end, 20)
  vim.wait(300)

  eq(child.lua_get('_G.line_count_reads'), 1)
end

T['the counts']['are shown in the added and removed groups, linked to the changes pane’s by default'] = function()
  explore('counts-groups', FILES, change_some_files)
  wait_for_lines(function(lines)
    return #lines == 5
  end)

  local groups = child.lua_get([[{
    added = vim.api.nvim_get_hl(0, { name = 'AineoExplorerAdded' }).link,
    removed = vim.api.nvim_get_hl(0, { name = 'AineoExplorerRemoved' }).link,
    unchanged = vim.api.nvim_get_hl(0, { name = 'AineoExplorerUnchanged' }).link,
  }]])

  eq(
    groups,
    { added = 'AineoChangesAdded', removed = 'AineoChangesDeleted', unchanged = 'Comment' }
  )
  local right_aligned = vim.tbl_filter(function(item)
    return item.position == 'right_align'
  end, child.lua_get(VIRTUAL_TEXT))
  eq(right_aligned[#right_aligned].groups, {
    'AineoExplorerAdded',
    'AineoExplorerRemoved',
  })
end

T['the icons'] = MiniTest.new_set()

--- Makes `mini.icons` in the child a fake, set up, that gives every file
--- `M` in `FakeIconGroup` and counts its calls in `_G.icon_calls`.
local FAKE_MINI_ICONS = [[
  _G.icon_calls = {}
  local fake = {
    get = function(category, name)
      table.insert(_G.icon_calls, category .. ':' .. name)
      return 'M', 'FakeIconGroup'
    end,
  }
  package.loaded['mini.icons'] = fake
  _G.MiniIcons = fake
]]

T['the icons']['come from mini.icons when it is set up, before each file’s name, in its group'] = function()
  child.lua(FAKE_MINI_ICONS)
  explore('icons-mini')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })

  local inline = child.lua_get(VIRTUAL_TEXT)

  eq(
    vim.tbl_map(function(item)
      return { item.line, item.column, item.text, item.groups }
    end, inline),
    {
      { 2, #'▸   ', '  ', {} },
      { 3, #'▸   ', '  ', {} },
      { 4, #'    ', 'M ', { 'FakeIconGroup' } },
    }
  )
  eq(child.lua_get('_G.icon_calls'), { 'file:README.md' })
end

T['the icons']['are asked for once for each path of a read, not once for each drawing'] = function()
  child.lua(FAKE_MINI_ICONS)
  explore('icons-once')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  put_cursor_on('docs/')
  entry.press(child, 'l')
  entry.press(child, 'l')
  entry.press(child, 'l')
  local before_reading = child.lua_get('#_G.icon_calls')

  entry.press(child, 'R')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('#_G.icon_calls') > before_reading
  end, 20)
  vim.wait(300)

  eq(before_reading, 2)
  eq(
    child.lua_get('_G.icon_calls'),
    { 'file:README.md', 'file:guide.md', 'file:guide.md', 'file:README.md' }
  )
end

T['the icons']['come from nvim-web-devicons when mini.icons is not set up'] = function()
  child.lua([[
    package.preload['nvim-web-devicons'] = function()
      return {
        get_icon = function(name, extension)
          return 'D' .. extension, 'FakeDevIcon'
        end,
      }
    end
  ]])
  explore('icons-devicons')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })

  local inline = child.lua_get(VIRTUAL_TEXT)

  eq(inline[#inline].text, 'Dmd ')
  eq(inline[#inline].groups, { 'FakeDevIcon' })
end

T['the icons']['are none when no icon plugin is set up, today’s look'] = function()
  explore('icons-none')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })

  eq(virtual_at('inline'), {})
end

T['the claude marks'] = MiniTest.new_set()

--- The lines of the explorer in the child that flash, from 1.
local FLASHING_LINES = [[(function()
  local buffer = vim.fn.bufnr('aineo://explorer')
  local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
  local lines = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
    if mark[4].line_hl_group == 'AineoExplorerClaudeFlash' then
      table.insert(lines, mark[2] + 1)
    end
  end
  return lines
end)()]]

--- The text before the names of the explorer's lines in the child, as
--- `{ line, text }`, for the places that hold a mark of Claude's or are
--- blank.
---
---@return table[]
local function claude_places()
  local found = {}
  for _, item in ipairs(child.lua_get(VIRTUAL_TEXT)) do
    if item.position == 'inline' and (item.text == '✦ ' or item.text == '  ') then
      table.insert(found, { item.line, item.text })
    end
  end
  return found
end

--- Waits, at most `PATIENCE_MS`, until `claude_places()` is `expected`, and
--- returns it as it is then.
---
---@param expected table[]
---@return table[]
local function wait_for_claude_places(expected)
  local found
  vim.wait(PATIENCE_MS, function()
    found = claude_places()
    return vim.deep_equal(found, expected)
  end, 20)
  return found
end

T['the claude marks']['sit before the files in the work of the session, a blank place before the others'] = function()
  local top = explore('claude')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  eq(claude_places(), {})

  git_repo.write(top, 'README.md', { 'changed by Claude' })
  entry.press(child, 'R')

  local places = wait_for_claude_places({ { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } })
  eq(places, { { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } })
  local inline = child.lua_get(VIRTUAL_TEXT)
  eq(inline[#inline].groups, { 'AineoExplorerClaude' })
  eq(child.lua_get("vim.api.nvim_get_hl(0, { name = 'AineoExplorerClaude' }).link"), 'Special')
  eq(
    child.lua_get("vim.api.nvim_get_hl(0, { name = 'AineoExplorerClaudeFlash' }).link"),
    'IncSearch'
  )
end

T['the claude marks']['follow the work the changes pane lists: a file committed since the session began too'] = function()
  local top = explore('claude-committed')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })

  git_repo.write(top, 'README.md', { 'committed by Claude' })
  git_repo.commit_all(top, 'Claude commits')
  entry.press(child, 'R')

  local places = wait_for_claude_places({ { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } })
  eq(places, { { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } })
end

T['the claude marks']['flash the line of a file that joins the work for a moment, the cursor staying where it is'] = function()
  local top = explore('claude-flash')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  put_cursor_on('docs/')
  local cursor_before = child.lua_get('vim.api.nvim_win_get_cursor(0)')

  git_repo.write(top, 'README.md', { 'changed by Claude' })
  entry.press(child, 'R')
  local appeared = vim.wait(PATIENCE_MS, function()
    return #child.lua_get(FLASHING_LINES) > 0
  end, 10)
  local started = vim.uv.now()
  local flashing = child.lua_get(FLASHING_LINES)
  local cursor_during = child.lua_get('vim.api.nvim_win_get_cursor(0)')
  local ended = vim.wait(PATIENCE_MS, function()
    return #child.lua_get(FLASHING_LINES) == 0
  end, 10)
  local lasted = vim.uv.now() - started

  eq(appeared, true)
  eq(flashing, { 4 })
  eq(ended, true)
  eq(lasted >= 1200 and lasted <= 2500, true)
  eq(cursor_during, cursor_before)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), cursor_before)
  eq(
    wait_for_claude_places({ { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } }),
    { { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } }
  )
end

T['the claude marks']['flash nothing for the work the session already had when the tree is first read'] = function()
  explore('claude-no-flash', FILES, function(top)
    git_repo.write(top, 'README.md', { 'changed before the explorer showed' })
  end)
  wait_for_tree({ '▸   docs/', '▸   src/', '  M README.md' })
  wait_for_claude_places({ { 2, '  ' }, { 3, '  ' }, { 4, '✦ ' } })
  vim.wait(300)

  eq(child.lua_get(FLASHING_LINES), {})
end

T['the unsaved mark'] = MiniTest.new_set()

--- Waits, at most `PATIENCE_MS`, until the virtual text of the explorer at
--- `position` is `expected`, as `{ line, text }`, and returns it as it is
--- then.
---
---@param position string
---@param expected table[]
---@return table[]
local function wait_for_virtual(position, expected)
  local found
  vim.wait(PATIENCE_MS, function()
    found = virtual_at(position)
    return vim.deep_equal(found, expected)
  end, 20)
  return found
end

--- Waits, at most `PATIENCE_MS`, until the unsaved marks of the explorer in
--- the child are `expected`, as `{ line, text }`, and returns them as they
--- are then.
---
---@param expected table[]
---@return table[]
local function wait_for_unsaved(expected)
  local found
  vim.wait(PATIENCE_MS, function()
    found = vim.tbl_filter(function(item)
      return item[2] == ' ●'
    end, virtual_at('inline'))
    return vim.deep_equal(found, expected)
  end, 20)
  return found
end

--- Counts, in the child, the times the explorer is drawn (`_G.explorer_draws`).
local COUNT_DRAWINGS = [[
  _G.explorer_draws = 0
  local decorate = require('aineo.explorer.decorate')
  local draw = decorate.draw
  decorate.draw = function(...)
    _G.explorer_draws = _G.explorer_draws + 1
    return draw(...)
  end
]]

--- Waits until the explorer in the child was not drawn for 300 ms, at most
--- `PATIENCE_MS`: what a change made before, such as opening a file, set
--- going (a read of the tree) has then drawn what it had to.
local function wait_until_drawn_still()
  local deadline = vim.uv.now() + PATIENCE_MS
  local drawn = child.lua_get('_G.explorer_draws')
  while vim.uv.now() < deadline do
    vim.wait(300)
    local now = child.lua_get('_G.explorer_draws')
    if now == drawn then
      return
    end
    drawn = now
  end
end

T['an explorer at rest'] = MiniTest.new_set()

T['an explorer at rest']['is not drawn again while its window has the cursor'] = function()
  explore('rest')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.lua(COUNT_DRAWINGS)
  wait_until_drawn_still()
  local before = child.lua_get('_G.explorer_draws')

  vim.wait(1000)

  eq(child.lua_get('_G.explorer_draws'), before)
end

T['an explorer at rest']['is drawn once for an edit of a file in another window'] = function()
  local top = explore('rest-edit')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  child.lua(COUNT_DRAWINGS)
  wait_until_drawn_still()
  local before = child.lua_get('_G.explorer_draws')

  child.lua('vim.api.nvim_buf_set_lines(0, 0, 0, false, { "edited" })')
  wait_for_unsaved({ { 4, ' ●' } })
  vim.wait(500)

  eq(child.lua_get('_G.explorer_draws') - before, 1)
end

T['the cursor of the explorer'] = MiniTest.new_set()

T['the cursor of the explorer']['keeps its column when a file in another window is edited'] = function()
  local top = explore('cursor-column')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  child.lua(COUNT_DRAWINGS)
  wait_until_drawn_still()
  local window = child.lua_get("vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1]")
  child.lua('vim.api.nvim_win_set_cursor(..., { 4, 6 })', { window })

  child.lua('vim.api.nvim_buf_set_lines(0, 0, 0, false, { "edited" })')
  wait_for_unsaved({ { 4, ' ●' } })

  eq(child.lua_get('vim.api.nvim_win_get_cursor(...)', { window }), { 4, 6 })
end

T['the unsaved mark']['follows the name of a file edited in this editor, until it is written'] = function()
  local top = explore('unsaved')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.lua(COUNT_DRAWINGS)
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  wait_until_drawn_still()

  child.lua('vim.api.nvim_buf_set_lines(0, 0, 0, false, { "edited" })')
  local edited = wait_for_unsaved({ { 4, ' ●' } })
  child.cmd('write')
  local written = wait_for_unsaved({})
  wait_until_drawn_still()
  child.lua('vim.api.nvim_buf_set_lines(0, 0, 0, false, { "edited again" })')
  local edited_again = wait_for_unsaved({ { 4, ' ●' } })
  child.cmd('write')
  local written_again = wait_for_unsaved({})

  eq(edited, { { 4, ' ●' } })
  eq(written, {})
  eq(edited_again, { { 4, ' ●' } })
  eq(written_again, {})
end

T['the unsaved mark']['is in the unsaved group, linked to WarningMsg by default'] = function()
  local top = explore('unsaved-group')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  child.lua('vim.api.nvim_buf_set_lines(0, 0, 0, false, { "edited" })')
  wait_for_unsaved({ { 4, ' ●' } })

  local inline = child.lua_get(VIRTUAL_TEXT)

  eq(inline[#inline].groups, { 'AineoExplorerModified' })
  eq(child.lua_get("vim.api.nvim_get_hl(0, { name = 'AineoExplorerModified' }).link"), 'WarningMsg')
end

T['the unsaved mark']['leaves out a file outside the folder shown, and a buffer that is no file'] = function()
  local top = explore('unsaved-outside')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(vim.fs.dirname(top), 'elsewhere.txt')))
  child.lua('vim.api.nvim_buf_set_lines(0, 0, 0, false, { "edited" })')
  child.cmd('enew')
  child.lua(
    [[
      local name = ...
      vim.bo.buftype = 'nofile'
      vim.api.nvim_buf_set_name(0, name)
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { 'scratch' })
      vim.bo.modified = true
    ]],
    { vim.fs.joinpath(top, 'README.md') }
  )
  vim.wait(300)

  eq(virtual_at('inline'), {})
end

T['the diagnostics'] = MiniTest.new_set()

T['the diagnostics']['of a loaded file show at its right, E before W, in the diagnostic groups'] = function()
  local top = explore('diagnostics')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))

  child.lua([[
    local severity = vim.diagnostic.severity
    local namespace = vim.api.nvim_create_namespace('look-test')
    vim.diagnostic.set(namespace, 0, {
      { lnum = 0, col = 0, message = 'a', severity = severity.ERROR },
      { lnum = 0, col = 0, message = 'b', severity = severity.ERROR },
      { lnum = 0, col = 0, message = 'c', severity = severity.WARN },
      { lnum = 0, col = 0, message = 'd', severity = severity.HINT },
    })
  ]])
  local shown = wait_for_virtual('right_align', { { 4, 'E2 W1' } })

  local right = child.lua_get(VIRTUAL_TEXT)
  eq(shown, { { 4, 'E2 W1' } })
  eq(right[#right].groups, { 'DiagnosticError', 'DiagnosticWarn' })
end

T['the diagnostics']['of a file the editor no longer has loaded are left out'] = function()
  local top = explore('diagnostics-unloaded')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  child.lua([[
    vim.diagnostic.set(vim.api.nvim_create_namespace('look-test'), 0, {
      { lnum = 0, col = 0, message = 'a', severity = vim.diagnostic.severity.ERROR },
    })
  ]])
  wait_for_virtual('right_align', { { 4, 'E1' } })
  local readme = child.lua_get('vim.api.nvim_get_current_buf()')
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'docs', 'guide.md')))
  child.cmd('bunload ' .. readme)

  child.lua([[
    vim.diagnostic.set(vim.api.nvim_create_namespace('look-test-other'), 0, {
      { lnum = 0, col = 0, message = 'b', severity = vim.diagnostic.severity.WARN },
    })
  ]])
  local shown = wait_for_virtual('right_align', { { 3, 'W1' } })

  eq(shown, { { 3, 'W1' } })
end

T['the diagnostics']['go when the file has none left'] = function()
  local top = explore('diagnostics-gone')
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  child.lua([[
    _G.look_namespace = vim.api.nvim_create_namespace('look-test')
    vim.diagnostic.set(_G.look_namespace, 0, {
      { lnum = 0, col = 0, message = 'a', severity = vim.diagnostic.severity.WARN },
    })
  ]])
  local shown = wait_for_virtual('right_align', { { 4, 'W1' } })

  child.lua('vim.diagnostic.reset(_G.look_namespace, 0)')
  local gone = wait_for_virtual('right_align', {})

  eq(shown, { { 4, 'W1' } })
  eq(gone, {})
end

T['the header'] = MiniTest.new_set()

--- Waits, at most `PATIENCE_MS`, until the explorer's header satisfies
--- `predicate`, and returns it as it is then.
---
---@param predicate fun(header: string): boolean
---@return string
local function wait_for_header(predicate)
  local header
  vim.wait(PATIENCE_MS, function()
    header = explorer_lines()[1] or ''
    return predicate(header)
  end, 20)
  return header
end

--- The cells the explorer's window takes for a line in the child.
local WINDOW_WIDTH = [[(function()
  local window = vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1]
  return vim.api.nvim_win_get_width(window) - vim.fn.getwininfo(window)[1].textoff
end)()]]

T['the header']['names the folder, its branch and the changes, the toggles at the right edge'] = function()
  explore('header', FILES, change_some_files)

  local header = wait_for_header(function(shown)
    return shown:find('3 changed', 1, true) ~= nil
  end)

  eq(header:find(' · main · 3 changed · 1 new', 1, true) ~= nil, true)
  eq(vim.endswith(header, 'ignored hidden  ·  dotfiles shown'), true)
  eq(vim.api.nvim_strwidth(header), child.lua_get(WINDOW_WIDTH))
  eq(#explorer_lines(), 5)
end

T['the header']['drops the toggles when the window narrows, and lays them out again when it widens'] = function()
  explore('header-resize', FILES, change_some_files)
  wait_for_header(function(shown)
    return shown:find('3 changed', 1, true) ~= nil
  end)

  child.cmd('vertical resize 30')
  local narrow = wait_for_header(function(shown)
    return shown:find('dotfiles', 1, true) == nil
  end)
  child.cmd('vertical resize ' .. (title_width('header-resize') + HEADER_ROOM))
  local wide = wait_for_header(function(shown)
    return shown:find('dotfiles', 1, true) ~= nil
  end)

  eq(narrow:find('dotfiles', 1, true), nil)
  eq(vim.endswith(wide, 'dotfiles shown'), true)
end

T['the header']['shows no branch for a folder on a detached HEAD'] = function()
  explore('header-detached', FILES, function(top)
    git_repo.git(top, { 'checkout', '--quiet', '--detach' })
  end)

  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  local header = explorer_lines()[1]

  eq(
    header:match('^(.-)%s+ignored hidden'),
    vim.fn.fnamemodify(child.lua_get('vim.fn.getcwd()'), ':~')
  )
end

T['the dimming'] = MiniTest.new_set()

T['the dimming']['shows an unchanged file’s name in the unchanged group while a file shows changed, and none otherwise'] = function()
  explore('dim', FILES, function(top)
    git_repo.write(top, 'README.md', { 'readme', 'second' })
  end)
  wait_for_lines(function(lines)
    return #lines == 3
  end)
  put_cursor_on('docs/')
  entry.press(child, 'l')
  local dimmed = child.lua_get([[(function()
    local buffer = vim.fn.bufnr('aineo://explorer')
    local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
    local found = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
      if mark[4].hl_group == 'AineoExplorerUnchanged' then
        table.insert(found, { mark[2] + 1, mark[3], mark[4].end_col })
      end
    end
    return found
  end)()]])

  eq(dimmed, { { 3, 6, #'      guide.md' } })
end

T['the looks turned off'] = MiniTest.new_set()

--- Explores as `explore()` does, with `looks` as the explorer options of the
--- child's configuration.
---
---@param name string
---@param looks table<string, boolean>
---@param files? table<string, string[]>
---@param change? fun(top: string)
---@return string top
local function explore_with(name, looks, files, change)
  return explore(name, files, change, { explorer = looks })
end

T['the looks turned off']['one set wrong while the editor runs raises nothing, says so once and keeps its default'] = function()
  explore_with('off-wrong', { icons = false })
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.lua(
    "local settings = vim.g.aineo; settings.explorer = { guides = 'no', icons = false }; vim.g.aineo = settings"
  )
  child.lua('vim.v.errmsg = ""')
  put_cursor_on('src/')
  entry.press(child, 'l')
  entry.press(child, 'R')
  wait_for_virtual('overlay', { { 5, '├ ' }, { 6, '└ ' } })
  entry.press(child, 'R')
  vim.wait(500)

  eq(child.lua_get('vim.v.errmsg'), '')
  local about_guides = vim.tbl_filter(function(told)
    return told.message:find('explorer.guides', 1, true) ~= nil
  end, entry.messages(child))
  eq(#about_guides, 1)
  eq(
    about_guides[1].message,
    'aineo: the explorer’s looks: explorer.guides: expected boolean, got string; the default applies'
  )
  eq(virtual_at('inline'), {})
end

T['the looks turned off']['guides: no connector over the indent'] = function()
  explore_with('off-guides', { guides = false })
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  put_cursor_on('src/')
  entry.press(child, 'l')
  wait_for_lines(function(lines)
    return #lines == 5
  end)

  eq(virtual_at('overlay'), {})
end

T['the looks turned off']['icons: no place for an icon, though the plugin is set up'] = function()
  child.lua(FAKE_MINI_ICONS)
  explore_with('off-icons', { icons = false })
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })

  eq(virtual_at('inline'), {})
  eq(child.lua_get('#_G.icon_calls'), 0)
end

T['the looks turned off']['dim: no unchanged group, though a file is changed and another is not'] = function()
  local files = vim.tbl_extend('force', FILES, { LICENSE = { 'mit' } })
  explore_with('off-dim', { dim = false }, files, function(top)
    git_repo.write(top, 'README.md', { 'readme', 'second' })
  end)
  wait_for_lines(function(lines)
    return #lines == 4
  end)

  eq(
    child.lua_get([[(function()
      local buffer = vim.fn.bufnr('aineo://explorer')
      local namespace = vim.api.nvim_get_namespaces()['aineo.explorer']
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
        if mark[4].hl_group == 'AineoExplorerUnchanged' then
          return true
        end
      end
      return false
    end)()]]),
    false
  )
end

T['the looks turned off']['counts: no number after a folder’s mark, no lines added and removed, and no numstat read'] = function()
  child.lua([[
    _G.line_count_reads = 0
    local git = require('aineo.git')
    local read = git.line_counts
    git.line_counts = function(...)
      _G.line_count_reads = _G.line_count_reads + 1
      return read(...)
    end
  ]])
  explore_with('off-counts', { counts = false }, FILES, change_some_files)
  wait_for_lines(function(lines)
    return #lines == 5
  end)
  vim.wait(300)

  eq(virtual_at('right_align'), {})
  eq(
    vim.tbl_filter(function(item)
      return item[2]:match('^%d+$') ~= nil
    end, virtual_at('inline')),
    {}
  )
  eq(child.lua_get('_G.line_count_reads'), 0)
end

T['the looks turned off']['compact: a chain of single-child folders keeps one line for each folder'] = function()
  explore_with('off-compact', { compact = false }, CHAIN_FILES)

  local lines = wait_for_lines(function(shown)
    return #shown == 3
  end)

  eq(lines, { '▸   lua/', '▸   x/', '    README.md' })
end

T['the looks turned off']['diagnostics: no errors and warnings at the right'] = function()
  local top = explore_with('off-diagnostics', { diagnostics = false })
  wait_for_tree({ '▸   docs/', '▸   src/', '    README.md' })
  child.cmd('edit ' .. vim.fn.fnameescape(vim.fs.joinpath(top, 'README.md')))
  child.lua([[
    vim.diagnostic.set(vim.api.nvim_create_namespace('look-test'), 0, {
      { lnum = 0, col = 0, message = 'a', severity = vim.diagnostic.severity.ERROR },
    })
  ]])
  vim.wait(500)

  eq(virtual_at('right_align'), {})
end

return T
