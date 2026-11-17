# White Shift - design

Status: phase 1 (digital prototype), built and playable at https://play.whiteshift.steefbeest.nl. Built on White Kit
v0.1.0 since 2026-11-17 (section 13, ADR 0005).
This document describes the game as decided and built. Decisions with their trade-offs are in `docs/adr/`;
terms are defined in `docs/glossary.md`; code and test rules are in `docs/conventions.md`.

## 1. Purpose

White Shift is a daily sliding puzzle for players aged 10 and up and adults. Every day there are three puzzles
(easy, medium, hard), identical for everyone, changing at midnight Dutch time. The player gets a white stone out
of a walled board in as few swipes as possible.

The phase 1 prototype exists to answer three questions:

1. Does the core rule force the player to think ahead (is a greedy approach punished)?
2. Are there "aha" moments, for example moving a blocker out of the way with the same swipe that moves the stone?
3. Is the generator good enough to produce three puzzles of distinct difficulty every day?

Out of scope for phase 1: accounts, leaderboards, a server, art, sound, Android/Windows builds.

## 2. Rules

### 2.1 Board and coordinates

- A rectangular board of `w x h` cells (all generated boards are square), surrounded by a wall.
- Coordinates: `x` grows to the right, `y` grows downwards, `(0, 0)` is the top-left cell.
- Exactly one exit: a one-cell opening in the wall, given by a side (`R`, `L`, `D`, `U` = right, left, bottom,
  top wall) and an index (the row for the left/right wall, the column for the top/bottom wall).

### 2.2 Pieces

| Kind | Code | Size | May move | Notes |
|---|---|---|---|---|
| White stone | `WHITE` (0) | 1x1 | right, left, down, up | Exactly one, always piece index 0. The only piece that can use the exit. |
| Block | `BLOCK` (1) | 1x1 | right, left, down, up | |
| Horizontal bar | `HBAR` (2) | 2 or 3 cells wide, 1 high | right, left | Never moves on a down/up swipe. |
| Vertical bar | `VBAR` (3) | 1 wide, 2 or 3 cells high | down, up | Never moves on a right/left swipe. |
| Pin | - | 1x1 | never | Fixed obstacle; stored separately from pieces. |

A bar's position is its top-left cell; it occupies `len` cells to the right (`HBAR`) or downwards (`VBAR`).

### 2.3 Swipe

A swipe has one direction: `R`, `L`, `D` or `U`.

1. Every piece that may move in that direction slides as far as it can. A piece that may not move in that
   direction (a bar across its axis, a pin) stays where it is and is an obstacle for this swipe.
2. Pieces are processed from the wall the swipe moves towards: the piece whose leading edge is nearest to that
   wall goes first. Each piece slides cell by cell until the next cell is a wall, a pin or any piece (moved or not).
   As a result, movable pieces in a line close up against each other and against the first obstacle; nothing
   pushes anything, and pieces never merge.
3. The exit is wall for every piece except the white stone.
4. The white stone leaves the board when the swipe points at the exit wall and its slide reaches the wall exactly
   at the exit index (it is in the exit row/column with nothing in between). The puzzle is then solved.
   Pieces behind the white stone in the same swipe may slide into the cells it vacated.
5. A swipe that changes nothing is a no-op: it is ignored completely (not counted, not recorded, no history entry).
6. After the puzzle is solved, every further swipe is a no-op; undo and restart are disabled.

Worked example (also a regression test): 5x5, exit right wall row 2; white at (0,1), vertical bar len 2 at (3,1),
horizontal bar len 2 at (0,3), block at (4,4).

```
start          after D        after R
.....          .....          solved: the white stone
W..V.          .....          slides along row 2 and
...V.          W....          leaves through the exit
HH...          HH.V.
....o          ...Vo
```

Swiping `R` first instead stops the white stone against the vertical bar at (2,1); the horizontal bar slides to
the right wall.

### 2.4 Counting, undo and restart

