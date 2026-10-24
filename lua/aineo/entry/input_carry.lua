--- How the text Input holds goes with a claim of another session: carried
--- into that session's draft, or, when it has a draft of its own, as the
--- user chooses.

local M = {}

--- What the question offers for each way of carrying Input's text, by the
--- draft home's name of it (`aineo.draft.Home`'s `follow_draft_session()`).
local CARRY_LABELS = {
  replace = "Replace: Input's text becomes its draft",
  merge = "Merge: its draft, a blank line, then Input's text",
}

--- Calls `with_carry` with how Input's text goes with a claim of the session
--- `claim.claimed`, as `aineo.draft.Home`'s `follow_draft_session()` names
--- it: `'replace'` at once when that session's draft and Input's text do not
--- differ (`input_differs_from_draft()`), which carries an empty Input's
--- nothing; else what the user chooses, asked once through `vim.ui.select()`,
--- `'replace'` or `'merge'`. A question cancelled calls `with_carry` with
--- nil — the claim then carries nothing — and tells the user, after it, where
--- Input's text stayed: the draft of `claim.left`, the session the panes
--- followed until then, or of the folder when they followed none.
---
---@param draft aineo.draft.Home the tab's draft home
---@param claim { claimed: string, left: string? }
---@param with_carry fun(carry: ('replace'|'merge')?)
function M.choose_input_carry(draft, claim, with_carry)
  if not draft.input_differs_from_draft(claim.claimed) then
    with_carry('replace')
    return
  end
  vim.ui.select({ 'replace', 'merge' }, {
    prompt = ('Input holds text, and session %s has a draft of its own'):format(claim.claimed),
    format_item = function(carry)
      return CARRY_LABELS[carry]
    end,
  }, function(carry)
    with_carry(carry)
    if not carry then
      vim.notify(
        ("aineo: Input's text was not carried over; it stays the draft of %s"):format(
          claim.left and 'session ' .. claim.left or 'this folder'
        ),
        vim.log.levels.INFO
      )
    end
  end)
end

return M
