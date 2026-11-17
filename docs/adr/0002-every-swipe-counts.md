# 0002 Every swipe counts, scored against par

Status: accepted (2026-11-17)

## Context

The score of a daily puzzle is the number of swipes. Players need undo and restart to explore without frustration,
especially younger players. If undo also took swipes off the count, a player could explore freely and then submit
a perfect count; the score would only measure persistence. A swipe that moves nothing should not be punished: it is
a misread of the board, not a move.

## Decision

- The score is the number of effective swipes (swipes that changed the board) in the whole attempt.
- Undo and restart are free actions but never lower the count: a swipe that is undone or discarded by a restart
  still counts.
- A swipe that changes nothing is ignored: not counted and not recorded.
- Par is the exact minimum number of swipes, computed by the breadth-first solver, and is the reference for the
  score ("exactly par").

## Alternatives considered

- Count only the swipes of the final path (undo refunds): rewards trial and error over planning and makes every
  diligent player score par. Rejected.
- No undo at all, restart only: purer, but harsh for the target audience and gives the same count as the decision
  anyway. Rejected.
- Count no-op swipes too: punishes misreading which pieces move, adds no skill signal. Rejected.
- Score by time: depends on device and interruptions; time is shown but only informational.

## Consequences

- Planning before swiping is what the score rewards, which is the point of the puzzle.
- The count is fully determined by the attempt record (ADR 0004): the number of `R`/`L`/`D`/`U` characters.
- Par must be exact, hence a complete breadth-first search rather than a heuristic solver.
- Whether par stays visible during play is open for phase 2.
