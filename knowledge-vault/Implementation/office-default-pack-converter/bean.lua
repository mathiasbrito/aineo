-- The agent, a jelly bean, as layers: its body, its face, its legs, its arms
-- with what they hold, and the few poses whose motion is drawn frame by frame.
--
-- Every layer is drawn in the bean's own coordinates (x 0..10, y 0..11, its
-- feet on row 11) with the anchor at its feet, column 5, so that the layers a
-- pose lists stack. A layer's art extends past the bean where an arm or a prop
-- does.

local art = require('art')
local palette = require('palette')

local M = {}

--- The bean's anchor: the middle of its feet.
M.ANCHOR = { 5, 11 }

--- The colour names of the mock's bean letters.
local function bean_names()
  palette.name_of('1e1e2e')
  palette.name_of('cdd6f4')
  return {
    B = 'agent',
    L = 'agent_light',
    S = 'agent_shade',
    p = 'agent_blush',
    k = 'ink',
    w = 'shine',
  }
end

local BIG = { -30, -30, 60, 40 }

--- A scratch canvas, big enough for any arm or prop.
local function scratch()
  return art.new_canvas(BIG[1], BIG[2], BIG[3], BIG[4])
end

--- The canvases of `painters`, one per frame, all cropped to the rectangle
--- that holds every pixel any of them paints, and the bean's anchor.
---
---@param painters (fun(canvas: table))[]
---@return table[] frames
local function cropped(painters)
  local drawn = {}
  local left, top, right, bottom = M.ANCHOR[1], M.ANCHOR[2], M.ANCHOR[1], M.ANCHOR[2]
  for index, paint in ipairs(painters) do
    local canvas = scratch()
    paint(canvas)
    drawn[index] = canvas
    for y = canvas.top, canvas.bottom do
      for x = canvas.left, canvas.right do
        if canvas:get(x, y) then
          left, top = math.min(left, x), math.min(top, y)
          right, bottom = math.max(right, x), math.max(bottom, y)
        end
      end
    end
  end
  local frames = {}
  for index, canvas in ipairs(drawn) do
    local frame = art.new_canvas(left, top, right, bottom)
    for y = top, bottom do
      for x = left, right do
        local name = canvas:get(x, y)
        if name then
          frame:set(x, y, name)
        end
      end
    end
    frames[index] = frame
  end
  return frames
end

--- A layer of the bean from painters, one per frame.
---
---@param about string
---@param painters (fun(canvas: table))[]
---@param seconds_per_frame? number
---@return converter.Piece
local function layer(about, painters, seconds_per_frame)
  return {
    about = about,
    frames = cropped(painters),
    anchor = { M.ANCHOR[1], M.ANCHOR[2] },
    seconds_per_frame = seconds_per_frame,
  }
end

--- Paints points `{ x, y }` in a colour name.
local function dots(canvas, points, name)
  for _, point in ipairs(points) do
    canvas:set(point[1], point[2], name)
  end
end

