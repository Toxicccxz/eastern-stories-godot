extends RefCounted

## 京师 B (d/city/shangshu, wall.c, jitan.c, midao1.c, feiyuan.c): 尚书府's thirteen rooms — its gate
## on the city's map, the compound behind the 大铁门 its own map since the remap — and its people —
## the 门房 who lets one in for three taels of gold (less is handed back, M1;
## the leave is spent going in, M3), the three 护院 whose names and skills create() draws and who
## stop anyone on the 小径 (present("trainer")), 庾子建, 庾清尘 behind the 帘子, the 花匠, the 丫鬟,
## the four shut doors; the 院墙 climbed from the 东街 (its own map) and jumped from; the altar's
## button (forward once, backward three times, press: the 地下密室 for three seconds; a press that
## opens nothing clears the turns, M4) and the way up opened from below (owner Q2 (a)); 废园's
## flash and find (random(kar + 30) >= 35) and the 出城令牌 a 守城兵 takes (marks/令牌, owner Q1 (b));
## every kind fought thirty seconds. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const PORTER: StringName = &"city.npc.shangshu.guard"
const TRAINER: StringName = &"city.npc.shangshu.huyuan"
const TRAINER1: StringName = &"city.npc.shangshu.huyuan1"
const GUARD: StringName = &"city.npc.guard"
const TOKEN: StringName = &"es2:d/city/obj/token"
const BUTTON: StringName = &"city.jitan.landmark.button"
const CEILING: StringName = &"city.midao1.landmark.ceiling"
const DOWN: StringName = &"city.jitan.down"
const UP: StringName = &"city.midao1.up"
const GATE_DOOR: StringName = &"city.shangshu.gate.door"
## The way in through the 大铁门 and out again (the door hangs on this pair since the remap).
const GATE_IN: StringName = &"city.shangshu.gate.east"
const GATE_OUT: StringName = &"city.shangshu.yuan.west"
const COMPOUND: StringName = &"city.shangshu"
const ROOMS: Array[String] = ["gate", "yuan", "keting", "road1", "road2", "road3", "road4", "kefang", "xiaowu", "chufang", "huayuan", "neizhai", "feiwu"]
## The kinds fought (the files' set("combat_exp"); the 护院's is drawn).
const KINDS: Array[StringName] = [
	PORTER, TRAINER, TRAINER1, &"city.npc.shangshu.shangshu", &"city.npc.shangshu.gardener",
	&"city.npc.shangshu.qing_chen", &"city.npc.shangshu.maid",
]
const FLASH: String = "突然你眼前似乎有什么东西一闪，然后又消失在草丛中。回去在草丛中找找？"

