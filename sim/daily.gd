class_name ShiftDaily
extends RefCounted
## Which day it is for the daily puzzles: the date in the Netherlands (CET/CEST), worked out without the network, so
## everyone gets the new puzzles at the same moment. Puzzle #1 is 2026-11-17.

const FIRST_DAY := "2026-11-17"


## Offset of Dutch time from UTC at a unix time: +2 h from the last Sunday of March 01:00 UTC to the last Sunday of
## October 01:00 UTC (EU rule), +1 h otherwise.
static func nl_offset(unix: int) -> int:
	var year: int = Time.get_datetime_dict_from_unix_time(unix).year
	var start := _last_sunday(year, 3) + 3600
	var end := _last_sunday(year, 10) + 3600
	return 7200 if unix >= start and unix < end else 3600


static func _last_sunday(year: int, month: int) -> int:
	var t := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": 31, "hour": 0, "minute": 0, "second": 0})
	var wd: int = Time.get_datetime_dict_from_unix_time(t).weekday # 0 = Sunday
	return t - wd * 86400


static func date_at(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix + nl_offset(unix))


static func today() -> String:
	return date_at(int(Time.get_unix_time_from_system()))


static func number(date: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(FIRST_DAY + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	return int(round((b - a) / 86400.0)) + 1
