--- What the agent of a tab is told when the user ends a walkthrough with
--- `\Vq` (`aineo.entry.walkthrough_record`): to write the whole walkthrough
--- as a record covering every step of the plan, reached or not, an HTML file
--- and the PDF made from it, at a path aineo chose.

local walkthrough_record_path = require('aineo.entry.walkthrough_record_path')

local M = {}

--- The words of the instruction, `%s` the path of the PDF, then of the HTML.
local INSTRUCTION = [[
The walkthrough is over. Write the FULL walkthrough (all steps) as a PDF, as a record for the user to keep or to share with a colleague, not only the steps shown so far. The PDF goes at:
%s

Write it first as HTML at %s (the same name, ending in .html), then make the PDF from that HTML with the first of these tools you find installed: headless Chrome or Chromium, pandoc, typst. If none is installed, keep the HTML, make no PDF and say so.

The record holds the whole walkthrough as planned:
- First page: the walkthrough plan you sent with walkthrough_plan: its title, its summary, what it covers and the list of its steps with their files.
- Then one section for each step of the plan, in its order: the step's title; its explanation, the text of its bands; and the code it marked, exactly the lines its bands were about, in a monospace block headed with the file's path and the numbers of its lines. A step with several ranges gets a block for each range.
- Every step of the plan gets a complete section, whether or not the user reached it. A step the user did not reach is written in full the same way, its explanation and its code ranges taken from the plan as it would have shown them. Mark no step and shorten none.

Before making the PDF, count the sections in the HTML: there must be exactly one for each step of the plan. Add any that is missing.

Create the folder if it is not there. Write no other file. Call neither walkthrough_step nor walkthrough_plan. When done, reply with the path you wrote.]]

--- The instruction that asks the agent for the record of the walkthrough as
--- the PDF at `pdf_path`, and the HTML beside it.
---
---@param pdf_path string where the PDF goes, ending in `.pdf`
---@return string
function M.text(pdf_path)
  return INSTRUCTION:format(pdf_path, walkthrough_record_path.html_beside(pdf_path))
end

return M