- The score of an attempt is the number of effective swipes (swipes that changed the state).
- Undo returns to the state before the last effective swipe. Restart returns to the start position and clears
  the undo history (undo cannot go back across a restart).
- Undo and restart are free, but they never lower the count: every effective swipe made in the attempt counts,
  including swipes that were later undone or discarded by a restart. See ADR 0002. In White Kit terms this is the
  count mode `EVERY_MOVE`, used for daily and practice puzzles alike.
- Undo and restart are only possible when there is history and the puzzle is not solved; otherwise they are
  no-ops and are not recorded.

### 2.5 Par

Par is the exact minimum number of effective swipes needed to get the white stone out, computed by the solver
(section 4). A result equal to par is "exactly par". The prototype shows par during play (phase 1 aid for judging
difficulty; whether it stays visible is a phase 2 decision).

## 3. Levels

Each level has its own generator parameters (`ShiftGenerator.LEVELS`):

| Level | Board | Other pieces | Pins | Par band | Max shortest solutions | Layouts tried |
|---|---|---|---|---|---|---|
| Easy (0) | 5x5 | 4-7 | 0-1 | 4-7 | 6 | 600 |
| Medium (1) | 6x6 | 7-11 | 0-2 | 8-12 | 4 | 900 |
| Hard (2) | 6x6 or 7x7 | 9-14 | 0-2 | 13-24 | 4 | 1500 |

- "Other pieces" excludes the white stone. Mix of other pieces: 30% blocks, 35% horizontal bars, 35% vertical
  bars; a bar is 2 long (65%) or 3 long (35%). Pieces and pins that would overlap are skipped, so a layout can
  end up with fewer than drawn.
- Every puzzle contains at least one horizontal and one vertical bar, so the core rule is always in play.
- Par must be at least 2.
- "Max shortest solutions" limits how many distinct shortest swipe sequences a puzzle may have; more means the
  par route is too easy to stumble on.
- The upper bound of 24 on hard was added after the generator trial produced puzzles of 29 swipes.
- The bands are provisional; phase 2 tunes them after play testing.

## 4. Solver and generator

### 4.1 State

A state is a `PackedInt32Array`: `[x0, y0, x1, y1, ..., won]` with the top-left cell of every piece in piece
order and a final flag that is 1 once the white stone has left. Pins and piece kinds/lengths are part of the
board, not of the state.

### 4.2 Swipe implementations

`ShiftBoard.swipe()` is the fast version (one scan over a cell grid from the target wall).
`ShiftBoard.swipe_reference()` is a straightforward version (sort movable pieces by leading edge, slide each).
Both must return identical states for every board, state and direction; the tests enforce this.

`ShiftBoard` also implements White Kit's rules interface (`extends WhiteRules`, kit design 5.6), so the kit's attempt
can play it: `start_state()` is `start`; `apply(state, dir)` is `swipe(state, dir)`, or `null` for a no-op swipe;
`is_solved(state)` is `is_won(state)`; a move is a direction `0..3` and its token is one letter of `LETTERS`
(`R L D U`).

### 4.3 Solver (`ShiftSolver.solve`)

- Breadth-first search over reachable states, layer by layer; a no-op swipe is not an edge.
- Returns `par` (depth of the first layer that reaches a won state), `solutions` (number of distinct shortest
  swipe sequences, saturating at 2^40), `path` (one shortest sequence), `states` (states visited) and `capped`.
- A state limit (`max_states`, default 200000; the generator uses 60000) bounds the work. When the limit is hit
  the result is `par = -1` with `capped = true`; an unsolvable board also gives `par = -1`.

### 4.4 Generator (`ShiftGenerator.generate`)

