extends RefCounted

## 黑松山 B (d/chuenyu): the 地牢 under 黑松堡 — the main hall's rope drops the player into it
## (asked first, random(10)+5 off eff_kee and kee), nine rooms of one text whose exits do not
## agree (M3: passages on one map), the sunlit 地牢's slab (five pushes, five seconds, shut on
## time). 淳于怀太 falls on whoever comes into the 刑房; 小娟 cries for help three seconds on and
## follows the player who stays twenty (only the player, F4), every way (F2: the maze, the slab,
## the chain, another map, a door; saved where she stands), attacking her asked first (F3).
## 刘老农 thanks the player only with 娟儿 beside them (F1) and both leave for good (Q2 (a)); her
## killer meets his revenge once (killhim(): 悲愤欲绝 until his room resets, M7), then silence.
## Walks use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const XIAOJUAN: StringName = &"chuenyu.npc.xiaojuan2"
const CHUNYU: StringName = &"chuenyu.npc.chuenyu"
const GUARD2: StringName = &"chuenyu.npc.guard2"
const LIU: StringName = &"village.npc.oldliu"
const HENGBING: StringName = &"es2:d/village/npc/obj/hengbing"
const PARRYBOOK: StringName = &"es2:d/village/npc/obj/parrybook"
const SLAB: StringName = &"chuenyu.tunnel4.landmark.rock"
## The LPC's exits, room by room (tunnel1.c … tortureroom2.c).
const EXITS: Dictionary = {
	"tunnel1": {"south": "tunnel5", "north": "tunnel2"},
	"tunnel2": {"east": "tunnel6", "north": "tunnel3", "south": "tunnel1"},
	"tunnel3": {"east": "dungeon", "north": "tunnel5", "south": "tunnel2"},
	"tunnel4": {"north": "tunnel5", "east": "tortureroom", "west": "tortureroom2", "south": "dungeon"},
	"tunnel5": {"north": "tunnel1", "west": "tunnel6", "east": "tortureroom"},
	"tunnel6": {"north": "tortureroom2", "east": "tunnel5"},
	"dungeon": {"west": "tunnel3", "north": "tunnel4"},
	"tortureroom": {"south": "tunnel6", "east": "tunnel4"},
	"tortureroom2": {"south": "tunnel6", "east": "tunnel4"},
}
const PEOPLE: Dictionary = {
	&"chuenyu.tunnel1": {&"chuenyu.npc.highrat": 1},
	&"chuenyu.dungeon": {CHUNYU: 1, XIAOJUAN: 1},
	&"chuenyu.tortureroom": {&"chuenyu.npc.highrat": 2, GUARD2: 2},
	&"chuenyu.tortureroom2": {&"chuenyu.npc.highrat": 2, GUARD2: 2},
}
const THANKS: Array[String] = [
	"刘老农说道：“这位%s，多谢答救小女娟儿。”",
	"刘老农说道：“这口剑，这本密笈赠于%s。”",
	"刘老农说道：“这处非久留之地，我等去也。”",
	"刘老农领着娟儿匆匆离去。",
]
const REVENGE: String = "刘老农悲愤欲绝的骂道：你．．你．．你们居然杀了我女儿，纳命来！"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _new_session(tree)
	await _test_fall(tree, session)
	await _test_maze(tree, session)
	await _test_chunyu(tree, session)
	await _test_xiaojuan(tree, session)
	session = await _test_slab(tree, session)
	await _test_way_home(tree, session)
	session = await _test_thanks(tree, session)
	session.free()
	await tree.process_frame
	session = await _new_session(tree)
	session = await _test_revenge(tree, session)
	await _test_wanderers(tree, session)
	session.free()
	await tree.process_frame
	session = await _new_session(tree)
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for room: String in EXITS:
		var zone: ZoneDefinition = catalog.zone(StringName("chuenyu." + room))
		_check(zone != null and zone.map_id == &"chuenyu.prison" and zone.distinct, "%s: on the 地牢's map, its text shown each time" % room)
		var exits: Dictionary = EXITS[room]
		_check(catalog.room(StringName("es2:d/chuenyu/" + room)).exits().size() == exits.size(), "%s: the LPC's exits" % room)
		for way: String in exits:
			var portal: PortalDefinition = catalog.portal(StringName("chuenyu.%s.%s" % [room, way]))
			_check(portal != null and portal.destination_zone_id == StringName("chuenyu." + exits[way]) and portal.destination_map_id == &"chuenyu.prison", "%s %s leads to %s (M3)" % [room, way, exits[way]])
	for room: StringName in [&"chuenyu.tortureroom", &"chuenyu.tortureroom2"]:
		_check(catalog.zone(room).combat_entry == &"complete_set", "%s: its two 狱卒 together" % room)
	var slab: WorldLandmarkDefinition = catalog.landmark(SLAB)
	_check(slab.policy == &"hidden_passage" and slab.setting("pushes") == 5 and slab.setting("open_seconds") == 5 and slab.setting("closes_on_time") == 1, "the slab: five pushes, five seconds, shut on time")
	_check(slab.portal_ids() == [&"chuenyu.tunnel4.up", &"chuenyu.east_castle.down"] and catalog.portal(&"chuenyu.tunnel4.up").destination_zone_id == &"chuenyu.east_castle", "up to the east clifftop and down again")
	var pull: ServiceDefinition = catalog.service(&"chuenyu.center.pull")
	var fall: ScriptedAct = pull.act.acts[0]
	_check(not fall.ask.is_empty() and fall.choice == "拉绳子" and fall.steps[-1].zone_id == &"chuenyu.tunnel1" and fall.steps[-2].amounts.get("kee") == 5 and fall.steps[-2].randoms.get("kee") == 10, "the rope: asked first, random(10)+5, down into tunnel1")
	var juan: NpcDefinition = catalog.npc(XIAOJUAN)
	var hooks: NpcHooks = juan.hooks()
	_check(hooks.calls.size() == 2 and hooks.calls[0].after == 3.0 and hooks.calls[1].after == 20.0 and hooks.calls[1].act.npc_in == &"chuenyu.dungeon", "小娟: messageing at 3, followhim at 20, in the 刑房")
	_check(hooks.die_marks_killer == "murder" and hooks.follows_every_way and not hooks.attack_ask.is_empty(), "her killer marked, every way (F2), asked first (F3)")
	_check(catalog.spawn(&"chuenyu.prison.dungeon.xiaojuan2").once and not catalog.spawn(&"chuenyu.prison.dungeon.chuenyu").once, "made once (Q2 (a)); 淳于怀太 as any other")
	_check(juan.attitude == NpcDefinition.Attitude.FRIENDLY, "小娟: friendly")
	_check(catalog.npc(CHUNYU).attitude == NpcDefinition.Attitude.KILLER and catalog.npc(CHUNYU).hooks().calls[0].after == 0.0, "淳于怀太: killer, his init() at once")
	_check(catalog.npc(GUARD2).has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE), "狱卒: kill_ob() whoever comes in")
	var grief: NpcMood = catalog.npc(LIU).hooks().moods.get("grief")
	_check(grief != null and grief.title == "悲愤欲绝" and grief.applies.get("damage") == 250 and grief.flags == [NpcDefinition.FLAG_HUNTS_PLAYER] and grief.talk != null and grief.talk.chat_chance == 15, "刘老农's 悲愤欲绝: apply/damage 250, his hatred, chat 15")
	_check(catalog.item(HENGBING).weapon_definition() != null and catalog.item(HENGBING).weapon_damage == 70 and catalog.item(HENGBING).value == 50000, "銮鱼衡冰: a sword of 70, worth 5 gold")


