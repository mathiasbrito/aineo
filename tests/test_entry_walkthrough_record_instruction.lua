local MiniTest = require('mini.test')
local instruction = require('aineo.entry.walkthrough_record_instruction')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local PATH = '/work/walkthroughs/2026-11-15-the-values.pdf'

--- Whether `text` holds `part`, spelled as it is.
---
---@param text string
---@param part string
---@return boolean
local function holds(text, part)
  return text:find(part, 1, true) ~= nil
end

T['text()'] = MiniTest.new_set()

T['text()']['names the PDF to write, on a line of its own'] = function()
  eq(holds(instruction.text(PATH), '\n' .. PATH .. '\n'), true)
end

T['text()']['names the HTML to write first, beside the PDF'] = function()
  eq(holds(instruction.text(PATH), '/work/walkthroughs/2026-11-15-the-values.html'), true)
end

T['text()']['says the walkthrough is over'] = function()
  eq(instruction.text(PATH):find('^The walkthrough is over'), 1)
end

T['text()']['asks for the plan on the first page'] = function()
  local text = instruction.text(PATH)

  eq(holds(text, 'First page: the walkthrough plan'), true)
  eq(holds(text, 'walkthrough_plan'), true)
end

T['text()']['asks for a section for each step, in order, with the explanation and the marked code'] = function()
  local text = instruction.text(PATH)

  eq(holds(text, 'one section for each step of the plan, in its order'), true)
  eq(holds(text, 'its explanation'), true)
  eq(holds(text, 'exactly the lines its bands were about'), true)
  eq(holds(text, "file's path and the numbers of its lines"), true)
  eq(holds(text, 'monospace'), true)
end

T['text()']['asks for the FULL walkthrough, all its steps, as a PDF'] = function()
  eq(holds(instruction.text(PATH), 'Write the FULL walkthrough (all steps) as a PDF'), true)
end

T['text()']['asks for every planned step in full, the ones the user did not reach too'] = function()
  local text = instruction.text(PATH)

  eq(
    holds(
      text,
      'Every step of the plan gets a complete section, whether or not the user reached it'
    ),
    true
  )
  eq(holds(text, 'its explanation and its code ranges taken from the plan'), true)
end

T['text()']['marks no step as not shown and shortens none'] = function()
  local text = instruction.text(PATH)

  eq(holds(text, 'not shown'), false)
  eq(holds(text, 'Mark no step and shorten none'), true)
end

T['text()']['asks to count the sections against the plan before making the PDF'] = function()
  eq(
    holds(
      instruction.text(PATH),
      'Before making the PDF, count the sections in the HTML: there must be exactly one for each step of the plan'
    ),
    true
  )
end

T['text()']['names the tools that make the PDF, and says what to do when none is installed'] = function()
  local text = instruction.text(PATH)

  eq(holds(text, 'headless Chrome or Chromium, pandoc, typst'), true)
  eq(holds(text, 'keep the HTML, make no PDF and say so'), true)
end

T['text()']['asks for the folder, no other file and the path as the reply'] = function()
  local text = instruction.text(PATH)

  eq(holds(text, 'Create the folder if it is not there'), true)
  eq(holds(text, 'Write no other file'), true)
  eq(holds(text, 'reply with the path you wrote'), true)
end

T['text()']['asks for no new step of the walkthrough'] = function()
  eq(holds(instruction.text(PATH), 'Call neither walkthrough_step nor walkthrough_plan'), true)
end

T['text()']['keeps a percent sign of the path as it is'] = function()
  eq(holds(instruction.text('/work/100%d/a.pdf'), '\n/work/100%d/a.pdf\n'), true)
end

return T
