# White Shift

A daily sliding puzzle. One swipe moves every piece that may move that way, as far as it can go:
bars only slide along their own axis, blocks and the white stone slide every way, pins never move.
Get the white stone out through the opening in the wall, in as few swipes as you can.

Three puzzles a day (easy, medium, hard), the same for everyone, changing at midnight Dutch time.
Every swipe counts, also the ones you take back.

Play: https://play.white-shift.steefbeest.nl

## Development

Godot 4.7.2 (GDScript). The shared base is White Kit, a git submodule at `addons/white_kit` pinned to a release tag.
Clone with `git clone --recurse-submodules`, or run `git submodule update --init` after a plain clone.

```bash
godot --headless --path . --import                        # once after a fresh clone
timeout 300 godot --headless --path . res://tests/run_tests.tscn
godot --headless --path . -s res://tools/measure.gd -- --days=30          # generator statistics per level
godot --headless --path . -s res://tools/build_puzzles.gd -- --from=2027-01-16 --days=30 --out=build/daily.json
```

- `sim/` the rules (`board.gd`), an exact breadth-first solver (`solver.gd`), the seeded generator (`generator.gd`),
  the day in the Netherlands (`daily.gd`) and an attempt with its record (`attempt.gd`; the record is the replay).
- `data/` precomputed puzzles: a phone never searches. Each puzzle carries its par and one shortest route; the tests
  replay every route.
- `ui/` the screen, drawn with `_draw`, no art files.

Debug screenshot (nothing saved): `godot --path . -- --shot=out.png --date=2026-11-17 --level=2 --keys=DL`
