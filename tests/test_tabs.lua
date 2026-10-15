local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Evaluates `code` in the child with the home required as `tabs`.
---
---@param code string
---@return any
local function in_child(code)
  return child.lua_get(("(function() local tabs = require('aineo.tabs') %s end)()"):format(code))
end

T['held()'] = MiniTest.new_set()

T['held()']['gives the held tabs in the order of their places, not of their holding'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')

  local result = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    tabs.hold(handles[3], function() return 'c' end)
    tabs.hold(handles[1], function() return 'a' end)
    return { held = tabs.held(), handles = handles }
  ]])

  eq(result.held, { result.handles[1], result.handles[3] })
end

T['held()']['leaves out a closed tab, which closed() still gives afterwards'] = function()
  child.cmd('tabnew')

  local result = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    for _, handle in ipairs(handles) do
      tabs.hold(handle, function() return 'a' end)
    end
    vim.cmd('tabclose 2')
    return { held = tabs.held(), closed = tabs.closed(), handles = handles }
  ]])

  eq(result.held, { result.handles[1] })
  eq(result.closed, { result.handles[2] })
end

T['hold()'] = MiniTest.new_set()

T['hold()']['takes the new name when a tab is held again'] = function()
  local title = in_child([[
    local handle = vim.api.nvim_get_current_tabpage()
    tabs.hold(handle, function() return 'old' end)
    tabs.hold(handle, function() return 'new' end)
    return tabs.title(handle)
  ]])

  eq(title, '1: new')
end

T['hold()']['raises, and holds nothing, for a name that is not a function'] = function()
  local result = in_child([[
    local handle = vim.api.nvim_get_current_tabpage()
    local held, failure = pcall(tabs.hold, handle, 'a name')
    return { held = held, failure = failure, still_held = #tabs.held() }
  ]])

  eq(result.held, false)
  eq(result.failure:find('name', 1, true) ~= nil, true)
  eq(result.still_held, 0)
end

T['closed()'] = MiniTest.new_set()

T['closed()']['gives a held tab that :tabclose closed, and none the second time'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')

  local result = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    for _, handle in ipairs(handles) do
      tabs.hold(handle, function() return 'a' end)
    end
    vim.cmd('tabclose 2')
    return { first = tabs.closed(), second = tabs.closed(), handles = handles, held = tabs.held() }
  ]])

  eq(result.first, { result.handles[2] })
  eq(result.second, {})
  eq(result.held, { result.handles[1], result.handles[3] })
end

T['closed()']['gives none for a tab that :tabmove moved'] = function()
  child.cmd('tabnew')

  local result = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    for _, handle in ipairs(handles) do
      tabs.hold(handle, function() return 'a' end)
    end
    vim.cmd('tabmove 0')
    return { closed = tabs.closed(), held = tabs.held(), handles = handles }
  ]])

  eq(result.closed, {})
  eq(result.held, { result.handles[2], result.handles[1] })
end

T['number()'] = MiniTest.new_set()

T['number()']['is the place of the tab, held or not, and follows :tabmove'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')

  local result = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    tabs.hold(handles[3], function() return 'c' end)
    local before = { tabs.number(handles[1]), tabs.number(handles[2]), tabs.number(handles[3]) }
    vim.cmd('tabmove 0')
    return {
      before = before,
      after = { tabs.number(handles[1]), tabs.number(handles[2]), tabs.number(handles[3]) },
    }
  ]])

  eq(result.before, { 1, 2, 3 })
  eq(result.after, { 2, 3, 1 })
end

T['number()']['falls when a tab before it closes'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')

  local number = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    vim.cmd('tabclose 1')
    return tabs.number(handles[3])
  ]])

  eq(number, 2)
end

T['number()']['is nil for a tab page that does not exist'] = function()
  child.cmd('tabnew')

  local result = in_child([[
    local handle = vim.api.nvim_list_tabpages()[2]
    vim.cmd('tabclose 2')
    local succeeded, number = pcall(tabs.number, handle)
    return { succeeded = succeeded, no_number = number == nil }
  ]])

  eq(result, { succeeded = true, no_number = true })
