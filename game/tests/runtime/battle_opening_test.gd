extends RefCounted

## How a fight opens in the battle panel, which covers the log: what was said
## (fight.c, kill.c) opens the battle log, and feature/attack.c kill_ob()'s
## 看起来X想杀死你！ from every NPC that fights the player to the death stays
## pinned under the title in HIR red. A spar has no warning; the player's attack
## gets the target's (kill.c obj->kill_ob(me)); the crazy dog's (combatd.c
## start_aggressive()) is its only line; 安惜迩 turns a spar into his kill. Those of one
## name share one line (DECISIONS「同名杀意合一行」): the lake's five 黑冠巨蟒 warn once, ×5.
## TEST-ONLY fixtures, each marked where used: combat experience, healing.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _hud: SharedGameplayUI
var _ui: BattlePresentationController
var _coordinator: CombatEncounterCoordinator


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_hud = _session.shared_ui()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	_coordinator = _session.combat_encounter_coordinator()
	# TEST-ONLY: fights the player wins quickly.
	_player.state.progression.combat_experience = 100000
	await _test_attack(tree)
	await _test_spar(tree)
	await _test_spar_over_before_shown(tree)
	await _test_crazy_dog(tree)
	_test_merged_warnings()
	await _test_annihir(tree)
	# Last: 老松林, away from 雪亭镇.
	await _test_serpents(tree)
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_attack(tree: SceneTree) -> void:
	_heal()
	var map: WorldMapController = await _beside(tree, &"snow.school2", &"snow.school2.trainee.2")
	_check(map != null, "beside a trainee")
	await tree.physics_frame
	map.select_npc(MapPlaces.npc_at(_session, &"snow.school2.trainee.2").character_id)
	var before: int = _hud.log_lines().size()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "an attack starts")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	var warning: String = "看起来武馆弟子想杀死你！"
	_check(said.size() == 2 and said[0].begins_with("你对著武馆弟子喝道：「") and said[0].ends_with("今日不是你死就是我活！」") and said[1] == warning, "kill.c's line, then obj->kill_ob(me): " + str(said))
	_check(_hud.combat_log.text.ends_with("[color=#%s]%s[/color]" % [SharedGameplayUI.ALERT_COLOR.to_html(false), warning]), "the warning in HIR red in the log")
	_ui.refresh_projection()
	_check_projection_is_the_queries()
	_check(_warning().is_visible_in_tree() and _warning().text == warning, "pinned under the title: " + _warning().text)
	_check(_log().begins_with("\n".join(PackedStringArray(said))), "the battle log opens with both: " + _log().left(120))
	_check(_strip() == said and _strip_red(1) and not _strip_red(0), "the recent strip shows them, the warning in red: " + str(_strip()))
	for _second: int in range(10):
		if not _coordinator.has_active_encounter() or not _strip().has(warning):
			break
		_coordinator.advance_scheduler(1.0)
		_ui.refresh_projection()
	_check(_coordinator.has_active_encounter() and not _strip().has(warning) and _warning().is_visible_in_tree(), "still pinned once the blows push it out of the recent strip")
	_check_projection_is_the_queries()
	await _finish(tree)
	var result: String = _hud.log_lines().back()
	_check(not result.contains(warning) and not result.contains("喝道"), "the fight's result does not repeat the opening: " + result)


## A spar after a lethal fight: nothing pinned is left over.
func _test_spar(tree: SceneTree) -> void:
	_heal()
	var map: WorldMapController = await _beside(tree, &"snow.school2", &"snow.school2.trainee.1")
	_check(map != null, "beside another trainee")
	await tree.physics_frame
	map.select_npc(MapPlaces.npc_at(_session, &"snow.school2.trainee.1").character_id)
	var before: int = _hud.log_lines().size()
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	_check(said.size() == 2 and said[0].begins_with("你对著武馆弟子说道：") and said[1].begins_with("武馆弟子说道："), "fight.c's words and npc.c accept_fight()'s answer: " + str(said))
	var id: StringName = _coordinator.active_encounter().encounter_id
	_check(_coordinator.opening_lines(id) == said and _coordinator.opening_warnings(id).is_empty(), "the opening is what the log got, no warning")
	_ui.refresh_projection()
	_check(_log().begins_with("\n".join(PackedStringArray(said))) and not _log().contains("想杀死你"), "the battle log opens with them, nothing from the last fight: " + _log().left(120))
	_check(_strip() == said, "the recent strip shows them before the first blow: " + str(_strip()))
	_check(not _warning().visible, "a spar after a lethal fight pins no warning")
	_check(_coordinator.opening_lines(&"encounter:another").is_empty(), "the opening belongs to its fight")
	await _finish(tree)


