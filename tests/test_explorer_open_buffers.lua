local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local open_buffers = require('aineo.explorer.open_buffers')

--- The buffers a case made, wiped after it.
local made

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      made = {}
    end,
    post_case = function()
      for _, buffer in ipairs(made) do
        pcall(vim.api.nvim_buf_delete, buffer, { force = true })
      end
    end,
  },
})

--- A loaded buffer named `name`, holding one line.
---
---@param name string
---@param buftype? string
---@return integer
local function loaded_buffer(name, buftype)
  local buffer = vim.api.nvim_create_buf(true, false)
  table.insert(made, buffer)
  vim.bo[buffer].buftype = buftype or ''
  vim.api.nvim_buf_set_name(buffer, name)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'text' })
  vim.bo[buffer].modified = false
  return buffer
end

--- Sets one diagnostic of each severity in `severities` on `buffer`.
---
---@param buffer integer
---@param severities integer[]
local function diagnose(buffer, severities)
  local diagnostics = vim.tbl_map(function(severity)
    return { lnum = 0, col = 0, message = 'm', severity = severity }
  end, severities)
  vim.diagnostic.set(vim.api.nvim_create_namespace('open-buffers-test'), buffer, diagnostics)
end

--- The path in the tree of a file under `/tree/`, nil for any other.
---
---@param file string
---@return string|nil
local function under_tree(file)
  return file:match('^/tree/(.*)$')
end

T['the loaded buffers'] = MiniTest.new_set()

T['the loaded buffers']['name the files with unsaved edits, by their path in the tree'] = function()
  local edited = loaded_buffer('/tree/src/a.lua')
  loaded_buffer('/tree/b.lua')
  vim.bo[edited].modified = true
  local clean = loaded_buffer('/tree/c.lua')
  vim.bo[clean].modified = false

  eq(open_buffers.read(under_tree).modified, { ['src/a.lua'] = true })
end

T['the loaded buffers']['count the errors and the warnings of a file, and leave out the other severities'] = function()
  local severity = vim.diagnostic.severity
  diagnose(
    loaded_buffer('/tree/a.lua'),
    { severity.ERROR, severity.ERROR, severity.WARN, severity.HINT }
  )
  diagnose(loaded_buffer('/tree/b.lua'), { severity.HINT, severity.INFO })

  eq(open_buffers.read(under_tree).diagnostics, { ['a.lua'] = { error = 2, warn = 1 } })
end

T['the loaded buffers']['leave out a file outside the tree, and one the tree turns into its root'] = function()
  vim.bo[loaded_buffer('/elsewhere/a.lua')].modified = true
  vim.bo[loaded_buffer('/tree/')].modified = true

  eq(open_buffers.read(under_tree).modified, {})
end

T['the loaded buffers']['leave out a buffer that is no file, however it is named'] = function()
  local scratch = loaded_buffer('/tree/scratch.lua', 'nofile')
  vim.bo[scratch].modified = true
  diagnose(scratch, { vim.diagnostic.severity.ERROR })

  local read = open_buffers.read(under_tree)

  eq(read.modified, {})
  eq(read.diagnostics, {})
end

T['the loaded buffers']['leave out a buffer that is no longer loaded, its diagnostics kept by the editor'] = function()
  local buffer = loaded_buffer('/tree/gone.lua')
  diagnose(buffer, { vim.diagnostic.severity.ERROR })
  vim.api.nvim_buf_delete(buffer, { unload = true })

  eq(open_buffers.read(under_tree).diagnostics, {})
end

return T
