#!/bin/sh
# The fake `claude` of tests/helpers/fake_claude.lua as a command whose words
# hold no flag, which the suites run in `claude.cmd` as
# `sh tests/helpers/fake_claude_print.sh`: aineo takes from `claude.cmd` the
# words before its first flag when it starts a Claude Code of its own for one
# request, and the flags `nvim --clean -l` would be left out. Its arguments
# go to the fake as they are.

exec nvim --clean -l "$(dirname "$0")/fake_claude.lua" "$@"
