# Glossary

Terms used in the code, the design (`docs/design.md`) and the ADRs. Code names in brackets. Terms of the shared base
(hook, count mode, puzzle store, ...) are defined in White Kit's glossary (`addons/white_kit/docs/glossary.md`).

| Term | Meaning |
|---|---|
| Attempt (`ShiftAttempt`) | One player's go at one puzzle: current state, undo history, swipe count, time and record. Extends White Kit's `WhiteAttempt` in every-move count mode. |
| Bar | A horizontal bar or a vertical bar. Moves only along its own axis. |
| Best route | The stored shortest solution (`path`), shown as an animation after solving. Prototype aid. |
| Block (`BLOCK`) | A grey 1x1 piece that moves in all four directions. Cannot use the exit. |
| Board (`ShiftBoard`) | Size, exit, pins, pieces and start state of one puzzle, plus the rules (swipe). Implements White Kit's rules interface (`WhiteRules`). |
| Daily set | The three puzzles (easy, medium, hard) of one Dutch calendar day, the same for everyone. |
| Dutch calendar day | The date in the Netherlands (CET/CEST); decides which daily set is current. |
| Effective swipe | A swipe that changed the state. Only effective swipes count and are recorded. |
| Exactly par | A solved attempt whose swipe count equals par. |
| Exit | The one-cell opening in the wall, given by side and index. Only the white stone can pass it. |
| Fallback | The generator's best near-miss when no layout fits the level within the allowed tries. |
| FNV-1a | The 64-bit hash that turns a seed text into the generator seed (`WhiteSeed.fnv1a64`). |
| Former generator | The generator as it was before 2026-11-17, drawing from Godot's `RandomNumberGenerator`. Built all data published before that date; that data cannot be rebuilt from the current code. |
| Horizontal bar (`HBAR`) | A blue piece 2 or 3 cells wide that moves only right and left. |
| Kit pin | The White Kit release tag the submodule `addons/white_kit` points at; CI fails when the submodule is not exactly at that tag. |
| Leading edge | The cell of a piece nearest to the wall a swipe moves towards; decides processing order. |
| Level | Easy (0), medium (1) or hard (2); each has its own board size, piece counts and par band. |
| Merge | Adding newly built days or practice sets to `data/` without changing existing keys (`build_puzzles.gd --merge`); refuses when a built key differs from the published one. |
| No-op swipe | A swipe that changes nothing. Not counted, not recorded (`ShiftBoard.apply` returns `null`). |
| Par | The exact minimum number of effective swipes to solve a puzzle, computed by the solver. |
| Par band | The range of par a generated puzzle must fall in for its level. |
| Pin | A fixed 1x1 obstacle. Never moves. |
| Practice set | Three puzzles (easy, medium, hard) from `data/practice.json`, not tied to a date and not saved. |
| Precomputed puzzles | Puzzles generated ahead of time by `tools/build_puzzles.gd` and shipped in `data/`. |
| Puzzle number | Day count of a daily set; `#1` is 2026-11-17. |
| Record | The action string of an attempt: `R` `L` `D` `U` for effective swipes, `z` undo, `r` restart. Save format and future replay format; White Kit's record grammar with move tokens of length 1. |
| Replay | Rebuilding an attempt by applying its record to the start position (`ShiftAttempt.replay`). |
| Restart | Back to the start position; clears the undo history; does not lower the count. |
| Seed text | The text hashed into a generator seed: `white-shift\|<date>\|<level>` for daily puzzles, `white-shift-practice\|<i>\|<level>` for practice sets. |
| Share line | One line with the day's counts and pars, without the solution, e.g. `White Shift #1 · 6/9/15 swipes (par 5/9/13)`. |
| Shortest solutions | The number of distinct swipe sequences of length par; capped per level by the generator. |
| Solver (`ShiftSolver`) | Breadth-first search that computes par, the number of shortest solutions and one shortest path. |
| State | `PackedInt32Array` `[x0, y0, ..., won]`: the top-left cell of every piece and the won flag. |
| Swipe | One move in a direction (`R`, `L`, `D`, `U`): every piece that may move that way slides as far as it can. |
| Undo | Back to the state before the last effective swipe; does not lower the count. |
| Vertical bar (`VBAR`) | An orange piece 2 or 3 cells high that moves only down and up. |
| White Kit | The shared base of the White daily puzzle games (day, seed, `WhiteRng`, attempt, progress file, screen, test runner, precompute tool, CI), included as a git submodule at `addons/white_kit`. |
| `WhiteRng` | White Kit's deterministic random generator (xoshiro128**); the generator's only source of randomness since 2026-11-17. |
| White stone (`WHITE`) | The 1x1 piece to get out; moves in all four directions; always piece index 0. |
| Won flag | Last element of the state; 1 once the white stone has left through the exit. |
