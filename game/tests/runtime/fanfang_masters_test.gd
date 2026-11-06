extends RefCounted

## 番坊 D (DECISIONS「番坊 D」): the three masters and what hangs on them.
## - 安敦 takes one who saw 冯禄 off (大秦人留下了) into 铁盾会 (family, 铁盾会的弟子), hands his
##   apprentice a round shield; 铁盾剑法 wants that shield on the arm (`learn.requires_armor_type`)
##   and is never taught to 鬼笠馆's men (`learn.forbids_marks`); 早川 refuses one who stood with
##   the 大秦人 (no 一刀 passed).
## - 卢卡 follows once 冯禄 is seen off (跟我走: 郭承's rule, every way, fights beside), 等我 stops him.
## - the fisherman's 水怪 grows worse once the 铜牒 is read.
## - on the 浪人's side 早川 takes one who passed his blow into 鬼笠馆浪人, hands over a 倭刀, teaches
##   鬼笠刀法, which 铁盾会's men never learn.
## - 龙若法王 (master.c's family 日陀罗寺): 剃度 first, then 拜师, then 大乘佛法 taught.
const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const LUCA: StringName = &"native.npc.luca"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var rome: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_shield_guild(tree, rome)
	rome.free()
	await tree.process_frame
	var ronin: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_ghost_hat(tree, ronin)
	ronin.free()
	await tree.process_frame
	var bonze: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_ritola(tree, bonze)
	bonze.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for name: String in ["铁盾会", "鬼笠馆浪人", "日陀罗寺"]:
		_check(catalog.family_named(name) != null, "the family %s" % name)
	var shield: SkillDefinition = catalog.skill(&"shield-sword")
	var blade: SkillDefinition = catalog.skill(&"ghost-hat-sword")
	_check(shield != null and shield.display_name == "铁盾剑法" and shield.learn_requires_armor_type == &"shield" and shield.learn_forbids_marks == ["鬼笠馆的弟子"] and shield.action_set().size() == 7, "铁盾剑法: a shield on the arm, never for 鬼笠馆's men, seven strokes")
	_check(blade != null and blade.display_name == "鬼笠刀法" and blade.learn_requires_armor_type.is_empty() and blade.learn_forbids_marks == ["铁盾会的弟子"] and blade.action_set().size() == 6 and blade.action_set().action_at(5).damage_percent == 110, "鬼笠刀法: never for 铁盾会's men, five strokes and the 一刀")
	var andun: NpcDefinition = catalog.npc(&"native.npc.andun")
	var hayakawa: NpcDefinition = catalog.npc(&"fanfang.npc.ronin_master")
	var lama: NpcDefinition = catalog.npc(&"fanfang.npc.lama_master")
	_check(andun != null and andun.teaching() != null and andun.teaching().f_master and andun.teaching().family_name == "铁盾会" and andun.teaching().apprentice != null and andun.teaching().apprentice.accept_marks == ["铁盾会的弟子"] and andun.teaching().apprentice.checks[0].mark == "大秦人留下了", "安敦: 铁盾会's master, takes one who saw 冯禄 off")
	_check(hayakawa != null and hayakawa.teaching() != null and hayakawa.teaching().family_name == "鬼笠馆浪人" and hayakawa.teaching().family_generation == 11 and hayakawa.teaching().apprentice.checks[0].mark == "过了一刀", "早川: master.c's 鬼笠馆浪人 (11, 宗道), takes one who passed his blow")
	_check(lama != null and lama.teaching() != null and lama.teaching().family_name == "日陀罗寺" and lama.teaching().family_generation == 2 and lama.teaching().apprentice.checks[1].class_id == &"bonze" and lama.teaching().apprentice.answer_after == 2.0, "龙若法王: master.c's 日陀罗寺 (2, 住持), answers in two seconds, takes a 剃度'd bonze")
	var luca: NpcDefinition = catalog.npc(LUCA)
	_check(luca != null and luca.hooks() != null and luca.hooks().follows_every_way and luca.hooks().fights_beside_player and luca.hooks().moods.has("going") and luca.talk().inquiry_topics().has("跟我走"), "卢卡: a companion once asked (跟我走)")
	var shield_item: ItemContentDefinition = catalog.item(&"native:fanfang/round_shield")
	_check(shield_item != null and shield_item.armor_definition() != null and shield_item.armor_definition().armor_type == &"shield", "the 大秦圆盾 is a shield")


