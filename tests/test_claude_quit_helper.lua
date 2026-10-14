local MiniTest = require('mini.test')
local claude = dofile('tests/helpers/claude_session.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- How long the scripted editor takes to receive the first key of the stop.
local FIRST_KEY_AFTER_MS = 300

--- How long the scripted editor takes to exit once the key has come.
local EXIT_AFTER_MS = 700

--- Runs `claude.quit_pressing_ctrl_c()` on an editor played by a script: it
--- quits, the fake receives the stop's first Ctrl-C `FIRST_KEY_AFTER_MS` later,
--- and the editor exits `EXIT_AFTER_MS` after the quit. Returns how many
--- Ctrl-C presses the helper made in the editor before that key reached the
--- fake, and after it.
---
---@return { before_the_key: integer, after_the_key: integer }
local function presses_around_the_first_key()
  local fake = claude.fake('quit-helper', 'ready')
  local editor = vim.fn.jobstart({ 'sleep', '30' })
  local presses = { before_the_key = 0, after_the_key = 0 }
  local scripted_child = {
    job = { id = editor },
    lua_notify = function()
      vim.defer_fn(function()
        vim.fn.writefile({ vim.json.encode({ received = '\3' }) }, fake.record, 'a')
      end, FIRST_KEY_AFTER_MS)
      vim.defer_fn(function()
        vim.fn.jobstop(editor)
      end, EXIT_AFTER_MS)
    end,
    api_notify = {
      nvim_input = function()
        local counted = claude.ctrl_c_count(fake) > 0 and 'after_the_key' or 'before_the_key'
        presses[counted] = presses[counted] + 1
      end,
    },
  }
  MiniTest.finally(function()
    vim.fn.jobstop(editor)
  end)

  claude.quit_pressing_ctrl_c(scripted_child, fake)

  return presses
end

T['quit_pressing_ctrl_c()'] = MiniTest.new_set()

T['quit_pressing_ctrl_c()']['presses no Ctrl-C before the stop’s first key has reached the fake'] = function()
  local presses = presses_around_the_first_key()

  eq(presses.before_the_key, 0)
end

T['quit_pressing_ctrl_c()']['presses Ctrl-C in the editor while the stop goes on'] = function()
  local presses = presses_around_the_first_key()

  eq(presses.after_the_key > 0, true)
end

return T
