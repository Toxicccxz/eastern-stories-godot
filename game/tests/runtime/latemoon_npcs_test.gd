extends RefCounted

## 晚月庄 A (d/latemoon): its people and what they fight with. The NPCs as imported (ids
## that keep their subdirectory apart, 雨梅's needles, the carried 杀手令牌 not worn), the
## arts (柔虹指, 寒雪鞭法, 雪影剑法 and 心法, 意寒功 with its hit_ob() and 意寒睨), the two
## conditions (rose_poison, iceshock), 蓝止萍's use_poison(), 龙韶吟's hit_ob(), the whips'
## rigidity and the items no_drop keeps. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MASTER: StringName = &"common.npc.dancer.master"
## The maps the fights walk, with where the player stands at first.
const MAPS: Array = [
	[&"latemoon.manor", &"latemoon.entrance", &"latemoon.entrance.cloud_entry"],
	[&"latemoon.secret", &"latemoon.miroom2", &"latemoon.miroom2.flower_arrival"],
	[&"latemoon.garden", &"latemoon.park.yard1", &"latemoon.park.yard1.manor_arrival"],
	[&"latemoon.upper", &"latemoon.upstar.upstar1", &"latemoon.upstar.upstar1.stairs_arrival"],
	[&"latemoon.hills", &"latemoon.sroad1", &"latemoon.sroad1.garden_arrival"],
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_people()
	_test_talk()
	_test_items()
	_test_arts()
	_test_conditions()
	_test_ice_wound()
	_test_chillgaze()
	_test_poison()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## Every kind placed fights to the end without the fight stopping: its arts, weapons,
## dodges and parries are data the fight can run.
func _test_fights(tree: SceneTree, session: WorldSessionController) -> void:
	var fought: Array[StringName] = []
	for entry: Array in MAPS:
		_check(session.handoff_to(entry[0], entry[1], entry[1], entry[2]).succeeded(), "onto %s" % entry[0])
		await tree.process_frame
		var map: WorldMapController = session.active_map() as WorldMapController
		for npc: NpcRuntimeState in map.resident_npcs():
			var id: StringName = npc.definition().definition_id
			if not npc.exists_in_map or fought.has(id):
				continue
			fought.append(id)
			await _fight(tree, session, map, npc)
	_check(fought.size() == 37, "37 kinds fought: %d" % fought.size())


func _fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var name: String = npc.definition().display_name
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	_check(map.relocate_player(npc.world_location().zone_id, npc.spawn_point_id), "beside %s" % name)
	await tree.physics_frame
	map.select_npc(npc.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	CombatEncounterCoordinator.take_aborted_total()
	var room: RoomDefinition = GameContent.catalog().room(GameContent.catalog().zone(npc.world_location().zone_id).room_ids()[0])
	if room.no_fight:
		_check(map.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED and not coordinator.has_active_encounter(), "%s: the 更衣室 is no_fight" % name)
		return
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s" % name)
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: away from %s" % name)


func _test_people() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maid: NpcDefinition = catalog.npc(&"latemoon.npc.servant")
	var rear_maid: NpcDefinition = catalog.npc(&"latemoon.npc.room.servant")
	_check(maid != null and rear_maid != null and maid.legacy_source_path == "d/latemoon/npc/servant.c" and rear_maid.legacy_source_path == "d/latemoon/room/npc/servant.c", "the two 婢女 files keep two ids (their subdirectory)")
	_check(catalog.npc(&"latemoon.npc.park.bird") != null and catalog.npc(&"latemoon.npc.upstar.bird") != null, "the garden's and the tower's 金丝雀 apart")
	var counts: Dictionary[StringName, int] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if String(spawn.zone_id).begins_with("latemoon."):
			counts[spawn.npc_definition_id] = counts.get(spawn.npc_definition_id, 0) + spawn.spawn_point_ids().size()
	var total: int = 0
	for id: StringName in counts:
		total += counts[id]
	_check(counts.size() == 37 and total == 47, "37 kinds, 47 NPCs placed: %d, %d" % [counts.size(), total])
	_check(counts.get(&"cloud.npc.lm_guard", 0) == 2 and counts.get(&"latemoon.npc.park.flwgirl", 0) == 4 and counts.get(MASTER, 0) == 1, "two 彩衣少女 at the arch, four 采花少女, 蓝止萍 in the hall")
	for unplaced: StringName in [&"latemoon.npc.sell", &"latemoon.npc.shaode", &"latemoon.npc.room.fong", &"latemoon.npc.room.jane", &"latemoon.npc.room.tenlon", &"latemoon.npc.room.aaa", &"latemoon.npc.cockroach"]:
		_check(not counts.has(unplaced), "%s: placed by nothing (as LPC)" % unplaced)
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(master.display_name == "蓝止萍" and master.teaching().family_name == "晚月庄" and master.teaching().family_generation == 1 and master.class_id == &"dancer", "蓝止萍, 晚月庄主, a dancer")
	var founder: NpcDefinition = catalog.npc(&"latemoon.npc.room.elon")
	_check(founder.teaching().family_generation == 0 and founder.teaching().f_master, "瑷伦, the founder: generation 0, an F_MASTER")
	_check(catalog.npc(&"latemoon.npc.room.annihi").teaching().family_name == "东方神教" and catalog.npc(&"latemoon.npc.room.annihi").teaching().apprentice == null, "安妮儿 of 东方神教 takes no apprentice")
	_check(not catalog.npc(&"cloud.npc.god").dealings().is_fight_deferred(), "朱鸿雪 can be fought now (雪影剑法, 雪影心法)")
	_check(_carries(catalog.npc(&"latemoon.npc.yumay"), &"es2:d/latemoon/obj/needle", 30, true), "雨梅 wields thirty 绣花针 (ob->set_amount(30); ob->wield())")
	_check(_carries(catalog.npc(&"latemoon.npc.room.servant"), &"es2:d/latemoon/room/npc/obj/needle", 30, false), "the rear 婢女 carries thirty 花针")
	_check(_carries(catalog.npc(&"latemoon.npc.room.tguest"), &"es2:d/latemoon/room/npc/obj/token", 1, false), "梦玉楼's 杀手令牌 is carried, not worn (an ITEM)")
	_check(_carries(catalog.npc(&"latemoon.npc.park.flwgirl"), &"es2:d/latemoon/park/npc/obj/guihua", 20, true), "two handfuls of 红桂花: one stack of 20 in hand")
	var shaoin: NpcHitCondition = catalog.npc(&"latemoon.npc.room.shaoin").hit_condition()
	_check(shaoin != null and shaoin.condition_id == ConditionIds.ROSE_POISON and shaoin.duration == 10 and shaoin.below == 20 and shaoin.message == "你觉得被打中的地方一阵麻痒！", "龙韶吟's hit_ob(): rose_poison 10 below 20")


func _test_talk() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var yumay: NpcTalk = catalog.npc(&"latemoon.npc.yumay").talk()
	var lines: Array[String] = []
	for act: ScriptedAct in yumay.greeting_choices():
		lines.append(act.steps[0].line.sentence("蓝雨梅", "姑娘"))
	_check(lines.size() == 2 and lines[0].begins_with("雨梅对你微笑，和善的对你说：") and lines[0].contains("这位姑娘，你好！欢迎来到晚月庄。请坐！") and lines[1].contains("请用茶！"), "雨梅's two greetings: %s" % [lines])
	_check(catalog.npc(&"latemoon.npc.zauron").talk().greeting_choices().size() == 2 and catalog.npc(&"latemoon.npc.shaowei").talk().greeting_choices().size() == 2, "昭蓉's and 筱薇's random(2) greetings")
	var master: NpcTalk = catalog.npc(MASTER).talk()
	var kinds: Array[String] = []
	for entry: Variant in master.combat_chat_entries():
		kinds.append("line" if entry is String else "poison" if entry is NpcFightChat.Poison else "exert" if entry is NpcSpecialAction else "?")
	_check(master.combat_chat_chance == 60 and kinds == ["line", "line", "line", "line", "poison", "exert"], "蓝止萍 in a fight: 60%%, four lines, use_poison and 意寒睨: %s" % [kinds])
	var dodo: NpcTalk = catalog.npc(&"latemoon.npc.park.dodo1").talk()
	_check(dodo.chat_chance == 15 and dodo.chat_entries().size() == 7 and dodo.chat_entries()[0] == NpcTalk.RANDOM_MOVE, "小金鼠: (: this_object(), \"random_move\" :) wanders")


func _test_items() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.item(&"es2:d/latemoon/obj/whip").weapon_rigidity == 70 and catalog.item(&"es2:daemon/class/dancer/echowhip").weapon_rigidity == 70 and catalog.item(&"es2:u/cloud/obj/npc/lm_guard/whip").weapon_rigidity == 30, "the whips' rigidity (weapond.c bash_weapon())")
	_check(catalog.item(&"es2:d/latemoon/obj/sword").weapon_rigidity == 0, "a weapon without set(\"rigidity\"): 0")
	var hankie: ItemContentDefinition = catalog.item(&"es2:d/latemoon/obj/hankie")
	_check(hankie.no_drop and hankie.no_drop_line.is_empty() and hankie.study != null and hankie.study.skill_id == &"move", "丝罗巾: no_drop; a book of move")
	_check(catalog.item(&"es2:d/latemoon/obj/skirt2").armor_definition().numeric_modifiers.value(&"dodge") == 0, "青绫绸裙's misspelt rmor_prop/dodge gives nothing")
	var wine: ItemContentDefinition = catalog.item(&"es2:d/latemoon/obj/wine")
	_check(wine.liquid_definition() != null and wine.liquid_definition().drunk_apply == 0, "女儿红's drunk_bonus is read by nothing (liquid.c reads drunk_apply)")
	_check(catalog.room(&"es2:d/latemoon/latemoon2").long.contains("灰鼠椅搭小褥") and catalog.room(&"es2:d/latemoon/park/paroad2").short == "稻香榭" and catalog.room(&"es2:d/latemoon/upstar/upcenter").long.contains("放开一切，所有时空"), "the lost characters decided (text_replacements.json)")


func _test_arts() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var tender: SkillDefinition = catalog.skill(&"tenderzhi")
	_check(tender.display_name == "柔虹指" and tender.can_enable_for(&"unarmed") and tender.action_set().size() == 4 and tender.action_set().action_at(0).displayed_weapon_or_body_token == "右手食指", "柔虹指: four points of the finger")
	var whip: SkillDefinition = catalog.skill(&"snowwhip")
	_check(whip.display_name == "寒雪鞭法" and whip.can_enable_for(&"whip") and whip.action_set().size() == 6, "寒雪鞭法: six lashes")
	var sword: SkillDefinition = catalog.skill(&"snowshade-sword")
	_check(sword.can_enable_for(&"sword") and sword.can_enable_for(&"parry") and sword.action_set().size() == 6, "雪影剑法: sword and parry")
	_check(catalog.skill(&"snowshade-force").standard_force_hit and catalog.skill(&"snowshade-force").force_hit_wound == null, "雪影心法: std/force.c's hit")
	var ice: SkillDefinition = catalog.skill(&"iceforce")
	_check(ice.standard_force_hit and ice.force_hit_wound != null and ice.force_hit_wound.condition_id == ConditionIds.ICE_SHOCK and ice.force_hit_wound.factor_divisor == 3 and ice.exert_functions == [&"chillgaze"], "意寒功: std/force.c's hit, then its own (iceshock factor / 3); exert chillgaze")
	_check(catalog.skill(&"whip").kind == SkillDefinition.Kind.BASIC, "基本鞭法")
	for id: StringName in [&"latemoon.npc.funlin", &"latemoon.npc.room.elon", MASTER, &"cloud.npc.lm_guard", &"latemoon.npc.room.annihi", &"latemoon.npc.room.tguest", &"latemoon.npc.room.yuchoun"]:
		_check(not catalog.npc(id).dealings().is_fight_deferred(), "%s can be fought" % id)


func _test_conditions() -> void:
	var system := ConditionSystem.new()
	var state: CharacterState = _full_state()
	state.conditions.add_or_replace_duration(ConditionIds.ROSE_POISON, 1)
	var told: ConditionUpdateResult = system.update_once(state)
	_check(state.spirit.effective == 180 and state.spirit.current == 180 and state.vitality.current == 190 and state.vitality.effective == 200, "火玫瑰毒: a wound of 20 sen, 10 kee")
	_check(told.lines.size() == 1 and told.lines[0].text == "你中的火玫瑰毒发作了！" and told.lines[0].color == ColoredLine.HIG, "told in HIG")
	system.update_once(state)
	system.update_once(state)
	_check(not state.conditions.has_condition(ConditionIds.ROSE_POISON) and state.spirit.effective == 160, "duration 1: it bites at 1 and at 0, then goes")
	state = _full_state()
	state.conditions.add_or_replace_duration(ConditionIds.ICE_SHOCK, 0)
	told = system.update_once(state)
	_check(state.essence.current == 175 and state.essence.effective == 200 and state.vitality.effective == 175 and state.spirit.current == 175 and state.spirit.effective == 200, "意寒掌毒: gin 25, a kee wound of 25, sen 25")
	_check(told.lines[0].text == "你中的意寒掌毒发作了！" and told.lines[0].color == ColoredLine.HIB and not state.conditions.has_condition(ConditionIds.ICE_SHOCK), "told in HIB; duration 0 bites once")
	_check(system.shown_names(_poisoned()) == ["火玫瑰毒", "意寒掌毒"] or system.shown_names(_poisoned()) == ["意寒掌毒", "火玫瑰毒"], "both shown on the HUD")


## iceforce.c hit_ob(): after std/force.c's number, random(iceforce) over damage_bonus plus
## it wounds the victim's kee by that sum, sets iceshock to factor / 3 and adds nothing.
func _test_ice_wound() -> void:
	var wound: ForceHitWound = GameContent.catalog().skill(&"iceforce").force_hit_wound
	var bounds: Array[int] = []
	var high := ScriptedCombatRandomSource.new([0, 3, 11, 0, 0, 24, 0, 0, 0, 0, 0, 0])
	var defender_vitality := CharacterResourceState.new(100, 100, 100)
	var conditions := CharacterConditionState.new()
	var result: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(_ice_attacker(wound, 50, 9), _defender(), CombatActionDefinition.new(&"ordinary", 0, 0, &"刺伤")),
		CharacterResourceState.new(100, 100, 100), defender_vitality, CharacterResourceState.new(100, 100, 100), high,
		CharacterInternalResourceState.new(30, 100), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100), conditions,
	)
	bounds.assign(result.calculation.random_upper_bounds())
	var total: int = result.calculation.force_wound
	_check(result.outcome == CombatAttackResult.Outcome.HIT and total > 0 and result.calculation.force_hit_wound == wound, "the blow hits and the cold wounds (%d; bounds %s)" % [total, bounds])
	_check(bounds.size() > 5 and bounds[5] == 25, "random(query_skill(\"iceforce\")): 50 / 2 = 25 (%s)" % [bounds])
	var payload: DurationConditionPayload = conditions.get_condition(ConditionIds.ICE_SHOCK) as DurationConditionPayload
	_check(payload != null and payload.remaining == 3, "iceshock factor 9 / 3 = 3")
	_check(result.calculation.final_strength_bonus == 9, "the force hit's number is not added (the hook returned its line)")
	_check(defender_vitality.effective <= 100 - total, "a wound of the sum on the victim's kee")
	var low := ScriptedCombatRandomSource.new([0, 3, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var calm := CharacterConditionState.new()
	var plain: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(_ice_attacker(wound, 50, 9), _defender(), CombatActionDefinition.new(&"ordinary", 0, 0, &"刺伤")),
		CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100), low,
		CharacterInternalResourceState.new(30, 100), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100), calm,
	)
	_check(plain.calculation.force_wound == 0 and not calm.has_condition(ConditionIds.ICE_SHOCK) and plain.calculation.final_strength_bonus > 9, "random(25) 0: no cold; std/force.c's number is added as ever")