## A spar that ends before the panel ever shows it (the completed_cast path).
func _test_spar_over_before_shown(tree: SceneTree) -> void:
	_heal()
	var map: WorldMapController = await _beside(tree, &"snow.school2", &"snow.school2.trainee.3")
	_check(map != null, "beside a third trainee")
	await tree.physics_frame
	map.select_npc(MapPlaces.npc_at(_session, &"snow.school2.trainee.3").character_id)
	var before: int = _hud.log_lines().size()
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	for _second: int in range(600):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "it ends unseen")
	_ui.refresh_projection()
	_check(said.size() == 2 and _log().begins_with("\n".join(PackedStringArray(said))), "the battle log still opens with the opening: " + _log().left(120))
	var result: String = _hud.log_lines().back()
	_check(said.size() == 2 and result.begins_with("切磋结束。") and not result.contains(said[0]) and not result.contains(said[1]), "the result says how it ended, not the opening again: " + result)
	await tree.process_frame


func _test_crazy_dog(tree: SceneTree) -> void:
	_heal()
	var before: int = _hud.log_lines().size()
	_check(await _beside(tree, &"snow.sroad4", &"snow.sroad4.crazy_dog.1") != null, "beside the crazy dog")
	for _frame: int in range(30):
		await tree.physics_frame
		if _coordinator.has_active_encounter():
			break
	_check(_coordinator.has_active_encounter(), "the crazy dog attacks")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	var warning: String = "看起来疯狗想杀死你！"
	_check(said.count(warning) == 1 and said.back() == warning and not "\n".join(PackedStringArray(said)).contains("发动攻击"), "start_aggressive() says nothing, kill_ob() warns once: " + str(said))
	var id: StringName = _coordinator.active_encounter().encounter_id
	_check(_coordinator.opening_lines(id).is_empty() and _coordinator.opening_warnings(id) == [warning], "the opening is the warning alone")
	_ui.refresh_projection()
	_check(_warning().is_visible_in_tree() and _warning().text == warning and _log().begins_with(warning), "pinned, and the battle log opens with it")
	await _finish(tree)


## CombatKillWarning: one line a name, in the order each first came, the count after it.
func _test_merged_warnings() -> void:
	var names: Array[String] = ["黑冠巨蟒", "毒蛇", "黑冠巨蟒", "黑冠巨蟒"]
	_check(CombatKillWarning.lines(names) == ["看起来黑冠巨蟒（×3）想杀死你！", "看起来毒蛇想杀死你！"], "one line a name, its count: " + str(CombatKillWarning.lines(names)))
	_check(CombatKillWarning.lines(["疯狗"]) == ["看起来疯狗想杀死你！"] and CombatKillWarning.lines([]).is_empty(), "one alone: ES2's line")