--- The points of an arm, mirrored to the bean's other side.
local function across(points)
  local out = {}
  for _, point in ipairs(points) do
    out[#out + 1] = { 10 - point[1], point[2] }
  end
  return out
end

--- The ticks of the mock, 12 to the second.
local TICK = 1 / 12

--- The layers of the bean and its arms, by name.
---
---@param sprites table the mock's sprites module
---@return table<string, converter.Piece>
function M.layers(sprites)
  local names = bean_names()
  local prop_names = art.names_of(sprites.PROP_PAL)
  local prop2_names = art.names_of(sprites.PROP2_PAL)
  local pieces = {}

  local function body(rows)
    return function(canvas)
      canvas:blit(rows, names, 0, 0)
    end
  end

  pieces.bean = layer(
    'The body of an agent, a jelly bean, in the agent\'s own colours.',
    { body(sprites.body) }
  )
  pieces.bean_seated = layer(
    'The body of an agent sitting behind a desk: only what the desk leaves showing.',
    {
      body(vim.list_slice(sprites.body, 1, 9)),
    }
  )
  pieces.bean_jumping = layer(
    'The body of an agent that jumps; its pose lifts it a tick at a time.',
    { body(sprites.body) },
    TICK
  )

  for _, face in ipairs({ 'side', 'happy', 'think', 'wait', 'error', 'sleep', 'yawn', 'back', 'down' }) do
    pieces['bean_face_' .. face] = layer(
      ('The face of an agent: %s.'):format(face),
      {
        function(canvas)
          canvas:blit(sprites.face[face], names, 0, 0)
        end,
      }
    )
  end
  local front_frames = {}
  for tick = 0, 44 do
    local rows = tick < 2 and sprites.face.blink or sprites.face.front
    front_frames[#front_frames + 1] = function(canvas)
      canvas:blit(rows, names, 0, 0)
    end
  end
  pieces.bean_face_front = layer(
    'The face of an agent looking at you; it blinks every few seconds.',
    front_frames,
    TICK
  )
  local startled = {}
  for tick = 0, 54 do
    local rows = tick < 14 and sprites.face.error or sprites.face.wait
    startled[#startled + 1] = function(canvas)
      canvas:blit(rows, names, 0, 0)
    end
  end
  pieces.bean_face_startled = layer(
    'The face of an agent that has been interrupted: a shock, then wariness.',
    startled,
    TICK
  )

  pieces.bean_legs_stand = layer('The legs of a standing agent.', {
    function(canvas)
      canvas:blit(sprites.legs.stand, names, 0, 0)
    end,
  })
  pieces.bean_legs_walk = layer('The legs of a walking agent, two frames.', {
    function(canvas)
      canvas:blit(sprites.legs.walk[1], names, 0, 0)
    end,
    function(canvas)
      canvas:blit(sprites.legs.walk[2], names, 0, 0)
    end,
  }, 1 / 6)
  pieces.bean_legs_tap = layer('The legs of an agent tapping a foot.', {
    function(canvas)
      canvas:blit(sprites.legs.stand, names, 0, 0)
    end,
    function(canvas)
      canvas:blit(sprites.legs.tap, names, 0, 0)
    end,
  }, 0.25)

  local function hands(frame)
    return function(canvas)
      canvas:blit(sprites.hands[frame], names, 0, 9)
    end
  end
  pieces.bean_hands_fast = layer(
    'The hands of a seated agent typing fast, on the desk.',
    { hands(1), hands(2) },
    TICK
  )
  pieces.bean_hands_slow = layer(
    'The hands of a seated agent typing slowly, on the desk.',
    { hands(1), hands(2) },
    0.25
  )

  -- Arms, in the agent's colour, with what they hold.
  local arms = sprites.arms
  local function arm(points, extra)
    return function(canvas)
      dots(canvas, points, 'agent')
      if extra then
        extra(canvas)
      end
    end
  end
  local function paper_at(x, y)
    return function(canvas)
      canvas:blit(sprites.paper, prop_names, x, y)
    end
  end
  pieces.arm_hold_paper = layer('An arm holding a sheet of paper.', {
    arm(arms.hold, paper_at(12, 3)),
  })
  pieces.arm_give_paper = layer('An arm held out with a sheet of paper.', {
    arm(arms.give, paper_at(15, 2)),
  })
  local function mug_at(y)
    return function(canvas)
      canvas:blit(sprites.mug, prop_names, 12, y)
    end
  end
  local steam_names = { w = palette.name_of(sprites.COFFEE_PAL.w) }
  local function steam_at(y, frame)
    return function(canvas)
      canvas:blit(sprites.steam_px(frame * 4), steam_names, 13, y)
    end
  end
  local function cup_painter(mug_y, frame)
    return arm(arms.hold, function(canvas)
      mug_at(mug_y)(canvas)
      steam_at(mug_y - 3, frame)(canvas)
    end)
  end
  pieces.arm_hold_cup = layer('An arm holding a cup of coffee, steaming.', {
    cup_painter(5, 0),
    cup_painter(5, 1),
  }, 4 * TICK)
  pieces.arm_hold_cup_sofa = layer('An arm holding a cup of coffee on the sofa, steaming.', {
    cup_painter(4, 0),
    cup_painter(4, 1),
  }, 4 * TICK)

  pieces.arm_raise_far = layer('The far arm raised: a hand up.', { arm(across(arms.raise)) })
  pieces.arm_raise_both = layer('Both arms raised.', {
    arm(arms.raise, function(canvas)
      dots(canvas, across(arms.raise), 'agent')
    end),
  })
  pieces.arm_wave_far = layer('The far arm raised, waving.', {
    arm(across(arms.raise)),
    arm(across(arms.wave)),
  }, 4 * TICK)
  pieces.arm_yawn = layer('Both arms raised, then down: a yawn and a stretch.', (function()
    local painters = {}
    for tick = 0, 25 do
      painters[#painters + 1] = function(canvas)
        if tick < 14 then
          dots(canvas, arms.raise, 'agent')
          dots(canvas, across(arms.raise), 'agent')
        end
      end
    end
    return painters
  end)(), TICK)

  local marker_frames = {}
  for wiggle = 0, 1 do
    marker_frames[#marker_frames + 1] = arm(arms.marker, function(canvas)
      canvas:blit(sprites.marker_tip, { b = palette.name_of(sprites.BOARD_PAL.b) }, 14, -3 - wiggle)
    end)
  end
  pieces.arm_marker = layer('An arm writing up on the board, the marker tip wiggling.', marker_frames, 0.25)

  pieces.arm_reach = layer('An arm reaching in front of the agent: into a drawer, to a machine.', {
    arm(arms.reach),
  })

  local scratch_frames = {}
  for frame = 1, 2 do
    scratch_frames[#scratch_frames + 1] = arm(arms.scratch, function(canvas)
      local hand = sprites.scratch_hand[frame]
      canvas:set(hand[1], hand[2], 'agent_light')
      canvas:set(hand[1] + 1, hand[2], 'agent_light')
    end)
  end
  pieces.arm_scratch = layer('A hand scratching the head.', scratch_frames, 0.25)

  pieces.arm_watch = layer('A wrist raised to look at a watch.', {
    arm(arms.watch, function(canvas)
      canvas:set(8, 4, palette.name_of(sprites.PROP_PAL.T))
    end),
  })
  pieces.arm_pet = layer('An arm reaching down and out, to pet or to sweep.', { arm(arms.pet) })
  pieces.arm_drink = layer('A hand holding a paper cup to the mouth.', {
    arm(arms.drink, function(canvas)
      canvas:blit(sprites.paper_cup, prop2_names, 8, 5)
    end),
  })

  local water_names = { d = palette.name_of(sprites.PROP2_PAL.d) }
  local can_frames = {}
  for tick = 0, 7 do
    can_frames[#can_frames + 1] = arm(arms.can, function(canvas)
      canvas:blit(sprites.watering_can, art.names_of(sprites.CAN_PAL), 12, 3)
      for drop = 0, 2 do
        canvas:blit({ 'd' }, water_names, 19, 5 + (tick + drop * 3) % 8)
      end
    end)
  end
  pieces.arm_water = layer('An arm holding out a watering can, the water running.', can_frames, TICK)

  pieces.book = layer('An open book held in front of the agent.', {
    function(canvas)
      canvas:blit(sprites.book, prop2_names, 2, 5)
    end,
  })

  -- A paddle, swung between two strokes.
  local paddle = { { 11, 5 }, { 12, 4 }, { 13, 4 } }
  local function stroke(up)
    return function(canvas)
      dots(canvas, paddle, 'agent')
      local y = up and 1 or 4
      canvas:blit({ 'rr', 'rr' }, { r = 'red' }, 13, y)
      canvas:set(12, y + 2, 'wood')
    end
  end
  palette.name_of('e64553')
  palette.name_of('b4875a')
  pieces.arm_paddle = layer('An arm swinging a table-tennis paddle.', { stroke(false), stroke(true) }, 0.4)

  -- A box, carried in front: the agent packing up.
  local pack_frames = {}
  for tick = 0, 23 do
    pack_frames[#pack_frames + 1] = function(canvas)
      canvas:blit(sprites.box, prop_names, 0, 6)
      if tick < 12 then
        canvas:blit(sprites.paper_flat, prop_names, 3, math.floor(tick / 2))
      end
    end
  end
  pieces.packing_props = layer('A box on the floor in front of the agent; the papers go into it.', pack_frames, TICK)

  return pieces
end

--- The composite pieces: poses whose body, face and props move together.
---
---@param sprites table
---@return table<string, converter.Piece>
function M.composites(sprites)
  local names = bean_names()
  local prop_names = art.names_of(sprites.PROP_PAL)
  local pieces = {}

  -- Spinning in the chair: front, side, back, side turned the other way.
  local turns = { 'front', 'side', 'back', 'side' }
  local spin = {}
  for index, face in ipairs(turns) do
    spin[index] = function(canvas)
      local turned = index == 4
      local body = vim.list_slice(sprites.body, 1, 9)
      canvas:blit(body, names, 0, 0, turned)
      canvas:blit(sprites.face[face], names, 0, 0, turned)
    end
  end
  pieces.bean_spinning = layer('An agent turning round in its chair: the front, the side, the back, the other side.', spin, 0.25)

  -- A paper falls on the desk, lies there, and is picked up.
  local lands_at = 8
  local task = {}
  for tick = 0, 39 do
    task[#task + 1] = function(canvas)
      local face = tick < 30 and 'front' or 'think'
      canvas:blit(vim.list_slice(sprites.body, 1, 9), names, 0, 0)
      canvas:blit(sprites.face[face], names, 0, 0)
      if tick < 12 then
        local y = math.floor(-20 + (lands_at + 20) * (tick / 12) + 0.5)
        canvas:blit(sprites.paper_fly[1], prop_names, 3, y)
      elseif tick < 24 then
        canvas:blit(sprites.paper_flat, prop_names, 3, lands_at)
      elseif tick < 30 then
        local progress = (tick - 24) / 6
        local x = math.floor(3 + (12 - 3) * progress + 0.5)
        local y = math.floor(lands_at + (3 - lands_at) * progress + 0.5)
        canvas:blit(sprites.paper, prop_names, x, y)
      end
      if tick >= 24 then
        dots(canvas, sprites.arms.hold, 'agent')
      end
      if tick >= 30 then
        canvas:blit(sprites.paper, prop_names, 12, 3)
      end
    end
  end
  pieces.bean_receiving_a_task = layer(
    'An agent at its desk: a paper falls on it, lies there, and is picked up.',
    task,
    TICK
  )

  -- Papers thrown up when an agent is interrupted, falling over the floor.
  local across_speed = { -2.2, -1.2, 0.6, 1.5, 2.4 }
  local up_speed = { -3.2, -4.2, -3.8, -2.8, -3.6 }
  local floor_y = 14
  local papers = {}
  for tick = 0, 54 do
    papers[#papers + 1] = function(canvas)
      for paper = 1, #across_speed do
        local x = 5 + across_speed[paper] * tick
        local y = 8 + up_speed[paper] * tick + 0.25 * tick * tick
        local resting = y >= floor_y and tick > 4
        if resting then
          local landed = (-up_speed[paper]
            + math.sqrt(up_speed[paper] ^ 2 + 4 * 0.25 * (floor_y - 8))) / 0.5
          x, y = 5 + across_speed[paper] * landed, floor_y
        end
        local rows = resting and sprites.paper_flat
          or sprites.paper_fly[(paper + math.floor(tick / 2)) % 2 + 1]
        canvas:blit(rows, prop_names, math.floor(x + 0.5), math.floor(y + 0.5))
      end
    end
  end
  pieces.papers_flying = layer(
    'Sheets of paper thrown up and falling over the floor.',
    papers,
    TICK
  )

  -- Tidying the desk: the papers on it jitter into a stack.
  local tidy = {}
  for tick = 0, 29 do
    tidy[#tidy + 1] = function(canvas)
      canvas:blit(sprites.hands[math.floor(tick / 3) % 2 + 1], names, 0, 9)
      local jitter = math.max(0, 3 - math.floor(tick / 8))
      for sheet = 0, 2 do
        local shift = ((sheet % 2 == 0) and 1 or -1) * math.min(jitter, sheet + 1)
        canvas:blit({ 'wwwww' }, art.names_of(sprites.PROP2_PAL), 13 + shift, 6 - sheet)
      end
    end
  end
  pieces.desk_tidying = layer('The hands and the papers of an agent tidying its desk.', tidy, TICK)

  -- A paper ball thrown at the bin, and what comes of it.
  local function flight(misses)
    local frames = {}
    local target_x, target_y = 15, 4
    if misses then
      target_x = 21
    end
    for tick = 0, 21 do
      frames[#frames + 1] = function(canvas)
        if tick < 8 then
          dots(canvas, sprites.arms.raise, 'agent')
        end
        if tick >= 4 then
          local progress = (tick - 4) / 18
          local x = math.floor(10 + (target_x - 10) * progress + 0.5)
          local y = math.floor(1 + (target_y - 1) * progress + 0.5)
            - math.floor(14 * math.sin(math.pi * progress) + 0.5)
          canvas:blit(sprites.paper_ball, art.names_of(sprites.PROP2_PAL), x, y)
        end
      end
    end
    return frames
  end
  pieces.paper_ball_on_the_floor = layer('A paper ball that missed the bin, on the floor beside the agent.', {
    function(canvas)
      canvas:blit(sprites.paper_ball, art.names_of(sprites.PROP2_PAL), 21, 10)
    end,
  })
  pieces.arm_throw_in = layer('An agent throws a paper ball at the bin; it lands in.', flight(false), TICK)
  pieces.arm_throw_miss = layer('An agent throws a paper ball at the bin; it misses.', flight(true), TICK)

  return pieces
end

return M
