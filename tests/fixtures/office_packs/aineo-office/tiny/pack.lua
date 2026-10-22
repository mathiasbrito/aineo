-- The tiny office: a door, a whiteboard, a server rack and as many desks as fit.
return {
  format = 1,
  name = 'tiny',
  about = 'The smallest office: a door, a whiteboard, a server rack and rows of desks.',
  author = 'aineo',
  based_on = false,

  colours = {
    wall = '#292c3c',
    floor = '#303446',
    wood = '#b4875a',
    dark_wood = '#7a5634',
    board = '#eff1f5',
    board_frame = '#a5adcb',
    rack = '#45475a',
    light = '#a6e3a1',
    ink = '#1e1e2e',
  },

  text_colours = { thought = '#b4befe', name = 'Comment' },

  characters = {
    agent = {
      colours = { '#a6e3a1', '#89b4fa', '#f9e2af', '#f5c2e7' },
      poses = {
        standing = { art = { 'person' } },
        walking = { art = { 'person_walking' } },
        sitting = { art = { 'person' }, sitting = true },
        typing = { like = 'sitting', effect = 'busy_dots' },
        thinking = { like = 'standing', effect = 'thought_bubble' },
      },
    },
  },

  effects = {
    thought_bubble = {
      text = { '·', '· ∘', '· ∘ ○' },
      colour = 'thought',
      place = 'above_right',
      seconds_per_frame = 0.4,
    },
    busy_dots = { text = { '.', '..', '...' }, place = 'above' },
    raised_hand = { text = { '!', ' ' }, colour = 'warning', bold = true },
  },

  floor = {
    plan = 'floor.txt',
    floor_colour = 'floor',
    wall_colour = 'wall',
    legend = {
      D = { piece = 'door' },
      B = { piece = 'whiteboard' },
      R = { piece = 'server_rack' },
      T = { piece = 'desk' },
      d = { spot = 'door' },
      b = { spot = 'whiteboard' },
      r = { spot = 'server_rack' },
      s = { spot = 'desk', sitting = true },
    },
  },

  activities = {
    come_in = {
      about = 'Walks in through the door and sits down at its desk.',
      steps = {
        { at = 'door', for_seconds = 0.5 },
        { at = 'desk', pose = 'sitting' },
      },
    },
    work_at_the_desk = {
      about = 'Types at its desk.',
      steps = { { at = 'desk', pose = 'typing' } },
    },
    think_at_the_board = {
      about = 'Stands at the whiteboard with a thought bubble.',
      steps = { { at = 'whiteboard', pose = 'thinking' } },
    },
    wait_with_a_raised_hand = {
      about = 'Sits at its desk with a blinking "!".',
      steps = { { at = 'desk', pose = 'sitting', effect = 'raised_hand' } },
    },
    sit_back = {
      about = 'Sits at its desk, doing nothing, for a while.',
      steps = { { at = 'desk', pose = 'sitting', for_seconds = { 5, 10 } } },
    },
    stretch_its_legs = {
      about = 'Gets up, walks to the whiteboard and back, and sits a while.',
      during = { 'idle' },
      chance = 1,
      steps = {
        { at = 'whiteboard', for_seconds = { 2, 4 } },
        { at = 'desk', pose = 'sitting', for_seconds = { 10, 20 } },
      },
    },
    go_home = {
      about = 'Walks out through the door.',
      steps = { { at = 'door' } },
    },
    tend_the_server_rack = {
      about = 'Stands at the server rack while a docker command runs.',
      steps = { { at = 'server_rack', pose = 'thinking' } },
    },
  },

  states = {
    standing = 'sit_back',
    arriving = 'come_in',
    working = 'work_at_the_desk',
    thinking = 'think_at_the_board',
    waiting = 'wait_with_a_raised_hand',
    resting = 'sit_back',
    leaving = 'go_home',
  },

  triggers = {
    { when = { tool = 'Bash', command = 'docker' }, play = 'tend_the_server_rack' },
  },
}