var _count: int = 0
var _failures: Array[String] = []
var _work: RefCounted = Work.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"city.main", &"city.street3", &"city.street3", &"city.street3.wall_return").succeeded(), "on the 东街 by 尚书府")
	await tree.process_frame
	await _test_trainers(tree, session)
	await _test_porter(tree, session)
	await _test_paths(tree, session)
	await _test_wall(tree, session)
	await _test_altar(tree, session)
	await _test_token(tree, session)
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	_count += _work._count
	_failures.append_array(_work._failures)
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for room: String in ROOMS:
		var zone: ZoneDefinition = catalog.zone(StringName("city.shangshu." + room))
		var map_id: StringName = &"city.main" if room == "gate" else COMPOUND
		_check(zone != null and zone.map_id == map_id and zone.room_ids() == [StringName("es2:d/city/shangshu/" + room)], "尚书府's %s on %s (the gate on the city's map, the compound its own since the remap)" % [room, map_id])
	_check(catalog.zone(&"city.wall").map_id == &"city.wall_top" and catalog.zone(&"city.midao1").map_id == &"city.cellar", "the 院墙 and the 地下密室: maps of their own")
	_check(catalog.zones_adjacent(&"city.street3", &"city.shangshu.gate"), "street3's way east is open")
	_check(catalog.portal(GATE_IN) != null and catalog.portal(GATE_IN).destination_map_id == COMPOUND and catalog.portal(GATE_OUT) != null and catalog.portal(GATE_OUT).destination_map_id == &"city.main", "the gate east into the compound's own map, and back west")
	var doors: Dictionary = {}
	for id: StringName in [GATE_DOOR, &"city.shangshu.road1.door", &"city.shangshu.road2.door", &"city.shangshu.huayuan.door"]:
		var door: DoorDefinition = catalog.door(id)
		_check(door != null and not door.starts_open, "%s starts shut (DOOR_CLOSED)" % id)
		doors[door.display_name] = true
	_check(doors.keys() == ["大铁门", "小木门", "木门", "帘子"], "the four doors: %s" % [doors.keys()])
	var gate: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"city.shangshu.gate", &"city.shangshu.yuan")
	_check(gate.size() == 1 and gate[0].mark == "尚书" and gate[0].present_npc_id == PORTER and gate[0].spends, "the gate: marks/尚书 while the 门房 stands there, spent going in (M3)")
	for to: StringName in [&"city.shangshu.road1", &"city.shangshu.kefang"]:
		var rules: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"city.shangshu.road2", to)
		_check(rules.size() == 1 and rules[0].present_npc_ids == [TRAINER, TRAINER1] and not rules[0].spends, "road2 to %s: either kind of 护院 stops the player" % to)
	_check(catalog.exit_rules_between(&"city.shangshu.road2", &"city.shangshu.yuan").is_empty(), "south is always free (dir != \"south\")")
	var wu_shun: SkillDefinition = catalog.skill(&"wu-shun")
	_check(wu_shun != null and wu_shun.display_name == "小无相功", "小无相功 (the 护院's and 庾子建's force)")
	var trainer: NpcDefinition = catalog.npc(TRAINER)
	_check(trainer.name_pick().size() == 12 * 33 and trainer.name_draws() == [12, 33] and trainer.name_pick()[0] == "赵顺" and trainer.name_pick()[33] == "钱顺", "a 护院's name: first_name[random(12)] + name_word[random(33)]")
	_check(catalog.npc(NpcDefinition.named_id(TRAINER, 395)) != null and catalog.npc(NpcDefinition.named_id(TRAINER, 395)).display_name == "林寿", "each name a form of its own (林寿 the last)")
	var token: ItemContentDefinition = catalog.item(TOKEN)
	_check(token != null and token.display_name == "出城令牌" and token.aliases().has("token"), "the 出城令牌")
	_check(catalog.landmark(BUTTON).policy == &"dial" and catalog.landmark(BUTTON).combination == {"forward": 1, "backward": 3}, "the altar's button: forward once, backward three times")
	_check(catalog.opener_below(BUTTON) == catalog.landmark(CEILING), "the 地下密室's ceiling opens it from below (Q2 (a))")
	_check(catalog.landmark(&"city.shangshu.kefang.landmark.book").description == "一本诗词集，上面圈圈点点了一些句子.\n", "the guest room's book of poems")


## Each 护院 draws its name, attributes, power, chances and skills in create()'s order, and
## keeps them through Save and Continue.
func _test_trainers(tree: SceneTree, session: WorldSessionController) -> void:
	# The 护院 stand in the compound, its own map since the remap (the player on the 东街).
	var map: WorldMapController = session.world_map_of(COMPOUND)
	var kept: Dictionary = {}
	var kinds: Dictionary = {}
	for npc: NpcRuntimeState in map.resident_npcs():
		var kind: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		if kind not in [TRAINER, TRAINER1]:
			continue
		kinds[kind] = kinds.get(kind, 0) + 1
		var state: CharacterState = npc.character_state
		var name: String = npc.definition().display_name
		_check(GameContent.catalog().npc(kind).name_pick().has(name) and npc.definition().title == "尚书府护院", "%s: a drawn name, 尚书府护院" % name)
		_check(state.attributes.strength in range(20, 35) and state.attributes.intelligence in range(20, 35) and state.attributes.courage in range(20, 55) and state.attributes.constitution in range(20, 30), "%s: str, int, cor, con drawn" % name)
		_check(state.recovery.inner_force.current in range(400, 800) and state.recovery.inner_force.maximum in range(400, 600) and state.attributes.force_factor in range(3, 6), "%s: force, max_force, force_factor drawn" % name)
		_check(state.progression.combat_experience in range(2000, 52000), "%s: combat_exp 2000 + random(50000): %d" % [name, state.progression.combat_experience])
		var force_skill: StringName = &"wu-shun" if kind == TRAINER else &"lotusforce"
		_check(state.skills.raw_level(&"shortsong-blade") >= (40 if kind == TRAINER else 60) and state.skills.raw_level(force_skill) in range(40, 80) and state.skills.mapped_skill(&"force") == force_skill, "%s: shortsong-blade, %s mapped to force" % [name, force_skill])
		if kind == TRAINER:
			_check(npc.chat_chance in range(0, 40) and npc.combat_chat_chance == -1, "%s: chat_chance random(40): %d" % [name, npc.chat_chance])
		else:
			_check(npc.combat_chat_chance in range(0, 40) and npc.chat_chance == -1, "%s: chat_chance_combat random(40): %d" % [name, npc.combat_chat_chance])
		kept[npc.character_id] = [name, state.attributes.strength, state.progression.combat_experience, npc.chat_chance, npc.combat_chat_chance]
	_check(kinds == {TRAINER: 2, TRAINER1: 1}, "three 护院: two that wander, one that heals (%s)" % [kinds])
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded(), "Continue with the 护院: %s" % restored.path)
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "Continue activates")
	var same: int = 0
	for npc: NpcRuntimeState in fresh.world_map_of(COMPOUND).resident_npcs():
		if kept.has(npc.character_id) and kept[npc.character_id] == [npc.definition().display_name, npc.character_state.attributes.strength, npc.character_state.progression.combat_experience, npc.chat_chance, npc.combat_chat_chance]:
			same += 1
	_check(same == 3, "Continue: each 护院 keeps what create() drew (%d)" % same)
	_check(GameSaveJsonCodec.encode(Work.capture(fresh)).text == encoded.text, "Save again: the same file")
	fresh.free()
	await tree.process_frame


