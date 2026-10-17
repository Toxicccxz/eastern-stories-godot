extends RefCounted

## What the player stands by (DECISIONS「说话和交互」): the things in reach, nearest first;
## the target E / A goes to, its prompt, stepping to the next; the interaction popup (its
## title, its rows, greyed ones with the reason, 查看 on its right by default, a row's page
## there and B back from it, one size, 给予's ticks and 确认, the confirm pages of 攻击 and
## 偷窃, world time held on every page); a thing that does one
## thing done at once (a door); a click on a thing in reach interacting with it; the
## selection following reach.

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
	var other: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == WAITER_POINT:
			waiter = npc
		elif npc.definition().display_name == "旅客" and npc.world_location().zone_id == &"snow.inn.main_floor":
			if traveller == null:
				traveller = npc
			elif other == null:
				other = npc
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

	# E: his popup, titled with his name, opened on its 查看 (the right column: him as
	# looking at him shows him); 查看 is no row. World time stands still on 查看.
	check(hud.interact() and hud.interaction_open(), "E opens his popup")
	var layout: SharedGameplayLayout = hud._presentation_layout
	check(layout.frame_title.text == waiter_name, "titled with his name: %s" % layout.frame_title.text)
	var rows: Array = hud.interaction_panel.shown().map(func(row: Array) -> String: return row[0])
	check(rows.has("购买") and rows.has("给予") and not rows.has("查看"), "its rows, no 查看 among them: %s" % [rows])
	check(layout.page() == null and hud.interaction_panel.look_text().contains(waiter_name) and hud.inspection_display().begins_with(waiter_name), "its right column is 查看: %s" % hud.interaction_panel.look_text())
	check(map.selected_character_id() == waiter.character_id, "opening it looks at him (selects him)")
	await tree.process_frame
	await tree.process_frame
	check(session.world_time_held(), "world time stands still on 查看")
	# 购买: the shop is the popup's page, its row marked; world time still stands still.
	check(hud.interaction_panel.press("购买"), "购买 pressed")
	check(hud.interaction_open() and layout.page() != null and layout.page() != hud.interaction_panel and hud.interaction_panel.page_mount().is_ancestor_of(layout.page()), "the shop opens in the popup's right column, no other window")
	check(hud.interaction_panel.current() == "购买" and layout.frame_title.text == waiter_name and layout.close_button.text == "返回", "its row marked, the title kept, 关闭 reads 返回")
	await tree.process_frame
	await tree.process_frame
	check(session.world_time_held(), "world time stands still on the shop's page too")
	# Back (B / Esc) goes back to 查看 first, then closes the popup.
	hud.dismiss_current_panel()
	check(hud.interaction_open() and layout.page() == null and hud.interaction_panel.current() == "" and layout.close_button.text == "关闭", "B: back to 查看")
	check(hud.interaction_panel.look_text().contains(waiter_name), "查看 still shows him after a page (a row selects him again): %s" % hud.interaction_panel.look_text())
	# The popup keeps one size, whatever its page holds.
	var size_on_look: Vector2 = layout.frame.size
	hud.interaction_panel.press("购买")
	await tree.process_frame
	await tree.process_frame
	check(layout.frame.size.is_equal_approx(size_on_look) and size_on_look.x > 0.0, "the popup keeps its size on a page: %s / %s" % [size_on_look, layout.frame.size])
	hud.dismiss_current_panel()
	# 给予: his page lists what the player carries to tick; 确认给予 waits for a tick, the
	# 背包's questions show as warnings, 确认 closes the popup and gives them all.
	map.floor_items.give_new_item_to_player(&"es2:obj/longsword") # TEST-ONLY: something to give
	map.floor_items.give_new_item_to_player(&"es2:obj/cloth") # TEST-ONLY: and another
	check(hud.interaction_panel.press("给予") and layout.page() == hud.items.give_panel, "给予: its page in the popup, not the 背包")
	var give: GivePanel = hud.items.give_panel
	check(not hud.menu.is_presented() and give.labels().size() == session.player_inventory_rows().size(), "every carried thing listed: %s" % [give.labels()])
	check(give.confirm_button.disabled, "确认给予 waits for something ticked")
	var gifts: Array[StringName] = []
	var worn: PlayerInventoryRowProjection = null
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
			worn = row
		elif GameContent.catalog().item(row.item_definition_id).currency_base_value == 0:
			gifts.append(row.item_instance_id)
			give.pick_box(PlayerInventoryPanel.row_label(row)).button_pressed = true
	check(gifts.size() >= 2 and not give.confirm_button.disabled and give.warning_text().is_empty(), "two things ticked: 确认给予 can be pressed, nothing to warn of: %s" % [give.labels()])
	check(worn != null, "something worn")
	if worn != null:
		var box: Button = give.pick_box(PlayerInventoryPanel.row_label(worn))
		box.button_pressed = true
		check(give.warning_text().contains(GameContent.catalog().item(worn.item_definition_id).display_name), "something worn ticked: the 背包's question as a warning: %s" % give.warning_text())
		box.button_pressed = false
		check(give.warning_text().is_empty(), "unticked: no warning")
	var given_lines: int = hud.log_lines().size()
	give.confirm_button.pressed.emit()
	check(not layout.frame.visible, "确认给予: the popup closes")
	check(hud.log_lines().size() >= given_lines + gifts.size(), "each ticked thing is given in turn (give.c's lines): %s" % [hud.log_lines().slice(given_lines)])
	await tree.process_frame
	await tree.process_frame
	check(not session.world_time_held(), "world time runs again")
	# 攻击: its confirm page says how strong he looks; 取消 goes back, nothing begun.
	check(hud.interact() and hud.interaction_panel.press("攻击") and layout.page() == hud.confirm_prompt and hud.is_asking(), "攻击: its confirm page in the popup")
	check(hud.confirm_prompt.detail.visible and hud.confirm_prompt.detail.text.contains("看起来"), "it says how strong he looks: %s" % hud.confirm_prompt.detail.text)
	hud.confirm_prompt.cancel()
	check(hud.interaction_open() and layout.page() == null and not session.combat_encounter_coordinator().has_active_encounter(), "取消: back to 查看, no fight")
	# 偷窃: his list in the popup; a thing chosen asks on its page; 确认 closes the popup and
	# the theft's moment comes in world time.
	check(hud.interaction_panel.press("偷窃") and layout.page() == hud.steal_panel, "偷窃: his list in the popup's right column")
	# 随手摸一样 (no item named).
	hud.steal_panel.chosen.emit(&"")
	check(hud.is_asking() and layout.page() == hud.confirm_prompt and hud.confirm_prompt.detail.text.contains("随手摸一样"), "its confirm page says what is reached for: %s" % hud.confirm_prompt.detail.text)
	hud.confirm_prompt.confirm_button.pressed.emit()
	check(not layout.frame.visible, "the theft begun: the popup closes")
	await tree.process_frame
	await tree.process_frame
	check(not session.world_time_held(), "and world time runs for it")
	hud.dismiss_current_panel()
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
	check(map.selected_character_id() == traveller.character_id and hud.inspection_display().begins_with(traveller_name), "its 查看 selects him and shows him: %s" % hud.inspection_display())
	hud.dismiss_current_panel()
	check(not hud.nearby.press(waiter_name, "购买"), "the waiter's 购买 is not offered from here")
	# The other traveller's popup has the same rows: its buttons act on him, not on the first.
	if other != null:
		var other_body: Node2D = map.runtime_body_for_character(other.character_id)
		await _stand(tree, map, other_body.global_position + Vector2(0, -50))
		hud.refresh_exploration()
		check(hud.nearby.choose(other.character_id) and hud.interact() and hud.interaction_open(), "the other traveller's popup")
		check(map.selected_character_id() == other.character_id, "its 查看 looks at him, not the first traveller")
		var row: Button = hud.interaction_panel.button_of("给予")
		if row != null:
			row.pressed.emit()
			check(hud._presentation_layout.page() == hud.items.give_panel and map.selected_character_id() == other.character_id, "its 给予 row gives to him, not the first")
			hud.dismiss_current_panel()
		hud.dismiss_current_panel()

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

	# 攻击 from the popup: its question (if any) in the popup; the popup closes as the fight begins.
	check(hud.nearby.choose(traveller.character_id) and hud.interact() and hud.interaction_open(), "the traveller's popup")
	hud.interaction_panel.press("攻击")
	check(hud.is_asking() and hud.interaction_open() and hud._presentation_layout.page() == hud.confirm_prompt, "攻击 asks on the popup's page")
	hud.confirm_prompt.confirm_button.pressed.emit()
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
