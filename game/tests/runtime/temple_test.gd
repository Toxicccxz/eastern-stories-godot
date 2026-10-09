extends RefCounted

## 茅山 A (d/temple): 25 of its 27 rooms on three maps (broom1.c and broom2.c, copies of
## the 藏经楼 no exit leads to, are not placed) and the steps up from Snow's mountain road;
## the NPCs as imported, each taoist calling itself 贫道 (rankd.c by class); road2.c's
## guards on duty, drawn at each reset; the doors (open as create_door() leaves them, the
## rear hall's shut); road2.c's invisible wall, road1.c's moss, book_room1.c's door lines,
## the slab; invocation.c (召护法) for NPCs and its 阴鬼卒. Walks use the move actions
## (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.taoist.taolord"
const SOLDIER: StringName = &"common.npc.heaven_soldier"
const GUARD: StringName = &"common.npc.hell_guard"
const FAMILY: StringName = &"family.maoshan"
const MOUNTAIN: Array[String] = ["sroad", "ladder5", "ladder4", "ladder3", "ladder2", "ladder1", "entrance"]
const GROUNDS: Array[String] = [
	"square", "temple1", "corridor1", "corridor2", "corridor7", "corridor6", "inneryard", "restroom1", "corridor3",
	"corridor5", "corridor4", "restroom2", "temple2", "trainroom", "road1", "road2", "book_room1",
]
const ON_DUTY: Array[StringName] = [&"temple.npc.guard_taoist1", &"temple.npc.guard_taoist2", &"temple.npc.guard_taoist3"]
const ON_DUTY_TOO: Array[StringName] = [&"temple.npc.taoist_guard1", &"temple.npc.taoist_guard2", &"temple.npc.taoist_guard3"]
const MOSS: String = "你一脚踩在青苔上, 不小心滑了一跤, 四脚朝天地摔在地上起不来。"
const WALL: String = "一道无形的墙挡住了门口, 差点把你的鼻子给撞扁了。"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_exit_rules()
	_test_invocation()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_test_guards(session)
	_test_words(session)
	await _test_the_climb(tree, session)
	await _test_grounds(tree, session)
	await _test_library(tree, session)
	await _test_moss(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary[StringName, int] = {}
	for room: String in MOUNTAIN + GROUNDS + ["book_room2"]:
		var room_id := StringName("es2:d/temple/" + room)
		var zone: ZoneDefinition = catalog.zone(StringName("temple." + room))
		_check(catalog.room(room_id) != null and zone != null and zone.room_ids() == [room_id], "%s: a zone of its own" % room)
		if zone != null:
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
	_check(maps == {&"temple.mountain": 7, &"temple.grounds": 17, &"temple.library": 1}, "7 rooms on the climb, 17 inside the gate, the 经楼's upper floor: %s" % maps)
	_check(catalog.room(&"es2:d/temple/broom1") == null and catalog.room(&"es2:d/temple/broom2") == null, "broom1.c and broom2.c: no exit leads in, not placed")
	_check(catalog.room(&"es2:d/temple/ladder3").outdoors and catalog.room(&"es2:d/temple/inneryard").outdoors and not catalog.room(&"es2:d/temple/road1").outdoors, "set(\"outdoors\") as authored: the stairs and the courtyard yes, the mossy path not")
	var spawns: Dictionary[StringName, int] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if String(spawn.zone_id).begins_with("temple."):
			spawns[spawn.npc_definition_id] = spawns.get(spawn.npc_definition_id, 0) + spawn.spawn_point_ids().size()
	var expected: Dictionary[StringName, int] = {
		&"temple.npc.guest": 1, &"temple.npc.little_taoist1": 1, MASTER: 1, &"temple.npc.trainer": 1, &"temple.npc.tfighter": 1,
		&"temple.npc.little_taoist2": 1, &"temple.npc.old_taoist": 1, &"temple.npc.taoist": 1, &"temple.npc.taoist2": 1,
	}
	for id: StringName in ON_DUTY + ON_DUTY_TOO:
		expected[id] = 1
	_check(spawns == expected, "fifteen kinds, the six guards each a spawn of their own: %s" % spawns)
	for id: StringName in ON_DUTY:
		var spawn: NpcSpawnDefinition = catalog.spawn(StringName("temple.grounds.road2." + String(id).get_slice(".", 2)))
		_check(spawn.drawn and spawn.draw_group == &"temple.road2.guard_taoist" and spawn.legacy_source_room_path == "d/temple/road2.c", "%s: drawn with its two others" % id)
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if String(spawn.zone_id).begins_with("temple.") and spawn.npc_definition_id != &"temple.npc.guest":
			_check(catalog.npc(spawn.npc_definition_id).class_id == &"taoist", "%s: set(\"class\", \"taoist\")" % spawn.npc_definition_id)
	_check(catalog.npc(&"temple.npc.guest").class_id.is_empty(), "the pilgrim has no class")
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(master.display_name == "林忌" and master.nickname == "六指真人" and master.teaching().family_name == "茅山派" and master.teaching().family_generation == 5 and master.teaching().f_master, "林忌 六指真人, 茅山派's fifth 天师, an F_MASTER")
	var sword: ItemContentDefinition = catalog.item(&"es2:daemon/class/taoist/sword")
	_check(sword.display_name == "咒剑王禅" and sword.weapon_damage == 44 and sword.weapon_apply == {&"spirituality": 30} and sword.description.contains("「 王 禅 」"), "咒剑王禅 (□ decided): sword 44, spirituality 30")
	var talk: NpcTalk = catalog.npc(&"temple.npc.trainer").talk()
	var casts: Array[StringName] = []
	for entry: Variant in talk.combat_chat_entries():
		if entry is NpcSpecialAction:
			casts.append((entry as NpcSpecialAction).function_id)
	_check(talk.combat_chat_chance == 100 and casts == [&"drainerbolt", &"netherbolt", &"feeblebolt", &"invocation", &"manimate", &"animate"], "僵尸侍者: every beat a cast, two of the six do nothing: %s" % [casts])
	var necromancy: SkillDefinition = catalog.skill(&"necromancy")
	_check(necromancy.cast_functions == [&"drainerbolt", &"feeblebolt", &"netherbolt", &"invocation", &"animate"], "茅山道术 casts the three bolts, 召护法 and animate (refused in a fight; no manimate)")
	var gouyee: SkillDefinition = catalog.skill(&"gouyee")
	_check(gouyee.display_name == "谷衣心法" and gouyee.standard_force_hit and gouyee.can_enable_for(&"force"), "谷衣心法: a force with std/force.c's hit")
	_check(catalog.skill(&"scratching").display_name == "天师剑法" and catalog.skill(&"scratching").can_enable_for(&"sword") and catalog.skill(&"taoism").display_name == "天师正道", "天师剑法 and 天师正道")
	var guard: NpcDefinition = catalog.npc(GUARD)
	_check(guard.name_pick().size() == 12 and guard.name_pick()[0] == "子阴鬼卒" and guard.summoning().color == ColoredLine.HIB, "the 阴鬼卒: a name of the twelve branches, its lines in HIB")
	_check(catalog.door(&"temple.square.door").starts_open and catalog.door(&"temple.corridor7.door").starts_open and not catalog.door(&"temple.corridor5.door").starts_open, "the doors open as create_door() leaves them; the rear hall's DOOR_CLOSED")
	var slab: WorldLandmarkDefinition = catalog.landmark(&"temple.road2.landmark.slab")
	_check(slab.policy == &"look" and slab.description.contains("茅  不"), "the slab: only looked at")
	var east: PortalDefinition = catalog.portal(&"snow.eroad3.east")
	_check(east != null and east.destination_zone_id == &"temple.sroad" and east.legacy_command == "east" and catalog.portal(&"temple.sroad.west").destination_spawn_point_id == &"snow.eroad3.temple_return", "Snow's mountain road east up to 茅山, and back")


func _test_exit_rules() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var wall: ZoneExitRuleDefinition = catalog.exit_rules_between(&"temple.road2", &"temple.book_room1")[0]
	_check(wall.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, &"", &"family.juechen"), false) and not wall.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, &"", FAMILY), false), "the invisible wall stops all but 茅山派")
	_check(wall.lines == [WALL] and wall.pass_lines == ["你推开门走了进去, 顺手把门关了起来。"], "its lines")
	var out: ZoneExitRuleDefinition = catalog.exit_rules_between(&"temple.book_room1", &"temple.road2")[0]
	_check(not out.refuses(ZoneExitRuleDefinition.Leaver.new(), false) and out.pass_lines == ["你拉开门大步走了出去, 随手把门带上。"], "out of the 经楼: only its line")
	for to: StringName in [&"temple.corridor3", &"temple.road2"]:
		var moss: ZoneExitRuleDefinition = catalog.exit_rules_between(&"temple.road1", to)[0]
		var bounds: Array[int] = []
		var draw := func(n: int) -> int:
			bounds.append(n)
			return 2
		_check(moss.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, &"", &"", 20, draw), false) and moss.knocks_out and bounds == [20], "%s: random(kar) 2 < 3 slips" % to)
		_check(not moss.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, &"", &"", 20, func(_n: int) -> int: return 3), false), "3: through")
		_check(moss.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, &"", &"", 0, func(_n: int) -> int: return 99), false), "no kar at all: random(0) is 0, always a slip")
	_check(catalog.exit_rules_between(&"temple.corridor3", &"temple.road1").is_empty(), "on the way in nothing slips (corridor3.c has no valid_leave())")