## d/oldpine/lake.c: five 黑冠巨蟒 set on the player at once; kill_ob() warns once for them all,
## in the log and pinned; one more of them turning on the player later (roar.c) counts in.
func _test_serpents(tree: SceneTree) -> void:
	_heal()
	# TEST-ONLY: kee to outlast five serpents.
	_player.state.vitality = CharacterResourceState.new(6000, 6000, 6000)
	var before: int = _hud.log_lines().size()
	_check(await _beside(tree, &"oldpine.gorge.lake", &"oldpine.gorge.lake.serpent.1") != null, "beside the lake's serpents")
	for _frame: int in range(240):
		await tree.physics_frame
		if _coordinator.has_active_encounter():
			break
	_check(_coordinator.has_active_encounter(), "the serpents attack")
	if not _coordinator.has_active_encounter():
		return
	var serpents: int = 0
	for participant: CombatParticipant in _coordinator.active_encounter().participants():
		if participant.participant_id != _player.character_id:
			serpents += 1
	var warning: String = "看起来黑冠巨蟒（×%d）想杀死你！" % serpents
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	var warned: int = 0
	for line: String in said:
		if line.contains("想杀死你"):
			warned += 1
	_check(serpents == 5 and warned == 1 and said.has(warning), "five serpents, one warning in the log: " + str(said))
	var id: StringName = _coordinator.active_encounter().encounter_id
	_check(_coordinator.opening_warnings(id) == [warning], "one pinned: " + str(_coordinator.opening_warnings(id)))
	_ui.refresh_projection()
	_check(_warning().is_visible_in_tree() and _warning().text == warning, "pinned under the title, one line: " + _warning().text)
	_check(_strip().count(warning) == 1, "the recent strip says it once: " + str(_strip()))
	_coordinator.note_warnings(["黑冠巨蟒"])
	_check(_coordinator.opening_warnings(id) == ["看起来黑冠巨蟒（×%d）想杀死你！" % (serpents + 1)], "one more of them turning later counts in")
	await _finish(tree)


func _test_annihir(tree: SceneTree) -> void:
	_heal()
	# TEST-ONLY: kee to outlast 安惜迩 while fleeing.
	_player.state.vitality = CharacterResourceState.new(3000, 3000, 3000)
	var map: WorldMapController = await _beside(tree, &"snow.bank", &"snow.bank.annihir.1")
	_check(map != null, "in the bank")
	await tree.physics_frame
	map.select_npc(MapPlaces.npc_at(_session, &"snow.bank.annihir.1").character_id)
	var before: int = _hud.log_lines().size()
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "安惜迩 takes the challenge")
	var warning: String = "看起来安惜迩想杀死你！"
	_ui.refresh_projection()
	var lines: PackedStringArray = _log().split("\n")
	_check(lines.size() >= 3 and lines[0].begins_with("你对著安惜迩说道：") and lines[1] == "安惜迩说道：咦... 要打就真打吧，光是较量多没意思？" and lines[2] == warning, "the battle log opens with the spar, his answer and kill_ob(): " + str(lines.slice(0, 3)))
	_check(_warning().is_visible_in_tree() and _warning().text == warning, "pinned under 死斗")
	_check(_ui._title.text == "死斗" and _ui.shown_mode() == CombatEncounterMode.Value.LETHAL and _ui._shade.color == UiPalette.SCRIM_LETHAL, "the title says 死斗, in its look: " + _ui._title.text)
	_check(_strip().back() == warning and _strip_red(2), "the recent strip ends with it, red, before the first blow")
	# Flee at once: the result must not repeat the opening the log already has.
	for attempt: int in range(30):
		if not _coordinator.has_active_encounter():
			break
		if _coordinator.active_encounter().queued_player_action() == null:
			var info: CombatTacticalActionInfo = _coordinator.action_infos()[0]
			_coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), _coordinator.active_encounter().encounter_id, _player.character_id, info.action_id, info.category))
		_coordinator.advance_scheduler(1.0)
		_ui.refresh_projection()
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "fled: " + _coordinator.last_abort_detail())
	_ui.refresh_projection()
	var after: Array[String] = []
	after.assign(_hud.log_lines().slice(before))
	_check(after.count(warning) == 1 and not after.back().contains(warning) and after.back().begins_with("你逃离了战斗"), "the warning is written once; the result does not repeat it: " + str(after.slice(-2)))
	await tree.process_frame


