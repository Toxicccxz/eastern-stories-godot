extends RefCounted

## DECISIONS「不能动手的人」: one the story will not let the player fight (`fight_deferred`) is
## never offered 切磋, but its 攻击 row and the attack button stay; choosing 攻击 shows that
## person's own line in the message log and starts nothing — no fight, no confirm page, no
## hostility, no time. One person from each data file that writes such lines, played through
## the interaction popup as the player would.

const MapPlaces := preload("res://tests/support/map_places.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

## [the spawn point, the NPC id, the marks its spawn wants, its data file].
const CASES: Array[Array] = [
	[&"snow.innerhall.pupil.1", &"native.npc.north_pupil_boy", ["竹书给了柳淳风"], "native"],
	[&"imperial.garden.maid.1", &"native.npc.palace_maid", [], "imperial"],
	[&"lancheng.white_gate.lan_child.1", &"native.npc.lan_child", [], "lancheng"],
	[&"niling.altar.shang_jue.1", &"native.npc.shang_jue", [], "niling"],
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	for _n: int in 20:
		await tree.process_frame
	session.set_process(false)
	for case: Array in CASES:
		await _test_case(tree, session, case)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## Every case is a person the data says cannot be fought, from the file named.
func _test_data() -> void:
	for case: Array in CASES:
		var definition: NpcDefinition = GameContent.catalog().npc(case[1])
		_check(definition != null and definition.dealings().is_fight_deferred() and not definition.dealings().fight_refusal().is_empty(), "%s: a line for 攻击 (%s)" % [case[1], case[3]])


func _test_case(tree: SceneTree, session: WorldSessionController, case: Array) -> void:
	var point: StringName = case[0]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	for mark: String in case[2]:
		player.state.marks[mark] = 1 # TEST-ONLY: the story's step that brings them here
	var map: WorldMapController = MapPlaces.enter(session, StringName("%s.%s" % [String(point).get_slice(".", 0), String(point).get_slice(".", 1)]), point)
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point)
	_check(map != null and npc != null and npc.definition().definition_id == case[1], "%s: on the map with %s" % [case[3], case[1]])
	if map == null or npc == null:
		return
	await _stand_by(tree, map, player, npc)
	var hud: SharedGameplayUI = session.shared_ui()
	hud.refresh_exploration()
	var line: String = TranslationServer.translate(npc.definition().dealings().fight_refusal())
	var seconds: int = session.day_clock().day_seconds()
	var shown_before: int = hud.message_log.log_lines().size()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	# The popup: 攻击 offered and pressable, 切磋 not.
	_check(hud.interact_with(npc.character_id) and hud.interaction_open(), "%s: the interaction popup on %s" % [case[3], case[1]])
	var rows: Array[Array] = hud.interaction_panel.shown()
	var labels: Array = rows.map(func(row: Array) -> String: return row[0])
	var attack: Array = rows.filter(func(row: Array) -> bool: return row[0] == "攻击")
	_check(attack.size() == 1 and String(attack[0][1]).is_empty(), "%s: 攻击 offered and not greyed: %s" % [case[3], rows])
	_check(not labels.has("切磋"), "%s: no 切磋: %s" % [case[3], labels])
	_check(map.select_npc(npc.character_id) and not hud.attack_button.disabled and hud.spar_button.disabled, "%s: the attack button pressable, the spar button not" % case[3])
	# Choosing 攻击: the line, and nothing else.
	var page_before: Control = _presentation_page(hud)
	_check(hud.interaction_panel.press("攻击"), "%s: 攻击 pressed" % case[3])
	await tree.process_frame
	var said: Array[String] = hud.message_log.log_lines().slice(shown_before)
	_check(said.has(line), "%s: the player is shown %s's line: %s" % [case[3], case[1], said])
	_check(not said.any(func(shown: String) -> bool: return shown.contains("今日不是你死就是我活")), "%s: no challenge shouted" % case[3])
	_check(not coordinator.has_active_encounter(), "%s: no fight" % case[3])
	_check(not hud.confirm_prompt.is_visible_in_tree() and _presentation_page(hud) == page_before, "%s: no confirm page (%s, %s → %s)" % [case[3], hud.confirm_prompt.is_visible_in_tree(), page_before, _presentation_page(hud)])
	_check(not npc.relationship.has_opponent(player.character_id) and not player.relationship.has_opponent(npc.character_id), "%s: no hostility" % case[3])
	_check(session.day_clock().day_seconds() == seconds, "%s: no time passed" % case[3])
	# The attack button's path says the same.
	var again: int = hud.message_log.log_lines().size()
	hud.attack_button.pressed.emit()
	await tree.process_frame
	_check(hud.message_log.log_lines().slice(again).has(line) and not coordinator.has_active_encounter(), "%s: the attack button shows the line too" % case[3])


func _presentation_page(hud: SharedGameplayUI) -> Control:
	return hud._presentation_layout.page()


## The player stands beside `npc` (as a visitor walks up to them).
func _stand_by(tree: SceneTree, map: WorldMapController, player: WorldPlayerRuntimeState, npc: NpcRuntimeState) -> void:
	var body: Node2D = map.runtime_body_for_character(npc.character_id)
	var placed: bool = body != null
	if placed:
		placed = false
		for offset: Vector2 in [Vector2(0, 56), Vector2(56, 0), Vector2(-56, 0), Vector2(0, -56), Vector2(40, 40), Vector2(-40, 40)]:
			if map.place_player(npc.world_location().zone_id, body.global_position + offset):
				placed = true
				break
	_check(placed, "standing beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.process_frame
	player.set_world_location(map.location_for_zone(npc.world_location().zone_id))


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("fight refusal: " + message)
