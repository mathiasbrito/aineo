#!/bin/sh
# Prints the passages of a Claude Code binary that decide its terminal title
# and its busy state, as w17-claude-title.txt quotes them. It reads the file;
# it never runs it. Usage: w17-claude-title.sh <path of the claude binary>
#   (the file a `claude` on PATH links to, in Claude Code's versions directory)
set -eu
python3 -I - "$1" <<'EOF'
import re, sys
data = open(sys.argv[1], "rb").read()
patterns = [
    rb"var u8=\[",                      # the busy glyphs, the idle glyph, the period
    rb"function HCe\(h\)\{let T=MCo",   # busy, waiting or idle
    rb"jpo=new Set\(",                  # the task types that count as delegated work
    rb"function jJt\(\)",               # the multiplexer check
    rb"function tc\(\)\{let\{isTerminalFocused", # the focus reading
    rb"terminalProgressBarEnabled:\(\)=>", # the OSC 9;4 setting
]
for pattern in patterns:
    match = re.search(pattern, data)
    if not match:
        print("NOT FOUND:", pattern)
        continue
    print("== offset", match.start())
    print(data[match.start():match.start() + 700].decode("utf-8", "replace"))
EOF
