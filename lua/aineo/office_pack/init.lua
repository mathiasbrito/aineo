--- The office's packs, `require('aineo.office_pack')`: finding them, reading
--- them as data and giving the engine what a pack describes. A pack is a
--- folder of text files and never code.

local literal = require('aineo.office_pack.literal')

local M = {}

M.parse_table_literal = literal.parse

return M
