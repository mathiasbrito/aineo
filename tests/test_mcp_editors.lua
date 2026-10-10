local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- A Neovim listening on an address a test lists as a running editor.
local live = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = live.stop } })

--- Session ids of the form Claude Code gives.
local SESSION_ID = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'
local OTHER_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- An address no Neovim listens on: a socket path under `state`.
---
---@param state string
---@return string
local function dead_address(state)
  return vim.fs.joinpath(state, 'gone.sock')
end

--- The entry of the editor at `address` that a test writes, following
--- `session` as its own terminal's, last used at `used` microseconds.
---
---@param address string
---@param session string
---@param used integer
---@return table
local function entry_of(address, session, used)
  return {
    address = address,
    working_directory = '/projects/alpha',
    session = session,
    own = true,
    used = used,
  }
end

--- The entry of the editor at `address` that follows `session` by a claim
--- of it, not as its own terminal's (`entry_of()`).
---
---@param address string
---@param session string
---@param used integer
---@return table
local function claimed_entry_of(address, session, used)
  return vim.tbl_extend('force', entry_of(address, session, used), { own = false })
end

--- The file the list keeps for the editor at `address` under `state`.
---
---@param state string
---@param address string
---@return string
local function entry_file(state, address)
  return vim.fs.joinpath(state, 'aineo', 'editors', vim.fn.sha256(address) .. '.json')
end

--- Writes `entry` into the list under `state` as an editor listening at its
--- address left it, without the pruning an editor's own write makes.
---
---@param state string
---@param entry table
local function plant_entry(state, entry)
  local file = entry_file(state, entry.address)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  assert(vim.fn.writefile({ vim.json.encode(entry) }, file) == 0, 'cannot write ' .. file)
end

--- The file that names the claimant of `session` under `state`.
---
---@param state string
---@param session string
---@return string
local function claim_file(state, session)
  return vim.fs.joinpath(state, 'aineo', 'claims', vim.fn.sha256(session) .. '.json')
end

