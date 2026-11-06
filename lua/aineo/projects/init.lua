--- The projects of a tab's changes pane, `require('aineo.projects')`: the
--- repositories a Claude Code session works in, the first the one it started
--- in, the others those it edited files of or was told of. Pure: it holds no
--- editor state beyond the lists it makes, and requires no other home.

local edits = require('aineo.projects.edits')
local checkouts = require('aineo.projects.checkouts')
local colours = require('aineo.projects.colours')
local kept = require('aineo.projects.kept')
local list = require('aineo.projects.list')
local tab_line = require('aineo.projects.tab_line')

local M = {}

M.new_checkouts = checkouts.new_checkouts
M.define_colours = colours.define_colours
M.keep = kept.keep
M.read_kept = kept.read_kept
M.move_kept = kept.move_kept
M.kept_file = kept.kept_file
M.followed_id = kept.followed_id
M.tab_line = tab_line.tab_line
M.CHOSEN_GROUP = tab_line.CHOSEN_GROUP
M.OTHER_GROUP = tab_line.OTHER_GROUP
M.edited_path = edits.edited_path
M.new_list = list.new_list
M.MOST = list.MOST

return M
