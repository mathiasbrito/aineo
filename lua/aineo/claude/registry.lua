--- Claude Code's own registry of the processes it runs: one file per process
--- under its configuration directory, `sessions/<pid>.json` (Claude Code
--- 2.1.310). Of each, the fields `sessionId`, `pid` and `procStart` are
--- read, and nothing else; the files beside them are never opened.

local M = {}

--- The entries of the registry under `config_directory`, decoded; a file
--- that cannot be read or decoded is passed over.
---
---@param config_directory string
---@return table[]
local function registered(config_directory)
  local folder = vim.fs.joinpath(config_directory, 'sessions')
  local entries = {}
  for name, kind in vim.fs.dir(folder) do
    if kind == 'file' and name:match('^%d+%.json$') then
      local read, lines = pcall(vim.fn.readfile, vim.fs.joinpath(folder, name))
      local decoded, entry = pcall(vim.json.decode, read and table.concat(lines, '\n') or '')
      if decoded and type(entry) == 'table' then
        table.insert(entries, entry)
      end
    end
  end
  return entries
end

--- `text` with every run of blanks one space, and none at either end; nil
--- for anything that is not a string.
---
---@param text any
---@return string?
local function squeezed(text)
  if type(text) == 'string' then
    return vim.trim((text:gsub('%s+', ' ')))
  end
end

--- How long the editor waits for `ps` to print a process's start.
local PS_PATIENCE_MS = 2000

--- When the process `pid` started, as `ps -o lstart=` prints it in UTC: the
--- form Claude Code writes in `procStart`; `''` when `ps` prints none, and
--- nil when `ps` cannot be run or does not answer within `PS_PATIENCE_MS`.
---
---@param pid integer
---@return string?
local function process_start(pid)
  local started, ps = pcall(vim.system, { 'ps', '-p', tostring(pid), '-o', 'lstart=' }, {
    env = { TZ = 'UTC' },
    text = true,
  })
  return started and squeezed(ps:wait(PS_PATIENCE_MS).stdout) or nil
end

--- Whether the process `entry` names runs: a process of its `pid`, a number
--- (nothing else becomes an argument of `ps`), started when its `procStart`
--- says, so that a pid another process took since is not taken for it, and
--- one that has ended, which `ps` prints nothing for, is not either.
---
---@param entry table
---@return boolean
local function runs(entry)
  return type(entry.pid) == 'number' and process_start(entry.pid) == squeezed(entry.procStart)
end

--- Whether the registry under `config_directory` names a process that runs
--- on `session` (`runs()`).
---
---@param config_directory string
---@param session string
---@return boolean
function M.is_registered(config_directory, session)
  return vim.iter(registered(config_directory)):any(function(entry)
    return entry.sessionId == session and runs(entry)
  end)
end

return M
