extends RefCounted

## 黑松山 (d/chuenyu) A: twenty-three rooms on two maps — the 黄土大道 west off 玉螺湖村's highway
## (owner, 玉螺湖村 plan Q2: ES2 had no way in), the paddies, the mountain path, the granite
## streets and the 铁索桥, 黑松堡's gate (combat_exp below 2000 turned back), the 夹道 and its
## arrows (trap_castle.c arrowing()), the vine-covered walls climbed into the gardens, the halls
## and 淳于's upper floor. The 紫衣家丁 on the bridge look the passer over (random(per) < 20), the
## 护院 attack whoever comes in, the 巨型犬 are killer (answers as aggressive, attacks only by
## berserk). 烤山猪肉 is food and a hammer (M4). The 地牢 and 小娟 wait for B.
## Walks use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"chuenyu.main": 20, &"chuenyu.upstairs": 3}
const JIADING: StringName = &"chuenyu.npc.jiading3"
const GUARD: StringName = &"chuenyu.npc.guard"
const WOLFDOG: StringName = &"chuenyu.npc.wolfdog"
const PIGMEAT: StringName = &"es2:d/chuenyu/obj/pigmeat"
const HIND: StringName = &"es2:u/cloud/obj/meat/hind"
const ARROW_LINES: Array[String] = ["刹那间石墙的后面“嘣嘣”声不绝，无数羽箭从圆孔中向你激射而出！！", "你被乱箭射得头破血流，遍体鳞伤！"]
## Where each kind stands (the rooms' set("objects")).
const PEOPLE: Dictionary = {
	&"chuenyu.sunnyroad": {&"chuenyu.npc.flower_seller": 1},
	&"chuenyu.rope_bridge": {JIADING: 2},
	&"chuenyu.west_garden": {&"chuenyu.npc.gardener": 1, &"chuenyu.npc.bee": 2},
	&"chuenyu.north_garden": {&"chuenyu.npc.smallgardener": 2},
	&"chuenyu.west_blackge": {GUARD: 2},
	&"chuenyu.east_blackge": {&"chuenyu.npc.cleangirl": 1},
	&"chuenyu.east_garden": {WOLFDOG: 3},
	&"chuenyu.south_garden": {&"chuenyu.npc.smallgardener": 2},
}
const UPSTAIRS_PEOPLE: Dictionary = {
	&"chuenyu.yiantai": {&"chuenyu.npc.pigeon": 2},
	&"chuenyu.kitchen": {&"chuenyu.npc.cook": 1},
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_greetings()
	_test_reminders()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_way_in(tree, session)
	await _test_mountain(tree, session)
	await _test_gate(tree, session)
	await _test_arrows(tree, session)
	await _test_walls(tree, session)
	await _test_halls(tree, session)
	session = await _test_pigmeat(tree, session)
	await _test_knockout(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("chuenyu."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "twenty-three rooms on two maps: %s" % maps)
	_check(catalog.region(&"chuenyu").display_name == "黑松山", "the region is 黑松山")
	# Q1 (a): d/chuenyu's copy of 刘家 (cut off in ES2: sunnyroad.c's south commented out) is not placed.
	for room: String in ["dustyroad3", "home", "littlegarden", "smallstorage", "smallyard"]:
		_check(catalog.zone_of_room(StringName("es2:d/chuenyu/" + room)) == null, "刘家's copy not placed: %s" % room)
	var sunny: RoomDefinition = catalog.room(&"es2:d/chuenyu/sunnyroad")
	_check(sunny.no_fight and sunny.no_magic, "the 山脚乡田: no fighting, no magic")
	for id: StringName in [&"chuenyu.gate_castle.door", &"chuenyu.west_blackge.door", &"chuenyu.bedroom.door"]:
		_check(catalog.door(id) != null and not catalog.door(id).starts_open, "%s shut" % id)
	_check(catalog.door(&"chuenyu.bedroom.door").display_name == "玉帘门", "the 玉帘门 to the 膳房")
	for from_zone: StringName in [&"chuenyu.high_b_mtn", &"chuenyu.high_b_mtn2"]:
		var rules: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(from_zone, &"chuenyu.gate_castle")
		var leaver := ZoneExitRuleDefinition.Leaver.new()
		leaver.combat_exp = 1999
		var refused: bool = rules.size() == 1 and rules[0].refuses(leaver, false)
		leaver.combat_exp = 2000
		_check(refused and not rules[0].refuses(leaver, false) and rules[0].lines == ["你被黑松堡散出的强烈杀气当了回来。"], "%s: below 2000 combat_exp the castle's killing air turns one back" % from_zone)
	var arrows: RoomHazardDefinition = catalog.hazard_in(&"chuenyu.trap_castle")
	_check(arrows != null and arrows.first_ms == 15000 and arrows.every_ms == 5000, "the 夹道: arrows 15 s after coming in, then every 5 s")
	var hurt: ScriptedAct.Step = arrows.act.steps[-1]
	_check(hurt.kind == ScriptedAct.Kind.HURT and hurt.amounts.get("kee", 0) == 35 and hurt.randoms.get("kee", 0) == 10, "random(10)+35 off eff_kee and kee")
	_check(catalog.landmark(&"chuenyu.trap_castle.landmark.noise").description == "这显然是拉开强弩的声音。\n", "the noise: crossbows drawn")
	_check(catalog.landmark(&"chuenyu.east_castle.landmark.rock").description == "青石板劳牢的镶在地下，但它下面似乎是空的。\n", "the slab: hollow beneath (B)")
	# M4: 烤山猪肉 is food and a hammer; eaten up it is the 山猪骨头, a hammer still; 牛腿 too.
	var meat: ItemContentDefinition = catalog.item(PIGMEAT)
	_check(meat.weapon_definition() != null and meat.weapon_definition().skill_type == &"hammer" and meat.food_definition() != null and meat.food_definition().initial_portions == 6 and meat.food_definition().food_supply == 90, "烤山猪肉: a hammer, six bites of 90")
	var rib: ItemContentDefinition = catalog.item(meat.leftover_id())
	_check(rib.display_name == "山猪骨头" and rib.weapon_definition() != null and rib.food_definition() == null and rib.aliases().has("bone") and rib.own_weight == 250, "山猪骨头: a hammer still (bone for the dog)")
	var broken: ItemContentDefinition = catalog.item(ItemContentDefinition.broken_id(PIGMEAT))
	_check(broken != null and broken.food_definition() != null and broken.food_definition().initial_value == 6 and broken.value == 6 and broken.weapon_definition() == null and catalog.item(broken.leftover_id()) != null, "broken it is food still (F_FOOD), worth a tenth, not a weapon")
	var hind: ItemContentDefinition = catalog.item(HIND)
	_check(hind.weapon_definition() != null and hind.food_definition() != null and catalog.item(hind.leftover_id()).display_name == "牛腿骨", "牛腿: food now, and a hammer (M4)")
	_check(catalog.npc(WOLFDOG).attitude == NpcDefinition.Attitude.KILLER, "巨型犬: attitude killer")
	_check(catalog.npc(GUARD).has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE), "护院: kill_ob() whoever comes in")
	_check(catalog.vendor(&"chuenyu.vendor.flower_seller").item_definition_id("black flower") == &"es2:d/chuenyu/npc/obj/black_flower", "卖花姑娘 sells the 黑牡丹")


## jiading3.c checklooking(): random(per) < 20 looks the passer over and fights; a killer
## attacks only by its berserk.
func _test_greetings() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var talk: NpcTalk = catalog.npc(JIADING).talk()
	for case: Array in [[30, 19, true], [30, 20, false], [15, 14, true]]:
		var facts := ScriptedAct.Facts.new()
		facts.per = case[0]
		var drawn: Array[int] = []
		facts.draw = func(bound: int) -> int:
			drawn.append(bound)
			return case[1]
		var act: ScriptedAct = talk.choose_greeting(&"男性", &"", func(_bound: int) -> int: return 0, facts)
		_check((act != null) == case[2] and drawn == [case[0]], "per %d, random(per) %d: %s (%s)" % [case[0], case[1], "stopped" if case[2] else "passes", drawn])
		if act != null:
			var kinds: Array = act.steps.map(func(step: ScriptedAct.Step) -> int: return step.kind)
			_check(kinds == [ScriptedAct.Kind.LINE, ScriptedAct.Kind.LINE, ScriptedAct.Kind.NPC_FLAG, ScriptedAct.Kind.NPC_FLAG, ScriptedAct.Kind.KILL] and act.steps[2].flag == String(NpcDefinition.FLAG_HUNTS_PLAYER) and act.steps[3].flag == String(NpcDefinition.FLAG_AGGRESSIVE), "站住！… then kill_ob() (his hatred) and attitude aggressive")
	# attack.c init(): only "aggressive" attacks on sight; the killer dogs go berserk (bellicosity 3000).
	_check(Berserk.applies_to(catalog.npc(WOLFDOG)) and not catalog.npc(WOLFDOG).has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE), "巨型犬: no attack on sight, its berserk does")


