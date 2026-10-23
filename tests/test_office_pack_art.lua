local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The directory the packs of one case are written in, emptied.
---
---@return string
local function pack_root()
  return fixture.directory('office_pack_art')
end

--- The pack `small` with the art file `art/probe.txt` holding `art_text`.
---
---@param art_text string
---@return string folder
local function pack_with_art(art_text)
  return files.write_pack(pack_root(), 'small', { ['art/probe.txt'] = art_text })
end

--- The piece `probe` of the pack `small` loaded with `art_text` as its art.
---
---@param art_text string
---@return aineo.office_pack.Piece|nil
local function probe_piece(art_text)
  local pack = office_pack.load({ name = 'small', folders = { pack_with_art(art_text) } })
  return pack.pieces.probe
end

--- The problems the art file `art/probe.txt` holding `art_text` has, each as
--- `{ line, message }`.
---
---@param art_text string
---@return table[]
local function probe_problems(art_text)
  local problems = office_pack.check({ name = 'small', folders = { pack_with_art(art_text) } })
  local told = {}
  for _, problem in ipairs(problems) do
    assert(problem.file == 'art/probe.txt', 'a problem in another file: ' .. problem.file)
    table.insert(told, { problem.line, problem.message })
  end
  return told
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

T['art files'] = MiniTest.new_set()

T['art files']['say what a piece is, and which way it faces'] = function()
  local plain = probe_piece('about: A box.\ncolours: A = ink\n---\nA\n')
  local turned = probe_piece('colours: A = ink\nfaces: left\n---\nA\n')

  eq(plain.about, 'A box.')
  eq(plain.faces, 'right')
  eq(turned.about, '')
  eq(turned.faces, 'left')
end

T['art files']['say which columns stretch, counted from 1'] = function()
  local piece = probe_piece('colours: A = ink\nstretch: columns 2-4\n---\nAAAAAA\n')

  eq(piece.stretch, { first = 2, last = 4 })
end

T['art files']['give a piece that does not stretch no stretch'] = function()
  eq(probe_piece('colours: A = ink\n---\nAA\n').stretch, nil)
end

T['art files']['say the rectangles aineo draws into, counted from 0'] = function()
  local piece = probe_piece(
    'colours: A = ink\narea screen: 1, 1, 4 x 2\narea name: 0, 3, 6 x 1\n---\nAAAAAA\nAAAAAA\nAAAAAA\nAAAAAA\n'
  )

  eq(piece.areas, {
    screen = { column = 1, row = 1, width = 4, height = 2 },
    name = { column = 0, row = 3, width = 6, height = 1 },
  })
end

T['art files']['give a piece with no area no areas'] = function()
  eq(probe_piece('colours: A = ink\n---\nA\n').areas, {})
end

T['art files']['may name the colours of the character they are drawn for'] = function()
  eq(
    probe_problems(
      'colours: A = agent, B = agent_light, C = agent_shade, D = agent_blush\n---\nABCD\n'
    ),
    {}
  )
end

T['art files']['take the colours of the pack, and no other'] = function()
  eq(probe_problems('colours: A = wood, B = ink, C = floor\n---\nABC\n'), {})
end

