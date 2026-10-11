extends RefCounted

## 天驼关 A (d/canyon): seventeen rooms on three maps — the 碎石小路 on the clifftop off Snow's
## 青石官道, the pass below it with the garrison's camp, and the 兵器库 (its way in is the swear,
## 天驼关 B) — the chain climbed both ways (its cost, asked first when it would knock the player
## out), the iron gate and its winch, the camp's well; 大队长's toll that adds up (owner, canyon
## plan Q2) and the mark that lets one past 李信 (his greeting throws the others out) into the
## 将军营帐; 大队长's story told two seconds a line. Walks use the move actions (MapPlaces).
## The 黄石穿林路, the mirror, the 竹林道 and the stone room (天驼关 C) are canyon_bamboo_test.
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"canyon.clifftop": 1, &"canyon.pass": 18, &"canyon.armory": 1, &"canyon.bamboo": 4, &"canyon.stoneroom": 1}
const CAPTAIN: StringName = &"canyon.npc.captain"
const VICE: StringName = &"canyon.npc.vice_general"
const STORY: Array[String] = [
	"二十多年前，先帝将大将军们调来这里驻守隘口。",
	"京城的也就因隘口的巩固而获得安全。",
	"事隔多年，先帝也死了，换上的是位我们不甚认识的小皇帝。",
	"看来他只忙著找剑，也没什么大作为，大家也不太服他。",
	"皇帝看到大将军还要敬畏三分ㄌㄟ。",
	"反正啊，将军和军师是超强的，你可要好好的乌西我们才行。",
	"知道了，就快缴钱。",
]
## Where each kind stands (camp1.c … camp8.c, blackmarket.c set("objects")).
const PEOPLE: Dictionary = {
	&"canyon.camp1": {&"canyon.npc.door_guard": 2},
	&"canyon.camp3": {&"canyon.npc.guard1": 2},
	&"canyon.camp4": {&"canyon.npc.guard1": 2, &"canyon.npc.guard2": 1},
	&"canyon.camp5": {&"canyon.npc.leader1": 2},
	&"canyon.camp6": {CAPTAIN: 1, &"canyon.npc.leader2": 1},
	&"canyon.camp7": {VICE: 1},
	&"canyon.camp8": {&"canyon.npc.general": 1, &"canyon.npc.adviser": 1},
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_way_in(tree, session)
	await _test_chain(tree, session)
	await _test_pass(tree, session)
	await _test_camp(tree, session)
	await _test_story(tree, session)
	await _test_toll(tree, session)
	await _test_armory(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("canyon."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "25 rooms on five maps (C's eight with them): %s" % maps)
	_check(catalog.region(&"canyon").display_name == "天驼关", "the region is 天驼关")
	_check(catalog.portal(&"snow.sroad4.southwest").destination_zone_id == &"canyon.road" and catalog.portal(&"canyon.road.northeast").destination_zone_id == &"snow.sroad4", "the 青石官道 south-west to the 碎石小路, and back")
	_check(catalog.zone_of_room(&"es2:d/canyon/stone_forest1") != null and catalog.room(&"es2:d/canyon/canyon2").exits().get("west") == "es2:d/canyon/stone_forest1", "canyon2.c leads west into the 黄石穿林路 (repaired, owner Q1)")
	for portal: PortalDefinition in catalog.portals_for_map(&"canyon.pass"):
		_check(portal.source_zone_id != &"canyon.canyon7", "nothing south of the valley yet (玉螺湖村 is #11): %s" % portal.portal_id)
	_check(catalog.room(&"es2:d/canyon/canyon7").exits().get("south") == "es2:d/village/road1", "canyon7.c's south names 玉螺湖村")
	var rule: ZoneExitRuleDefinition = catalog.exit_rules_between(&"canyon.camp7", &"canyon.camp8")[0]
	var stranger := ZoneExitRuleDefinition.Leaver.new()
	var listed := ZoneExitRuleDefinition.Leaver.new()
	listed.marks = {"军营": 1}
	_check(rule.refuses(stranger, false) and not rule.refuses(listed, false) and rule.lines == ["你还没被允许进入喔。"], "east into the 将军营帐 only with marks/军营")
	_check(catalog.landmark(&"canyon.canyon6.landmark.machine").description == "这是个很大的绞盘，可能是开关铁门用的。\n", "the winch can be looked at (item_desc's key mechine was a slip)")
	_check(catalog.landmark(&"canyon.canyon5.landmark.door").description.begins_with("这巨大的铁门锈迹斑斑"), "the iron gate")
	_check(catalog.service(&"canyon.camp2.well").kind == &"water", "the camp's well fills a wineskin")
	_check(catalog.room(&"es2:d/canyon/road").long.contains("这里人烟稀少") and not catalog.room(&"es2:d/canyon/camp8").long.contains("□"), "lost characters: 这里, 鼎 (默认)")
	var captain: NpcDefinition = catalog.npc(CAPTAIN)
	_check(captain.dealings().object_rules.size() == 4 and captain.dealings().object_rules[2].tally == "军营", "大队长's gifts add up under 军营")


## Snow's 青石官道 south-west onto the clifftop, and back.
func _test_way_in(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"snow.outdoor", &"snow.sroad4", &"snow.sroad4", &"snow.sroad4.canyon_return").succeeded(), "on the 青石官道")
	var snow: WorldMapController = session.active_map() as WorldMapController
	# TEST-ONLY: the crazy dog of the 青石官道 would start a fight (snow_south_road_test's).
	snow.find_resident_npc(&"snow.sroad4.crazy_dog.1.character").set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	await tree.physics_frame
	_check(await MapPlaces.take_passage(tree, snow, &"snow.sroad4.southwest"), "south-west onto the gravel path")
	var top: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(top.map_id() == &"canyon.clifftop" and location.zone_id == &"canyon.road", "the 碎石小路: %s" % location.zone_id)
	_check(session.place_name(location) == "天驼关 · 碎石小路", "天驼关 · 碎石小路: %s" % session.place_name(location))
	_check(Work.capture(session) != null, "Save on the clifftop")
	_check(await MapPlaces.take_passage(tree, top, &"canyon.road.northeast"), "north-east back to Snow")
	_check(session.active_map_id() == &"snow.outdoor" and session.player_runtime().world_location().zone_id == &"snow.sroad4", "the 青石官道")
	snow = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, snow, &"snow.sroad4.southwest"), "and onto the clifftop again")


