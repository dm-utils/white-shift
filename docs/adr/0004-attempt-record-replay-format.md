# 0004 Attempt record as save and replay format

Status: accepted (2026-11-17)

## Context

Progress must survive a reload: a half-played day continues where the player stopped, with the same count. Later
(phase 4) results go to a server for leaderboards. A server must not trust a submitted count; it needs something it
can check. The undo history and the "every swipe counts" rule (ADR 0002) must both be reproducible.

## Decision

An attempt is stored as a record: a string with one character per action, in order. `R`, `L`, `D`, `U` are
effective swipes, `z` is undo, `r` is restart. No-op swipes and impossible undo/restart are not written.
`ShiftAttempt.replay(board, record)` rebuilds the attempt from the start position. Saved progress
(`user://progress.json`) stores the record per level, plus time and a derived solved flag. The same record is the
intended replay format for server-side verification: the server replays it against the puzzle and derives the
count and the solved state itself.

## Alternatives considered

- Store the current state and the count: smaller, but loses the undo history and cannot be verified. Rejected.
- Store only the final solution path: cannot reproduce the count, since undone swipes also count. Rejected.
- A structured list of events (JSON objects with timestamps): more flexible, much larger, and timestamps are not
  needed for the score. Rejected for now; time is stored next to the record.

## Consequences

- A reload is an exact replay; the solved flag in the save file is informational.
- The count equals the number of swipe letters in the record, so any implementation can check it.
- A server-side check needs the board and the same swipe rules; a second implementation of the rules must match
  `ShiftBoard.swipe()` exactly. The board JSON plus the worked examples in the design serve as the contract.
- Records grow with the number of actions; for these puzzle sizes that stays small.
- Changing the meaning of a letter breaks old saves and replays; new actions get new letters.
