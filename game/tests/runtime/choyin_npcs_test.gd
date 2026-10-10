extends RefCounted

## 乔阴 A (d/choyin, daemon/class/scholar, daemon/class/beggar): the people and what they
## fight with — 步玄七诀 with its 玄羽乱舞 (hasten.c: the round's line only when no blow was
## struck, an obvious slip), 小步玄剑, 步玄心法, 油流麻香手 and its broken bones (spicyclaw.c
## hit_ob()), 短歌刀法, 秋风步; the hotel guards' and the 红衣武士's accept_kill() (owner: as
## meant: the others join, the report or the grudge, a hint); the 采药老者's own functions
## (the 山药蛋, his ghost story instead of a fight, the pills, his walk out, his growth);
## 风泉剑灵 when 骆云舟 dies, and its chant; a 书生's book drawn among ten names; every kind
## fought to the end. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.scholar.master"
const BEGGAR: StringName = &"common.npc.beggar.master"
const SOUL: StringName = &"common.npc.scholar.sword_soul"
const OLDMAN: StringName = &"choyin.npc.oldman"
const GUARD: StringName = &"choyin.npc.guard"
const WINDSPRING: StringName = &"es2:daemon/class/scholar/windspring"
const TOMATOO: StringName = &"es2:d/choyin/npc/obj/tomatoo"
const BOOK: StringName = &"es2:d/choyin/obj/book"
const KINDS: Array[StringName] = [
	&"choyin.npc.cityguard", &"common.npc.garrison", &"choyin.npc.cake_vendor", BEGGAR, &"choyin.npc.dumpling_seller",
	&"choyin.npc.boss", &"choyin.npc.sergeant", &"choyin.npc.cucurbit_seller", &"choyin.npc.judge_gu", &"choyin.npc.magistra",
	&"choyin.npc.visitor", &"choyin.npc.scholar", &"choyin.npc.girl", &"choyin.npc.maid", MASTER,
	&"choyin.npc.youngman", &"choyin.npc.servant", GUARD, &"choyin.npc.judgeman", &"choyin.npc.serpent",
	&"choyin.npc.lboy",
]
## The maps the fights walk, with where the player stands at first.
const MAPS: Array = [
	[&"choyin.town", &"choyin.n_gate", &"choyin.n_gate.road_arrival"],
	[&"choyin.hotel_2f", &"choyin.hotel2", &"choyin.hotel2.stairs_arrival"],
	[&"choyin.hotel_3f", &"choyin.hotel3", &"choyin.hotel3.stairs_arrival"],
	[&"choyin.yamen_compound", &"choyin.yamen", &"choyin.yamen.hall_entry"],
	[&"choyin.east", &"choyin.solidpath1", &"choyin.solidpath1.gate_arrival"],
	[&"choyin.summit", &"choyin.platform", &"choyin.platform.crane_arrival"],
]


## Every draw the highest: no dodge or parry, bones break, the last message.
class Highest:
	extends CombatRandomSource

	func next_below(bound: int) -> int:
		return maxi(bound - 1, 0)


## hasten.c's fight()s as the test wants them: "hit", "guard" or "none" in turn.
class Fights:
	extends SpecialAttackSource
	var outcomes: Array[String] = []
	var enemy: StringName = &""

	func fight(attacker_id: StringName, victim_id: StringName) -> SpecialAttack:
		var outcome: String = outcomes.pop_front() if not outcomes.is_empty() else "none"
		if outcome == "hit":
			return SpecialAttack.new(attacker_id, victim_id, CombatSingleAttackExecutionResult.new(), null)
		if outcome == "guard":
			var guarded := SpecialAttack.new(attacker_id, victim_id)
			guarded.guard_index = 0
			return guarded
		return null

	func select_opponent(_attacker_id: StringName, random: Callable) -> StringName:
		random.call(4)
		return enemy


