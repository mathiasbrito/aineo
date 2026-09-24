--- When Claude Code, starting in a terminal buffer, is ready for input.

local M = {}

--- The glyph that opens Claude Code's input box.
local PROMPT = '❯'

--- Words of the workspace-trust dialog, whose selected choice carries the
--- prompt's glyph too: "Yes, I trust this folder". Narrower than "trust", which
--- a folder's own name on the startup screen may hold.
local TRUST_DIALOG = 'trust this folder'

--- How long the input box must have shown before Claude Code counts as ready:
--- the shortest wait known to be enough for Claude Code to take the input sent
--- after it.
local SETTLE_MS = 1500

--- Whether the screen of `buffer` shows Claude Code's input box, and not the
--- workspace-trust dialog.
---
---@param buffer integer a terminal buffer
---@return boolean
local function shows_ready_prompt(buffer)
  local screen = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
  return screen:find(PROMPT, 1, true) ~= nil and screen:find(TRUST_DIALOG, 1, true) == nil
end

--- Calls `on_ready` once, `SETTLE_MS` after the screen of `buffer` first shows
--- Claude Code's input box with no workspace-trust dialog: never while the
--- dialog waits for the user's answer. Watches the buffer's changes from the
--- moment it is called, so it is called before the terminal starts.
---
---@param buffer integer the buffer Claude Code's terminal runs in
---@param on_ready fun()
function M.when_ready(buffer, on_ready)
  vim.api.nvim_buf_attach(buffer, false, {
    on_lines = function()
      if shows_ready_prompt(buffer) then
        vim.defer_fn(on_ready, SETTLE_MS)
        return true
      end
    end,
  })
end

return M
