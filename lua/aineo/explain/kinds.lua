--- The kinds of virtual line the explain home shows: what each is named, in
--- which namespace it lives, the word that labels it in the gutter, and the
--- highlight groups it is drawn with.

local M = {}

--- The highlight groups one kind is drawn with.
---@class aineo.explain.KindGroups
---@field text string the text of a row and the band behind it
---@field gutter string the gutter's `▎` and label
---@field fill string the gutter's other columns
---@field number string the number of the line the kind is shown for

--- The highlight groups an issue is drawn with once it is marked, in place of
--- the same groups of `aineo.explain.KindGroups`.
---@class aineo.explain.MarkedGroups
---@field text string the text of a row and the band behind it
---@field gutter string the gutter's `✓` and label

--- What one kind says of a deep request, in place of what it says of any
--- other.
---@class aineo.explain.DeepWords
---@field label string the word that names it in the gutter
---@field working string what it says while its request runs
---@field title string what the float that steers the request says it does

--- How a band looks: the word that labels it in the gutter, its accent and
--- the highlight groups it is drawn with (`aineo.explain.look`).
---@class aineo.explain.Look
---@field label string
---@field accent_group string the highlight group whose foreground is its accent
---@field accent_fallback integer the accent when that group has no foreground
---@field groups aineo.explain.KindGroups
---@field marked_groups? aineo.explain.MarkedGroups
---@field struck? aineo.explain.Struck

--- The highlight group of the lines a look shows struck through, and its
--- accent.
---@class aineo.explain.Struck
---@field group string
---@field accent_group string the highlight group whose foreground is its accent
---@field accent_fallback integer the accent when that group has no foreground

--- One kind of virtual line.
--- Its `label` names it in the gutter, on its first row, and its
--- `marked_groups` are those of a marked one, for a kind that can be marked.
---@class aineo.explain.Kind : aineo.explain.Look
---@field name 'explanations'|'issues'|'fix'|'write' what a request names it
---@field namespace string the name of the namespace its extmarks live in
---@field column integer the column its extmarks are set at: a kind with a lower one shows above one with a higher on the same line
---@field working string what it says while its request runs
---@field deep aineo.explain.DeepWords how it names a deep request's answer, and says it works

---@type aineo.explain.Kind
M.EXPLANATIONS = {
  name = 'explanations',
  namespace = 'aineo_explain',
  column = 0,
  working = 'explaining…',
  deep = {
    label = 'expl+',
    working = 'explaining in depth…',
    title = 'Deep explanation',
  },
  label = 'expl',
  accent_group = 'DiagnosticInfo',
  accent_fallback = 0x61afef,
  groups = {
    text = 'AineoExplain',
    gutter = 'AineoExplainGutter',
    fill = 'AineoExplainGutterFill',
    number = 'AineoExplainNr',
  },
}

---@type aineo.explain.Kind
M.ISSUES = {
  name = 'issues',
  namespace = 'aineo_explain_issues',
  column = 1,
  working = 'looking for issues…',
  deep = {
    label = 'issue+',
    working = 'looking for issues in depth…',
    title = 'Deep issue review',
  },
  label = 'issue',
  accent_group = 'DiagnosticWarn',
  accent_fallback = 0xe5c07b,
  groups = {
    text = 'AineoExplainIssue',
    gutter = 'AineoExplainIssueGutter',
    fill = 'AineoExplainIssueGutterFill',
    number = 'AineoExplainIssueNr',
  },
  marked_groups = {
    text = 'AineoExplainIssueMarked',
    gutter = 'AineoExplainIssueMarkedGutter',
  },
}

--- The kind of a proposed fix: the virtual line that says its request is
--- working, and the new lines of its preview (`aineo.explain.preview`). Not
--- one of `ALL`: a fix is not an answer placed above lines.
---@type aineo.explain.Kind
M.FIX = {
  name = 'fix',
  namespace = 'aineo_explain_fix',
  column = 2,
  working = 'proposing a fix…',
  deep = {
    label = 'fix',
    working = 'proposing a fix…',
    title = 'Propose a fix',
  },
  label = 'fix',
  accent_group = 'DiagnosticOk',
  accent_fallback = 0x98c379,
  groups = {
    text = 'AineoFix',
    gutter = 'AineoFixGutter',
    fill = 'AineoFixGutterFill',
    number = 'AineoFixNr',
  },
  struck = {
    group = 'AineoFixOld',
    accent_group = 'DiagnosticError',
    accent_fallback = 0xe06c75,
  },
}

--- The kind of code written for a request (`aineo.explain.write`): the
--- virtual line that says its request is working, and the row that names the
--- request at the top of its preview (`aineo.explain.preview`). Not one of
--- `ALL`: written code is not an answer placed above lines. Its `deep`
--- words are those of a request that reads the project with the tools.
---@type aineo.explain.Kind
M.WRITE = {
  name = 'write',
  namespace = 'aineo_explain_write',
  column = 3,
  working = 'writing code…',
  deep = {
    label = 'write',
    working = 'writing code, reading the project…',
    title = 'Write code, reading the project',
  },
  label = 'write',
  accent_group = 'Special',
  accent_fallback = 0xc678dd,
  groups = {
    text = 'AineoWrite',
    gutter = 'AineoWriteGutter',
    fill = 'AineoWriteGutterFill',
    number = 'AineoWriteNr',
  },
}

--- The look of the fix explanation: the band that says, above each edit of
--- a fix's preview, what the fix does and why the edit fixes the issue. Its
--- rows are drawn with the preview's (`aineo.explain.preview`).
---@type aineo.explain.Look
M.FIX_WHY = {
  label = 'why',
  accent_group = 'DiagnosticHint',
  accent_fallback = 0x56b6c2,
  groups = {
    text = 'AineoFixWhy',
    gutter = 'AineoFixWhyGutter',
    fill = 'AineoFixWhyGutterFill',
    number = 'AineoFixWhyNr',
  },
}

--- Every kind, in the order they are told.
---@type aineo.explain.Kind[]
M.ALL = { M.EXPLANATIONS, M.ISSUES }

--- The kinds of request whose answer is a proposal shown as a preview
--- (`aineo.explain.preview`), of which a buffer shows one at a time.
---@type aineo.explain.Kind[]
M.PROPOSALS = { M.FIX, M.WRITE }

--- Every look whose highlight groups the explain home defines
--- (`aineo.explain.look`): each kind's, and the fix explanation's.
---@type aineo.explain.Look[]
M.LOOKS = { M.EXPLANATIONS, M.ISSUES, M.FIX, M.WRITE, M.FIX_WHY }

--- The kind a request names.
---
---@param name 'explanations'|'issues'
---@return aineo.explain.Kind
function M.named(name)
  return name == M.ISSUES.name and M.ISSUES or M.EXPLANATIONS
end

return M
