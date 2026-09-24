#!/usr/bin/env python3
"""Context and cost of Claude Code agents, read from their transcripts.

Usage: agent-context.py <transcript.jsonl> [...]

A subagent's transcript is `~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl`.
One row per transcript: the API requests it made (deduplicated by request id,
since a request's content blocks repeat its usage), the context of its last
request (input plus cache tokens — what the next request will carry), and the
totals of uncached input, cache writes, cache reads and output. The orchestrate
skill (§6) gives a fix round to a fresh agent when the author's last context is
past 400 K tokens.
"""
import json
import os
import sys


def usage_rows(path):
    """The final usage of each API request in the transcript at `path`, in order."""
    seen = {}
    with open(path) as transcript:
        for line in transcript:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            message = entry.get("message") or {}
            usage = message.get("usage") if isinstance(message, dict) else None
            request = entry.get("requestId")
            if usage and request:
                seen[request] = usage
    return list(seen.values())


def main(paths):
    print("| transcript | requests | last request's context | input (uncached) | cache write | cache read | output |")
    print("|---|---|---|---|---|---|---|")
    for path in paths:
        rows = usage_rows(path)
        total = lambda key: sum(row.get(key, 0) or 0 for row in rows)
        last = rows[-1] if rows else {}
        context = sum(last.get(key, 0) or 0 for key in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
        print(f"| {os.path.basename(path)} | {len(rows)} | {context:,} | {total('input_tokens'):,} | "
              f"{total('cache_creation_input_tokens'):,} | {total('cache_read_input_tokens'):,} | {total('output_tokens'):,} |")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
