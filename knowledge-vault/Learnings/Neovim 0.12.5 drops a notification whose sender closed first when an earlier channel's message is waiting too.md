# Neovim 0.12.5 drops a notification whose sender closed first when an earlier channel's message is waiting too

**Tags:** #neovim #rpc #trap #measured
**Discovered:** [[Sessions/2026-10-07 — T35 Session switch]] (*Decided over the brief, on measurement*; PR #137's records review, finding 2)
**Applies to:** [[Projects/aineo]]

## The insight

A client that sends Neovim one RPC notification and then closes its connection cannot count on it being run. When the editor could not run it at once — busy in a long Lua call, or at a hit-enter prompt — and a channel connected **before** that client also has a message waiting (another client's request or notification, or the TUI's keys), Neovim 0.12.5 drops the notification. It is lost, not delayed: it never runs.

Keep the connection open until the editor answers a request sent **behind** the notification. The request is answered only after the notification has run, so its answer is the proof of delivery.

## Example

- **T35's hook relay** was briefed to notify the editor and exit, because a hook that waits holds Claude Code's in-session `/resume` (wave 9's M8). Its author measured the loss: a real Neovim TUI held at a hit-enter prompt, then Enter, lost the notification 3 of 3 times; an idle editor got it every time (the session note's *The probes*). The relay became a hook that starts a detached deliverer and exits in about 20 ms, while the deliverer notifies, waits for the answer to a request behind it, and exits (`lua/aineo/claude/hook_relay.lua`; `e5d661d` on `dev`). The user made that the rule as D43, superseding D36's "one RPC notification, never a request".
- **PR #137's records review** reproduced it with its own scripts: lost 0 of 3 with a request, a notification, or a notification from a third channel connected before the busy spell; delivered 3 of 3 with nothing else waiting, with a third channel connected *after* the relay, with the connection held open, and with a confirming request behind it. Its test-integrity review pinned it: a deliverer that confirmed through a fast call (`nvim_get_mode`) in place of a request behind the notification passed the whole file while losing the notification at a real prompt (r3), so the suite now holds a TUI at a hit-enter prompt (`tests/test_claude_switch.lua`).
- **This pass** (`probe-notify.lua` in [[Attachments/learnings-probes-2026-10-08.txt]]), headless, an editor sleeping 2 s: a relay that notified and closed in 23–27 ms was never run when a channel connected earlier then sent a request (0 of 3) or a notification (0 of 3); it was run when nothing else came (3 of 3). A relay that sent a request behind its notification ended after about 1.9 s, at the answer, and was run 3 of 3.

**Why.** Measured, not read: the mechanism inside Neovim's channel handling was not traced to its source.

## Why it matters

- Any helper process that reports to the editor over RPC — a hook, a relay, a client script — must not notify and exit. Either wait for an answer behind the notification, or send a request, and let a detached process do the waiting when the caller cannot wait.
- [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]] is the other half: a request is held at the prompt, a notification is not held but can be lost. "Notify instead of requesting" avoids the hold only while the sender stays connected.
- aineo's MCP relay keeps its connection open until the editor answers (`lua/aineo/mcp/editor.lua`), so it is not exposed, unless its process ends before an editor at a prompt answers.
- **Limits:** measured on Neovim 0.12.5, macOS, over Unix sockets; a TCP address, and how a later Neovim behaves, were not measured.