## center.c roping(): the rope, asked first; down into tunnel1, eff_kee and kee random(10)+5 less.
func _test_fall(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(session.handoff_to(&"chuenyu.main", &"chuenyu.croad1", &"chuenyu.croad1", &"chuenyu.croad1.village_arrival").succeeded(), "on 黑松山")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == &"chuenyu.npc.guard":
			map.npcs.vanish(npc) # TEST-ONLY: the 护院 out of the way
	_check(map.place_player(&"chuenyu.center", MapPlaces.zone_centre(map, &"chuenyu.center")), "TEST-ONLY: in the main hall")
	await tree.physics_frame
	var pull: ActService = map.service(&"chuenyu.center.pull") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"chuenyu.center.pull")) and pull.in_reach() and pull.verb() == "拉", "绳子 · 拉")
	pull.interact()
	await tree.physics_frame
	_check(hud.is_asking() and hud.confirm_prompt.confirm_button.text == "拉绳子" and hud.confirm_prompt.message.text.contains("地牢"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"chuenyu.center", "取消: still in the hall")
	var kee: CharacterResourceState = player.state.vitality
	kee.maximum = 5000 # TEST-ONLY: tough
	kee.effective = 5000
	kee.current = 5000
	pull.interact()
	await tree.physics_frame
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == &"chuenyu.prison" and player.world_location().zone_id == &"chuenyu.tunnel1", "fallen into the 地牢: %s" % player.world_location().zone_id)
	var hurt: int = 5000 - kee.current
	_check(hurt >= 5 and hurt <= 14 and kee.effective == kee.current, "random(10)+5 off eff_kee and kee: %d" % hurt)
	_check(_said(hud, ["你试着拉了一下绳子，触动了翻板，整个人“轰隆”一声掉了下去！", "你“轰隆”一声，从上面掉了下来！摔得你好痛！"]), "the trapdoor's lines: %s" % [hud.log_lines().slice(-4)])
	_check(_people(session.active_map() as WorldMapController) == PEOPLE, "who the rooms put where: %s" % [_people(session.active_map() as WorldMapController)])