## invocation.c: 100 mana, 60 sen; random(max_mana) below 200 brings nothing; else
## !random(3) a 天将, the other two a 阴鬼卒.
func _test_invocation() -> void:
	var action := NpcSpecialAction.new(NpcSpecialAction.Kind.CAST, &"", &"invocation")
	var cases: Array = [[[199], [], "199: nothing comes"], [[200, 0], [SOLDIER], "random(3) 0: a 天将"], [[1999, 1], [GUARD], "1: a 阴鬼卒"], [[200, 2], [GUARD], "2: a 阴鬼卒"]]
	for case: Array in cases:
		var pair: Array[SpecialSide] = _pair()
		var draws: Array[int] = []
		draws.assign(case[0])
		var context: SpecialContext = _context(pair, Specials.Pattern.new(draws))
		_check(NpcSpecials.run(action, context) and context.summons == case[1] and context.lines[0].template == "$N喃喃地念了几句咒语。", case[2])
		_check(pair[0].state.recovery.mana.current == 3900 and pair[0].state.spirit.current == 240, "100 mana and 60 sen")
		if case[1].is_empty():
			_check(context.lines[1].template == "但是什麽也没有发生。", "told so")
	var pair: Array[SpecialSide] = _pair()
	pair[0].state.recovery.mana = CharacterInternalResourceState.new(99, 2000)
	var refused: SpecialContext = _context(pair, Specials.Pattern.new())
	_check(not NpcSpecials.run(action, refused) and refused.fail_line.template == "你的法力不够了！", "99 mana: 你的法力不够了！")
	var alone: Array[SpecialSide] = _pair()
	alone[0].relationship.remove_opponent(&"player")
	var outside: SpecialContext = SpecialContext.new(alone[0], [], Specials.Pattern.new().legacy_random, GameContent.catalog())
	_check(not NpcSpecials.run(action, outside) and outside.fail_line.template == "只有战斗中才能召唤天将！", "only in a fight")
	_check(InvocationSpell.new().label == "召护法" and (SpecialFunctions.cast(&"drainerbolt") as BoltSpell).label == "紫光", "each has a name on the battle panel")


