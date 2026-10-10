--- The running aineo editors and the claims of sessions, kept under the state
--- directory: one file per editor that follows a Claude session, named by
--- its address's SHA-256, in `aineo/editors/`, and one file per claimed
--- session, named by the session id's SHA-256, in `aineo/claims/`.

local kept_files = require('aineo.mcp.kept_files')

local M = {}

--- What the list keeps of a running editor: its server address, the
--- directory it started in, the Claude session its panes follow, whether
--- that is its own terminal's session (`own`) or one it claimed by its id,
--- and when it was last used, in microseconds of the wall clock.
---@class aineo.mcp.EditorEntry
---@field address string
---@field working_directory string
---@field session string
---@field own boolean
---@field used integer

--- The folder of the list of running editors under `state_directory`.
---
---@param state_directory string
---@return string
local function editors_folder(state_directory)
  return vim.fs.joinpath(state_directory, 'aineo', 'editors')
end

--- The file the list keeps for the editor at `address`.
---
---@param state_directory string
---@param address string
---@return string
local function entry_file(state_directory, address)
  return vim.fs.joinpath(editors_folder(state_directory), vim.fn.sha256(address) .. '.json')
end

--- An entry as the list holds it: the entry, its file's name, and the text
--- it was read from.
---@alias aineo.mcp.ListedEntry { entry: aineo.mcp.EditorEntry, name: string, text: string }

--- Whether `entry`, decoded from an entry's file, is an entry.
---
---@param entry any
---@return boolean
local function is_entry(entry)
  return type(entry) == 'table'
    and type(entry.address) == 'string'
    and type(entry.session) == 'string'
    and type(entry.used) == 'number'
end

--- Every entry of the list, in the order of its files' names; a file that
--- holds no entry is left out.
---
---@param state_directory string
---@return aineo.mcp.ListedEntry[]
function M.read_entries(state_directory)
  local folder = editors_folder(state_directory)
  local listed = {}
  for _, name in ipairs(kept_files.file_names(folder, '.json')) do
    local text = kept_files.read_file(vim.fs.joinpath(folder, name))
    local read, entry = pcall(vim.json.decode, text or '')
    if read and is_entry(entry) then
      table.insert(listed, { entry = entry, name = name, text = text })
    end
  end
  return listed
end

--- Removes `listed`, an entry `M.read_entries()` read, if its file still
--- holds what was read then.
---
---@param state_directory string
---@param listed aineo.mcp.ListedEntry
function M.remove_listed(state_directory, listed)
  kept_files.remove_if_unchanged(
    vim.fs.joinpath(editors_folder(state_directory), listed.name),
    listed.text
  )
end

--- Removes the list's entry of the editor at `address`.
---
---@param state_directory string
---@param address string
function M.remove_entry(state_directory, address)
  vim.uv.fs_unlink(entry_file(state_directory, address))
end

--- The folder of the claims under `state_directory`.
---
---@param state_directory string
---@return string
local function claims_folder(state_directory)
  return vim.fs.joinpath(state_directory, 'aineo', 'claims')
end

--- The file that names the claimant of `session`.
---
---@param state_directory string
---@param session string
---@return string
local function claim_file(state_directory, session)
  return vim.fs.joinpath(claims_folder(state_directory), vim.fn.sha256(session) .. '.json')
end

--- Makes the editor at `address` the claimant of `session`, claimed at
--- `claimed` microseconds of the wall clock: the session's claim file names
--- it alone, in place of any claimant before.
---
--- Raises an error naming the file when it cannot be written.
---
---@param state_directory string
---@param session string
---@param address string
---@param claimed integer
function M.claim(state_directory, session, address, claimed)
  kept_files.make_private_folder(claims_folder(state_directory))
  kept_files.replace_file(
    claim_file(state_directory, session),
    vim.json.encode({ address = address, claimed = claimed })
  )
end