## Content that waits for 黑松山 B keeps a test that fails once it comes.
func _test_reminders() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# 黑松山 B: the 地牢 (center.c's pull, tunnel4.c's slab), 淳于怀太 and 小娟, 刘老农's thanks and revenge.
	for room: String in ["tunnel1", "tunnel2", "tunnel3", "tunnel4", "tunnel5", "tunnel6", "dungeon", "tortureroom", "tortureroom2"]:
		_check(catalog.zone_of_room(StringName("es2:d/chuenyu/" + room)) == null, "the 地牢 is placed (%s): give center.c's rope its pull (asked first), tunnel4.c's slab, 淳于怀太 and 小娟 (B)" % room)
	_check(catalog.landmark(&"chuenyu.center.landmark.rope").policy == &"look" and catalog.service(&"chuenyu.center.pull") == null, "the rope only looks until the 地牢 comes (B)")


## 玉螺湖村's 黄土大道: its spur west (owner Q2) onto d/chuenyu's 黄土大道, and back.
func _test_way_in(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"village.main", &"village.road1", &"village.road1", &"village.road1.chuenyu_return").succeeded(), "on the village's 黄土大道")
	await tree.physics_frame
	var village: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, village, &"village.road1.west"), "west along the spur")
	var map: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(map.map_id() == &"chuenyu.main" and location.zone_id == &"chuenyu.croad1", "黑松山's 黄土大道: %s" % location.zone_id)
	_check(session.place_name(location) == "黑松山 · 黄土大道", "黑松山 · 黄土大道: %s" % session.place_name(location))
	_check(Work.capture(session) != null, "Save on the 黄土大道")
	_check(await MapPlaces.take_passage(tree, map, &"chuenyu.croad1.south"), "back east")
	_check(session.active_map_id() == &"village.main" and session.player_runtime().world_location().zone_id == &"village.road1", "the village's 黄土大道")
	village = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, village, &"village.road1.west"), "and west again")