end

T['title()'] = MiniTest.new_set()

T['title()']['is the place and the name of a held tab'] = function()
  child.cmd('tabnew')

  local titles = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    tabs.hold(handles[2], function() return 'fix the login' end)
    local before = tabs.title(handles[2])
    vim.cmd('tabmove 0')
    return { before, tabs.title(handles[2]) }
  ]])

  eq(titles, { '2: fix the login', '1: fix the login' })
end

T['title()']['is the place and the tail of the buffer name for a tab not held'] = function()
  child.cmd('edit /tmp/t65-folder/notes.txt')
  child.cmd('tabnew /tmp/t65-folder/other/todo.md')
  child.cmd('tabnew')
  child.cmd('tabnext 1')

  local titles = in_child([[
    local result = {}
    for _, handle in ipairs(vim.api.nvim_list_tabpages()) do
      table.insert(result, tabs.title(handle))
    end
    return result
  ]])

  eq(titles, { '1: notes.txt', '2: todo.md', '3: [No Name]' })
end

--- The title of the only tab page, held with the name `name`.
---
---@param name string
---@return string
local function title_named(name)
  return child.lua_get(
    [[(function(name)
      local tabs = require('aineo.tabs')
      local handle = vim.api.nvim_get_current_tabpage()
      tabs.hold(handle, function() return name end)
      return tabs.title(handle)
    end)(...)]],
    { name }
  )
end

T['title()']['keeps a name of 24 display cells whole'] = function()
  local name = string.rep('n', 24)

  eq(title_named(name), '1: ' .. name)
end

T['title()']['cuts a name of 25 display cells to 23 cells and an ellipsis'] = function()
  eq(title_named(string.rep('n', 25)), '1: ' .. string.rep('n', 23) .. '…')
end

T['title()']['cuts a 60-cell name'] = function()
  eq(title_named(string.rep('n', 60)), '1: ' .. string.rep('n', 23) .. '…')
end

T['title()']['cuts multibyte text by display cells, not by bytes'] = function()
  eq(title_named(string.rep('é', 25)), '1: ' .. string.rep('é', 23) .. '…')
end

T['title()']["cuts wide characters on a character's edge"] = function()
  local twelve_wide = string.rep('語', 12)

  eq(title_named(twelve_wide), '1: ' .. twelve_wide)
  eq(title_named(string.rep('語', 13)), '1: ' .. string.rep('語', 11) .. '…')
end

T['title()']['cuts the tail of a buffer name too'] = function()
  child.cmd('edit /tmp/t65-folder/' .. string.rep('b', 30) .. '.txt')

  local title = in_child('return tabs.title(vim.api.nvim_get_current_tabpage())')

  eq(title, '1: ' .. string.rep('b', 23) .. '…')
end

--- What a held tab's `name()` does, in Lua, when it gives no usable text.
local NAMES_WITH_NO_TEXT = {
  ['nothing'] = 'return nil',
  ['an empty string'] = "return ''",
  ['a number'] = 'return 5',
  ['a table'] = 'return {}',
  ['an error'] = "error('no name today')",
}

T['title()']["says the buffer's tail for a held tab whose name() gives no text"] =
  MiniTest.new_set({
    parametrize = vim.tbl_map(function(name)
      return { name }
    end, vim.fn.sort(vim.tbl_keys(NAMES_WITH_NO_TEXT))),
  })

T['title()']["says the buffer's tail for a held tab whose name() gives no text"][1] = function(name)
  child.cmd('edit /tmp/t65-folder/fallback.txt')

  local title = in_child(([[
    local handle = vim.api.nvim_get_current_tabpage()
    tabs.hold(handle, function() %s end)
    local succeeded, title = pcall(tabs.title, handle)
    return succeeded and title or 'title() raised: ' .. title
  ]]):format(NAMES_WITH_NO_TEXT[name]))

  eq(title, '1: fallback.txt')
end

