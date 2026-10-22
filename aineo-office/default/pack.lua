-- The default office: a door on the wall and a row of desks, each with a monitor.
-- An agent is a jelly bean: it stands by its desk, and sits and types while a tool runs.
return {
  format = 1,
  name = 'default',
  about = 'The default office: a door, and a row of desks with monitors, for agents that are beans.',
  author = 'aineo',
  based_on = false,

  colours = {
    wall = '#292c3c',
    floor = '#303446',
    ink = '#1e1e2e',
    shine = '#cdd6f4',
    wood = '#b4875a',
    dark_wood = '#7a5634',
    door_frame = '#6b4f3f',
    door_panel = '#8b6a4f',
    door_inset = '#7a5a40',
    brass = '#f9e2af',
    monitor_frame = '#45475a',
    screen = '#181825',
    code_cyan = '#89dceb',
    code_green = '#a6e3a1',
    code_mauve = '#cba6f7',
    code_yellow = '#f9e2af',
  },

  text_colours = { status = '#cdd6f4', thought = '#b4befe' },

  characters = {
    agent = {
      colours = { '#a6e3a1', '#89b4fa', '#f9e2af', '#f5c2e7', '#fab387', '#94e2d5' },
      poses = {
        standing = { art = { 'bean', 'bean_face_front', 'bean_legs_stand' } },
        walking = { art = { 'bean', 'bean_face_side', 'bean_legs_walk' } },
        sitting = { art = { 'bean', 'bean_face_front' }, sitting = true },
        typing = { like = 'sitting', effect = 'busy_dots' },
      },
    },
  },

  effects = {
    busy_dots = { text = { '.', '..', '...' }, place = 'above', seconds_per_frame = 0.25 },
  },

  floor = {
    plan = 'floor.txt',
    floor_colour = 'floor',
    wall_colour = 'wall',
    legend = {
      D = { piece = 'door' },
      T = { piece = 'desk' },
      M = { piece = 'monitor' },
      a = { spot = 'beside_desk' },
      s = { spot = 'desk', sitting = true },
    },
  },

  activities = {
    stand_by_the_desk = {
      about = 'Stands beside its desk.',
      steps = { { at = 'beside_desk', pose = 'standing' } },
    },
    work_at_the_desk = {
      about = 'Sits at its desk and types, dots rising over its head.',
      steps = { { at = 'desk', pose = 'typing' } },
    },
  },

  states = {
    standing = 'stand_by_the_desk',
    working = 'work_at_the_desk',
  },
}