## road2.c: when the world is made one of each three stands on duty; a reset draws again
## and the earlier ones stay; a dead one comes back only when it is drawn.
func _test_guards(session: WorldSessionController) -> void:
	var grounds: WorldMapController = session.world_map_of(&"temple.grounds")
	_check(_on_duty(grounds, ON_DUTY).size() == 1 and _on_duty(grounds, ON_DUTY_TOO).size() == 1, "one 清灵/清平/清玄 and one 清风/清音/清云 on duty: %s %s" % [_on_duty(grounds, ON_DUTY), _on_duty(grounds, ON_DUTY_TOO)])
	var before: Array[StringName] = _on_duty(grounds, ON_DUTY) + _on_duty(grounds, ON_DUTY_TOO)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 2, 0, 0])) # TEST-ONLY: guard_taoist1, taoist_guard3
	session.reset_room("d/temple/road2.c")
	var now: Array[StringName] = _on_duty(grounds, ON_DUTY) + _on_duty(grounds, ON_DUTY_TOO)
	_check(now.has(&"temple.npc.guard_taoist1") and now.has(&"temple.npc.taoist_guard3"), "the reset's draw comes: %s" % [now])
	for id: StringName in before:
		_check(now.has(id), "%s stays on duty" % id)
	var dead: NpcRuntimeState = _guard(grounds, &"temple.npc.guard_taoist1")
	dead.character_state.vitality.apply_wound(dead.character_state.vitality.effective + 1) # TEST-ONLY
	dead.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([1, 2])) # TEST-ONLY: guard_taoist2
	session.reset_room("d/temple/road2.c")
	_check(_guard(grounds, &"temple.npc.guard_taoist1") == dead, "清灵 lies dead while another is drawn")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 2])) # TEST-ONLY: guard_taoist1 again
	session.reset_room("d/temple/road2.c")
	var fresh: NpcRuntimeState = _guard(grounds, &"temple.npc.guard_taoist1")
	_check(fresh != dead and fresh.exists_in_map and fresh.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "drawn again: a new 清灵")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new()) # TEST-ONLY