## The maze (M3): every way off a room takes its LPC exit; north from tunnel1 twice, then east.
func _test_maze(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel1.north") and player.world_location().zone_id == &"chuenyu.tunnel2", "north: tunnel2")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel2.south") and player.world_location().zone_id == &"chuenyu.tunnel1", "south: back in tunnel1")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel1.south") and player.world_location().zone_id == &"chuenyu.tunnel5", "south from tunnel1: tunnel5")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel5.north") and player.world_location().zone_id == &"chuenyu.tunnel1", "north from tunnel5: tunnel1 again")
	_check(session.shared_ui().log_lines().has("你来到地牢。"), "你来到地牢。")
	_check(Work.capture(session) != null, "Save in the 地牢")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel1.north") and await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel2.north"), "north twice: tunnel3")


## chuenyu.c init(): 呔！你竟敢坏大爷的好事！ and kill_ob() at once.
func _test_chunyu(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel3.east") and player.world_location().zone_id == &"chuenyu.dungeon", "east: the 刑房")
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(0.1)
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.LETHAL, "淳于怀太 attacks at once")
	_check(session.shared_ui().log_lines().has("淳于怀太喝道：呔！你竟敢坏大爷的好事！"), "呔！你竟敢坏大爷的好事！: %s" % [session.shared_ui().log_lines().slice(-3)])
	var chunyu: NpcRuntimeState = _npc(map, CHUNYU)
	_check(chunyu != null and chunyu.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER), "kill_ob(): his hatred")
	_finish_fight(session)
	if chunyu != null:
		map.npcs.vanish(chunyu) # TEST-ONLY: out of the story from here
	await tree.physics_frame


