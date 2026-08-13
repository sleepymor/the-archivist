class_name GenderDetector
extends RefCounted

const FEMALE_NAMES := [
	"ningsih", "martha", "ying", "johanna", "fitri", "dewi", "louise",
	"christina", "rani", "wati", "rahayu", "putri", "sri", "dian",
	"tomiko", "hisako", "sumiko", "siti", "rina", "indah", "sinta",
	"lestari", "nurul", "ratna", "yuni", "wulan", "anisa", "hana",
	"kusuma", "ito"
]

static func guess_gender(full_name: String) -> String:
	var words: PackedStringArray = full_name.to_lower().split(" ")
	for word in words:
		if FEMALE_NAMES.has(word):
			return "female"
	return "male"
