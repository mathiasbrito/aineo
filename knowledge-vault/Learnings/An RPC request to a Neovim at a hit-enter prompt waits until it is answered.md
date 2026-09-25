# An RPC request to a Neovim at a hit-enter prompt waits until it is answered

**Tags:** #neovim #rpc #testing #trap
**Discovered:** [[Sessions/2026-09-25 — T7 entry point]] (its open threads; the fix round and the correction)
**Applies to:** [[Projects/aineo]]

## The insight

A Neovim that shows a hit-enter or more prompt serves no ordinary RPC request until the prompt is answered. A test, or any client, that sends `nvim_exec_lua`, `nvim_eval` or `nvim_buf_get_lines` to it waits for as long as the prompt stands — without a timeout, forever. A fast request — `nvim_get_mode()`, `nvim_input()` — is still answered: `nvim_get_mode()`'s `blocking` field is `true` at such a prompt. Checking it first narrows the window but does not close it, since the editor can block between the check and the next request.

## Why it is true

Neovim's help states it (`:h api-fast`, 0.11.6): "Most API functions are ‘deferred’: they are queued on the main loop and processed sequentially with normal input. So if the editor is waiting for user input in a ‘modal’ fashion (e.g. the |hit-enter-prompt|), the request will block. Non-deferred (fast) functions such as |nvim_get_mode()| and |nvim_input()| are served immediately." `nvim_get_mode()`'s `blocking` "is true if Nvim is waiting for input" (`:h nvim_get_mode()`).

## Example

T7's interactive test editors — real Neovims in terminal jobs, queried over their `--listen` socket (`tests/helpers/entry_editor.lua`) — hit exactly this when an error at startup produced a hit-enter prompt at 80 columns. The fix round's helper asks `nvim_get_mode()` before each request and raises when it finds the editor blocked; the correction added `launch()`, `mode()` and `wait_for_screen()` so the 80-column pin asks nothing that waits. The helper's `start()` and `settle()` can still stall when the editor blocks the moment after the check: the suite's run limit (`AINEO_TEST_RUN_LIMIT_MS`) bounds it, and T7's note records it as a limit.

## Why it matters

Any tool that drives a Neovim over RPC — a test harness, an embedding UI, a remote plugin — must treat a message longer than `v:echospace`, or any error at startup, as a way to freeze its client. Ask `nvim_get_mode()` first, keep messages short enough not to prompt, and bound every wait from outside. Measured on Neovim 0.11.6 by T7's packet and its reviews.