## xiaojuan2.c init(): 救我！ three seconds on; twenty seconds with the player there and she follows
## (marks/老刘); leaving and coming back starts both again (remove_call_out()); 攻击 asks first.
func _test_xiaojuan(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var juan: NpcRuntimeState = _npc(map, XIAOJUAN)
	_check(juan != null and juan.world_location().zone_id == &"chuenyu.dungeon", "小娟 in the 刑房")
	if juan == null:
		return
	# Out and back in: the call_outs start anew.
	_check(await _out_and_back(tree, map), "out to tunnel3 and back")
	map.npc_life._advance_ambience(2.9)
	_check(not hud.log_lines().has("小娟说道：救我！救救我呀！"), "nothing for three seconds")
	map.npc_life._advance_ambience(0.2)
	_check(_said(hud, ["小娟说道：救我！救救我呀！", "小娟竭力挣扎，渐渐从绳索里摆脱出来……。"]), "救我！ and she struggles free: %s" % [hud.log_lines().slice(-3)])
	map.npc_life._advance_ambience(10.0)
	_check(await _out_and_back(tree, map), "out and back after thirteen seconds")
	map.npc_life._advance_ambience(19.0)
	_check(not juan.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and player.state.marks.get("老刘", 0) == 0, "the twenty seconds count from the last arrival")
	map.npc_life._advance_ambience(1.1)
	_check(juan.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and player.state.marks.get("老刘", 0) == 1, "twenty seconds: she follows the player (marks/老刘)")
	# F3: 攻击 asks first; 切磋 she refuses.
	_check(map.select_npc(juan.character_id), "select 小娟")
	hud.actions.attack_context()
	_check(hud.is_asking() and hud.confirm_prompt.confirm_button.text == "确定攻击" and hud.confirm_prompt.message.text.contains("只剩一口气"), "攻击 asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(not session.combat_encounter_coordinator().has_active_encounter() and juan.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "取消: no fight")
	map.selection.selected_target = null
	# She follows through the maze (F2): north into the sunlit 地牢.
	_check(await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.dungeon.north") and player.world_location().zone_id == &"chuenyu.tunnel4", "north: the sunlit 地牢")
	_check(juan.world_location().zone_id == &"chuenyu.tunnel4" and hud.log_lines().has("小娟走了过来。"), "小娟走了过来。 (%s)" % juan.world_location().zone_id)
	# Her room's reset does not call her home while she follows the player (F2).
	session.reset_room("d/chuenyu/dungeon.c")
	_check(juan.world_location().zone_id == &"chuenyu.tunnel4" and juan.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "the 刑房's reset leaves her with the player: %s" % juan.world_location().zone_id)
	# Nor does the player's berserk fall on her (F3: no fight with her the player did not choose).
	var bellicosity: int = player.state.attributes.bellicosity
	var composure: int = player.state.attributes.composure
	player.state.attributes.bellicosity = 400000 # TEST-ONLY: boiling over
	player.state.attributes.composure = 0 # TEST-ONLY
	var rat: NpcRuntimeState = _npc(map, &"chuenyu.npc.highrat")
	_check(rat != null and map.npcs.bring_beside_player(rat), "TEST-ONLY: a rat beside the player")
	map.hostilities.pending_player_berserk = &""
	map.hostilities.player_init([rat])
	_check(rat != null and map.hostilities.pending_player_berserk == rat.character_id, "the berserk falls on a rat")
	map.hostilities.pending_player_berserk = &""
	map.hostilities.player_init([juan])
	_check(map.hostilities.pending_player_berserk.is_empty(), "but never on 小娟")
	player.state.attributes.bellicosity = bellicosity
	player.state.attributes.composure = composure


## tunnel4.c: five pushes open the slab for five seconds, up to the east clifftop; it shuts on
## time with the player above too (east_castle's line). 小娟 comes up with them, onto that map.
func _test_slab(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"chuenyu.tunnel4", map.landmark_areas[SLAB].global_position)), "under the slab")
	_check(map.select_landmark(SLAB) and hud.portal_action_text() == "推", "石板 · 推")
	for push: int in range(4):
		map.traverse_selected_portal()
	_check(not map.is_portal_open(&"chuenyu.tunnel4.up") and hud.log_lines()[-1] == "你试著往上用力推动石板，石板变得越来越松动了....", "four pushes: looser")
	map.traverse_selected_portal()
	_check(map.is_portal_open(&"chuenyu.tunnel4.up") and hud.log_lines()[-1] == "石板终于被推的斜立起来，露出一个向上的缝隙。", "the fifth: a gap upward")
	_check(await MapPlaces.take_passage(tree, map, &"chuenyu.tunnel4.up"), "up through the gap")
	var main: WorldMapController = session.active_map() as WorldMapController
	_check(main.map_id() == &"chuenyu.main" and player.world_location().zone_id == &"chuenyu.east_castle", "the east clifftop: %s" % player.world_location().zone_id)
	var juan: NpcRuntimeState = _npc(main, XIAOJUAN)
	_check(juan != null and juan.world_location().zone_id == &"chuenyu.east_castle" and _npc(map, XIAOJUAN) == null, "小娟 came up with the player, onto the castle's map")
	session.advance_hidden_passages(5.0)
	_check(not main.is_portal_open(&"chuenyu.east_castle.down") and hud.log_lines()[-1] == "石板“轰”的一声又倒了下去，将向下的通道盖住了。", "five seconds: it falls shut with the player above (close_passage())")
	# Saved here, she is here again.
	session = await _continue(tree, session)
	main = session.active_map() as WorldMapController
	juan = _npc(main, XIAOJUAN)
	_check(juan != null and juan.world_location().zone_id == &"chuenyu.east_castle" and juan.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and session.player_runtime().state.marks.get("老刘", 0) == 1, "Continue: 小娟 beside the player on the castle's map, still following")
	_check(_npc(session.world_map_of(&"chuenyu.prison"), XIAOJUAN) == null, "and not in the 地牢")
	return session


## Every way the player goes (F2): walked to the gate and the street, down the chain, along the
## road and off the map to 玉螺湖村, through 刘家's door.
func _test_way_home(tree: SceneTree, session: WorldSessionController) -> void:
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.attributes.personality = 30 # TEST-ONLY: the 家丁's random(per) is 29
	var juan: NpcRuntimeState = _npc(map, XIAOJUAN)
	_check(await _walk(tree, map, [&"chuenyu.gate_castle", &"chuenyu.high_b_mtn", &"chuenyu.rope_bridge"]), "the gate, the west street, the bridge")
	_check(juan.world_location().zone_id == &"chuenyu.rope_bridge", "she walked after the player: %s" % juan.world_location().zone_id)
	var chain: ActService = map.service(&"chuenyu.rope_bridge.climb") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, chain.service_id())) and chain.in_reach(), "by the chain")
	chain.interact()
	await tree.physics_frame
	_check(player.world_location().zone_id == &"chuenyu.base_b_m" and juan.world_location().zone_id == &"chuenyu.base_b_m", "down the chain, and she too (go.c took only exits)")
	map.npc_life._advance_ambience(0.0)
	_check(await _walk(tree, map, [&"chuenyu.sunnyroad", &"chuenyu.croad2", &"chuenyu.croad1"]) and juan.world_location().zone_id == &"chuenyu.croad1", "down the road, she after the player: %s %s" % [juan.world_location().zone_id, session.player_runtime().world_location().zone_id])
	_check(await MapPlaces.take_passage(tree, map, &"chuenyu.croad1.south"), "east onto 玉螺湖村's road")
	var village: WorldMapController = session.active_map() as WorldMapController
	juan = _npc(village, XIAOJUAN)
	_check(village.map_id() == &"village.main" and juan != null and juan.world_location().zone_id == &"village.road1", "on the village's map, she too")
	if juan == null:
		return
	_check(village.place_player(&"village.littlegarden", MapPlaces.zone_centre(village, &"village.littlegarden")) and village.npcs.bring_beside_player(juan), "TEST-ONLY: in 刘家's garden, she beside")
	await tree.physics_frame
	village.npc_life._advance_ambience(0.0)
	_check(await MapPlaces.drive(tree, village, MapPlaces.door_spot(village, &"village.home.door", &"village.littlegarden")) and village.open_door(&"village.home.door"), "open 刘家's door")


