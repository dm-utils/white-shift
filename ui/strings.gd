class_name Strings
extends RefCounted
## Dutch and English texts. Small enough to keep in code for the prototype.

const TEXT := {
	"nl": {
		"levels": ["Makkelijk", "Middel", "Moeilijk"],
		"today": "Dagpuzzel #%d",
		"practice": "Oefenen",
		"daily": "Vandaag",
		"swipes": "Vegen: %d",
		"par": "Par: %d",
		"undo": "Terug",
		"restart": "Opnieuw",
		"next": "Volgende",
		"solved": "Opgelost in %d vegen (par %d) · %s",
		"perfect": "Precies par!",
		"show_best": "Beste route",
		"share": "Deel uitslag",
		"copied": "Gekopieerd",
		"no_puzzle": "Voor vandaag is er nog geen puzzel. Kies Oefenen.",
		"hint": "Veeg: alles wat die kant op mag, schuift mee. Breng de witte steen naar de opening.",
		"rule_more": "Blauw: alleen links/rechts. Oranje: alleen op/neer. Grijs en wit: alle kanten. Elke veeg telt, ook als je terugdraait.",
		"share_line": "White Shift #%d · %s vegen (par %s)",
		"unit": "vegen",
		"lang": "EN",
	},
	"en": {
		"levels": ["Easy", "Medium", "Hard"],
		"today": "Daily puzzle #%d",
		"practice": "Practice",
		"daily": "Today",
		"swipes": "Swipes: %d",
		"par": "Par: %d",
		"undo": "Undo",
		"restart": "Restart",
		"next": "Next",
		"solved": "Solved in %d swipes (par %d) · %s",
		"perfect": "Exactly par!",
		"show_best": "Best route",
		"share": "Share result",
		"copied": "Copied",
		"no_puzzle": "There is no puzzle for today yet. Choose Practice.",
		"hint": "Swipe: everything that may move that way slides along. Get the white stone to the opening.",
		"rule_more": "Blue: left/right only. Orange: up/down only. Grey and white: every way. Every swipe counts, also when you undo.",
		"share_line": "White Shift #%d · %s swipes (par %s)",
		"unit": "swipes",
		"lang": "NL",
	},
}

static var lang := "nl"


static func t(key: String) -> Variant:
	return TEXT[lang][key]


static func clock(ms: int) -> String:
	var s := ms / 1000
	return "%d:%02d" % [s / 60, s % 60]


## One line for all three puzzles of a day, without the solution. Unsolved levels show as "-".
static func share_line(number: int, swipes: Array, pars: Array) -> String:
	var a := PackedStringArray()
	for s in swipes:
		a.append("-" if s == null else str(s))
	var b := PackedStringArray()
	for p in pars:
		b.append(str(p))
	return t("share_line") % [number, "/".join(a), "/".join(b)]
