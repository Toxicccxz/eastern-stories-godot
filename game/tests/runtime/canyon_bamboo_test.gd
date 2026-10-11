extends RefCounted

## 天驼关 C (d/canyon): the side way west of the pass, repaired (owner, canyon plan Q1: canyon2.c had
## no way west). The 黄石穿林路 (stone_forest1–3) runs west from 隘口小路 to the mirror; inside it
## (梦幻迷境通道, fantasy1.c) the middle way leads north up the 竹林道 (bamboo1–3) to the great yellow
## stone. bamboo3.c's move stone wants 560 force and max_force and 40 force_factor and costs 20 gin,
## 60 kee, 20 sen; it opens a gap (a room flag) that enter closes behind the player in the 洞内石室
## (train.c). Its bookcase gives a 书匣 holding the 悟疾风劲竹书 whenever no such book exists
## (F_UNIQUE; train.c's got went with ES2's clean_up, 默认); the book is taken out of the carried
## 书匣 (and put back) and teaches parry to 50 from 20000 exp. Walks use the move actions
## (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const BOOK: StringName = &"es2:d/canyon/bamboo/obj/parry_book"
const SLIPCASE: StringName = &"es2:d/canyon/bamboo/obj/slipcase"
const STONE: StringName = &"canyon.bamboo3.stone"
const GAP: StringName = &"canyon.bamboo3.gap"
const BOOKCASE: StringName = &"canyon.train.bookcase"
const ZONES: Dictionary = {
	&"canyon.stone_forest1": &"canyon.pass", &"canyon.stone_forest2": &"canyon.pass", &"canyon.stone_forest3": &"canyon.pass",
	&"canyon.fantasy1": &"canyon.bamboo", &"canyon.bamboo1": &"canyon.bamboo", &"canyon.bamboo2": &"canyon.bamboo",
	&"canyon.bamboo3": &"canyon.bamboo", &"canyon.train": &"canyon.stoneroom",
}
const PUSHED: String = "你将大黄石缓缓的向左边移动，而出现了一个小小的隙缝。"
const WEAK: String = "你出力不太够喔！"
const THROUGH: String = "当你通过隙缝，大黄石又急速地合闭。"
const FOUND: String = "你在书柜中找了到一个书匣"
const NOTHING: String = "你在书柜找了找但没找到些什么"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_rules()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_forest(tree, session)
	await _test_bamboo(tree, session)
	await _test_stone(tree, session)
	await _test_bookcase(tree, session)
	await _test_book(tree, session)
	await _test_way_back(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for zone_id: StringName in ZONES:
		var zone: ZoneDefinition = catalog.zone(zone_id)
		_check(zone != null and zone.map_id == ZONES[zone_id], "%s on %s" % [zone_id, ZONES[zone_id]])
	_check(catalog.zone_of_room(&"es2:d/canyon/dream/tmp") == null and catalog.zone_of_room(&"es2:d/canyon/evil/tmp") == null, "dream/tmp.c and evil/tmp.c (整修中，请往回走:P) are not placed")
	_check(catalog.room(&"es2:d/canyon/stone_forest1").short == "黄石穿林路路口" and catalog.room(&"es2:d/canyon/bamboo/train").short == "洞内石室", "the rooms' own names")
	_check(catalog.portal(&"canyon.stone_forest3.mirror").destination_zone_id == &"canyon.fantasy1" and catalog.portal(&"canyon.fantasy1.back").destination_zone_id == &"canyon.stone_forest3", "into the mirror and back")
	_check(catalog.portal(&"canyon.train.out").destination_zone_id == &"canyon.bamboo3", "out of the stone room to the 竹林道")
	var book: ItemContentDefinition = catalog.item(BOOK)
	_check(book.display_name == "悟疾风劲竹书" and book.unique and book.weapon_skill_type == &"", "parry_book.c: 悟疾风劲竹书, unique (F_UNIQUE)")
	_check(book.study != null and book.study.skill_id == &"parry" and book.study.exp_required == 20000 and book.study.max_skill == 50 and book.study.sen_cost == 30 and book.study.difficulty == 15, "parry to 50 from 20000 exp, 30 sen at difficulty 15")
	var slipcase: ItemContentDefinition = catalog.item(SLIPCASE)
	_check(slipcase.display_name == "书匣" and slipcase.max_encumbrance == 5000 and slipcase.contains == [BOOK] and slipcase.own_weight == 4000, "slipcase.c: a 书匣 that holds 5000, made with the book inside")
	var bookcase: WorldLandmarkDefinition = catalog.landmark(&"canyon.train.landmark.bookcase")
	_check(bookcase.description == "看起来是个普普通通的柜子，或许你可以search看看。\n", "the bookcase's item_desc, word for word")
	_check(catalog.service(STONE).act.verb == "推开" and catalog.service(GAP).act.verb == "进去" and catalog.service(BOOKCASE).act.verb == "翻找", "大黄石 · 推开, 隙缝 · 进去, 书柜 · 翻找")


## Which branch answers: the stone wants all three of force, max_force and force_factor; only
## the gap answers once it is open (默认: no second push, which cost again and said nothing);
## the bookcase gives only while no book exists.
func _test_rules() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var stone: RoomActDefinition = catalog.service(STONE).act
	var gap: RoomActDefinition = catalog.service(GAP).act
	var strong := ScriptedAct.Facts.new()
	strong.numbers = {"force": 560, "max_force": 560, "force_factor": 40}
	_check(stone.act_for(&"男性", &"", strong) == stone.acts[0], "560 / 560 / 40: the push")
	for key: String in ["force", "max_force", "force_factor"]:
		var weak := ScriptedAct.Facts.new()
		weak.numbers = strong.numbers.duplicate()
		weak.numbers[key] -= 1
		var act: ScriptedAct = stone.act_for(&"男性", &"", weak)
		_check(act == stone.acts[1] and act.steps.size() == 1 and act.steps[0].line.text == WEAK + "\n", "one short of %s: %s" % [key, WEAK])
	_check(gap.act_for(&"男性", &"", strong) == null, "no gap before the push")
	var open := ScriptedAct.Facts.new()
	open.numbers = strong.numbers.duplicate()
	open.room = {"exits/enter": 1}
	_check(stone.act_for(&"男性", &"", open) == null and gap.act_for(&"男性", &"", open) == gap.acts[0], "open: only the way in")
	var bookcase: RoomActDefinition = catalog.service(BOOKCASE).act
	var fresh := ScriptedAct.Facts.new()
	fresh.item_exists = func(_id: StringName) -> bool: return false
	_check(bookcase.act_for(&"男性", &"", fresh) == bookcase.acts[1] and bookcase.acts[1].steps.size() == 2, "no book in the world: the line and the 书匣 (no room flag kept)")
	var exists := ScriptedAct.Facts.new()
	exists.item_exists = func(id: StringName) -> bool: return id == BOOK
	_check(bookcase.act_for(&"男性", &"", exists) == bookcase.acts[0], "the book exists somewhere: nothing (F_UNIQUE, 默认)")


## canyon2.c west (repaired) along the 黄石穿林路 to the mirror, and into it.
func _test_forest(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"canyon.pass", &"canyon.canyon1", &"canyon.canyon1", &"canyon.canyon1.chain_arrival").succeeded(), "TEST-ONLY: at the pass's tail")
	await tree.physics_frame
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.canyon2", &"canyon.stone_forest1", &"canyon.stone_forest2", &"canyon.stone_forest3"]), "west from 隘口小路 along the yellow-stone path")
	_check(session.place_name(player.world_location()) == "天驼关 · 梦幻迷境入口", "天驼关 · 梦幻迷境入口: %s" % session.place_name(player.world_location()))
	_check(Work.capture(session) != null, "Save by the mirror")
	_check(await MapPlaces.take_passage(tree, gorge, &"canyon.stone_forest3.mirror"), "into the mirror")
	_check(session.active_map_id() == &"canyon.bamboo" and player.world_location().zone_id == &"canyon.fantasy1", "梦幻迷境通道: %s" % player.world_location().zone_id)


