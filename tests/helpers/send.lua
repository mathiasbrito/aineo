--- Drives Send in a child Neovim for the Send suite: starts aineo's Claude
--- session against a fake `claude` (`tests/helpers/claude_session.lua`) with
--- aineo's layout around its terminal, fills and reads the Input buffer, sends
--- it as `\s` will, and collects what Send tells the user.

local children = dofile('tests/helpers/child.lua')

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local CLAUDE_SESSION = vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'claude_session.lua')

--- The child's screen: wide and tall enough that Claude's column holds the
--- fake's screens, which Claude Code drew 80 columns wide, whole — Claude's
--- column takes half the width. The recordings were made at 120x40.
local COLUMNS = 240
local LINES = 42

--- Starts `child` afresh at `COLUMNS` by `LINES`, with every notification
--- it gives kept for `messages()` rather than shown.
---
---@param child table a child from `MiniTest.new_child_neovim()`
function M.restart(child)
  children.restart(child)
  child.o.columns = COLUMNS
  child.o.lines = LINES
  child.lua([[
    _G.aineo_test_messages = {}
    vim.notify = function(message, level)
      table.insert(_G.aineo_test_messages, { message = message, level = level })
    end
  ]])
end

--- Opens aineo's layout in `child` around a scratch buffer standing in for
--- Claude's terminal, with no Claude session started; returns the Input
--- buffer.
---
---@param child table
---@return integer input
function M.open_layout_without_session(child)
  return child.lua([[
    local layout = require('aineo.layout')
    layout.open({
      claude = vim.api.nvim_create_buf(false, true),
      report = vim.api.nvim_create_buf(false, true),
      report_height = 2 / 3,
    })
    return layout.input_buffer()
  ]])
end

--- Starts aineo's Claude session in `child` with `fake`'s environment and
--- the stand-in settings (`claude_session.stand_in_settings()`), and, in the
--- same tick, opens the layout around its terminal, as `:Aineo` will; returns
--- the terminal buffer.
---
---@param child table
---@param fake { environment: table<string, string> }
---@return integer buffer
function M.start_with_layout(child, fake)
  return child.lua(
    [[
      local helper, environment = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      local buffer = require('aineo.claude').start_session(helper.stand_in_settings())
      require('aineo.layout').open({
        claude = buffer,
        report = vim.api.nvim_create_buf(false, true),
        report_height = 2 / 3,
      })
      return buffer
    ]],
    { CLAUDE_SESSION, fake.environment }
  )
end

--- Replaces the text of the Input buffer in `child` with `lines`.
---
---@param child table
---@param lines string[]
function M.set_input(child, lines)
  child.lua(
    "vim.api.nvim_buf_set_lines(require('aineo.layout').input_buffer(), 0, -1, false, ...)",
    { lines }
  )
end

--- The Input buffer in `child`: its lines, its name and its `'buftype'`.
---
---@param child table
---@return { lines: string[], name: string, buftype: string }
function M.input(child)
  return child.lua([[
    local input = require('aineo.layout').input_buffer()
    return {
      lines = vim.api.nvim_buf_get_lines(input, 0, -1, false),
      name = vim.api.nvim_buf_get_name(input),
      buftype = vim.bo[input].buftype,
    }
  ]])
end

--- Makes `child` keep every write to a channel (`nvim_chan_send()`) for
--- `writes()`, and still make it.
---
---@param child table
function M.watch_writes(child)
  child.lua([[
    local chan_send = vim.api.nvim_chan_send
    _G.aineo_test_writes = {}
    vim.api.nvim_chan_send = function(channel, bytes)
      table.insert(_G.aineo_test_writes, bytes)
      return chan_send(channel, bytes)
    end
  ]])
end

--- The bytes of every write to a channel `child` has made since
--- `watch_writes()`, one entry per write.
---
---@param child table
---@return string[]
function M.writes(child)
  return child.lua_get('_G.aineo_test_writes')
end

--- Sends Input in `child`, as `\s` will, keeping an error it raises for
--- `messages()` rather than raising it in the test.
---
---@param child table
function M.send(child)
  child.lua([[
    local sent, error_message = pcall(require('aineo.send').send)
    if not sent then
      table.insert(_G.aineo_test_messages, { error = error_message })
    end
  ]])
end

--- Closes the stream of the terminal `buffer` in `child` and sends Input in
--- the same tick, before Neovim has seen the session exit, keeping an error
--- `send()` raises for `messages()`; returns the session's status, read
--- between the two.
---
---@param child table
---@param buffer integer the session's terminal buffer
---@return string? status
function M.send_after_closing_stream(child, buffer)
  return child.lua(
    [[
      vim.fn.jobstop(vim.bo[...].channel)
      local status = require('aineo.claude').session_status()
      local sent, error_message = pcall(require('aineo.send').send)
      if not sent then
        table.insert(_G.aineo_test_messages, { error = error_message })
      end
      return status
    ]],
    { buffer }
  )
end

--- Sends Input in `child` from an `<expr>` mapping, whose callback runs
--- under a text lock, keeping an error `send()` raises for `messages()`.
---
---@param child table
function M.send_from_expression_mapping(child)
  child.lua([[
    vim.keymap.set('n', '<Plug>(aineo-test-send)', function()
      local sent, error_message = pcall(require('aineo.send').send)
      if not sent then
        table.insert(_G.aineo_test_messages, { error = error_message })
      end
      return ''
    end, { expr = true })
    vim.api.nvim_feedkeys(vim.keycode('<Plug>(aineo-test-send)'), 'x', false)
  ]])
end

--- What `child` has told the user since `restart()`, in order: each
--- notification as its message and level, and each error `send()` raised as
--- that error.
---
---@param child table
---@return { message: string?, level: integer?, error: string? }[]
function M.messages(child)
  return child.lua_get('_G.aineo_test_messages')
end

--- The errors `send()` has raised in `child` since `restart()`, joined by
--- line feeds: empty when it raised none.
---
---@param child table
---@return string
function M.raised(child)
  return child.lua([[
    local errors = {}
    for _, message in ipairs(_G.aineo_test_messages) do
      table.insert(errors, message.error)
    end
    return table.concat(errors, '\n')
  ]])
end

return M
