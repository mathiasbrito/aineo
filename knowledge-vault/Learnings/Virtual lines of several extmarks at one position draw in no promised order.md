# Virtual lines of several extmarks at one position draw in no promised order

**Tags:** #neovim #extmarks #virt_lines
**Discovered:** [[Sessions/2026-10-25 — T151 propose fix]] (D123, the fix preview)
**Applies to:** [[Projects/aineo]]

## The insight

When several extmarks carry virtual lines at one position, Neovim draws them in no order you can rely on, and `priority` does not set it. Content that must stack in a fixed order at one place goes in one extmark, whose `virt_lines` list carries the rows in the order wanted.

## Example

Measured on Neovim 0.12.5 while building the fix preview (T151): three extmarks at one position in one namespace drew their lines 1, 3, 2; giving them a `priority` did not order them; across namespaces the order followed neither insertion order nor namespace. The preview therefore draws a place's head row, its fix explanation and its new lines as one extmark in the preview's namespace, and the fix explanation has no namespace of its own.

## Where it applies again

Any overlay that stacks parts from several sources above or below a line: build the rows in one place and draw them with one extmark. The measure is of one Neovim release; a different release may order them, but nothing documents that it does, so do not depend on it.