## The 大秦人's side: 拜师 at 铁盾会, the shield, 铁盾剑法's two rules, 早川's refusal, 卢卡 following,
## the fisherman.
func _test_shield_guild(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter7_done(session, true, true)
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, &"fanfang.hall", &"fanfang.hall.andun.1")
	await _settle(tree)
	var andun: NpcRuntimeState = await _beside(tree, session, hall, &"fanfang.hall.andun.1", Vector2(-70, 0))
	var teacher: TeacherService = _teacher(hall, andun)
	_check(teacher != null and teacher.takes_apprentices() and teacher.teachable_skills().has(&"shield-sword"), "安敦 teaches 铁盾剑法 and takes apprentices")
	var taken: NpcApprenticeship.Outcome = teacher.request_apprentice()
	await _go_on(tree, ui)
	_check(taken == NpcApprenticeship.Outcome.RECRUITED and state.marks.get("铁盾会的弟子", 0) == 1 and state.family.has_family() and GameContent.catalog().family(state.family.family_id).display_name == "铁盾会" and teacher.last_lines.any(func(line: String) -> bool: return line.contains("盾在前，剑在后")), "拜师: taken into 铁盾会 (铁盾会的弟子): %s %s" % [taken, teacher.last_lines])
	# No shield on the arm: 盾呢？
	var refused: LearnResult = teacher.request_learn(&"shield-sword")
	_check(refused != null and not refused.success and refused.failure_reason == LearnResult.FailureReason.ARMOR_TYPE_MISSING and teacher.last_lines.any(func(line: String) -> bool: return line.contains("盾呢")), "铁盾剑法 without a shield: 盾呢？没盾的剑法不是我们的剑法 — %s" % [teacher.last_lines])
	# His shield, worn.
	_check(hall.ask_selected("盾").any(func(line: String) -> bool: return line.contains("盾不倒，人不倒")) and session.player_held_item_ids().has(&"native:fanfang/round_shield") and state.marks.get("领了圆盾", 0) == 1, "盾: the round shield handed over once")
	_check(hall.ask_selected("盾").any(func(line: String) -> bool: return line.contains("给过你了")), "asked again: 盾给过你了")
	var shield_id: StringName = _carried(session, &"native:fanfang/round_shield")
	session.wear_player_item(shield_id)
	_check(not shield_id.is_empty() and session.player_inventory_rows().any(func(row: PlayerInventoryRowProjection) -> bool: return row.equipment_slot == PlayerInventoryRowProjection.EquipmentSlot.WORN and row.armor_type == &"shield"), "the shield on the arm")
	_full(session.player_runtime())
	var learned: LearnResult = teacher.request_learn(&"shield-sword")
	_check(learned != null and learned.success and state.skills.raw_level(&"shield-sword") >= 1, "铁盾剑法 learned with the shield on: %s" % [teacher.last_lines])
	# 鬼笠馆's man (TEST-ONLY the mark): never.
	state.marks["鬼笠馆的弟子"] = 1
	var forbidden: LearnResult = teacher.request_learn(&"shield-sword")
	_check(forbidden != null and not forbidden.success and forbidden.failure_reason == LearnResult.FailureReason.FORBIDDEN_MARK and teacher.last_lines.any(func(line: String) -> bool: return line.contains("不教鬼笠馆")), "a 鬼笠馆 man is never taught 铁盾剑法: %s" % [teacher.last_lines])
	state.marks.erase("鬼笠馆的弟子")
	# 早川 has no 一刀 for one who stood with the 大秦人: no 拜师 either.
	var temple_yard: WorldMapController = MapPlaces.enter(session, &"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival")
	await _settle(tree)
	var dojo: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.gate_yard")
	_check(dojo != null and await MapPlaces.drive_through(tree, dojo, [&"fanfang.dojo"]), "onto 鬼笠馆's boards")
	var master: NpcRuntimeState = await _beside(tree, session, dojo, &"fanfang.dojo.ronin_master.1", Vector2(-60, 0))
	var hayakawa: TeacherService = _teacher(dojo, master)
	var refused_ronin: NpcApprenticeship.Outcome = hayakawa.request_apprentice()
	_check(refused_ronin == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and hayakawa.last_lines.any(func(line: String) -> bool: return line.contains("一刀都没过")) and not state.marks.has("鬼笠馆的弟子"), "早川: 一刀都没过，拜什么师 — %s" % [hayakawa.last_lines])
	# 卢卡 at the gate: 跟我走, and he follows every way; 等我 stops him.
	ui.dismiss_current_panel()
	var bazaar: WorldMapController = MapPlaces.enter(session, &"fanfang.bazaar_north", &"fanfang.bazaar_north.hall_return")
	await _settle(tree)
	var luca: NpcRuntimeState = await _beside(tree, session, bazaar, &"fanfang.bazaar_north.luca.1", Vector2(0, 60))
	_check(luca != null and bazaar.ask_selected("跟我走").any(func(line: String) -> bool: return line.contains("你去哪儿，我去哪儿")) and state.marks.get("卢卡跟上了", 0) == 1 and luca.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "跟我走: 卢卡 follows")
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east"]), "down the lane")
	var came: bool = false
	for frame: int in 400:
		if luca.world_location().zone_id == &"fanfang.bazaar_east":
			came = true
			break
		session.advance_npc_heartbeat(0.2)
		await tree.physics_frame
	await _settle(tree)
	_check(came, "卢卡 came along into the street (%s, flags %s, player at %s, held %s %s / %s, open %s, fighting %s, exists %s)" % [luca.world_location().zone_id, luca.flags(), session.player_runtime().world_location().zone_id, session.world_time_held(), session._world_time_holds, session._presentation_holds, bazaar.gameplay_open(), luca.relationship.is_fighting(), luca.exists_in_map])
	_check(bazaar.select_npc(luca.character_id) and bazaar.ask_selected("等我").any(func(line: String) -> bool: return line.contains("我在这儿等")) and not luca.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "等我: he waits")
	_check(bazaar.ask_selected("跟我走").any(func(line: String) -> bool: return line.contains("走")) and luca.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "跟我走 again: he follows again")
	# The fisherman after the 铜牒 is read.
	var village: WorldMapController = MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.fisher.1")
	await _settle(tree)
	var fisher: NpcRuntimeState = MapPlaces.npc_at(session, &"village.lakeside.fisher.1")
	var fisher_body: Node2D = null if fisher == null else village.runtime_body_for_character(fisher.character_id)
	_check(fisher != null and fisher_body != null and village.place_player(&"village.lakeside", fisher_body.global_position + Vector2(0, 56)) and village.select_npc(fisher.character_id), "TEST-ONLY: beside the fisherman")
	await _settle(tree)
	_check(fisher != null and village.ask_selected("水怪").any(func(line: String) -> bool: return line.contains("别碰那把剑")), "the fisherman's 水怪 after the 铜牒: 别碰那把剑")
	_check(village.ask_selected("湖").any(func(line: String) -> bool: return line.contains("湖底冷")), "and the lake: 湖底冷")


