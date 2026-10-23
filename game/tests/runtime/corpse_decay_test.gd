extends RefCounted

## 尸体腐烂 (owner Q2, 2026-10-23; DECISIONS): obj/corpse.c decay() on world time, ES2's
## 120, 120 and 60 seconds (pacing.json knobs): 某某的尸体 rots (腐烂的尸体), dries to bones
## (一具枯乾的骸骨: no corpse any more, nothing dissolves or raises it) and scatters, what it
## held falling where it lay. On the player's map its say() is heard; on another map it comes
## to its stage when the map is caught up. Its age is saved.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const T1: StringName = &"snow.inn.main_floor.inn.traveller.1.character"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _decays_in_sight(tree)
	await _decays_away(tree)
	await _continue_keeps_its_age(tree)
	await _knob_off(tree)
	return {"assertions": _count, "failures": _failures}


## Killed in the inn where the player stands: 2 min, 4 min, 5 min.
func _decays_in_sight(tree: SceneTree) -> void:
	var session: WorldSessionController = await _session(tree)
	var map: WorldMapController = session.active_map() as WorldMapController
	var corpse: CorpseState = _kill(session, T1)
	_check(corpse != null and map.corpses.corpse_name(corpse) == "旅客的尸体", "the 旅客 dies and lies as 旅客的尸体")
	if corpse == null:
		session.free()
		return
	var held: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id))
	_check(held.size() >= 2 and not corpse.occupied_worn_slots().is_empty(), "it holds the 旅客's coins and wears his cloth")
	_beats(session, 119)
	_check(corpse.decay_stage == CorpseState.Stage.FRESH, "at 119 s still fresh")
	_beats(session, 1)
	_check(corpse.decay_stage == CorpseState.Stage.ROTTEN and map.corpses.corpse_name(corpse) == "腐烂的尸体", "at 120 s it rots: 腐烂的尸体")
	_check(_heard(session, "旅客的尸体开始腐烂了，发出一股难闻的恶臭。"), "the player in its room reads it rot")
	_check(map.corpses.corpse_view_for(corpse.corpse_item_instance_id).get_node("NameLabel").text == "腐烂的尸体", "its label says 腐烂的尸体")
	_check(map.select_corpse(corpse.corpse_item_instance_id) and map.dissolvable_corpse_name() == "腐烂的尸体", "a rotten corpse is still a corpse: 化尸粉 would take it")
	_beats(session, 120)
	_check(corpse.decay_stage == CorpseState.Stage.SKELETON and map.corpses.corpse_name(corpse) == "一具枯乾的骸骨", "at 240 s: 一具枯乾的骸骨")
	_check(_heard(session, "腐烂的尸体被风吹乾了，变成一具骸骨。"), "the player reads it dry to bones")
	_check(map.dissolvable_corpse_name() == "" and map.animatable_corpse() == null, "bones are no corpse: nothing dissolves or raises them")
	_beats(session, 60)
	_check(map.corpses.find_corpse(corpse.corpse_item_instance_id) == null, "at 300 s the bones are gone")
	_check(_heard(session, "一阵风吹过，把一具枯乾的骸骨化成骨灰吹散了。"), "the player reads a gust scatter them")
	var on_floor: int = 0
	for item_id: StringName in held:
		if map.dropped_item_ids().has(item_id):
			on_floor += 1
	_check(on_floor == held.size(), "what it held lies on the floor where it lay (%d of %d)" % [on_floor, held.size()])
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open after the scattering")
	session.free()
	await tree.process_frame


## Killed in the inn, the player out on the square six minutes: coming back, it is gone and
## what it held lies there; nothing of it was read on the square.
func _decays_away(tree: SceneTree) -> void:
	var session: WorldSessionController = await _session(tree)
	var inn: WorldMapController = session.active_map() as WorldMapController
	var corpse: CorpseState = _kill(session, T1)
	if corpse == null:
		_check(false, "the away run kills the 旅客")
		session.free()
		return
	var held: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id))
	var zone: ZoneDefinition = GameContent.catalog().zone(&"snow.square")
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", zone.combat_location_id, &"snow.square.inn_entry").succeeded(), "out onto the square")
	_beats(session, 360)
	_check(inn.corpses.find_corpse(corpse.corpse_item_instance_id) != null, "while nobody looks the inn waits")
	_check(not _heard(session, "化成骨灰吹散了"), "nothing of it is read on the square")
	session.catch_up_map(inn)
	_check(inn.corpses.find_corpse(corpse.corpse_item_instance_id) == null, "caught up, it has scattered")
	var on_floor: int = 0
	for item_id: StringName in held:
		if inn.dropped_item_ids().has(item_id):
			on_floor += 1
	_check(on_floor == held.size(), "what it held lies on the inn's floor")
	session.free()
	await tree.process_frame