## Who stands where; up the road, through the paddies and the mountain path to the bridge.
func _test_mountain(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(_people(map) == PEOPLE, "the people where the rooms put them: %s" % [_people(map)])
	player.state.attributes.personality = 30 # TEST-ONLY: Still draws random(per) = 29, not below 20
	_check(await MapPlaces.drive_through(tree, map, [&"chuenyu.croad2", &"chuenyu.sunnyroad", &"chuenyu.base_b_m", &"chuenyu.foot_b_mtn", &"chuenyu.high_b_mtn", &"chuenyu.rope_bridge"]), "the crossing, the paddies, the foot, up the path, the west street, onto the bridge")
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "a handsome passer crosses the bridge")
	_check(Work.capture(session) != null, "Save on the bridge")
	# The chain: straight down to the foot (do_climb()).
	var chain: ActService = map.service(&"chuenyu.rope_bridge.climb") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, chain.service_id())) and chain.in_reach() and chain.verb() == "顺着走下去", "铁链 · 顺着走下去")
	chain.interact()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"chuenyu.base_b_m" and session.shared_ui().log_lines().has("你抓紧铁链，顺着铁索桥走了下去。"), "down the chain to the foot")
	# M2: the path is walked both ways, and the east street comes down to the foot too.
	_check(await MapPlaces.drive_through(tree, map, [&"chuenyu.high_b_mtn2", &"chuenyu.rope_bridge"]), "up the east street, onto the bridge from the east")
	player.state.attributes.personality = 15 # TEST-ONLY: random(per) = 14, below 20
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.high_b_mtn"), "off the bridge")
	map.npc_life._advance_ambience(0.0)
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.rope_bridge"), "and on again")
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(1.0)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.LETHAL, "站住！你干什么的。 — a fight to the death")
	_check(session.shared_ui().log_lines().has("紫衣家丁说道：看你那贼眉鼠眼，尖嘴猴腮的样儿，决不是什么好东西！"), "贼眉鼠眼: %s" % [session.shared_ui().log_lines().slice(-4)])
	var hostile: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == JIADING and npc.flags().get(NpcDefinition.FLAG_AGGRESSIVE, false):
			hostile = npc
	_check(hostile != null and hostile.definition().attacks_on_sight(hostile.flags(), player.state), "a 家丁 who stopped the player turns aggressive: he attacks on sight from now on")
	_finish_fight(session)
	if hostile != null:
		hostile.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, false) # TEST-ONLY: as the player's death clears it
		_check(hostile.definition().attacks_on_sight(hostile.flags(), player.state), "his attitude outlives his hatred (kill_passenger()'s set(\"attitude\"))")
	for npc: NpcRuntimeState in map.resident_npcs():
		npc.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, false) # TEST-ONLY
		npc.set_flag(NpcDefinition.FLAG_AGGRESSIVE, false) # TEST-ONLY
	player.state.attributes.personality = 30


