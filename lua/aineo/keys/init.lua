--- The keys of aineo, `require('aineo.keys')`: the one table that declares each
--- key aineo maps, whether global (typed after the prefix) or local to a
--- buffer that shows something of aineo's: its `<Plug>` mapping, the `:Aineo`
--- command that does the same, the group it belongs to and what it does in a
--- few words. `plugin/aineo.lua` maps the global keys from it, and the
--- cheatsheet is written from it, so neither can drift from the other.
---
--- It loads no other module and reads nothing from the editor.

local M = {}

---@class aineo.keys.Section
---@field id string
---@field title string

---@class aineo.keys.Group
---@field id string
---@field title string
---@field sections? aineo.keys.Section[] the subsections of a group that has them, in the order the cheatsheet shows them; the rows of such a group each name theirs

--- The groups of keys, in the order the cheatsheet shows them.
---@type aineo.keys.Group[]
local GROUPS = {
  { id = 'layout', title = 'Layout and tabs' },
  { id = 'claude', title = 'Claude and sessions' },
  { id = 'agent', title = 'Agent pane' },
  { id = 'changes', title = 'Changes and diff' },
  { id = 'run', title = 'Run and terminal' },
  { id = 'explorer', title = 'Explorer' },
  {
    id = 'explain',
    title = 'Explain and fix',
    sections = {
      { id = 'explain', title = 'Explain' },
      { id = 'issues', title = 'Issues' },
      { id = 'fix', title = 'Fix' },
      { id = 'fix_shown', title = 'While a fix shows' },
      { id = 'steer', title = 'In the steering float' },
      { id = 'clean', title = 'Clean' },
    },
  },
  { id = 'office', title = 'Office and zoom' },
  { id = 'changes_pane', title = 'In the changes pane' },
  { id = 'explorer_pane', title = 'In the explorer' },
}

---@class aineo.keys.Row
---@field group string the id of the row's group (`M.groups()`)
---@field section? string the id of the row's section in its group, when the group has sections
---@field scope 'global'|'buffer'|'mirror' `global`: mapped in the editor, after the prefix; `buffer`: mapped in the buffers that show what the key acts on; `mirror`: maps nothing, lists the key of the row `mirrors` names again, under its own phrase
---@field suffix? string what is typed after the prefix; exactly one of `suffix` and `key` is given, but for a mirror, which has neither
---@field key? string the keys as typed, in the notation of a mapping
---@field mirrors? string the `plug` of the row whose key a `mirror` row lists again
---@field plug? string the words after `aineo-` in the `<Plug>(aineo-…)` mapping that does what the key does
---@field command? string the words after `:Aineo` that do the same
---@field phrase string what the key does, in a few words
---@field modes string the modes it is mapped in: `n` Normal, `x` Visual, `o` Operator-pending, each written once
---@field twin boolean whether Terminal and Insert mode have it too, after the terminal prefix
---@field folded_into? string the `plug` of the row that stands for this one on the cheatsheet, which shows both as a range

--- A key mapped in the editor after the prefix, in Normal mode alone, with no
--- twin in Terminal and Insert mode.
---
---@param group string
---@param suffix string
---@param plug string
---@param command string|nil
---@param phrase string
---@return aineo.keys.Row
local function global(group, suffix, plug, command, phrase)
  return {
    group = group,
    scope = 'global',
    suffix = suffix,
    plug = plug,
    command = command,
    phrase = phrase,
    modes = 'n',
    twin = false,
  }
end

--- A key mapped in the editor after the prefix that has its twin in Terminal
--- and Insert mode too.
---
---@param group string
---@param suffix string
---@param plug string
---@param command string
---@param phrase string
---@return aineo.keys.Row
local function global_with_twin(group, suffix, plug, command, phrase)
  return vim.tbl_extend('force', global(group, suffix, plug, command, phrase), { twin = true })
end