## Saved rotten at 150 s: Continue keeps its stage and age, and it dries at 240 s.
func _continue_keeps_its_age(tree: SceneTree) -> void:
	var session: WorldSessionController = await _session(tree)
	var corpse: CorpseState = _kill(session, T1)
	if corpse == null:
		_check(false, "the save run kills the 旅客")
		session.free()
		return
	var corpse_id: StringName = corpse.corpse_item_instance_id
	_beats(session, 150)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var saved: GameSaveValueTypes.CorpseSnapshot = null
	if snapshot != null:
		for record: GameSaveValueTypes.CorpseSnapshot in snapshot.corpses:
			if record.corpse_item_instance_id == corpse_id:
				saved = record
	_check(saved != null and saved.decay_stage == CorpseState.Stage.ROTTEN and saved.age_ms == 150_000, "the save keeps it rotten, 150 s old")
	session.free()
	await tree.process_frame
	if snapshot == null:
		return
	var text: String = GameSaveJsonCodec.encode(snapshot).text
	var read: GameSaveResult = GameSaveJsonCodec.decode(text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(read.snapshot, tree.root)
	if restored.succeeded():
		restored.candidate.set_process(false)
	_check(read.succeeded() and restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue builds the world")
	if not restored.succeeded():
		return
	var world: WorldSessionController = restored.candidate
	await tree.process_frame
	var map: WorldMapController = world.active_map() as WorldMapController
	var back: CorpseState = map.corpses.find_corpse(corpse_id)
	_check(back != null and back.decay_stage == CorpseState.Stage.ROTTEN and map.corpses.age_ms(back) == 150_000, "Continue: rotten, 150 s old")
	_check(GameSaveJsonCodec.encode(Work.capture(world)).text == text, "the restored world saves the same")
	_beats(world, 89)
	_check(back.decay_stage == CorpseState.Stage.ROTTEN, "at 239 s still rotten")
	_beats(world, 1)
	_check(back.decay_stage == CorpseState.Stage.SKELETON, "at 240 s bones, as without the save")
	world.free()
	await tree.process_frame


## corpse_rot_seconds 0: corpses stay as before.
func _knob_off(tree: SceneTree) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	GameContent.catalog().set_pacing(pacing.copy().with_corpse_decay(0, 120, 60))
	var session: WorldSessionController = await _session(tree)
	var corpse: CorpseState = _kill(session, T1)
	_beats(session, 1000)
	_check(corpse != null and corpse.decay_stage == CorpseState.Stage.FRESH and (session.active_map() as WorldMapController).corpses.find_corpse(corpse.corpse_item_instance_id) != null, "with corpse_rot_seconds 0 a corpse stays")
	session.free()
	await tree.process_frame
	GameContent.catalog().set_pacing(pacing)


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = Work.create_session(tree)
	session.set_process(false)
	await tree.process_frame
	return session


## TEST-ONLY: a wound past death (eff_kee below zero); char.c's next beat lets it die.
func _kill(session: WorldSessionController, character_id: StringName) -> CorpseState:
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = map.npcs.find_resident_npc(character_id)
	if npc == null:
		return null
	var before: Array[CorpseState] = map.corpses.corpse_states()
	npc.character_state.vitality.effective = -1
	session.advance_npc_heartbeat(0.0)
	for corpse: CorpseState in map.corpses.corpse_states():
		if not before.has(corpse) and corpse.victim_character_id == character_id:
			return corpse
	return null


func _beats(session: WorldSessionController, seconds: int) -> void:
	for _second: int in seconds:
		session.advance_npc_heartbeat(1.0)


func _heard(session: WorldSessionController, text: String) -> bool:
	for line: String in session.shared_ui().log_lines():
		if line.contains(text):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