## gate.c and the 门房: three taels of gold let one in once.
func _test_porter(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.gate"), "east from the 东街 to 尚书府's gate")
	_check(hud.log_lines().has("你来到尚书府大门。门上悬挂着一块很大的黑色牌匾，上面用隶") or session.place_name(player.world_location()) == "京师 · 尚书府大门", "尚书府大门: %s" % session.place_name(player.world_location()))
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, GATE_DOOR, &"city.shangshu.gate")) and map.open_door(GATE_DOOR), "the 大铁门 opens")
	_check(not await MapPlaces.take_passage(tree, map, GATE_IN, 240) and session.active_map_id() == &"city.main" and player.world_location().zone_id == &"city.shangshu.gate", "no way in without the 门房's leave")
	_check(hud.log_lines().has("门房伸手拦住了你的去路，喝道：闯什么闯！"), "闯什么闯: %s" % [hud.log_lines().slice(-3)])
	var porter: NpcRuntimeState = _npc(map, PORTER)
	_check(porter != null and map.select_npc(porter.character_id), "the 门房")
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.GOLD, 2, &"000-test-shangshu-gold-small") # TEST-ONLY
	var small: ItemHandlingResult = map.give_to_selected(&"000-test-shangshu-gold-small")
	_check(small.outcome == ItemHandlingResult.Outcome.REFUSED and small.lines == ["鼻子里哼了一声，头掉了过去。", "门房没有收下。"], "two taels of gold: he turns his head and hands them back (M1): %s" % [small.lines])
	_check(_carries(session, &"000-test-shangshu-gold-small") and not player.state.marks.has("尚书"), "the gold is still the player's; no leave")
	Finance.add_money(money, CurrencyDenomination.Value.GOLD, 3, &"000-test-shangshu-gold") # TEST-ONLY
	var paid: ItemHandlingResult = map.give_to_selected(&"000-test-shangshu-gold")
	_check(paid.done() and paid.lines[0] == "门房说道：这位大人，里面请！" and player.state.marks.get("尚书", 0) == 1, "three taels: 这位大人，里面请！ and marks/尚书: %s" % [paid.lines])
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 1, &"000-test-shangshu-silver") # TEST-ONLY
	var more: ItemHandlingResult = map.give_to_selected(&"000-test-shangshu-silver")
	_check(more.done() and more.lines[0] == "门房说道：大人太客气了", "with the leave, anything: 大人太客气了 (kept, as ES2)")
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.street3") and await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.gate"), "west to the 东街 and back")
	_check(player.state.marks.has("尚书"), "walking away west keeps the leave (M3)")
	_check(await MapPlaces.take_passage(tree, map, GATE_IN), "in through the 大铁门")
	var compound: WorldMapController = session.active_map() as WorldMapController
	await tree.physics_frame # The arrival's zone Areas report a frame later.
	_check(compound.map_id() == COMPOUND and player.world_location().zone_id == &"city.shangshu.yuan", "to the 庭院 (the compound's own map)")
	_check(compound.door(GATE_DOOR) != null and compound.door(GATE_DOOR).is_open(), "the 大铁门 stands open inside too (one door on both maps)")
	_check(not player.state.marks.has("尚书"), "the leave is spent going in")
	_check(await MapPlaces.take_passage(tree, compound, GATE_OUT), "back out through the 大铁门")
	await tree.physics_frame
	_check(session.active_map_id() == &"city.main" and player.world_location().zone_id == &"city.shangshu.gate", "back out to the gate")
	_check(not await MapPlaces.take_passage(tree, map, GATE_IN, 240) and session.active_map_id() == &"city.main" and player.world_location().zone_id == &"city.shangshu.gate", "and not in again without a new leave")
	porter.set_exists_in_map(false) # TEST-ONLY: the 门房 gone
	_check(await MapPlaces.take_passage(tree, map, GATE_IN) and session.active_map_id() == COMPOUND, "with the 门房 gone, the way is free")
	await tree.physics_frame
	porter.set_exists_in_map(true) # TEST-ONLY
	_check(Work.capture(session) != null, "Save in the 庭院 (the 大铁门 open)")


