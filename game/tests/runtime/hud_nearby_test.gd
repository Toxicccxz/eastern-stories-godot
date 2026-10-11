extends RefCounted

## The HUD's nearby groups (owner, 2026-10-11): the actions show only for what is in
## reach, one group per thing, nearest first, gone once the player walks off; a click
## selects nothing, a group's button selects its thing; the selection follows reach.

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

	# Beside the waiter: his group, his shop's 购买 first; nothing else is near.
	await _stand(tree, map, waiter_body.global_position + Vector2(0, 50))
	hud.refresh_exploration()
	var groups: Array[Array] = hud.nearby.groups()
	check(groups.size() == 1 and groups[0][0] == waiter_name, "beside the waiter: his group only: %s" % [groups])
	check(hud.nearby.actions_of(waiter_name).slice(0, 4) == ["购买", "查看", "攻击", "切磋"], "his shop's 购买 first, then 查看 …: %s" % [hud.nearby.actions_of(waiter_name)])
	check(not hud.nearby.actions_of(traveller_name).has("查看"), "the traveller across the room offers nothing")
	check(map.selected_character_id() == waiter.character_id, "the selection follows reach: the waiter")
	check(hud._presentation_layout.nearby.is_visible_in_tree(), "the groups show on the card")

	# A click on the traveller across the room selects nothing.
	(traveller_body as WorldCharacterBody2D).selection_requested.emit(traveller.character_id)
	check(map.selected_character_id() == waiter.character_id, "a click on someone selects nothing")

	# Off by oneself: no group, no selection.
	await _stand(tree, map, (waiter_body.global_position + traveller_body.global_position) / 2.0 + Vector2(220, 0))
	hud.refresh_exploration()
	check(hud.nearby.groups().is_empty() and not hud._presentation_layout.nearby.visible, "away from everyone: no group: %s" % [hud.nearby.groups()])
	check(map.selected_character_id().is_empty(), "nothing near: nothing selected")

	# Beside the traveller: his group; 查看 selects him and shows him.
	await _stand(tree, map, traveller_body.global_position + Vector2(0, -50))
	hud.refresh_exploration()
	check(hud.nearby.actions_of(traveller_name).has("查看") and not hud.nearby.actions_of(traveller_name).has("购买"), "beside the traveller: his group: %s" % [hud.nearby.groups()])
	check(hud.nearby.press(traveller_name, "查看"), "his 查看 is pressed")
	check(map.selected_character_id() == traveller.character_id and hud.inspection_display().begins_with(traveller_name), "查看 selects him and shows him: %s" % hud.inspection_display())
	hud.dismiss_current_panel()
	check(not hud.nearby.press(waiter_name, "购买"), "the waiter's 购买 is not offered from here")

	# Both near: the groups keep their places as the distances change, and the selection
	# is the NPC the player stands nearest.
	await _stand(tree, map, waiter_body.global_position + Vector2(0, 400))
	hud.refresh_exploration()
	check(hud.nearby.groups().is_empty(), "off again: the card is empty")
	traveller_body.global_position = waiter_body.global_position + Vector2(100, 0) # TEST-ONLY: he stands by the counter
	await _stand(tree, map, waiter_body.global_position + Vector2(30, 40))
	hud.refresh_exploration()
	var names: Array = hud.nearby.groups().map(func(group: Array) -> String: return group[0])
	check(names == [waiter_name, traveller_name], "both near, the nearer first: %s" % [names])
	check(map.selected_character_id() == waiter.character_id, "the selection: the nearer, the waiter")
	await _stand(tree, map, waiter_body.global_position + Vector2(70, 40))
	hud.refresh_exploration()
	names = hud.nearby.groups().map(func(group: Array) -> String: return group[0])
	check(names == [waiter_name, traveller_name], "the traveller now nearer: the groups keep their places: %s" % [names])
	check(map.selected_character_id() == traveller.character_id, "the selection follows to the nearer, the traveller")
	session.queue_free()
	await tree.process_frame
	return {"assertions": assertions, "failures": failures}


func _stand(tree: SceneTree, map: WorldMapController, at: Vector2) -> void:
	map.runtime_player_body().global_position = at
	await tree.physics_frame
	await tree.physics_frame
