extends RefCounted

## What the player stands by (DECISIONS「说话和交互」): the things in reach, nearest first;
## the target E / A goes to, its prompt, stepping to the next; the interaction popup (its
## title, its rows, greyed ones with the reason, world time held while it shows, a row
## closing it); a thing that does one thing done at once (a door); a click on a thing in
## reach interacting with it; the selection following reach.

var assertions: int = 0
var failures: Array[String] = []

const WAITER_POINT: StringName = &"snow.inn.main_floor.inn.waiter.1"


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func run_all(tree: SceneTree) -> Dictionary:
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	check(session.configure_source_entry("Nearby", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	session.set_process(false) # TEST-ONLY: nobody wanders while the player is placed
	var waiter: NpcRuntimeState = null
	var traveller: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == WAITER_POINT:
			waiter = npc
		elif npc.definition().display_name == "旅客" and npc.world_location().zone_id == &"snow.inn.main_floor" and traveller == null:
			traveller = npc
	check(waiter != null and traveller != null, "the waiter and a traveller in the Inn")
	if waiter == null or traveller == null:
		session.queue_free()
		return {"assertions": assertions, "failures": failures}
	var waiter_body: Node2D = map.runtime_body_for_character(waiter.character_id)
	var traveller_body: Node2D = map.runtime_body_for_character(traveller.character_id)
	var waiter_name: String = waiter.definition().short_name()
	var traveller_name: String = traveller.definition().short_name()

	# Beside the waiter: him only; his shop's 购买, his 攻击, 查看 last.
	await _stand(tree, map, waiter_body.global_position + Vector2(0, 50))
	hud.refresh_exploration()
	var groups: Array[Array] = hud.nearby.groups()
	check(groups.size() == 1 and groups[0][0] == waiter_name, "beside the waiter: him only: %s" % [groups])
	var labels: Array[String] = hud.nearby.actions_of(waiter_name)
	check(labels.has("购买") and labels.has("攻击") and labels.back() == "查看" and labels.find("购买") < labels.find("攻击"), "his options, 查看 last: %s" % [labels])
	check(map.selected_character_id() == waiter.character_id, "the selection follows reach: the waiter")
	check(hud.nearby.target() != null and hud.nearby.target().id == waiter.character_id, "E / A goes to him")
	hud.focus_marker._process(0.2)
	check(hud.focus_marker.prompt_text() == "交互", "his prompt: %s" % hud.focus_marker.prompt_text())

	# E: his popup, titled with his name; world time stands still while it shows.
	check(hud.interact() and hud.interaction_open(), "E opens his popup")
	check(hud._presentation_layout.frame_title.text == waiter_name, "titled with his name: %s" % hud._presentation_layout.frame_title.text)
	var rows: Array = hud.interaction_panel.shown().map(func(row: Array) -> String: return row[0])
	check(rows.has("购买") and rows.has("给予") and rows.has("查看"), "its rows: %s" % [rows])
	await tree.process_frame
	await tree.process_frame
	check(session.world_time_held(), "world time stands still")
	# A row closes it and does its thing: 购买 opens the shop, and time runs again.
	check(hud.interaction_panel.press("购买"), "购买 pressed")
	check(not hud.interaction_open() and hud._presentation_layout.frame.visible, "the popup gives way to the shop")
	await tree.process_frame
	await tree.process_frame
	check(not session.world_time_held(), "world time runs again")
	hud.dismiss_current_panel()
	await tree.process_frame

	# Lying unconscious: his 切磋 and 给予 greyed, each saying why; the popup says how he is.
	waiter.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	waiter.set_revive_in_ms(9500)
	hud.refresh_exploration()
	check(hud.interact() and hud.interaction_open(), "his popup again")
	var reasons: Dictionary = {}
	for row: Array in hud.interaction_panel.shown():
		reasons[row[0]] = row[1]
	check(reasons.get("切磋", "") == "%s已经无法战斗了。" % waiter.definition().display_name, "切磋 greyed: fight.c's line: %s" % [reasons])
	check(not String(reasons.get("给予", "")).is_empty() and String(reasons.get("攻击", "x")).is_empty(), "给予 greyed with why; 攻击 still open: %s" % [reasons])
	check(hud.nearby.about(hud.nearby.target())[0] == ["昏迷不醒，约 10 秒后醒来"], "the popup says when he comes to: %s" % [hud.nearby.about(hud.nearby.target())])
	check(hud.interaction_panel.button_of("切磋").disabled and not hud.interaction_panel.press("切磋"), "a greyed row does nothing")
	hud.dismiss_current_panel()
	waiter.set_revive_in_ms(0)
	waiter.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	await tree.process_frame

	# A click on the traveller across the room does nothing; beside him it opens his popup.
	(traveller_body as WorldCharacterBody2D).selection_requested.emit(traveller.character_id)
	check(not hud._presentation_layout.frame.visible, "a click on someone out of reach does nothing")
	await _stand(tree, map, traveller_body.global_position + Vector2(0, -50))
	hud.refresh_exploration()
	(traveller_body as WorldCharacterBody2D).selection_requested.emit(traveller.character_id)
	check(hud.interaction_open() and hud._presentation_layout.frame_title.text == traveller_name, "beside him, a click opens his popup")
	check(hud.interaction_panel.press("查看") and map.selected_character_id() == traveller.character_id and hud.inspection_display().begins_with(traveller_name), "查看 selects him and shows him: %s" % hud.inspection_display())
	hud.dismiss_current_panel()
	check(not hud.nearby.press(waiter_name, "购买"), "the waiter's 购买 is not offered from here")

	# Off by oneself: nothing in reach, no target, no selection.
	await _stand(tree, map, (waiter_body.global_position + traveller_body.global_position) / 2.0 + Vector2(220, 0))
	hud.refresh_exploration()
	check(hud.nearby.groups().is_empty() and hud.nearby.target() == null and not hud.interact(), "away from everyone: nothing: %s" % [hud.nearby.groups()])
	check(map.selected_character_id().is_empty(), "nothing near: nothing selected")

	# Both near: nearest first; the target steps from one to the other and back.
	traveller_body.global_position = waiter_body.global_position + Vector2(100, 0) # TEST-ONLY: he stands by the counter
	await _stand(tree, map, waiter_body.global_position + Vector2(30, 40))
	hud.refresh_exploration()
	var names: Array = hud.nearby.groups().map(func(group: Array) -> String: return group[0])
	check(names == [waiter_name, traveller_name], "both near, the nearer first: %s" % [names])
	var first: StringName = hud.nearby.target().id
	check(hud.nearby.cycle(1) and hud.nearby.target().id != first, "Tab / Y: the other one")
	hud.refresh_exploration()
	check(hud.nearby.target().id != first, "a chosen target stays while in reach")
	check(hud.nearby.cycle(1) and hud.nearby.target().id == first, "and back")

	# 攻击 from the popup: the popup closes as the fight begins.
	check(hud.nearby.choose(traveller.character_id) and hud.interact() and hud.interaction_open(), "the traveller's popup")
	hud.interaction_panel.press("攻击")
	if hud.is_asking():
		hud.confirm_prompt.confirm()
	check(session.combat_encounter_coordinator().has_active_encounter() and not hud.interaction_open(), "攻击: the fight begins, the popup is gone")
	await tree.process_frame
	check(not session.world_time_held(), "and nothing holds world time")
	session.queue_free()
	await tree.process_frame
	CombatEncounterCoordinator.take_aborted_total()

	# A door does its one thing at once: no popup.
	await _test_door(tree)
	return {"assertions": assertions, "failures": failures}


func _test_door(tree: SceneTree) -> void:
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	check(session.configure_source_entry("Door", CharacterState.GENDER_MALE), "source setup (door)")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	session.set_process(false) # TEST-ONLY
	var hud: SharedGameplayUI = session.shared_ui()
	# Upstairs: the guest rooms' doors.
	var map: WorldMapController = MapPlaces.enter(session, &"snow.inn_2f", &"snow.inn_2f.stairs_arrival")
	await tree.process_frame
	await tree.process_frame
	var door_id: StringName = &"snow.inn_2f.north_door"
	check(map != null and map.doors_by_id.has(door_id), "the north guest room's door upstairs")
	if map == null or not map.doors_by_id.has(door_id):
		session.queue_free()
		return
	var door: Node2D = map.doors_by_id[door_id].wall_shape()
	for offset: Vector2 in [Vector2(0, 40), Vector2(0, -40), Vector2(40, 0), Vector2(-40, 0)]:
		await _stand(tree, map, MapPlaces.spot(map, &"snow.inn_2f", door.global_position + offset, 30.0))
		if map.can_operate_door(door_id):
			break
	hud.refresh_exploration()
	check(hud.nearby.choose(door_id), "the door in reach")
	var was_open: bool = map.doors_by_id[door_id].is_open()
	var name: String = GameContent.catalog().door(door_id).display_name
	check(hud.nearby.prompt_text(hud.nearby.target()) == ("关闭" if was_open else "打开") + name, "its prompt says what E does: %s" % hud.nearby.prompt_text(hud.nearby.target()))
	check(hud.interact() and map.doors_by_id[door_id].is_open() != was_open and not hud._presentation_layout.frame.visible, "E: it opens (or shuts) at once, no popup")
	session.queue_free()
	await tree.process_frame


func _stand(tree: SceneTree, map: WorldMapController, at: Vector2) -> void:
	map.runtime_player_body().global_position = at
	await tree.physics_frame
	await tree.physics_frame
