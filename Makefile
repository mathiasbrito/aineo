# aineo's development tasks, run from the checkout:
#
#   make deps                   fetch mini.nvim at its pinned commit
#   make test                   run every tests/**/test_*.lua under mini.test
#   make test_file FILE=<path>  run one test file
#   make lint                   check formatting (StyLua) and lint (selene)
#   make format                 format the Lua sources in place (StyLua)
#
# deps, lint and format take their paths from this file's directory. test
# collects tests/**/test_*.lua under the working directory, and a relative
# FILE resolves there. The checkout's path must hold no space, which make
# cannot take in a file name.

ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# mini.nvim v0.18.0, pinned by commit so the tag cannot move under the suite.
MINI_NVIM_URL := https://github.com/nvim-mini/mini.nvim
MINI_NVIM_COMMIT := 1345d191bb3da9c7b0e977f4387c5761f9bff68d
MINI_NVIM_DIR := $(ROOT)/deps/mini.nvim

NVIM_TEST := nvim --headless --noplugin -u '$(ROOT)/scripts/minimal_init.lua'

# Everything the suites' Neovims read or write as user state lives here, even
# when make's command line or MAKEFLAGS names another TEST_HOME.
override TEST_HOME := $(ROOT)/.tests

# The directory of the test runner's log file, which the recipes make before
# they start the runner: Neovim 0.12 does not make it, and a Neovim that
# cannot open its log file tells every Neovim it starts so, in a message the
# tests would read.
override TEST_LOG_DIRECTORY := $(TEST_HOME)/state/nvim

# Where the test runner makes, for each run, a directory of its own holding a
# home for each test file (scripts/run_tests.lua). A run starts with homes no
# earlier run used and removes them when it ends, so neither of the recipes
# clears anything: a run started while another runs, as the suite's own tests
# of these recipes start them, leaves the other's homes alone.
override TEST_HOMES := $(TEST_HOME)/homes

LUA_SOURCES := lua plugin scripts tests

.PHONY: deps test test_file lint format

# The test runner inherits these, and so never sees the developer's own
# configuration, data, state, cache, Neovim log or Claude Code settings; it
# gives each test file's Neovim a home of its own under $(TEST_HOMES) in their
# place. `override` keeps them even against the same names on make's command
# line; other targets see the caller's values, as before.
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME CLAUDE_CONFIG_DIR NVIM_LOG_FILE
test test_file: override XDG_CONFIG_HOME := $(TEST_HOME)/config
test test_file: override XDG_DATA_HOME := $(TEST_HOME)/data
test test_file: override XDG_STATE_HOME := $(TEST_HOME)/state
test test_file: override XDG_CACHE_HOME := $(TEST_HOME)/cache
test test_file: override CLAUDE_CONFIG_DIR := $(TEST_HOME)/claude
test test_file: override NVIM_LOG_FILE := $(TEST_LOG_DIRECTORY)/log

# A Neovim or Claude Code session that starts make hands these down: the parent
# editor's server address, application name, init file and init commands, the
# log file it could not open (which Neovim 0.12 would tell every Neovim of the
# run about), and a Claude Code marker. No target passes them on, whether they
# come from the environment, make's command line or MAKEFLAGS, so neither the
# test runner nor any Neovim it starts sees them. VIMRUNTIME is still passed
# on: a development build of Neovim needs it.
unexport NVIM NVIM_APPNAME MYVIMRC VIMINIT __NVIM_LOG_FILE_WANT AI_AGENT

# Fetches mini.nvim at MINI_NVIM_COMMIT into MINI_NVIM_DIR. Does nothing, and
# reaches for no remote, when that commit is already checked out there; a
# missing or foreign checkout reads as "not at the pin". Fails when the
# checkout's files differ from the commit, an edit left in deps/ included, and
# when git cannot read the checkout at all.
deps:
	@if [ "$$(git --git-dir='$(MINI_NVIM_DIR)/.git' rev-parse HEAD 2>/dev/null)" != '$(MINI_NVIM_COMMIT)' ]; then \
		mkdir -p '$(MINI_NVIM_DIR)' && \
		git -C '$(MINI_NVIM_DIR)' init --quiet && \
		git -C '$(MINI_NVIM_DIR)' fetch --quiet --depth 1 '$(MINI_NVIM_URL)' '$(MINI_NVIM_COMMIT)' && \
		git -C '$(MINI_NVIM_DIR)' -c advice.detachedHead=false checkout --quiet FETCH_HEAD; \
	fi
	@changes=$$(git --git-dir='$(MINI_NVIM_DIR)/.git' --work-tree='$(MINI_NVIM_DIR)' status --porcelain) && [ -z "$$changes" ] || { \
		echo '$(MINI_NVIM_DIR) differs from commit $(MINI_NVIM_COMMIT), or git cannot read it; remove it and run make deps' >&2; \
		exit 1; \
	}

# Runs each test file in a Neovim of its own, AINEO_TEST_JOBS=<number> of them
# at once (8 when it is absent), and prints one summary over all of them.
# Exits 0 only when every case ran and passed, and non-zero otherwise — also
# when a test file does not load or contributes no case, when test code ends
# Neovim, when mini.test stalls, when the run outlasts its time limit, which
# AINEO_TEST_RUN_LIMIT_MS=<milliseconds> replaces, and when either setting
# names no number above zero (scripts/run_tests.lua).
test: deps
	mkdir -p '$(TEST_LOG_DIRECTORY)'
	$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua' '$(TEST_HOMES)'

# FILE reaches the runner through the environment, so the shell reads it as one
# word and never as shell text, whatever quotes or spaces the path holds.
test_file: export AINEO_TEST_FILE = $(FILE)
test_file: deps
	mkdir -p '$(TEST_LOG_DIRECTORY)'
	$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua' '$(TEST_HOMES)' "$$AINEO_TEST_FILE"

lint:
	cd '$(ROOT)' && stylua --check $(LUA_SOURCES)
	cd '$(ROOT)' && selene $(LUA_SOURCES)

format:
	cd '$(ROOT)' && stylua $(LUA_SOURCES)