## road2.c: a 护院 on the 小径 lets nobody north or east (the leave was spent at the gate).
func _test_paths(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.road2"), "north from the 庭院 onto the 小径")
	_check(not await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.road1") and player.world_location().zone_id == &"city.shangshu.road2", "not north past the 护院")
	_check(hud.log_lines().has("护院伸手拦住了你的去路，喝道：闯什么闯！"), "护院: 闯什么闯")
	player.state.marks["尚书"] = 1 # TEST-ONLY: the leave the 门房 spent (road2.c asks for it)
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.road1"), "with marks/尚书: north")
	player.state.marks.erase("尚书")
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.road2"), "south again: always free")
	var trainers: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) in [TRAINER, TRAINER1] and npc.world_location().zone_id == &"city.shangshu.road2":
			trainers.append(npc)
	_check(trainers.size() == 2, "two 护院 on the 小径, one of each kind")
	trainers[0].set_exists_in_map(false) # TEST-ONLY: one gone
	trainers[1].set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: the other lying there
	_check(not await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.road1"), "a 护院 lying unconscious there stops the player too (present())")
	for npc: NpcRuntimeState in trainers:
		npc.set_exists_in_map(false) # TEST-ONLY: both gone
	var door: StringName = &"city.shangshu.road2.door"
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, door, &"city.shangshu.road2")) and map.open_door(door), "the 木门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.kefang"), "with no 护院 there: east into the guest room")
	_check(map.select_landmark(&"city.shangshu.kefang.landmark.book"), "the books on the desk")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("一本诗词集"), "a book of poems: %s" % hud.inspection_text.text.left(20))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	for npc: NpcRuntimeState in trainers:
		npc.set_exists_in_map(true) # TEST-ONLY
		npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.road2") and await MapPlaces.drive_through(tree, map, [&"city.shangshu.yuan", &"city.shangshu.road3", &"city.shangshu.huayuan"]), "south through the garden path to the 花园")
	var curtain: StringName = &"city.shangshu.huayuan.door"
	_check(not await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.neizhai"), "the 帘子 is drawn")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, curtain, &"city.shangshu.huayuan")) and map.open_door(curtain), "the 帘子 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.shangshu.neizhai") and _npc(map, &"city.npc.shangshu.qing_chen").world_location().zone_id == &"city.shangshu.neizhai", "庾清尘 in the 内宅")
	_check(await MapPlaces.drive_through(tree, map, [&"city.shangshu.huayuan", &"city.shangshu.road4", &"city.shangshu.feiwu"]), "west along the wall to the 废屋")


## street3.c's climb and wall.c's jumps: no 轻功 asked (as ES2).
func _test_wall(tree: SceneTree, session: WorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	# From the 废屋 in the compound (its own map) back onto the city's.
	var map: WorldMapController = MapPlaces.enter(session, &"city.street3", &"city.street3.wall_return")
	_check(map != null and map.map_id() == &"city.main" and map.place_player(&"city.street3", MapPlaces.zone_centre(map, &"city.street3")), "TEST-ONLY: on the 东街")
	await tree.physics_frame
	_check(map.select_landmark(&"city.street3.landmark.wall"), "the 院墙")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("轻功好的人爬上"), "a high wall: %s" % hud.inspection_text.text.left(20))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"city.street3", _landmark_at(map, &"city.street3.landmark.wall") + Vector2(0, -24), 40.0)), "under the wall")
	_check(map.select_landmark(&"city.street3.landmark.wall") and hud.portal_action_text() == "爬上去", "院墙 · 爬上去")
	map.traverse_selected_portal()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == &"city.wall_top" and player.world_location().zone_id == &"city.wall", "on top of the 院墙")
	_check(Work.capture(session) != null, "Save on the wall")
	var top: WorldMapController = session.active_map() as WorldMapController
	var jump_in: ActService = top.service(&"city.wall.jump_in") as ActService
	var jump_out: ActService = top.service(&"city.wall.jump_out") as ActService
	_check(jump_in != null and jump_out != null and jump_in.in_reach() and jump_out.in_reach() and jump_in.verb() == "跳进去" and jump_out.verb() == "跳回去", "尚书府 · 跳进去 and 京师东街 · 跳回去")
	jump_out.interact()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == &"city.main" and player.world_location().zone_id == &"city.street3", "jump out: back on the 东街")
	map = session.active_map() as WorldMapController
	_check(map.select_landmark(&"city.street3.landmark.wall"), "the wall again")
	map.traverse_selected_portal()
	await tree.physics_frame
	await tree.physics_frame
	top = session.active_map() as WorldMapController
	(top.service(&"city.wall.jump_in") as ActService).interact()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == COMPOUND and player.world_location().zone_id == &"city.shangshu.feiwu", "jump in: the 废屋, past the 门房 (the compound's own map)")
	_check(Work.capture(session) != null, "Save in the 废屋")


