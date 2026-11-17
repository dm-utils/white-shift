# 0005 Adopt White Kit as the shared base

Status: accepted (2026-11-17)

## Context

White Shift was built as a single repository: day calculation, seed hash, puzzle loading, attempt and record, the
progress file, texts, the whole screen, the test runner, the precompute tool and the CI workflow all lived in its own
code. A second game in the series, White Tally, needs almost all of that unchanged; only rules, solver, generator,
board drawing and texts differ. Copying the code into each game would double every fix (the progress file robustness
fix ce16f44 is an example) and let the games drift apart.

The generator used Godot's `RandomNumberGenerator`. Its algorithm and seeding are engine internals: a server or tool
outside Godot cannot reproduce a puzzle from a seed, and an engine change could silently change what a seed produces.

White Kit (repository `dm-utils/white-kit`, its own design and ADRs) was designed to hold the shared part, with White
Shift as its first user and a migration plan that must not change White Shift's behaviour or published puzzles.

## Decision

- White Shift includes White Kit as a git submodule at `addons/white_kit`, pinned to a release tag (now `v0.1.0`). CI
  checks out submodules and fails when the submodule is not exactly at the tag named in the kit's `VERSION` file.
- White Shift's shared code is replaced by the kit's classes, in ten steps with the 177 checks green after each
  (kit design section 10):
  - `ShiftDaily`, `ShiftPuzzles` and `Strings` become thin wrappers over `WhiteDaily`, `WhitePuzzleStore`,
    `WhiteText` and `WhiteFormat`;
  - `ShiftBoard` extends `WhiteRules`; `ShiftAttempt` extends `WhiteAttempt` (count mode `EVERY_MOVE`);
  - `ui/main.gd` extends `WhiteDayScreen` and implements only its hooks;
  - `tests/run_tests.gd` extends `WhiteTestRunner`; `tools/build_puzzles.gd` extends `WhitePrecompute`, which adds a
    safe `--merge`;
  - the CI workflow comes from the kit's template and uses the kit's Godot setup action; the kit's own tests run in
    White Shift's CI too.
- The generator draws from `WhiteRng` instead of `RandomNumberGenerator`; the seed texts and FNV-1a hash are
  unchanged (`WhiteSeed`).
- Published data in `data/` is not regenerated. The 60 daily puzzles (2026-11-17 to 2027-01-15) and 45 practice sets
  built with the former generator stay as they are; only new days and sets are built with the `WhiteRng` generator
  and added with `--merge`.
- Texts: the counter key `swipes` is renamed to `count`, the key the kit's screen reads. No player-visible text
  changes.

## Alternatives considered

- Keep White Shift standalone and copy its code into White Tally: no migration risk now, but every shared fix must be
  made twice and the games drift apart. Rejected.
- Move to the kit but keep `RandomNumberGenerator` in the generator: published and future puzzles would come from the
  same generator, but seeds would stay non-portable and engine-dependent, which blocks server-side checks in phase 4
  (kit ADR 0002). Rejected.
- Switch to `WhiteRng` and regenerate all published data, so that every shipped puzzle is reproducible from current
  code: changes puzzles that players have already seen and played, and breaks saved records, which are replayed
  against the published boards. Rejected; published days are never regenerated (ADR 0001).
- Copy the kit's files into the repository (vendoring) instead of a submodule: simpler clone, but no visible pin and
  local edits could drift from the kit. Rejected (kit ADR 0001).

## Consequences

- Measured during the migration: all 177 checks green after every step; `git diff` of `data/` empty; the new
  `build_puzzles.gd` writes byte-identical files to the old tool before step 10; the merge reproduces
  `data/daily.json` byte for byte; screenshots (daily, practice, no puzzle, English, level 2, with keys) pixel-identical;
  progress files interchangeable between old and new version; play version deployed with CI green (530b879).
- The published puzzles can no longer be rebuilt from the current code: rebuilding a published date gives a different
  board, and `--merge` refuses it. They remain fully checked by the tests (valid board, path wins in par, solver
  agrees), which do not regenerate. ADR 0001's statement that the data "can be rebuilt" now holds only for days built
  from 2026-11-17 on with the `WhiteRng` generator.
- Generator quality on `WhiteRng`: `tools/measure.gd --days=30` fits 30 of 30 days per level without fallback (was
  30 of 30); par ranges easy 4-7, medium 8-12, hard 13-22. Median generation time per puzzle was 13 ms / 0.18 s /
  3.6 s against 9 ms / 0.14 s / 0.7 s before, measured on a busy machine; generation only runs ahead of time, so this
  does not affect players. If it persists in a quiet measurement it is a precompute cost, not a defect.
- A fresh clone needs `--recurse-submodules` (or `git submodule update --init`); without it the project does not load.
  The README says so.
- Kit updates are explicit commits that move the pin; White Shift's tests and screenshots decide whether an update is
  accepted. Changes to shared behaviour (screen, progress file, runner) are made in the kit, not in White Shift.
- The wrappers `ShiftDaily`, `ShiftPuzzles`, `ShiftAttempt` and `Strings` remain until the tests are moved to the
  kit's names.
- Godot `.uid` files are committed for White Shift's own scripts; the kit commits its own, so the submodule stays
  clean after import.