--- A key mapped in the editor after the prefix, in Normal and Visual mode.
---
---@param group string
---@param suffix string
---@param plug string
---@param command string|nil
---@param phrase string
---@return aineo.keys.Row
local function global_in_visual_too(group, suffix, plug, command, phrase)
  return vim.tbl_extend('force', global(group, suffix, plug, command, phrase), { modes = 'nx' })
end

--- `row` in the section `section` of its group.
---
---@param section string
---@param row aineo.keys.Row
---@return aineo.keys.Row
local function in_section(section, row)
  return vim.tbl_extend('force', row, { section = section })
end

--- A listing again, under the phrase `phrase` in the section `section` of
--- `group`, of the key of the row whose `<Plug>` words are `plug`: it maps
--- nothing.
---
---@param group string
---@param section string
---@param plug string
---@param phrase string
---@return aineo.keys.Row
local function listing_again(group, section, plug, phrase)
  return {
    group = group,
    section = section,
    scope = 'mirror',
    mirrors = plug,
    phrase = phrase,
    modes = 'n',
    twin = false,
  }
end

--- A key mapped in a buffer, typed as it is written in the mapping, in
--- `modes` — Normal mode when not given.
---
---@param group string
---@param key string
---@param plug string|nil
---@param phrase string
---@param modes? string
---@return aineo.keys.Row
local function in_buffer(group, key, plug, phrase, modes)
  return {
    group = group,
    scope = 'buffer',
    key = key,
    plug = plug,
    phrase = phrase,
    modes = modes or 'n',
    twin = false,
  }
end

--- A key mapped in a buffer after the prefix, in Normal mode.
---
---@param group string
---@param suffix string
---@param plug string|nil
---@param phrase string
---@return aineo.keys.Row
local function in_buffer_after_the_prefix(group, suffix, plug, phrase)
  return vim.tbl_extend('force', global(group, suffix, plug, nil, phrase), { scope = 'buffer' })
end

--- The keys that move to the tab pages 2 to 9, which the cheatsheet shows
--- as one range with the key of tab page 1.
---
---@return aineo.keys.Row[]
local function tab_keys_after_the_first()
  local rows = {}
  for number = 2, 9 do
    local row = global_with_twin(
      'layout',
      tostring(number),
      'tab-' .. number,
      'tab ' .. number,
      'move to tab ' .. number
    )
    row.folded_into = 'tab-1'
    table.insert(rows, row)
  end
  return rows
end

