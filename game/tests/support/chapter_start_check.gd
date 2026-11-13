extends RefCounted

## TEST-ONLY: the checks of one start of the dev launcher 从第几章开始 (tests/dev/chapter_start), shared by
## chapter_start_test.gd (序章 to 第四章, the launcher's words, panel and shell run),
## chapter_start_middle_test.gd (第五章 to 第八章) and chapter_start_late_test.gd (第九章 to 终章), split so the
## gate runs them side by side. For each start, on a real New Game of the runtime host:
## - the journal: the chapter begun and tracked, the one before it done, its first step current (not
##   already done by the placing), the objective that step's;
## - the place: the player in the start's zone, the step's person standing on its map, its place
##   reachable from where the player stands (a path on the map, or a chain of ways to its map);
## - the hand: what the chapters before it leave carried, the sword wielded for the sword build (the
##   build's school enabled), exp from the chapter's arrival up to what its own road pays; the step's
##   checklist rows tick;
## - Save, back to the main menu, Continue: the same chapter, step, place, things, marks and exp.

const Start := preload("res://tests/dev/chapter_start/chapter_start.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const Transaction := preload("res://tests/runtime/oldpine_save_load_transaction_test.gd")
const HOST_SCENE: PackedScene = preload("res://scenes/runtime/oldpine_game_runtime_host.tscn")
const MapPlaces := preload("res://tests/support/map_places.gd")

## Checklist rows of a first step that may stand unticked at its start, and why (the step's own work).
const UNTICKED: Dictionary[String, String] = {}

var count: int = 0
var failures: Array[String] = []


static func spec_of(quest_id: StringName, values: Dictionary = {}) -> ChapterStart.Spec:
	var out := ChapterStart.Spec.new()
	out.quest = quest_id
	for key: String in values:
		out.set(key, values[key])
	return out


## Every chapter of `quests` on the defaults, then `extra`.
static func specs(quests: Array[StringName], extra: Array[ChapterStart.Spec] = []) -> Array[ChapterStart.Spec]:
	var out: Array[ChapterStart.Spec] = []
	for quest_id: StringName in quests:
		out.append(spec_of(quest_id))
	out.append_array(extra)
	return out


func result() -> Dictionary[String, Variant]:
	return {"assertions": count, "failures": failures}


func test_start(tree: SceneTree, spec: ChapterStart.Spec) -> void:
	var label: String = spec.describe()
	var files := Transaction.MemoryFiles.new()
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	_check(host.configure_manual_before_start(GameSaveStorageProfile.isolated_test("chapter-start"), files), "%s: a test profile" % label)
	tree.root.add_child(host)
	await tree.process_frame
	host.opening_card = false
	if not host.request_new_game("凌雪" if spec.gender == CharacterState.GENDER_FEMALE else "凌风", spec.gender):
		_check(false, "%s: New Game" % label)
		host.free()
		return
	await host.new_game_completed
	var session: WorldSessionController = host.current_session()
	_check(session != null and session.is_initialized(), "%s: New Game's session" % label)
	if session == null:
		host.free()
		return
	var problem: String = Start.apply(session, spec)
	_check(problem.is_empty(), "%s: applied (%s)" % [label, problem])
	await _frames(tree, 4)
	if spec.quest == &"main.prologue":
		_check(session.player_runtime().state.progression.combat_experience == 0 and session.player_runtime().state.marks.is_empty(), "序章: the New Game itself, nothing written")
	else:
		_check_start(session, spec, label)
	var before: Dictionary = _facts(session)
	# A refused request is a failure, not a wait: its signal never comes.
	var saved: bool = host.request_save()
	_check(saved, "%s: Save" % label)
	if saved:
		saved = (await host.save_completed).succeeded()
		_check(saved, "%s: saved" % label)
	var ended: bool = saved and host.request_end_session()
	_check(ended, "%s: back to the menu" % label)
	if ended:
		await host.end_session_completed
	var continued: bool = ended and host.request_continue()
	_check(continued, "%s: Continue" % label)
	if continued:
		var loaded: OldPineRuntimeSaveLoadResult = await host.continue_completed
		_check(loaded.succeeded() and host.current_session() != null, "%s: continued" % label)
		if loaded.succeeded():
			await _frames(tree, 4)
			var after: Dictionary = _facts(host.current_session())
			for key: String in before:
				_check(after.get(key) == before[key], "%s: after Continue, the same %s (%s / %s)" % [label, key, before[key], after.get(key)])
	host.get_parent().remove_child(host)
	host.free()
	await tree.process_frame


func _check_start(session: WorldSessionController, spec: ChapterStart.Spec, label: String) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quests: Array[StoryQuestDefinition] = catalog.story_quests()
	var quest: StoryQuestDefinition = catalog.story_quest(spec.quest)
	var state: CharacterState = session.player_runtime().state
	# The journal.
	for required: StringName in quest.requires:
		_check(StoryQuestLog.is_done(state, catalog.story_quest(required)), "%s: %s done" % [label, required])
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.tracked(state, quests) == quest, "%s: the chapter begun and tracked" % label)
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step == quest.steps[0], "%s: its first step current (%s)" % [label, "none" if step == null else String(step.step_id)])
	_check(step != null and StoryQuestLog.objective(state, quests) == step.objective and not step.objective.is_empty(), "%s: the objective: %s" % [label, StoryQuestLog.objective(state, quests)])
	if step == null:
		return
	# The place.
	var map: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	var start_zone: StringName = ChapterStart.START[ChapterStart.index_of(spec.quest)]["zone"]
	_check(map != null and location != null and location.zone_id == start_zone, "%s: the player in %s (%s)" % [label, start_zone, "?" if location == null else String(location.zone_id)])
	var target: StoryQuestDefinition.Target = step.target
	if target != null and not target.npc_ids.is_empty():
		var standing: Array[StringName] = target.npc_ids.filter(func(npc_id: StringName) -> bool: return ChapterStart.standing(session, npc_id, target.map_id) != null)
		_check(not standing.is_empty(), "%s: the step's person on %s (one of %s)" % [label, target.map_id, target.npc_ids])
	if target != null and map != null and location != null and location.zone_id != target.zone_id:
		if map.map_id() == target.map_id:
			var to: Vector2 = MapPlaces.zone_spot(map, target.zone_id)
			_check(to.is_finite() and not MapRoute.path(map, map.runtime_player_body().global_position, to).is_empty(), "%s: a way on the map to %s" % [label, target.zone_id])
		else:
			_check(not MapPlaces.portal_chain(map.map_id(), target.map_id).is_empty(), "%s: ways from %s to %s" % [label, map.map_id(), target.map_id])
	# The hand.
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	for item_id: StringName in ChapterStart.carried(spec):
		_check(held.get(item_id, false), "%s: %s carried" % [label, item_id])
	# What arriving here pays on the chapter's own road (its new region's first visit) comes on top;
	# the regions before it are visited already, so nothing is paid twice.
	var arrival: int = ChapterStart.arrival_exp(spec)
	var after: int = _next_arrival(spec)
	var experience: int = state.progression.combat_experience
	_check(experience >= arrival and (experience < after or (after == arrival and experience == arrival)), "%s: exp %d from the chapter's arrival %d, below the next one's %d" % [label, experience, arrival, after])
	var weapon: EquippedWeaponRef = state.equipment.primary_weapon()
	_check((weapon != null) == spec.sword, "%s: %s" % [label, "a sword in hand" if spec.sword else "bare-handed"])
	_check(state.skills.mapped_skill(&"sword" if spec.sword else &"unarmed") == (&"fonxansword" if spec.sword else &"liuh-ken"), "%s: the build's school enabled" % label)
	for checked: StoryQuestLog.Checked in StoryQuestLog.checked(step, session.quest_condition_test()):
		if checked.tick == StoryQuestLog.Checked.Tick.LACKING:
			_check(UNTICKED.has(checked.row.label), "%s: checklist row「%s」lacking" % [label, checked.row.label])


