# sockconnect's on_data hands a zero byte over as a newline

**Tags:** #neovim #channels #binary #trap
**Discovered:** [[Sessions/2026-09-24 — T5 report channel]] (the correction, finding 2)
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.11.6, the list that a `sockconnect()` channel's `on_data` callback receives is split on newlines, and a zero byte in the stream arrives as a `"\n"` inside an item — so joining the list with `"\n"` cannot tell a zero byte from a newline. A binary protocol (msgpack-RPC among them) read through `on_data` breaks whenever a length or a type byte is zero. Read it through a `vim.uv` pipe or TCP handle, whose `read_start()` chunks are the bytes as they came.

## Example

The report relay read the editor's msgpack answer through `sockconnect()`'s `on_data` after the fix round of PR #10 moved off `vim.rpcrequest()` to bound its wait. The re-measure of PR #10 (finding 2) found that a refusal whose message length is a multiple of 256 carries a zero in its str16 header; read as a newline, it left the unpacker waiting for bytes that never came, and the 5 s bound then told Claude the report was sent. The correction (`bc4d9ed`) connects with a `vim.uv` pipe, or a TCP handle for a `host:port` address, and reads with `read_start()` (`lua/aineo/mcp/editor.lua:127`); its tests send refusals of 255, 256, 300, 512 and 513 bytes, and 256 and 512 failed by assertion before it.

## Why it matters

Neovim 0.11.6's help does say it, one step removed: `on_data`'s `{data}` is a "|readfile()|-style list of strings" (`channel.txt`, *channel-callback*, beside the *channel-lines* tag), and `readfile()` replaces "All NUL characters … with a NL character" (`vimfn.txt`, *readfile()*). The writing side, `nvim_chan_send()`, is "8-bit clean: can contain NUL bytes" (`api.txt`). A reader who takes the writing side's promise for the reading side, or reads *channel-lines* without following the `readfile()` link, is caught. Any plugin that speaks a binary protocol over a socket or a job's stdout from Lua should read it through `vim.uv`. The limit of this note: measured on Neovim 0.11.6 with a socket channel; a job's `on_stdout` uses the same list form (`:h channel-lines`), which this project did not measure for zero bytes.
