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
---@field namespace string the name of the namespace its extmarks live in
---@field label string the word that names it in the gutter, on its first row
---@field accent_group string the highlight group whose foreground is its accent
---@field accent_fallback integer the accent when that group has no foreground
---@field groups aineo.explain.KindGroups

---@type aineo.explain.Kind
M.EXPLANATIONS = {
  namespace = 'aineo_explain',
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

return M
