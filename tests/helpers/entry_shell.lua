--- Drives the shell terminal aineo's terminal pane shows in a child Neovim
--- for the entry suites: finds the shell's terminal, types into it and reads
--- what it prints, and finds the process behind it.

local M = {}

--- The program the child's `'shell'` is set to: a POSIX shell that reads no
--- startup file of the user's, so a case never runs the user's own shell.
M.TEST_SHELL = '/bin/sh'

--- How long a wait for the shell or its process takes at most.
M.PATIENCE_MS = 10000

--- Waits until the Lua expression `expression`, with `...` standing for
--- `args`, is true in `child`, and says whether it was within
--- `M.PATIENCE_MS`.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param expression string
---@param args? table
---@return boolean became_true
function M.wait_until(child, expression, args)
  return vim.wait(M.PATIENCE_MS, function()
    return child.lua_get(expression, args or {})
  end, 20)
end

--- The expression, run in a Neovim, that counts the terminal jobs it runs:
--- Claude's, and each shell's.
M.TERMINAL_JOBS = [[#vim.tbl_filter(function(channel)
  return channel.mode == 'terminal'
end, vim.api.nvim_list_chans())]]

--- The buffer of the shell of the first aineo tab's shell home
--- (`aineo.shell`'s `shell_buffer()`), or nil when it runs none.
---
---@param child table
---@return integer|nil
function M.first_tab_buffer(child)
  return child.lua_get([[require('aineo.shell').shell_buffer()]])
end

--- The buffer the window numbered `window` in the layout's tab shows.
---
---@param child table
---@param window integer the window's place by position in `M.WINDOWS` order, 1 to 3
---@return integer
function M.buffer_of_window(child, window)
  return child.lua_get(
    [[(function(place)
      local windows = vim.tbl_filter(function(candidate)
        return vim.api.nvim_win_get_config(candidate).relative == ''
      end, vim.api.nvim_tabpage_list_wins(0))
      table.sort(windows, function(a, b)
        local a_position, b_position = vim.fn.win_screenpos(a), vim.fn.win_screenpos(b)
        return a_position[2] < b_position[2]
          or (a_position[2] == b_position[2] and a_position[1] < b_position[1])
      end)
      return vim.api.nvim_win_get_buf(windows[place])
    end)(...)]],
    { window }
  )
end

--- Types `command` into the terminal job of `buffer` in `child`, as the user
--- would, ending the line.
---
---@param child table
---@param buffer integer
---@param command string
function M.type_into(child, buffer, command)
  child.lua(
    [[vim.fn.chansend(vim.b[(...)].terminal_job_id, (select(2, ...)) .. '\n')]],
    { buffer, command }
  )
end

--- Waits until a line of the terminal `buffer` holds `text`, and says whether
--- one did.
---
---@param child table
---@param buffer integer
---@param text string
---@return boolean
function M.shows(child, buffer, text)
  return M.wait_until(
    child,
    [[(function(buffer, text)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return false
      end
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
        if line:find(text, 1, true) then
          return true
        end
      end
      return false
    end)(...)]],
    { buffer, text }
  )
end

--- The process id of the shell the terminal `buffer` runs, in `child`.
---
---@param child table
---@param buffer integer
---@return integer pid
function M.pid_of(child, buffer)
  return child.lua_get([[vim.fn.jobpid(vim.b[(...)].terminal_job_id)]], { buffer })
end

--- Waits until the process `pid` has ended, and says whether it had within
--- `M.PATIENCE_MS`.
---
---@param pid integer
---@return boolean
function M.has_ended(pid)
  return vim.wait(M.PATIENCE_MS, function()
    return vim.uv.kill(pid, 0) ~= 0
  end, 20)
end

--- Whether the process `pid` runs.
---
---@param pid integer
---@return boolean
function M.is_running(pid)
  return vim.uv.kill(pid, 0) == 0
end

return M