--- The claim kept for `session`, and the text of its file as it was read; nil
--- when there is none, or its file holds no claim.
---
---@param state_directory string
---@param session string
---@return { address: string, claimed: integer }? claim
---@return string? text
function M.read_claim(state_directory, session)
  local text = kept_files.read_file(claim_file(state_directory, session))
  local read, claim = pcall(vim.json.decode, text or '')
  if read and type(claim) == 'table' and type(claim.address) == 'string' then
    return claim, text
  end
end

--- Removes the claim of `session` if it still names the editor at `address`.
---
---@param state_directory string
---@param session string
---@param address string
function M.release(state_directory, session, address)
  local claim, text = M.read_claim(state_directory, session)
  if claim and claim.address == address then
    kept_files.remove_if_unchanged(claim_file(state_directory, session), text)
  end
end

--- Whether `address` names an editor that a report may be offered to, or a
--- switch told: a local socket the user owns. An address of the form
--- `host:port` is not, nor a socket another user owns; a socket path where
--- nothing is any more is, and cannot be reached.
---
---@param address string
---@return boolean
function M.may_be_tried(address)
  if address:match('^[^/]+:%d+$') then
    return false
  end
  local socket = vim.uv.fs_stat(address)
  return socket == nil or socket.uid == vim.uv.getuid()
end

--- The addresses of the editors to tell that Claude Code switched from the
--- session `left`: the claimant of `left`, and each editor that follows
--- `left` by a claim of it rather than as its own terminal's session; each
--- once, and only where it may be tried (`M.may_be_tried()`), but
--- `excluded`, the editor that started that Claude Code, which follows the
--- switch through its own hooks.
---
---@param state_directory string
---@param left string
---@param excluded string?
---@return string[]
function M.switch_followers(state_directory, left, excluded)
  local addresses = {}
  local claim = M.read_claim(state_directory, left)
  if claim then
    addresses[claim.address] = true
  end
  for _, listed in ipairs(M.read_entries(state_directory)) do
    if listed.entry.session == left and listed.entry.own == false then
      addresses[listed.entry.address] = true
    end
  end
  return vim.tbl_filter(function(address)
    return address ~= excluded and M.may_be_tried(address)
  end, vim.tbl_keys(addresses))
end

--- Whether an editor listens at `address`, a local socket: a connection to
--- it is made, and closed again at once.
---
---@param address string
---@return boolean
local function answers(address)
  local connected, channel = pcall(vim.fn.sockconnect, 'pipe', address, { rpc = true })
  if connected then
    vim.fn.chanclose(channel)
  end
  return connected
end

--- Removes each file in `folder` whose `address` field names an editor that
--- may be tried (`M.may_be_tried()`) but cannot be reached (`answers()`),
--- if it still holds what was read, but the one of `own_address`.
---
---@param folder string
---@param own_address string
local function prune_folder(folder, own_address)
  for _, name in ipairs(kept_files.file_names(folder, '.json')) do
    local path = vim.fs.joinpath(folder, name)
    local text = kept_files.read_file(path)
    local read, kept = pcall(vim.json.decode, text or '')
    local address = read and type(kept) == 'table' and kept.address
    if
      type(address) == 'string'
      and address ~= own_address
      and M.may_be_tried(address)
      and not answers(address)
    then
      kept_files.remove_if_unchanged(path, text)
    end
  end
end

--- Writes `entry` as the list's entry of its editor, in place of the one
--- before, then removes every other entry, and every claim, whose editor
--- cannot be reached (`prune_folder()`).
---
--- Raises an error naming the file when it cannot be written.
---
---@param state_directory string
---@param entry aineo.mcp.EditorEntry
function M.write_entry(state_directory, entry)
  kept_files.make_private_folder(editors_folder(state_directory))
  kept_files.replace_file(entry_file(state_directory, entry.address), vim.json.encode(entry))
  prune_folder(editors_folder(state_directory), entry.address)
  prune_folder(claims_folder(state_directory), entry.address)
end

return M
