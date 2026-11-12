extends RefCounted

## DECISIONS「任务物品不丢」 in play, on 第二章's road: 柳淳风's letter cannot be dropped; taken from
## the player (a thief's hand_over, as 飞贼 does) it is written again, and 潘军禅 says what is
## missing instead of his plain refusal; 陈剑秋's 镖单 likewise. The 背包's 丢下 of a thing worth
## nothing (drop.c destructs it) asks first.

const MapPlaces := preload("res://tests/support/map_places.gd")
const LETTER: StringName = &"native:snow/letter_to_pan"
const NOTE: StringName = &"native:cloud/escort_note"
const WORTHLESS: StringName = &"es2:d/city/obj/token"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_letter(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_letter(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter1_done(session, true)
	session.record_journal()
	var school: WorldMapController = await _beside(tree, session, &"snow.school2", &"snow.school2.gate_entry", &"snow.schoolhall", &"snow.schoolhall.master.1")
	var liu: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.schoolhall.master.1")
	_check(school != null and liu != null and school.select_npc(liu.character_id), "beside 柳淳风")
	if school == null or liu == null:
		return
	school.ask_selected("水烟阁")
	var letter: StringName = _carried(session, LETTER)
	_check(not letter.is_empty() and state.marks.get("柳淳风的引荐信", 0) == 1, "the letter written")
	# It cannot be dropped: no question, its own refusal, still carried.
	ui.items.drop_item(letter, 0)
	_check(not ui.is_asking() and _carried(session, LETTER) == letter and ui.log_lines().any(func(line: String) -> bool: return line.contains("这封信不能随便丢")), "the letter is not dropped")
	# Something worth nothing is asked about first: 取消 keeps it, 确定丢下 lets it go for good.
	var token: StringName = school.give_new_item_to_player(WORTHLESS) # TEST-ONLY
	ui.items.drop_item(token, 0)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("再也找不回来") and not _carried(session, WORTHLESS).is_empty(), "丢下 a thing worth nothing asks first")
	ui.confirm_prompt.cancel()
	_check(not ui.is_asking() and _carried(session, WORTHLESS) == token, "取消: still carried")
	# Dropped from the open 背包 with another beside it: 确定丢下 opens the 背包 again, on the same
	# section, reading the row that took its place, so the next one is a click away.
	var second: StringName = school.give_new_item_to_player(WORTHLESS) # TEST-ONLY
	ui.items.open_inventory()
	await tree.process_frame
	var panel: PlayerInventoryPanel = ui.inventory_panel
	panel.show_section(InventorySections.Section.ALL)
	panel.select_item(token)
	var listed: Array[PlayerInventoryRowProjection] = panel.listed_rows()
	var at: int = listed.find_custom(func(row: PlayerInventoryRowProjection) -> bool: return row.item_instance_id == token)
	var beside: StringName = listed[at + 1 if at + 1 < listed.size() else at - 1].item_instance_id if at >= 0 and listed.size() > 1 else &""
	_check(panel.is_open() and panel.selected_item() == token and not beside.is_empty(), "the 背包 open on the thing worth nothing, another beside it")
	ui.items.drop_item(token, 0)
	_check(ui.is_asking(), "丢下 from the 背包 asks first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await tree.process_frame
	_check(_count_carried(session, WORTHLESS) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("并不会注意到它的存在")), "确定丢下: gone, as drop.c has it")
	_check(ui.items.inventory_is_open() and panel.current_section() == InventorySections.Section.ALL and panel.selected_item() == beside, "确定丢下: the 背包 again, on the row beside it")
	ui.menu.close()
	await tree.process_frame
	ui.items.drop_item(second, 0)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await tree.process_frame
	_check(_carried(session, WORTHLESS).is_empty() and ui.items.inventory_is_open(), "dropped with the 背包 shut: it opens after, all the same")
	ui.menu.close()
	await tree.process_frame
	# Taken by a thief: 柳淳风 writes another; with it in hand, not a third.
	_check(ItemHandlingService.hand_over(liu, letter, school.floor_items.item_authorities()) and _carried(session, LETTER).is_empty(), "the letter taken (TEST-ONLY: as 飞贼's hand_over)")
	_check(_said(school.ask_selected("水烟阁"), "再写一封") and not _carried(session, LETTER).is_empty(), "柳淳风 writes it again")
	_check(_said(school.ask_selected("水烟阁"), "信已经给你了") and _count_carried(session, LETTER) == 1, "in hand: 信已经给你了, one letter")
	# 陈剑秋's 镖单, lost and given again.
	var biaoju: WorldMapController = await _beside(tree, session, &"cloud.biaoju", &"cloud.biaoju.eroad2_entry", &"cloud.biaoju", &"cloud.biaoju.b_header.1")
	var chen: NpcRuntimeState = MapPlaces.npc_at(session, &"cloud.biaoju.b_header.1")
	_check(biaoju != null and chen != null and biaoju.select_npc(chen.character_id), "beside 陈剑秋")
	if biaoju == null or chen == null:
		return
	biaoju.ask_selected("失镖")
	var note: StringName = _carried(session, NOTE)
	_check(not note.is_empty() and state.marks.get("看过镖单", 0) == 1, "the 镖单")
	_check(ItemHandlingService.hand_over(chen, note, biaoju.floor_items.item_authorities()), "the 镖单 taken (TEST-ONLY)")
	_check(_said(biaoju.ask_selected("失镖"), "存根") and not _carried(session, NOTE).is_empty(), "陈剑秋 gives the 镖单 again")
	# 潘军禅 without the letter says what is missing; with it, the bait.
	var pavilion: WorldMapController = await _beside(tree, session, &"waterfog.entrance", &"waterfog.entrance.yard_arrival", &"waterfog.guildhall", &"waterfog.guildhall.executioner.1")
	var pan: NpcRuntimeState = MapPlaces.npc_at(session, &"waterfog.guildhall.executioner.1")
	_check(pavilion != null and pan != null and pavilion.select_npc(pan.character_id), "beside 潘军禅")
	if pavilion == null or pan == null:
		return
	_check(ItemHandlingService.hand_over(pan, _carried(session, LETTER), pavilion.floor_items.item_authorities()), "the second letter taken (TEST-ONLY)")
	_check(_said(pavilion.ask_selected("邪剑穿灵"), "回武馆找他再写一封") and state.marks.get("潘军禅说了鱼饵", 0) == 0, "潘军禅 without the letter: where to get another")
	school = await _beside(tree, session, &"snow.school2", &"snow.school2.gate_entry", &"snow.schoolhall", &"snow.schoolhall.master.1")
	liu = MapPlaces.npc_at(session, &"snow.schoolhall.master.1")
	_check(school != null and liu != null and school.select_npc(liu.character_id) and _said(school.ask_selected("水烟阁"), "再写一封"), "back at the 武馆: written again")
	pavilion = await _beside(tree, session, &"waterfog.entrance", &"waterfog.entrance.yard_arrival", &"waterfog.guildhall", &"waterfog.guildhall.executioner.1")
	pan = MapPlaces.npc_at(session, &"waterfog.guildhall.executioner.1")
	_check(pavilion != null and pan != null and pavilion.select_npc(pan.character_id) and _said(pavilion.ask_selected("邪剑穿灵"), "野羊山北麓") and state.marks.get("潘军禅说了鱼饵", 0) == 1, "with the letter: the bait, the mark 第二章's step is done by")


## Enters `map_id` at `entry` and stands the player beside the NPC of `point` in `zone`.
func _beside(tree: SceneTree, session: WorldSessionController, map_id: StringName, entry: StringName, zone: StringName, point: StringName) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, map_id, entry)
	await _settle(tree)
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point)
	if map == null or npc == null:
		return null
	map.place_player(zone, map.runtime_body_for_character(npc.character_id).global_position + Vector2(0, 60))
	await _settle(tree)
	return map


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("丢信", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	for id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _count_carried(session: WorldSessionController, definition_id: StringName) -> int:
	var count: int = 0
	for id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			count += 1
	return count


func _said(lines: Array[String], text: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(text))


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
