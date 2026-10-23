--- The office's packs, `require('aineo.office_pack')`: reading a pack as data
--- and giving the engine what it describes. A pack is a folder of text files
--- — `pack.lua`, `floor.txt` and `art/*.txt` — and never code.

local finder = require('aineo.office_pack.finder')
local literal = require('aineo.office_pack.literal')
local loader = require('aineo.office_pack.loader')
local problems = require('aineo.office_pack.problems')
local starter = require('aineo.office_pack.starter')
local state_list = require('aineo.office_pack.state_list')

local M = {}

M.find = finder.find
M.load = loader.load
M.check = loader.check
M.start_from_default = starter.start_from_default
M.describe_states = state_list.describe
M.describe_problem = problems.describe
M.warning_of = problems.warning_of
M.quickfix_items = problems.quickfix_items
M.parse_table_literal = literal.parse

return M