- Input: a 64-bit seed and a level. The seed is FNV-1a 64-bit over the UTF-8 bytes of a text
  (`ShiftGenerator.seed_for`, which calls `WhiteSeed.fnv1a64` from White Kit):
  - daily puzzle: `white-shift|<YYYY-MM-DD>|<level>` (level `0`, `1` or `2`), e.g. `white-shift|2026-11-17|2`;
  - practice set: `white-shift-practice|<i>|<level>`.
  FNV-1a was chosen so another implementation (a server) can compute the same seed.
- The seed initialises White Kit's `WhiteRng` (xoshiro128**, integer-only, kit ADR 0002). Its output for a seed is
  frozen and checked against a Python reference, so the sequence of random numbers is the same on every platform and
  Godot version. Reproducing a board from a seed requires the same generator code (`ShiftGenerator`, including
  `LEVELS` and `MIX`) and `WhiteRng`; with those, any implementation can rebuild it. The board JSON (section 5.2)
  remains the portable form of a published puzzle.
- Random draws: `rng.range_int(a, b)` (inclusive) for sizes, sides, indexes, counts and cells; `rng.next_float()` for
  the piece kind and bar length rolls.
- Loop up to "layouts tried" times: draw a random layout (board size, exit side and index, pins, white stone,
  other pieces), discard it unless it has both bar kinds, solve it, and return the first layout whose par is in
  the band and whose shortest-solution count is within the maximum.
- Fallback when no layout fits: the layout nearest to the band (then fewest shortest solutions). In the original
  trial no fallback was needed (10 of 10 days in band; median 2 / 5 / 8 layouts tried for easy / medium / hard).
  After the switch to `WhiteRng`, `tools/measure.gd --days=30` gave 30 of 30 days in band without fallback on every
  level; par ranges easy 4-7, medium 8-12, hard 13-22.
- Fully deterministic: the same seed and level give the same puzzle on every machine running the same code.
- History: until 2026-11-17 the generator used Godot's `RandomNumberGenerator`. All puzzles published in `data/` were
  built with that version (section 5.2). The current generator gives different boards for the same seeds; the
  published data is not regenerated (ADR 0001, ADR 0005).

## 5. Precomputed puzzles

### 5.1 Why

Generation time on a desktop PC: easy about 3 ms, medium about 0.2 s (max 10 s), hard about 6 s (max 22 s). That
is too slow for a phone browser. Puzzles are therefore computed ahead of time and shipped with the game; the game
itself never searches. See ADR 0001. (Medians measured after the switch to `WhiteRng`, on a busy machine:
13 ms / 0.18 s / 3.6 s; a precompute concern only.)

### 5.2 Files and format

- `data/daily.json`: daily puzzles by date. Currently 60 days, 2026-11-17 to 2027-01-15, all built with the former
  `RandomNumberGenerator` generator.
- `data/practice.json`: practice sets keyed `"0"`, `"1"`, ...; currently 45 sets, built with the former generator.
  The game picks a set by its position in the file (keys are stored sorted as text), not by the numeric key.
- Days and sets added from now on are built with the `WhiteRng` generator and merged (section 5.3). The file does not
  record which generator built a key; the format and the checks are the same for both.
- Both: `{"<key>": [easy, medium, hard]}`, each puzzle:

```json
{
  "board": {"n": [w, h], "exit": [side, index], "pins": [[x, y]], "pieces": [[kind, x, y, len]]},
  "par": 9,
  "solutions": 2,
  "path": "DRUL..."
}
```

`side` uses the direction codes `R=0, L=1, D=2, U=3`; `kind` uses the piece codes of section 2.2 (the white stone
is the first piece); `len` is 1 for the white stone and blocks; `path` is one shortest solution in direction
letters. All numbers are JSON integers.

Loading: `ShiftPuzzles` keeps its public functions (`has_day`, `day`, `practice_count`, `practice`) and delegates to
one `WhitePuzzleStore` (kit design 5.5) with `ShiftPuzzles._puzzle` as converter (board dictionary to `ShiftBoard`,
path letters to directions).

### 5.3 Build tool

