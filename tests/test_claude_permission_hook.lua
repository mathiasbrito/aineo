local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
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

--- The `--settings` the fake `claude` was given, inline, decoded.
---
---@param fake { record: string }
---@return table
local function settings_of(fake)
  return claude.decoded_words_after(claude.arguments(fake), '--settings')[1]
end

T['aineo’s settings'] = MiniTest.new_set()

T['aineo’s settings']['carry one PermissionRequest hook with no matcher, run in the background'] = function()
  local fake = claude.fake('permission-hook-entry', 'exit')

  claude.start(child, fake, { state_directory = fixture.directory('permission-hook-state') })

  local entries = settings_of(fake).hooks.PermissionRequest or {}
  local entry = entries[1] or {}
  local hook = (entry.hooks or {})[1] or {}
  eq({ #entries, entry.matcher, #(entry.hooks or {}) }, { 1, nil, 1 })
  eq({ hook.type, hook.async }, { 'command', true })
end

T['aineo’s settings']['run the hook relay for PermissionRequest, told the start token'] = function()
  local fake = claude.fake('permission-hook-command', 'exit')

  claude.start(child, fake, { state_directory = fixture.directory('permission-hook-state') })

  local command = claude.hook_command(fake, 1, 'PermissionRequest')
  eq(command:match("'([^']*)' 'PermissionRequest'"), claude.start_token(fake, 1))
end

return T
