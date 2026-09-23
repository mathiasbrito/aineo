# aineo's development tasks. Every path is taken from this file's own
# directory, so `make -f <checkout>/Makefile <target>` works from anywhere.
#
#   make deps                   fetch mini.nvim at its pinned commit
#   make test                   run every tests/**/test_*.lua under mini.test
#   make test_file FILE=<path>  run one test file
#   make lint                   check formatting (StyLua) and lint (selene)
#   make format                 format the Lua sources in place (StyLua)

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
# see the developer's own configuration, data, state, cache or Claude Code
# settings.
test test_file: export XDG_CONFIG_HOME := $(TEST_HOME)/config
test test_file: export XDG_DATA_HOME := $(TEST_HOME)/data
test test_file: export XDG_STATE_HOME := $(TEST_HOME)/state
test test_file: export XDG_CACHE_HOME := $(TEST_HOME)/cache
test test_file: export CLAUDE_CONFIG_DIR := $(TEST_HOME)/claude

# Fetches mini.nvim at MINI_NVIM_COMMIT into MINI_NVIM_DIR. Does nothing, and
# reaches for no remote, when that commit is already checked out there; a
# missing or foreign checkout reads as "not at the pin".
deps:
	@if [ "$$(git --git-dir='$(MINI_NVIM_DIR)/.git' rev-parse HEAD 2>/dev/null)" != '$(MINI_NVIM_COMMIT)' ]; then \
		mkdir -p '$(MINI_NVIM_DIR)' && \
		git -C '$(MINI_NVIM_DIR)' init --quiet && \
		git -C '$(MINI_NVIM_DIR)' fetch --quiet --depth 1 '$(MINI_NVIM_URL)' '$(MINI_NVIM_COMMIT)' && \
		git -C '$(MINI_NVIM_DIR)' -c advice.detachedHead=false checkout --quiet FETCH_HEAD; \
	fi

# Exits 0 when every case passed and non-zero otherwise — also when a test file
# does not load or no case is collected (scripts/run_tests.lua).
test: deps
	$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua'

test_file: deps
	$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua' '$(FILE)'

lint:
	cd '$(ROOT)' && stylua --check $(LUA_SOURCES)
	cd '$(ROOT)' && selene $(LUA_SOURCES)

format:
	cd '$(ROOT)' && stylua $(LUA_SOURCES)