## The arrival exp of the chapter after the spec's (the same for 终章, the last).
static func _next_arrival(spec: ChapterStart.Spec) -> int:
	var at: int = ChapterStart.index_of(spec.quest)
	var next: StringName = ChapterStart.START[mini(at + 1, ChapterStart.START.size() - 1)]["quest"]
	return Arrival.exploring(next) if spec.exploring else Arrival.main_story(next)


## What a Continue must bring back of a start.
func _facts(session: WorldSessionController) -> Dictionary:
	var state: CharacterState = session.player_runtime().state
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var tracked: StoryQuestDefinition = StoryQuestLog.tracked(state, quests)
	var step: StoryQuestDefinition.Step = null if tracked == null else StoryQuestLog.current_step(state, tracked)
	var held: Array = session.player_held_item_ids().keys()
	held.sort()
	var marks: Array = state.marks.keys()
	marks.sort()
	var location: WorldLocationState = session.player_runtime().world_location()
	return {
		"quest": "" if tracked == null else String(tracked.quest_id),
		"step": "" if step == null else String(step.step_id),
		"zone": "" if location == null else String(location.zone_id),
		"things": ",".join(held),
		"marks": ",".join(marks),
		"exp": state.progression.combat_experience,
		"weapon": state.equipment.primary_weapon() != null,
	}


func _frames(tree: SceneTree, frames: int) -> void:
	for frame: int in frames:
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures.append(label)
