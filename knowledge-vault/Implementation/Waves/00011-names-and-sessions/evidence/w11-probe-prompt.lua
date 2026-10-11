-- Wave 11 planning probe P7: what Neovim 0.12.5 lets Lua read of an empty
-- Claude Code prompt and a drafted one, from Claude Code 2.1.281's own
-- recorded screens (`tests/fixtures/claude/startup-2.1.281.bytes`, whose
-- prompt shows the dim placeholder, and `draft-2.1.281.bytes`, a two-line
-- draft), replayed into a terminal buffer at the 120x40 they were recorded
-- at. No `claude` runs. From the checkout's root, headless, its XDG data,
-- state and cache and its log under .tests/:
--   nvim --clean --headless -l <this file>
vim.o.columns, vim.o.lines = 120, 42

local function replay(fixture)
  local bytes = assert(io.open('tests/fixtures/claude/' .. fixture, 'rb')):read('a')
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buffer)
  vim.cmd('resize 40')
  local channel = vim.api.nvim_open_term(buffer, {})
  vim.api.nvim_chan_send(channel, bytes)
  vim.wait(500, function()
    return false
  end, 20)
  return buffer
end

local function report(fixture)
  vim.cmd('silent! only')
  vim.cmd('enew')
  local buffer = replay(fixture)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local prompt_row
  for row, line in ipairs(lines) do
    if vim.startswith(line, '❯') then
      prompt_row = row
    end
  end
  print(('%s: prompt row %s: %q'):format(fixture, tostring(prompt_row), lines[prompt_row] or ''))
  print('  Normal mode window cursor: ' .. vim.inspect(vim.api.nvim_win_get_cursor(0)))
  vim.cmd('startinsert')
  vim.wait(300, function()
    return vim.api.nvim_get_mode().mode == 't'
  end, 10)
  print(
    ('  mode %s, window cursor in Terminal mode: %s'):format(
      vim.api.nvim_get_mode().mode,
      vim.inspect(vim.api.nvim_win_get_cursor(0))
    )
  )
  vim.cmd('stopinsert')
  vim.wait(100, function()
    return false
  end, 10)
  if prompt_row then
    for _, column in ipairs({ 4, 8 }) do
      local ok, position = pcall(vim.inspect_pos, buffer, prompt_row - 1, column)
      print(
        ('  inspect_pos(row %d, byte %d): %s'):format(
          prompt_row,
          column,
          ok
              and vim.inspect({
                treesitter = #position.treesitter,
                syntax = position.syntax,
                extmarks = vim.tbl_map(function(mark)
                  return { mark.ns, mark.opts and mark.opts.hl_group }
                end, position.extmarks),
                semantic_tokens = #position.semantic_tokens,
              })
            or tostring(position)
        )
      )
    end
  end
end

report('startup-2.1.281.bytes')
report('draft-2.1.281.bytes')
vim.cmd('qall!')