--- Art files with something wrong, the line each problem is on and what it says.
local WRONG_ART = {
  {
    'no separator',
    'colours: A = ink\nAAA\n',
    1,
    'the header is not followed by a line “---”',
  },
  { 'no pixels', 'colours: A = ink\n---\n', 2, 'the piece has no pixels' },
  {
    'a row of another width',
    'colours: A = ink\n---\nAAA\nAAA\nAA\n',
    5,
    'this row is 2 pixels wide, and the first row is 3',
  },
  {
    'a row of another width in a later frame',
    'colours: A = ink\n---\nAA\nAA\n---\nAAA\n',
    6,
    'this row is 3 pixels wide, and the first row is 2',
  },
  {
    'a letter the header does not name',
    'colours: A = ink\n---\nAA\nAB\n',
    4,
    'the letter “B” is not named in the colours header',
  },
  {
    'a colour the pack does not have',
    'about: x\ncolours: A = ink, B = mauve\n---\nAB\n',
    2,
    'the colour “mauve” is not one of the pack’s colours',
  },
  {
    'a colour entry that is none',
    'colours: A ink\n---\nA\n',
    1,
    '“A ink” is not “letter = colour”',
  },
  {
    'a field the header does not know',
    'colours: A = ink\ncolors: A = ink\n---\nA\n',
    2,
    '“colors” is not a header field aineo knows',
  },
  {
    'a header line that is no field',
    'colours: A = ink\nnonsense\n---\nA\n',
    2,
    '“nonsense” is not “field: value”',
  },
  {
    'an anchor that is not two numbers',
    'colours: A = ink\nanchor: 1\n---\nA\n',
    2,
    'the anchor is “column, row”, two whole numbers',
  },
  {
    'an anchor outside the art',
    'colours: A = ink\nanchor: 1, 0\n---\nA\n',
    2,
    'the anchor lies outside the art',
  },
  {
    'a speed that is not above 0',
    'colours: A = ink\nseconds per frame: 0\n---\nA\n',
    2,
    'seconds per frame is a number above 0',
  },
  {
    'a facing that is neither left nor right',
    'colours: A = ink\nfaces: up\n---\nA\n',
    2,
    'faces is left or right',
  },
  {
    'a stretch that is not columns',
    'colours: A = ink\nstretch: rows 1-2\n---\nAAA\n',
    2,
    'stretch is “columns first-last”',
  },
  {
    'a stretch outside the art',
    'colours: A = ink\nstretch: columns 2-9\n---\nAAA\n',
    2,
    'the stretched columns lie outside the art',
  },
  {
    'a stretch that ends before it starts',
    'colours: A = ink\nstretch: columns 3-2\n---\nAAA\n',
    2,
    'the stretched columns lie outside the art',
  },
  {
    'an area that is not a rectangle',
    'colours: A = ink\narea screen: 1, 2\n---\nAAA\n',
    2,
    'an area is “column, row, width x height”',
  },
  {
    'an area aineo does not draw into',
    'colours: A = ink\narea window: 0, 0, 1 x 1\n---\nAAA\n',
    2,
    '“window” is not an area aineo draws into',
  },
  {
    'an area outside the art',
    'colours: A = ink\narea screen: 2, 0, 2 x 1\n---\nAAA\n',
    2,
    'the area lies outside the art',
  },
}

T['art files']['that are wrong are told with the line, one by one'] = MiniTest.new_set({
  parametrize = vim.tbl_map(function(case)
    return { case[1], case[2], case[3], case[4] }
  end, WRONG_ART),
})

T['art files']['that are wrong are told with the line, one by one']['case'] = function(
  _,
  art_text,
  line,
  message
)
  eq(probe_problems(art_text), { { line, message } })
end

T['art files']['tell every problem at once'] = function()
  eq(probe_problems('colours: A = ink, B = mauve\nfaces: up\n---\nAA\nAAA\nAC\n'), {
    { 1, 'the colour “mauve” is not one of the pack’s colours' },
    { 2, 'faces is left or right' },
    { 5, 'this row is 3 pixels wide, and the first row is 2' },
    { 6, 'the letter “C” is not named in the colours header' },
  })
end

T['art files']['may be 400 pixels wide, 200 tall and have 64 frames'] = function()
  local wide = 'colours: A = ink\n---\n' .. ('A'):rep(400) .. '\n'
  local tall = 'colours: A = ink\n---\n' .. ('A\n'):rep(200)
  local frames = 'colours: A = ink\n---\n' .. ('A\n---\n'):rep(63) .. 'A\n'

  eq(probe_problems(wide), {})
  eq(probe_problems(tall), {})
  eq(probe_problems(frames), {})
end

T['art files']['are refused over 400 pixels wide'] = function()
  eq(probe_problems('colours: A = ink\n---\n' .. ('A'):rep(401) .. '\n'), {
    { 3, 'the art is wider than 400 pixels' },
  })
end

T['art files']['are refused over 200 pixels tall'] = function()
  eq(probe_problems('colours: A = ink\n---\n' .. ('A\n'):rep(201)), {
    { 3, 'the art is taller than 200 pixels' },
  })
end

T['art files']['are refused over 64 frames'] = function()
  eq(probe_problems('colours: A = ink\n---\n' .. ('A\n---\n'):rep(64) .. 'A\n'), {
    { 3, 'the art has more than 64 frames' },
  })
end

T['a pack'] = MiniTest.new_set()

T['a pack']['may have 500 art files'] = function()
  local extra = {}
  for index = 1, 499 do
    extra[('art/zz%03d.txt'):format(index)] = 'colours: A = ink\n---\nA\n'
  end
  local folder = files.write_pack(pack_root(), 'small', extra)

  eq(office_pack.check({ name = 'small', folders = { folder } }), {})
end

T['a pack']['is told to have more than 500 art files, and the ones over are left out'] = function()
  local extra = {}
  for index = 1, 500 do
    extra[('art/zz%03d.txt'):format(index)] = 'colours: A = ink\n---\nA\n'
  end
  local folder = files.write_pack(pack_root(), 'small', extra)

  local pack, problems = office_pack.load({ name = 'small', folders = { folder } })

  eq(#problems, 1)
  eq(problems[1].message, 'the pack has more than 500 art files')
  eq(vim.tbl_count(pack.pieces), 500)
  eq(pack.pieces.person ~= nil, true)
end

return T