`tools/build_puzzles.gd` extends White Kit's `WhitePrecompute` (kit design 5.14). It only provides `_game_id()`
(`"white-shift"`) and `_generate(seed, level)`, which calls `ShiftGenerator.generate` and returns
`{board, par, solutions, path}`. Argument handling, seed texts, output and merging come from the kit:

```
--from=YYYY-MM-DD [--days=N] --out=<file>     build daily puzzles for N days (default 1)
--practice=N [--start=S] --out=<file>         build practice sets S..S+N-1
--merge=<built file> --into=<data file>       add new keys to a published file
```

- Build mode writes a fresh file and prints `<key> par [p0, p1, p2]` per key.
- New days are built to `build/` and merged into `data/daily.json` with `--merge`. The merge appends keys that are not
  in the data file yet, skips keys whose puzzles are identical, and refuses (exit code 1, nothing written) when a built
  key differs from a published one. Existing keys keep their order and bytes.
- Because the current generator gives different boards than the one that built the published data, rebuilding a
  published date and merging it is always refused. Only new dates and new practice indexes can be added. Days that
  are already published are never regenerated.

CI reports how many days are built from today on and warns when fewer than 14 remain.

### 5.4 Known trade-off

The repository is public, so future puzzles and one shortest solution for each are readable in advance. This is
accepted for the prototype; later the server delivers the daily puzzle (section 11).

## 6. The Dutch calendar day

- The current puzzle day is the calendar date in the Netherlands (CET/CEST), computed on the device from the
  system clock without any network call (`ShiftDaily.date_at`, which calls `WhiteDaily.date_at` from White Kit).
- Offset rule (EU): UTC+2 from the last Sunday of March 01:00 UTC until the last Sunday of October 01:00 UTC,
  UTC+1 otherwise.
- Puzzle number: `#1` is 2026-11-17 (`ShiftDaily.FIRST_DAY`); the number is the day count since then plus one
  (`ShiftDaily.number`, which calls `WhiteDaily.number(date, FIRST_DAY)`).
- When `data/daily.json` has no entry for today, the game says so and offers practice.

See ADR 0003.

## 7. Attempt and record

`ShiftAttempt` holds one player's attempt at one puzzle: current state, undo history, swipe count, time and the
record. It extends White Kit's `WhiteAttempt` (kit design 5.7) in count mode `EVERY_MOVE`, and keeps the White Shift
names: `board`, `swipe(dir)` (= `play`), `swipes` (= `count()`) and `ShiftAttempt.replay(board, record)` (a new
attempt plus `apply_record`).

### 7.1 Record format

The record is a string with one character per action, in order:

| Char | Meaning |
|---|---|
| `R` `L` `D` `U` | An effective swipe in that direction. |
| `z` | Undo. |
| `r` | Restart. |

No-op swipes, and undo/restart when they are not possible, are not written. Replaying a record from the start
position (`ShiftAttempt.replay`) rebuilds the exact attempt, including the count. Unknown characters are ignored.
The swipe count equals the number of `R`/`L`/`D`/`U` characters.

This is White Kit's record grammar (kit design 6.1) with move tokens of length 1. Other lower-case letters are
reserved for future kit actions and ignored on replay, as before.

Example: the record `DRzUrDR` means swipe down, swipe right, undo, swipe up, restart, swipe down, swipe right:
5 swipes.

The record is the save format today and the intended replay format for later server-side verification:
the server replays the record against the puzzle and computes the count itself. See ADR 0004.

### 7.2 Time

`time_ms` runs while a level is on screen, starting at its first effective swipe, and stops when the puzzle is
solved or the player switches level or mode. It is informational only; it does not affect the score. The clock is
kept by the kit's day screen.

## 8. Saved progress

- File: `user://progress.json` (browser storage on the web build, the user data folder elsewhere).
- Read, sanitised and written by White Kit's `WhiteProgress` (kit design 5.8); the format is unchanged, and files
  written before and after the switch to the kit are interchangeable.