## chillgaze.c: busy 4 first, 50 force and 20 sen, the stare; the target looks away when
## random(its combat_exp) > the user's / 2; else force_factor * 2 - max_force / 15 gin.
func _test_chillgaze() -> void:
	var me: CharacterState = _full_state()
	me.recovery.inner_force = CharacterInternalResourceState.new(100, 1200)
	me.attributes.force_factor = 18
	me.progression.combat_experience = 1000000
	var target := SpecialSide.new(&"player", _full_state(), ActionBusyState.new())
	target.state.recovery.inner_force = CharacterInternalResourceState.new(0, 150)
	target.state.progression.combat_experience = 1000
	target.state.attributes.composure = 10
	var draws: Array[int] = [0, 99]
	var busy := ActionBusyState.new()
	var context := ExertContext.new(me, 30, true, busy, &"lan", func(n: int) -> int: return mini(draws.pop_front(), n - 1))
	context.offensive = func() -> SpecialSide: return target
	_check(ExertFunctions.find(&"chillgaze").exert(context), "意寒睨")
	_check(me.recovery.inner_force.current == 50 and me.spirit.current == 180 and busy.is_busy(), "50 force, 20 sen, busy")
	_check(target.state.essence.current == 200 - 26 and target.state.essence.effective == 200 - 13, "gin 18 * 2 - 150 / 15 = 26, and a wound of 13 when random(30) > cps * 2")
	var said: Array[String] = []
	for line: VisionLine in context.vision_lines:
		said.append(line.template)
	_check(said == ["$N眼神忽然发出异光，双瞳犹如两把利刃般盯著$n！", "$N被$n的目光所摄，不自禁地打了个寒噤。"] and context.vision_lines[1].actor_id == &"player", "the stare, then the target shivers ($N the target): %s" % [said])
	var tired := ExertContext.new(_full_state(), 30, true, ActionBusyState.new(), &"lan")
	_check(not ExertFunctions.find(&"chillgaze").exert(tired) and tired.fail_line == "你的内力不够。" and tired.busy.is_busy(), "no force: refused, but busy already (start_busy() comes first)")
	var calm := ExertContext.new(_full_state(), 30, false, ActionBusyState.new(), &"lan")
	_check(not ExertFunctions.find(&"chillgaze").exert(calm) and calm.fail_line == "「意寒睨」之术只能在战斗中使用。", "only in a fight")


