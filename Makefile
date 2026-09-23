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

# Everything the suites' Neovims read or write as user state lives here.
TEST_HOME := $(ROOT)/.tests

LUA_SOURCES := lua plugin scripts tests

.PHONY: deps test test_file lint format

# The test runner and every child Neovim it starts inherit these, and so never
# see the developer's own configuration, data, state, cache, Neovim log or
# Claude Code settings. `override` keeps them even against the same names on
# make's command line; other targets see the caller's values, as before.
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME CLAUDE_CONFIG_DIR NVIM_LOG_FILE
test test_file: override XDG_CONFIG_HOME := $(TEST_HOME)/config
test test_file: override XDG_DATA_HOME := $(TEST_HOME)/data
test test_file: override XDG_STATE_HOME := $(TEST_HOME)/state
test test_file: override XDG_CACHE_HOME := $(TEST_HOME)/cache
test test_file: override CLAUDE_CONFIG_DIR := $(TEST_HOME)/claude
test test_file: override NVIM_LOG_FILE := $(TEST_HOME)/state/nvim/log

# Fetches mini.nvim at MINI_NVIM_COMMIT into MINI_NVIM_DIR. Does nothing, and
# reaches for no remote, when that commit is already checked out there; a
# missing or foreign checkout reads as "not at the pin". Fails when the
# checkout's files differ from the commit, an edit left in deps/ included.
deps:
	@if [ "$$(git --git-dir='$(MINI_NVIM_DIR)/.git' rev-parse HEAD 2>/dev/null)" != '$(MINI_NVIM_COMMIT)' ]; then \
		mkdir -p '$(MINI_NVIM_DIR)' && \
		git -C '$(MINI_NVIM_DIR)' init --quiet && \
		git -C '$(MINI_NVIM_DIR)' fetch --quiet --depth 1 '$(MINI_NVIM_URL)' '$(MINI_NVIM_COMMIT)' && \
		git -C '$(MINI_NVIM_DIR)' -c advice.detachedHead=false checkout --quiet FETCH_HEAD; \
	fi
	@if [ -n "$$(git --git-dir='$(MINI_NVIM_DIR)/.git' --work-tree='$(MINI_NVIM_DIR)' status --porcelain)" ]; then \
		echo '$(MINI_NVIM_DIR) differs from commit $(MINI_NVIM_COMMIT); remove it and run make deps' >&2; \
		exit 1; \
	fi

# Exits 0 only when every case ran and passed, and non-zero otherwise — also
# when a test file does not load or contributes no case, when test code ends
# Neovim, or when mini.test stalls (scripts/run_tests.lua).
test: deps
	$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua'

# FILE reaches the runner through the environment, so the shell reads it as one
# word and never as shell text, whatever quotes or spaces the path holds.
test_file: export AINEO_TEST_FILE = $(FILE)
test_file: deps
	$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua' "$$AINEO_TEST_FILE"

lint:
	cd '$(ROOT)' && stylua --check $(LUA_SOURCES)
	cd '$(ROOT)' && selene $(LUA_SOURCES)

format:
	cd '$(ROOT)' && stylua $(LUA_SOURCES)
