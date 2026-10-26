extends RefCounted

## 京师 (d/city, u/cp): fifty-five rooms on twelve maps — the 北驿道 south of 玉螺湖村's 三叉路口, the
## city's streets inside its walls, each building and 尚书府 on a map of its own (the remap), the
## 太白酒楼's upper floor, the 院墙 and the 地下密室. The
## guards of the five shut gates turn everyone back (guard.c do_out(): with no token, and anyway
## there is no way out); the 店小二 lets only one with marks/酒楼 up (go_up()), which a tip of ten
## taels gives, and a smaller one lands on the floor (owner, 京师 plan); the bank is no_fight;
## signs and notices read word for word. 尚书府 and the city's secrets: city_shangshu_test.gd.
## Walks use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
## Since the remap every building is its own map, entered by its door from the streets'.
const MAPS: Dictionary = {
	&"city.main": 33, &"city.bank_house": 1, &"city.weapon_house": 1, &"city.biaoju_house": 1, &"city.cloth_house": 1,
	&"city.jiulou_house": 1, &"city.boots_house": 1, &"city.house1_house": 1, &"city.upstairs": 1, &"city.shangshu": 12,
	&"city.wall_top": 1, &"city.cellar": 1,
}
const GUARD: StringName = &"city.npc.guard"
const WAITER: StringName = &"city.npc.waiter"
const GATES: Array[StringName] = [&"city.eastdoor1", &"city.eastdoor2", &"city.westdoor1", &"city.westdoor2", &"city.southdoor"]
## Where each kind stands (the rooms' set("objects")).
const PEOPLE: Dictionary = {
	&"city.nroad2": {&"common.npc.chater2": 1},
	&"city.northdoor": {GUARD: 3},
	&"city.bank": {&"city.npc.microsof": 1},
	&"city.weapon": {&"city.npc.weaponor": 1},
	&"city.westdoor1": {GUARD: 3},
	&"city.street8": {&"snow.npc.scavenger": 1},
	&"city.street9": {&"snow.npc.scavenger": 1},
	&"city.eastdoor1": {GUARD: 3},
	&"city.biaoju": {&"city.npc.chen": 1},
	&"city.cloth": {&"city.npc.clother": 1},
	&"city.jiulou": {WAITER: 1, &"city.npc.boss": 1},
	&"city.street2": {&"city.npc.walker": 2},
	&"city.street4": {&"city.npc.walker": 1, &"city.npc.trader": 1},
	&"city.boots": {&"city.npc.shoer": 1},
	&"city.westdoor2": {GUARD: 3},
	&"city.street13": {&"snow.npc.scavenger": 1},
	&"city.bridge": {&"city.npc.vendor": 1, &"city.npc.caker": 1, &"city.npc.dumpling_seller": 1},
	&"city.eastdoor2": {GUARD: 3},
	&"city.street17": {&"snow.npc.scavenger": 1},
	&"city.southdoor": {GUARD: 3},
	&"city.shangshu.gate": {&"city.npc.shangshu.guard": 1},
	&"city.shangshu.keting": {&"city.npc.shangshu.shangshu": 1},
	&"city.shangshu.road1": {&"city.npc.shangshu.huyuan": 1},
	&"city.shangshu.road2": {&"city.npc.shangshu.huyuan": 1, &"city.npc.shangshu.huyuan1": 1},
	&"city.shangshu.chufang": {&"city.npc.shangshu.maid": 1},
	&"city.shangshu.huayuan": {&"city.npc.shangshu.gardener": 1},
	&"city.shangshu.neizhai": {&"city.npc.shangshu.qing_chen": 1},
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
	await _test_city(tree, session)
	await _test_gates(tree, session)
	await _test_bank(tree, session)
	await _test_jiulou(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("city."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "fifty-five rooms on the streets', each building's and 尚书府's own (the remap), the upper floor's, the wall's and the cellar's maps: %s" % maps)
	_check(catalog.region(&"city").display_name == "京师", "the region is 京师")
	_check(catalog.room(&"es2:d/city/bank").no_fight, "the 旺金钱庄 is no_fight")
	_check(catalog.landmark(&"city.eastdoor2.landmark.notice").description == "布告上写著：辑拿要犯----於兰天武。\n", "the 东二门's notice: 於兰天武")
	_check(catalog.landmark(&"city.southdoor.landmark.notice").description == "告示上写著：今年文武大选。\n", "the 南门's notice, as a non-wizard reads it")
	_check(catalog.landmark(&"city.cloth.landmark.sign").description == "匾上三个大字：闯名堂\n", "四喜绸缎庄's sign: 闯名堂")
	var up: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"city.jiulou", &"city.jiulou_2")
	_check(up.size() == 1 and up[0].mark == "酒楼" and up[0].present_npc_id == WAITER, "the stairs: marks/酒楼 while the 店小二 stands there")
	var leaver := ZoneExitRuleDefinition.Leaver.new()
	_check(up[0].refuses(leaver, true) and not up[0].refuses(leaver, false), "without the mark: refused only with the 店小二 there")
	leaver.marks["酒楼"] = 1
	_check(not up[0].refuses(leaver, true), "with the mark: up")
	for gate: StringName in GATES:
		var out: ServiceDefinition = catalog.service(StringName(String(gate) + ".out"))
		_check(out != null and out.kind == &"act", "%s: 城门 · 出城" % gate)
	_check(catalog.service(&"city.northdoor.out") == null, "the 北门 has no 出城: the road north is the way out (默认)")
	var strike: SkillDefinition = catalog.skill(&"bloodystrike")
	_check(strike != null and strike.display_name == "密宗大手印", "密宗大手印 (the 商人's; city_npcs_test fights with it)")
	_check(catalog.skill(&"iron-cloth") != null and catalog.skill(&"iron-cloth").display_name == "铁布衫", "铁布衫 (nothing reads its absorb lines)")


## The 三叉路口's way south onto the 北驿道, and back.
func _test_way_in(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"village.main", &"village.road2", &"village.road2", &"village.road2.city_return").succeeded(), "on the 三叉路口")
	await tree.physics_frame
	var village: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, village, &"village.road2.south"), "south from the 三叉路口")
	var map: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(map.map_id() == &"city.main" and location.zone_id == &"city.nroad2", "the 北驿道: %s" % location.zone_id)
	_check(session.place_name(location) == "京师 · 北驿道", "京师 · 北驿道: %s" % session.place_name(location))
	_check(Work.capture(session) != null, "Save on the 北驿道")
	_check(await MapPlaces.take_passage(tree, map, &"city.nroad2.north"), "north back to the village")
	_check(session.active_map_id() == &"village.main" and session.player_runtime().world_location().zone_id == &"village.road2", "the 三叉路口")
	village = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, village, &"village.road2.south"), "and south again")


