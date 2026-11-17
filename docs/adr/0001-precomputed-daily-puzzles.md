# 0001 Precomputed daily puzzles in the repository

Status: accepted (2026-11-17)

## Context

Every player must get the same three puzzles each day. The generator draws random layouts and checks each one with
an exact breadth-first solver until one fits the level's par band. On a desktop PC this takes about 3 ms for easy,
0.2 s (max 10 s) for medium and 6 s (max 22 s) for hard. The game runs in a phone browser, which is several times
slower and single-threaded; the hard puzzle could take minutes there. Phase 1 has no server.

## Decision

Puzzles are generated ahead of time with `tools/build_puzzles.gd` and shipped in the repository as
`data/daily.json` (by date) and `data/practice.json` (practice sets). Each puzzle carries its board, par, number of
shortest solutions and one shortest path. The game only loads; it never searches. The generator stays
deterministic (seed from the date and level), so the data can be rebuilt and checked. The tests re-verify every
shipped puzzle; CI warns when fewer than 14 days are built ahead.

## Alternatives considered

- Generate on the device at day start: identical results thanks to the deterministic seed, but too slow on phones
  for medium and hard, and the time would vary per device. Rejected.
- Generate on a server and serve the daily set: the right end state, but phase 1 has no backend and the prototype
  must cost nothing. Deferred to phase 4.
- Cap the solver harder so on-device generation is fast enough: changes which puzzles are accepted and weakens
  the hard level. Rejected.

## Consequences

- Instant start on every device, no network needed, no device-dependent behaviour.
- The repository is public: anyone can read future puzzles and their shortest solution in advance. Accepted for
  the prototype, where there is nothing to win. From phase 4 the server delivers the daily puzzle and the
  repository no longer contains future days.
- Someone has to build days ahead; when the data runs out the game shows "no puzzle today" (practice still works).
  Currently built through 2027-01-15.
- Changing the generator does not change already shipped puzzles; published days must not be regenerated.
