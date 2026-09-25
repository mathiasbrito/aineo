#!/bin/sh
# Runs a headless Nvim probe isolated under the scratchpad: t4-probe.sh <driver.lua> <out>
dir=<scratchpad>
export XDG_CONFIG_HOME="$dir/t4-xdg/config" XDG_DATA_HOME="$dir/t4-xdg/data"
export XDG_STATE_HOME="$dir/t4-xdg/state" XDG_CACHE_HOME="$dir/t4-xdg/cache"
export NVIM_LOG_FILE="$dir/t4-xdg/log" CLAUDE_CONFIG_DIR="$dir/t4-xdg/claude"
cd "$dir" || exit 1
nvim --clean --headless --cmd 'set lines=24 columns=80' -c "luafile $1" > "$2" 2>&1
echo "rc=$?"