## Who stands where; down the 驿道 through the 北门 to the 十字路口.
func _test_city(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var found: Dictionary = {}
	var people: Array[NpcRuntimeState] = []
	for map_id: StringName in MAPS:
		people.append_array(session.world_map_of(map_id).resident_npcs())
	for npc: NpcRuntimeState in people:
		var zone: StringName = npc.world_location().zone_id
		if not found.has(zone):
			found[zone] = {}
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		found[zone][id] = found[zone].get(id, 0) + 1
	_check(found == PEOPLE, "the people where the rooms put them (the buildings' on their own maps): %s" % [found])
	_check(await MapPlaces.drive_through(tree, map, [&"city.nroad1", &"city.northdoor", &"city.street16", &"city.street7"]), "down the 驿道, through the 北门, 大栅栏 to the 十字路口")
	_check(session.player_runtime().world_location().zone_id == &"city.street7", "at the 十字路口")
	_check(Work.capture(session) != null, "Save at the 十字路口")
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.street16") and await MapPlaces.drive_to_zone(tree, map, &"city.northdoor"), "back up to the 北门")
	_check(map.select_landmark(&"city.northdoor.landmark.sign"), "the 北门's notices")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("模糊不可分辨"), "names nobody can read (a non-wizard): %s" % hud.inspection_text.text.left(30))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame


