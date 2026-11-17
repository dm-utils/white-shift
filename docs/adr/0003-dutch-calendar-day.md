# 0003 Daily change at midnight Dutch time

Status: accepted (2026-11-17)

## Context

A daily puzzle only works socially if everyone plays the same puzzle on the same day and can compare results. The
players are mainly in the Netherlands. Phase 1 has no server, and the web build should not depend on a network call
to know which day it is.

## Decision

The puzzle day is the calendar date in the Netherlands (CET/CEST). The device computes it from its own clock in UTC
with the EU daylight-saving rule (UTC+2 from the last Sunday of March 01:00 UTC to the last Sunday of October
01:00 UTC, UTC+1 otherwise), without time zone data and without the network (`ShiftDaily`). Puzzle `#1` is
2026-11-17.

## Alternatives considered

- The device's local date: players abroad or with a different time zone setting would get a different puzzle at
  the same moment; sharing results stops working. Rejected.
- UTC date: the change would happen at 01:00 or 02:00 at night for the main audience. Rejected.
- Ask a time server: adds a network dependency and a failure mode for no gain in phase 1. Deferred; from phase 4
  the server decides the day.
- Look up `Europe/Amsterdam` in a time zone database: Godot offers no lookup by zone name, only the device's own
  zone. Rejected.

## Consequences

- Everyone switches at the same moment, Dutch midnight, wherever they are.
- A device with a wrong clock shows the wrong day; accepted, as nothing is at stake in phase 1.
- If the EU changes its daylight-saving rule, `ShiftDaily.nl_offset` must be updated.
- The tests cover the switch moments, including the daylight-saving change days.
