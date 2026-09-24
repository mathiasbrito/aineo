--- The names the editor's side of the report server and the relay share.

local M = {}

--- The name Claude Code knows aineo's server by.
M.SERVER_NAME = 'aineo'

--- The name of the server's one tool.
M.REPORT_TOOL = 'report'

--- The environment variable that tells the relay which editor to deliver to.
M.EDITOR_ADDRESS_VARIABLE = 'AINEO_EDITOR_ADDRESS'

return M
