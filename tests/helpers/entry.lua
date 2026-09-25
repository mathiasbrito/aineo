--- Drives aineo's entry point in a child Neovim for the entry suites: starts
--- the child wide enough for aineo's layout around the fake `claude`'s
--- screens, configures aineo to run that fake (`tests/helpers/fake_claude.lua`)
--- in the CLI's place, keeps what aineo tells the user, and reads back what
--- the child's windows show.

local children = dofile('tests/helpers/child.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')

local M = {}

--- The child's screen: Claude's column, half of it, holds the fake's screens,
--- which Claude Code drew 80 columns wide, whole.
M.COLUMNS = 240
M.LINES = 42

--- What `:Aineo` tells the user when it is not given one of its subcommands.
M.USAGE = 'aineo: :Aineo takes one of send, open, report, input, claude'

--- Starts `child` afresh at `M.COLUMNS` by `M.LINES`, with every notification
--- it gives from then on kept for `messages()` rather than shown.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param extra_args? string[] further start arguments, after the init
function M.restart(child, extra_args)
  children.restart(child, extra_args)
  child.o.columns = M.COLUMNS
  child.o.lines = M.LINES
  child.lua([[
    _G.entry_test_messages = {}
    vim.notify = function(message, level)
      table.insert(_G.entry_test_messages, { message = message, level = level })
    end
  ]])
end

--- Runs the Ex command `command` in `child`, keeping an error it raises for
--- `messages()` rather than raising it in the test.
---
---@param child table
---@param command string
function M.command(child, command)
  child.lua(
    [[
      local succeeded, failure = pcall(vim.cmd, ...)
      if not succeeded then
        table.insert(_G.entry_test_messages, { error = failure })
      end
    ]],
    { command }
  )
end

--- What `child` has told the user through `vim.notify()` since `restart()`,
--- in order, each notification as its message and level, and each error a
--- command run by `command()` raised as that error.
---
---@param child table
---@return { message: string?, level: integer?, error: string? }[]
function M.messages(child)
  return child.lua_get('_G.entry_test_messages')
end

--- Makes aineo in `child` run the fake `claude` in `fake`'s mode, writing
--- `fake`'s record (`claude_session.fake()`): the fake's variables go into the
--- child's environment, which Claude's terminal inherits, and `vim.g.aineo`
--- names the fake as `claude.cmd`, overridden key by key by `settings`.
---
---@param child table
---@param fake { environment: table<string, string> }
---@param settings? table more of `vim.g.aineo`
function M.use_fake(child, fake, settings)
  child.lua(
    [[
      local environment, settings = ...
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      vim.g.aineo = settings
    ]],
    {
      fake.environment,
      vim.tbl_deep_extend(
        'force',
        { claude = { cmd = claude_session.fake_command() } },
        settings or {}
      ),
    }
  )
end

--- Replaces the text of the layout's Input buffer in `child` with `lines`.
---
---@param child table
---@param lines string[]
function M.set_input(child, lines)
  child.lua(
    "vim.api.nvim_buf_set_lines(require('aineo.layout').input_buffer(), 0, -1, true, ...)",
    { lines }
  )
end

--- Types `keys` in `child`'s Normal mode as a user would, mappings applied,
--- and waits until they have run. `keys` are written as in a mapping, such
--- as `<Plug>(aineo-open)` or `\o`.
---
---@param child table
---@param keys string
function M.press(child, keys)
  child.lua(
    "vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(..., true, false, true), 'mx', false)",
    { keys }
  )
end

--- The expression, run in a Neovim, that lists what each window of its
--- current tab that does not float shows, left to right and then top to
--- bottom: `'terminal'` for a terminal buffer, else the buffer's name.
M.WINDOWS = [[(function()
  local windows = vim.tbl_filter(function(window)
    return vim.api.nvim_win_get_config(window).relative == ''
  end, vim.api.nvim_tabpage_list_wins(0))
  table.sort(windows, function(a, b)
    local a_position, b_position = vim.fn.win_screenpos(a), vim.fn.win_screenpos(b)
    return a_position[2] < b_position[2]
      or (a_position[2] == b_position[2] and a_position[1] < b_position[1])
  end)
  return vim.tbl_map(function(window)
    local buffer = vim.api.nvim_win_get_buf(window)
    return vim.bo[buffer].buftype == 'terminal' and 'terminal' or vim.api.nvim_buf_get_name(buffer)
  end, windows)
end)()]]

--- The expression, run in a Neovim, that tells what its current window shows,
--- as `M.WINDOWS` tells it.
M.CURRENT_WINDOW = [[vim.bo.buftype == 'terminal' and 'terminal' or vim.api.nvim_buf_get_name(0)]]

--- What `child`'s current window shows (`M.CURRENT_WINDOW`).
---
---@param child table
---@return string
function M.current_window(child)
  return child.lua_get(M.CURRENT_WINDOW)
end

--- What each window of `child`'s current tab shows (`M.WINDOWS`).
---
---@param child table
---@return string[]
function M.windows(child)
  return child.lua_get(M.WINDOWS)
end

return M
