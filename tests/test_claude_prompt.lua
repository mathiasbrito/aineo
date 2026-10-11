local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
      child.o.columns = 120
      child.o.lines = 42
    end,
    post_once = child.stop,
  },
})

--- The bytes of the recorded fixture `name` under `tests/fixtures/claude/`:
--- what follows its header, which ends at the first empty line.
---
---@param name string
---@return string
local function recorded_bytes(name)
  local file = assert(io.open('tests/fixtures/claude/' .. name, 'rb'))
  local content = file:read('*a')
  file:close()
  return content:sub((assert(content:find('\n\n', 1, true))) + 2)
end

--- Draws `bytes` on a terminal that the current window of the child shows,
--- as Claude Code's output reaches one, and waits for the screen to hold a
--- prompt.
---
---@param bytes string
local function draw_in_current_window(bytes)
  child.lua(
    [[
      local buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, buffer)
      vim.api.nvim_chan_send(vim.api.nvim_open_term(buffer, {}), ...)
      vim.wait(2000, function()
        return vim.iter(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)):any(function(line)
          return vim.startswith(line, '❯')
        end)
      end, 20)
    ]],
    { bytes }
  )
end

--- Whether the Claude home says the prompt shows text in the current window
--- of the child.
---
---@return boolean
local function current_window_prompt_shows_text()
  return child.lua_get("require('aineo.claude').prompt_shows_text(vim.api.nvim_get_current_win())")
end

--- Draws `bytes` as `draw_in_current_window()` does, enters Terminal mode,
--- as `\c` does, and returns whether the Claude home says the prompt shows
--- text there.
---
---@param bytes string
---@return boolean
local function prompt_shows_text_after(bytes)
  draw_in_current_window(bytes)
  child.lua([[
    vim.cmd.startinsert()
    vim.wait(2000, function()
      return vim.api.nvim_get_mode().mode == 't'
    end, 20)
  ]])
  return current_window_prompt_shows_text()
end

--- The bytes of Claude Code's startup followed by those of the two-line
--- draft typed after it, as the fake's `draft` mode draws them: the draft's
--- recording repaints the rows it changes alone.
---
---@return string
local function drafted_screen()
  return recorded_bytes('startup-2.1.281.bytes') .. recorded_bytes('draft-2.1.281.bytes')
end

T['an empty prompt, its grey example showing'] = function()
  eq(prompt_shows_text_after(recorded_bytes('startup-2.1.281.bytes')), false)
end

T['a two-line draft'] = function()
  eq(prompt_shows_text_after(drafted_screen()), true)
end

T['a one-line draft, the cursor at its end'] = function()
  local typed = '\27[20;1H❯\194\160hello\27[K'

  eq(prompt_shows_text_after(recorded_bytes('startup-2.1.281.bytes') .. typed), true)
end

T['an empty prompt, the cursor on another row of the screen'] = function()
  local cursor_in_footer_at_the_prompts_column = '\27[22;4H'

  eq(
    prompt_shows_text_after(
      recorded_bytes('startup-2.1.281.bytes') .. cursor_in_footer_at_the_prompts_column
    ),
    true
  )
end

T['a one-line draft, the cursor moved back to its start, reads as an empty prompt'] = function()
  local typed_then_home = '\27[20;1H❯\194\160hello\27[K\27[20;3H'

  eq(prompt_shows_text_after(recorded_bytes('startup-2.1.281.bytes') .. typed_then_home), false)
end

T['a two-line draft, the cursor moved to the start of its first line'] = function()
  local cursor_after_the_glyph = '\27[19;3H'

  eq(prompt_shows_text_after(drafted_screen() .. cursor_after_the_glyph), true)
end

T['a screen with no input box, a dialog'] = function()
  local dialog = '\27[2J\27[H' .. recorded_bytes('trust-dialog-2.1.280.screen'):gsub('\n', '\r\n')

  eq(prompt_shows_text_after(dialog), true)
end

T['a window not in Terminal mode'] = function()
  draw_in_current_window(recorded_bytes('startup-2.1.281.bytes'))

  eq(current_window_prompt_shows_text(), true)
end

return T
