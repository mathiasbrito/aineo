--- The office's packs, `require('aineo.office_pack')`: reading a pack as data
--- and giving the engine what it describes. A pack is a folder of text files
--- — `pack.lua`, `floor.txt` and `art/*.txt` — and never code.

local literal = require('aineo.office_pack.literal')
local loader = require('aineo.office_pack.loader')

local M = {}

M.load = loader.load
M.parse_table_literal = literal.parse

return M