## The panel's projection is built from one read of the fight a frame (CombatEncounterRead):
## what it shows is what the coordinator's own queries answer, one by one.
func _check_projection_is_the_queries() -> void:
	var shown: BattlePresentationProjection = BattleProjectionBuilder.build(_session)
	_check(shown.active and shown.participants().size() == 2, "a fight to project")
	var moves: Array[CombatActionDefinition] = _coordinator.player_moves()
	var shown_ids: Array[StringName] = []
	for move: CombatActionDefinition in shown.moves:
		shown_ids.append(move.action_id)
	var ids: Array[StringName] = []
	var costs: Dictionary[StringName, int] = {}
	for move: CombatActionDefinition in moves:
		ids.append(move.action_id)
		costs[move.action_id] = _coordinator.move_cost(move.action_id)
	_check(shown_ids == ids and not ids.is_empty(), "the player's moves: %s / %s" % [str(shown_ids), str(ids)])
	_check(shown.move_costs == costs, "each move's beats: %s / %s" % [str(shown.move_costs), str(costs)])
	_check(shown.locked_moves == _coordinator.locked_moves() and shown.unaffordable_moves == _coordinator.unaffordable_moves(), "the locked and the unaffordable moves")
	_check(shown.player_earn == _coordinator.earn_of(shown.player_id) and shown.waiting == _coordinator.waiting_for_player() and shown.round_running == _coordinator.round_running(), "how the player's school wins a beat, whether the clock waits, whether a round runs")
	var orders: Array[CombatTacticalActionInfo] = _coordinator.action_infos()
	var same_orders: bool = shown.actions().size() == orders.size()
	for index: int in mini(shown.actions().size(), orders.size()):
		same_orders = same_orders and shown.actions()[index].action_id == orders[index].action_id and shown.actions()[index].unavailable_reason == orders[index].unavailable_reason
	_check(same_orders and not orders.is_empty(), "the orders and why each is greyed")
	for fighter: BattleParticipantProjection in shown.participants():
		var id: StringName = fighter.participant_id
		var beats: CombatRoundBeats = _coordinator.beats_now(id)
		_check((fighter.beats == null) == (beats == null) and (beats == null or (fighter.beats.remaining == beats.remaining and fighter.beats.spent == beats.spent)), "%s: the beats held" % fighter.display_name)
		_check(fighter.targetable == _coordinator.player_can_target(id) and fighter.display_name == _session.encounter_display_name(id), "%s: whether the player may target them, their name" % fighter.display_name)
		if id == shown.player_id:
			continue
		_check(fighter.next_move_tag == _coordinator.next_move_tag(id), "%s: the tag of the move to come" % fighter.display_name)
		var school: SkillDefinition = _coordinator.school_of(id)
		var known: bool = school != null and MoveRecognition.style_known(_player.state, school, GameContent.catalog().pacing().decision_rules(), GameContent.catalog())
		_check(fighter.style_word == (_coordinator.style_word_of(id) if known and fighter.hostile_to_player else ""), "%s: the 打法词" % fighter.display_name)


func _finish(tree: SceneTree) -> void:
	for _second: int in range(600):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight ends: " + _coordinator.last_abort_detail())
	_ui.refresh_projection()
	await tree.process_frame


func _log() -> String:
	return _ui.log_panel._text.get_parsed_text()


## The texts the recent strip's rows show, empty rows left out.
func _strip() -> Array[String]:
	var texts: Array[String] = []
	for row: Node in _ui._recent.get_children():
		var text: String = (row.get_node("Text") as RichTextLabel).get_parsed_text()
		if not text.is_empty():
			texts.append(text)
	return texts


func _strip_red(row: int) -> bool:
	var label: RichTextLabel = _ui._recent.get_child(row).get_node("Text")
	return label.text.begins_with("[color=#%s]" % SharedGameplayUI.ALERT_COLOR.to_html(false))


func _warning() -> Label:
	return _ui._warning


## TEST-ONLY: whole again between fights.
func _heal() -> void:
	var state: CharacterState = _player.state
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _to_snow(tree: SceneTree) -> void:
	for _step: int in range(400):
		MapRoute.press_toward(_session.active_map().runtime_player_body(), Vector2.RIGHT)
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	MapPlaces.release()
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


## The player beside the NPC of a spawn point, on the map its zone lies on (the 武馆 and the
## bank are their own maps since the remap); returns that map, or null.
func _beside(tree: SceneTree, zone_id: StringName, point_id: StringName) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(_session, zone_id, point_id)
	if map == null:
		return null
	await tree.physics_frame
	await tree.physics_frame
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return null
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return map if _player.set_world_location(map.location_for_zone(zone_id)) else null
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("battle opening: " + label)