## oldliu.c greeting(): with 娟儿 beside the player, his thanks, a new 銮鱼衡冰 and 过招要旨, and
## both leave for good; no reset makes them anew, Continue too.
func _test_thanks(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var village: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var juan: NpcRuntimeState = _npc(village, XIAOJUAN)
	var liu: NpcRuntimeState = _npc(village, LIU)
	if juan == null or liu == null:
		_check(false, "小娟 and 刘老农 on the village's map")
		return session
	_check(await _walk(tree, village, [&"village.home"]), "into 刘家小房")
	_check(juan.world_location().zone_id == &"village.home", "she came in through the door")
	village.npc_life._advance_ambience(1.0)
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	var lines: Array[String] = []
	for line: String in THANKS:
		lines.append(line % respect if line.contains("%s") else line)
	_check(_said(hud, lines), "his thanks: %s" % [hud.log_lines().slice(-5)])
	_check(_carries(session, HENGBING) and _carries(session, PARRYBOOK) and player.state.marks.get("老刘", 0) == 0, "銮鱼衡冰 and 过招要旨 the player's, marks/老刘 gone")
	_check(not juan.exists_in_map and not liu.exists_in_map and juan.has_flag(NpcDefinition.FLAG_GONE) and liu.has_flag(NpcDefinition.FLAG_GONE), "he leads 娟儿 away, both gone")
	session.reset_room("d/village/home.c")
	session.reset_room("d/chuenyu/dungeon.c")
	_check(not liu.exists_in_map and _npc(village, LIU) == liu and not _npc(village, XIAOJUAN).exists_in_map, "刘家's reset does not make him anew (Q2 (a)); she stays gone")
	session = await _continue(tree, session)
	village = session.active_map() as WorldMapController
	_check(_npc(village, LIU) != null and not _npc(village, LIU).exists_in_map and _npc(village, LIU).has_flag(NpcDefinition.FLAG_GONE), "Continue: 刘家 stands empty")
	return session


## Killing 小娟 (asked first) marks her killer; 刘老农 takes his revenge once: 悲愤欲绝, apply/damage
## 250, 銮鱼衡冰 drawn, a fight to the death; it lasts until his room resets (M7); then silence.
func _test_revenge(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var prison: WorldMapController = session.world_map_of(&"chuenyu.prison")
	_check(session.handoff_to_point(&"chuenyu.prison", &"chuenyu.dungeon", GameContent.catalog().zone(&"chuenyu.dungeon").combat_location_id, MapPlaces.spot(prison, &"chuenyu.dungeon", MapPlaces.zone_centre(prison, &"chuenyu.dungeon"))).succeeded(), "TEST-ONLY: in the 刑房")
	prison.npcs.vanish(_npc(prison, CHUNYU)) # TEST-ONLY: 淳于怀太 out of the way
	await tree.physics_frame
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	var juan: NpcRuntimeState = _npc(prison, XIAOJUAN)
	_check(prison.select_npc(juan.character_id), "select 小娟")
	hud.actions.attack_context()
	_check(hud.is_asking(), "asked first")
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 120:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(juan.life_status == CharacterRuntimeLifeStatus.Value.DEAD and player.state.marks.get("murder", 0) == 1, "killed, her killer marked (marks/murder)")
	hud.dismiss_current_panel()
	session.reset_room("d/chuenyu/dungeon.c")
	_check(_npc(prison, XIAOJUAN).life_status == CharacterRuntimeLifeStatus.Value.DEAD, "the 刑房's reset does not make her anew (once)")
	var village: WorldMapController = session.world_map_of(&"village.main")
	_check(session.handoff_to_point(&"village.main", &"village.home", GameContent.catalog().zone(&"village.home").combat_location_id, MapPlaces.spot(village, &"village.home", MapPlaces.zone_centre(village, &"village.home"))).succeeded(), "TEST-ONLY: into 刘家小房")
	await tree.physics_frame
	village.npc_life._advance_ambience(0.0)
	village.npc_life._advance_ambience(1.0)
	var liu: NpcRuntimeState = _npc(village, LIU)
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.LETHAL, "纳命来！ — a fight to the death")
	_check(hud.log_lines().has(REVENGE), "his curse: %s" % [hud.log_lines().slice(-3)])
	_check(liu.short_name().begins_with("悲愤欲绝") and liu.character_state.applies.get("damage", 0) == 250 and liu.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER), "悲愤欲绝: %s, apply/damage 250, his hatred" % liu.short_name())
	var held: EquippedWeaponRef = liu.character_state.equipment.primary_weapon()
	_check(held != null and held.weapon_id == HENGBING, "銮鱼衡冰 in his hand")
	_check(player.state.marks.get("murder", 0) == 0 and player.state.marks.get("老刘", 0) == 0 and player.state.marks.get("老刘报仇", 0) == 1, "marks/murder and 老刘 gone: once")
	_finish_fight(session)
	session = await _continue(tree, session)
	hud = session.shared_ui()
	coordinator = session.combat_encounter_coordinator()
	village = session.active_map() as WorldMapController
	liu = _npc(village, LIU)
	_check(liu.mood() != null and liu.short_name().begins_with("悲愤欲绝") and liu.character_state.applies.get("damage", 0) == 250, "Continue: still 悲愤欲绝")
	session.reset_room("d/village/home.c")
	_check(liu.mood() == null and not liu.short_name().contains("悲愤欲绝") and liu.character_state.applies.get("damage", 0) == 0 and not liu.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER), "his room's reset: the grief is over (M7)")
	village.place_player(&"village.littlegarden", MapPlaces.zone_centre(village, &"village.littlegarden"))
	await tree.physics_frame
	village.npc_life._advance_ambience(0.0)
	village.place_player(&"village.home", MapPlaces.spot(village, &"village.home", MapPlaces.zone_centre(village, &"village.home")))
	await tree.physics_frame
	var before: int = hud.log_lines().size()
	village.npc_life._advance_ambience(0.0)
	village.npc_life._advance_ambience(1.0)
	_check(not coordinator.has_active_encounter() and hud.log_lines().slice(before).filter(func(line: String) -> bool: return line.begins_with("刘老农")).is_empty(), "he no longer asks after her: %s" % [hud.log_lines().slice(before)])
	return session


