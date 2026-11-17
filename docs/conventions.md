# Conventions

How code, tests, data and branches are handled in this repository. The design is in `docs/design.md`.

## Engine and layout

- Godot 4.7.2, GDScript only, pinned in `project.godot` and, through White Kit's `ci/setup-godot` action, in CI. Use
  the same version on every machine.
- Renderer: GL Compatibility (works on the web and on older phones).
- White Kit is a git submodule at `addons/white_kit`, pinned to a release tag. Clone with `--recurse-submodules`, or
  run `git submodule update --init` after a plain clone.

| Folder | Content |
|---|---|
| `sim/` | Rules, solver, generator, day calculation, attempt, puzzle loading. No scenes, no nodes, no UI. |
| `ui/` | Screen and drawing (`main.gd`, `board_view.gd`) and texts (`strings.gd`). Depends on `sim/`, never the other way round. |
| `tools/` | Headless scripts (`extends SceneTree`) for generating and measuring puzzles. |
| `data/` | Precomputed puzzles shipped with the game (`daily.json`, `practice.json`). |
| `tests/` | Headless test runner and tests. |
| `addons/white_kit/` | White Kit (submodule). Never edited here; changes go to the kit repository and arrive as a new tag. |
| `build/` | Local output (exports, generated puzzle files). Ignored by git. |

- Godot's `.uid` files are committed next to their scripts. After adding or renaming a script, import once so the
  `.uid` exists, and commit it with the script.

## GDScript style

- Godot style guide: tabs for indentation, `snake_case` for functions and variables, `PascalCase` for classes and
  enums, `UPPER_CASE` for constants and enum values. Keep lines within 120 characters.
- Static typing everywhere: typed parameters and return types, `:=` for inferred locals, typed arrays where
  practical.
- Members and functions that are internal to a class start with `_`.
- Classes in `sim/` have a `class_name` with the prefix `Shift` (`ShiftBoard`, `ShiftSolver`, `ShiftGenerator`,
  `ShiftDaily`, `ShiftAttempt`, `ShiftPuzzles`). They extend `RefCounted` or a White Kit base class (`ShiftBoard`
  extends `WhiteRules`, `ShiftAttempt` extends `WhiteAttempt`) and mostly expose static functions.
  The two existing UI classes (`BoardView`, `Strings`) predate this rule; new global classes use the prefix. The
  prefix `White` is reserved for White Kit.
- Shared functionality comes from White Kit; do not reimplement in White Shift what the kit provides (day, seed,
  random numbers, puzzle loading, attempt, progress file, text lookup, formatting, screen flow, test runner, precompute
  skeleton). A shared need that the kit does not cover is raised as a kit change, not solved locally.
- `ui/main.gd` extends `WhiteDayScreen` and only implements its hooks, keeps game-only features (Best route) and
  reacts to screen events through the screen's signals (`refreshed`, ...). It does not override `_ready` or internal
  screen functions such as `_refresh` or `_open_day`.
- `sim/` code must not use scenes, nodes, input, rendering or `user://`. It may use pure engine helpers such as
  `Time`, `JSON` and `FileAccess` on `res://`, and White Kit's `core/` classes.
- Hot paths (swipe, solver) work on `PackedInt32Array` states and a flat cell grid, not on objects.
- Every rule change keeps `ShiftBoard.swipe()` and `ShiftBoard.swipe_reference()` in agreement, and
  `ShiftBoard.apply()` returns `null` exactly for no-op swipes.
- Documentation comments use `##` on the class and on public functions; ordinary comments use `#`. Comments and
  identifiers are in English.
- Player-facing texts live in `ui/strings.gd` (`Strings.TEXT`), in Dutch and English with the same keys; no texts
  hard-coded elsewhere. Keys the kit screen reads (`count`, `today`, `solved`, ...) keep the kit's names; White
  Shift's own keys (`hint`, `rule_more`, `show_best`, `unit`) are added to the same table.
- No credentials, keys or personal data in the repository.

## Determinism

- The generator must give the same puzzle for the same seed text on every machine. It draws only from the
  `WhiteRng` passed in (`range_int`, `next_float`); never `RandomNumberGenerator` or the global random functions
  (`randi`, `randf`, `randomize`, `seed`) in `sim/` or `tools/`.
