#!/bin/sh
# Runs w17-probes.lua in a bare Neovim from a scratch directory, with no
# multiplexer variable and no Claude Code variable inherited, and its state
# kept in that directory. Usage: w17-probes.sh <checkout root>
set -eu
root=$(cd "$1" && pwd)
scratch=$(mktemp -d)
cd "$scratch"
for name in $(env | sed -n 's/^\(CLAUDE[A-Z_]*\)=.*/\1/p') TMUX STY ZELLIJ AINEO_CHILD; do
  unset "$name"
done
XDG_STATE_HOME="$scratch/state" XDG_DATA_HOME="$scratch/data" \
  nvim --clean --headless -l "$root/knowledge-vault/Implementation/Waves/00017-tab-activity/evidence/w17-probes.lua" "$root"
rm -rf "$scratch"
