-- What was written by hand for the default pack: its characters and their
-- poses, its effects, its activities and what plays in each state, and the
-- cat's life. The converter writes everything else.
--
-- The activities follow the approved mock's scenes (what each of the states
-- does) and its random behaviours (`behaviours.lua`: the weights, the times
-- and the steps), in the pack format's plain fields.

local M = {}

--- The colours of the office's text, by role.
M.text_colours = {
  name = '#6c7086',
  status = '#7c7f93',
  thought = '#b4befe',
  warning = '#f38ba8',
}

--- The colours of the agents, one for each place in turn.
M.agent_colours = {
  '#a6e3a1', '#89b4fa', '#fab387', '#cba6f7', '#f9e2af', '#94e2d5', '#f5c2e7', '#b4befe',
}

--- The ticks of the mock, 12 to the second.
local function ticks(count)
  return count / 12
end

--- The effects: text drawn by a character. Characters that are one cell wide
--- whatever 'ambiwidth' says.
M.effects = {
  thought_bubble = {
    text = { '.', '. ∘', '. ∘ o' },
    colour = 'thought',
    place = 'above_right',
    seconds_per_frame = ticks(5),
  },
  reading_glyph = {
    text = { '=', '#' },
    colour = '#eff1f5',
    place = 'above_right',
    seconds_per_frame = ticks(4),
  },
  searching_glyph = {
    text = { '=', '#', '=', ' ' },
    colour = '#eff1f5',
    place = 'above_right',
    seconds_per_frame = ticks(3),
  },
  permission_hand = {
    text = { '! y/n?', ' ' },
    colour = 'warning',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  question_mark = {
    text = { '?', ' ' },
    colour = '#f9e2af',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  error_symbols = {
    text = { '#@!', '@!#', '!#@' },
    colour = 'warning',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  interrupted_marks = {
    text = { '!?', '!?', '!?', ' ' },
    colour = '#f9e2af',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  sparkle = {
    text = { '✦         ✧', '✧         ✦' },
    colour = '#a6e3a1',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  chat = {
    text = { '..', '..', ' ' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(5),
  },
  sleeping_z = {
    text = { 'z', 'z Z', 'z Z z', '  Z z', '    z' },
    colour = '#89b4fa',
    place = 'above_right',
    seconds_per_frame = ticks(6),
  },
  goodbye = {
    text = { 'bye', 'bye', ' ' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(5),
  },
  new_task = {
    text = { '!' },
    colour = '#f9e2af',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  yawn_mouth = {
    text = { 'o', 'O', 'O', 'o' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(4),
  },
  drumming_fingers = {
    text = { '.', '..', '...', '..' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(2),
  },
  watch_ticks = {
    text = { 'tick', 'tock' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(6),
  },
  glance_mark = {
    text = { '?', ' ' },
    colour = '#f9e2af',
    place = 'above_left',
    seconds_per_frame = ticks(6),
  },
  throw_in = {
    text = { 'in!' },
    colour = '#a6e3a1',
    place = 'above_right',
    seconds_per_frame = ticks(6),
    bold = true,
  },
  throw_miss = {
    text = { 'miss' },
    colour = 'warning',
    place = 'above_right',
    seconds_per_frame = ticks(6),
  },
  spin_swirl = {
    text = { '~', ' ' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(3),
  },
  job_spinner = {
    text = { '|', '/', '-', '\\' },
    colour = '#89dceb',
    place = 'above_right',
    seconds_per_frame = ticks(3),
  },
  committing_words = {
    text = { 'git', ' ' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(6),
  },
  doodling_marks = {
    text = { '~', ' ~', '  ~' },
    colour = '#89b4fa',
    place = 'above_right',
    seconds_per_frame = ticks(4),
  },
  angry = {
    text = { '#@!', '@!#' },
    colour = 'warning',
    place = 'above',
    seconds_per_frame = ticks(4),
    bold = true,
  },
  sweeping = {
    text = { '~', ' ~', '  ~' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(4),
  },
  purring = {
    text = { '~', ' ~', ' ' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(5),
  },
  cat_sleeping = {
    text = { 'z', ' z', ' ' },
    colour = '#cdd6f4',
    place = 'above_right',
    seconds_per_frame = ticks(8),
  },
}

--- The agent's poses: the layers of art, bottom first, and what a pose shows.
M.agent_poses = {
  standing = { art = { 'bean', 'bean_face_front', 'bean_legs_stand' } },
  walking = { art = { 'bean', 'bean_face_side', 'bean_legs_walk' } },
  sitting = { art = { 'bean_seated', 'bean_face_front' }, screen = 'screen_cursor' },
  typing_code = {
    art = { 'bean_seated', 'bean_face_side', 'bean_hands_fast' },
    screen = 'screen_code',
  },
  typing_command = {
    art = { 'bean_seated', 'bean_face_side', 'bean_hands_slow' },
    screen = 'screen_command',
  },
  typing_tests = {
    art = { 'bean_seated', 'bean_face_side', 'bean_hands_slow' },
    screen = 'screen_tests',
  },
  browsing = {
    art = { 'bean_seated', 'bean_face_side', 'bean_hands_slow' },
    screen = 'screen_web',
  },
  receiving_a_task = {
    art = { 'bean_receiving_a_task' },
    effect = 'new_task',
    screen = 'screen_cursor',
  },
  thinking = {
    art = { 'bean', 'bean_face_think', 'bean_legs_stand' },
    effect = 'thought_bubble',
  },
  writing = { art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_marker' } },
  reaching = { art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_reach' } },
  asking_permission = {
    art = { 'bean_seated', 'bean_face_wait', 'arm_raise_far' },
    effect = 'permission_hand',
    screen = 'screen_permission',
  },
  asking_a_question = {
    like = 'asking_permission',
    effect = 'question_mark',
  },
  scratching_its_head = {
    art = { 'bean_seated', 'bean_face_error', 'arm_scratch' },
    effect = 'error_symbols',
    screen = 'screen_error',
  },
  startled = {
    art = { 'bean_jumping', 'bean_face_startled', 'papers_flying' },
    rises = { 0, 3, 5, 6, 6, 5, 3, 1, 0, 0 },
    effect = 'interrupted_marks',
    screen = 'screen_interrupted',
  },
  stretching = {
    art = { 'bean', 'bean_face_happy', 'bean_legs_stand', 'arm_raise_both' },
    effect = 'sparkle',
  },
  yawning = {
    art = { 'bean', 'bean_face_yawn', 'bean_legs_stand', 'arm_yawn' },
    effect = 'yawn_mouth',
  },
  spinning = { art = { 'bean_spinning' }, effect = 'spin_swirl', screen = 'screen_cursor' },
  looking_out = { art = { 'bean', 'bean_face_back', 'bean_legs_stand' } },
  reading_a_book = { art = { 'bean', 'bean_face_down', 'book' } },
  watering = { art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_water' } },
  throwing_in = { art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_throw_in' } },
  throwing_out = { art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_throw_miss' } },
  cheering = { art = { 'bean', 'bean_face_happy', 'bean_legs_stand' }, effect = 'throw_in' },
  dismayed = {
    art = { 'bean', 'bean_face_error', 'bean_legs_stand', 'paper_ball_on_the_floor' },
    effect = 'throw_miss',
  },
  drinking = { art = { 'bean', 'bean_face_front', 'bean_legs_stand', 'arm_drink' } },
  tidying_the_desk = {
    art = { 'bean_seated', 'bean_face_down', 'desk_tidying' },
    screen = 'screen_cursor',
  },
  drumming = {
    art = { 'bean_seated', 'bean_face_side', 'bean_hands_fast' },
    effect = 'drumming_fingers',
    screen = 'screen_cursor',
  },
  looking_at_the_watch = {
    art = { 'bean', 'bean_face_wait', 'bean_legs_stand', 'arm_watch' },
    effect = 'watch_ticks',
  },
  glancing = { art = { 'bean', 'bean_face_side', 'bean_legs_stand' }, effect = 'glance_mark' },
  tapping_a_foot = { art = { 'bean', 'bean_face_side', 'bean_legs_tap' } },
  sleeping = {
    art = { 'bean', 'bean_face_sleep' },
    rises = { -1 },
    effect = 'sleeping_z',
  },
  sitting_on_the_sofa = { art = { 'bean', 'bean_face_front' } },
  chatting_on_the_sofa = { art = { 'bean', 'bean_face_happy' }, effect = 'chat' },
  sipping_coffee = { art = { 'bean', 'bean_face_front', 'arm_hold_cup_sofa' } },
  waving = {
    art = { 'bean', 'bean_face_happy', 'bean_legs_stand', 'arm_wave_far' },
    effect = 'goodbye',
  },
  packing = { art = { 'bean', 'bean_face_front', 'bean_legs_stand', 'packing_props' } },
  holding_a_task = { art = { 'bean', 'bean_face_front', 'bean_legs_stand', 'arm_hold_paper' } },
  giving_a_task = { art = { 'bean', 'bean_face_front', 'bean_legs_stand', 'arm_give_paper' } },
  playing_table_tennis = {
    art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_paddle' },
  },
  cleaning = {
    art = { 'bean', 'bean_face_side', 'bean_legs_stand', 'arm_pet' },
    effect = 'sweeping',
  },
  grumbling = {
    art = { 'bean', 'bean_face_error', 'bean_legs_stand' },
    effect = 'angry',
  },
  looking_at_the_watch_seated = {
    art = { 'bean_seated', 'bean_face_wait', 'arm_watch' },
    effect = 'watch_ticks',
    screen = 'screen_permission',
  },
  glancing_seated = {
    art = { 'bean_seated', 'bean_face_side' },
    effect = 'glance_mark',
    screen = 'screen_permission',
  },
  drumming_seated = {
    like = 'drumming',
    screen = 'screen_permission',
  },
}

--- The cat's poses.
M.cat_poses = {
  standing = { art = { 'cat_sit' } },
  walking = { art = { 'cat_walk' } },
  washing = { art = { 'cat_wash' } },
  sleeping = { art = { 'cat_sleep' }, effect = 'cat_sleeping' },
  sleeping_on_a_seat = { art = { 'cat_sleep_on_a_seat' }, effect = 'cat_sleeping' },
  sitting_on_a_desk = { art = { 'cat_sit_on_a_desk' } },
  rubbing = { art = { 'cat_rub' }, effect = 'purring' },
  purring = { art = { 'cat_sit' }, effect = 'purring' },
}

--- What plays in each state.
M.states = {
  standing = 'stand_by_the_desk',
  working = 'write_code',
  waiting = 'wait_for_subagents',
  resting = 'rest_on_the_sofa',
  arriving = 'walk_in',
  getting_a_task = 'receive_a_task',
  thinking = 'think_at_the_whiteboard',
  planning = 'plan_on_the_whiteboard',
  reading = 'read_from_the_cabinet',
  searching = 'search_the_cabinet',
  writing_code = 'write_code',
  running_a_command = 'run_a_command',
  running_tests = 'run_the_tests',
  background_job = 'keep_a_job_running',
  on_the_web = 'browse_the_web',
  delegating = 'hand_a_task_over',
  waiting_for_subagents = 'wait_for_subagents',
  needs_permission = 'wait_for_permission',
  asking_you = 'ask_a_question',
  reporting = 'report_at_the_printer',
  committing = 'commit_changes',
  compacting = 'tidy_up_the_notes',
  error = 'hit_an_error',
  interrupted = 'get_interrupted',
  done = 'finish_up',
  idle = 'rest_on_the_sofa',
  asleep = 'sleep_on_the_sofa',
  leaving = 'pack_up_and_leave',
}

local DURING_IDLE = { 'idle' }
local DURING_WAITING = { 'waiting', 'waiting_for_subagents' }
local DURING_PERMISSION = { 'needs_permission' }
local DURING_CAT = { 'always' }

--- The activities, in the order the pack lists them.
---@type { [1]: string, [2]: table }[]
M.activities = {
  -- What each state plays.
  {
    'stand_by_the_desk',
    {
      about = 'Stands in the aisle beside its desk.',
      steps = { { at = 'beside_desk', pose = 'standing' } },
    },
  },
  {
    'walk_in',
    {
      about = 'Comes in through the door, walks to its desk and sits down.',
      steps = { { at = 'door', for_seconds = 0.5 }, { at = 'desk', pose = 'sitting' } },
    },
  },
  {
    'receive_a_task',
    {
      about = 'Sits at its desk: a sheet of paper drops on it, lies there, and is picked up.',
      steps = {
        { at = 'desk', pose = 'receiving_a_task', for_seconds = 3.4 },
        { at = 'desk', pose = 'sitting' },
      },
    },
  },
  {
    'think_at_the_whiteboard',
    {
      about = 'Stands at the whiteboard with a thought bubble over its head.',
      steps = { { at = 'whiteboard', pose = 'thinking' } },
    },
  },
  {
    'plan_on_the_whiteboard',
    {
      about = 'Writes the session\'s tasks on the whiteboard; the board shows the real ones.',
      steps = { { at = 'whiteboard', pose = 'writing' } },
    },
  },
  {
    'read_from_the_cabinet',
    {
      about = 'Stands at the file cabinet and reaches into a drawer, which opens.',
      steps = { { at = 'file_cabinet', pose = 'reaching', effect = 'reading_glyph' } },
    },
  },
  {
    'search_the_cabinet',
    {
      about = 'Opens the drawers of the file cabinet one after another.',
      steps = { { at = 'file_cabinet', pose = 'reaching', effect = 'searching_glyph' } },
    },
  },
  {
    'write_code',
    {
      about = 'Sits at its desk and types fast; code fills its screen.',
      steps = { { at = 'desk', pose = 'typing_code' } },
    },
  },
  {
    'run_a_command',
    {
      about = 'Sits at its desk; a command runs and its output scrolls on the screen.',
      steps = { { at = 'desk', pose = 'typing_command' } },
    },
  },
  {
    'run_the_tests',
    {
      about = 'Sits at its desk while the tests run: dots fill in on the screen, then the verdict shows.',
      steps = { { at = 'desk', pose = 'typing_tests' } },
    },
  },
  {
    'keep_a_job_running',
    {
      about = 'Sits at its desk while a job runs in the background, a spinner over its head.',
      steps = { { at = 'desk', pose = 'typing_command', effect = 'job_spinner' } },
    },
  },
  {
    'browse_the_web',
    {
      about = 'Sits at its desk looking something up; the monitor shows a browser, and what it looks up.',
      steps = { { at = 'desk', pose = 'browsing' } },
    },
  },
  {
    'hand_a_task_over',
    {
      about = 'Stands beside its desk with a sheet of paper, turns, and holds it out.',
      steps = {
        { at = 'beside_desk', facing = 'left', pose = 'holding_a_task', for_seconds = 1.2 },
        { at = 'beside_desk', pose = 'giving_a_task', for_seconds = 1 },
        { at = 'beside_desk', pose = 'standing' },
      },
    },
  },
  {
    'wait_for_subagents',
    {
      about = 'Taps its foot beside its desk, then sits and waits.',
      steps = {
        { at = 'beside_desk', pose = 'tapping_a_foot', for_seconds = 1.2 },
        { at = 'desk', pose = 'sitting', for_seconds = 5 },
      },
    },
  },
  {
    'wait_for_permission',
    {
      about = 'Sits at its desk with a hand up and a "!" over its head; "y/n?" asks on the screen.',
      steps = {
        { at = 'desk', pose = 'asking_permission', for_seconds = 1.8 },
        { at = 'desk', pose = 'asking_permission', for_seconds = 3.2 },
      },
    },
  },
  {
    'ask_a_question',
    {
      about = 'Sits at its desk with a hand up and a "?" over its head, waiting for an answer.',
      steps = { { at = 'desk', pose = 'asking_a_question' } },
    },
  },
  {
    'report_at_the_printer',
    {
      about = 'Walks to the printer and waits there while a page prints.',
      steps = { { at = 'printer', pose = 'glancing', facing = 'left' } },
    },
  },
  {
    'commit_changes',
    {
      about = 'Sits at its desk typing a command, "git" blinking over its head.',
      steps = { { at = 'desk', pose = 'typing_command', effect = 'committing_words' } },
    },
  },
  {
    'tidy_up_the_notes',
    {
      about = 'Sits at its desk and tidies its papers into a stack.',
      steps = { { at = 'desk', pose = 'tidying_the_desk' } },
    },
  },
  {
    'hit_an_error',
    {
      about = 'Sits at its desk scratching its head, "#@!" over it; the screen flashes red.',
      steps = { { at = 'desk', pose = 'scratching_its_head' } },
    },
  },
  {
    'get_interrupted',
    {
      about = 'Jumps up at its desk and throws its papers into the air, then sits down again.',
      steps = {
        { at = 'desk', pose = 'startled', for_seconds = 4.6 },
        { at = 'desk', pose = 'sitting' },
      },
    },
  },
  {
    'finish_up',
    {
      about = 'Stretches with a sparkle, gets a cup at the coffee machine and takes it to the sofa.',
      steps = {
        { at = 'beside_desk', pose = 'stretching', for_seconds = 1.8 },
        { at = 'coffee_machine', pose = 'reaching', for_seconds = 2.6 },
        { at = 'sofa', pose = 'sipping_coffee' },
      },
    },
  },
  {
    'rest_on_the_sofa',
    {
      about = 'Sits on the sofa with a cup, chatting with whoever sits beside it.',
      steps = {
        { at = 'sofa', pose = 'sipping_coffee', for_seconds = 3 },
        { at = 'sofa', pose = 'chatting_on_the_sofa', for_seconds = { 3, 6 } },
      },
    },
  },
  {
    'sleep_on_the_sofa',
    {
      about = 'Dozes off on the sofa, "z Z" rising.',
      steps = { { at = 'sofa', pose = 'sleeping' } },
    },
  },
  {
    'pack_up_and_leave',
    {
      about = 'Packs its things into a box, walks to the door and waves goodbye.',
      steps = {
        { at = 'beside_desk', pose = 'packing', for_seconds = 1.6 },
        { at = 'door', pose = 'waving' },
      },
    },
  },

  -- What an idle agent does when its state goes on.
  {
    'stretch',
    {
      about = 'Stretches where it is, a sparkle over its head.',
      label = 'stretches',
      during = DURING_IDLE,
      chance = 3,
      steps = { { pose = 'stretching', for_seconds = { 1.5, 2.5 } } },
    },
  },
  {
    'yawn',
    {
      about = 'Yawns, its arms over its head.',
      label = 'yawns',
      during = DURING_IDLE,
      chance = 3,
      steps = { { pose = 'yawning', for_seconds = { 1.4, 2.2 } } },
    },
  },
  {
    'spin_in_the_chair',
    {
      about = 'Goes to its desk and turns round in its chair, front, side and back.',
      label = 'spins in the chair',
      during = DURING_IDLE,
      chance = 2,
      steps = {
        { at = 'desk', pose = 'spinning', for_seconds = { 2, 3 } },
        { at = 'desk', pose = 'sitting', for_seconds = { 0.5, 1 } },
      },
    },
  },
  {
    'look_out_of_the_window',
    {
      about = 'Goes to the window and looks out at the sky.',
      label = 'looks out of the window',
      during = DURING_IDLE,
      chance = 2,
      steps = { { at = 'window', pose = 'looking_out', for_seconds = { 2.5, 4 } } },
    },
  },
  {
    'read_a_book_on_the_sofa',
    {
      about = 'Sits on the sofa and reads a book.',
      label = 'reads a book on the sofa',
      during = DURING_IDLE,
      chance = 2,
      steps = { { at = 'sofa', pose = 'reading_a_book', for_seconds = { 3, 5 } } },
    },
  },
  {
    'water_the_snake_plant',
    {
      about = 'Goes to the snake plant on the wall and waters it.',
      label = 'waters the plant',
      during = DURING_IDLE,
      chance = 2,
      steps = { { at = 'snake_plant', pose = 'watering', for_seconds = { 2, 3 } } },
    },
  },
  {
    'water_the_corner_plant',
    {
      about = 'Goes to the plant in the corner and waters it.',
      label = 'waters the plant',
      during = DURING_IDLE,
      chance = 1,
      steps = { { at = 'corner_plant', pose = 'watering', for_seconds = { 2, 3 } } },
    },
  },
  {
    'throw_a_paper_ball_in_the_bin',
    {
      about = 'Goes to the bin, throws a paper ball in an arc, and cheers when it lands in.',
      label = 'throws a paper ball at the bin',
      during = DURING_IDLE,
      chance = 1.4,
      steps = {
        { at = 'trash_bin', pose = 'throwing_in', for_seconds = 1.85 },
        { at = 'trash_bin', pose = 'cheering', for_seconds = 1.2 },
      },
    },
  },
  {
    'throw_a_paper_ball_and_miss',
    {
      about = 'Goes to the bin, throws a paper ball, and groans when it misses and lands on the floor.',
      label = 'throws a paper ball at the bin',
      during = DURING_IDLE,
      chance = 0.6,
      steps = {
        { at = 'trash_bin', pose = 'throwing_out', for_seconds = 1.85 },
        { at = 'trash_bin', pose = 'dismayed', for_seconds = 1.2 },
      },
    },
  },
  {
    'get_a_drink_at_the_water_cooler',
    {
      about = 'Goes to the water cooler and drinks a cup of water.',
      label = 'chats at the water cooler',
      during = DURING_IDLE,
      chance = 2,
      steps = { { at = 'water_cooler', pose = 'drinking', for_seconds = { 2.5, 4 } } },
    },
  },
  {
    'doodle_on_the_whiteboard',
    {
      about = 'Goes to the whiteboard and doodles on it with the marker.',
      label = 'doodles on the whiteboard',
      during = DURING_IDLE,
      chance = 1,
      steps = {
        { at = 'whiteboard', pose = 'writing', effect = 'doodling_marks', for_seconds = { 2, 3 } },
      },
    },
  },
  {
    'tidy_the_desk',
    {
      about = 'Sits at its desk and tidies its papers into a stack.',
      label = 'tidies the desk',
      during = DURING_IDLE,
      chance = 2,
      steps = { { at = 'desk', pose = 'tidying_the_desk', for_seconds = { 2, 3 } } },
    },
  },
  {
    'nap_on_the_sofa',
    {
      about = 'Curls up on the sofa for a nap, "z Z" rising.',
      label = 'naps on the sofa',
      during = DURING_IDLE,
      chance = 1,
      steps = { { at = 'sofa', pose = 'sleeping', for_seconds = { 3, 4.5 } } },
    },
  },
  {
    'play_table_tennis',
    {
      about = 'Two idle agents go to the table-tennis table, one at each end, and play a rally.',
      label = 'plays table tennis',
      during = DURING_IDLE,
      chance = 1,
      players = 2,
      steps = { { at = 'table_tennis', pose = 'playing_table_tennis', for_seconds = { 6, 10 } } },
    },
  },

  -- What an agent waiting for its subagents does.
  {
    'drum_its_fingers',
    {
      about = 'Sits at its desk drumming its fingers.',
      label = 'drums its fingers',
      during = DURING_WAITING,
      chance = 3,
      steps = { { at = 'desk', pose = 'drumming', for_seconds = { 1.5, 3 } } },
    },
  },
  {
    'look_at_its_watch',
    {
      about = 'Looks at its watch, where it stands.',
      label = 'looks at its watch',
      during = DURING_WAITING,
      chance = 2,
      steps = { { pose = 'looking_at_the_watch', for_seconds = { 1.4, 2.2 } } },
    },
  },
  {
    'pace_beside_the_desk',
    {
      about = 'Paces to the left of its desk and to the right and back.',
      label = 'paces beside the desk',
      during = DURING_WAITING,
      chance = 2,
      steps = {
        { at = 'left_of_desk', for_seconds = { 0, 0 } },
        { at = 'right_of_desk', for_seconds = { 0, 0 } },
        { at = 'left_of_desk', for_seconds = { 0, 0 } },
        { at = 'beside_desk', for_seconds = { 0.3, 0.6 } },
      },
    },
  },
  {
    'glance_at_the_door',
    {
      about = 'Turns and glances at the door, a "?" over its head.',
      label = 'glances at the door',
      during = DURING_WAITING,
      chance = 2,
      steps = { { facing = 'left', pose = 'glancing', for_seconds = { 1.2, 2 } } },
    },
  },
  {
    'tap_a_foot',
    {
      about = 'Taps its foot beside its desk.',
      label = 'taps its foot',
      during = DURING_WAITING,
      chance = 2,
      steps = { { at = 'beside_desk', pose = 'tapping_a_foot', for_seconds = { 1.5, 2.5 } } },
    },
  },

  -- What an agent waiting for an answer does, seated, its hand still up on screen.
  {
    'drum_its_fingers_and_wait',
    {
      about = 'Drums its fingers at its desk while it waits for an answer.',
      label = 'drums its fingers',
      during = DURING_PERMISSION,
      chance = 3,
      steps = {
        { at = 'desk', pose = 'drumming_seated', effect = 'permission_hand', for_seconds = { 1.2, 2 } },
      },
    },
  },
  {
    'look_at_its_watch_and_wait',
    {
      about = 'Looks at its watch at its desk while it waits for an answer.',
      label = 'looks at its watch',
      during = DURING_PERMISSION,
      chance = 2,
      steps = {
        {
          at = 'desk',
          pose = 'looking_at_the_watch_seated',
          effect = 'permission_hand',
          for_seconds = { 1.2, 1.8 },
        },
      },
    },
  },
  {
    'glance_at_the_door_and_wait',
    {
      about = 'Turns in its chair and glances at the door while it waits for an answer.',
      label = 'glances at the door',
      during = DURING_PERMISSION,
      chance = 2,
      steps = {
        {
          at = 'desk',
          facing = 'left',
          pose = 'glancing_seated',
          effect = 'permission_hand',
          for_seconds = { 1, 1.6 },
        },
        { at = 'desk', facing = 'right', pose = 'asking_permission', for_seconds = { 0, 0 } },
      },
    },
  },

  -- What the agents do about what the cat leaves.
  {
    'grumble',
    {
      about = 'Is upset by what the cat left near it: "#@!" over its head.',
      label = 'is upset by what the cat left',
      steps = { { pose = 'grumbling', for_seconds = 2.5 } },
    },
  },
  {
    'clean_up_the_mess',
    {
      about = 'The idle agent nearest to the mess goes to it, cleans it up, and goes to the bin.',
      label = 'cleans up the mess',
      steps = {
        { at = 'mess', pose = 'cleaning', for_seconds = { 2, 3 }, remove = 'mess' },
        { at = 'trash_bin', pose = 'standing', for_seconds = 1 },
      },
    },
  },
  {
    'mop_up_the_puddle',
    {
      about = 'The idle agent nearest to the puddle goes to it, mops it up, and goes to the bin.',
      label = 'mops up the puddle',
      steps = {
        { at = 'puddle', pose = 'cleaning', for_seconds = { 2, 3 }, remove = 'puddle' },
        { at = 'trash_bin', pose = 'standing', for_seconds = 1 },
      },
    },
  },
  {
    'leave_in_a_huff',
    {
      about = 'Is turned off its seat by the cat: grumbles, and goes to stand beside its desk.',
      label = 'leaves in a huff',
      steps = {
        { pose = 'grumbling', for_seconds = 1.5 },
        { at = 'beside_desk', pose = 'standing', for_seconds = { 0, 0 } },
      },
    },
  },

  -- The cat's own life.
  {
    'wander_the_aisles',
    {
      about = 'The cat walks somewhere and sits down for a moment.',
      label = 'wanders the aisles',
      who = 'cat',
      during = DURING_CAT,
      chance = 4,
      steps = {
        { at = 'anywhere', for_seconds = { 0, 0 } },
        { pose = 'standing', for_seconds = { 0.8, 2 } },
      },
    },
  },
  {
    'sit_and_wash',
    {
      about = 'The cat sits and washes itself.',
      label = 'sits and washes',
      who = 'cat',
      during = DURING_CAT,
      chance = 3,
      steps = { { pose = 'washing', for_seconds = { 2.5, 4 } } },
    },
  },
  {
    'sleep_on_a_seat',
    {
      about = 'The cat curls up asleep on a free seat of the sofa, for a long time: cats are lazy.',
      label = 'sleeps on the sofa',
      who = 'cat',
      during = DURING_CAT,
      chance = 5,
      steps = { { at = 'sofa', pose = 'sleeping_on_a_seat', for_seconds = { 60, 180 } } },
    },
  },
  {
    'jump_on_an_empty_desk',
    {
      about = 'The cat jumps on a desk nobody sits at and sits there.',
      label = 'jumps on an empty desk',
      who = 'cat',
      during = DURING_CAT,
      chance = 2,
      steps = { { at = 'an_empty_desk', pose = 'sitting_on_a_desk', for_seconds = { 2, 4 } } },
    },
  },
  {
    'sit_on_a_keyboard',
    {
      about = 'The cat sits on the desk of an idle agent who is away from it.',
      label = 'sits on a keyboard',
      who = 'cat',
      during = DURING_CAT,
      chance = 2,
      steps = { { at = 'an_idle_agents_desk', pose = 'sitting_on_a_desk', for_seconds = { 3, 5 } } },
    },
  },
  {
    'rub_against_legs',
    {
      about = 'The cat goes to an agent who stands still and rubs against its legs.',
      label = 'rubs against legs',
      who = 'cat',
      during = DURING_CAT,
      chance = 2,
      steps = { { at = 'next_to_an_agent', pose = 'rubbing', for_seconds = { 2, 3 } } },
    },
  },
  {
    'follow_someone',
    {
      about = 'The cat trails an agent that walks.',
      label = 'follows someone',
      who = 'cat',
      during = DURING_CAT,
      chance = 2,
      steps = { { pose = 'walking', follow = 'someone_walking', for_seconds = { 3, 5 } } },
    },
  },
  {
    'stare_at_the_fish',
    {
      about = 'The cat sits in front of the fish tank and stares at the fish.',
      label = 'stares at the fish',
      who = 'cat',
      during = DURING_CAT,
      chance = 2,
      steps = { { at = 'fish_tank', pose = 'standing', for_seconds = { 3, 5 } } },
    },
  },
  {
    'leave_a_mess',
    {
      about = 'The cat goes somewhere on the floor, sits, and leaves a mess that angers the agents near it.',
      label = 'leaves a mess',
      who = 'cat',
      during = DURING_CAT,
      chance = 1,
      steps = {
        { at = 'anywhere', for_seconds = { 0, 0 } },
        { pose = 'standing', for_seconds = 2, leave = 'mess' },
      },
    },
  },
  {
    'leave_a_puddle',
    {
      about = 'The cat goes somewhere on the floor, squats, and leaves a puddle that angers the agents near it.',
      label = 'leaves a puddle',
      who = 'cat',
      during = DURING_CAT,
      chance = 1,
      steps = {
        { at = 'anywhere', for_seconds = { 0, 0 } },
        { pose = 'standing', for_seconds = 2, leave = 'puddle' },
      },
    },
  },
  {
    'take_an_occupied_seat',
    {
      about = 'The cat takes the sofa seat an agent sits on; the agent leaves in a huff.',
      label = 'takes someone\'s seat',
      who = 'cat',
      during = DURING_CAT,
      chance = 1,
      steps = {
        {
          at = 'sofa',
          pose = 'sleeping_on_a_seat',
          even_if_taken = true,
          the_one_moved_plays = 'leave_in_a_huff',
          for_seconds = { 30, 90 },
        },
      },
    },
  },
}

--- What the activities leave behind.
M.things = {
  mess = {
    piece = 'cat_mess',
    upsets_agents_within = 16,
    upset_agents_play = 'grumble',
    cleaned_up_by = 'clean_up_the_mess',
  },
  puddle = {
    piece = 'cat_puddle',
    upsets_agents_within = 16,
    upset_agents_play = 'grumble',
    cleaned_up_by = 'mop_up_the_puddle',
  },
}

return M