## jitan.c's button and the 地下密室 (owner Q2 (a): its stairs open from below too).
func _test_altar(tree: SceneTree, session: WorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var passages: WorldHiddenPassages = session.hidden_passages()
	# From the 废屋 in the compound (its own map) onto the city's, by the altar.
	var map: WorldMapController = MapPlaces.enter(session, &"city.jitan", &"city.jitan.stairs_return")
	_check(map != null and map.map_id() == &"city.main" and map.place_player(&"city.jitan", MapPlaces.spot(map, &"city.jitan", _landmark_at(map, BUTTON) + Vector2(0, 40), 40.0)), "TEST-ONLY: by the altar")
	await tree.physics_frame
	await tree.physics_frame
	_check(map.select_landmark(&"city.jitan.landmark.altar") and map.select_landmark(&"city.jitan.landmark.platform") and map.select_landmark(BUTTON), "祭坛, 台子 and 凸起 in reach")
	hud.nearby.refresh()
	_check(hud.nearby.actions_of("凸起") == ["查看", "顺时针转", "逆时针转", "按下"], "the button's buttons: %s" % [hud.nearby.actions_of("凸起")])
	_check(not map.is_portal_open(DOWN) and not session.world_map_of(&"city.cellar").is_portal_open(UP), "the floor is shut")
	map.traverse_selected_portal("forward")
	_check(hud.log_lines()[-1] == "你将按钮沿顺时针转了一圈，什么事情也没发生。", "顺时针转: %s" % hud.log_lines()[-1])
	map.traverse_selected_portal("backward")
	_check(hud.log_lines().slice(-2) == ["你将按钮沿逆时针转了一圈，什么事情也没发生。", "你忽然打了个冷颤，可能是心里害怕了。"] or hud.log_lines()[-1] == "你将按钮沿逆时针转了一圈，什么事情也没发生。\n你忽然打了个冷颤，可能是心里害怕了。", "逆时针转: %s" % [hud.log_lines().slice(-2)])
	_check(passages.state(BUTTON).turns() == {"forward": 1, "backward": 1}, "counted: %s" % [passages.state(BUTTON).turns()])
	var before: int = hud.log_lines().size()
	map.traverse_selected_portal()
	_check(not map.is_portal_open(DOWN) and passages.state(BUTTON).turns().is_empty() and hud.log_lines().size() == before, "a press too soon opens nothing, says nothing, and clears the turns (M4)")
	map.traverse_selected_portal("forward")
	map.traverse_selected_portal("backward")
	map.traverse_selected_portal("backward")
	session.reset_room("d/city/jitan.c")
	_check(passages.state(BUTTON).turns().is_empty(), "the room's reset() clears the turns")
	map.traverse_selected_portal("forward")
	for _turn: int in range(3):
		map.traverse_selected_portal("backward")
	map.traverse_selected_portal()
	_check(map.is_portal_open(DOWN) and session.world_map_of(&"city.cellar").is_portal_open(UP), "forward once, backward three times, press: the way down and the way up")
	_check(hud.log_lines()[-1] == "地板忽然发出轧轧的声音，一块地面缓缓移动著，露出一个向下的阶梯。", "the floor moves: %s" % hud.log_lines()[-1])
	_check(await MapPlaces.take_passage(tree, map, DOWN), "down the steps")
	_check(session.active_map_id() == &"city.cellar" and player.world_location().zone_id == &"city.midao1", "the 地下密室")
	var cellar: WorldMapController = session.active_map() as WorldMapController
	session.advance_hidden_passages(3.0)
	_check(not passages.state(BUTTON).is_open and not cellar.is_portal_open(UP), "three seconds on, the stairs fold up, the player below or not")
	_check(hud.log_lines().has("天花板忽然发出轧轧的声音，向上的阶梯又缓缓地收了回去。"), "the room below sees it: %s" % [hud.log_lines().slice(-2)])
	await _work.round_trip(tree, session, Work.capture(session), "京师 B below")
	await _test_continue_below(tree, session)
	_check(cellar.select_landmark(CEILING) and hud.portal_action_text() == "推开", "天花板 · 推开")
	cellar.traverse_selected_portal()
	_check(cellar.is_portal_open(UP) and map.is_portal_open(DOWN) and hud.log_lines()[-1] == "天花板忽然发出轧轧的声音，露出一个向上的阶梯。", "opened from below: %s" % hud.log_lines()[-1])
	_check(await MapPlaces.take_passage(tree, cellar, UP), "up the steps")
	_check(session.active_map_id() == &"city.main" and player.world_location().zone_id == &"city.jitan", "back at the altar")
	session.advance_hidden_passages(3.0)
	_check(not map.is_portal_open(DOWN) and hud.log_lines().has("地板忽然发出轧轧的声音，一块地面缓缓移动著，将向下的通道盖住了。"), "the floor shuts over the way down")


## Continue in the 地下密室: the way up stays shut (unlike Snow's, 4C), and the 天花板 opens it.
func _test_continue_below(tree: SceneTree, session: WorldSessionController) -> void:
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(Work.capture(session))
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded(), "Continue below: %s" % restored.path)
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "Continue below activates")
	await tree.physics_frame
	await tree.physics_frame
	var below: WorldMapController = fresh.world_map_of(&"city.cellar")
	_check(not fresh.hidden_passages().state(BUTTON).is_open and not below.is_portal_open(UP), "Continue below: the way up is shut")
	_check(below.select_landmark(CEILING), "the 天花板 after Continue")
	below.traverse_selected_portal()
	_check(fresh.hidden_passages().state(BUTTON).is_open and below.is_portal_open(UP), "Continue below: the 天花板 opens it")
	fresh.free()
	await tree.process_frame


