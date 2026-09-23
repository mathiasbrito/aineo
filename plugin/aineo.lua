--- aineo's composition root, sourced by Neovim at every startup. It stays
--- cheap: it requires no aineo module, so `lua/aineo/` loads only when a
--- command or mapping first needs it.
---
--- It runs once. Setting `vim.g.loaded_aineo` before startup turns it off, and
--- sourcing it again does nothing.

if vim.g.loaded_aineo then
  return
end
vim.g.loaded_aineo = true