## gate_castle.c init(): below 2000 combat_exp the castle's killing air turns one back.
func _test_gate(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(map.place_player(&"chuenyu.high_b_mtn2", MapPlaces.zone_centre(map, &"chuenyu.high_b_mtn2")), "TEST-ONLY: on the east street")
	await tree.physics_frame
	player.state.progression.combat_experience = 1999 # TEST-ONLY
	_check(not await MapPlaces.drive_to_zone(tree, map, &"chuenyu.gate_castle"), "up to the gate: turned back")
	_check(player.world_location().zone_id == &"chuenyu.high_b_mtn2" and session.shared_ui().log_lines().has("你被黑松堡散出的强烈杀气当了回来。"), "被黑松堡散出的强烈杀气当了回来")
	player.state.progression.combat_experience = 2000 # TEST-ONLY
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.gate_castle"), "with 2000: before the gate")
	_check(Work.capture(session) != null, "Save before the gate")


## trap_castle.c: behind the 城门 the 夹道; 15 seconds after coming in the arrows fly, then every
## 5 seconds while one stays (eff_kee and kee down random(10)+35 each time).
func _test_arrows(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var kee: CharacterResourceState = player.state.vitality
	kee.maximum = 1000 # TEST-ONLY: tough enough for three volleys
	kee.effective = 1000
	kee.current = 1000
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"chuenyu.gate_castle.door", &"chuenyu.gate_castle")), "at the 城门")
	_check(map.open_door(&"chuenyu.gate_castle.door"), "open the 城门")
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.trap_castle"), "into the 夹道")
	var hazards: WorldRoomHazards = session.room_hazards()
	session.advance_room_hazards(14.9)
	_check(kee.current == 1000 and not hud.log_lines().has(ARROW_LINES[0]), "nothing for fifteen seconds")
	session.advance_room_hazards(0.2)
	var first: int = 1000 - kee.current
	_check(first >= 35 and first <= 44 and kee.effective == kee.current and _said(hud, ARROW_LINES), "the arrows: %d off eff_kee and kee: %s" % [first, hud.log_lines().slice(-2)])
	session.advance_room_hazards(4.7)
	_check(1000 - kee.current == first, "the next volley waits five seconds")
	session.advance_room_hazards(0.4)
	_check(1000 - kee.current >= first + 35 and kee.effective == kee.current, "and comes: %d" % (1000 - kee.current))
	_check(Work.capture(session) != null, "Save in the 夹道 (the wait is not saved)")
	for landmark: StringName in [&"chuenyu.trap_castle.landmark.hole", &"chuenyu.trap_castle.landmark.rock"]:
		_check(map.select_landmark(landmark), "%s" % landmark)
		map.inspect_selected()
		hud.dismiss_current_panel()
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.gate_castle"), "out of the 夹道")
	var after: int = kee.current
	session.advance_room_hazards(20.0)
	_check(kee.current == after and hazards.elapsed_ms() == 0.0, "outside, no arrows")
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.trap_castle"), "back in")
	session.advance_room_hazards(5.0)
	_check(kee.current == after, "coming back waits the fifteen seconds again (init()'s remove_call_out())")
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.gate_castle"), "out again")