- Format:

```json
{
  "lang": "nl",
  "days": {
    "2026-11-17": [
      {"record": "DRzUR", "time_ms": 41250, "solved": true},
      {"record": "", "time_ms": 0, "solved": false},
      {"record": "", "time_ms": 0, "solved": false}
    ]
  }
}
```

- Written after every effective swipe, undo, restart and level switch, and after a language change. On opening a day
  the records are replayed, so a reload continues exactly where the player was. The `solved` flag is derived and
  informational; replay is authoritative.
- A damaged file never stops the game: a file that is not JSON, or parts with the wrong structure, are replaced by
  empty values and whatever is usable is kept (fix ce16f44, now in `WhiteProgress.sanitize`).
- Practice attempts are not saved. Debug screenshot runs save nothing.

## 9. User interface

Godot 4.7.2, GL Compatibility renderer, portrait 720x1280 design size (stretch `canvas_items`, aspect `expand`).
All drawing is code (`_draw`), no image assets. Look: abstract and flat; the white stone stands out; the allowed
movement of every piece is visible on the piece.

| Element | Presentation |
|---|---|
| White stone | White with a soft glow. Leaves through the exit and fades out when solved. |
| Block | Grey, small cross (moves every way). |
| Horizontal bar | Blue, two grooves along its length. |
| Vertical bar | Orange, two grooves along its length. |
| Pin | Dark disc with a rim. |
| Exit | Gap in the wall with a short bright mark just outside. |

- Pieces glide to their new cells at one shared speed (16 cells/s), so the player sees what stopped where.
- Screen, top to bottom: title with mode button (Today/Practice) and language button (NL/EN); subtitle (daily
  puzzle number or practice set); three level tabs (solved levels show their count); swipe count, par and clock;
  the board; a message line (rules hint before the first swipe, result after solving); buttons.
- Buttons: Undo and Restart while playing; after solving: Best route (animates the stored shortest solution
  without changing the attempt), Share result (daily only) and Next.
- Input: swipe on the board with touch or mouse (at least 24 px; fires immediately at 48 px while dragging;
  dominant axis wins), arrow keys or WASD, Z or Backspace for undo, R for restart. Input is ignored while the
  best route is playing.
- Opening a day selects the first unsolved level.
- Share line (copied to the clipboard, no solution in it), unsolved levels as `-`:
  `White Shift #1 · 6/9/15 swipes (par 5/9/13)` (Dutch: `vegen`).
- Languages: Dutch (default) and English, texts in `ui/strings.gd`; the choice is saved.
- Practice: three levels from one practice set; Next on the hard level opens the next set. The start set is
  random per session.
- Prototype-only aids, to be removed or hidden later: visible par, Best route, Practice.
- Debug screenshot mode: `-- --shot=<png> [--date=YYYY-MM-DD] [--practice] [--level=N] [--keys=RLDUzr] [--lang=en]
  [--best]`.

Implementation on White Kit (kit design 5.12, kit ADR 0004):

- `ui/main.gd` extends `WhiteDayScreen`, which holds the layout, the screen flow, the clock, saving, practice, the
  language toggle, sharing and the debug screenshot mode. `ui/main.tscn` is unchanged.
- `main.gd` implements only the hooks: `_game_id` (`"white-shift"`), `_game_title` (`"WHITE SHIFT"`), `_first_day`
  (`ShiftDaily.FIRST_DAY`), `_texts` (`Strings.TEXT`), `_load_day`, `_load_practice`, `_practice_count` (through
  `ShiftPuzzles`), `_new_attempt` (`ShiftAttempt.new(puzzle.board)`, count mode ignored), `_make_view` (a `BoardView`
  whose `swiped` signal calls `_on_move`), `_view_show`, `_view_clear`, `_view_update`, `_extra_buttons` (the Best
  route button), `_hint_text` (`hint` plus `rule_more`), `_key_move` (arrow keys and WASD) and `_on_debug_extra`
  (`--best`). It keeps `best_btn`, `_show_best` and `_on_swipe_all_best`.
