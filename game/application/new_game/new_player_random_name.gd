class_name NewPlayerRandomName
extends RefCounted
## A name for the New Game screen's 随机名字 (owner, gamepad support: a pad has no keys to
## type one): a surname and a given name from NAMES_PATH, the given name for the chosen
## gender (either list before one is chosen). Native: ES2's login asked for a typed name.

const NAMES_PATH: String = "res://data/new_game/names.json"


static func pick(gender: StringName, rng: RandomNumberGenerator) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH))
	var surnames: Array = data["surnames"]
	var given: Array = []
	if gender == CharacterState.GENDER_MALE:
		given = data["given"]["male"]
	elif gender == CharacterState.GENDER_FEMALE:
		given = data["given"]["female"]
	else:
		given = data["given"]["male"] + data["given"]["female"]
	return String(surnames[rng.randi_range(0, surnames.size() - 1)]) + String(given[rng.randi_range(0, given.size() - 1)])