## Up the middle way into the 竹林道, to the stone.
func _test_bamboo(tree: SceneTree, session: WorldSessionController) -> void:
	var bamboo: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, bamboo, [&"canyon.bamboo1", &"canyon.bamboo2", &"canyon.bamboo3"]), "north up the 竹林道")
	_check(session.place_name(player.world_location()) == "天驼关 · 竹林道", "天驼关 · 竹林道")
	session.shared_ui().describe_arrival()
	_check(session.shared_ui().log_lines()[-1].begins_with("【竹林道】北方有一个大黄石堵住去路"), "bamboo3 has its own say though bamboo2 has its name (distinct): the stone to push")
	_check(await MapPlaces.drive(tree, bamboo, MapPlaces.service_spot(bamboo, STONE)) and (bamboo.service(STONE) as ActService).in_reach(), "at the great yellow stone")
	_check((bamboo.service(GAP) as ActService).point.get_node_or_null("Visual") == null, "the gap has no diamond of its own")


## move stone: too weak, the line only; asked first when its cost would knock the player out;
## pushed, 20 gin, 60 kee, 20 sen and the gap; then only 进去, which shuts the stone behind them.
func _test_stone(tree: SceneTree, session: WorldSessionController) -> void:
	var bamboo: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var stone: ActService = bamboo.service(STONE) as ActService
	var gap: ActService = bamboo.service(GAP) as ActService
	_resources(player, 100, 100, 100)
	_check(bamboo.interaction_title() == "大黄石 · 推开" and gap.context_title() == "", "大黄石 · 推开; no gap yet: %s" % bamboo.interaction_title())
	stone.interact()
	await tree.physics_frame
	_check(hud.log_lines()[-1] == WEAK and player.state.vitality.current == 100, "a fresh character: %s, nothing spent" % hud.log_lines()[-1])
	_strong(player) # TEST-ONLY
	_resources(player, 100, 50, 100)
	stone.interact()
	await tree.physics_frame
	_check(hud.is_asking() and hud.confirm_prompt.message.text.begins_with("推开要耗去 60 点气，你现在撑不住，会当场昏过去。"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(player.state.vitality.current == 50 and not session.room_states().has_flag(&"canyon.bamboo3", "exits/enter"), "取消: nothing spent, the stone stays")
	_resources(player, 100, 100, 100)
	stone.interact()
	await tree.physics_frame
	_check(hud.log_lines()[-1] == PUSHED, "the stone moves: %s" % hud.log_lines()[-1])
	_check(player.state.essence.current == 80 and player.state.vitality.current == 40 and player.state.spirit.current == 80, "20 gin, 60 kee, 20 sen: %d %d %d" % [player.state.essence.current, player.state.vitality.current, player.state.spirit.current])
	_check(player.state.recovery.inner_force.current == 600, "the push spends no force (do_move() only checks it)")
	_check(stone.context_title() == "" and bamboo.interaction_title() == "隙缝 · 进去", "open: only 隙缝 · 进去 (默认): %s" % bamboo.interaction_title())
	_check(Work.capture(session) != null, "Save with the gap open")
	gap.interact()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == &"canyon.stoneroom" and player.world_location().zone_id == &"canyon.train", "into the 洞内石室: %s" % player.world_location().zone_id)
	_check(hud.log_lines().has(THROUGH), THROUGH)
	_check(not session.room_states().has_flag(&"canyon.bamboo3", "exits/enter"), "the stone shut behind them")


## search bookcase: the 书匣 with the book inside; nothing more while the book exists; the
## bookcase looked at; a Continue starts with the stone shut.
func _test_bookcase(tree: SceneTree, session: WorldSessionController) -> void:
	var room: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(room.select_landmark(&"canyon.train.landmark.bookcase"), "the stone bookcase")
	room.inspect_selected()
	_check(hud.inspection_text.text.contains("或许你可以search看看"), "看起来是个普普通通的柜子: %s" % hud.inspection_text.text.left(20))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	var bookcase: ActService = room.service(BOOKCASE) as ActService
	_check(await MapPlaces.drive(tree, room, MapPlaces.service_spot(room, BOOKCASE)) and bookcase.in_reach() and room.interaction_title() == "书柜 · 翻找", "书柜 · 翻找: %s" % room.interaction_title())
	bookcase.interact()
	await tree.physics_frame
	_check(hud.log_lines()[-1] == FOUND, FOUND)
	var slipcase: StringName = _carried(session, SLIPCASE)
	var inside: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, slipcase))
	_check(slipcase != &"" and inside.size() == 1 and session.item_instance_index().resolve(inside[0]).item_definition_id == BOOK, "the 书匣 is carried, the book inside it")
	_check(_carried(session, BOOK) == &"", "the book is not in the pack itself")
	_check(session.inventory_state().subtree_weight(slipcase) == 4800, "the 书匣 weighs 4000 and the book 800")
	bookcase.interact()
	await tree.physics_frame
	_check(hud.log_lines()[-1] == NOTHING and _all_carried(session, SLIPCASE).size() == 1, "again, the book in the 书匣: %s (F_UNIQUE, 默认)" % hud.log_lines()[-1])
	# TEST-ONLY: back to a fresh character's force first (Continue recomputes max kee from max_force).
	session.player_runtime().state.recovery.inner_force = CharacterInternalResourceState.new(0, 0)
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, Work.capture(session), "天驼关 C with the 书匣")
	_check(walker._failures.is_empty(), "Save/Continue keeps the book in the 书匣: " + str(walker._failures))
	# Room flags are not saved: a Continue finds the stone shut whatever was open.
	session.room_states().set_flag(&"canyon.bamboo3", "exits/enter") # TEST-ONLY: the gap open
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(Work.capture(session))
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue in the stone room")
	if restored.succeeded():
		var fresh: WorldSessionController = restored.candidate
		fresh.set_process(false)
		_check(fresh.room_states().flags(&"canyon.bamboo3").is_empty(), "after Continue the stone is shut")
		fresh.free()
		await tree.process_frame
	session.room_states().clear_flag(&"canyon.bamboo3", "exits/enter")


