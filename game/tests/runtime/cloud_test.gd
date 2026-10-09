extends RefCounted

## 卧龙岗 + 绮云镇 (u/cloud/dragonhill, u/cloud; region plan #3, package 3A): the road
## south from Snow's 雪亭镇街道 over the ridge into the town, its streets and shops. What
## it first needed: a toll the ridge's robbers take (gangster.c), a thief who steals
## silver from whoever comes into the garden (thief.c with cmds/std/steal.c), a
## teacher who takes a keepsake (girl.c), greetings that sometimes say nothing
## (switch(random(4)) with fewer cases), lines shown as written (the say() efun) and
## 春风快意刀 (spring-blade). TEST-ONLY fixtures are marked where used.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const Goathill := preload("res://tests/runtime/goathill_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const ROOMS: Array[String] = [
	"dragonhill/nroad", "dragonhill/nhillfoot", "dragonhill/hummock", "dragonhill/shillfoot", "dragonhill/sroad",
	"entrance", "nwroad1", "butchery", "tearoom", "tea_corridor", "nwroad2", "woodboxy", "god1", "god2", "tailory",
	"nwroad3", "zaihuoy", "nroad1", "drugstore", "weapony", "nroad2", "cross", "wroad2", "monky", "wroad1", "bookstore",
	"wroad0", "marry_room", "sroad1", "dukou", "eroad1", "jiyuan", "duchang", "eroad2", "park", "biaoju", "eroad3",
	"rich", "m_house", "eroad4", "tearoom2", "jiyuan2", "duchang2",
]
const BOOK: StringName = &"es2:u/cloud/obj/literate_book"
const GOLD: StringName = &"es2:obj/money/gold"

