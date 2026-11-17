# Conventions

How code, tests, data and branches are handled in this repository. The design is in `docs/design.md`.

## Engine and layout

- Godot 4.7.2, GDScript only, pinned in `project.godot` and CI. Use the same version on every machine.
- Renderer: GL Compatibility (works on the web and on older phones).

| Folder | Content |
|---|---|
| `sim/` | Rules, solver, generator, day calculation, attempt, puzzle loading. No scenes, no nodes, no UI. |
| `ui/` | Screen and drawing (`main.gd`, `board_view.gd`) and texts (`strings.gd`). Depends on `sim/`, never the other way round. |
| `tools/` | Headless scripts (`extends SceneTree`) for generating and measuring puzzles. |
| `data/` | Precomputed puzzles shipped with the game (`daily.json`, `practice.json`). |
| `tests/` | Headless test runner and tests. |
| `build/` | Local output (exports, generated puzzle files). Ignored by git. |

## GDScript style

- Godot style guide: tabs for indentation, `snake_case` for functions and variables, `PascalCase` for classes and
  enums, `UPPER_CASE` for constants and enum values. Keep lines within 120 characters.
- Static typing everywhere: typed parameters and return types, `:=` for inferred locals, typed arrays where
  practical.
- Members and functions that are internal to a class start with `_`.
- Classes in `sim/` have a `class_name` with the prefix `Shift` (`ShiftBoard`, `ShiftSolver`, `ShiftGenerator`,
  `ShiftDaily`, `ShiftAttempt`, `ShiftPuzzles`). They extend `RefCounted` and mostly expose static functions.
  The two existing UI classes (`BoardView`, `Strings`) predate this rule; new global classes use the prefix.
- `sim/` code must not use scenes, nodes, input, rendering or `user://`. It may use pure engine helpers such as
  `Time`, `JSON`, `FileAccess` on `res://` and `RandomNumberGenerator`.
- Hot paths (swipe, solver) work on `PackedInt32Array` states and a flat cell grid, not on objects.
- Every rule change keeps `ShiftBoard.swipe()` and `ShiftBoard.swipe_reference()` in agreement.
- Documentation comments use `##` on the class and on public functions; ordinary comments use `#`. Comments and
  identifiers are in English.
- Player-facing texts live in `ui/strings.gd`, in Dutch and English; no texts hard-coded elsewhere.
- No credentials, keys or personal data in the repository.

## Determinism

- The generator must give the same puzzle for the same seed text on every machine. Use only the seeded
  `RandomNumberGenerator` passed in; never the global random functions in `sim/`.
- Seed texts are fixed: `white-shift|<YYYY-MM-DD>|<level>` and `white-shift-practice|<i>|<level>`, hashed with
  FNV-1a 64-bit (`ShiftGenerator.seed_for`).
- Changing `ShiftGenerator` (levels, mix, layout drawing) changes what a seed produces. Puzzles that are already
  in `data/` are not regenerated; a generator change only applies to days built afterwards.

## Tests

- Run headless. After a fresh clone, or after adding or renaming a `class_name`, import first so the class cache
  exists:

```bash
godot --headless --path . --import
timeout 300 godot --headless --path . res://tests/run_tests.tscn
```

- The runner (`tests/run_tests.gd`) calls each `test_*` function, records results with `check(ok, what)`,
  prints `tests: N passed, M failed` and exits with code 1 on any failure. CI uses that exit code.
- `what` describes the expected behaviour in plain words, so a failure message explains itself.
- Tests cover `sim/` directly (no UI); boards for rule tests are built by hand with `ShiftBoard.create()` and
  `add()`, and compared with `render()` where a picture is clearer than coordinates.
- Every shipped puzzle in `data/` is re-checked by the tests (valid board, `path` wins in `par`, solver agrees).
- UI is checked with the debug screenshot mode (`-- --shot=<png> ...`, see README); screenshots are not committed.

## Puzzle data

- Build daily puzzles ahead with the precompute tool; it writes a fresh file and does not append:

```bash
godot --headless --path . -s res://tools/build_puzzles.gd -- --from=YYYY-MM-DD --days=30 --out=build/daily.json
godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 --start=0 --out=build/practice.json
```

- Merge new days into `data/daily.json` without changing existing dates; run the tests before committing.
- Keep at least 14 days ahead; CI warns below that.
- Measure the generator after changing it: `godot --headless --path . -s res://tools/measure.gd -- --days=30`.

## Git and CI

- `develop` is the working branch; every push to `develop` runs CI and publishes the play version.
  `main` is protected and is updated through pull requests only; CI runs on those pull requests.
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main`. Do not commit build output (`build/` is ignored).