## get book from slipcase (the 背包's 取出 on the 书匣), put it back (放进书匣) and out again,
## then study it.
func _test_book(tree: SceneTree, session: WorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	var slipcase: StringName = _carried(session, SLIPCASE)
	var rows: Array[PlayerInventoryRowProjection] = session.player_inventory_rows()
	var row: PlayerInventoryRowProjection = null
	for each: PlayerInventoryRowProjection in rows:
		if each.item_instance_id == slipcase:
			row = each
	_check(row != null and row.contents.size() == 1 and row.contents[0][1] == "悟疾风劲竹书" and row.contents[0][2] == 1, "the 书匣's row lists what it holds")
	_check(PlayerInventoryPanel.held_label([&"x", "银子", 5]) == "银子 ×5" and PlayerInventoryPanel.held_label(row.contents[0]) == "悟疾风劲竹书", "a stack inside says its amount (combined.c short())")
	hud.inventory_panel.show_inspection(row)
	_check(hud.inventory_panel.inspection_display().ends_with("里面有：\n  悟疾风劲竹书"), "观察 the 书匣: 里面有： (look.c): %s" % hud.inventory_panel.inspection_display())
	hud.show_inventory(rows)
	await tree.process_frame
	var take: Button = _button(hud.inventory_panel, "取出悟疾风劲竹书")
	_check(take != null, "取出悟疾风劲竹书 on the 书匣")
	if take != null:
		take.pressed.emit()
	await tree.process_frame
	_check(hud.log_lines()[-1] == "你从书匣中拿出一把悟疾风劲竹书。", "get.c: %s" % hud.log_lines()[-1])
	var book: StringName = _carried(session, BOOK)
	_check(book != &"", "the book is in the pack")
	_check(_button(hud.inventory_panel, "取出悟疾风劲竹书") == null, "the 书匣 is empty now")
	var back: Button = _row_button(hud.inventory_panel, "悟疾风劲竹书", "放进书匣")
	_check(back != null, "放进书匣 on the book's row (put.c: a carried container)")
	if back != null:
		back.pressed.emit()
	await tree.process_frame
	_check(hud.log_lines()[-1] == "你将一把悟疾风劲竹书放进书匣。" and _carried(session, BOOK) == &"", "put.c: %s" % hud.log_lines()[-1])
	take = _button(hud.inventory_panel, "取出悟疾风劲竹书")
	_check(take != null, "and 取出 again")
	if take != null:
		take.pressed.emit()
	await tree.process_frame
	book = _carried(session, BOOK)
	_check(book != &"", "the book is in the pack again")
	var second: StringName = _new_item(session, SLIPCASE) # TEST-ONLY: a second, empty 书匣
	hud.show_inventory(session.player_inventory_rows())
	await tree.process_frame
	_check(_row_button(hud.inventory_panel, "悟疾风劲竹书", "放进书匣 #1") != null and _row_button(hud.inventory_panel, "悟疾风劲竹书", "放进书匣 #2") != null, "two 书匣: their 放进 buttons are numbered")
	_check(_drop(session, second), "TEST-ONLY: the second 书匣 gone again")
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(not hud.inventory_is_open(), "the 背包 is closed")
	state.skills.set_raw_level(SkillIds.LITERATE, 10) # TEST-ONLY
	state.progression.combat_experience = 19999 # TEST-ONLY
	_check(session.martial_arts().study(book).outcome == StudyResult.Outcome.COMBAT_EXPERIENCE_TOO_LOW, "below 20000 exp: too deep")
	state.progression.combat_experience = 20000 # TEST-ONLY
	var read: StudyResult = session.martial_arts().study(book)
	_check(read.outcome == StudyResult.Outcome.STUDIED and hud.log_lines()[-1] == "你研读有关基本招架的技巧，似乎有点心得。", "study: parry: %s" % hud.log_lines()[-1])


## out to the 竹林道, back through the mirror to the 黄石穿林路.
func _test_way_back(tree: SceneTree, session: WorldSessionController) -> void:
	var room: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.take_passage(tree, room, &"canyon.train.out"), "out")
	_check(session.active_map_id() == &"canyon.bamboo" and player.world_location().zone_id == &"canyon.bamboo3", "by the stone again: %s" % player.world_location().zone_id)
	var bamboo: WorldMapController = session.active_map() as WorldMapController
	_check((bamboo.service(GAP) as ActService).context_title() == "" and not session.room_states().has_flag(&"canyon.bamboo3", "exits/enter"), "the stone is shut: no gap")
	_check(await MapPlaces.drive_through(tree, bamboo, [&"canyon.bamboo2", &"canyon.bamboo1", &"canyon.fantasy1"]), "back down to the mirror's chamber")
	_check(await MapPlaces.take_passage(tree, bamboo, &"canyon.fantasy1.back"), "back through the mirror")
	_check(session.active_map_id() == &"canyon.pass" and player.world_location().zone_id == &"canyon.stone_forest3", "the clearing: %s" % player.world_location().zone_id)
	var gorge: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.stone_forest2", &"canyon.stone_forest1", &"canyon.canyon2"]), "east to 隘口小路")