- Seed texts are fixed: `white-shift|<YYYY-MM-DD>|<level>` and `white-shift-practice|<i>|<level>`, hashed with
  FNV-1a 64-bit (`ShiftGenerator.seed_for`, which calls `WhiteSeed.fnv1a64`).
- Changing `ShiftGenerator` (levels, mix, layout drawing, the order of random draws) changes what a seed produces.
  Puzzles that are already in `data/` are not regenerated; a generator change only applies to days built afterwards.
  The switch from `RandomNumberGenerator` to `WhiteRng` (ADR 0005) is such a change: data published before
  2026-11-17 cannot be rebuilt from the current code.
- A kit update never changes the generator's output: `WhiteSeed` and `WhiteRng` output is frozen by the kit (only a
  kit MAJOR version may change it, and then White Shift decides whether to take it).

## Tests

- Run headless. After a fresh clone, after a kit update, or after adding or renaming a `class_name`, import first so
  the class cache exists:

```bash
godot --headless --path . --import
timeout 300 godot --headless --path . res://addons/white_kit/tests/run_kit_tests.tscn -- --min-checks=250
timeout 300 godot --headless --path . res://tests/run_tests.tscn -- --min-checks=177
```

- The runner (`tests/run_tests.gd`, which extends White Kit's `WhiteTestRunner`) runs the `test_*` functions from
  `_run()`, records results with `check(ok, what)`, prints `tests: N passed, M failed` and exits with code 1 on any
  failure or when fewer than `--min-checks` checks ran. CI uses that exit code; `MIN_CHECKS` in the workflow equals
  the current number of game checks and is raised when tests are added.
- With kit 0.1.0 a GDScript runtime error inside a test function silently skips the rest of that function; read the
  output for `SCRIPT ERROR` lines. From kit 0.2.0 the runner counts such errors as failures.
- `what` describes the expected behaviour in plain words, so a failure message explains itself.
- Tests cover `sim/` directly (no UI); boards for rule tests are built by hand with `ShiftBoard.create()` and
  `add()`, and compared with `render()` where a picture is clearer than coordinates. Random test input comes from a
  seeded `WhiteRng`.
- Every shipped puzzle in `data/` is re-checked by the tests (valid board, `path` wins in `par`, solver agrees). The
  tests never regenerate published puzzles.
- The kit's own tests also run in White Shift's CI; they use their own `user://white_kit_test_*` files and never touch
  `user://progress.json`.
- UI is checked with the debug screenshot mode (`-- --shot=<png> ...`, see README); screenshots are not committed.
  After a kit update, compare screenshots before and after (`--date=2026-11-17`, `--practice`, `--date=2027-02-01`,
  `--lang=en`, `--level=2`).

## Puzzle data

- Build daily puzzles ahead with the precompute tool into `build/`, then merge them into `data/`:

```bash
godot --headless --path . -s res://tools/build_puzzles.gd -- --from=YYYY-MM-DD --days=30 --out=build/daily.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --merge=build/daily.json --into=data/daily.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 --start=45 --out=build/practice.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --merge=build/practice.json --into=data/practice.json
```

- `--from` is the first date not yet in `data/daily.json`; `--start` is the first practice index not yet in
  `data/practice.json`. The merge refuses (exit code 1, nothing written) when a built key already exists with
  different content; never edit published keys by hand and never work around a refusal.
- Run the tests before committing new data; check that `git diff data/` only adds keys.
- Keep at least 14 days ahead; CI warns below that.
- Measure the generator after changing it: `godot --headless --path . -s res://tools/measure.gd -- --days=30`.

## White Kit updates

- Update only to a released tag:
  `git -C addons/white_kit fetch --tags && git -C addons/white_kit checkout v<new>`, then import, run kit and game
  tests, compare screenshots, and commit `chore: update White Kit to v<new>` (the gitlink change only, plus any
  adaptation the kit's changelog asks for).
- CI rejects a submodule commit that is not exactly the tag named in the kit's `VERSION`.
- Never commit changes inside `addons/white_kit`; if the submodule shows as modified after an import, report it as a
  kit issue.

## Git and CI

- `develop` is the working branch; every push to `develop` runs CI and publishes the play version.
  `main` is protected and is updated through pull requests only; CI runs on those pull requests.
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main`. Do not commit build output (`build/` is ignored).
