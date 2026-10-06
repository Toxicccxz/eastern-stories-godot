extends RefCounted

## Which of the 84 names in quest/qlist*.c 朱鸿雪 can give now (owner, 3C): a target
## counts once an NPC of that name is placed and can be fought. The list is recorded
## in tests/fixtures/quest_targets.json; a region package that places a target (or
## renames one) sees it here and re-records the list deliberately with
## UPDATE_QUEST_TARGETS=1, so no quest target is forgotten.
const FIXTURE_PATH: String = "res://tests/fixtures/quest_targets.json"

var _count: int = 0
var _failures: Array[String] = []


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	var actual: Dictionary = coverage(GameContent.catalog())
	if OS.get_environment("UPDATE_QUEST_TARGETS") == "1":
		var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t", false) + "\n")
		file.close()
		print("wrote %s" % FIXTURE_PATH)
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	_check(expected is Dictionary, "the recorded quest targets are readable")
	if expected is Dictionary:
		var normalized: Dictionary = JSON.parse_string(JSON.stringify(actual))
		for key: String in normalized:
			_check(JSON.stringify(normalized[key]) == JSON.stringify(expected.get(key)), "%s match the recording (UPDATE_QUEST_TARGETS=1 re-records): %s" % [key, JSON.stringify(normalized[key])])
	var names: Array = actual["available"] + actual["missing"]
	_check(names.size() == 84, "84 names in the 15 lists (书生, 仆役, 后备兵 only in commented-out entries): %d" % names.size())
	return {"assertions": _count, "failures": _failures}


## {"available": [names], "missing": [names], "tiers": [{min_exp, available, entries}]}.
static func coverage(catalog: ContentCatalog) -> Dictionary:
	var available: Dictionary[String, bool] = {}
	var missing: Dictionary[String, bool] = {}
	var tiers: Array[Dictionary] = []
	for tier: QuestTier in catalog.quest_tiers():
		var count: int = 0
		for quest: QuestDefinition in tier.quests:
			if catalog.quest_target_available(quest.target):
				available[quest.target] = true
				count += 1
			else:
				missing[quest.target] = true
		tiers.append({"min_exp": tier.min_exp, "available": count, "entries": tier.quests.size()})
	var available_names: Array[String] = []
	available_names.assign(available.keys())
	var missing_names: Array[String] = []
	missing_names.assign(missing.keys())
	available_names.sort()
	missing_names.sort()
	return {"available": available_names, "missing": missing_names, "tiers": tiers}


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("quest targets: " + label)
