--- Helpers of the suites that drive aineo's tabs (`tests/test_entry_tabs*.lua`)
--- in a child Neovim: where aineo keeps its list of running editors for the
--- child, what the list holds for each of the child's tabs, and what the
--- child's tab pages show.

local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local M = {}

--- How long a case waits for the list of running editors, a window or a mode
--- to hold what it waits for.
M.PATIENCE_MS = 10000

--- The key the list gives the entry of a Neovim's first tab, which has none.
M.FIRST_TAB = ''

--- Gives `child` the state home `name` names, a directory of the case's own
--- under which aineo keeps what it keeps, and returns the state directory
--- under it.
---
---@param child table
---@param name string
---@return string state_directory
function M.use_own_state(child, name)
  local home = fixture.directory(name .. '-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { home })
  return vim.fs.joinpath(home, 'nvim')
end

--- The entries the list of running editors under `state` holds for the
--- editor at `address`, decoded, by the key of the tab each is for
--- (`M.FIRST_TAB` for the entry with none).
---
---@param state string
---@param address string
---@return table<string, table>
function M.entries(state, address)
  local entries = {}
  local pattern = vim.fs.joinpath(state, 'aineo', 'editors', '*.json')
  for _, path in ipairs(vim.fn.glob(pattern, true, true)) do
    local file = io.open(path, 'rb')
    if file then
      local text = file:read('*a')
      file:close()
      local decoded = vim.json.decode(text)
      if decoded.address == address then
        entries[decoded.tab or M.FIRST_TAB] = decoded
      end
    end
  end
  return entries
end

--- How the fake's Claude Code ended, once it has — `keys`, `detach`,
--- `hangup`, `exit` or `lifetime` — waiting for that at most
--- `claude_session.STOP_PATIENCE_MS`; nil when it has not ended by then.
---
---@param fake { record: string }
---@return string?
function M.ended_how(fake)
  local events = claude_session.wait_for_end(fake)
  return events[#events] and events[#events].ended
end

--- The autocommand groups of the second tab's copies of the homes, which
--- exist while that tab does: the layout's, the Report's, the draft's and the
--- changes pane's two.
M.SECOND_TAB_GROUPS = {
  'aineo.layout.2',
  'aineo_report_2',
  'aineo.draft.2',
  'aineo_changes_copy1',
  'aineo_changes_commits_scroll_copy1',
}

--- The groups of `M.SECOND_TAB_GROUPS` that exist in `child`.
---
---@param child table
---@return string[]
function M.second_tab_groups_that_exist(child)
  return child.lua_get(
    [[vim.tbl_filter(function(name)
      return (pcall(vim.api.nvim_get_autocmds, { group = name }))
    end, ...)]],
    { M.SECOND_TAB_GROUPS }
  )
end

--- Types a probe into `child`: keys that set a flag the child answers with
--- `M.probe_answered()`. A child that is blocked, as while a stop waits for
--- a Claude Code to exit, still answers requests of the test but handles no
--- typed key, so the probe tells a blocked editor from one that is not.
---
---@param child table
function M.type_probe(child)
  child.lua('_G.tabs_probe_answered = false')
  child.api.nvim_input('<C-\\><C-n>:lua _G.tabs_probe_answered = true<CR>')
end

--- Whether the child handled the keys of `M.type_probe()` within `within_ms`
--- of this call.
---
---@param child table
---@param within_ms integer
---@return boolean
function M.probe_answered(child, within_ms)
  return vim.wait(within_ms, function()
    return child.lua_get('_G.tabs_probe_answered')
  end, 20)
end

--- The keys of `entries` (`M.entries()`), sorted.
---
---@param entries table<string, table>
---@return string[]
function M.keys_of(entries)
  local keys = vim.tbl_keys(entries)
  table.sort(keys)
  return keys
end

--- The entries of `child` (`M.entries()`) once `is_wanted` accepts them,
--- waiting at most `M.PATIENCE_MS`; else what they are when the wait runs out.
---
---@param state string
---@param child table
---@param is_wanted fun(entries: table<string, table>): boolean
---@return table<string, table>
function M.entries_once(state, child, is_wanted)
  local address = child.v.servername
  vim.wait(M.PATIENCE_MS, function()
    return is_wanted(M.entries(state, address))
  end, 20)
  return M.entries(state, address)
end

--- The session the entry of the tab `key` names, in `child`'s list under
--- `state`, once it has one — waiting at most `M.PATIENCE_MS` — else nil.
--- A Claude Code whose start is confirmed has its tab's entry written, so
--- this also waits for a tab's Claude Code to be ready.
---
---@param state string
---@param child table
---@param key string
---@return string?
function M.session_of_tab(state, child, key)
  local entries = M.entries_once(state, child, function(listed)
    return listed[key] ~= nil
  end)
  return entries[key] and entries[key].session
end

--- The names of the buffers the windows of the tab page numbered `number`
--- show, left to right and then top to bottom: `'terminal'` for a terminal
--- buffer, the buffer's name with the number a copy's name ends in (`-2`)
--- left out otherwise.
---
---@param child table
---@param number integer
---@return string[]
function M.windows_of_tab(child, number)
  return child.lua_get(
    [[(function(number)
      local page = vim.api.nvim_list_tabpages()[number]
      local windows = vim.tbl_filter(function(window)
        return vim.api.nvim_win_get_config(window).relative == ''
      end, vim.api.nvim_tabpage_list_wins(page))
      table.sort(windows, function(a, b)
        local a_position, b_position = vim.fn.win_screenpos(a), vim.fn.win_screenpos(b)
        return a_position[2] < b_position[2]
          or (a_position[2] == b_position[2] and a_position[1] < b_position[1])
      end)
      return vim.tbl_map(function(window)
        local buffer = vim.api.nvim_win_get_buf(window)
        if vim.bo[buffer].buftype == 'terminal' then
          return 'terminal'
        end
        return (vim.api.nvim_buf_get_name(buffer):gsub('%-%d+$', ''))
      end, windows)
    end)(...)]],
    { number }
  )
end

--- The number of the tab page the child's cursor is in.
---
---@param child table
---@return integer
function M.current_tab(child)
  return child.lua_get('vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage())')
end

--- How many tab pages the child has.
---
---@param child table
---@return integer
function M.tab_count(child)
  return child.lua_get('#vim.api.nvim_list_tabpages()')
end

--- The buffer of the terminal Claude's window shows in the tab page numbered
--- `number`: the first window of that tab page by position, which is
--- Claude's in aineo's layout.
---
---@param child table
---@param number integer
---@return integer
function M.claude_terminal_of_tab(child, number)
  return child.lua_get(
    [[(function(number)
      local page = vim.api.nvim_list_tabpages()[number]
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(page)) do
        local buffer = vim.api.nvim_win_get_buf(window)
        if vim.bo[buffer].buftype == 'terminal' then
          return buffer
        end
      end
    end)(...)]],
    { number }
  )
end

--- The name of the Input buffer the tab page numbered `number` shows, or nil
--- when it shows none.
---
---@param child table
---@param number integer
---@return string?
function M.input_name_of_tab(child, number)
  return child.lua_get(
    [[(function(number)
      local page = vim.api.nvim_list_tabpages()[number]
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(page)) do
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
        if name:match('^aineo://input') then
          return name
        end
      end
    end)(...)]],
    { number }
  )