## The vine-covered walls: climbed from the clifftops into the gardens and back (at once, M1).
func _test_walls(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_to_zone(tree, map, &"chuenyu.west_castle"), "west along the clifftop")
	for climb: Array in [[&"chuenyu.west_castle.climb", &"chuenyu.west_garden"], [&"chuenyu.west_garden.climb", &"chuenyu.west_castle"]]:
		var service: ActService = map.service(climb[0]) as ActService
		_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, climb[0])) and service.in_reach() and service.verb() == "爬上去", "%s: 城墙 · 爬上去" % climb[0])
		service.interact()
		await tree.physics_frame
		_check(player.world_location().zone_id == climb[1] and hud.log_lines().has("你抓着蔓藤，慢慢的顺着城墙爬了上去。") and hud.log_lines().has("你用手一撑墙头儿，轻巧的跳了过来。"), "over the wall into %s" % climb[1])
		# The garden's killer bees may go berserk on whoever drops in (bellicosity 3000).
		await tree.physics_frame
		_finish_fight(session)
	_check(map.select_landmark(&"chuenyu.west_castle.landmark.vine"), "the vines")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("蔓藤长满了城墙"), "蔓藤长满了城墙: %s" % hud.inspection_text.text.left(20))
	hud.dismiss_current_panel()
	await tree.physics_frame


## Inside: the 护院 fall on whoever comes into the west hall; the stairs up to 淳于's rooms, the
## 玉帘门 to the 膳房 and the cook; down the other stairs to the east hall.
func _test_halls(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.place_player(&"chuenyu.west_garden", MapPlaces.zone_centre(map, &"chuenyu.west_garden")), "TEST-ONLY: in the west garden")
	await tree.physics_frame
	_finish_fight(session)
	# Into the west hall: the 护院 attack as the player comes in (the walk stops there).
	await MapPlaces.drive_to_zone(tree, map, &"chuenyu.west_blackge")
	await tree.physics_frame
	if not coordinator.has_active_encounter():
		map.hostilities.process_pending_aggression()
	_check(coordinator.has_active_encounter() and player.world_location().zone_id == &"chuenyu.west_blackge", "the 护院 attack whoever comes in: %s" % player.world_location().zone_id)
	_finish_fight(session)
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == GUARD:
			npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: out of the way
	_check(map.place_player(&"chuenyu.west_blackge", MapPlaces.zone_centre(map, &"chuenyu.west_blackge")), "TEST-ONLY: in the west hall")
	await tree.physics_frame
	_check(await MapPlaces.take_passage(tree, map, &"chuenyu.west_blackge.eastup"), "up the stairs")
	var upstairs: WorldMapController = session.active_map() as WorldMapController
	_check(upstairs.map_id() == &"chuenyu.upstairs" and player.world_location().zone_id == &"chuenyu.bedroom", "淳于's bedroom")
	_check(_people(upstairs) == UPSTAIRS_PEOPLE, "the pigeons on the balcony, the cook in the 膳房: %s" % [_people(upstairs)])
	_check(await MapPlaces.drive_to_zone(tree, upstairs, &"chuenyu.yiantai"), "out on the balcony")
	_check(await MapPlaces.drive(tree, upstairs, MapPlaces.door_spot(upstairs, &"chuenyu.bedroom.door", &"chuenyu.bedroom")), "at the 玉帘门")
	_check(upstairs.open_door(&"chuenyu.bedroom.door"), "open the 玉帘门")
	_check(await MapPlaces.drive_to_zone(tree, upstairs, &"chuenyu.kitchen"), "into the 膳房")
	upstairs.npc_life._advance_ambience(0.0)
	upstairs.npc_life._advance_ambience(1.0)
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.has("厨子嘟囔着：“真是的，堡主又在地牢里留涟忘返。”") or log.has("厨子道：“去地牢叫堡主上来吃饭。"), "the cook grumbles about the 地牢: %s" % [log.slice(-2)])
	_check(Work.capture(session) != null, "Save in the 膳房")
	_check(await MapPlaces.drive_to_zone(tree, upstairs, &"chuenyu.bedroom") and await MapPlaces.take_passage(tree, upstairs, &"chuenyu.bedroom.eastdown"), "down the east stairs")
	_check(session.active_map_id() == &"chuenyu.main" and player.world_location().zone_id == &"chuenyu.east_blackge", "the east hall")


