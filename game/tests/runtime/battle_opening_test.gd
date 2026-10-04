extends RefCounted

## How a fight opens in the battle panel, which covers the log: what was said
## (fight.c, kill.c) opens the battle log, and feature/attack.c kill_ob()'s
## 看起来X想杀死你！ from every NPC that fights the player to the death stays
## pinned under the title in HIR red. A spar has no warning; the player's attack
## gets the target's (kill.c obj->kill_ob(me)); the crazy dog's (combatd.c
## start_aggressive()) is its only line; 安惜迩 turns a spar into his kill.
## TEST-ONLY fixtures, each marked where used: combat experience, healing.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []
var _session: OldPineWorldSessionController
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
	await _test_spar(tree)
	await _test_attack(tree)
	await _test_crazy_dog(tree)
	await _test_annihir(tree)
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_spar(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.1"), "beside a trainee")
	await tree.physics_frame
	map.select_npc(_npc(map, &"snow.school2.trainee.1").character_id)
	var before: int = _hud.log_lines().size()
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	_check(said.size() == 2 and said[0].begins_with("你对著武馆弟子说道：") and said[1].begins_with("武馆弟子说道："), "fight.c's words and npc.c accept_fight()'s answer: " + str(said))
	var id: StringName = _coordinator.active_encounter().encounter_id
	_check(_coordinator.opening_lines(id) == said and _coordinator.opening_warnings(id).is_empty(), "the opening is what the log got, no warning")
	_ui.refresh_projection()
	_check(_log().begins_with("\n".join(PackedStringArray(said))), "the battle log opens with them: " + _log().left(120))
	_check(_recent() == said, "and the recent strip shows them before the first blow")
	_check(not _warning().visible, "a spar pins no warning")
	_check(_coordinator.opening_lines(&"encounter:another").is_empty(), "the opening belongs to its fight")
	_finish()
	await tree.process_frame


func _test_attack(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_heal()
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.2"), "beside another trainee")
	await tree.physics_frame
	map.select_npc(_npc(map, &"snow.school2.trainee.2").character_id)
	var before: int = _hud.log_lines().size()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "an attack starts")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	var warning: String = "看起来武馆弟子想杀死你！"
	_check(said.size() == 2 and said[0].begins_with("你对著武馆弟子喝道：「") and said[0].ends_with("今日不是你死就是我活！」") and said[1] == warning, "kill.c's line, then obj->kill_ob(me): " + str(said))
	_check(_hud.combat_log.text.ends_with("[color=#%s]%s[/color]" % [SharedGameplayUI.ALERT_COLOR.to_html(false), warning]), "the warning in HIR red in the log")
	_ui.refresh_projection()
	_check(_warning().visible and _warning().text == warning, "pinned under the title: " + _warning().text)
	var opening: Array[BattleNarrationLine] = BattleFeedbackReader.opening_lines(_coordinator, _coordinator.active_encounter().encounter_id)
	_check(opening.size() == 2 and opening[0].color == ColoredLine.PLAIN and opening[1].color == ColoredLine.HIR, "red in the battle log too, the words plain")
	for _second: int in range(10):
		if not _coordinator.has_active_encounter() or not _recent().has(warning):
			break
		_coordinator.advance_scheduler(1.0)
		_ui.refresh_projection()
	_check(_coordinator.has_active_encounter() and not _recent().has(warning) and _warning().visible, "still pinned once the blows push it out of the recent strip")
	_finish()
	_ui.refresh_projection()
	await tree.process_frame


func _test_crazy_dog(tree: SceneTree) -> void:
	_heal()
	var map: WorldMapController = _session.active_map() as WorldMapController
	var before: int = _hud.log_lines().size()
	_check(_beside(map, &"snow.sroad4", &"snow.sroad4.crazy_dog.1"), "beside the crazy dog")
	for _frame: int in range(30):
		await tree.physics_frame
		if _coordinator.has_active_encounter():
			break
	_check(_coordinator.has_active_encounter(), "the crazy dog attacks")
	var said: Array[String] = []
	said.assign(_hud.log_lines().slice(before))
	_check(said.size() >= 1 and said.back() == "看起来疯狗想杀死你！" and not "\n".join(PackedStringArray(said)).contains("发动攻击"), "start_aggressive() says nothing, kill_ob() warns: " + str(said))
	var id: StringName = _coordinator.active_encounter().encounter_id
	_check(_coordinator.opening_lines(id).is_empty() and _coordinator.opening_warnings(id) == ["看起来疯狗想杀死你！"], "the opening is the warning alone")
	_ui.refresh_projection()
	_check(_warning().visible and _warning().text == "看起来疯狗想杀死你！" and _log().begins_with("看起来疯狗想杀死你！"), "pinned, and the battle log opens with it")
	_finish()
	_ui.refresh_projection()
	await tree.process_frame


func _test_annihir(tree: SceneTree) -> void:
	_heal()
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.bank", &"snow.bank.annihir.1"), "in the bank")
	await tree.physics_frame
	map.select_npc(_npc(map, &"snow.bank.annihir.1").character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "安惜迩 takes the challenge")
	_ui.refresh_projection()
	var lines: PackedStringArray = _log().split("\n")
	_check(lines.size() >= 3 and lines[0].begins_with("你对著安惜迩说道：") and lines[1] == "安惜迩说道：咦... 要打就真打吧，光是较量多没意思？" and lines[2] == "看起来安惜迩想杀死你！", "the battle log opens with the spar, his answer and kill_ob(): " + str(lines.slice(0, 3)))
	_check(_warning().visible and _warning().text == "看起来安惜迩想杀死你！", "pinned under 厮杀")
	_check(_ui._title.text.begins_with("厮杀"), "the title says 厮杀: " + _ui._title.text)
	_check(_recent().back() == "看起来安惜迩想杀死你！", "the recent strip ends with it before the first blow")


func _finish() -> void:
	for _second: int in range(600):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight ends: " + _coordinator.last_abort_detail())


func _log() -> String:
	return _ui.log_panel._text.get_parsed_text()


func _recent() -> Array[String]:
	var texts: Array[String] = []
	for line: BattleNarrationLine in _ui.feedback_reader().recent():
		texts.append(line.text)
	return texts


func _warning() -> Label:
	return _ui._warning


## TEST-ONLY: whole again between fights.
func _heal() -> void:
	var state: CharacterState = _player.state
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _to_snow(tree: SceneTree) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(map: WorldMapController, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return _player.set_world_location(map.location_for_zone(zone_id))
	return false


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("battle opening: " + label)
