--- A stand-in for a startup dashboard, a plugin the entry suites put on an
--- editor's 'runtimepath' after aineo, so that its autocommands follow
--- aineo's. At a bare start it makes the buffer the editor starts with a
--- dashboard's, as `vim.g.entry_dashboard` describes, set before startup:
---
--- - `filetype` — the dashboard's filetype;
--- - `moment` — when it shows: `VimEnter`, `UIEnter`, or `scheduled`, from a
---   `vim.schedule()` callback scheduled at `VimEnter`;
--- - `autocommands` — whether showing it runs autocommands; without them it
---   shows under `eventignore=all`;
--- - `options` — the buffer's other options, set as the dashboard sets them;
--- - `drawn` — whether it draws into the buffer, which it then leaves not
---   modifiable and not modified.
---
--- Modelled on the dashboards' own sources, read at these versions:
--- snacks.nvim v2.31.0 (`lua/snacks/dashboard.lua`, `M.setup()`, run at
--- `UIEnter`) shows its dashboard in the first buffer with `eventignore` set
--- to `all`; alpha-nvim 4ba26e4 (`lua/alpha.lua`, `alpha.start()`) at
--- `VimEnter`, in the current buffer, under `eventignore=all` when its
--- `noautocmd` option is set; dashboard-nvim f787e34 (`plugin/dashboard.lua`,
--- `lua/dashboard/init.lua`) at `UIEnter`, with autocommands, in the current
--- buffer when it is empty — at a bare start, the first — else in a new one;
--- `buf_local()` sets `bufhidden=wipe`, `nobuflisted`, `noswapfile` and the
--- filetype `dashboard`, and no `'buftype'`; its themes draw and leave the
--- buffer not modifiable and not modified (`lua/dashboard/utils.lua`,
--- `lua/dashboard/theme/doom.lua`), and without `setup()` it draws nothing
--- until a cache file its first run writes exists (`db:get_opts()`).
--- mini.starter, the fourth, is the real one in `deps/`.

local dashboard = vim.g.entry_dashboard

--- Makes the current buffer, the one the editor starts with, the
--- dashboard's.
local function show()
  local ignored_events = vim.o.eventignore
  if not dashboard.autocommands then
    vim.o.eventignore = 'all'
  end
  local buffer = vim.api.nvim_get_current_buf()
  for option, value in pairs(dashboard.options) do
    vim.bo[buffer][option] = value
  end
  vim.bo[buffer].filetype = dashboard.filetype
  if dashboard.drawn then
    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { dashboard.filetype })
    vim.bo[buffer].modifiable = false
    vim.bo[buffer].modified = false
  end
  vim.o.eventignore = ignored_events
end

if dashboard.moment == 'scheduled' then
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      vim.schedule(show)
    end,
  })
else
  vim.api.nvim_create_autocmd(dashboard.moment, { once = true, nested = true, callback = show })
end
