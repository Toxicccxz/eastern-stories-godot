extends RefCounted

## DECISIONS「势力线的仗」: 步玄's 问剑 measured. It is a 切磋 with its own way to win — the 风泉剑灵's four
## lines each make it stronger, and the fourth (剑神如意) ends the bout; a blow landed before it passes
## the 问剑 — so MainlineFightSim (lethal fights, won when the foes are down) does not fit it. Here the
## spar is fought as faction_buxuan_a_test fights it (tests/support/real_fight.gd: the real coordinator
## and scheduler, the plain policy, the player grown to the story's arrival), TRIES times with as many
## seeds, by the sword build and by the fist build, at 第五章's arrival for one who follows only the
## main story (乔阴 is 第五章's). Not a wall (the 剑灵 is back the next night), and not tuned: a try
## passes most times, and this keeps it so — a change elsewhere (growth, a rule, the 剑灵's numbers)
## that turns the 问剑 into a night-after-night wait shows here.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RealFight := preload("res://tests/support/real_fight.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const SOUL: StringName = &"native.npc.sword_soul_spar"
const ENTRANCE: StringName = &"choyin.entrance"
const ENTRANCE_POINT: StringName = &"choyin.entrance.grove_return"
## Somewhere else to stand between two tries (the stage is laid again on the way back).
const ASIDE: StringName = &"choyin.s_street2"
const ASIDE_POINT: StringName = &"choyin.s_street2.yu_steward.1"
const NIGHT_SECONDS: int = 19 * 3600
const TRIES: int = 15
## A try passes at least this often (15 tries: one that passes nine times in ten falls under it by
## chance about once in a thousand runs).
const FLOOR: float = 0.60

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for sword: bool in [true, false]:
		await _measure(tree, sword)
	return {"assertions": _count, "failures": _failures.duplicate()}


func _measure(tree: SceneTree, sword: bool) -> void:
	var session: WorldSessionController = await _session(tree)
	var state: CharacterState = session.player_runtime().state
	var experience: int = Arrival.tuned(&"main.chapter5")
	state.marks["骆云舟插了剑"] = 1 # TEST-ONLY: the 问剑 asked for; the sword stands in the stone
	session.day_clock().set_day_seconds(NIGHT_SECONDS)
	var passed: int = 0
	var fought: int = 0
	for attempt: int in TRIES:
		state.marks.erase("问剑过了") # TEST-ONLY: each try as the first
		state.marks.erase("剑灵回了剑")
		session.day_clock().set_day_seconds(NIGHT_SECONDS)
		MapPlaces.enter(session, ASIDE, ASIDE_POINT)
		await _settle(tree)
		var map: WorldMapController = MapPlaces.enter(session, ENTRANCE, ENTRANCE_POINT)
		await _settle(tree)
		var soul: NpcRuntimeState = _first(session, ENTRANCE, SOUL)
		if attempt == 0:
			RealFight.ready_player(session, experience, &"es2:obj/longsword" if sword else &"", 1)
		else:
			RealFight.Grown.grow(state, experience, 50, sword)
			RealFight.Grown.heal(state)
			session.configure_combat_random_source(RealFight.Specials.Seeded.new(attempt + 1))
		# A blow may have laid it out the try before (it can only be knocked down): on its feet and whole again.
		if soul != null and soul.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			map.npc_life.revive(soul, false)
		if soul != null:
			RealFight.Grown.heal(soul.character_state)
		if map == null or soul == null or not map.select_npc(soul.character_id) or map.spar_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
			continue
		var steps: int = RealFight.fight_out(session)
		await _settle(tree)
		if steps >= RealFight.MAX_STEPS:
			continue
		fought += 1
		passed += 1 if state.marks.get("问剑过了", 0) == 1 else 0
	var build: String = "sword" if sword else "fist"
	print("问剑 %s at %d: %d of %d tries passed" % [build, experience, passed, fought])
	_check(fought == TRIES, "%s: every try was a spar fought to its end (%d of %d)" % [build, fought, TRIES])
	_check(fought > 0 and float(passed) / float(fought) >= FLOOR, "%s: a try of the 问剑 passes at least %d%% of the time at 第五章's arrival (%d of %d)" % [build, int(FLOOR * 100.0), passed, fought])
	session.free()
	await tree.process_frame


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("问剑", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