var _count: int = 0
var _failures: Array[String] = []
var _goathill: RefCounted = Goathill.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_steal_rolls()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_test_tiles(session)
	await _test_walks(tree, session)
	_test_shops_and_study(session)
	await _test_toll_window(tree, session)
	await _test_toll(tree, session)
	await _test_thief(tree, session)
	_test_keepsake(session)
	await _test_spring_blade(tree, session)
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "in 绮云镇 with the toll paid and the book read")
	_check(work._failures.is_empty(), "Save/Continue: " + str(work._failures))
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.region(&"cloud") != null and catalog.region(&"cloud").display_name == "绮云镇", "the region 绮云镇")
	var missing: Array[String] = []
	for room: String in ROOMS:
		var zone: ZoneDefinition = catalog.zone_of_room(StringName("es2:u/cloud/" + room))
		if catalog.room(StringName("es2:u/cloud/" + room)) == null or zone == null:
			missing.append(room)
	_check(missing.is_empty() and ROOMS.size() == 43, "forty-three rooms, a zone each: missing " + str(missing))
	_check(catalog.zone(&"cloud.dragonhill.hummock").map_id == &"cloud.outdoor" and catalog.zone(&"cloud.tearoom2").map_id == &"cloud.tearoom_upstairs" and catalog.zone(&"cloud.jiyuan2").map_id == &"cloud.jiyuan_upstairs" and catalog.zone(&"cloud.duchang2").map_id == &"cloud.duchang_upstairs", "the ridge and the town's ground floor on one map; each upper floor its own (owner)")
	_check(catalog.zones_adjacent(&"snow.sroad1", &"cloud.dragonhill.nroad"), "Snow's 雪亭镇街道 south to 黄土路")
	_check(catalog.zones_adjacent(&"cloud.dragonhill.shillfoot", &"cloud.entrance") and catalog.zones_adjacent(&"cloud.dragonhill.sroad", &"cloud.entrance") and catalog.zones_adjacent(&"cloud.dragonhill.sroad", &"cloud.dragonhill.shillfoot"), "南坡, the second 黄土路 and the town's entrance all lead to each other")
	_check(catalog.zone(&"cloud.dragonhill.hummock").combat_entry == &"complete_set", "the two robbers on the ridge attack together")
	var counts: Array[int] = []
	for spawn_id: String in ["cloud.outdoor.hummock.gangsters", "cloud.outdoor.butchery.flys", "cloud.outdoor.woodboxy.box_waiters",
			"cloud.outdoor.rich.room_guas", "cloud.outdoor.eroad4.workers", "cloud.outdoor.monky.beggars", "cloud.outdoor.nwroad3.garrisons",
			"cloud.outdoor.biaoju.b_header", "cloud.outdoor.god2.god", "cloud.outdoor.duchang.judge", "cloud.outdoor.marry_room.mei_po",
			"cloud.outdoor.dukou.boater", "cloud.jiyuan_upstairs.jiyuan2.girl"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(StringName(spawn_id))
		counts.append(0 if spawn == null else spawn.quantity)
	_check(counts == [2, 6, 8, 5, 6, 2, 2, 1, 1, 1, 1, 1, 1], "the rooms' objects, the later packages' masters and the boatman included: %s" % [counts])
	_check(catalog.spawn(&"cloud.outdoor.monky.beggars").npc_definition_id == &"snow.npc.beggar", "the 斋院's two beggars are Snow's (d/snow/npc/beggar.c)")
	var spring: SkillDefinition = catalog.skill(&"spring-blade")
	var types: Array[String] = []
	for action: CombatActionDefinition in spring.action_set().actions():
		types.append(String(action.damage_type))
	_check(spring.display_name == "春风快意刀" and types == ["割伤", "割伤", "割伤", "擦伤", "擦伤", "擦伤", "擦伤"], "春风快意刀's seven moves, the source's □伤 as 擦伤: " + str(types))
	var goods: Dictionary[String, Array] = {}
	for vendor_id: String in ["book_seller", "butcher", "doctor", "seller", "tailor", "weaponor"]:
		var vendor: VendorDefinition = catalog.vendor(StringName("cloud.vendor." + vendor_id))
		goods[vendor_id] = vendor.goods_keys()
	_check(goods["weaponor"] == ["whip", "sword", "blade", "dart", "leather shield", "sixhammer", "thin sword", "dagger"] and goods["book_seller"] == ["literate book"] and goods["seller"] == ["rope", "bag", "dust"], "six shops with their goods: " + str(goods))
	var book: ItemContentDefinition = catalog.item(BOOK)
	_check(book.display_name == "说文解字" and book.value == 2000 and book.study.skill_id == &"literate" and book.study.max_skill == 30, "说文解字: 20 silver, study literate up to 30")
	_check(catalog.npc(&"cloud.npc.monk").dealings().is_fight_deferred() and not catalog.npc(&"cloud.npc.god").dealings().is_fight_deferred() and not catalog.npc(&"cloud.npc.jiading").dealings().is_fight_deferred(), "the monk waits for his arts; 朱鸿雪 (雪影剑法 since 晚月庄 A) and the 家丁 (春风快意刀) can be fought")
	_check(catalog.npc(&"cloud.npc.bfighter").talk().has_chat(), "趟子手 shouts and wanders ((:random_move :) without a space)")
	var greet: NpcTalk = catalog.npc(&"cloud.npc.book_seller").talk()
	_check(greet.greeting_choices().size() == 3 and greet.greeting_draws() == 4 and greet.greeting_choices()[1].as_written, "潘若秋 greets with one of three lines out of random(4), as written")
	var room_gua: NpcDefinition = catalog.npc(&"cloud.npc.room_gua")
	_check(room_gua.talk().answer("碧玉刀") == PackedStringArray(["这刀可是个宝物, 据说是当年张家老祖宗退隐时皇上赐的。"]), "the archive's hard wrap inside a string is gone: " + str(room_gua.talk().answer("碧玉刀")))


## steal.c's odds and rolls, scripted.
func _test_steal_rolls() -> void:
	var steal := NpcSteal.new()
	steal.what = &"silver"
	steal.chance_below = 2
	_check(steal.starts(20, ScriptedWorldInteractionRandomSource.new([1])) and not steal.starts(20, ScriptedWorldInteractionRandomSource.new([2])), "thief.c: random(kar) < 2 starts it")
	_check(NpcSteal.thief_odds(35, 20, 0, false) == 215 and NpcSteal.thief_odds(35, 20, 1, true) == 97 and NpcSteal.thief_odds(0, 0, 3, false) == 1, "sp = stealing*5 + kar*2 - thief*20, at least 1, halved in a fight")
	_check(NpcSteal.victim_odds(100, 50, false, false) == 202 and NpcSteal.victim_odds(100, 50, true, true) == 20200, "dp = sen*2 + weight/25, x10 fighting, x10 equipped")
	var random := ScriptedWorldInteractionRandomSource.new([203, 5, 0])
	_check(NpcSteal.resolve(215, 202, true, random) == NpcSteal.Outcome.TAKEN and random.requested_bounds() == [417], "random(sp+dp) > dp takes it")
	NpcSteal.after_taken(215, true, 20, random)
	_check(random.requested_bounds() == [417, 20, 215], "once moved: improve_skill's random(int) and the onlookers' random(sp)")
	_check(NpcSteal.resolve(215, 202, true, ScriptedWorldInteractionRandomSource.new([202, 102])) == NpcSteal.Outcome.UNNOTICED, "failed, random(sp) > dp/2: unnoticed")
	_check(NpcSteal.resolve(215, 202, true, ScriptedWorldInteractionRandomSource.new([10, 101])) == NpcSteal.Outcome.CAUGHT, "failed, random(sp) <= dp/2: caught")
	var asleep := ScriptedWorldInteractionRandomSource.new([])
	_check(NpcSteal.resolve(215, 202, false, asleep) == NpcSteal.Outcome.TAKEN and asleep.call_count() == 0, "from someone not conscious: taken, no roll")


func _test_tiles(session: WorldSessionController) -> void:
	for map_id: StringName in [&"cloud.outdoor", &"cloud.tearoom_upstairs", &"cloud.jiyuan_upstairs", &"cloud.duchang_upstairs"]:
		var map: WorldMapController = session.world_map_of(map_id)
		var layers: Array[TileMapLayer] = TerrainProbe.layers(map)
		var walkable: Dictionary[Vector2i, bool] = {}
		for layer: TileMapLayer in layers:
			for cell: Vector2i in layer.get_used_cells():
				if layer.get_cell_tile_data(cell).get_collision_polygons_count(0) == 0:
					walkable[cell] = true
		# Every way in: the map's entry and each stairs arrival (the upper floors are apart).
		var reached: Dictionary[Vector2i, bool] = {}
		var frontier: Array[Vector2i] = []
		for marker: WorldSpawnMarker2D in map.find_children("*", "WorldSpawnMarker2D", true, false):
			if String(marker.spawn_point_id).ends_with("snow_entry") or String(marker.spawn_point_id).ends_with("stairs_arrival"):
				var start: Vector2i = layers[0].local_to_map(marker.position)
				reached[start] = true
				frontier.append(start)
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if walkable.has(cell + step) and not reached.has(cell + step):
					reached[cell + step] = true
					frontier.append(cell + step)
		var cut_off: Array[StringName] = []
		for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
			var shape: RectangleShape2D = (zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
			var rect := Rect2(zone.position - shape.size / 2.0, shape.size)
			if not reached.keys().any(func(cell: Vector2i) -> bool: return rect.has_point(layers[0].map_to_local(cell))):
				cut_off.append(zone.zone_id)
		_check(cut_off.is_empty(), "every room of %s is joined to a way in on the tiles: cut off %s" % [map_id, cut_off])
		var unplaced: Array[String] = []
		for npc: NpcRuntimeState in map.npc_runtimes():
			var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
			if body == null or not walkable.has(layers[0].local_to_map(body.global_position)):
				unplaced.append(String(npc.spawn_point_id))
		_check(unplaced.is_empty(), "%s's NPCs stand on open ground: %s" % [map_id, unplaced])
	var upstairs: Array[int] = []
	for map_id: StringName in [&"cloud.tearoom_upstairs", &"cloud.jiyuan_upstairs", &"cloud.duchang_upstairs"]:
		upstairs.append(session.world_map_of(map_id).npc_runtimes().size())
	_check(session.world_map_of(&"cloud.outdoor").npc_runtimes().size() == 51 and upstairs == [1, 1, 0], "51 people in the town and on the ridge; upstairs the chess player, 李师师 and nobody: %d, %s" % [session.world_map_of(&"cloud.outdoor").npc_runtimes().size(), upstairs])


## South from Snow, up the tea house's stairs and through its 木雕门, walked.
func _test_walks(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.handoff_to(&"snow.outdoor", &"snow.sroad1", &"snow.sroad1", &"snow.sroad1.cloud_return").succeeded(), "on Snow's 雪亭镇街道")
	await tree.physics_frame
	await _goathill._walk_until_map(tree, session, &"cloud.outdoor", "move_down")
	_check(session.active_map_id() == &"cloud.outdoor" and player.world_location().zone_id == &"cloud.dragonhill.nroad", "south from the street: 黄土路")
	_check(session.shared_ui().log_lines().any(func(line: String) -> bool: return line.begins_with("【黄土路】")), "its room text on arrival")
	await _goathill._walk_until_map(tree, session, &"snow.outdoor", "move_up")
	_check(session.active_map_id() == &"snow.outdoor" and player.world_location().zone_id == &"snow.sroad1", "north again: Snow's street")
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.tearoom", &"cloud.tearoom", &"cloud.tearoom.stairs_return").succeeded(), "in 香茗坊")
	await tree.physics_frame
	await _goathill._walk_until_map(tree, session, &"cloud.tearoom_upstairs", "move_right")
	_check(session.active_map_id() == &"cloud.tearoom_upstairs" and player.world_location().zone_id == &"cloud.tearoom2", "its stairs: 香茗坊二楼")
	await _goathill._walk_until_map(tree, session, &"cloud.outdoor", "move_right")
	_check(session.active_map_id() == &"cloud.outdoor" and player.world_location().zone_id == &"cloud.tearoom", "and down again")
	# The other two upper floors, each its own map with its own stairs.
	for floor: Array in [[&"cloud.jiyuan", &"cloud.jiyuan_upstairs", &"cloud.jiyuan2"], [&"cloud.duchang", &"cloud.duchang_upstairs", &"cloud.duchang2"]]:
		_check(session.world_map_of(&"cloud.outdoor").relocate_player(floor[0], StringName(String(floor[0]) + ".stairs_return")), "in %s, by its stairs" % floor[0])
		await tree.physics_frame
		await _goathill._walk_until_map(tree, session, floor[1], "move_right")
		_check(session.active_map_id() == floor[1] and player.world_location().zone_id == floor[2], "up its stairs: %s" % floor[2])
		await _goathill._walk_until_map(tree, session, &"cloud.outdoor", "move_right")
		_check(session.active_map_id() == &"cloud.outdoor" and player.world_location().zone_id == floor[0], "and down again into %s" % floor[0])
	_check(session.world_map_of(&"cloud.outdoor").relocate_player(&"cloud.tearoom", &"cloud.tearoom.stairs_return"), "back in 香茗坊")
	await tree.physics_frame
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var door_at: Vector2 = map.door(&"cloud.tearoom.door").wall_shape().global_position
	map.runtime_player_body().global_position = door_at + Vector2(0, 56) # TEST-ONLY: by the 木雕门
	await tree.physics_frame
	_check(map.door(&"cloud.tearoom.door") != null and not map.door(&"cloud.tearoom.door").is_open() and map.can_operate_door(&"cloud.tearoom.door"), "the 木雕门 is shut, within reach")
	_check(map.open_door(&"cloud.tearoom.door"), "opened")
	await tree.physics_frame
	await Work.new().walk_to(tree, session, "move_up", door_at.y - 60, 1)
	_check(player.world_location().zone_id == &"cloud.tea_corridor", "through it: 香茗坊茶窖")


func _test_shops_and_study(session: WorldSessionController) -> void:
	var money: MoneyInventoryContext = Finance.session_context(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 50, &"test.cloud.silver") # TEST-ONLY
	var books: VendorDefinition = GameContent.catalog().vendor(&"cloud.vendor.book_seller")
	var bought: VendorPurchaseResult = VendorPurchaseService.buy(books, "literate book", GameContent.catalog(), money,
		session.food_collection(), session.liquid_collection(), session.item_id_allocator(), player.maximum_encumbrance)
	_check(bought.delivered and bought.price == 2000 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == 30, "说文解字 bought for 20 silver")
	var weapons: VendorDefinition = GameContent.catalog().vendor(&"cloud.vendor.weaponor")
	var blade: VendorPurchaseResult = VendorPurchaseService.buy(weapons, "blade", GameContent.catalog(), money,
		session.food_collection(), session.liquid_collection(), session.item_id_allocator(), player.maximum_encumbrance)
	_check(blade.delivered and blade.price == 500, "a 单刀 for 5 silver")
	var dart: VendorPurchaseResult = VendorPurchaseService.buy(weapons, "dart", GameContent.catalog(), money,
		session.food_collection(), session.liquid_collection(), session.item_id_allocator(), player.maximum_encumbrance)
	_check(not dart.delivered, "飞镖 has no value(): buy.c does not sell it")
	var shop: VendorService = session.world_map_of(&"cloud.outdoor").service(&"cloud.outdoor.weapony.weaponor") as VendorService
	_check(shop != null and not shop.sellable_keys().has("dart") and shop.sellable_keys().has("blade") and shop.sellable_keys().size() == 7, "so the shop does not list it (modern fixes): " + str([] if shop == null else shop.sellable_keys()))
	var illiterate: StudyResult = session.martial_arts().study(bought.item_id)
	_check(illiterate != null and illiterate.outcome == StudyResult.Outcome.ILLITERATE, "study.c: an illiterate cannot read even 说文解字")
	player.state.skills.set_raw_level(&"literate", 1) # TEST-ONLY: taught by 魏无极 or 李师师
	var result: StudyResult = session.martial_arts().study(bought.item_id)
	_check(result != null and result.outcome == StudyResult.Outcome.STUDIED and player.state.skills.learned_progress(&"literate") > 0, "研读 说文解字: literate learned from it: %s" % (StudyResult.Outcome.find_key(result.outcome) if result != null else "null"))


## gangster.c init(): call_out("greeting", 1): a robber attacks a player still in the room
## when the time to leave it has passed (2 s in its reach here, toll_attack_delay_ms; the
## ridge takes 1.2-1.5 s to cross). One who walked on meets nobody, and (owner, pacing knobs)
## the robber holds no grudge for it: the way back has the same time.
func _test_toll_window(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var robbers: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"cloud.npc.gangster":
			robbers.append(npc)
	session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad.snow_entry")
	await tree.physics_frame
	var body: CharacterBody2D = map.runtime_player_body()
	var ridge: Rect2 = map.physical_zone(&"cloud.dragonhill.hummock").global_rect()
	var robber_at: Vector2 = map.runtime_body_for_character(robbers[0].character_id).global_position
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var delay: float = robbers[0].definition().dealings().toll_attack_delay_ms / 1000.0
	_check(delay == 2.0, "the robbers wait 2 s: %.1f" % delay)
	# TEST-ONLY: on the ridge, in the first robber's reach only (below him, away from the other).
	body.global_position = robber_at + Vector2(0, 60)
	player.set_world_location(map.location_for_zone(&"cloud.dragonhill.hummock"))
	await tree.physics_frame
	await tree.physics_frame
	map.hostilities.toll_contact_seconds[robbers[0].character_id] = 0.0 # TEST-ONLY: the frames so far
	map._process(delay * 0.5)
	_check(map.hostilities.complete_entry_contact(robbers[0].character_id) and not session.combat_encounter_coordinator().has_active_encounter(), "half the time in his reach: no attack yet")
	# Walk on: out of reach before the time is up.
	body.global_position = Vector2(ridge.get_center().x, ridge.position.y + 12)
	await tree.physics_frame
	await tree.physics_frame
	map._process(delay)
	_check(not session.combat_encounter_coordinator().has_active_encounter() and not map.hostilities.toll_contact_seconds.has(robbers[0].character_id), "walked on: his greeting finds nobody")
	_check(not robbers[0].has_flag(NpcDefinition.FLAG_FOUGHT_PLAYER) and robbers[0].definition().toll_attack_delay_ms(robbers[0].flags(), player.state) == 2000, "no grudge for it (owner): the way back has the same time")
	# Stay: the whole time in his reach and he attacks.
	body.global_position = robber_at + Vector2(0, 60)
	await tree.physics_frame
	await tree.physics_frame
	map.hostilities.toll_contact_seconds[robbers[0].character_id] = 0.0 # TEST-ONLY
	map._process(delay * 0.5)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "still waiting at half the time")
	var said: int = session.shared_ui().log_lines().size()
	map._process(delay * 0.5)
	_check(session.combat_encounter_coordinator().has_active_encounter() and robbers[0].relationship.has_lethal_target(player.character_id), "the whole time in his reach: he attacks (kill_passenger)")
	_check(session.shared_ui().log_lines().slice(said).has("看起来卧龙岗强盗想杀死你！"), "kill_ob()'s warning: " + str(session.shared_ui().log_lines().slice(said)))
	await tree.physics_frame
	_check(robbers[0].has_flag(NpcDefinition.FLAG_FOUGHT_PLAYER) and robbers[0].definition().toll_attack_delay_ms(robbers[0].flags(), player.state) == 0, "having fought, he attacks at once from then on")
	session.combat_encounter_coordinator()._abort_failed_resolution() # TEST-ONLY
	CombatEncounterCoordinator.take_aborted_total()
	robbers[0].set_flag(NpcDefinition.FLAG_FOUGHT_PLAYER, false) # TEST-ONLY
	# Between the two (in both reaches), the first's time up and the second's not yet:
	# both greetings come from the same arrival, so both attack (review on pacing knobs).
	body.global_position = Vector2(ridge.get_center().x, ridge.position.y + 12) # out of reach: a new arrival
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.0)
	body.global_position = (robber_at + map.runtime_body_for_character(robbers[1].character_id).global_position) / 2.0
	await tree.physics_frame
	await tree.physics_frame
	map.hostilities.toll_contact_seconds[robbers[0].character_id] = delay * 0.6 # TEST-ONLY
	map.hostilities.toll_contact_seconds[robbers[1].character_id] = delay * 0.3 # TEST-ONLY
	map._process(delay * 0.45)
	_check(session.combat_encounter_coordinator().has_active_encounter() and robbers[0].relationship.has_lethal_target(player.character_id) and robbers[1].relationship.has_lethal_target(player.character_id), "in both reaches: the second robber joins the first's attack")
	session.combat_encounter_coordinator()._abort_failed_resolution() # TEST-ONLY
	CombatEncounterCoordinator.take_aborted_total()
	await tree.physics_frame
	for robber: NpcRuntimeState in robbers:
		robber.set_flag(NpcDefinition.FLAG_FOUGHT_PLAYER, false) # TEST-ONLY: the toll test starts with fresh robbers
	await tree.physics_frame


## gangster.c: no marks/强盗 and they attack on sight; ten taels of gold set it and let
## the player pass; too little and they attack.
func _test_toll(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var robbers: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"cloud.npc.gangster":
			robbers.append(npc)
	session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nhillfoot", &"cloud.dragonhill.nhillfoot", &"cloud.dragonhill.nroad.snow_entry")
	await tree.physics_frame
	player.set_world_location(map.location_for_zone(&"cloud.dragonhill.hummock")) # TEST-ONLY
	var decision: NpcAggressionDecision = map.aggression_adapter()._evaluate(robbers[0], player, true)
	_check(decision.outcome == NpcAggressionDecision.Outcome.READY, "no marks/强盗: the robber attacks on sight")
	player.state.marks["强盗"] = 1 # TEST-ONLY: paid before
	decision = map.aggression_adapter()._evaluate(robbers[0], player, true)
	_check(decision.outcome == NpcAggressionDecision.Outcome.NOT_AUTHORED, "with the mark: let through")
	player.state.marks.erase("强盗")
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.GOLD, 10, &"test.cloud.gold") # TEST-ONLY
	# TEST-ONLY: just in from 北坡, more than presence_radius 100 from both robbers.
	var ridge: Rect2 = map.physical_zone(&"cloud.dragonhill.hummock").global_rect()
	map.runtime_player_body().global_position = Vector2(ridge.get_center().x, ridge.position.y + 24)
	await tree.physics_frame
	await tree.physics_frame
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "not yet in their reach")
	map.select_npc(robbers[0].character_id)
	var gold: StringName = _carried(session, GOLD)
	var said: int = session.shared_ui().log_lines().size()
	var paid: ItemHandlingResult = map.give_to_selected(gold, 10)
	_check(paid.done() and player.state.marks.get("强盗", 0) == 1, "ten taels of gold (value 100000): marks/强盗")
	_check(session.shared_ui().log_lines().slice(said).has("强盗接过钱，眼睛瞪得大大的，点了点头，说道：大爷今天做个善人，放你条生路。还不快滚！"), "said as written: " + str(session.shared_ui().log_lines()))
	_check(map.aggression_adapter()._evaluate(robbers[1], player, true).outcome == NpcAggressionDecision.Outcome.NOT_AUTHORED, "and the other one lets the player pass too")
	player.state.marks.erase("强盗") # TEST-ONLY
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 1, &"test.cloud.silver2") # TEST-ONLY
	var silver: StringName = _carried(session, &"es2:obj/money/silver")
	said = session.shared_ui().log_lines().size()
	var refused: ItemHandlingResult = map.give_to_selected(silver, 1)
	_check(not refused.done() and session.combat_encounter_coordinator().has_active_encounter() and robbers[0].relationship.has_lethal_target(player.character_id), "one tael: he spits and attacks (kill_passenger)")
	var order: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(order.size() >= 3 and order[0].begins_with("强盗往地上吐了口唾沫") and order[-2] == "看起来卧龙岗强盗想杀死你！" and order[-1] == "卧龙岗强盗没有收下。",
		"his line, kill_ob()'s warning, then the refusal: " + str(order))
	_check(robbers[0].has_flag(NpcDefinition.FLAG_FOUGHT_PLAYER), "and from then on he attacks on sight, mark or not")
	session.combat_encounter_coordinator()._abort_failed_resolution() # TEST-ONLY
	CombatEncounterCoordinator.take_aborted_total()
	player.state.marks["强盗"] = 1
	_check(map.aggression_adapter()._evaluate(robbers[0], player, true).outcome != NpcAggressionDecision.Outcome.NOT_AUTHORED, "the mark no longer helps with him")
	# 切磋 with the other, mark paid: accept_fight() kill_passenger()s, so he too remembers.
	map.select_npc(robbers[1].character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED and robbers[1].has_flag(NpcDefinition.FLAG_FOUGHT_PLAYER), "a 切磋 turned kill marks him as having fought the player (review on 3A)")
	session.combat_encounter_coordinator()._abort_failed_resolution() # TEST-ONLY
	CombatEncounterCoordinator.take_aborted_total()
	await tree.physics_frame