## master.c use_poison(): a random enemy without rose_poison is told, and random(her
## combat_exp) over its own poisons it for 20.
func _test_poison() -> void:
	var rule: NpcFightChat.Poison = null
	for entry: Variant in GameContent.catalog().npc(MASTER).talk().combat_chat_entries():
		if entry is NpcFightChat.Poison:
			rule = entry
	var chat := CombatNpcChat.new(func(id: StringName) -> NpcRuntimeState: return null if id == &"player" else NpcRuntimeState.new())
	var master := CombatSliceCharacterBinding.new(&"lan", _full_state(), CombatRelationshipState.new(&"lan"), ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(), &"here")
	master.state.progression.combat_experience = 1000000
	var player := CombatSliceCharacterBinding.new(&"player", _full_state(), CombatRelationshipState.new(&"player"), ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(), &"here", true, CombatSliceLifeStatus.Value.ACTIVE, true)
	player.state.progression.combat_experience = 5000
	var said: CombatNpcChatResult = chat._poison(rule, master, [player], ScriptedCombatRandomSource.new([0, 500000]))
	var payload: DurationConditionPayload = player.state.conditions.get_condition(ConditionIds.ROSE_POISON) as DurationConditionPayload
	_check(said != null and said.lines()[0].template == "你觉得脸上似乎沾上了什麽东西，伸手一摸却什麽也没有。" and payload != null and payload.remaining == 20, "told, then poisoned for 20")
	_check(chat._poison(rule, master, [player], ScriptedCombatRandomSource.new([0])) == null, "already poisoned: nothing")
	player.state.conditions.remove_condition(ConditionIds.ROSE_POISON)
	said = chat._poison(rule, master, [player], ScriptedCombatRandomSource.new([0, 4000]))
	_check(said != null and not player.state.conditions.has_condition(ConditionIds.ROSE_POISON), "random(1000000) not over 5000: only the feeling")