## random_move() through the maze: a 狱卒 is simply in the room its exit names (no walk leads there).
func _test_wanderers(tree: SceneTree, session: WorldSessionController) -> void:
	var prison: WorldMapController = session.world_map_of(&"chuenyu.prison")
	_check(session.handoff_to(&"chuenyu.prison", &"chuenyu.tunnel1", GameContent.catalog().zone(&"chuenyu.tunnel1").combat_location_id, &"chuenyu.tunnel1.rope_arrival").succeeded(), "TEST-ONLY: back in the 地牢")
	await tree.physics_frame
	var guard: NpcRuntimeState = null
	for npc: NpcRuntimeState in prison.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == GUARD2 and npc.world_location().zone_id == &"chuenyu.tortureroom":
			guard = npc
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: the last exit (east: tunnel4)
	prison.npc_life._advance_ambience(0.0)
	_check(guard != null and prison.npc_life.random_move(guard) and guard.world_location().zone_id == &"chuenyu.tunnel4", "a 狱卒 goes east into tunnel4: %s" % ("" if guard == null else String(guard.world_location().zone_id)))
	var body: WorldCharacterBody2D = null if guard == null else prison.npcs.runtime_body_for_character(guard.character_id)
	_check(body != null and MapPlaces.zone_rect(prison, &"chuenyu.tunnel4").has_point(body.global_position), "its body there too")