## thief.c in 张家花园: an arrival rolls random(kar) < 2; a second later steal.c picks the
## silver, and three seconds after it rolls. Taken: the silver is his, and the player
## reads that it is gone (modern fixes; ES2 says nothing).
func _test_thief(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var thief: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"cloud.npc.thief":
			thief = npc
	session.handoff_to(&"cloud.outdoor", &"cloud.park", &"cloud.park", &"cloud.dragonhill.nroad.snow_entry")
	await tree.physics_frame
	map.runtime_player_body().global_position = map.physical_zone(&"cloud.park").global_rect().end - Vector2(64, 64) # TEST-ONLY: clear of the pond
	player.set_world_location(map.location_for_zone(&"cloud.park"))
	thief.set_world_location(map.location_for_zone(&"cloud.park")) # TEST-ONLY: he may have wandered
	var silver: StringName = _carried(session, &"es2:obj/money/silver")
	var amount: int = session.stack_collection().stack_state(silver).amount
	session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([0, 0])) # TEST-ONLY
	map.npc_life._advance_ambience(0.0)
	map.npc_life.ambience.cancel_call(thief.character_id)
	map.npc_life.pending_steals.erase(thief.character_id)
	map.npc_life._consider_stealing(thief)
	_check(map.npc_life.ambience.has_call(thief.character_id, NpcAmbience.STEAL), "random(kar) 0 < 2: steal_it in a second")
	map.npc_life.ambience.cancel_call(thief.character_id)
	map.npc_life._steal_step(thief)
	_check(map.npc_life.pending_steals.has(thief.character_id) and map.npc_life.pending_steals[thief.character_id]["item"] == silver, "steal.c picks present(\"silver\")")
	map.npc_life.ambience.cancel_call(thief.character_id)
	var random := ScriptedWorldInteractionRandomSource.new([999999, 0, 0]) # TEST-ONLY: random(sp+dp) > dp
	session.configure_npc_ambience_random_source(random)
	map.npc_life._advance_ambience(0.0)
	var lines: int = session.shared_ui().log_lines().size()
	map.npc_life._steal_step(thief)
	_check(not _carried_ids(session).has(silver) and session.stack_collection().stack_state(silver) != null, "taken: the player's %d silver is gone" % amount)
	_check(random.call_count() == 3 and session.inventory_state().is_direct_child(silver, ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, thief.character_id)), "the thief has it")
	_check(session.shared_ui().log_lines().slice(lines) == ["你忽然觉得身上一轻，银子不见了！"], "the player notices what is gone, not who took it (modern fixes; ES2 says nothing): " + str(session.shared_ui().log_lines().slice(lines)))
	# A thief killed between steal.c's main() and compelete_steal() takes nothing (review on 3A).
	var more: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(more, CurrencyDenomination.Value.SILVER, 3, &"test.cloud.silver3") # TEST-ONLY
	var kept: StringName = _carried(session, &"es2:obj/money/silver")
	map.npc_life.pending_steals[thief.character_id] = {"item": kept, "sp": 1, "dp": 0}
	thief.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY
	session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([999999, 0, 0]))
	map.npc_life._advance_ambience(0.0)
	map.npc_life._steal_step(thief)
	_check(_carried_ids(session).has(kept), "a dead thief finishes no theft")
	thief.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders


## girl.c: money is refused; a keepsake from a man with per >= 25 sets marks/李师师,
## after which she teaches (recognize_apprentice).
func _test_keepsake(session: WorldSessionController) -> void:
	var rules: Array[NpcObjectRule] = GameContent.catalog().npc(&"cloud.npc.girl").dealings().object_rules
	var offer := NpcObjectRule.Offer.new(0, &"", 0, {}, {})
	offer.giver_gender = CharacterState.GENDER_MALE
	offer.giver_per = 25
	_check(NpcObjectRule.decide(rules, offer).mark_giver == "李师师", "a keepsake from a man with per 25: marks/李师师")
	offer.giver_per = 24
	_check(not NpcObjectRule.decide(rules, offer).accept, "per 24: 我对您没兴趣！")
	offer.giver_per = 30
	offer.giver_gender = CharacterState.GENDER_FEMALE
	_check(not NpcObjectRule.decide(rules, offer).accept, "a woman: refused")
	offer.value = 100
	offer.giver_gender = CharacterState.GENDER_MALE
	_check(NpcObjectRule.decide(rules, offer).lines[0].text == "我对钱没兴趣！", "money: 我对钱没兴趣！")
	var recognize: Array = GameContent.catalog().npc(&"cloud.npc.girl").teaching().recognize_rules
	_check(recognize.size() == 2 and recognize[0].giver_mark == "李师师", "she recognizes the keepsake's giver")