--- Every key, in the order `plugin/aineo.lua` maps them: the keys of
--- `:Aineo`'s actions, then those of explaining code, then those local to a
--- buffer. The cheatsheet gathers them by group (`M.sheet()`).
---@type aineo.keys.Row[]
local ROWS = vim.list_extend(
  {
    global_in_visual_too('agent', 's', 'send', 'send', 'send Input, or the selection, to Claude'),
    global_with_twin('layout', 'o', 'open', 'open', 'open or restore the layout'),
    global_with_twin('agent', 'r', 'report', 'report', 'move to the Report'),
    global_with_twin('agent', 'i', 'input', 'input', 'move to Input'),
    global_with_twin('claude', 'c', 'claude', 'claude', "move to Claude's terminal"),
    global_with_twin(
      'claude',
      'tcn',
      'claude-numbers',
      'claude-numbers',
      "show or hide the line numbers of Claude's window"
    ),
    global_with_twin(
      'claude',
      'S',
      'sessions',
      'sessions',
      'list the sessions of the folder and resume one'
    ),
    global_with_twin('claude', 'N', 'new', 'new', 'start a new Claude Code session'),
    global_with_twin(
      'agent',
      'pa',
      'pane-agent',
      'pane agent',
      'show the agent pane, in the Report'
    ),
    global_with_twin('changes', 'g', 'pane-changes', 'pane changes', 'show the changes pane'),
    global_with_twin(
      'run',
      'pt',
      'pane-terminal',
      'pane terminal',
      'show the terminal pane, in the shell'
    ),
    global_with_twin('run', 'x', 'pane-run', 'pane run', 'ask for a command and run it'),
    global_with_twin('explorer', 'e', 'pane-explorer', 'pane explorer', 'show the explorer tree'),
    global_with_twin(
      'run',
      'X',
      'run-shell',
      'run shell',
      'add an interactive shell to the run pane'
    ),
    global_with_twin('layout', 'T', 'tab-new', 'tab new', 'open a new tab'),
    global_with_twin('layout', 'Q', 'tab-close', 'tab close', 'close this tab'),
    global_with_twin('layout', '1', 'tab-1', 'tab 1', 'move to tab 1 to 9'),
  },
  vim.list_extend(tab_keys_after_the_first(), {
    global_with_twin('changes', 'd', 'diff-close', 'diff close', 'close the diff'),
    global_with_twin('explorer', 'f', 'find', 'find', 'find a file and open it'),
    global_with_twin('office', 'z', 'zoom', 'zoom', 'zoom the window of the right column'),
    global_with_twin('office', 'Z', 'zoom-full', 'zoom full', 'zoom the window to the whole tab'),
    global_with_twin('office', 'O', 'office', 'office', 'show the office'),
    global('layout', '?', 'cheatsheet', 'cheatsheet', 'show this sheet of keys'),
    in_section(
      'explain',
      global_in_visual_too('explain', 'v', 'explain', 'explain', 'explain the code')
    ),
    in_section(
      'explain',
      global_in_visual_too(
        'explain',
        'V',
        'explain-tools',
        'explain tools',
        'explain it, reading the project'
      )
    ),
    in_section(
      'issues',
      global_in_visual_too(
        'explain',
        'vi',
        'explain-issues',
        'explain issues',
        'find potential issues'
      )
    ),
    in_section(
      'issues',
      global_in_visual_too(
        'explain',
        'VI',
        'explain-issues-tools',
        'explain issues tools',
        'find issues, reading the project'
      )
    ),
    in_section(
      'explain',
      global_in_visual_too(
        'explain',
        'VV',
        'explain-deep',
        nil,
        'explain, editing the prompt first'
      )
    ),
    in_section(
      'issues',
      global_in_visual_too(
        'explain',
        'VVI',
        'explain-deep-issues',
        nil,
        'find issues, editing the prompt first'
      )
    ),
    in_section(
      'issues',
      global_in_visual_too('explain', 'vm', 'explain-mark', nil, 'mark or unmark an issue')
    ),
    in_section(
      'fix',
      global('explain', 'Vf', 'explain-fix', nil, 'propose a fix of the issue here')
    ),
    in_section(
      'fix',
      global(
        'explain',
        'VVf',
        'explain-fix-steered',
        nil,
        'propose a fix, editing the prompt first'
      )
    ),
    in_section(
      'clean',
      global(
        'explain',
        'vc',
        'explain-clean',
        'explain clear',
        'clean the explanations from the buffer'
      )
    ),
    listing_again('explain', 'issues', 'send', 'send the marked issues to Claude'),
    in_section(
      'fix_shown',
      in_buffer_after_the_prefix('explain', 'Va', 'fix-accept', 'accept the fix')
    ),
    in_section(
      'fix_shown',
      in_buffer_after_the_prefix('explain', 'Vr', 'fix-reject', 'reject the fix')
    ),
    in_section(
      'fix_shown',
      in_buffer_after_the_prefix(
        'explain',
        'Vd',
        'fix-diff',
        'show the fix as a diff, or as an overlay'
      )
    ),
    in_section('steer', in_buffer('explain', '<CR>', nil, 'send the prompt')),
    in_section('steer', in_buffer('explain', 'q', nil, 'cancel, as <Esc> does')),
    in_section('steer', in_buffer('explain', 'R', nil, 'restore the default prompt')),
    in_section(
      'issues',
      in_buffer('explain', ']v', 'explain-next', 'jump to the next explanation or issue', 'nxo')
    ),
    in_section(
      'issues',
      in_buffer('explain', '[v', 'explain-previous', 'jump to the previous one', 'nxo')
    ),
    in_buffer('changes_pane', '<CR>', nil, 'show the diff of the entry'),
    in_buffer(
      'changes_pane',
      'l',
      nil,
      'commits: move to the files window; files: diff the file against its previous version'
    ),
    in_buffer('changes_pane', 'h', nil, 'diff the file against HEAD'),
    in_buffer(
      'changes_pane',
      'j',
      nil,
      'next line: in the commits it chooses the files listed, in the files the diff follows'
    ),
    in_buffer('changes_pane', 'k', nil, 'previous line, as j does'),
    in_buffer('changes_pane', 's', nil, 'show one worktree or branch alone'),
    in_buffer('changes_pane', 't', nil, 'show the commit graph'),
    in_buffer('changes_pane', 'gf', nil, 'open the file'),
    in_buffer_after_the_prefix('changes_pane', '<CR>', nil, 'edit the file in its working tree'),
    in_buffer('changes_pane', '<S-CR>', nil, 'edit the file in its working tree'),
    in_buffer('changes_pane', 'F', nil, 'in a diff: the whole file as context, or three lines'),
    in_buffer('changes_pane', '<BS>', nil, 'move back to the files or commits window'),
    in_buffer('explorer_pane', '<CR>', nil, 'unfold or fold the folder, or open the file'),
    in_buffer('explorer_pane', 'l', nil, 'unfold or fold the folder'),
    in_buffer('explorer_pane', 'h', nil, 'fold the folder, or the one above'),
    in_buffer('explorer_pane', 'R', nil, 'read the tree again'),
    in_buffer('explorer_pane', 'I', nil, 'show or hide what git ignores'),
    in_buffer('explorer_pane', 'H', nil, 'hide or show dotfiles'),
    in_buffer('explorer_pane', 'f', nil, 'filter the files by their path'),
    in_buffer('explorer_pane', '@', nil, "paste the entry's path into Claude Code's prompt"),
    in_buffer('explorer_pane', 's', nil, 'pick the worktree or branch to show'),
  })
)

