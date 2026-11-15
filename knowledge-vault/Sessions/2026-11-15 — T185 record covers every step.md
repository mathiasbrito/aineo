# 2026-11-15 — T185 record covers every step

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t185-record-all-steps` (from `dev` at 19dac010) · **Pull request:** into `dev` (number recorded after the merge)

T185 (A751, D162): a small fix (D30) to [[Sessions/2026-11-15 — T184 walkthrough record]]. The user reported that when a walkthrough is ended early with `\Vq`, the PDF covers only the steps that were shown. The fixed instruction (`aineo.entry.walkthrough_record_instruction`) now opens with "Write the FULL walkthrough (all steps) as a PDF"; every step of the plan gets a complete section, whether or not the user reached it, its explanation and code ranges taken from the plan; the "marked as not shown" rule is gone, so no step is marked or shortened; and a step asks the agent to count the sections in the HTML against the plan before it makes the PDF.

## Links

- [[Projects/aineo]]

## Tests

- `tests/test_entry_walkthrough_record_instruction.lua`: the "marked as not shown" case became four: the opening words, every step in full including those not reached, no "not shown" and nothing shortened, and the section count against the plan.
- Documentation: `doc/aineo.txt` (`aineo-walkthrough-record`) and the two `\Vq` lines of `README.md`.

## Open threads

- None. Whether an agent obeys the count step is up to the agent; the instruction is the only lever aineo has.
