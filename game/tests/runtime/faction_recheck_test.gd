extends RefCounted

## 势力线复查 (2026-11-26; DECISIONS「势力线复查」), what the choices leave in the world and what was promised:
## the 逆灵宫 once its 余孽 are settled (nobody on its stages, the rope free, the 官兵 inside the gate, the rooms
## read as left).

const SETTLED: String = "余孽有了去处"
const CRUSHED: String = "余孽交了官府"
const PARDONED: String = "招安了余孽"
const SOLDIERS: StringName = &"niling.yard.soldiers"
## What a player who walked every way of the 逆灵宫 carries: with these alone its people are all on their stages.
const WALKED: Array[String] = ["见过唤首", "祭坛的鬼卒倒了", "答应了做眼线", "林忌说了地牢", "被识破", "终章"]

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_empty_temple()
	_test_empty_rooms()
	return {"assertions": _count, "failures": _failures.duplicate()}


## 余孽有了去处: no spawn of the 逆灵宫's maps (nor the turn's 押车道士 and 追杀的道士) is on its stage; given to the
## 官府, two 官兵 stand where the 守门道士 stood.
func _test_empty_temple() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var checked: int = 0
	for spawn: NpcSpawnDefinition in catalog.spawns():
		var turn: bool = spawn.spawn_id in [&"native.mroad4.tribute_taoists", &"native.mroad4.niling_pursuers"]
		# One a scene summons (the 无头黑影, the 祭坛's 鬼卒) stands only while its scene plays.
		if (not String(spawn.map_id).begins_with("niling.") and not turn) or spawn.summoned:
			continue
		checked += 1
		for outcome: String in [CRUSHED, PARDONED]:
			var state: CharacterState = _fresh(WALKED + [SETTLED, outcome])
			state.quests["main.chapter3#started"] = 1 # TEST-ONLY
			state.quests["main.chapter3/choice/chase"] = 1 # TEST-ONLY: 第三章's own prisoners left with its choice
			var stays: bool = spawn.spawn_id == SOLDIERS and outcome == CRUSHED
			_check(_on_stage(spawn, state) == stays, "%s after %s: %s" % [spawn.spawn_id, outcome, "there" if stays else "gone"])
	_check(checked >= 20, "the 逆灵宫's spawns were looked at (%d)" % checked)
	var soldiers: NpcSpawnDefinition = catalog.spawn(SOLDIERS)
	_check(soldiers != null and soldiers.quantity == 2 and not _on_stage(soldiers, _fresh(WALKED)), "no 官兵 before the 余孽 are given up")
	var soldier: NpcDefinition = catalog.npc(&"native.npc.niling_soldier")
	_check(soldier != null and soldier.display_name == "官兵", "the 官兵")
	var guards: NpcSpawnDefinition = catalog.spawn(&"niling.yard.gate_guards")
	_check(guards != null and not _on_stage(guards, _fresh(WALKED + [SETTLED, CRUSHED])), "the 守门道士 are gone from where the 官兵 stand")


## The rooms that name their people, their fire or their lamp read as left: by the outcome where it shows.
func _test_empty_rooms() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var front: ZoneDefinition = catalog.zone(&"niling.front")
	_check(front.description_for(_fresh(WALKED).marks) == front.description and front.description.contains("诵经"), "before: the 前殿 chants")
	_check(front.description_for(_fresh([SETTLED, CRUSHED]).marks).contains("掀翻") and front.description_for(_fresh([SETTLED, PARDONED]).marks).contains("排得整整齐齐"), "the 前殿 after, by the outcome")
	for zone_id: StringName in [&"niling.gatehouse", &"niling.yard", &"niling.front", &"niling.alchemy", &"niling.corridor", &"niling.altar"]:
		var zone: ZoneDefinition = catalog.zone(zone_id)
		for outcome: String in [CRUSHED, PARDONED]:
			var text: String = zone.description_for(_fresh([SETTLED, outcome]).marks)
			_check(text != zone.description and not text.contains("诵经") and not text.contains("黑焰") and not text.contains("桌后坐着"), "%s after %s reads as left" % [zone_id, outcome])
	_check(catalog.zone(&"niling.gatehouse").description_for(_fresh([SETTLED, CRUSHED]).marks).contains("封条"), "the 官府's seal on the gate")


func _on_stage(spawn: NpcSpawnDefinition, state: CharacterState) -> bool:
	return spawn != null and _holds(spawn.present, state) and not (spawn.until != null and _holds(spawn.until, state))


func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY
	return state


func _holds(condition: JournalEntryDefinition, state: CharacterState) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return condition == null or JournalLog.holds(condition, state, temps, held)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
