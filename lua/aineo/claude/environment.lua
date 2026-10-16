--- The environment Claude Code's process gets: the one a terminal job of
--- Neovim gets, plus the variable that marks the process as aineo's child,
--- and, unless the user keeps them, without the variables that tell Claude
--- Code it runs inside a terminal multiplexer.

local M = {}

--- The variables Claude Code 2.1.301 reads to find that it runs inside a
--- terminal multiplexer, read from its program: `TMUX` (with `TMUX_PANE`, the
--- pane it names), `STY` for screen and `ZELLIJ`. Under one of them it keeps
--- its terminal title still, which the activity indicator of a tab reads.
local MULTIPLEXER_VARIABLES = { 'TMUX', 'TMUX_PANE', 'STY', 'ZELLIJ' }

--- The variables Neovim 0.12.5 removes from the environment of a job it
--- starts, as measured on a terminal job (`:help jobstart-env` lists
--- `NVIM_LISTEN_ADDRESS`, `NVIM_LOG_FILE`, `VIM` and `VIMRUNTIME`; a job
--- started there kept `NVIM_LOG_FILE`).
local VARIABLES_NEOVIM_REMOVES = { 'NVIM_LISTEN_ADDRESS', 'VIM', 'VIMRUNTIME' }

--- The terminal type Neovim 0.12.5 gives the terminal job it starts as `TERM`.
local TERMINAL_JOB_TERM = 'xterm-256color'

--- The variable that tells aineo, should Claude Code start a Neovim, that it
--- runs inside aineo's own session.
local CHILD_MARKER = { AINEO_CHILD = '1' }

--- What the editor holds that a job's environment is made from.
---@class aineo.claude.EditorEnvironment
---@field variables table<string, string> the editor's environment (`vim.fn.environ()`)
---@field has_true_colour boolean whether the editor draws true colour ('termguicolors'), in which case a terminal job gets `COLORTERM=truecolor`

--- The environment a terminal job of Neovim 0.12.5 gets from `editor`, as
--- Neovim makes it when it merges `env` into the editor's environment:
--- `TERM` is `xterm-256color`, `COLORTERM` is `truecolor` with true colour
--- and absent without it, and `VIM`, `VIMRUNTIME` and `NVIM_LISTEN_ADDRESS`
--- are absent. `NVIM`, the editor's server address, is left out: Neovim sets
--- it itself in a job whose environment `clear_env` defines, as in any other.
---
---@param editor aineo.claude.EditorEnvironment
---@return table<string, string>
local function terminal_job_environment(editor)
  local environment = vim.deepcopy(editor.variables)
  for _, variable in ipairs(VARIABLES_NEOVIM_REMOVES) do
    environment[variable] = nil
  end
  environment.NVIM = nil
  environment.TERM = TERMINAL_JOB_TERM
  environment.COLORTERM = editor.has_true_colour and 'truecolor' or nil
  return environment
end

--- The `jobstart()` options that give Claude Code's process its environment.
--- Without `hide_multiplexer` the process gets the environment of a terminal
--- job and `AINEO_CHILD`, as `jobstart()` makes it. With it the process gets
--- the same environment without the multiplexer variables: `jobstart()`
--- merges `env` into the editor's environment and cannot unset a variable, so
--- `clear_env` has `env` define the whole environment, which
--- `terminal_job_environment()` then makes as `jobstart()` would.
---
---@param editor aineo.claude.EditorEnvironment
---@param hide_multiplexer boolean whether the process is told nothing of a terminal multiplexer
---@return { env: table<string, string>, clear_env: boolean }
function M.job_environment(editor, hide_multiplexer)
  if not hide_multiplexer then
    return { env = CHILD_MARKER, clear_env = false }
  end
  local environment = terminal_job_environment(editor)
  for _, variable in ipairs(MULTIPLEXER_VARIABLES) do
    environment[variable] = nil
  end
  return { env = vim.tbl_extend('force', environment, CHILD_MARKER), clear_env = true }
end

return M
