--- The git commands aineo's hook reads as the creation of a worktree or a
--- branch, in the plain forms an agent writes them: pure functions of the
--- command's text.

local M = {}

--- What a command makes, as the hook reads it: a worktree, by the folder it
--- names, with the branch `-b` or `-B` gives it, or a branch, by its name;
--- each with the start point the command names and the folder `-C` names,
--- as the command spells them.
---@class aineo.claude.MadeWork
---@field kind 'worktree'|'branch'
---@field path? string the worktree's folder, with `kind` `worktree`
---@field branch? string the branch the command makes, by name
---@field start? string the commit the command makes the work from; the `HEAD` of the folder it runs in when nil
---@field directory? string the folder `-C` names, which the command runs in

--- The characters a word may hold outside quotes: none the shell expands,
--- joins, redirects or ends a command at.
local PLAIN_CHARACTER = '[%w%-%._/:@+=,%%^]'

--- The characters a word between double quotes may not hold: those the
--- shell still expands there.
local EXPANDED_IN_DOUBLE_QUOTES = '[%$`\\!]'

--- The words of `command` as a POSIX shell splits them, or nil when the
--- command holds anything a shell would read as more than plain words:
--- words are runs of `PLAIN_CHARACTER`, a `~` past a word's start — which
--- the shell expands at the start alone, as in `HEAD~2` — and quoted parts,
--- a part between
--- single quotes taken as it is, one between double quotes as it is when it
--- holds none of `EXPANDED_IN_DOUBLE_QUOTES`; blanks and tabs part them.
---
---@param command string
---@return string[]|nil
local function words_of(command)
  local words, word, position = {}, nil, 1
  while position <= #command do
    local character = command:sub(position, position)
    if character == ' ' or character == '\t' then
      if word then
        table.insert(words, word)
        word = nil
      end
      position = position + 1
    elseif character == "'" or character == '"' then
      local closing = command:find(character, position + 1, true)
      if not closing then
        return nil
      end
      local quoted = command:sub(position + 1, closing - 1)
      if character == '"' and quoted:find(EXPANDED_IN_DOUBLE_QUOTES) then
        return nil
      end
      word = (word or '') .. quoted
      position = closing + 1
    elseif character:match(PLAIN_CHARACTER) or (character == '~' and word ~= nil) then
      word = (word or '') .. character
      position = position + 1
    else
      return nil
    end
  end
  if word then
    table.insert(words, word)
  end
  return words
end

--- Whether `word` is a name a command may take as a value: given, and not
--- an option.
---
---@param word string|nil
---@return boolean
local function is_name(word)
  return word ~= nil and word ~= '' and not vim.startswith(word, '-')
end

--- The options a form takes: the flags it allows, which carry nothing, and
--- those that carry the branch the command makes, in the word after them.
---@class aineo.claude.FormOptions
---@field flags table<string, true>
---@field branch_options table<string, true>
---@field ends_options? boolean whether `--` ends the options

--- What `words`, the words of one git subcommand after its name, give under
--- `options`: the branch an option of `options.branch_options` names and the
--- words that are no option, in their order; nil for an option the form does
--- not take, or one that carries a value it is not given.
---
---@param words string[]
---@param options aineo.claude.FormOptions
---@return { branch: string|nil, positionals: string[] }|nil
local function read_options(words, options)
  local branch, positionals, index = nil, {}, 1
  local options_ended = false
  while index <= #words do
    local word = words[index]
    if options_ended or not vim.startswith(word, '-') then
      table.insert(positionals, word)
    elseif word == '--' and options.ends_options then
      options_ended = true
    elseif options.branch_options[word] then
      if branch or not is_name(words[index + 1]) then
        return nil
      end
      branch = words[index + 1]
      index = index + 1
    elseif not options.flags[word] then
      return nil
    end
    index = index + 1
  end
  return { branch = branch, positionals = positionals }
end

--- The options of `git worktree add` the hook reads.
local WORKTREE_ADD = {
  flags = {
    ['-f'] = true,
    ['--force'] = true,
    ['-q'] = true,
    ['--quiet'] = true,
    ['--detach'] = true,
  },
  branch_options = { ['-b'] = true, ['-B'] = true },
  ends_options = true,
}

--- The options of `git checkout` the hook reads, `-b` or `-B` among them.
local CHECKOUT = {
  flags = { ['-q'] = true, ['--quiet'] = true },
  branch_options = { ['-b'] = true, ['-B'] = true },
}

--- The options of `git switch` the hook reads, one that makes a branch
--- among them.
local SWITCH = {
  flags = { ['-q'] = true, ['--quiet'] = true },
  branch_options = { ['-c'] = true, ['-C'] = true, ['--create'] = true, ['--force-create'] = true },
}

--- The options of `git branch` the hook reads: none, as every one of them
--- does something else than make a branch.
local BRANCH = { flags = {}, branch_options = {} }

--- What a subcommand that makes a branch with an option — `checkout`,
--- `switch` — makes of `words` under `options`: the branch, and the start
--- point when one is named; nil without that option, or with more words.
---
---@param words string[]
---@param options aineo.claude.FormOptions
---@return aineo.claude.MadeWork|nil
local function branch_made_by_option(words, options)
  local read = read_options(words, options)
  if not (read and read.branch) or #read.positionals > 1 then
    return nil
  end
  return { kind = 'branch', branch = read.branch, start = read.positionals[1] }
end

--- What each subcommand the hook reads makes of the words after it.
---@type table<string, fun(words: string[]): aineo.claude.MadeWork|nil>
local SUBCOMMANDS = {
  worktree = function(words)
    if words[1] ~= 'add' then
      return nil
    end
    local read = read_options(vim.list_slice(words, 2), WORKTREE_ADD)
    if not read or #read.positionals < 1 or #read.positionals > 2 then
      return nil
    end
    return {
      kind = 'worktree',
      path = read.positionals[1],
      branch = read.branch,
      start = read.positionals[2],
    }
  end,
  checkout = function(words)
    return branch_made_by_option(words, CHECKOUT)
  end,
  switch = function(words)
    return branch_made_by_option(words, SWITCH)
  end,
  branch = function(words)
    local read = read_options(words, BRANCH)
    if not read or #read.positionals < 1 or #read.positionals > 2 then
      return nil
    end
    return { kind = 'branch', branch = read.positionals[1], start = read.positionals[2] }
  end,
}

--- What `command`, a shell command an agent ran, makes, as aineo's hook
--- reads it, or nil when it makes nothing the hook reads: one `git` command
--- of plain words (`words_of()`), `-C <folder>` before its subcommand and no
--- other option of git's own, and one of `git worktree add [-b|-B <branch>]
--- <path> [<commit>]`, `git checkout -b|-B <branch> [<start>]`, `git switch
--- -c|-C <branch> [<start>]` and `git branch <name> [<start>]`, each with
--- the few flags it allows. A command joined to another, redirected, or
--- holding anything the shell expands is read as none. The strings are the
--- command's own, never run.
---
---@param command string
---@return aineo.claude.MadeWork|nil
function M.work_of(command)
  local words = words_of(command)
  if not words or words[1] ~= 'git' then
    return nil
  end
  local index, directory = 2, nil
  while words[index] == '-C' do
    if not is_name(words[index + 1]) or directory then
      return nil
    end
    directory = words[index + 1]
    index = index + 2
  end
  local read = SUBCOMMANDS[words[index] or '']
  local work = read and read(vim.list_slice(words, index + 1))
  if work then
    work.directory = directory
  end
  return work
end

return M