---@class aineo.keys.SheetSection : aineo.keys.Section
---@field rows aineo.keys.Row[] its keys, in the order they are declared

---@class aineo.keys.SheetGroup : aineo.keys.Group
---@field rows aineo.keys.Row[] the keys of the group that belong to no section, in the order they are declared
---@field sections aineo.keys.SheetSection[] the sections of the group, in order, each with its keys; none for a group without sections

--- The groups of keys, in the order the cheatsheet shows them.
---
---@return aineo.keys.Group[]
function M.groups()
  return vim.deepcopy(GROUPS)
end

--- Every key aineo maps, in the order `plugin/aineo.lua` maps them.
---
---@return aineo.keys.Row[]
function M.rows()
  return vim.deepcopy(ROWS)
end

--- The keys gathered by group, as the cheatsheet shows them: each group of
--- `M.groups()`, in its order, with its keys in the order they are declared,
--- those of a group with sections under their sections.
---
---@return aineo.keys.SheetGroup[]
function M.sheet()
  local sheet = {}
  for _, group in ipairs(GROUPS) do
    local in_group = vim.tbl_filter(function(row)
      return row.group == group.id
    end, ROWS)
    local sections = {}
    for _, section in ipairs(group.sections or {}) do
      table.insert(sections, {
        id = section.id,
        title = section.title,
        rows = vim.deepcopy(vim.tbl_filter(function(row)
          return row.section == section.id
        end, in_group)),
      })
    end
    table.insert(sheet, {
      id = group.id,
      title = group.title,
      rows = vim.deepcopy(vim.tbl_filter(function(row)
        return row.section == nil
      end, in_group)),
      sections = sections,
    })
  end
  return sheet
end

return M
