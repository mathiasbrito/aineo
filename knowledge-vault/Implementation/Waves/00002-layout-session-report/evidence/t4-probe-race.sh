#!/bin/sh
# Three sweeps of t4-probe-race.lua against the committed fake, then three against the fixed one;
# prints each sweep's hang-ups that took longer than 100 ms to end the fake.
dir=<scratchpad>
root=<worktree>
cd "$dir" || exit 1
for which in old new; do
  if [ "$which" = old ]; then fake="$dir/t4-old-fake.lua"; else fake="$root/tests/helpers/fake_claude.lua"; fi
  for run in 1 2 3; do
    PROBE_FAKE=$fake sh t4-probe.sh t4-probe-race.lua "t4-probe-race-$which-$run-run.txt" >/dev/null
    slow=$(awk '{ if ($6 + 0 > 100) print }' t4-probe-race-out.txt | tr '\n' ';')
    echo "$which sweep $run: $(wc -l < t4-probe-race-out.txt | tr -d ' ') hang-ups, slow: ${slow:-none}"
  done
done
ps -Ao pid,ppid,command | grep -E 't4-old-fake|fake_claude.lua' | grep -v grep | cut -c1-70
