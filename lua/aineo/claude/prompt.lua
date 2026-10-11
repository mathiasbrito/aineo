--- Whether the prompt of Claude Code, running in a terminal buffer, shows
--- text, read from the terminal's screen and cursor.
---
--- The grey example and suggestions Claude Code draws in an empty prompt read
--- as text in the buffer, and Lua sees no cell attribute that sets them
--- apart, so the text is not what this reads. Claude Code puts the terminal's
--- cursor right after the prompt glyph on an empty prompt and at the end of
--- what is typed otherwise (2.1.281, `tests/fixtures/claude/`), and Neovim
--- keeps the cursor of a window in Terminal mode on the terminal's.

local readiness = require('aineo.claude.readiness')

local M = {}

--- What stands before the cursor on the prompt's line when the prompt is
--- empty: the prompt glyph, then the space or no-break space Claude Code
--- draws after it.
local EMPTY_PROMPT_BEFORE_CURSOR = '^❯[ \194\160]*$'

--- Whether the prompt of the Claude Code terminal that `window` shows holds
--- text: unless the input box is one line and the cursor sits right after
--- the prompt glyph on it. The window must be in Terminal mode, where Neovim
--- keeps its cursor on the terminal's; in any other mode the cursor is
--- somewhere else and this reads the prompt as holding text.
---
--- A draft whose cursor was moved back to its start reads as an empty
--- prompt. A screen that holds no input box, as a dialog's does, reads as
--- holding text.
---
---@param window integer a window showing Claude Code's terminal
---@return boolean
function M.shows_text(window)
  local screen, first_line = readiness.shown_screen(vim.api.nvim_win_get_buf(window))
  local box = screen and readiness.input_box(screen)
  if not box or box.rule ~= box.prompt + 1 then
    return true
  end
  local row, column = unpack(vim.api.nvim_win_get_cursor(window))
  if row - first_line + 1 ~= box.prompt then
    return true
  end
  return screen[box.prompt]:sub(1, column):match(EMPTY_PROMPT_BEFORE_CURSOR) == nil
end

return M