## The 浪人's side: 拜师 at 鬼笠馆, the 倭刀, 鬼笠刀法, never for 铁盾会's men.
func _test_ghost_hat(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter7_done(session, false, false)
	session.record_journal()
	var temple_yard: WorldMapController = MapPlaces.enter(session, &"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival")
	await _settle(tree)
	var dojo: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.gate_yard")
	_check(dojo != null and await MapPlaces.drive_through(tree, dojo, [&"fanfang.dojo"]), "ronin: onto the boards")
	var master: NpcRuntimeState = await _beside(tree, session, dojo, &"fanfang.dojo.ronin_master.1", Vector2(-60, 0))
	var teacher: TeacherService = _teacher(dojo, master)
	_check(teacher != null and teacher.teachable_skills().has(&"ghost-hat-sword"), "早川 teaches 鬼笠刀法")
	var taken: NpcApprenticeship.Outcome = teacher.request_apprentice()
	await _go_on(tree, ui)
	_check(taken == NpcApprenticeship.Outcome.RECRUITED and state.marks.get("鬼笠馆的弟子", 0) == 1 and GameContent.catalog().family(state.family.family_id).display_name == "鬼笠馆浪人" and teacher.last_lines.any(func(line: String) -> bool: return line.contains("只出一次")), "拜师: taken into 鬼笠馆浪人: %s" % [teacher.last_lines])
	_check(dojo.ask_selected("刀").any(func(line: String) -> bool: return line.contains("你的")) and session.player_held_item_ids().has(&"native:fanfang/katana") and state.marks.get("领了倭刀", 0) == 1, "刀: the 倭刀 handed over")
	_full(session.player_runtime())
	var learned: LearnResult = teacher.request_learn(&"ghost-hat-sword")
	_check(learned != null and learned.success and state.skills.raw_level(&"ghost-hat-sword") >= 1, "鬼笠刀法 learned: %s" % [teacher.last_lines])
	state.marks["铁盾会的弟子"] = 1 # TEST-ONLY
	var forbidden: LearnResult = teacher.request_learn(&"ghost-hat-sword")
	_check(forbidden != null and forbidden.failure_reason == LearnResult.FailureReason.FORBIDDEN_MARK and teacher.last_lines.any(func(line: String) -> bool: return line.contains("用不着刀")), "a 铁盾会 man is never taught 鬼笠刀法: %s" % [teacher.last_lines])
	state.marks.erase("铁盾会的弟子")
	# 卢卡 on the quay has no words for a companion.
	var port: WorldMapController = MapPlaces.enter(session, &"fanfang.dock", &"fanfang.dock.bazaar_return")
	await _settle(tree)
	var luca: NpcRuntimeState = await _beside(tree, session, port, &"fanfang.dock.luca.1", Vector2(0, -60))
	_check(luca != null and port.ask_selected("跟我走").any(func(line: String) -> bool: return line == "卢卡说道：不。" or line.contains("不。")) and not state.marks.has("卢卡跟上了"), "跟我走 on the quay: 不。")


## 日陀罗寺: 剃度 (master.c, as B placed it), then 拜师 into 龙若法王's family, then 大乘佛法 taught.
func _test_ritola(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter7_done(session, true, true)
	session.record_journal()
	var monastery: WorldMapController = MapPlaces.enter(session, &"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival")
	await _settle(tree)
	var lama: NpcRuntimeState = await _beside(tree, session, monastery, &"fanfang.temple_yard.lama_master.1", Vector2(-60, 0))
	var teacher: TeacherService = _teacher(monastery, lama)
	# master.c: answered two seconds later (call_out("do_recruit", 2)), a bonze only.
	var early: NpcApprenticeship.Outcome = teacher.request_apprentice()
	_check(early == NpcApprenticeship.Outcome.ANSWER_DUE, "拜师: 龙若法王 answers in a moment (%s)" % early)
	var meanwhile: NpcApprenticeship.Outcome = teacher.request_apprentice()
	_check(meanwhile in [NpcApprenticeship.Outcome.MASTER_BUSY, NpcApprenticeship.Outcome.ANSWER_DUE, NpcApprenticeship.Outcome.PENDING], "asked again meanwhile: the answer still due (%s: %s)" % [meanwhile, teacher.last_lines])
	await _answer(tree, session)
	_check(not state.family.has_family() and ui.log_lines().any(func(line: String) -> bool: return line.contains("剃度出家")), "拜师 before 剃度: 请先到小寺剃度出家 — %s" % [ui.log_lines().slice(-3)])
	_check(monastery.ask_selected("剃度").any(func(line: String) -> bool: return line.contains("跪下")) and session.player_runtime().temp_marks.get("pending/join_bonze", 0) == 1, "剃度: 请跪下受戒")
	var knelt: Array[String] = monastery.kneel_selected()
	_check(knelt.any(func(line: String) -> bool: return line.contains("法名")) and state.affiliation.class_id == &"bonze", "knelt: a 法名, a bonze now")
	var again: NpcApprenticeship.Outcome = teacher.request_apprentice()
	_check(again == NpcApprenticeship.Outcome.ANSWER_DUE, "asked again, a bonze now (%s: %s)" % [again, teacher.last_lines])
	await _answer(tree, session)
	await _go_on(tree, ui)
	_check(state.family.has_family() and GameContent.catalog().family(state.family.family_id).display_name == "日陀罗寺" and ui.log_lines().any(func(line: String) -> bool: return line.contains("善哉")), "拜师: taken into 日陀罗寺 (善哉！善哉！): %s" % [ui.log_lines().slice(-3)])
	_full(session.player_runtime())
	var learned: LearnResult = teacher.request_learn(&"buddhism")
	_check(learned != null and learned.success and state.skills.raw_level(&"buddhism") >= 1, "大乘佛法 taught: %s" % [teacher.last_lines])


## The 拜师 card (前两小时 A) read and put away: 继续.
func _go_on(tree: SceneTree, ui: SharedGameplayUI) -> void:
	await _settle(tree)
	if ui.life_overlay.card_shown():
		ui.life_overlay.go_on()
		await _settle(tree)


## master.c's call_out("do_recruit", 2): the answer comes with the world's seconds.
func _answer(tree: SceneTree, session: WorldSessionController) -> void:
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _teacher(map: WorldMapController, npc: NpcRuntimeState) -> TeacherService:
	for service: WorldService in map.service_nodes:
		if service is TeacherService and npc != null and (service as TeacherService).npc.character_id == npc.character_id:
			return service as TeacherService
	return null


func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, point_id: StringName, offset: Vector2) -> NpcRuntimeState:
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point_id)
	var body: Node2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	_check(npc != null and body != null and await MapPlaces.drive(tree, map, MapPlaces.spot(map, npc.world_location().zone_id, body.global_position + offset, 64.0)) and map.select_npc(npc.character_id), "beside %s" % point_id)
	await _settle(tree)
	return npc


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = maxi(player.state.progression.combat_experience, 200000) # TEST-ONLY: a seventh-chapter character's


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return &""
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