- The Best route button's text is set from the screen's `refreshed` signal, so it follows the language toggle.
- Texts: `Strings.TEXT` is registered with `WhiteText`; the counter key is `count` (was `swipes`). `Strings.t`,
  `Strings.lang`, `Strings.clock` and `Strings.share_line` remain as thin wrappers over `WhiteText` and `WhiteFormat`
  because the tests call them. White Shift defines no `count_final` and keeps the default `_play_message`.
- Look: the colours, sizes and spacing come from `WhiteTheme` and `WhiteUi`; they are the values White Shift had.

## 10. Build and deployment

- CI (`.github/workflows/ci.yml`, from White Kit's `templates/ci.yml`) on pushes to `develop` and `main`, pull
  requests to `main` and manual runs:
  1. checkout with submodules;
  2. kit pin check: `addons/white_kit` must be exactly the commit of tag `v<VERSION>` of the kit; the version is
     written to the run summary;
  3. Godot 4.7.2 through the kit's composite action `addons/white_kit/ci/setup-godot` (SHA-512 verified, cached);
  4. `--import`; kit tests (`res://addons/white_kit/tests/run_kit_tests.tscn -- --min-checks=522`); game tests
     (`res://tests/run_tests.tscn -- --min-checks=192`, the `MIN_CHECKS` variable);
  5. report remaining daily puzzle days (warning below 14);
  6. export the Web build (release) as an artifact.
- The export preset excludes `tests/*`, `tools/*`, `addons/white_kit/tests/*` and `addons/white_kit/tools/*`, so no
  test, fixture or tool code ships.
- On `develop` (not on pull requests) the Web build is published to GitHub Pages, served at
  https://play.whiteshift.steefbeest.nl (custom domain via a DNS record in the existing zone).
- No Android or Windows builds in phase 1.
- Cost: none (public repositories; Pages and Actions are free for public repositories).

## 11. Roadmap

| Phase | Content |
|---|---|
| 1 | Digital prototype: rules, solver, generator, three daily puzzles, abstract look, play version. Built. |
| 2 | Tuning from play tests: levels, rules, feel. |
| 3 | Version 1 finish: look, sound, statistics, sharing, Android. |
| 4 | st33f-engine: puzzle results, leaderboards, friends, one account on several devices. |
| 5 | Competitions; player feedback triage. |

From phase 4 the server delivers the daily puzzle instead of the repository (which also stops looking ahead),
and results are submitted as attempt records that the server replays to verify the count. st33f-engine is a
separate, private backend; this repository only depends on its public interface once that phase starts. The seams
for this are White Kit's (kit design section 11).
Accounts for players aged 10-15 require the owner's approval before phase 4 starts.

## 12. Acceptance criteria

Rules (`sim/board.gd`)
- The worked example in 2.3 gives exactly the shown boards; `R` first gives the described position.
- A horizontal bar never changes `y`; a vertical bar never changes `x`; pins never move.
- A non-white piece never leaves the board; the exit acts as wall for it.
- The white stone leaves only on a swipe towards the exit wall in the exit row/column.
- A no-op swipe returns a state equal to the input; `apply` returns `null` for it.
- `swipe()` and `swipe_reference()` agree on random boards, states and directions (random input from `WhiteRng`).
- `to_dict()` / `from_dict()` round-trip a board exactly.

Solver and generator
- On a hand-made board with a known optimum the solver returns that par and a path that, replayed, wins in par
  swipes.
- `generate(seed, level)` returns an identical board, par and path when called twice.
- `seed_for` equals FNV-1a 64-bit of the UTF-8 text (reference value checkable outside Godot).
- Generated boards contain at least one horizontal and one vertical bar.
- `tools/measure.gd -- --days=30`: each level fits its band without fallback on at least 27 of 30 seeds.

Shipped puzzles
- Every puzzle in `data/daily.json` and `data/practice.json` is a valid board; replaying `path` wins in exactly
  `par` swipes; the solver confirms `par` and `solutions`; par lies in the level band. These checks do not regenerate
  puzzles, so they hold for data from either generator.
- Every date from 2026-11-17 through the last built date is present with three puzzles.
- A merge of newly built days leaves the bytes of every existing key unchanged; a merge of a rebuilt published day is
  refused.

Day and attempt
- `date_at` switches date at 23:00 UTC in winter and 22:00 UTC in summer, including the DST change days.
- `number("2026-11-17") == 1`.
- Undo and restart do not lower the count; a no-op swipe changes neither count nor record.
- `replay(board, record)` reproduces state, count and record of the original attempt.
- `share_line` produces the format in section 9, with `-` for unsolved levels.

UI and deployment (manual or screenshot)
- After a reload, a partly played day shows the same position, count and record.
- Without a puzzle for today the game shows the no-puzzle message and practice works.
- After a language toggle on a solved level, the Best route button shows the text of the new language.
- CI on `develop` is green (kit pin, kit tests, game tests) and the play version at
  https://play.whiteshift.steefbeest.nl loads and plays.

## 13. White Kit

White Shift is built on White Kit, the shared base of the White daily puzzle games, included as a git submodule at
`addons/white_kit` and pinned to a release tag (now `v0.1.0`). The kit's design is in its own repository
(`docs/design.md` there); this section only records how White Shift uses it. Decision: ADR 0005.

| White Shift code | Kit class it uses | What stays in White Shift |
|---|---|---|
| `sim/daily.gd` (`ShiftDaily`) | `WhiteDaily` | `FIRST_DAY`; thin wrapper functions. |
| `sim/generator.gd` (`ShiftGenerator`) | `WhiteSeed`, `WhiteRng` | `LEVELS`, `MIX`, layout drawing, the fit loop. |
| `sim/puzzles.gd` (`ShiftPuzzles`) | `WhitePuzzleStore` | File paths and the puzzle converter `_puzzle`. |
| `sim/board.gd` (`ShiftBoard`) | `WhiteRules` (extends) | All rules, both swipe implementations. |
| `sim/attempt.gd` (`ShiftAttempt`) | `WhiteAttempt` (extends) | The names `board`, `swipe`, `swipes`, `replay`. |
| `sim/solver.gd` (`ShiftSolver`) | - | Everything. |
| `ui/main.gd` | `WhiteDayScreen` (extends), `WhiteUi`, `WhiteProgress` | Hooks, Best route animation. |
| `ui/strings.gd` (`Strings`) | `WhiteText`, `WhiteFormat` | All texts (`TEXT`); thin wrapper functions. |
| `ui/board_view.gd` (`BoardView`) | - | Everything. |
| `tools/build_puzzles.gd` | `WhitePrecompute` (extends) | `_game_id`, `_generate`. |
| `tools/measure.gd` | - | Everything. |
| `tests/run_tests.gd` | `WhiteTestRunner` (extends) | All game tests. |
| `.github/workflows/ci.yml` | `templates/ci.yml`, `ci/setup-godot` | Header comment, `MIN_CHECKS`. |

- The wrappers `ShiftDaily`, `ShiftPuzzles`, `ShiftAttempt` and `Strings` stay because the tests call them by these
  names. Removing them is a separate task together with a test update.
- Updating the kit follows the kit's procedure (kit design section 8): check out the new tag in the submodule, run
  kit and game tests, commit `chore: update White Kit to v<new>`. A kit update must keep the 192 game checks green and
  the screenshots of the kit's migration acceptance pixel-identical, unless the kit's changelog announces a visible
  change.
- Planned kit 0.2.0 (practice-only hook for White Tally, test runner counting script errors) needs no code change in
  White Shift; after updating, a script error that was silently skipped in a test would now fail the run and is then a
  test finding.
