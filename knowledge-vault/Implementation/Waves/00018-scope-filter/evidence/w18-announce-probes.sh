#!/bin/sh
# Wave 18's amendment (T84): what the planning measured before proposing the
# announce_work tool. Runs git and reads the installed Claude Code binary's
# strings; it never runs `claude`.
#
# P1: how git lists a worktree made through a symbolic link and through a
#     relative path (the path an agent announces versus the one git lists).
# P2: which channels Claude Code offers an MCP server to tell the model
#     about a tool, and whether its MCP tools are deferred behind tool search.
set -eu

PROBE=/tmp/w18-announce-probe
rm -rf "$PROBE"
mkdir -p "$PROBE"

echo "== P1: git $(git --version | cut -d' ' -f3-)"
echo "/tmp is: $(ls -ld /tmp | awk '{print $NF}')"
git init -q "$PROBE/repo"
git -C "$PROBE/repo" worktree add -q --orphan -b feat/a "$PROBE/wt-a"
(cd "$PROBE/repo" && git worktree add -q --orphan -b feat/b ../wt-b)
echo "announced: $PROBE/wt-a and ../wt-b (relative to the repository)"
git -C "$PROBE/repo" worktree list --porcelain | grep '^worktree '

echo "== P2: Claude Code binary"
BINARY=$(python3 -I -c 'import os,shutil; print(os.path.realpath(shutil.which("claude")))')
echo "version (from the file name the install links to): $(basename "$BINARY")"
strings -n 8 "$BINARY" > "$PROBE/strings.txt"
python3 -I - "$PROBE/strings.txt" <<'PY'
import re, sys
text = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
probes = [
    ('a search hint read from a tool\'s _meta',
     r'B\._meta\?\.\["anthropic/searchHint"\]'),
    ('a tool is always loaded when its _meta says so',
     r'alwaysLoad:!T&&\(w&&!\(r==="dynamic"&&B\._meta\?\.\["anthropic/alwaysLoad"\]===!1\)\|\|B\._meta\?\.\["anthropic/alwaysLoad"\]===!0\)'),
    ('the server option, and the default: deferred',
     r'Default: tools are deferred when tool search is enabled\.'),
    ('a deferred tool description is cut',
     r'The model receives only about the first'),
    ('the description length limits',
     r'CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH'),
    ("a server's initialize instructions join the prompt",
     r'# MCP Server Instructions'),
    ('P3: the subagent prompt flag, and its limit',
     r"--append-subagent-system-prompt <prompt>\s+Append a system prompt to every Task-tool subagent's system prompt, propagated to nested subagents \(only works with --print\)"),
    ('P3: the SubagentStart hook gives the subagent context',
     r'When a subagent \(Agent tool call\) is started\s+Input to command is JSON with agent_id and agent_type\.\s+Exit code 0 - JSON additionalContext shown to subagent'),
    ('P3: an agent with no tools list inherits the parent',
     r'If omitted, inherits all tools from parent'),
]
for label, pattern in probes:
    found = re.search(pattern, text)
    shown = found.group(0)[:160] if found else pattern[:80]
    print(('found    ' if found else 'MISSING  ') + label + ': ' + shown)
PY
rm -rf "$PROBE"
