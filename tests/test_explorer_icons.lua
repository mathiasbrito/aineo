local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local icons = require('aineo.explorer.icons')

--- The modules and globals a case may fake, as they were before it.
local FAKED_MODULES = { 'mini.icons', 'nvim-web-devicons' }

local saved

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      saved = { global = MiniIcons, loaded = {}, preload = {} }
      for _, name in ipairs(FAKED_MODULES) do
        saved.loaded[name] = package.loaded[name]
        saved.preload[name] = package.preload[name]
        package.loaded[name] = nil
        package.preload[name] = nil
      end
      MiniIcons = nil
    end,
    post_case = function()
      MiniIcons = saved.global
      for _, name in ipairs(FAKED_MODULES) do
        package.loaded[name] = saved.loaded[name]
        package.preload[name] = saved.preload[name]
      end
    end,
  },
})

--- A fake `mini.icons` whose `get(category, name)` gives `icon` and `group`
--- for a file and records what it was asked.
---
---@param asked table[] receives `{ category, name }` of each call
---@return table
local function fake_mini_icons(asked)
  return {
    get = function(category, name)
      table.insert(asked, { category, name })
      return '󰢱', 'MiniIconsAzure', false
    end,
  }
end

--- A fake `nvim-web-devicons` whose `get_icon(name, extension, options)`
--- gives `icon` and `group`, and records what it was asked.
---
---@param asked table[] receives `{ name, extension, options }` of each call
---@return table
local function fake_devicons(asked)
  return {
    get_icon = function(name, extension, options)
      table.insert(asked, { name, extension, options })
      return 'λ', 'DevIconLua'
    end,
  }
end

T['the icons of a plugin'] = MiniTest.new_set()

local FILE = { path = 'src/main.lua', name = 'main.lua', kind = 'file' }

T['the icons of a plugin']['come from mini.icons when it loads and was set up'] = function()
  local asked = {}
  local fake = fake_mini_icons(asked)
  package.preload['mini.icons'] = function()
    return fake
  end
  MiniIcons = fake

  local icon = icons.from_plugins()(FILE)

  eq(icon, { text = '󰢱', group = 'MiniIconsAzure' })
  eq(asked, { { 'file', 'main.lua' } })
end

T['the icons of a plugin']['skip mini.icons when it was not set up, and take nvim-web-devicons'] = function()
  local mini_asked, devicons_asked = {}, {}
  local mini = fake_mini_icons(mini_asked)
  local devicons = fake_devicons(devicons_asked)
  package.preload['mini.icons'] = function()
    return mini
  end
  package.preload['nvim-web-devicons'] = function()
    return devicons
  end

  local icon = icons.from_plugins()(FILE)

  eq(icon, { text = 'λ', group = 'DevIconLua' })
  eq(mini_asked, {})
  eq(devicons_asked, { { 'main.lua', 'lua', { default = true } } })
end

T['the icons of a plugin']['prefer mini.icons to nvim-web-devicons'] = function()
  local mini_asked, devicons_asked = {}, {}
  local mini = fake_mini_icons(mini_asked)
  local devicons = fake_devicons(devicons_asked)
  package.preload['mini.icons'] = function()
    return mini
  end
  package.preload['nvim-web-devicons'] = function()
    return devicons
  end
  MiniIcons = mini

  icons.from_plugins()(FILE)

  eq(#mini_asked, 1)
  eq(devicons_asked, {})
end

T['the icons of a plugin']['are none when neither plugin loads'] = function()
  package.preload['nvim-web-devicons'] = function()
    error('no such plugin')
  end

  eq(icons.from_plugins(), nil)
end

T['the icons of a plugin']['are none for a file when the plugin raises'] = function()
  package.preload['nvim-web-devicons'] = function()
    return {
      get_icon = function()
        error('broken plugin')
      end,
    }
  end

  eq(icons.from_plugins()(FILE), nil)
end

T['the icons of a plugin']['are none for a file the plugin knows none for'] = function()
  package.preload['nvim-web-devicons'] = function()
    return {
      get_icon = function()
        return nil
      end,
    }
  end

  eq(icons.from_plugins()(FILE), nil)
end

T['the icons looked up'] = MiniTest.new_set()

T['the icons looked up']['ask the plugin once for a path, whatever the times asked'] = function()
  local asked = {}
  local lookup = icons.once_per_path(function(entry)
    table.insert(asked, entry.path)
    return { text = 'x', group = 'G' }
  end)

  lookup(FILE)
  lookup(FILE)
  lookup({ path = 'other.lua', name = 'other.lua', kind = 'file' })

  eq(asked, { 'src/main.lua', 'other.lua' })
end

T['the icons looked up']['remember that a path has none'] = function()
  local asked = 0
  local lookup = icons.once_per_path(function()
    asked = asked + 1
    return nil
  end)

  lookup(FILE)
  lookup(FILE)

  eq(asked, 1)
end

return T
