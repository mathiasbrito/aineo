--- The rules of a test layout as they are stated — by the agent, by a
--- preset, by the user's correction — turned into the rules finding uses.

local M = {}

--- A rule as stated: either a rule of its own, or a preset named by its
--- id, with its kind or its `create` overridden.
---@class aineo.test_layout.Statement
---@field preset? string the id of a preset, for a statement that names one
---@field source? string
---@field test? string|string[] one test template, or the alternatives, the first used to create
---@field inline? boolean
---@field folder? string
---@field kind? string
---@field create? boolean
---@field discover? string[]
---@field framework? string
---@field companions? string[]

--- A preset: a known layout of tests, with what marks a repository that
--- follows it.
---@class aineo.test_layout.Preset
---@field id string such as `python.pytest.flat`
---@field framework string
---@field doc string the documentation of the layout
---@field extensions string[] the extensions of the sources it is for
---@field markers (string|{ file: string, holds: string })[] globs of the files whose presence marks it, or a file and a text it holds
---@field discover string[] the framework's discovery globs, relative to the unit root
---@field rules aineo.test_layout.Statement[]
---@field companions? string[]
---@field convention? boolean whether no documentation states the layout, which is a common convention

--- The rule `statement`, a rule of its own, states, with `origin` and
--- `description`; the fields of `defaults` fill those it does not give.
---
---@param statement aineo.test_layout.Statement
---@param origin 'user'|'agent'|'repository'|'preset'
---@param description string
---@param defaults? { discover?: string[], framework?: string, companions?: string[], extensions?: string[] }
---@return aineo.test_layout.Rule
function M.of_statement(statement, origin, description, defaults)
  defaults = defaults or {}
  local tests = statement.test
  if type(tests) == 'string' then
    tests = { tests }
  end
  return {
    source = statement.source,
    tests = tests,
    inline = statement.inline,
    folder = statement.folder,
    kind = statement.kind,
    create = statement.create,
    discover = statement.discover or defaults.discover,
    framework = statement.framework or defaults.framework,
    companions = statement.companions or defaults.companions,
    extensions = defaults.extensions,
    origin = origin,
    description = description,
  }
end

--- The rules of `preset`, in its order, each described by `description`
--- (the preset's id when not given) and with `origin`, `overrides` — a
--- kind, a `create` — given to each.
---
---@param preset aineo.test_layout.Preset
---@param origin 'user'|'agent'|'repository'|'preset'
---@param description? string
---@param overrides? { kind?: string, create?: boolean }
---@return aineo.test_layout.Rule[]
function M.of_preset(preset, origin, description, overrides)
  return vim.tbl_map(function(statement)
    local rule = M.of_statement(statement, origin, description or preset.id, {
      discover = preset.discover,
      framework = preset.framework,
      companions = preset.companions,
      extensions = preset.extensions,
    })
    return vim.tbl_extend('force', rule, overrides or {})
  end, preset.rules)
end

return M