--- The JSON the file at `path` holds, decoded, or nil when there is none.
---
---@param path string
---@return table?
local function decoded_file(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return vim.json.decode(text)
end

--- The permission bits of the file or folder at `path`, as octal digits.
---
---@param path string
---@return string
local function mode_of(path)
  return ('%o'):format(vim.uv.fs_stat(path).mode % 512)
end

T['an editor entry'] = MiniTest.new_set()

T['an editor entry']['is a file only the user can read, named by its address’s SHA-256, in a folder only the user can enter'] = function()
  local state = fixture.directory('mcp-editors-entry')
  local address = vim.v.servername

  mcp.write_editor_entry(state, entry_of(address, SESSION_ID, 1000))

  local file = entry_file(state, address)
  eq({
    entry = decoded_file(file),
    file_mode = mode_of(file),
    folder_mode = mode_of(vim.fs.dirname(file)),
  }, {
    entry = entry_of(address, SESSION_ID, 1000),
    file_mode = '600',
    folder_mode = '700',
  })
end

T['an editor entry']['written removes the entries whose address cannot be reached, and leaves one that answers'] = function()
  local state = fixture.directory('mcp-editors-prune')
  children.restart(live)
  local gone = dead_address(state)
  mcp.write_editor_entry(state, entry_of(gone, SESSION_ID, 1000))
  mcp.write_editor_entry(state, entry_of(live.v.servername, SESSION_ID, 2000))

  mcp.write_editor_entry(state, entry_of(vim.v.servername, OTHER_SESSION_ID, 3000))

  eq({
    gone = decoded_file(entry_file(state, gone)),
    live = decoded_file(entry_file(state, live.v.servername)) ~= nil,
  }, { live = true })
end

T['an editor entry']['removed is gone from the list, the others kept'] = function()
  local state = fixture.directory('mcp-editors-remove')
  mcp.write_editor_entry(state, entry_of('127.0.0.1:9', SESSION_ID, 1000))
  mcp.write_editor_entry(state, entry_of(vim.v.servername, SESSION_ID, 2000))

  mcp.remove_editor_entry(state, vim.v.servername)

  eq({
    removed = decoded_file(entry_file(state, vim.v.servername)),
    kept = decoded_file(entry_file(state, '127.0.0.1:9')) ~= nil,
  }, { kept = true })
end

T['a claim'] = MiniTest.new_set()

T['a claim']['names the newest claimant alone, in a file only the user can read'] = function()
  local state = fixture.directory('mcp-editors-claim')
  mcp.claim_session(state, SESSION_ID, '/run/first.sock', 1000)

  mcp.claim_session(state, SESSION_ID, vim.v.servername, 2000)

  local file = claim_file(state, SESSION_ID)
  eq({
    claim = decoded_file(file),
    file_mode = mode_of(file),
    folder_mode = mode_of(vim.fs.dirname(file)),
  }, {
    claim = { address = vim.v.servername, claimed = 2000 },
    file_mode = '600',
    folder_mode = '700',
  })
end

T['a claim']['names its claimant to whoever asks, and no one for a session unclaimed'] = function()
  local state = fixture.directory('mcp-editors-claimant')
  mcp.claim_session(state, SESSION_ID, vim.v.servername, 1000)

  eq(
    { mcp.session_claimant(state, SESSION_ID), mcp.session_claimant(state, OTHER_SESSION_ID) },
    { vim.v.servername, nil }
  )
end

T['a claim']['is let go by its claimant alone'] = function()
  local state = fixture.directory('mcp-editors-release')
  mcp.claim_session(state, SESSION_ID, vim.v.servername, 1000)
  mcp.claim_session(state, OTHER_SESSION_ID, vim.v.servername, 1000)

  mcp.release_claim(state, SESSION_ID, '/run/other.sock')
  mcp.release_claim(state, OTHER_SESSION_ID, vim.v.servername)

  eq({
    kept = decoded_file(claim_file(state, SESSION_ID)),
    let_go = decoded_file(claim_file(state, OTHER_SESSION_ID)),
  }, { kept = { address = vim.v.servername, claimed = 1000 } })
end

T['a claim']['whose claimant cannot be reached is removed at an entry’s write'] = function()
  local state = fixture.directory('mcp-editors-claim-prune')
  mcp.claim_session(state, SESSION_ID, dead_address(state), 1000)

  mcp.write_editor_entry(state, entry_of(vim.v.servername, OTHER_SESSION_ID, 3000))

  eq(decoded_file(claim_file(state, SESSION_ID)), nil)
end

T['a switch'] = MiniTest.new_set()

T['a switch']['is told to the claimant of the session left and to each editor that follows it by a claim, but the one excluded'] = function()
  local state = fixture.directory('mcp-editors-followers')
  local by_claim = vim.fs.joinpath(state, 'by-claim.sock')
  local own = vim.fs.joinpath(state, 'own.sock')
  local other = vim.fs.joinpath(state, 'other.sock')
  local claimant = vim.fs.joinpath(state, 'claimant.sock')
  local excluded = vim.fs.joinpath(state, 'excluded.sock')
  local tcp = '127.0.0.1:9'
  plant_entry(state, claimed_entry_of(by_claim, SESSION_ID, 1))
  plant_entry(state, entry_of(own, SESSION_ID, 2))
  plant_entry(state, claimed_entry_of(other, OTHER_SESSION_ID, 3))
  plant_entry(state, claimed_entry_of(excluded, SESSION_ID, 4))
  plant_entry(state, claimed_entry_of(tcp, SESSION_ID, 5))
  mcp.claim_session(state, SESSION_ID, claimant, 6)

  local followers = mcp.switch_followers(state, SESSION_ID, excluded)

  table.sort(followers)
  eq(followers, { by_claim, claimant })
end

T['a switch']['told to an editor reaches the handler registered there, from a scheduled callback'] = function()
  children.restart(live)
  live.lua([[
    _G.told = {}
    require('aineo.mcp').on_followed_switch(function(left, new)
      table.insert(_G.told, { left, new, vim.in_fast_event() })
    end)
  ]])

  local in_the_call = live.lua(
    "require('aineo.mcp').receive_followed_switch(...); return #_G.told",
    { SESSION_ID, OTHER_SESSION_ID }
  )

  eq({ in_the_call, live.lua_get('_G.told') }, { 0, { { SESSION_ID, OTHER_SESSION_ID, false } } })
end

T['an editor entry']['written leaves an entry listening on host:port, which is never tried'] = function()
  local state = fixture.directory('mcp-editors-tcp')
  local tcp = '127.0.0.1:9'
  mcp.write_editor_entry(state, entry_of(tcp, SESSION_ID, 1000))

  mcp.write_editor_entry(state, entry_of(vim.v.servername, OTHER_SESSION_ID, 3000))

  eq(decoded_file(entry_file(state, tcp)), entry_of(tcp, SESSION_ID, 1000))
end

return T
