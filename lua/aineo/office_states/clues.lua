--- The clue a tool call gives of what its agent looks for on the web: the
--- query of a search, the host of a fetched address. Pure.

local M = {}

--- The longest host, in bytes, that a name system allows.
local LONGEST_HOST = 253

--- The host of `address`: what stands between its scheme, if it has one, and
--- the first `/`, `?` or `#`, without the user and password before an `@` and
--- the port after a `:`; and only if that has the shape of a host: letters,
--- digits, dots, hyphens and the bytes of non-ASCII letters, or an IPv6
--- address in brackets, at most 253 bytes. Nothing else of the address is
--- kept: the path, the query and the credentials of an address can hold what
--- its owner would not show, and so can a string that is no address at all.
---
---@param address string
---@return string|nil host none when the address holds none
local function host_of(address)
  local authority = address:gsub('^%a[%w+.-]*://', ''):match('^[^/?#]*')
  local host = authority:gsub('^.*@', ''):gsub(':%d*$', '')
  local is_host = #host <= LONGEST_HOST
    and (host:find('^[%w.%-\128-\255]+$') or host:find('^%[[%x:.]+%]$'))
  return is_host and host or nil
end

---@type table<string, fun(input: table): string|nil>
local CLUE_OF_TOOL = {
  WebSearch = function(input)
    return type(input.query) == 'string' and input.query ~= '' and input.query or nil
  end,
  WebFetch = function(input)
    return type(input.url) == 'string' and host_of(input.url) or nil
  end,
}

--- The clue of the call of `tool` with `input`.
---
---@param tool string|nil
---@param input table
---@return string|nil clue none for a call that gives none
function M.of_call(tool, input)
  local clue_of = tool and CLUE_OF_TOOL[tool]
  return clue_of and clue_of(input)
end

return M