var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_people()
	_test_arts()
	_test_refusals()
	_test_hasten()
	_test_bone_crack()
	_test_hurt()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_books(tree, session)
	await _test_oldman(tree, session)
	await _test_hotel_guards(tree, session)
	await _test_elite_guards(tree, session)
	await _test_sword_soul(tree, session)
	await _test_fights(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_people() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in KINDS + [OLDMAN, SOUL, &"choyin.npc.crone", &"choyin.npc.lady"]:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and not npc.dealings().is_fight_deferred(), "%s can be fought" % id)
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(master.display_name == "骆云舟" and master.teaching().family_name == "步玄派" and master.skill_map().get(&"dodge") == &"mysterrier" and master.skill_map().get(&"sword") == &"mystsword" and master.skill_map().get(&"force") == &"mystforce", "骆云舟: 步玄七诀, 小步玄剑, 步玄心法")
	var entries: Array = master.talk().combat_chat_entries()
	_check(master.talk().combat_chat_chance == 30 and entries.size() == 2 and (entries[1] as NpcSpecialAction).function_id == &"hasten", "his fight chat: exert recover (步玄心法 has no file: nothing) or perform move.hasten")
	var beggar: NpcDefinition = catalog.npc(BEGGAR)
	_check(beggar.display_name == "陆得财" and beggar.nickname == "黑水伏蛟" and beggar.skill_map().get(&"unarmed") == &"spicyclaw" and beggar.skill_map().get(&"force") == &"serpentforce", "陆得财: 油流麻香手, 伏蛟功")
	var magistrate: NpcDefinition = catalog.npc(&"choyin.npc.magistra")
	_check(magistrate.skill_map().get(&"blade") == &"shortsong-blade" and magistrate.skill_map().get(&"dodge") == &"fall-steps", "带刀侍卫: 短歌刀法, 秋风步")
	var targets: Array[String] = []
	for id: StringName in KINDS:
		targets.append(catalog.npc(id).display_name)
	for name: String in ["卖包子的", "卖糖葫芦的", "卖饼大叔", "守城官兵", "武官", "贵公子"]:
		_check(targets.has(name), "朱鸿雪's %s stands" % name)
	_check(catalog.npc(&"choyin.npc.cake_vendor").query_self(CharacterState.GENDER_MALE, 42) == "小的", "卖饼大叔 calls himself 小的 (rank_info/self)")
	var book: ItemContentDefinition = catalog.item(BOOK)
	_check(book.name_pick().size() == 10 and catalog.item(ItemContentDefinition.named_id(BOOK, 3)).display_name == "「梁父文集」" and catalog.item(ItemContentDefinition.named_id(BOOK, 3)).study != null, "the book's ten names, each a form of its own (study literate to 50)")
	_check(catalog.item(WINDSPRING).owner_killed_npc() == SOUL and catalog.item(WINDSPRING).owner_killed_unless() == SOUL, "风泉之剑: 风泉剑灵 when its holder dies, not when the 剑灵 does")
	_check(catalog.npc(&"choyin.npc.crane").dealings().is_fight_deferred(), "the cranes wait for 乔阴 B (a beast without verbs)")
	_check(catalog.item(&"es2:d/choyin/obj/silver_clasp").armor_definition() != null and catalog.item(&"es2:d/choyin/obj/silver_clasp").weapon_definition() == null, "the 银簪 is worn in the hair")


