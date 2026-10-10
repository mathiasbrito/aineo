--- The names the editor's side of the report server and the relay share.

local M = {}

--- The name Claude Code knows aineo's server by.
M.SERVER_NAME = 'aineo'

--- The name of the server's one tool.
M.REPORT_TOOL = 'report'

--- The environment variable that tells the relay which editor to deliver to.
M.EDITOR_ADDRESS_VARIABLE = 'AINEO_EDITOR_ADDRESS'

--- The environment variable that tells the relay the token of the start of
--- Claude Code it serves.
M.START_TOKEN_VARIABLE = 'AINEO_START_TOKEN'

--- The environment variable in which Claude Code tells its MCP servers the
--- session it started on.
M.SESSION_VARIABLE = 'CLAUDE_CODE_SESSION_ID'

return M