## rankd.c by class: a taoist calls himself 贫道 (npc.c accept_fight()); the pilgrim 在下;
## 老道士 never spars; 僵尸侍者 and 僵尸护法 spar only with 茅山派.
func _test_words(session: WorldSessionController) -> void:
	var grounds: WorldMapController = session.world_map_of(&"temple.grounds")
	var mountain: WorldMapController = session.world_map_of(&"temple.mountain")
	var asker := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 20, &"", &"")
	var boy: NpcSparConsent = NpcSparConsent.decide(_npc(grounds, &"temple.npc.little_taoist2"), asker)
	_check(boy.accepted and boy.npc_self == "贫道" and boy.lines[0].text == "既然$RESPECT赐教，$SELF只好奉陪。", "玄和: 既然…赐教，贫道只好奉陪")
	var guest: NpcSparConsent = NpcSparConsent.decide(_npc(mountain, &"temple.npc.guest"), asker)
	_check(not guest.accepted and guest.npc_self == "在下" and guest.lines[0].text == "$SELF怎麽可能是$RESPECT的对手？", "the pilgrim: 在下怎麽可能是…的对手")
	var old: NpcSparConsent = NpcSparConsent.decide(_npc(grounds, &"temple.npc.old_taoist"), asker)
	_check(not old.accepted and old.lines[0].text == "无量寿佛 ! 贫道年迈力衰, 怎是施主的对手。", "老道士 never spars")
	var respect: Callable = func(id: StringName) -> String:
		var npc: NpcRuntimeState = _npc(grounds if id != &"temple.npc.little_taoist1" else mountain, id)
		return RankWords.query_respect(npc.character_state.gender, npc.age, npc.definition().class_id, npc.definition().rank_respect)
	_check(respect.call(&"temple.npc.taoist") == "道长" and respect.call(&"temple.npc.little_taoist1") == "道兄", "fight.c's 领教…的高招: 道长 for 清虚, 道兄 for the boy 玄真")
	var guard: NpcRuntimeState = _npc(grounds, _on_duty(grounds, ON_DUTY)[0])
	_check(RankWords.query_rude(guard.character_state.gender, guard.age, guard.definition().class_id) == "死牛鼻子", "kill.c's rude word for a taoist: 死牛鼻子")
	for id: StringName in [&"temple.npc.trainer", &"temple.npc.tfighter"]:
		var outsider: NpcSparConsent = NpcSparConsent.decide(_npc(grounds, id), asker)
		_check(not outsider.accepted and outsider.lines[0].text == "茅山派不和别派的人过招。", "%s: not with another family's" % id)
		var brother: NpcSparConsent = NpcSparConsent.decide(_npc(grounds, id), NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 20, &"taoist", FAMILY))
		_check(brother.accepted and brother.lines[0].emote and brother.lines[1].text == "进招吧。", "%s: a 茅山派 brother: nod, 进招吧" % id)