func _ice_attacker(wound: ForceHitWound, level: int, factor: int) -> CombatAttackerSnapshot:
	return CombatAttackerSnapshot.new(
		&"lan", true, 0, 0, 0, &"unarmed", 3, 0, 10, CombatStrengthProjection.new(0, factor, 0), false,
		&"iceforce", CombatHitPolicyStatus.Value.STANDARD_FORCE, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
		CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, null, &"force", 10, null, wound, level / 2,
	)


func _defender() -> CombatDefenderSnapshot:
	return CombatDefenderSnapshot.new(&"player", true, false, 1, 0, 0, 2, 2, 2, 0, 0, false, [&"头", &"右臂"], &"force", 10, 0, 0)


func _carries(npc: NpcDefinition, item_id: StringName, amount: int, wielded: bool) -> bool:
	for entry: NpcLoadoutEntry in npc.loadout_entries():
		if entry.item_definition_id == item_id:
			return entry.quantity == amount and (entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY) == wielded
	return false


func _full_state() -> CharacterState:
	return CharacterState.new(
		CharacterBaseAttributes.new(0, 0, 0, 0, 0, 0, 30),
		CharacterResourceState.new(200, 200, 200),
		CharacterResourceState.new(200, 200, 200),
		CharacterResourceState.new(200, 200, 200),
	)


func _poisoned() -> CharacterState:
	var state: CharacterState = _full_state()
	state.conditions.add_or_replace_duration(ConditionIds.ROSE_POISON, 5)
	state.conditions.add_or_replace_duration(ConditionIds.ICE_SHOCK, 5)
	return state


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