func _test_arts() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var steps: SkillDefinition = catalog.skill(&"mysterrier")
	_check(steps.display_name == "步玄七诀" and steps.can_enable_for(&"dodge") and steps.can_enable_for(&"move") and steps.perform_functions == [&"hasten"] and steps.dodge_messages.size() == 5, "步玄七诀: dodge and move, 玄羽乱舞")
	_check(catalog.skill(&"mystforce").standard_force_hit and catalog.skill(&"mystforce").exert_functions.is_empty(), "步玄心法: std/force.c's hit, no exert file")
	_check(catalog.skill(&"mystsword").action_set().actions().size() == 4 and catalog.skill(&"mystsword").can_enable_for(&"parry"), "小步玄剑: four moves, sword and parry")
	var claw: SkillDefinition = catalog.skill(&"spicyclaw")
	_check(claw.display_name == "油流麻香手" and claw.action_set().actions().size() == 7 and claw.martial_hit_wound != null and claw.martial_hit_wound.at_least == 100 and claw.martial_hit_wound.messages.size() == 3 and not claw.has_own_hit_ob, "油流麻香手: seven moves and the bones it breaks")
	_check(catalog.skill(&"shortsong-blade").display_name == "短歌刀法" and catalog.skill(&"shortsong-blade").action_set().actions().size() == 7 and catalog.skill(&"shortsong-blade").parry_messages_armed.is_empty(), "短歌刀法: seven moves (its parry lines are never asked: combatd.c asks parry.c)")
	_check(catalog.skill(&"fall-steps").display_name == "秋风步" and catalog.skill(&"fall-steps").dodge_messages.size() == 9, "秋风步")


func _test_refusals() -> void:
	var stranger := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 20, &"", &"")
	var cases: Array = [
		[GUARD, "掌柜的有交代，不准任何人在这里打架！", false],
		[&"choyin.npc.judgeman", "这是衙门，快回去吧。", false],
	]
	for entry: Array in cases:
		var npc := NpcRuntimeState.new(&"x", GameContent.catalog().npc(entry[0]), &"", &"", _full_state())
		var answer: NpcSparConsent = NpcSparConsent.decide(npc, stranger)
		_check(answer.accepted == entry[2] and answer.lines.size() == 1 and answer.lines[0].text == entry[1], "%s: %s" % [entry[0], entry[1]])
	var old := NpcRuntimeState.new(&"x", GameContent.catalog().npc(OLDMAN), &"", &"", _full_state())
	var oldman: NpcSparConsent = NpcSparConsent.decide(old, stranger)
	_check(oldman.accepted and oldman.lines.is_empty(), "the 采药老者 takes a spar without a word")


## hasten.c: busy 3 after query_skill("mysterrier") / 20 + 2 rounds (here 5), each circling
## an enemy and fight()ing it, 10 kee and 10 force each; 但是$N找不到机会出手！ after a round
## without a blow (an obvious slip: ES2 printed it after every round).
func _test_hasten() -> void:
	var perform: PerformFunction = SpecialFunctions.perform(&"hasten")
	_check(perform != null and perform.label == "「玄羽乱舞」", "玄羽乱舞 is a perform file")
	var me := SpecialSide.new(&"luo", _full_state(), ActionBusyState.new(), CombatRelationshipState.new(&"luo"))
	me.state.skills.set_raw_level(&"mysterrier", 120)
	me.state.recovery.inner_force = CharacterInternalResourceState.new(200, 100)
	me.relationship.add_opponent(&"player")
	var foe := SpecialSide.new(&"player", _full_state(), ActionBusyState.new(), CombatRelationshipState.new(&"player"))
	var fights := Fights.new()
	fights.outcomes.assign(["hit", "guard", "none", "hit", "none"])
	fights.enemy = &"player"
	var context := SpecialContext.new(me, [foe], func(n: int) -> int: return n - 1, GameContent.catalog(), null, [foe])
	context.attack_source = fights
	_check(perform.perform(context), "玄羽乱舞")
	var said: Array[String] = []
	for line: VisionLine in context.lines:
		said.append(line.template)
	var round: String = "$N迅捷无伦地在$n身旁绕了一圈 ..."
	var none: String = "但是$N找不到机会出手！"
	_check(said == ["$N使出步玄七诀第一式「玄羽乱舞」，身法陡然加快！", round, round, none, round, none, round, round, none], "five rounds; the line only after one without a blow: %s" % [said])
	_check(context.attacks.size() == 3 and context.attacks[1].guard_index == 0, "two blows and a guard line are its attacks")
	_check(me.state.vitality.current == 150 and me.state.recovery.inner_force.current == 150 and me.busy.busy_value == 3, "50 kee, 50 force, busy 3")
	var calm := SpecialContext.new(SpecialSide.new(&"luo", _full_state(), ActionBusyState.new(), CombatRelationshipState.new(&"luo")))
	_check(not perform.perform(calm) and calm.fail_line.template == "「玄羽乱舞」只能在战斗中使用。", "only in a fight")
	me.state.vitality = CharacterResourceState.new(60, 200, 200)
	_check(not perform.perform(context) and context.fail_line.template == "你的气不够！", "60 kee: 你的气不够！")
	me.state.vitality = CharacterResourceState.new(200, 200, 200)
	me.state.recovery.inner_force = CharacterInternalResourceState.new(160, 100)
	_check(not perform.perform(context) and context.fail_line.template == "你的真气不够！", "60 over max_force: 你的真气不够！")


