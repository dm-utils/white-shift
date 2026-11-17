class_name ShiftDaily
extends RefCounted
## Which day it is for the daily puzzles: the date in the Netherlands (CET/CEST), worked out without the network, so
## everyone gets the new puzzles at the same moment. Puzzle #1 is 2026-11-17. The work is done by WhiteDaily.

const FIRST_DAY := "2026-11-17"


static func nl_offset(unix: int) -> int:
	return WhiteDaily.nl_offset(unix)


static func date_at(unix: int) -> String:
	return WhiteDaily.date_at(unix)


static func today() -> String:
	return WhiteDaily.today()


static func number(date: String) -> int:
	return WhiteDaily.number(date, FIRST_DAY)