end

--- The lines the Report of the tab page numbered `number` shows, each time
--- of day, which starts a header, written `HH:MM`; none when the tab page
--- shows no Report.
---
---@param child table
---@param number integer
---@return string[]
function M.report_lines_of_tab(child, number)
  return child.lua_get(
    [[(function(number)
      local page = vim.api.nvim_list_tabpages()[number]
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(page)) do
        local buffer = vim.api.nvim_win_get_buf(window)
        if vim.api.nvim_buf_get_name(buffer):match('^aineo://report') then
          return vim.tbl_map(function(line)
            return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
          end, vim.api.nvim_buf_get_lines(buffer, 0, -1, true))
        end
      end
      return {}
    end)(...)]],
    { number }
  )
end

--- The lines the Report of the tab page numbered `number` shows once they
--- are `lines` (`M.report_lines_of_tab()`), waiting for that at most
--- `M.PATIENCE_MS`; else what they are when the wait runs out.
---
---@param child table
---@param number integer
---@param lines string[]
---@return string[]
function M.report_lines_once(child, number, lines)
  local shown
  vim.wait(M.PATIENCE_MS, function()
    shown = M.report_lines_of_tab(child, number)
    return vim.deep_equal(shown, lines)
  end, 50)
  return shown
end

--- Waits, at most `M.PATIENCE_MS`, until the child is in `mode`, as
--- `nvim_get_mode()` names it, and returns the mode it is in then.
---
---@param child table
---@param mode string
---@return string
function M.mode_once(child, mode)
  local current
  vim.wait(M.PATIENCE_MS, function()
    current = child.lua_get('vim.api.nvim_get_mode().mode')
    return current == mode
  end, 20)
  return current
end

--- Waits, at most `M.PATIENCE_MS`, until the child is in Normal mode, which
--- in a terminal buffer `nvim_get_mode()` names `nt`, and returns the mode it
--- is in then.
---
---@param child table
---@return string
function M.normal_mode_once(child)
  local current
  vim.wait(M.PATIENCE_MS, function()
    current = child.lua_get('vim.api.nvim_get_mode().mode')
    return current == 'n' or current == 'nt'
  end, 20)
  return current
end

--- Starts aineo in `child` for a case named `name`, on a state directory of
--- the case's own, with the fake `claude` `fake` in `mode` and the fake's
--- hooks running, and waits until the first Claude Code is ready. Returns the
--- state directory and the fake.
---
---@param child table
---@param name string
---@param mode? string the fake's mode, `ready` by default
---@param extra_environment? table<string, string> more of the fake's variables
---@return string state_directory
---@return { record: string, environment: table<string, string> } fake
function M.open_first_tab(child, name, mode, extra_environment)
  local state = M.use_own_state(child, name)
  local fake = M.fake(name .. '-first', mode, extra_environment)
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return state, fake
end

--- A fake `claude` for one case, in `mode` (`ready` by default), that runs
--- the session hooks aineo gives it.
---
---@param name string
---@param mode? string
---@param extra_environment? table<string, string>
---@return { record: string, environment: table<string, string> }
function M.fake(name, mode, extra_environment)
  return claude_session.fake(
    name,
    mode or 'ready',
    vim.tbl_extend('force', { AINEO_FAKE_CLAUDE_HOOKS = '1' }, extra_environment or {})
  )
end

--- Makes the Claude Code aineo starts next in `child` the fake `fake`: its
--- record and variables replace the previous fake's.
---
---@param child table
---@param fake { record: string, environment: table<string, string> }
function M.use_next_fake(child, fake)
  entry.use_fake(child, fake)
end

--- The new session id the fake's `count`th start was given, on
--- `--session-id`, or none.
---
---@param fake { record: string }
---@param count integer
---@return string?
function M.new_id_of_start(fake, count)
  return claude_session.words_after(claude_session.start_arguments(fake, count), '--session-id')[1]
end

return M