## 家丁 fight with 春风快意刀: its moves land and the fight never aborts. TEST-ONLY: a
## player who survives.
func _test_spring_blade(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var guard: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"cloud.npc.jiading":
			guard = npc
	session.handoff_to(&"cloud.outdoor", &"cloud.m_house", &"cloud.m_house", &"cloud.dragonhill.nroad.snow_entry")
	await tree.physics_frame
	map.runtime_player_body().global_position = map.runtime_body_for_character(guard.character_id).global_position + Vector2(0, 46) # TEST-ONLY
	player.set_world_location(map.location_for_zone(&"cloud.m_house"))
	await tree.physics_frame
	var vitality: CharacterResourceState = player.state.vitality
	player.state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY
	map.select_npc(guard.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 家丁")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var text: String = ""
	for _round: int in range(60):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
		text = ui.log_panel._text.get_parsed_text()
		if text.contains("一招「"):
			break
	_check(text.contains("一招「"), "a move of 春风快意刀: " + text.right(200))
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "the fight never aborts")
	if coordinator.has_active_encounter():
		coordinator._abort_failed_resolution() # TEST-ONLY
		CombatEncounterCoordinator.take_aborted_total()
	player.state.vitality = vitality
	await tree.physics_frame


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	for id: StringName in _carried_ids(session):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _carried_ids(session: WorldSessionController) -> Array[StringName]:
	return session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id))


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("cloud: " + label)