## spicyclaw.c hit_ob(): from a damage_bonus of 100, random(it / 2) over the victim's
## query_str() wounds kee by (bonus - 100) / 2 and says one of three lines.
func _test_bone_crack() -> void:
	var wound: MartialHitWound = GameContent.catalog().skill(&"spicyclaw").martial_hit_wound
	var vitality := CharacterResourceState.new(500, 500, 500)
	var result: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(_claw_attacker(wound, 60), _defender(10), CombatActionDefinition.new(&"ordinary", 0, 160, &"抓伤")),
		CharacterResourceState.new(500, 500, 500), vitality, CharacterResourceState.new(500, 500, 500), Highest.new(),
		CharacterInternalResourceState.new(0, 0), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100), CharacterConditionState.new(),
	)
	var bonus: int = 60 + 160 * 60 / 100
	_check(result.outcome == CombatAttackResult.Outcome.HIT and result.calculation.martial_wound == (bonus - 100) / 2 and result.calculation.martial_message == wound.messages[2], "bonus %d: a wound of %d and the third line (%d, %s)" % [bonus, (bonus - 100) / 2, result.calculation.martial_wound, result.calculation.martial_message])
	_check(vitality.effective <= 500 - (bonus - 100) / 2, "the wound on the victim's kee")
	var weak: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(_claw_attacker(wound, 30), _defender(10), CombatActionDefinition.new(&"ordinary", 0, 160, &"抓伤")),
		CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), Highest.new(),
		CharacterInternalResourceState.new(0, 0), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100), CharacterConditionState.new(),
	)
	_check(weak.calculation.martial_wound == 0 and weak.calculation.martial_message.is_empty(), "below 100 (30 + 48): nothing")
	var strong: CombatAttackResult = CombatAttackResolver.resolve(
		CombatAttackInput.new(_claw_attacker(wound, 60), _defender(200), CombatActionDefinition.new(&"ordinary", 0, 160, &"抓伤")),
		CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), CharacterResourceState.new(500, 500, 500), Highest.new(),
		CharacterInternalResourceState.new(0, 0), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100),
		CharacterResourceState.new(100, 100, 100), CharacterConditionState.new(),
	)
	_check(strong.calculation.martial_wound == 0, "a victim stronger than the roll: no bones break")