T['title()']['takes the buffer of the tab page itself, not of the current tab'] = function()
  child.cmd('edit /tmp/t65-folder/first.txt')
  child.cmd('tabnew /tmp/t65-folder/second.txt')
  child.cmd('split /tmp/t65-folder/third.txt')
  child.cmd('tabnext 1')

  local title = in_child('return tabs.title(vim.api.nvim_list_tabpages()[2])')

  eq(title, '2: third.txt')
end

T['tabline()'] = MiniTest.new_set()

--- Draws the tab line the way a window does, in the child, with the
--- highlight groups it names.
---
---@param setup string Lua run in the child before the drawing, with `tabs` required
---@return { str: string, highlights: { group: string, start: integer }[], format: string }
local function drawn_tabline(setup)
  return in_child(setup .. [[
    local made, format = pcall(tabs.tabline)
    if not made then
      return { str = 'tabline() raised: ' .. format, format = '' }
    end
    local succeeded, drawn =
      pcall(vim.api.nvim_eval_statusline, format, { use_tabline = true, highlights = true })
    drawn = succeeded and drawn or { str = 'the format cannot be drawn: ' .. drawn }
    drawn.format = format
    return drawn
  ]])
end

T['tabline()']['draws the title of every tab page, the current one in AineoTabLineSel'] = function()
  local drawn = drawn_tabline([[
    tabs.draw_tabline()
    vim.cmd('edit /tmp/t65-folder/notes.txt')
    vim.cmd('tabnew')
    tabs.hold(vim.api.nvim_get_current_tabpage(), function() return 'second' end)
  ]])

  eq(drawn.str, '  1: notes.txt    2: second  ')
  eq(drawn.highlights, {
    { group = 'AineoTabLine', start = 0, groups = { 'TabLineFill', 'AineoTabLine' } },
    { group = 'AineoTabLineSel', start = 16, groups = { 'TabLineFill', 'AineoTabLineSel' } },
    { group = 'AineoTabLineFill', start = 29, groups = { 'TabLineFill', 'AineoTabLineFill' } },
  })
end

T['tabline()']['draws the padding setting either side of every title'] = MiniTest.new_set({
  parametrize = {
    { 0, '1: notes.txt2: second' },
    { 4, '    1: notes.txt        2: second    ' },
  },
})

T['tabline()']['draws the padding setting either side of every title'][1] = function(padding, line)
  local drawn = drawn_tabline(([[
    vim.g.aineo = { tabs = { padding = %d } }
    vim.cmd('edit /tmp/t65-folder/notes.txt')
    vim.cmd('tabnew')
    tabs.hold(vim.api.nvim_get_current_tabpage(), function() return 'second' end)
  ]]):format(padding))

  eq(drawn.str, line)
end

T['tabline()']['draws each title in the click region of its tab page'] = function()
  local drawn = drawn_tabline("vim.cmd('tabnew') vim.cmd('tabnew')")

  eq(drawn.format:find('%1T', 1, true) ~= nil, true)
  eq(drawn.format:find('%2T', 1, true) ~= nil, true)
  eq(drawn.format:find('%3T', 1, true) ~= nil, true)
end

T['tabline()']['draws a percent sign in a name as written'] = function()
  local drawn = drawn_tabline([[
    tabs.hold(vim.api.nvim_get_current_tabpage(), function() return '100% done %{x}' end)
  ]])

  eq(drawn.str, '  1: 100% done %{x}  ')
end

T['draw_tabline()'] = MiniTest.new_set()

T['draw_tabline()']["sets 'tabline' to draw aineo's line while it is empty"] = function()
  child.cmd('tabnew')

  local result = in_child([[
    local in_use = tabs.draw_tabline()
    local drawn = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true })
    return { in_use = in_use, str = drawn.str }
  ]])

  eq(result, { in_use = true, str = '  1: [No Name]    2: [No Name]  ' })
end

T['draw_tabline()']["leaves a 'tabline' of the user's in place, and says it is not in use"] = function()
  child.o.tabline = '%f'

  local in_use = in_child('return tabs.draw_tabline()')

  eq(in_use, false)
  eq(child.o.tabline, '%f')
