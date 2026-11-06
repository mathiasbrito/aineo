--- Helpers of the suites of a tab's projects (`tests/test_entry_projects*.lua`):
--- repositories to work in, aineo opened in the first with the fake `claude`,
--- the transcript the session writes, and what the changes pane shows.

local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local edit_transcript = dofile('tests/helpers/edit_transcript.lua')
local entry = dofile('tests/helpers/entry.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local M = {}

--- How long a case waits for the pane to show what it waits for.
M.PATIENCE_MS = 10000

--- How long a case waits to be sure something does not happen.
M.QUIET_MS = 600

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

--- Stops `child`, once the fake Claude Code it runs, if any, has ended.
---
---@param child table
function M.stop(child)
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

--- Makes the repository `.tests/fixtures/git-<group>-<folder>/<folder>` hold
--- one commit with `files` (path to lines) on `main`.
---
---@param group string
---@param folder string
---@param files table<string, string[]>
---@return string top
---@return string base the full id of the commit
function M.repository(group, folder, files)
  local top = git_repo.create_unborn(group .. '-' .. folder, folder)
  for path, lines in pairs(files) do
    git_repo.write(top, path, lines)
  end
  return top, git_repo.commit_all(top, 'base')
end

--- Gives the child the environment of the suites' git.
function M.use_isolated_git()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
end

--- Opens aineo in `child` in `top` with the fake `claude`, ready, and
--- returns the fake and the session the tab follows.
---
---@param child table
---@param name string the case's own name for the fake's files
---@param top string the folder to start in
---@param extra_environment? table<string, string> more of the fake's environment, such as `AINEO_FAKE_CLAUDE_HOOKS`
---@return table fake
---@return string session
function M.open_in(child, name, top, extra_environment)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local fake = claude_session.fake(name, 'ready', extra_environment)
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  git_repo.wait_until('the tab follows a session', function()
    return child.lua_get([[require('aineo.claude').session_id()]]) ~= vim.NIL
  end)
  return fake, child.lua_get([[require('aineo.claude').session_id()]])
end

--- Runs `lua` in the child, then waits until the callbacks scheduled by then
--- have run, and those they scheduled in turn.
---
---@param child table
---@param lua string
---@param arguments? any[]
function M.run_and_settle(child, lua, arguments)
  child.lua(lua, arguments or {})
  child.lua([[
    _G.settled = false
    vim.schedule(function()
      vim.schedule(function()
        _G.settled = true
      end)
    end)
  ]])
  vim.wait(M.PATIENCE_MS, function()
    return child.lua_get('_G.settled')
  end, 20)
end

--- Writes an empty transcript for `session` in a file of its own and tells
--- the child's Claude home, as a `SessionStart` hook does, that Claude Code
--- writes the session's transcript there. Returns the path.
---
---@param child table
---@param session string
---@param lines? string[] what the transcript holds already
---@return string path
function M.name_transcript(child, session, lines)
  local directory = vim.fs.joinpath(child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]]), 'projects-test')
  vim.fn.mkdir(directory, 'p')
  local path = vim.fs.joinpath(directory, session .. '.jsonl')
  if lines then
    fake_transcript.append(path, lines)
  else
    fake_transcript.append_text(path, '')
  end
  M.run_and_settle(
    child,
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'startup', claude.start_token(), nil, nil, select(2, ...))
    ]],
    { session, path }
  )
  return path
end

local calls_written = 0

--- Appends to the transcript `path` a call of `tool` with `input`.
---
---@param path string
---@param tool string
---@param input table
function M.call(path, tool, input)
  calls_written = calls_written + 1
  fake_transcript.append(path, { edit_transcript.call(tool, input, calls_written) })
end

--- The line of an `Edit` call of the file `file`, as the transcript holds it.
---
---@param file string
---@return string
function M.edit_line(file)
  calls_written = calls_written + 1
  return edit_transcript.edit(file, calls_written)
end

--- Appends to the transcript `path` an `Edit` call of the file `file`,
--- stamped `stamped`.
---
---@param path string
---@param file string
---@param stamped string
function M.edit_stamped(path, file, stamped)
  calls_written = calls_written + 1
  fake_transcript.append(path, {
    edit_transcript.call(
      'Edit',
      { file_path = file, old_string = 'one', new_string = 'two' },
      calls_written,
      stamped
    ),
  })
end

--- Appends to the transcript `path` an `Edit` call of the file `file`.
---
---@param path string
---@param file string
function M.edit(path, file)
  M.call(path, 'Edit', { file_path = file, old_string = 'one', new_string = 'two' })
end

--- The Lua that finds, in the child, the window that shows a commits buffer
--- of the changes pane in the current tab page.
local COMMITS_WINDOW = [[
  local function commits_window()
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
      if name:find('changes-commits', 1, true) then
        return window
      end
    end
  end
]]

--- The names of the buffers the child's windows show in the current tab
--- page, in the order of the windows.
---
---@param child table
---@return string[]
function M.shown_buffer_names(child)
  return child.lua_get([[vim.tbl_map(function(window)
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

--- The 'winbar' of the window that shows the changes pane's commits buffer,
--- nil when none shows one.
---
---@param child table
---@return string|nil
function M.tab_line(child)
  local line = child.lua(COMMITS_WINDOW .. [[
    local window = commits_window()
    return window and vim.api.nvim_get_option_value('winbar', { win = window }) or vim.NIL
  ]])
  return line ~= vim.NIL and line or nil
end

--- The lines of the buffer the commits window shows.
---
---@param child table
---@return string[]
function M.commits_lines(child)
  return child.lua(COMMITS_WINDOW .. [[
    return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(commits_window()), 0, -1, true)
  ]])
end

--- The lines of the buffer the files window shows: the buffer in the window
--- above the commits window.
---
---@param child table
---@return string[]
function M.files_lines(child)
  return child.lua_get([[(function()
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buffer = vim.api.nvim_win_get_buf(window)
      if vim.api.nvim_buf_get_name(buffer):find('changes-files', 1, true) then
        return vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
      end
    end
    return {}
  end)()]])
end

--- Shows the changes pane in the child, the cursor staying where it is.
---
---@param child table
function M.show_changes_pane(child)
  child.lua([[require('aineo.entry.registry').tab_list[1].show_pane('changes')]])
end

--- Moves the cursor to the commits window of the pane in the child.
---
---@param child table
function M.enter_commits_window(child)
  child.lua(COMMITS_WINDOW .. [[vim.api.nvim_set_current_win(commits_window())]])
end

--- Moves the cursor to the files window of the pane in the child.
---
---@param child table
function M.enter_files_window(child)
  child.lua([[
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
      if name:find('changes-files', 1, true) then
        vim.api.nvim_set_current_win(window)
      end
    end
  ]])
end

--- Waits until `condition()` holds, at most `PATIENCE_MS`, and fails the case
--- with `description` when it never does.
---
---@param description string
---@param condition fun(): boolean
function M.wait_until(description, condition)
  if not vim.wait(M.PATIENCE_MS, condition, 20) then
    MiniTest.expect.equality(description, 'what happened in time')
  end
end

return M