## From Snow's mountain road up the steps, the stairs and through the 山门.
func _test_the_climb(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"snow.outdoor", &"snow.eroad3", &"snow.eroad3", &"snow.eroad3.temple_return").succeeded(), "on Snow's mountain road")
	await tree.physics_frame
	await tree.physics_frame
	var snow: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, snow, &"snow.eroad3.east"), "up the steps")
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(map.map_id() == &"temple.mountain" and player.world_location().zone_id == &"temple.sroad", "on the 青石官道")
	_check(await MapPlaces.drive_through(tree, map, [&"temple.ladder5", &"temple.ladder4", &"temple.ladder3", &"temple.ladder2", &"temple.ladder1", &"temple.entrance"]), "up the quartz stairs to the 山门")
	_check(await MapPlaces.take_passage(tree, map, &"temple.entrance.north"), "through the gate")
	_check(session.active_map().map_id() == &"temple.grounds" and player.world_location().zone_id == &"temple.square", "on the square")


## The open red door into the hall, round the walkways, the shut rear hall.
func _test_grounds(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(map.door(&"temple.square.door").is_open() and not map.door(&"temple.corridor5.door").is_open(), "the hall's door stands open, the rear hall's is shut")
	_check(await MapPlaces.drive_through(tree, map, [&"temple.temple1", &"temple.corridor2", &"temple.corridor6", &"temple.inneryard", &"temple.corridor7", &"temple.restroom1"]), "into the hall, west round the courtyard and into the east guest room")
	_check(player.world_location().zone_id == &"temple.restroom1", "with the old taoist")
	_check(await MapPlaces.drive_through(tree, map, [&"temple.corridor7", &"temple.corridor3", &"temple.corridor5"]), "out and along to the north walkway")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"temple.corridor5.door", &"temple.corridor5")) and map.open_door(&"temple.corridor5.door"), "the red door opens")
	await tree.physics_frame
	_check(await MapPlaces.drive_to_zone(tree, map, &"temple.temple2"), "into the rear hall")
	_check(await MapPlaces.drive_through(tree, map, [&"temple.corridor5", &"temple.corridor4", &"temple.trainroom"]), "and to the training hall")
	_check(player.world_location().zone_id == &"temple.trainroom", "among the wooden dummies")


## road2.c's wall and book_room1.c's door, the ladder up and down.
func _test_library(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	player.state.attributes.karma = 20 # TEST-ONLY
	_check(await MapPlaces.drive_through(tree, map, [&"temple.corridor4", &"temple.corridor5", &"temple.corridor3", &"temple.road1"]), "onto the mossy path")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([3])) # TEST-ONLY: random(kar) 3, no slip
	_check(await MapPlaces.drive_to_zone(tree, map, &"temple.road2"), "round behind the rear hall")
	map.select_landmark(&"temple.road2.landmark.slab")
	map.inspect_selected()
	_check(hud.inspection_text.text.begins_with("石碑\n石碑上写著"), "the slab: " + hud.inspection_text.text)
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	var library: WorldPhysicalZoneArea2D = map.physical_zone(&"temple.book_room1")
	var door: Vector2 = MapPlaces.doorway(map, &"temple.road2", &"temple.book_room1")
	map.runtime_player_body().global_position = Vector2(door.x, map.physical_zone(&"temple.road2").global_rect().position.y - 8) # TEST-ONLY: just past the threshold
	_check(not map.accept_zone_presence(library) and player.world_location().zone_id == &"temple.road2" and hud.log_lines()[-1] == WALL, "not 茅山派: the invisible wall")
	player.state.family = FamilyState.new(FAMILY, 6) # TEST-ONLY
	map.runtime_player_body().global_position = Vector2(door.x, map.physical_zone(&"temple.road2").global_rect().position.y - 8)
	_check(map.accept_zone_presence(library) and player.world_location().zone_id == &"temple.book_room1" and hud.log_lines().has("你推开门走了进去, 顺手把门关了起来。"), "a 茅山派 disciple goes in, the door shut behind")
	_check(await MapPlaces.take_passage(tree, map, &"temple.book_room1.up"), "up the little ladder")
	var upstairs: WorldMapController = session.active_map() as WorldMapController
	hud.describe_arrival()
	_check(upstairs.map_id() == &"temple.library" and hud.log_lines()[-1].begins_with("【经楼】上了楼来"), "upstairs: 张天师's portrait: " + hud.log_lines()[-1])
	_check(await MapPlaces.take_passage(tree, upstairs, &"temple.book_room2.down"), "and down")
	map = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, map, &"temple.road2"), "out of the door")
	_check(hud.log_lines().has("你拉开门大步走了出去, 随手把门带上。"), "pulling it shut behind")


