# The converter of the default office pack (T133)

Run once, 2026-10-23, to make `aineo-office/default/` from the approved mock (the mock v4, its `lua/agent-office/` folder: `sprites.lua`, `behaviours.lua`, `layout.lua`, `demo.lua`, `stage.lua`). Its output is committed; nothing ships from here and nothing requires it. The mock's folder is read, never copied into the repository.

```
nvim --headless --clean -l main.lua <the mock's folder> <the pack's folder>   # aineo-office/default
```

It replaces the pack's `art/`, `floor.txt` and `pack.lua`, and prints how many pieces and colours it wrote and how the pack's activities differ from the mock's `behaviours.lua` (`compare.lua`).

| File | Does |
|---|---|
| `main.lua` | reads the mock's sprites, builds every piece, writes the art files, the plan and `pack.lua`; refuses a pack of more than 64 colours |
| `palette.lua` | the mock's hexes merged into the 58 the pack names, each named by role |
| `art.lua` | pixel canvases of colour names; the art file's text |
| `furniture.lua` | the wall's fixtures, the desks, the lounge, the decorations and the four skies, from the mock's sprite tables, each given the anchor that puts it where the mock drew it |
| `bean.lua` | the bean's body, faces, legs and hands, the arms with what they hold, and the poses whose motion is drawn frame by frame (the paper that falls on the desk, the papers thrown up, a paper ball thrown, tidying, spinning) |
| `extras.lua` | the monitor's screens (the mock's `screen_v3` sampled at 12 frames a second), the baseboard, the table-tennis table, the cat's poses, what the cat leaves |
| `plan.lua` | the floor plan, drawn by code so that every column and row lines up with the art, and its legend |
| `definitions.lua` | what was written by hand: the poses, the effects, the activities, what plays in each state, the things |
| `serialize.lua` | `pack.lua`, as table literals of the subset the pack reader takes |
| `compare.lua` | the label, the chance and the times of the pack's random-life activities against the mock's `behaviours.lua` |

How a mock piece becomes a piece: its rows are the art's rows; its palette's letters are named in the art's `colours:` header, and its hexes in `pack.lua`'s `colours`; a list of frames is one file, the frames separated by `---`; a function of the width is the art at its narrowest width with the columns that repeat in `stretch:`; a function of time is sampled (at 12 frames a second until it repeats, or at the pace of its change) into frames, or becomes an `area` that aineo draws into (the clock's time, the calendar's date, the window's sky, the printer's page, the monitor's screen and query, the whiteboard's plan). The mock's pixel coordinates are kept: a piece the mock stood on the baseboard (feet at pixel 27) is placed on cell row 12, and its last two pixel rows hang over the aisle row below.