## feiyuan.c: the flash on the way out, the find, and the 出城令牌 a 守城兵 takes.
func _test_token(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(map.place_player(&"city.feiyuan", MapPlaces.zone_centre(map, &"city.feiyuan")), "TEST-ONLY: in the 废园")
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.street6") and hud.log_lines().has(FLASH), "leaving south: something flashes in the grass")
	_check(await MapPlaces.drive_to_zone(tree, map, &"city.feiyuan"), "back into the 废园")
	var find: ActService = map.service(&"city.feiyuan.find") as ActService
	_check(find != null and find.verb() == "寻找" and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"city.feiyuan.find")) and find.in_reach(), "草丛 · 寻找")
	var kar: int = player.state.attributes.karma
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	var source := ScriptedWorldInteractionRandomSource.new([34]) # TEST-ONLY: random(kar + 30) comes up 34
	session.configure_world_interaction_random_source(source)
	find.interact()
	_check(source.requested_bounds() == [kar + 30] and hud.log_lines()[-1] == "白忙了半天，一无所获。", "34: nothing (random(%d)): %s" % [kar + 30, hud.log_lines()[-1]])
	source = ScriptedWorldInteractionRandomSource.new([35]) # TEST-ONLY: 35
	session.configure_world_interaction_random_source(source)
	find.interact()
	var token: StringName = _carried_of(session, TOKEN)
	_check(not token.is_empty() and hud.log_lines()[-1] == "你竟找到了一个出城令。", "35: an 出城令牌: %s" % hud.log_lines()[-1])
	source = ScriptedWorldInteractionRandomSource.new([39]) # TEST-ONLY
	session.configure_world_interaction_random_source(source)
	find.interact()
	_check(source.call_count() == 0 and hud.log_lines()[-1] == "忙活了半天，没有什么新的发现。", "with one already: nothing new, no roll")
	session.configure_world_interaction_random_source(original)
	_check(Work.capture(session) != null, "Save with the token")
	_check(map.place_player(&"city.eastdoor1", MapPlaces.zone_centre(map, &"city.eastdoor1")), "TEST-ONLY: at the 东一门")
	await tree.physics_frame
	var guard: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == GUARD and npc.world_location().zone_id == &"city.eastdoor1":
			guard = npc
	_check(guard != null and map.select_npc(guard.character_id), "a 守城兵")
	var given: ItemHandlingResult = map.give_to_selected(token)
	_check(given.done() and given.lines[0] == "京师守城兵连忙说道：原来是官府中人，您请出城。" and player.state.marks.get("令牌", 0) == 1, "the token: 原来是官府中人 and marks/令牌: %s" % [given.lines])
	_check(_carried_of(session, TOKEN).is_empty() and not session.inventory_state().registered_item_ids().has(token), "the token is gone (destruct())")
	var out: ActService = map.service(&"city.eastdoor1.out") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"city.eastdoor1.out")) and out.in_reach(), "城门 · 出城")
	out.interact()
	await tree.physics_frame
	_check(hud.log_lines()[-1] == "这个方向没有出路。", "the gate is shut all the same: %s" % hud.log_lines()[-1])