## oldman.c receive_damage(): above max_kee / 5 his line and, on random(kee) < the blow,
## his walk out; below 20 gin, kee or sen a pill (nine), all back to eff_.
func _test_hurt() -> void:
	var oldman := NpcRuntimeState.new(&"old", GameContent.catalog().npc(OLDMAN), &"", &"", _full_state())
	var chat := CombatNpcChat.new(func(id: StringName) -> NpcRuntimeState: return oldman if id == &"old" else null).with_leaving(
		func(_id: StringName, _draw: Callable) -> NpcRandomMove.Move: return NpcRandomMove.Move.new("north", &"choyin.rockpath1"))
	var binding := CombatSliceCharacterBinding.new(&"old", oldman.character_state, CombatRelationshipState.new(&"old"), ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(), &"here")
	_check(chat.hurt(binding, 40, ScriptedCombatRandomSource.new([0, 0])) == null, "40 of 200: not above 200 / 5, nothing")
	var hit: CombatNpcChatResult = chat.hurt(binding, 41, ScriptedCombatRandomSource.new([10, 0]))
	_check(hit != null and hit.lines()[0].template == "老者捂著受伤的地方，白发散乱，勉强稳住身行。" and hit.lines()[1].template == "老者往北落荒而逃了。" and hit.departure_zone_id() == &"choyin.rockpath1", "41: his line, random(kee) 10 < 41: he walks out")
	_check(chat.hurt(binding, 41, ScriptedCombatRandomSource.new([199])).departure_zone_id().is_empty(), "random(kee) 199: he stays")
	binding.state.vitality.apply_damage(190)
	var pill: CombatNpcChatResult = chat.hurt(binding, 5, ScriptedCombatRandomSource.new([]))
	_check(pill != null and pill.lines().back().template == "老者从口袋摸出一粒象小山药蛋的仙豆吞了下去。" and binding.state.vitality.current == 200 and oldman.pills() == 8, "kee 10: a pill, kee back to 200, eight left")
	oldman.pills_left = 0
	binding.state.vitality.apply_damage(190)
	_check(chat.hurt(binding, 5, ScriptedCombatRandomSource.new([])) == null, "no pills left: nothing")


## A 书生 carries one of book.c's ten books, its name drawn as it is made.
func _test_books(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "in the town")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var books: int = 0
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id != &"choyin.npc.scholar":
			continue
		for item: ItemInstance in npc.loadout_items():
			if ItemContentDefinition.unnamed_id(item.item_definition_id) == BOOK and item.item_definition_id != BOOK:
				books += 1
	_check(books == 2, "each 书生's book is one of its named forms: %d" % books)