## 烤山猪肉 (M4): wielded as a hammer and eaten; Continue mid-meal keeps the meat in the hand;
## the last bite leaves the 山猪骨头 in the hand, and Continue keeps that too.
func _test_pigmeat(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var meat: StringName = map.floor_items.give_new_item_to_player(PIGMEAT) # TEST-ONLY
	_check(session.wield_player_item(meat).succeeded, "wield the 烤山猪肉")
	var outcomes: Array[int] = []
	for bite: int in range(3):
		outcomes.append(_bite(session, meat).outcome)
	session = await _continue(tree, session)
	player = session.player_runtime()
	var food: FoodState = session.food_collection().state(meat)
	_check(food != null and food.remaining_portions == 3 and player.state.equipment.primary_weapon().weapon_id == PIGMEAT, "Continue mid-meal: three bites left, the meat in the hand")
	var last: FoodUseResult = null
	for bite: int in range(3):
		last = _bite(session, meat)
		outcomes.append(last.outcome)
	_check(outcomes.all(func(outcome: int) -> bool: return outcome == FoodUseResult.Outcome.ATE) and player.state.recovery.food == 90, "six bites of 90 while wielded: %s" % [outcomes])
	var rib: ItemContentDefinition = GameContent.catalog().item(session.item_instance_index().resolve(meat).item_definition_id)
	_check(last.leftover_id == rib.item_definition_id and rib.display_name == "山猪骨头" and player.state.equipment.primary_weapon().weapon_id == rib.item_definition_id and session.inventory_state().own_weight(meat) == 250, "the 250 g 山猪骨头 is what the hand holds")
	session = await _continue(tree, session)
	player = session.player_runtime()
	_check(player.state.equipment.primary_weapon() != null and player.state.equipment.primary_weapon().weapon_id == rib.item_definition_id and session.food_collection().state(meat) == null, "Continue: the bone still in the hand")
	return session


## A volley that knocks the player out ends that moment: the next comes five seconds on (and
## finds them lying there, as ES2's would). Last: the player is left lying in the 夹道.
func _test_knockout(tree: SceneTree, session: WorldSessionController) -> void:
	# Continue came back in the east hall, on this map.
	_check(session.active_map_id() == &"chuenyu.main", "on 黑松山's map")
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	map.open_door(&"chuenyu.gate_castle.door")
	_check(map.place_player(&"chuenyu.trap_castle", MapPlaces.zone_centre(map, &"chuenyu.trap_castle")), "TEST-ONLY: in the 夹道")
	await tree.physics_frame
	var kee: CharacterResourceState = player.state.vitality
	kee.maximum = 1000 # TEST-ONLY
	kee.effective = 1000
	kee.current = 10
	session.advance_room_hazards(25.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and kee.effective >= 1000 - 44, "one volley knocks the player out; the volleys due with it wait: eff %d" % kee.effective)


func _bite(session: WorldSessionController, item_id: StringName) -> FoodUseResult:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.recovery.food = 0 # TEST-ONLY: hungry
	return HeldFoodUseService.eat(player, Finance.session_context(session), session.food_collection(), GameContent.catalog().native_item_projections(), item_id, true)


## Save, and Continue from it in a fresh session (the old one freed first: two would share physics).
func _continue(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save")
	if snapshot == null:
		return session
	session.free()
	await tree.process_frame
	var preparation: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	var restored: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	_check(restored.configure_restore(preparation.preparation), "Continue configured")
	tree.root.add_child(restored)
	_check(restored.activate_restore_candidate(), "Continue")
	restored.set_process(false)
	await tree.process_frame
	return restored


## TEST-ONLY: away from the fight, by fleeing as often as it takes (as city_npcs_test).
func _finish_fight(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	for opponent_id: StringName in player.relationship.opponent_ids():
		player.relationship.remove_lethal_relation(opponent_id)


func _people(map: WorldMapController) -> Dictionary:
	var found: Dictionary = {}
	for npc: NpcRuntimeState in map.resident_npcs():
		var zone: StringName = npc.world_location().zone_id
		if not found.has(zone):
			found[zone] = {}
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		found[zone][id] = found[zone].get(id, 0) + 1
	return found


## These lines, one after the other, among the last few of the log.
func _said(hud: SharedGameplayUI, lines: Array[String]) -> bool:
	var log: Array[String] = hud.log_lines()
	var at: int = log.rfind(lines[0])
	return at >= 0 and at >= log.size() - 5 and log.slice(at, at + lines.size()) == lines


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("chuenyu: " + message)