## Every kind of 尚书府 fought thirty seconds without the fight stopping.
func _test_fights(tree: SceneTree, session: WorldSessionController) -> void:
	var fought: Array[StringName] = []
	# The 门房 at the gate on the city's map, the rest in the compound (its own map since the remap).
	var people: Array[NpcRuntimeState] = []
	people.append_array(session.world_map_of(&"city.main").resident_npcs())
	people.append_array(session.world_map_of(COMPOUND).resident_npcs())
	for npc: NpcRuntimeState in people:
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		if not KINDS.has(id) or not npc.exists_in_map or fought.has(id) or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		fought.append(id)
		await _fight(tree, session, npc)
	_check(fought.size() == KINDS.size(), "%d kinds fought: %s" % [fought.size(), fought])


func _fight(tree: SceneTree, session: WorldSessionController, npc: NpcRuntimeState) -> void:
	var name: String = npc.definition().display_name
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	# TEST-ONLY placement onto whichever map the NPC stands, then beside it.
	var map: WorldMapController = MapPlaces.enter(session, npc.world_location().zone_id, npc.spawn_point_id)
	_check(map != null, "onto %s's map" % name)
	if map == null:
		return
	await tree.physics_frame
	_check(map.place_player(npc.world_location().zone_id, MapPlaces.spot(map, npc.world_location().zone_id, map.runtime_body_for_character(npc.character_id).global_position + Vector2(0, 40), 60.0)), "beside %s" % name)
	await tree.physics_frame
	await tree.physics_frame
	CombatEncounterCoordinator.take_aborted_total()
	map.select_npc(npc.character_id)
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s: %s" % [name, CombatSliceInitiationResult.Outcome.find_key(started.outcome)])
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: out of the fight with %s" % name)
	session.shared_ui().dismiss_current_panel()
	for opponent_id: StringName in player.relationship.opponent_ids(): # TEST-ONLY: as walking away would
		player.relationship.remove_lethal_relation(opponent_id)
		player.relationship.remove_opponent(opponent_id)
	await tree.physics_frame


## Where a landmark stands on the map (read from the map, so it survives a redraw).
func _landmark_at(map: WorldMapController, landmark_id: StringName) -> Vector2:
	for node: Node in map.find_children("*", "Area2D", true, false):
		if node is WorldLandmarkArea2D and (node as WorldLandmarkArea2D).landmark_id == landmark_id:
			return (node as Node2D).global_position
	return Vector2.INF


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.exists_in_map:
			return npc
	return null


func _carries(session: WorldSessionController, item_id: StringName) -> bool:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)).has(item_id)


## The first thing of `definition_id` the player carries; empty when none.
func _carried_of(session: WorldSessionController, definition_id: StringName) -> StringName:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("city shangshu: " + message)
