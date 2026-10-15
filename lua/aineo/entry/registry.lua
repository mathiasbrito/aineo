--- The tabs of aineo in this editor: the list of them, the one the user used
--- last, and what is read from them — a tab's place, the tab a tab page holds,
--- the tabs that show a session.

local M = {}

--- The tabs of this editor, in the order they were made (`opening.lua`'s
--- `new_tab()`): the tabs whose layout has opened in a tab page of their own,
--- and at most one that has none yet, which a claim made before aineo opened
--- uses. The table is the same for the editor's life; the files of this home
--- add and remove its tabs.
---@type aineo.entry.Tab[]
local tab_list = {}

--- The aineo tab the user used last: the one the current tab page is in when
--- it is one, else the last one the user was in or an action moved to
--- (`opening.lua`'s `acting_tab()`, `editors.lua`'s `TabEnter` handler). Nil
--- before there is one; the files of this home set it.
---@type aineo.entry.Tab?
M.last_used_tab = nil

--- The place of `tab`'s tab page among the editor's tab pages, as `{n}gt`
--- counts it (`aineo.tabs`' `number()`).
---
---@param tab aineo.entry.Tab
---@return integer
local function tab_number(tab)
  return require('aineo.tabs').number(tab.page())
end

--- The first tab of `tab_list` but `except` whose panes follow `session`, in
--- a tab page that exists; nil when there is none.
---
---@param session string
---@param except aineo.entry.Tab
---@return aineo.entry.Tab?
local function tab_following(session, except)
  return vim.iter(tab_list):find(function(other)
    return other ~= except and other.is_bound() and other.panes_session() == session
  end)
end

--- The tab whose tab page the current window is in; nil when it is in none.
---
---@return aineo.entry.Tab?
local function tab_of_current_page()
  local current = vim.api.nvim_get_current_tabpage()
  return vim.iter(tab_list):find(function(tab)
    return tab.page() == current
  end)
end

--- The place of each tab page of this editor that shows a Claude session,
--- by the session's id: the session of the Claude Code of each tab
--- (`aineo.entry.Tab`'s `session_id()`), and, where several tabs show one, the
--- lowest place. What the list of sessions marks and a pick moves to, unless
--- the current tab shows the session itself (`settles_by_standing()`).
---
---@return aineo.claude.ShownInTabs
local function sessions_shown_in_tabs()
  local shown = {}
  for _, tab in ipairs(tab_list) do
    local id = tab.is_bound() and tab.session_id()
    if id then
      shown[id] = math.min(shown[id] or math.huge, tab_number(tab))
    end
  end
  return shown
end

M.tab_list = tab_list
M.tab_number = tab_number
M.tab_following = tab_following
M.tab_of_current_page = tab_of_current_page
M.sessions_shown_in_tabs = sessions_shown_in_tabs

return M
