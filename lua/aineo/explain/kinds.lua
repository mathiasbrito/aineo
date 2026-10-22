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

--- One kind of virtual line.
---@class aineo.explain.Kind
---@field name 'explanations'|'issues' what a request names it
---@field namespace string the name of the namespace its extmarks live in
---@field column integer the column its extmarks are set at: a kind with a lower one shows above one with a higher on the same line
---@field label string the word that names it in the gutter, on its first row
---@field accent_group string the highlight group whose foreground is its accent
---@field accent_fallback integer the accent when that group has no foreground
---@field groups aineo.explain.KindGroups

---@type aineo.explain.Kind
M.EXPLANATIONS = {
  name = 'explanations',
  namespace = 'aineo_explain',
  column = 0,
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
  label = 'issue',
  accent_group = 'DiagnosticWarn',
  accent_fallback = 0xe5c07b,
  groups = {
    text = 'AineoExplainIssue',
    gutter = 'AineoExplainIssueGutter',
    fill = 'AineoExplainIssueGutterFill',
    number = 'AineoExplainIssueNr',
  },
}

--- Every kind, in the order they are told.
---@type aineo.explain.Kind[]
M.ALL = { M.EXPLANATIONS, M.ISSUES }

--- The kind a request names.
---
---@param name 'explanations'|'issues'
---@return aineo.explain.Kind
function M.named(name)
  return name == M.ISSUES.name and M.ISSUES or M.EXPLANATIONS
end

return M
