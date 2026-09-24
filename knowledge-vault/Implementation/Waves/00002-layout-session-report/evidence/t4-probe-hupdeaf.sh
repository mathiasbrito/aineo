#!/bin/sh
# Does a terminal job that ignores SIGHUP outlive Neovim's :qa, with and without a jobstop in VimLeavePre?
dir=<scratchpad>
cd "$dir" || exit 1
for mode in plain jobstop; do
  rm -f "t4-probe-hupdeaf-$mode.pid"
  start=$(date +%s)
  PROBE_MODE=$mode sh t4-probe.sh t4-probe-hupdeaf.lua "t4-probe-hupdeaf-$mode-run.txt"
  end=$(date +%s)
  pid=$(cat "t4-probe-hupdeaf-$mode.pid")
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then alive=yes; kill -9 "$pid"; else alive=no; fi
  echo "$mode: nvim took $((end - start)) s; child $pid alive 1 s after nvim exited: $alive"
done
cat t4-probe-hupdeaf-jobstop.txt