## TEST-ONLY: force and max_force 600, force_factor 40.
func _strong(player: WorldPlayerRuntimeState) -> void:
	player.state.recovery.inner_force = CharacterInternalResourceState.new(600, 600)
	player.state.attributes.force_factor = 40


## TEST-ONLY: the player's gin, kee and sen at these, their maxima 100.
func _resources(player: WorldPlayerRuntimeState, gin: int, kee: int, sen: int) -> void:
	player.state.essence = CharacterResourceState.new(gin, 100, 100)
	player.state.vitality = CharacterResourceState.new(kee, 100, 100)
	player.state.spirit = CharacterResourceState.new(sen, 100, 100)


## The button with this text somewhere under `root`, or null.
func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return node as Button
	return null


## The button with this text on the 背包 row whose label begins with `row_name`, or null.
func _row_button(panel: PlayerInventoryPanel, row_name: String, text: String) -> Button:
	for row: Node in panel.row_container.get_children():
		var label: Label = row.get_child(0) as Label
		if label != null and label.text.begins_with(row_name) and not row.is_queued_for_deletion():
			return _button(row, text)
	return null


## TEST-ONLY: an item of `definition_id` in the player's pack.
func _new_item(session: WorldSessionController, definition_id: StringName) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, content.own_weight))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, destination).succeeded)
	return item.item_instance_id


## TEST-ONLY: destroys an empty item the player carries.
func _drop(session: WorldSessionController, id: StringName) -> bool:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(context.inventory, context.stacks, id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, context.owner)
	return removal.succeeded and context.index.forget_destroyed_snapshots(removal.removed_instance_ids, context.inventory)


## An item of `definition_id` the player carries directly (the first), or empty.
func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var found: Array[StringName] = _all_carried(session, definition_id)
	return &"" if found.is_empty() else found[0]


func _all_carried(session: WorldSessionController, definition_id: StringName) -> Array[StringName]:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var found: Array[StringName] = []
	for id: StringName in context.inventory.direct_children(context.endpoint()):
		var item: ItemInstance = context.index.resolve(id)
		if item != null and item.item_definition_id == definition_id:
			found.append(id)
	return found


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("canyon_bamboo_test.gd: " + message)