## oldman.c: one without a 山药蛋 is given one, one carrying it asked how it tasted; one who
## attacks him reads his ghost story and he is gone until his room makes him anew; waking,
## he grows (revive()).
func _test_oldman(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.east", &"choyin.solidpath1", &"choyin.solidpath1", &"choyin.solidpath1.gate_arrival").succeeded(), "east of the city")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var oldman: NpcRuntimeState = _npc(map, OLDMAN)
	_check(oldman != null and map.relocate_player(&"choyin.rockyu", oldman.spawn_point_id), "beside the old man")
	await tree.physics_frame
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(1.1)
	_check(not _carried(session, TOMATOO).is_empty() and hud.log_lines()[-1].ends_with("最后拿出个小山药蛋塞到你手里。"), "a 山药蛋 put in the player's hand: %s" % hud.log_lines()[-1])
	_check(session.player_runtime().temp_marks.get("choyin/山药蛋", 0) == 1, "set_temp(\"choyin/山药蛋\")")
	_check(map.place_player(&"choyin.rockpath1", MapPlaces.zone_spot(map, &"choyin.rockpath1")), "away down the path")
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	_check(map.place_player(&"choyin.rockyu", MapPlaces.spot(map, &"choyin.rockyu", oldman_body(map, oldman))), "back beside him")
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(1.1)
	_check(hud.log_lines()[-1] == "我给你的山药蛋好吃吗??", "我给你的山药蛋好吃吗??")
	var progression: CharacterProgressionState = oldman.character_state.progression
	progression.combat_experience = 300 # TEST-ONLY
	progression.potential = 31 # TEST-ONLY
	map.npc_life._revive_growth(oldman)
	_check(progression.combat_experience == 410 and oldman.character_state.applies.get("attack", 0) == 10 and progression.potential_spent == 30, "waking: 300 + 100 + 10 combat_exp, a third of 31 potential each to attack, dodge, damage")
	map.select_npc(oldman.character_id)
	var said: int = hud.log_lines().size()
	var answer: CombatSliceInitiationResult = map.attack_selected()
	var lines: Array[String] = hud.log_lines().slice(said)
	_check(answer.outcome != CombatSliceInitiationResult.Outcome.COMPLETED and not session.combat_encounter_coordinator().has_active_encounter(), "no fight")
	_check(lines.size() >= 20 and lines[1] == "采药老者眼放异光，说道：你真的不喜欢山药蛋吗??" and lines.has("你死了。") and lines.has("你觉得有什么地方不对了，使劲掐了一下自己，你惨叫了一声:哇，好痛啊～～～～～～") and lines[-1] == "山药蛋就地一滚，没入土中不见了......", "his ghost story: %s" % [lines.slice(0, 3)])
	_check(oldman.life_status == CharacterRuntimeLifeStatus.Value.DEAD and not oldman.exists_in_map and map.corpse_states().is_empty(), "he is gone, no corpse")
	map.reset_room("d/choyin/rockyu.c")
	var fresh: NpcRuntimeState = _npc(map, OLDMAN)
	_check(fresh != null and fresh != oldman and fresh.exists_in_map and fresh.pills() == 9, "his room makes him anew, nine pills")


## guard.c accept_kill() (owner: as meant): the other two say 干什么？！ and join, the one
## attacked calls for the law, vendetta/authority, the hint; then the 守城官兵 attack on sight.
func _test_hotel_guards(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.hotel_3f", &"choyin.hotel3", &"choyin.hotel3", &"choyin.hotel3.stairs_arrival").succeeded(), "the guest rooms")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var guard: NpcRuntimeState = _npc(map, GUARD)
	_check(map.relocate_player(&"choyin.hotel3", guard.spawn_point_id), "beside a guard")
	await tree.physics_frame
	map.select_npc(guard.character_id)
	var said: int = hud.log_lines().size()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks him")
	var lines: Array[String] = hud.log_lines().slice(said)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var guards: int = 0
	for participant: CombatParticipant in coordinator.active_encounter().participants():
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(participant.participant_id)
		if npc != null and npc.definition().definition_id == GUARD and participant.binding.relationship.has_lethal_target(player.character_id):
			guards += 1
	_check(guards == 3, "all three fight the player to the death: %d" % guards)
	_check(lines.count("酒楼守卫说道：干什么？！") == 2 and lines.has("酒楼守卫说道：有强人打劫哪... 快去报官！") and lines.has("（福林酒楼报了官：从此守城官兵和县城官兵见到你就会动手。）"), "干什么？！ twice, the call for the law, the hint: %s" % [lines])
	_check(player.state.vendetta.get("authority", 0) == 1, "vendetta/authority")
	_check(GameContent.catalog().npc(&"choyin.npc.cityguard").attacks_on_sight({}, player.state) and GameContent.catalog().npc(&"common.npc.garrison").attacks_on_sight({}, player.state), "守城官兵 and 县城官兵 attack on sight now")
	_finish_fight(session)
	player.state.vendetta.clear() # TEST-ONLY
	await tree.physics_frame


## elite_guard.c accept_kill() (owner: as meant, and every 红衣武士 holds the grudge): his
## line, his powerup, the other one joins; vendetta/waterfog_guard and the hint.
func _test_elite_guards(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"waterfog.upstairs", &"waterfog.west_2f", &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival").succeeded(), "水烟阁's west room upstairs")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var guard: NpcRuntimeState = _npc(map, &"waterfog.npc.elite_guard")
	_check(map.relocate_player(&"waterfog.west_2f", guard.spawn_point_id), "beside a 红衣武士")
	await tree.physics_frame
	map.select_npc(guard.character_id)
	var said: int = hud.log_lines().size()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks him")
	var lines: Array[String] = hud.log_lines().slice(said)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var guards: int = 0
	for participant: CombatParticipant in coordinator.active_encounter().participants():
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(participant.participant_id)
		if npc != null and npc.definition().definition_id == &"waterfog.npc.elite_guard":
			guards += 1
	_check(guards == 2, "the other one joins: %d" % guards)
	_check(lines.has("水烟阁红衣武士说道：哼 ... 原来阁下是找麻烦来著？") and lines.has("（水烟阁的红衣武士从此都把你当作敌人，见到你就会动手。）"), "his line and the hint: %s" % [lines])
	_check(guard.character_state.timed_applies.value(&"attack") > 0 or guard.character_state.timed_applies.value(&"dodge") > 0 or guard.character_state.recovery.inner_force.current < 1800, "his powerup")
	_check(player.state.vendetta.get("waterfog_guard", 0) == 1 and GameContent.catalog().npc(&"waterfog.npc.elite_guard").attacks_on_sight({}, player.state), "the grudge: every 红衣武士 attacks on sight")
	_finish_fight(session)
	player.state.vendetta.clear() # TEST-ONLY
	await tree.physics_frame


## windspring.c owner_is_killed(): 骆云舟 dies, his sword is gone and 风泉剑灵 stands
## there; its chant every 20 s, 100000 combat_exp with the fourth.
func _test_sword_soul(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "back in the town")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var master: NpcRuntimeState = _npc(map, MASTER)
	_check(map.place_player(&"choyin.entrance", MapPlaces.spot(map, &"choyin.entrance", oldman_body(map, master))), "on the 曼雩台")
	await tree.physics_frame
	map.select_npc(master.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 骆云舟")
	master.character_state.vitality.apply_wound(master.character_state.vitality.effective + 1) # TEST-ONLY: the last blow
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 20:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(master.life_status == CharacterRuntimeLifeStatus.Value.DEAD and CombatEncounterCoordinator.take_aborted_total() == 0, "骆云舟 dies")
	var soul: NpcRuntimeState = _npc(map, SOUL)
	_check(soul != null and soul.world_location().zone_id == &"choyin.entrance", "风泉剑灵 stands on the 曼雩台")
	var lines: Array[String] = hud.log_lines()
	for line: ColoredLine in hud._after_fight_lines:
		lines.append(line.text)
	_check(lines.has("你看到风泉之剑掉落在地上 ...") and lines.has("不 ... 它飘了起来！一个人形忽然浮现，手中正握著风泉之剑！"), "its lines: %s" % [lines.slice(-4)])
	var swords: int = 0
	for corpse: CorpseState in map.corpse_states():
		for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)):
			if session.item_instance_index().resolve(item_id).item_definition_id == WINDSPRING:
				swords += 1
	_check(swords == 0 and soul.character_state.equipment.primary_weapon() != null and soul.character_state.equipment.primary_weapon().weapon_id == WINDSPRING, "the sword is not in his corpse: the 剑灵 holds its own")
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(20.0)
	_check(hud.log_lines()[-1] == "风泉剑灵说道：剑气指天 ...", "剑气指天 ...: %s" % hud.log_lines()[-1])
	map.npc_life._advance_ambience(20.0)
	map.npc_life._advance_ambience(20.0)
	map.npc_life._advance_ambience(20.0)
	var seen: Array[String] = hud.log_lines().slice(-2)
	_check(seen == ["风泉剑灵说道：剑神如意！", "一阵蓝光笼罩住风泉剑灵，「嗡」地一声，风泉剑灵的轮廓又变清晰了一些！"] and soul.character_state.progression.combat_experience == 400000, "剑神如意！ and 100000 combat_exp: %s %d" % [seen, soul.character_state.progression.combat_experience])
	map.npc_life._advance_ambience(59.0)
	_check(hud.log_lines()[-1] == seen[1], "the next round sixty seconds on")
	map.npc_life._advance_ambience(1.5)
	_check(hud.log_lines()[-1] == "风泉剑灵说道：剑气指天 ...", "and again")
	_check(Work.capture(session) != null, "Save with the 剑灵 standing")
	map.select_npc(soul.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 剑灵")
	soul.character_state.vitality.apply_wound(soul.character_state.vitality.effective + 1) # TEST-ONLY: the last blow
	rounds = 0
	while coordinator.has_active_encounter() and rounds < 20:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	map.npc_life._advance_ambience(30.0)
	var dropped: int = 0
	for corpse: CorpseState in map.corpse_states():
		for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)):
			if session.item_instance_index().resolve(item_id).item_definition_id == WINDSPRING:
				dropped += 1
	_check(soul.life_status == CharacterRuntimeLifeStatus.Value.DEAD and map.npc_life.chants.is_empty() and _npc(map, SOUL) == null, "the 剑灵 falls; its chant with it")
	_check(dropped == 1, "its 风泉之剑 lies in its corpse")


## Every kind fights to the end without the fight stopping.
func _test_fights(tree: SceneTree, session: WorldSessionController) -> void:
	var fought: Array[StringName] = []
	for entry: Array in MAPS:
		if session.active_map_id() == entry[0]:
			_check((session.active_map() as WorldMapController).relocate_player(entry[1], entry[2]), "back to %s" % entry[1])
		else:
			_check(session.handoff_to(entry[0], entry[1], entry[1], entry[2]).succeeded(), "onto %s" % entry[0])
		await tree.process_frame
		var map: WorldMapController = session.active_map() as WorldMapController
		map.reset_room("d/choyin/entrance.c") # TEST-ONLY: 骆云舟 again after the 剑灵's test
		for npc: NpcRuntimeState in map.resident_npcs():
			var id: StringName = npc.definition().definition_id
			if not KINDS.has(id) or not npc.exists_in_map or fought.has(id) or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
				continue
			fought.append(id)
			await _fight(tree, session, map, npc)
	_check(fought.size() == KINDS.size(), "%d kinds fought: %s" % [fought.size(), fought])


func _fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var name: String = npc.definition().display_name
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_full(player)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.relocate_player(npc.world_location().zone_id, npc.spawn_point_id), "beside %s" % name)
	await tree.physics_frame
	await tree.physics_frame
	CombatEncounterCoordinator.take_aborted_total()
	if not coordinator.has_active_encounter():
		map.select_npc(npc.character_id)
		var started: CombatSliceInitiationResult = map.attack_selected()
		_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s: %s %s" % [name, CombatSliceInitiationResult.Outcome.find_key(started.outcome), session.shared_ui().log_lines().slice(-2)])
	coordinator.advance_scheduler(30.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: thirty seconds of fighting without a stop" % name)
	_finish_fight(session)
	player.state.vendetta.clear() # TEST-ONLY: the guards' report
	await tree.physics_frame


## TEST-ONLY: away from the fight, by fleeing as often as it takes.
func _finish_fight(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: out of the fight")
	session.shared_ui().dismiss_current_panel()
	for opponent_id: StringName in player.relationship.opponent_ids(): # TEST-ONLY: as walking away would
		player.relationship.remove_lethal_relation(opponent_id)
		player.relationship.remove_opponent(opponent_id)


## Where the NPC's body stands.
func oldman_body(map: WorldMapController, npc: NpcRuntimeState) -> Vector2:
	return map.runtime_body_for_character(npc.character_id).global_position


func _claw_attacker(wound: MartialHitWound, strength: int) -> CombatAttackerSnapshot:
	return CombatAttackerSnapshot.new(
		&"lu", true, 0, 0, 0, &"unarmed", 3, 0, 0, CombatStrengthProjection.new(strength, 0, 0), true,
		&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE, &"spicyclaw", CombatHitPolicyStatus.Value.MARTIAL_WOUND,
		CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, null, &"force", 0, null, null, 0, wound,
	)


func _defender(strength: int) -> CombatDefenderSnapshot:
	return CombatDefenderSnapshot.new(&"player", true, false, 1, 0, 0, 2, 2, 2, 0, 0, false, [&"头", &"右臂"], &"force", 10, 0, 0, strength)


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for id: StringName in session.inventory_state().direct_children(carried):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _full_state() -> CharacterState:
	return CharacterState.new(
		CharacterBaseAttributes.new(0, 0, 0, 0, 0, 0, 30),
		CharacterResourceState.new(200, 200, 200),
		CharacterResourceState.new(200, 200, 200),
		CharacterResourceState.new(200, 200, 200),
	)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("choyin npcs: " + message)
