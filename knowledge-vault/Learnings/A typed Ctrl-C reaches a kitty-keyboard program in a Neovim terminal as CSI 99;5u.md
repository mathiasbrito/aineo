# A typed Ctrl-C reaches a kitty-keyboard program in a Neovim terminal as CSI 99;5u

**Tags:** #neovim #terminal #keyboard #testing #measured
**Discovered:** [[Sessions/2026-09-26 — T21 Claude exit]] (PR #64: the records review's R7, the test-integrity review's finding 5) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

A program running in a Neovim terminal can switch on the kitty keyboard protocol by pushing flags with `CSI > <flags> u`. From then on, Neovim sends keys typed in Terminal mode in that protocol's encoding. A Ctrl-C arrives as the eight bytes `ESC [ 9 9 ; 5 u`, not as the byte `0x03`. Neovim also answers the flags query `CSI ? u` with `CSI ? <flags> u`.

A program, or a test's stand-in for one, that waits for `0x03` never sees the interrupt a user types.

## Example

- **T21 (PR #64).** Claude Code's recorded screen switches the protocol on with `ESC[>5u`, and the suite's fake `claude` replays that screen. So a double Ctrl-C typed through Neovim reached the fake as two `ESC[99;5u`. The fake reads only `\3`, so it did not exit.
  - The records review measured it at `70a43c7` on 0.12.5.
  - The test-integrity review measured it at the same head on 0.12.5 **and** 0.11.6, its finding 5.
  - T21 drove the self-exit by writing `\3\3` straight to the pseudo-terminal instead (`claude_session.end_by_keys()`). The typed path through Neovim is not driven (T21's session note, *Decisions* 6 and *Limits*).
- **This pass, in bare Neovim** (2026-09-28, `probe-kitty-ctrl-c.lua` and `keys-reader.py` in `Implementation/Waves/00006-fixes/evidence/learnings-probes.txt`).
  - A small Python program ran in a terminal job of a fresh child, `nvim --clean --headless --embed`. It set its tty raw, pushed the flags if given, asked for them with `CSI ? u`, then recorded every byte it received for 4 s.
  - The child entered Terminal mode (`:startinsert`), and Ctrl-C was typed with `nvim_input('<C-c>')`.
  - The output is identical on 0.12.5 and 0.11.6:

  ```
  flags none mode before the key: t; the program received b'\x03'
  flags 1    mode before the key: t; the program received b'\x1b[?1u\x1b[99;5u'
  flags 5    mode before the key: t; the program received b'\x1b[?5u\x1b[99;5u'
  ```

**Why.** In the protocol's `CSI <key> ; <modifiers> u` form, 99 is the code point of `c`, and 5 is 1 plus 4, the Ctrl modifier's bit. Flag 1 ("disambiguate escape codes") is enough for Ctrl-C to be sent this way. This pass did not re-read the protocol's specification for this note, and did not read where Neovim's terminal implements it; both versions were measured.

## Why it matters

- **A stand-in for a TUI that switches the protocol on** must decode `CSI … u`, or a test must deliver the interrupt some other way, as T21 did.
- **A real program that switches it on** receives a typed Ctrl-C as a key sequence to decode, not as the byte a terminal's line discipline would turn into a signal. Its tty is raw anyway.
- **Limits:**
  - measured on 0.11.6 and 0.12.5, for Ctrl-C only, with flags 1 and 5;
  - what the real Claude Code does with the sequence was not measured; the suite never runs it.