## West out of the 刑房 and back in, each arrival noticed.
func _out_and_back(tree: SceneTree, map: WorldMapController) -> bool:
	if not await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.dungeon.west"):
		return false
	map.npc_life._advance_ambience(0.0)
	if not await MapPlaces.take_same_map_passage(tree, map, &"chuenyu.tunnel3.east"):
		return false
	map.npc_life._advance_ambience(0.0)
	return true


## Zone by zone, the NPCs noticing each arrival (their time is driven by hand here) and who
## follows walking after.
func _walk(tree: SceneTree, map: WorldMapController, zone_ids: Array[StringName]) -> bool:
	for zone_id: StringName in zone_ids:
		if not await MapPlaces.drive_to_zone(tree, map, zone_id):
			return false
		map.npc_life._advance_ambience(0.0)
		map.npc_life.npc_walker().advance(2.0)
		await tree.physics_frame
	return true


## The 地牢's people fought: thirty seconds each without a stop (淳于怀太's whip, the 狱卒's
## sword, the rats' bites), then the player walks away.
func _test_fights(tree: SceneTree, session: WorldSessionController) -> void:
	var prison: WorldMapController = session.world_map_of(&"chuenyu.prison")
	_check(session.handoff_to(&"chuenyu.prison", &"chuenyu.tunnel1", GameContent.catalog().zone(&"chuenyu.tunnel1").combat_location_id, &"chuenyu.tunnel1.rope_arrival").succeeded(), "into the 地牢")
	await tree.physics_frame
	var fought: Array[StringName] = []
	for npc: NpcRuntimeState in prison.resident_npcs():
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		if id == XIAOJUAN or fought.has(id):
			continue
		fought.append(id)
		await _fight(tree, session, prison, npc)
	_check(fought.size() == 3, "three kinds fought: %s" % [fought])


func _fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var name: String = npc.definition().display_name
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	_check(map.place_player(npc.world_location().zone_id, MapPlaces.spot(map, npc.world_location().zone_id, map.npc_rest_position(npc.character_id))), "beside %s" % name)
	await tree.physics_frame
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not coordinator.has_active_encounter():
		map.select_npc(npc.character_id)
		CombatEncounterCoordinator.take_aborted_total()
		_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s" % name)
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	_finish_fight(session)
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: away from %s" % name)


func _new_session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


## Save, and Continue from it in a fresh session (the old one freed first: two would share physics).
func _continue(tree: SceneTree, session: WorldSessionController) -> WorldSessionController:
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save")
	if snapshot == null:
		return session
	session.free()
	await tree.process_frame
	var preparation: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	_check(preparation.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS, "Continue prepared: %s %s" % [preparation.path, preparation.detail])
	var restored: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	_check(restored.configure_restore(preparation.preparation), "Continue configured")
	tree.root.add_child(restored)
	_check(restored.activate_restore_candidate(), "Continue")
	restored.set_process(false)
	restored.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY
	await tree.process_frame
	# Where the player stands is noted (the restored room's init() skipped, as in play).
	(restored.active_map() as WorldMapController).npc_life._advance_ambience(0.0)
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


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _carries(session: WorldSessionController, definition_id: StringName) -> bool:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return true
	# Too heavy, it lies at the player's feet.
	return false


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
	return at >= 0 and at >= log.size() - 8 and log.slice(at, at + lines.size()) == lines


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("chuenyu_prison: " + message)
