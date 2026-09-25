--- A stand-in for a startup dashboard, a plugin the entry suites put on an
--- editor's 'runtimepath' after aineo, so that its autocommands follow
--- aineo's. At a bare start it shows a buffer of a dashboard's filetype in the
--- current window, as `vim.g.entry_dashboard` describes, set before startup:
---
--- - `filetype` — the dashboard's filetype;
--- - `moment` — when it shows: `VimEnter`, `UIEnter`, or `scheduled`, from a
---   `vim.schedule()` callback scheduled at `VimEnter`;
--- - `autocommands` — whether showing it runs autocommands; without them it
---   shows under `eventignore=all`;
--- - `buffer` — `first`, the buffer the editor starts with, or `new`.
---
--- Modelled on the dashboards' own sources, read at these versions:
--- snacks.nvim v2.31.0 (`lua/snacks/dashboard.lua`, `M.setup()`, run at
--- `UIEnter`) shows its dashboard in the first buffer with `eventignore` set
--- to `all`; alpha-nvim 4ba26e4 (`lua/alpha.lua`, `alpha.start()`) at
--- `VimEnter`, in the current buffer, under `eventignore=all` when its
--- `noautocmd` option is set; dashboard-nvim f787e34 (`plugin/dashboard.lua`,
--- `lua/dashboard/init.lua`) at `UIEnter`, in a new buffer unless the current
--- one is empty. mini.starter, the fourth, is the real one in `deps/`.

local dashboard = vim.g.entry_dashboard

--- Shows the dashboard's buffer in the current window.
local function show()
  local ignored_events = vim.o.eventignore
  if not dashboard.autocommands then
    vim.o.eventignore = 'all'
  end
  local buffer = dashboard.buffer == 'first' and vim.api.nvim_get_current_buf()
    or vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buffer)
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].filetype = dashboard.filetype
  vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { dashboard.filetype })
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