end

T['draw_tabline()']['changes nothing when called again, and still says it is in use'] = function()
  in_child('tabs.draw_tabline()')
  local drawn_once = child.o.tabline

  local in_use = in_child('return tabs.draw_tabline()')

  eq(in_use, true)
  eq(child.o.tabline, drawn_once)
end

T['draw_tabline()']["leaves 'showtabline' as it was"] = function()
  child.o.showtabline = 2

  in_child('tabs.draw_tabline()')

  eq(child.o.showtabline, 2)
end

T['kept_tabs()'] = MiniTest.new_set()

local FIRST = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
local SECOND = 'bbbbbbbb-bbbb-4bbb-9bbb-bbbbbbbbbbbb'
local THIRD = 'cccccccc-cccc-4ccc-accc-cccccccccccc'

T['kept_tabs()']['gives back the sessions in their order and the current place'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-kept-round-trip')

  tabs.keep_tabs(state, '/work/project', { sessions = { SECOND, FIRST, THIRD }, current = 2 })

  eq(tabs.kept_tabs(state, '/work/project'), { sessions = { SECOND, FIRST, THIRD }, current = 2 })
end

--- The file that keeps the list of `folder` under `state`, as the home
--- names it.
---
---@param state string
---@param folder string
---@return string
local function list_file_of(state, folder)
  return vim.fs.joinpath(state, 'aineo', 'claude-tabs', vim.fn.sha256(folder) .. '.json')
end

T['kept_tabs()']["reads the file named by the folder's SHA-256, which only the user can read"] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-kept-file')

  tabs.keep_tabs(state, '/work/project', { sessions = { FIRST }, current = 1 })

  local file = list_file_of(state, '/work/project')
  eq(vim.uv.fs_stat(file).type, 'file')
  eq(vim.uv.fs_stat(file).mode % tonumber('1000', 8), tonumber('600', 8))
end

T['kept_tabs()']['gives the list kept last'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-kept-last')

  tabs.keep_tabs(state, '/work/project', { sessions = { FIRST, SECOND }, current = 2 })
  tabs.keep_tabs(state, '/work/project', { sessions = { THIRD }, current = 1 })

  eq(tabs.kept_tabs(state, '/work/project'), { sessions = { THIRD }, current = 1 })
end

T['kept_tabs()']['keeps one list for each folder, and reads none for another'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-kept-folders')

  tabs.keep_tabs(state, '/work/one', { sessions = { FIRST }, current = 1 })
  tabs.keep_tabs(state, '/work/two', { sessions = { SECOND, THIRD }, current = 2 })

  eq(tabs.kept_tabs(state, '/work/one'), { sessions = { FIRST }, current = 1 })
  eq(tabs.kept_tabs(state, '/work/two'), { sessions = { SECOND, THIRD }, current = 2 })
  eq(tabs.kept_tabs(state, '/work/three'), nil)
end

--- What a file under the folder's name holds, and why it is no list: each
--- reads as none.
local NO_LIST = {
  ['empty'] = { '' },
  ['not JSON'] = { 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' },
  ['a JSON array'] = { '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]' },
  ['no sessions'] = { '{"current":1}' },
  ['sessions that are a string'] = {
    '{"sessions":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","current":1}',
  },
  ['sessions that are an object'] = {
    '{"sessions":{"a":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"},"current":1}',
  },
  ['an empty list'] = { '{"sessions":[],"current":1}' },
  ['an id in upper case'] = {
    '{"sessions":["AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"],"current":1}',
  },
  ['an id of another version'] = {
    '{"sessions":["aaaaaaaa-aaaa-1aaa-8aaa-aaaaaaaaaaaa"],"current":1}',
  },
  ['an id of another form'] = { '{"sessions":["--dangerously-skip-permissions"],"current":1}' },
  ['an id with something after it'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\\n"],"current":1}',
  },
  ['a null among the ids'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",null],"current":1}',
  },
  ['a number for an id'] = { '{"sessions":[1],"current":1}' },
  ['one bad id after good ones'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","bbbbbbbb-bbbb-4bbb-9bbb-bbbbbbbbbbbb","nope"],"current":1}',
  },
  ['a repeated session id'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"],"current":2}',
  },
  ['a current place of 0'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"],"current":0}',
  },
  ['a current place past the list'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"],"current":2}',
  },
  ['a current place that is not whole'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","bbbbbbbb-bbbb-4bbb-9bbb-bbbbbbbbbbbb"],"current":1.5}',
  },
  ['a current place that is a string'] = {
    '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"],"current":"1"}',
  },
  ['no current place'] = { '{"sessions":["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]}' },
  ['bytes that are no text'] = { '\0\255\254{' },
}

--- Writes `text`, byte for byte, as the file that keeps the list of
--- `folder` under `state`.
---
---@param state string
---@param folder string
---@param text string
local function write_list_file(state, folder, text)
  local file = list_file_of(state, folder)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  local handle = assert(io.open(file, 'wb'))
  handle:write(text)
  handle:close()
end

T['kept_tabs()']['reads none from a file that is no list'] = MiniTest.new_set({
  parametrize = vim.tbl_map(function(name)
    return { name }
  end, vim.fn.sort(vim.tbl_keys(NO_LIST))),
})

T['kept_tabs()']['reads none from a file that is no list'][1] = function(name)
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-no-list')
  write_list_file(state, '/work/project', NO_LIST[name][1])

  eq(tabs.kept_tabs(state, '/work/project'), nil)
end

T['kept_tabs()']['reads none when no file is kept'] = function()
  local tabs = require('aineo.tabs')

  eq(tabs.kept_tabs(fixture.directory('t65-none'), '/work/project'), nil)
end

T['kept_tabs()']['reads none when the file is a directory'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-directory')
  vim.fn.mkdir(list_file_of(state, '/work/project'), 'p')

  eq(tabs.kept_tabs(state, '/work/project'), nil)
end

T['kept_tabs()']['reads none from a file grown past any list'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-grown')
  write_list_file(
    state,
    '/work/project',
    '{"sessions":["' .. FIRST .. '"],"current":1}' .. string.rep(' ', 70 * 1024)
  )

  eq(tabs.kept_tabs(state, '/work/project'), nil)
end

T['kept_tabs()']['reads none, and raises nothing, for arguments that are no paths'] = function()
  local tabs = require('aineo.tabs')

  eq({ pcall(tabs.kept_tabs, nil, nil) }, { true })
  eq({ pcall(tabs.kept_tabs, 42, { '/work' }) }, { true })
end

T['keep_tabs()'] = MiniTest.new_set()

T['keep_tabs()']['raises an error naming the file, and leaves the kept list as it was, when the replacement fails'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-keep-fails')
  tabs.keep_tabs(state, '/work/project', { sessions = { FIRST }, current = 1 })
  local file = list_file_of(state, '/work/project')
  vim.fn.mkdir(('%s.%d.cut'):format(file, vim.uv.os_getpid()), 'p')

  local kept, failure =
    pcall(tabs.keep_tabs, state, '/work/project', { sessions = { SECOND }, current = 1 })

  eq(kept, false)
  eq(failure:find(file, 1, true) ~= nil, true)
  eq(tabs.kept_tabs(state, '/work/project'), { sessions = { FIRST }, current = 1 })
end

--- Lists `keep_tabs()` refuses to write, because `kept_tabs()` would read
--- none from them.
local REFUSED_LISTS = {
  ['an id of another form'] = { sessions = { 'nope' }, current = 1 },
  ['an empty list'] = { sessions = {}, current = 1 },
  ['a repeated id'] = { sessions = { FIRST, FIRST }, current = 1 },
  ['a current place past the list'] = { sessions = { FIRST }, current = 2 },
  ['no current place'] = { sessions = { FIRST } },
  ['a hole in the list'] = { sessions = { [1] = FIRST, [5] = SECOND }, current = 1 },
  ['something that is no id'] = { sessions = { FIRST, print }, current = 1 },
}

T['keep_tabs()']['refuses a list kept_tabs() would read as none, naming the file, and keeps the list as it was'] =
  MiniTest.new_set({
    parametrize = vim.tbl_map(function(name)
      return { name }
    end, vim.fn.sort(vim.tbl_keys(REFUSED_LISTS))),
  })

T['keep_tabs()']['refuses a list kept_tabs() would read as none, naming the file, and keeps the list as it was'][1] = function(
  name
)
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-keep-refuses')
  tabs.keep_tabs(state, '/work/project', { sessions = { THIRD }, current = 1 })

  local kept, failure = pcall(tabs.keep_tabs, state, '/work/project', REFUSED_LISTS[name])

  eq(kept, false)
  eq(failure:find(list_file_of(state, '/work/project'), 1, true) ~= nil, true)
  eq(tabs.kept_tabs(state, '/work/project'), { sessions = { THIRD }, current = 1 })
end

T['keep_tabs()']['leaves no file of its own behind when the replacement fails'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-keep-leaves-none')
  local file = list_file_of(state, '/work/project')
  vim.fn.mkdir(vim.fs.joinpath(file, 'occupied'), 'p')

  local kept = pcall(tabs.keep_tabs, state, '/work/project', { sessions = { FIRST }, current = 1 })

  eq(kept, false)
  eq(vim.fn.readdir(vim.fs.dirname(file)), { vim.fs.basename(file) })
end

T['keep_tabs()']['raises an error naming the file when its directory cannot be made'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t65-keep-no-directory')
  write_list_file(state, '/work/other', '{}')
  local blocked = vim.fs.joinpath(state, 'aineo', 'claude-tabs')
  vim.fn.delete(blocked, 'rf')
  vim.fn.writefile({ 'a file, not a directory' }, blocked)

  local kept, failure =
    pcall(tabs.keep_tabs, state, '/work/project', { sessions = { FIRST }, current = 1 })

  eq(kept, false)
  eq(failure:find(list_file_of(state, '/work/project'), 1, true) ~= nil, true)
end

T['tabline()']['numbers each click region by the place of its tab page, after :tabmove and a close'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')

  local drawn = drawn_tabline("vim.cmd('tabclose 1')")

  eq(drawn.format:find('%1T  1: [No Name]  ', 1, true) ~= nil, true)
  eq(drawn.format:find('%2T  2: [No Name]  ', 1, true) ~= nil, true)
end

T['tabline()']['numbers the click regions in the order of the places after :tabmove'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')

  local drawn = drawn_tabline("vim.cmd('tabmove 0')")

  eq(drawn.format:find('%1T', 1, true) < drawn.format:find('%2T', 1, true), true)
  eq(drawn.format:find('%2T', 1, true) < drawn.format:find('%3T', 1, true), true)
end

--- Draws the tab line at 80 columns over three held tabs named for 30 cells,
--- with the tab page `current` current.
---
---@param current integer
---@param setup? string Lua run after the columns are set
---@return string
local function drawn_over_three_long_names(current, setup)
  return drawn_tabline(([[
    vim.o.columns = 80
    %s
    for number = 1, 3 do
      if number > 1 then vim.cmd('tabnew') end
      tabs.hold(vim.api.nvim_get_current_tabpage(), function()
        return ('session %%d, fixing the tab line'):format(number)
      end)
    end
    vim.cmd('%dtabnext')
  ]]):format(setup or '', current)).str
end

T['tabline()']['draws only whole titles, the first tab page current, when all would overflow'] = function()
  eq(
    drawn_over_three_long_names(1),
    '  1: session 1, fixing the t…    2: session 2, fixing the t…  '
  )
end

T['tabline()']['takes the padding from the options setup() recorded'] = function()
  local drawn =
    drawn_tabline("require('aineo').setup({ tabs = { padding = 0 } }) vim.cmd('tabnew')")

  eq(drawn.str, '1: [No Name]2: [No Name]')
end

T['tabline()']['draws the default padding, and raises nothing, when the setting is wrong'] = function()
  local drawn = drawn_tabline('vim.g.aineo = { tabs = { padding = math.huge } }')

  eq(drawn.str, '  1: [No Name]  ')
end

T['tabline()']['counts the padding in the width of the titles it fits'] = MiniTest.new_set({
  parametrize = {
    { 81, 0, 1, 3 },
    { 66, 4, 1, 1 },
    { 100, 4, 1, 2 },
    { 100, 4, 3, 2 },
  },
})

T['tabline()']['counts the padding in the width of the titles it fits'][1] = function(
  columns,
  padding,
  current,
  titles_drawn
)
  local line = drawn_over_three_long_names(
    current,
    ('vim.o.columns = %d vim.g.aineo = { tabs = { padding = %d } }'):format(columns, padding)
  )

  eq(select(2, line:gsub('session %d', '')), titles_drawn)
end

T['tabline()']['draws the current tab page and the one before it when the one after would overflow'] = function()
  eq(
    drawn_over_three_long_names(2),
    '  1: session 1, fixing the t…    2: session 2, fixing the t…  '
  )
end

T['tabline()']['draws the last tab page current, with the one before it, when all would overflow'] = function()
  eq(
    drawn_over_three_long_names(3),
    '  2: session 2, fixing the t…    3: session 3, fixing the t…  '
  )
end

T['title()']["says the buffer's tail for a held tab whose name() holds a NUL, and the line still draws"] = function()
  child.cmd('edit /tmp/t65-folder/fallback.txt')

  local drawn = drawn_tabline([[
    tabs.hold(vim.api.nvim_get_current_tabpage(), function() return 'a\0b' end)
  ]])

  eq(drawn.str, '  1: fallback.txt  ')
end

T['title()']['keeps a character with its accent when it cuts decomposed text'] = function()
  local accented = 'e\204\129'

  eq(title_named(string.rep(accented, 30)), '1: ' .. string.rep(accented, 23) .. '…')
end

T['title()']['keeps a family emoji whole when it cuts'] = function()
  local family = '👨‍👩‍👧'

  eq(title_named(string.rep(family, 13)), '1: ' .. string.rep(family, 11) .. '…')
end

T['title()']['says the last part of a buffer name that ends in a slash'] = function()
  child.cmd('file oil:///work/project/')

  local title = in_child('return tabs.title(vim.api.nvim_get_current_tabpage())')

  eq(title, '1: project')
end

T['hold()']['raises, and holds nothing, for a tab handle below 1'] = MiniTest.new_set({
  parametrize = { { 0 }, { -1 } },
})

T['hold()']['raises, and holds nothing, for a tab handle below 1'][1] = function(handle)
  local result = in_child(([[
    local held, failure = pcall(tabs.hold, %d, function() return 'a' end)
    return { held = held, failure = failure, still_held = #tabs.held() }
  ]]):format(handle))

  eq(result.held, false)
  eq(result.failure:find('tab', 1, true) ~= nil, true)
  eq(result.still_held, 0)
end

T['closed()']['gives several closed tabs in the order of their handles, whichever was held first'] = function()
  local result = in_child([[
    for _ = 1, 16 do vim.cmd('tabnew') end
    local handles = vim.api.nvim_list_tabpages()
    for _, index in ipairs({ 17, 9, 2 }) do
      tabs.hold(handles[index], function() return 'a' end)
    end
    vim.cmd('1tabnext')
    vim.cmd('tabonly')
    return { closed = tabs.closed(), handles = handles }
  ]])

  eq(result.closed, { result.handles[2], result.handles[9], result.handles[17] })
end

T['let_go()'] = MiniTest.new_set()

T['let_go()']['holds the tab no more, and leaves the others held'] = function()
  child.cmd('tabnew')

  local result = in_child([[
    local handles = vim.api.nvim_list_tabpages()
    tabs.hold(handles[1], function() return 'a' end)
    tabs.hold(handles[2], function() return 'b' end)
    tabs.let_go(handles[1])
    return { held = tabs.held(), handles = handles }
  ]])

  eq(result.held, { result.handles[2] })
end

T['list_of_tabs()'] = MiniTest.new_set()

T['list_of_tabs()']['gives the sessions in the order of the tabs and the place of the current one'] = function()
  local tabs = require('aineo.tabs')

  local list = tabs.list_of_tabs({
    { session = SECOND, current = false },
    { session = FIRST, current = true },
    { session = THIRD, current = false },
  })

  eq(list, { sessions = { SECOND, FIRST, THIRD }, current = 2 })
end

T['list_of_tabs()']['leaves out a tab that has no session yet, and counts the place among the rest'] = function()
  local tabs = require('aineo.tabs')

  local list = tabs.list_of_tabs({
    { session = FIRST, current = false },
    { current = false },
    { session = SECOND, current = true },
  })

  eq(list, { sessions = { FIRST, SECOND }, current = 2 })
end

T['list_of_tabs()']['lists a session two tabs show once, at the lower place, and its place for the current one'] = function()
  local tabs = require('aineo.tabs')

  local list = tabs.list_of_tabs({
    { session = FIRST, current = false },
    { session = SECOND, current = false },
    { session = FIRST, current = true },
  })

  eq(list, { sessions = { FIRST, SECOND }, current = 1 })
end

T['list_of_tabs()']['puts the place at the first tab when none is current, or the current one has no session'] = function()
  local tabs = require('aineo.tabs')

  local none_current = tabs.list_of_tabs({
    { session = FIRST, current = false },
    { session = SECOND, current = false },
  })
  local current_has_no_session = tabs.list_of_tabs({
    { session = FIRST, current = false },
    { current = true },
  })

  eq(none_current, { sessions = { FIRST, SECOND }, current = 1 })
  eq(current_has_no_session, { sessions = { FIRST }, current = 1 })
end

T['list_of_tabs()']['gives nothing when no tab has a session'] = function()
  local tabs = require('aineo.tabs')

  eq(tabs.list_of_tabs({}), nil)
  eq(tabs.list_of_tabs({ { current = true } }), nil)
end

T['list_of_tabs()']['gives a list keep_tabs() keeps and kept_tabs() reads back'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t68-list-of-tabs-round-trip')
  local list = tabs.list_of_tabs({
    { session = FIRST, current = false },
    { session = FIRST, current = false },
    { session = SECOND, current = true },
  })

  tabs.keep_tabs(state, '/work/project', list)

  eq(tabs.kept_tabs(state, '/work/project'), { sessions = { FIRST, SECOND }, current = 2 })
end

T['tabs_to_reopen()'] = MiniTest.new_set()

T['tabs_to_reopen()']['gives the kept list when it holds the session kept for the folder'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t68-reopen-holds')
  tabs.keep_tabs(state, '/work/project', { sessions = { FIRST, SECOND, THIRD }, current = 3 })

  local list = tabs.tabs_to_reopen(state, '/work/project', SECOND)

  eq(list, { sessions = { FIRST, SECOND, THIRD }, current = 3 })
end

T['tabs_to_reopen()']['gives nothing when the kept list does not hold the session kept for the folder'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t68-reopen-lacks')
  tabs.keep_tabs(state, '/work/project', { sessions = { FIRST, SECOND }, current = 1 })

  eq(tabs.tabs_to_reopen(state, '/work/project', THIRD), nil)
end

T['tabs_to_reopen()']['gives nothing when no list is kept, or no session is kept for the folder'] = function()
  local tabs = require('aineo.tabs')
  local state = fixture.directory('t68-reopen-none')
  tabs.keep_tabs(state, '/work/other', { sessions = { FIRST }, current = 1 })

  eq(tabs.tabs_to_reopen(state, '/work/project', FIRST), nil)
  eq(tabs.tabs_to_reopen(state, '/work/other', nil), nil)
end

return T