## road.c and canyon1.c do_climb(): down 20 gin, 30 kee, 10 sen; up 30, 40, 20; a climb that
## would take one below zero is asked first, and gone through anyway it moves them.
func _test_chain(tree: SceneTree, session: WorldSessionController) -> void:
	var top: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_resources(player, 100, 100, 100)
	_check(top.select_landmark(&"canyon.road.landmark.chain"), "the chain")
	top.inspect_selected()
	_check(hud.inspection_text.text.contains("或许你可以试著攀爬(climb)"), "一长条铁索缘山壁而下: %s" % hud.inspection_text.text.left(30))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	var down: ActService = top.service(&"canyon.road.chain") as ActService
	_check(await MapPlaces.drive(tree, top, MapPlaces.service_spot(top, &"canyon.road.chain")) and down.in_reach(), "by the mound")
	_check(down.verb() == "爬下去", "铁索 · 爬下去")
	down.interact()
	await tree.physics_frame
	await tree.physics_frame
	_check(not hud.is_asking(), "not asked: it does not knock the player out")
	var gorge: WorldMapController = session.active_map() as WorldMapController
	_check(gorge.map_id() == &"canyon.pass" and player.world_location().zone_id == &"canyon.canyon1", "down at the 黄石隘口尾: %s" % player.world_location().zone_id)
	_check(hud.log_lines().has("你手脚并用，努力地沿著铁索向下攀爬而去。"), "你手脚并用，努力地沿著铁索向下攀爬而去。")
	_check(player.state.essence.current == 80 and player.state.vitality.current == 70 and player.state.spirit.current == 90, "20 gin, 30 kee, 10 sen: %d %d %d" % [player.state.essence.current, player.state.vitality.current, player.state.spirit.current])
	_check(Work.capture(session) != null, "Save at the pass's tail")
	var up: ActService = gorge.service(&"canyon.canyon1.chain") as ActService
	_check(await MapPlaces.drive(tree, gorge, MapPlaces.service_spot(gorge, &"canyon.canyon1.chain")) and up.in_reach() and up.verb() == "爬上去", "铁索 · 爬上去")
	up.interact()
	await tree.physics_frame
	await tree.physics_frame
	top = session.active_map() as WorldMapController
	_check(top.map_id() == &"canyon.clifftop" and player.world_location().zone_id == &"canyon.road", "up on the clifftop")
	_check(hud.log_lines().has("你手脚并用，努力地沿著铁索向上攀缘上去了"), "你手脚并用，努力地沿著铁索向上攀缘上去了")
	_check(player.state.essence.current == 50 and player.state.vitality.current == 30 and player.state.spirit.current == 70, "30 gin, 40 kee, 20 sen: %d %d %d" % [player.state.essence.current, player.state.vitality.current, player.state.spirit.current])
	# 30 kee left: down takes 30, which leaves 0 (not below): not asked. Then 20 kee: asked.
	_resources(player, 100, 20, 100)
	down = top.service(&"canyon.road.chain") as ActService
	_check(await MapPlaces.drive(tree, top, MapPlaces.service_spot(top, &"canyon.road.chain")), "back by the mound")
	down.interact()
	await tree.physics_frame
	_check(hud.is_asking() and hud.confirm_prompt.message.text.begins_with("爬下去要耗去 30 点气，你现在撑不住，会当场昏过去。"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(session.active_map_id() == &"canyon.clifftop" and player.state.vitality.current == 20, "取消: still on the clifftop, nothing spent")
	down.interact()
	await tree.physics_frame
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == &"canyon.pass" and player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "确定: down, kee below zero, knocked out (unconcious())")
	for _second: int in range(300):
		if player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session._process(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.world_location().zone_id == &"canyon.canyon1", "and wakes at the pass's tail")
	_resources(player, 100, 100, 100)


## The pass south past the camp's gate to the iron gate and the valley.
func _test_pass(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.canyon2", &"canyon.canyon3", &"canyon.canyon4", &"canyon.canyon5"]), "down the yellow-earth path to the iron gate")
	_check(gorge.select_landmark(&"canyon.canyon5.landmark.door"), "the iron gate")
	gorge.inspect_selected()
	_check(hud.inspection_text.text.contains("现在已经高高的抬起"), "raised high: %s" % hud.inspection_text.text.left(30))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.canyon6", &"canyon.canyon7"]), "through the gate into the valley")
	_check(session.place_name(session.player_runtime().world_location()) == "天驼关 · 天驼关谷地", "天驼关 · 天驼关谷地")
	_check(Work.capture(session) != null, "Save in the valley")
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.canyon6", &"canyon.canyon5", &"canyon.canyon4", &"canyon.camp1", &"canyon.camp2"]), "back north and into the camp")
	var well: WaterService = gorge.service(&"canyon.camp2.well") as WaterService
	_check(await MapPlaces.drive(tree, gorge, MapPlaces.service_spot(gorge, &"canyon.camp2.well")) and well.available(), "the camp's well fills a wineskin")


## Who stands where; 李信 throws out one the 大队长 has not listed; the 将军营帐 is barred.
func _test_camp(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var found: Dictionary = {}
	for npc: NpcRuntimeState in gorge.resident_npcs():
		var zone: StringName = npc.world_location().zone_id
		if not found.has(zone):
			found[zone] = {}
		found[zone][npc.definition().definition_id] = found[zone].get(npc.definition().definition_id, 0) + 1
	_check(found == PEOPLE, "the garrison where camp1-8.c put them: %s" % [found])
	_check(await MapPlaces.drive_to_zone(tree, gorge, &"canyon.camp7"), "into the 副将营帐")
	gorge.npc_life._advance_ambience(0.0)
	gorge.npc_life._advance_ambience(1.0)
	await tree.physics_frame
	await tree.physics_frame
	_check(hud.log_lines().has("李信说道：大胆狂徒，竟私闯此地，给我滚出去") and player.world_location().zone_id == &"canyon.camp2", "大胆狂徒，竟私闯此地，给我滚出去: out at the camp fire (%s)" % player.world_location().zone_id)
	_check(Work.capture(session) != null, "Save at the camp fire")


## captain.c tell_story(): nothing at once (no 没听说过 either), then a line every two seconds.
func _test_story(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_to_zone(tree, gorge, &"canyon.camp6"), "into the squad leaders' tent")
	gorge.npc_life._advance_ambience(0.0)
	var captain: NpcRuntimeState = _npc(gorge, CAPTAIN)
	_check(captain != null and gorge.select_npc(captain.character_id), "大队长")
	_check(gorge.ask_topics_selected().has("允许") and gorge.ask_topics_selected().has("黄石隘口"), "允许, 兵器库, 黄石隘口")
	_check(gorge.ask_selected("允许") == ["你向大队长打听有关『允许』的消息。", "大队长说道：先给钱再说吧。"], "允许: 先给钱再说吧。")
	var said: Array[String] = gorge.ask_selected("黄石隘口")
	_check(said == ["你向大队长打听有关『黄石隘口』的消息。"], "黄石隘口: nothing at once: %s" % [said])
	var start: int = hud.log_lines().size()
	gorge.npc_life._advance_ambience(1.0)
	_check(hud.log_lines().size() == start, "nothing before two seconds")
	for stage: int in range(STORY.size()):
		gorge.npc_life._advance_ambience(1.0 if stage == 0 else 2.0)
		_check(hud.log_lines()[-1] == STORY[stage], "line %d: %s" % [stage, hud.log_lines()[-1]])
	gorge.npc_life._advance_ambience(10.0)
	_check(hud.log_lines()[-1] == STORY[-1] and not gorge.npc_life.makings.has(captain.character_id), "the story ends: 知道了，就快缴钱。")


## captain.c accept_object(): 30 taels for the list; less is kept, and the owner's ruling
## (canyon plan Q2) adds it up; listed, more is thanked for; what is not money, too.
func _test_toll(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var context: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(context, CurrencyDenomination.Value.SILVER, 31, &"test.toll") # TEST-ONLY
	var captain: NpcRuntimeState = _npc(gorge, CAPTAIN)
	_check(gorge.select_npc(captain.character_id), "大队长 again")
	var silver: int = Finance.amount(context, CurrencyDenomination.Value.SILVER)
	var first: ItemHandlingResult = gorge.give_to_selected(&"test.toll", 20)
	_check(first.done() and first.lines[0] == "大队长说道:你的诚意不够喔，再多缴点吧。" and player.state.counters.get("tally/军营", 0) == 2000 and not player.state.marks.has("军营"), "twenty taels: not enough, kept, counted: %s" % [first.lines])
	_check(Finance.amount(context, CurrencyDenomination.Value.SILVER) == silver - 20, "the twenty taels gone: %d of %d" % [Finance.amount(context, CurrencyDenomination.Value.SILVER), silver])
	# What was paid survives Save and Continue.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded() and encoded.text.contains("\"tally/军营\""), "the save holds the twenty taels paid")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "天驼关 A after twenty taels")
	_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue in the squad leaders' tent")
	if restored.succeeded():
		_check(restored.candidate.player_runtime().state.counters.get("tally/军营", 0) == 2000, "after Continue, twenty taels still paid")
		restored.candidate.free()
		await tree.process_frame
	var second: ItemHandlingResult = gorge.give_to_selected(&"test.toll", 10)
	_check(second.done() and second.lines[0] == "大队长说道:我已帮你列入名册了，从今天你可自由地出入营区了。" and player.state.marks.get("军营", 0) == 1 and not player.state.counters.has("tally/军营"), "ten more: thirty in all, listed (marks/军营), the count settled: %s" % [second.lines])
	var third: ItemHandlingResult = gorge.give_to_selected(&"test.toll", 1)
	_check(third.done() and third.lines[0] == "大队长说道:哦喔！还真有心啊，真是谢谢你了。", "listed, one more tael is thanked for")
	var blade: StringName = _new_item(session, &"es2:d/canyon/npc/obj/blade")
	var thing: ItemHandlingResult = gorge.give_to_selected(blade)
	_check(thing.done() and thing.lines[0] == "大队长说道：ㄟ....Ｔhank Ｙou!!!", "not money: Thank You, and kept: %s" % [thing.lines])
	# Listed: 李信 lets the player be, and the 将军营帐 is open.
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.camp2", &"canyon.camp7"]), "into the 副将营帐 again")
	gorge.npc_life._advance_ambience(0.0)
	gorge.npc_life._advance_ambience(1.0)
	await tree.physics_frame
	_check(player.world_location().zone_id == &"canyon.camp7", "李信 lets the listed stay")
	_check(await MapPlaces.drive_to_zone(tree, gorge, &"canyon.camp8"), "on into the 将军营帐")
	_check(_npc(gorge, &"canyon.npc.general").world_location().zone_id == &"canyon.camp8" and session.place_name(player.world_location()) == "天驼关 · 将军营帐", "严廷殷 and his 军师")


## The 兵器库 (its way in is the swear, 天驼关 B): the 后备兵 there, and the way out east.
func _test_armory(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"canyon.armory", &"canyon.blackmarket", &"canyon.blackmarket", &"canyon.blackmarket.swear_arrival").succeeded(), "TEST-ONLY: into the 兵器库")
	await tree.physics_frame
	var armory: WorldMapController = session.active_map() as WorldMapController
	_check(_npc(armory, &"canyon.npc.seller") != null and session.place_name(session.player_runtime().world_location()) == "天驼关 · 兵器库", "the 后备兵 among the weapons")
	_check(await MapPlaces.take_passage(tree, armory, &"canyon.blackmarket.east"), "out east")
	_check(session.active_map_id() == &"canyon.pass" and session.player_runtime().world_location().zone_id == &"canyon.canyon4", "onto 隘口中道")


## TEST-ONLY: the player's gin, kee and sen at these, their maxima 100.
func _resources(player: WorldPlayerRuntimeState, gin: int, kee: int, sen: int) -> void:
	player.state.essence = CharacterResourceState.new(gin, 100, 100)
	player.state.vitality = CharacterResourceState.new(kee, 100, 100)
	player.state.spirit = CharacterResourceState.new(sen, 100, 100)


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
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


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("canyon: " + message)
