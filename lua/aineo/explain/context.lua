--- The code around a line of a buffer that a request about tests is about:
--- the function or method that holds the line, else the class, read from
--- the buffer's treesitter tree when it has a parser, else from the
--- indentation of its lines.

local M = {}

--- The ends of the names of treesitter nodes that define something, such
--- as `function_definition` or `class_declaration`.
local DEFINING_ENDS = { '_definition$', '_declaration$', '_item$' }

--- Words in the name of a node that defines a function or a method.
local FUNCTION_WORDS = { 'function', 'method', 'constructor' }

--- Words in the name of a node that defines a class or the like.
local CLASS_WORDS = { 'class', 'struct', 'interface', 'impl', 'trait' }

--- Whether the treesitter node type `type` defines something named by one
--- of `words` (`DEFINING_ENDS`), or is an arrow function, for functions.
---
---@param type string
---@param words string[]
---@return boolean
local function defines(type, words)
  if words == FUNCTION_WORDS and type == 'arrow_function' then
    return true
  end
  local defining = vim.iter(DEFINING_ENDS):any(function(ending)
    return type:find(ending) ~= nil
  end)
  return defining
    and vim.iter(words):any(function(word)
      return type:find(word, 1, true) ~= nil
    end)
end

--- The lines, from 1, of the nearest node above `node`, itself included,
--- that defines something named by one of `words` (`defines()`), or `nil`.
---
---@param node TSNode
---@param words string[]
---@return integer[]|nil
local function enclosing_lines(node, words)
  local current = node
  while current do
    if defines(current:type(), words) then
      local first, _, last, last_column = current:range()
      if last_column == 0 and last > first then
        last = last - 1
      end
      return { first + 1, last + 1 }
    end
    current = current:parent()
  end
end

--- The lines, from 1, of the function or method that holds the line
--- `line` of `buffer`, else of the class, in the tree `parser` parses;
--- `nil` when nothing defines the line.
---
---@param parser vim.treesitter.LanguageTree
---@param buffer integer
---@param line integer
---@return integer[]|nil
local function from_the_tree(parser, buffer, line)
  parser:parse()
  local text = vim.api.nvim_buf_get_lines(buffer, line - 1, line, true)[1]
  local node = vim.treesitter.get_node({
    bufnr = buffer,
    pos = { line - 1, #text:match('^%s*') },
    ignore_injections = true,
  })
  if not node then
    return nil
  end
  return enclosing_lines(node, FUNCTION_WORDS) or enclosing_lines(node, CLASS_WORDS)
end

--- The words that start a definition, after any of `MODIFIERS`.
local DEFINING_WORDS = {
  def = true,
  class = true,
  func = true,
  fn = true,
  ['function'] = true,
  struct = true,
  interface = true,
  impl = true,
  trait = true,
}

--- The words that may stand before a defining word.
local MODIFIERS = {
  async = true,
  export = true,
  default = true,
  ['local'] = true,
  pub = true,
  public = true,
  private = true,
  protected = true,
  static = true,
  abstract = true,
  final = true,
}

--- The words a C-like line starts with that make it no definition, though
--- it reads as `words (…) {`.
local STATEMENTS = {
  ['if'] = true,
  ['for'] = true,
  ['while'] = true,
  switch = true,
  ['return'] = true,
  ['else'] = true,
  catch = true,
}

--- Whether `text`, a line, starts a definition: its first word past any
--- modifier is a defining word, or it reads as a C-like signature, a type
--- and a name and its parameters, opening a body or not, that starts with
--- no statement's word.
---
---@param text string
---@return boolean
local function starts_a_definition(text)
  for word in text:gmatch('[%a_]+') do
    if DEFINING_WORDS[word] then
      return true
    end
    if not MODIFIERS[word] then
      break
    end
  end
  local first = text:match('^%s*([%a_]+)')
  return first ~= nil
    and not STATEMENTS[first]
    and text:match('^%s*[%w_][%w_%s%*&:<>,]*[%s%*&][%w_:~]+%s*%(.*%)[%w%s]*{?%s*$') ~= nil
end

--- How far `text`, a line, is indented: the length of its leading white
--- space.
---
---@param text string
---@return integer
local function indent_of(text)
  return #text:match('^%s*')
end

--- Whether `text` holds white space alone.
---
---@param text string
---@return boolean
local function is_blank(text)
  return text:match('^%s*$') ~= nil
end

--- The line, from 1, of the definition that holds the line `line` of
--- `lines`: the line itself when it starts one (`starts_a_definition()`),
--- else the nearest above it that does and is indented less than every
--- line between, `line` included; `nil` when none is.
---
---@param lines string[]
---@param line integer
---@return integer|nil
local function definition_above(lines, line)
  local ceiling = is_blank(lines[line]) and math.huge or indent_of(lines[line])
  for index = line, 1, -1 do
    local text = lines[index]
    if not is_blank(text) then
      local indent = indent_of(text)
      if starts_a_definition(text) and (index == line or indent < ceiling) then
        return index
      end
      ceiling = math.min(ceiling, indent)
    end
  end
end

--- The last line, from 1, of the definition that starts on the line
--- `first` of `lines`: the last line after it indented more than it,
--- blank lines between counted, and then a line at its own indentation
--- that closes it with `}`, `]`, `)` or `end`.
---
---@param lines string[]
---@param first integer
---@return integer
local function definition_end(lines, first)
  local indent = indent_of(lines[first])
  local last = first
  for index = first + 1, #lines do
    local text = lines[index]
    if not is_blank(text) then
      if indent_of(text) > indent then
        last = index
      else
        if
          indent_of(text) == indent and (text:match('^%s*[%]})]') or text:match('^%s*end%f[%W]'))
        then
          last = index
        end
        break
      end
    end
  end
  return last
end

--- The lines, from 1, of the definition that holds the line `line` of
--- `buffer`, read from the indentation of its lines (`definition_above()`,
--- `definition_end()`); `nil` when none does.
---
---@param buffer integer
---@param line integer
---@return integer[]|nil
local function from_the_indentation(buffer, line)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local first = definition_above(lines, line)
  if not first then
    return nil
  end
  return { first, definition_end(lines, first) }
end

--- The first and last lines, from 1, of the code around the line `line`
--- of `buffer`: the function or method that holds it, else the class, in
--- the buffer's treesitter tree when it has a parser
--- (`from_the_tree()`), else as the indentation of its lines shows it
--- (`from_the_indentation()`); the line alone when neither finds one.
---
---@param buffer integer
---@param line integer
---@return integer[]
function M.around(buffer, line)
  local parser = vim.treesitter.get_parser(buffer, nil, { error = false })
  local found
  if parser then
    found = from_the_tree(parser, buffer, line)
  else
    found = from_the_indentation(buffer, line)
  end
  return found or { line, line }
end

return M