## road1.c: random(kar) below 3 slips: the line, unconcious(), and no way through.
func _test_moss(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_to_zone(tree, map, &"temple.road1"), "back on the mossy path (nothing slips on the way in)")
	var observed := ScriptedWorldInteractionRandomSource.new([2]) # TEST-ONLY: random(kar) 2
	session.configure_world_interaction_random_source(observed)
	var corridor: WorldPhysicalZoneArea2D = map.physical_zone(&"temple.corridor3")
	var edge: float = map.physical_zone(&"temple.road1").global_rect().end.y
	map.runtime_player_body().global_position = Vector2(map.physical_zone(&"temple.road1").global_rect().get_center().x, edge + 8) # TEST-ONLY: just past the edge
	_check(not map.accept_zone_presence(corridor) and player.world_location().zone_id == &"temple.road1", "slipped: still on the path")
	_check(hud.log_lines()[-1] == MOSS, "road1.c's line")
	_check(observed._requested_bounds == [20], "random(kar), kar 20: %s" % [observed._requested_bounds])
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and session.player_life_flow().phase == PlayerLifeFlow.Phase.UNCONSCIOUS, "unconcious(): down at once")
	for _second: int in range(300):
		if player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session._process(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.world_location().zone_id == &"temple.road1", "and wakes where the moss threw them")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([3])) # TEST-ONLY
	map.runtime_player_body().global_position = Vector2(map.physical_zone(&"temple.road1").global_rect().get_center().x, edge + 8)
	_check(map.accept_zone_presence(corridor) and player.world_location().zone_id == &"temple.corridor3", "3: down to the walkway")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new()) # TEST-ONLY


func _on_duty(map: WorldMapController, ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		if ids.has(npc.definition().definition_id) and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			out.append(npc.definition().definition_id)
	return out


func _guard(map: WorldMapController, id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == id:
			return npc
	return null


func _npc(map: WorldMapController, id: StringName) -> NpcRuntimeState:
	return _guard(map, id)


## TEST-ONLY: 林忌's spells (100, 茅山道术 100) with 4000 of 2000 mana and 300 sen,
## fighting a player of 100000 combat_exp.
func _pair() -> Array[SpecialSide]:
	var state := CharacterState.new()
	state.skills.set_raw_level(&"spells", 100)
	state.skills.set_raw_level(&"necromancy", 100)
	state.skills.map_skill(&"spells", &"necromancy")
	state.recovery.mana = CharacterInternalResourceState.new(4000, 2000)
	state.spirit = CharacterResourceState.new(300, 300, 300)
	var master_relationship := CombatRelationshipState.new(&"taolord")
	master_relationship.add_opponent(&"player")
	var player := CharacterState.new()
	player.progression.combat_experience = 100000
	var player_relationship := CombatRelationshipState.new(&"player")
	player_relationship.add_opponent(&"taolord")
	return [
		SpecialSide.new(&"taolord", state, ActionBusyState.new(), master_relationship),
		SpecialSide.new(&"player", player, ActionBusyState.new(), player_relationship),
	]


func _context(pair: Array[SpecialSide], random: CombatRandomSource) -> SpecialContext:
	return SpecialContext.new(pair[0], [pair[1]], random.legacy_random, GameContent.catalog())


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