## guard.c do_out() in the five shut gates; the guards' 出城 and their refusal of a gift.
func _test_gates(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	for gate: StringName in GATES:
		_check((session.active_map() as WorldMapController).place_player(gate, MapPlaces.zone_centre(session.active_map() as WorldMapController, gate)), "TEST-ONLY: in %s" % gate)
		await tree.physics_frame
		var map: WorldMapController = session.active_map() as WorldMapController
		var out: ActService = map.service(StringName(String(gate) + ".out")) as ActService
		_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, out.service_id())) and out.in_reach() and out.verb() == "出城", "%s: 城门 · 出城" % gate)
		out.interact()
		await tree.physics_frame
		_check(_said(hud, ["京师守城兵说道：没有官府通令，任何人不能出入京师。", "出城方向的路被京师守城兵挡住了。"]), "%s: the guards turn the player back: %s" % [gate, hud.log_lines().slice(-3)])
		_check(player.world_location().zone_id == gate, "still in %s" % gate)
	var map: WorldMapController = session.active_map() as WorldMapController
	var out: ActService = map.service(&"city.southdoor.out") as ActService
	# TEST-ONLY: the token's mark (a guard given the 出城令牌: city_shangshu_test): no out exit all the same.
	player.state.marks["令牌"] = 1
	out.interact()
	await tree.physics_frame
	# Among the last lines: the gate's room text may come in the same frame, after it.
	_check(_said(hud, ["这个方向没有出路。"]), "with marks/令牌: 这个方向没有出路。 %s" % [hud.log_lines().slice(-3)])
	player.state.marks.erase("令牌")
	# Guards lying unconscious stop nobody (默认): there is still no way out.
	var guards: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == GUARD and npc.world_location().zone_id == &"city.southdoor":
			guards.append(npc)
			npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	var refused: int = hud.log_lines().count("这个方向没有出路。")
	out.interact()
	await tree.physics_frame
	# As above, the gate's room text may follow in the same frame.
	_check(guards.size() == 3 and hud.log_lines().count("这个方向没有出路。") > refused and hud.log_lines().slice(-3).has("这个方向没有出路。"),
		"the guards down: 这个方向没有出路。 %s" % [hud.log_lines().slice(-3)])
	for npc: NpcRuntimeState in guards:
		npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY
	_check(Array(GameContent.catalog().npc(GUARD).talk().answer("出城")) == ["你可以在京城里找一找，说不定可以找到一些出城的令牌。\n"], "出城: look for a token in the city")
	var guard: NpcRuntimeState = guards[0]
	_check(map.select_npc(guard.character_id), "a guard")
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 10, &"000-test-city-guard-coin") # TEST-ONLY
	var given: ItemHandlingResult = map.give_to_selected(&"000-test-city-guard-coin")
	_check(given.outcome == ItemHandlingResult.Outcome.REFUSED and given.lines == ["京师守城兵说道：这是什么东西啊！你想偷渡呀？", "京师守城兵没有收下。"], "你想偷渡呀？ and the coins stay: %s" % [given.lines])


## 旺金钱庄: convert, no fighting, and its sign.
func _test_bank(tree: SceneTree, session: WorldSessionController) -> void:
	_check((session.active_map() as WorldMapController).place_player(&"city.street8", MapPlaces.zone_centre(session.active_map() as WorldMapController, &"city.street8")), "TEST-ONLY: on 护国道 by the bank")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.take_passage(tree, map, &"city.street8.north"), "north through the bank's door")
	map = session.active_map() as WorldMapController
	await tree.physics_frame # The arrival's zone Areas report a frame later.
	_check(map.map_id() == &"city.bank_house" and session.player_runtime().world_location().zone_id == &"city.bank", "into the 旺金钱庄 (its own map)")
	var counter: WorldService = map.service(&"city.bank.counter")
	_check(counter != null and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"city.bank.counter")) and counter.in_reach(), "钱庄 · 兑换")
	var boss: NpcRuntimeState = _npc(map, &"city.npc.microsof")
	_check(boss != null and map.select_npc(boss.character_id), "黑你没商量")
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED and hud.log_lines()[-1] == "这里不准战斗。", "no fighting in the bank: %s" % hud.log_lines()[-1])
	_check(map.select_landmark(&"city.bank.landmark.sign"), "the sign")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("兑换钱币，自点数目"), "convert: 自点数目: %s" % hud.inspection_text.text.left(40))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame


## 太白酒楼: 钱掌柜's rude greeting, the 店小二's stairs (go_up()) and his tips.
func _test_jiulou(tree: SceneTree, session: WorldSessionController) -> void:
	_check(await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, &"city.bank.south") and session.active_map_id() == &"city.main", "out of the bank by its door")
	await tree.physics_frame
	var map: WorldMapController = MapPlaces.enter(session, &"city.street5", &"city.street5.jiulou_return")
	_check(map != null and map.map_id() == &"city.main", "TEST-ONLY: on the 西街")
	await tree.physics_frame
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.take_passage(tree, map, &"city.street5.west"), "west through the 酒楼's door")
	map = session.active_map() as WorldMapController
	await tree.physics_frame # The arrival's zone Areas report a frame later.
	_check(map.map_id() == &"city.jiulou_house" and player.world_location().zone_id == &"city.jiulou", "into the 太白酒楼 (its own map)")
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(1.0)
	_check(hud.log_lines().has("钱千万皱了皱眉，说:这里是可不是为你们开的，吃完了快走。"), "钱千万: 吃完了快走 (no player has a rank): %s" % [hud.log_lines().slice(-3)])
	_check(not await MapPlaces.take_passage(tree, map, &"city.jiulou.up", 240), "up the stairs: refused")
	_check(player.world_location().zone_id == &"city.jiulou" and _said(hud, ["店小二对你一白眼:你是谁呀，闯什么闯！", "上楼的路被店小二挡住了。"]), "闯什么闯: %s" % [hud.log_lines().slice(-3)])
	var waiter: NpcRuntimeState = _npc(map, WAITER)
	_check(waiter != null and map.select_npc(waiter.character_id), "the 店小二")
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 5, &"000-test-city-tip-small") # TEST-ONLY
	var small: ItemHandlingResult = map.give_to_selected(&"000-test-city-tip-small")
	_check(small.done() and small.lines.size() == 3 and small.lines[0] == "店小二说道：这点钱，还不够买酒喝。" and small.lines[2].begins_with("店小二丢下"), "five taels: 这点钱 and he drops it: %s" % [small.lines])
	_check(map.floor_items.floor_item_ids().has(&"000-test-city-tip-small") and not player.state.marks.has("酒楼"), "the five taels lie on the floor; no mark")
	_check(map.floor_items.select_floor_item(&"000-test-city-tip-small"), "the silver on the floor")
	await MapPlaces.drive(tree, map, map.floor_items.floor_item_view(&"000-test-city-tip-small").global_position + Vector2(0, 24))
	_check(map.floor_items.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "picked up again")
	_check(map.select_npc(waiter.character_id), "the 店小二 again")
	var cloth_id: StringName = map.floor_items.give_new_item_to_player(&"es2:obj/cloth") # TEST-ONLY
	var thing: ItemHandlingResult = map.give_to_selected(cloth_id)
	_check(thing.done() and thing.lines[0] == "店小二说道：这点钱，还不够买酒喝。" and map.floor_items.floor_item_ids().has(cloth_id), "a 布衣 is worth nothing to him: on the floor too")
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 10, &"000-test-city-tip") # TEST-ONLY
	var tip: ItemHandlingResult = map.give_to_selected(&"000-test-city-tip")
	_check(tip.done() and tip.lines[0] == "店小二说道：谢谢这位客官了。" and player.state.marks.get("酒楼", 0) == 1, "ten taels: 谢谢这位客官了 and marks/酒楼: %s" % [tip.lines])
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 10, &"000-test-city-tip-again") # TEST-ONLY
	var again: ItemHandlingResult = map.give_to_selected(&"000-test-city-tip-again")
	_check(again.done() and again.lines[0] == "店小二说道：真是谢谢你了。", "again: 真是谢谢你了: %s" % [again.lines])
	_check(await MapPlaces.take_passage(tree, map, &"city.jiulou.up"), "up the stairs now")
	var upstairs: WorldMapController = session.active_map() as WorldMapController
	_check(upstairs.map_id() == &"city.upstairs" and player.world_location().zone_id == &"city.jiulou_2", "太白酒楼二楼")
	_check(hud.log_lines().has("店小二高声喊道:你楼上请"), "楼上请: %s" % [hud.log_lines().slice(-4)])
	_check(Work.capture(session) != null, "Save upstairs")
	_check(await MapPlaces.take_passage(tree, upstairs, &"city.jiulou_2.down"), "down again")
	_check(session.active_map_id() == &"city.jiulou_house" and player.world_location().zone_id == &"city.jiulou", "the 茶座 (the 酒楼's own map)")


## These lines, one after the other, among the last few of the log.
func _said(hud: SharedGameplayUI, lines: Array[String]) -> bool:
	var log: Array[String] = hud.log_lines()
	var at: int = log.rfind(lines[0])
	return at >= 0 and at >= log.size() - 5 and log.slice(at, at + lines.size()) == lines


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("city: " + message)
