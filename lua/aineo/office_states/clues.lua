--- The clue a tool call gives of what its agent looks for on the web: the
--- query of a search, the host of a fetched address. Pure.

local M = {}

--- The host of `address`: what stands between its scheme, if it has one, and
--- the first `/`, `?` or `#`, without the user and password before an `@` and
--- the port after a `:`. Nothing else of the address is kept: the path and
--- the query of an address can hold what its owner would not show.
---
---@param address string
---@return string|nil host none when the address holds none
local function host_of(address)
  local authority = address:gsub('^%a[%w+.-]*://', ''):match('^[^/?#]*')
  local host = authority:gsub('^.*@', ''):gsub(':%d*$', '')
  return host ~= '' and host or nil
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
