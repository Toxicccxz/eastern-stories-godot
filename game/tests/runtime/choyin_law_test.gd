extends RefCounted

## 乔阴 D: 花紫会, stealing and the 县衙. 陆得财's attempt_apprentice() (look, can_afford(100)
## of the money carried refuses, else the recruit: class beggar) and his teaching; the player's
## 油流麻香手 (empty hands, max_force 80; practice 25 kee, 3 force) and 伏蛟功 (practised only
## where the room has resource/water: 30 kee, 10 force; the basic force's exerts); the player's
## steal (cmds/std/steal.c with NpcSteal's odds: what the NPC wears or wields or 随手摸一样;
## asked first from one clearly stronger; caught, a fight to the death and thief + 1); thief
## forgotten one a reset (obj/user.c), halved at death, 惯窃 above ten. The 县衙 repaired (owner,
## 乔阴 A Q1): eight 巡捕 with drawn names patrol the main street; one meeting a thief catches
## them seven times in ten (crime_lv + 3, thief - 1), leads them back along the street, their
## walking refused, into the 大堂; 程不平 beats them by formula two seconds later, clears the
## crime and puts them out at the 衙门口. Ten gold frees them on the way (crime_lv - 3), less is
## refused (crime_lv + 1); killing a 巡捕 is crime_lv + 5. Save waits while in custody; a 巡捕's
## drawn name is kept by a save. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.beggar.master"
const POLICE: StringName = &"choyin.npc.yamen_po"
const JUDGE: StringName = &"choyin.npc.judgeman"
const SCHOLAR: StringName = &"choyin.npc.scholar"
const FAMILY: StringName = &"family.huazi"
const ROUTE: Array[StringName] = [
	&"choyin.court1", &"choyin.crossroad", &"choyin.s_street5", &"choyin.s_street4", &"choyin.s_street1", &"choyin.s_street2",
	&"choyin.s_street3", &"choyin.tree_tomb", &"choyin.n_street3", &"choyin.n_street2", &"choyin.n_street1", &"choyin.n_gate",
]
const SURNAMES: Array[String] = ["慕容巡捕", "西门巡捕", "公孙巡捕", "上官巡捕", "南宫巡捕", "欧阳巡捕", "司徒巡捕"]
const CAUGHT_SAY: String = "闹了半天原来你是个贼啊! 我走一趟吧!"


## Every draw the smallest (a catch's random(10) < 7).
class Lowest extends WorldInteractionRandomSource:
	func next_below(_bound: int) -> int:
		return 0


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_apprentice_rule()
	_test_learn()
	_test_practice()
	_test_crime_record()
	_test_sentence_rule()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats, wanders or patrols
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "TEST-ONLY: in the town")
	await tree.physics_frame
	await tree.physics_frame
	await _test_join(tree, session)
	await _test_water(tree, session)
	await _test_steal(tree, session)
	await _test_patrol(tree, session)
	await _test_bribe(tree, session)
	await _test_court(tree, session)
	await _test_custody_ends(tree, session)
	await _test_killed(tree, session)
	await _test_save(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Data ---------------------------------------------------------------------------

func _test_data() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var rule: NpcTeaching.ApprenticeRule = master.teaching().apprentice
	_check(rule != null and rule.kind == NpcTeaching.Kind.REQUIREMENTS and rule.class_id == &"beggar" and rule.looks and rule.accept_say.is_empty(), "陆得财: looks first, nods (nothing), class beggar")
	_check(rule.checks.size() == 1 and rule.checks[0].cannot_afford == 100 and rule.checks[0].refuse_say == "我们花紫会只收化子，$RESPECT您还是回去享福吧。\n", "can_afford(100) refuses, with his say")
	_check(master.teaching().family_id == FAMILY and master.teaching().family_generation == 4 and master.teaching().f_master, "花紫会's fourth 龙头, an F_MASTER")
	var taught: Array[StringName] = NpcTeacher.teachable_skills(master, _catalog)
	_check(taught.size() == 11 and taught.has(&"stealing") and taught.has(&"spicyclaw") and taught.has(&"serpentforce") and taught.has(&"perception"), "he teaches all eleven of his skills, 偷窃 among them: %s" % [taught])
	_check(_catalog.skill(&"stealing").display_name == "偷窃" and _catalog.skill(&"stealing").kind == SkillDefinition.Kind.BASIC, "偷窃, a basic skill (plan name)")
	var police: NpcDefinition = _catalog.npc(POLICE)
	var patrol: NpcPatrol = police.dealings().patrol
	_check(patrol != null and patrol.route == ROUTE, "the beat: the main street from the 衙门口 to the 北门, through s_street3: %s" % [patrol.route if patrol != null else []])
	var arrest: NpcArrest = patrol.arrest
	_check(arrest.catch_below == 7 and arrest.out_of == 10 and arrest.crime == 3 and arrest.bribe_at == 100000 and arrest.pardon == 3 and arrest.bribe_crime == 1 and arrest.killed_crime == 5, "random(10) < 7, crime_lv + 3, ten gold, - 3, + 1, + 5")
	_check(arrest.court_zone_id == &"choyin.yamen" and arrest.court_point_id == &"choyin.yamen.hall_entry" and arrest.escape_line == "嘿嘿, 还想往哪逃?!", "into the 大堂; do_go()'s line")
	_check(police.talk().chat_chance == 99 and police.talk().chat_entries() == [NpcTalk.PATROL], "chat_chance 99: patrol()")
	_check(police.name_pick() == SURNAMES, "the seven surnames")
	for index: int in range(SURNAMES.size()):
		var named: NpcDefinition = _catalog.npc(NpcDefinition.named_id(POLICE, index))
		_check(named != null and named.display_name == SURNAMES[index] and named.name_pick().is_empty() and named.dealings().patrol != null, "named form %s" % SURNAMES[index])
	var spawns: Array[StringName] = []
	for spawn: NpcSpawnDefinition in _catalog.spawns():
		if spawn.npc_definition_id == POLICE:
			spawns.append(spawn.zone_id)
			_check(ROUTE.has(spawn.zone_id) and spawn.legacy_source_room_path == "d/choyin/yamen.c" and not spawn.summoned, "a 巡捕 on the beat from yamen.c: %s" % spawn.zone_id)
	_check(spawns.size() == 8, "eight 巡捕 (yamen.c's eight): %s" % [spawns])
	var sentence: NpcSentence = _catalog.npc(JUDGE).dealings().sentence
	_check(sentence != null and is_equal_approx(sentence.after, 2.0) and sentence.out_zone_id == &"choyin.court1" and sentence.out_point_id == &"choyin.court1.yamen_return", "程不平: two seconds on, out at the 衙门口")
	_check(sentence.beat_line == "来人哪！把$N拖下去打{boards}大板！" and sentence.faint_lines == ["哎, 早知今日,何必当初?", "来人呀, 把$N给我抬出去!", "...退...堂...!"] and sentence.warn_line == "$N对$n说道: 再敢犯案, 定斩不饶!", "settle_lawsuit()'s lines verbatim")
	_check(_catalog.zone_has_water(&"choyin.s_street1") and _catalog.zone_has_water(&"oldpine.gorge.river") and not _catalog.zone_has_water(&"choyin.n_street1"), "resource/water: the well, the stream (riverbank1.c); not the street")


func _test_apprentice_rule() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var rich: CharacterState = _student()
	var request := NpcApprenticeship.new()
	request.affords = func(price: int) -> bool: return price <= 100
	_check(request.request(rich, master, _catalog.family(FAMILY), 1, "小兄弟") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED, "one who can afford 100 is refused")
	_check(request.lines == ["你想要拜陆得财为师。", "陆得财正盯著你看，不知道打些什麽主意。", "陆得财说道：我们花紫会只收化子，小兄弟您还是回去享福吧。"] and not request.is_pending(), "the look, his say; the request is over: %s" % [request.lines])
	request.affords = func(price: int) -> bool: return price <= 99
	var poor: CharacterState = _student()
	_check(request.request(poor, master, _catalog.family(FAMILY), 1, "小兄弟") == NpcApprenticeship.Outcome.RECRUITED, "one with less than 100 is taken")
	_check(request.lines.slice(0, 2) == ["你想要拜陆得财为师。", "陆得财正盯著你看，不知道打些什麽主意。"] and not request.lines.has("陆得财说道："), "the look, then the recruit (nod: nothing): %s" % [request.lines])
	_check(poor.affiliation.class_id == &"beggar" and poor.family.family_id == FAMILY and poor.family.generation == 5, "花紫会's fifth generation, a 叫化子")
	_check(RankWords.query_rank(poor.gender, poor.affiliation.class_id) == "【 叫化子 】", "rankd.c: 叫化子")


func _test_learn() -> void:
	var disciple: CharacterState = _member()
	for skill: StringName in [&"stealing", &"serpentforce", &"perception", &"unarmed", &"staff"]:
		_check((_learn(disciple, skill)[0] as LearnResult).success, "he teaches his apprentice %s" % skill)
	var claw: CharacterState = _member()
	claw.recovery.inner_force = CharacterInternalResourceState.new(0, 80)
	claw.equipment.wield(Martial.sword(), false) # TEST-ONLY
	_check(_learn(claw, &"spicyclaw")[1] == ["练油流麻香手必须空手。"], "with a weapon in hand: refused")
	var weak: CharacterState = _member()
	weak.recovery.inner_force = CharacterInternalResourceState.new(0, 79)
	_check(_learn(weak, &"spicyclaw")[1] == ["你的内力太弱，无法练油流麻香手。"], "max_force 79: refused")
	weak.recovery.inner_force = CharacterInternalResourceState.new(0, 80)
	_check((_learn(weak, &"spicyclaw")[0] as LearnResult).success, "bare hands, max_force 80: learnt")


func _test_practice() -> void:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var claw: CharacterState = _member()
	claw.skills.set_raw_level(&"unarmed", 10)
	claw.skills.set_raw_level(&"spicyclaw", 5)
	claw.skills.map_skill(&"unarmed", &"spicyclaw")
	claw.recovery.inner_force = CharacterInternalResourceState.new(3, 80)
	claw.vitality = CharacterResourceState.new(24, 100, 100)
	_check(_practice(claw, &"unarmed", registry) == ["你的体力不够了，休息一下再练吧。"] and claw.vitality.current == 24, "kee 24: its line, nothing paid")
	claw.vitality = CharacterResourceState.new(100, 100, 100)
	claw.recovery.inner_force.current = 2
	_check(_practice(claw, &"unarmed", registry) == ["你的内力不够了，休息一下再练吧。"], "force 2: its own line")
	claw.recovery.inner_force.current = 3
	var progress: int = claw.skills.learned_progress(&"spicyclaw")
	_practice(claw, &"unarmed", registry)
	_check(claw.vitality.current == 75 and claw.recovery.inner_force.current == 0 and claw.skills.learned_progress(&"spicyclaw") > progress, "25 kee and 3 force, progress")
	var force: CharacterState = _member()
	force.skills.set_raw_level(&"force", 10)
	force.skills.set_raw_level(&"serpentforce", 5)
	force.skills.map_skill(&"force", &"serpentforce")
	force.recovery.inner_force = CharacterInternalResourceState.new(10, 100)
	force.vitality = CharacterResourceState.new(100, 100, 100)
	_check(_practice(force, &"force", registry, false) == ["伏蛟功只能在有水的地方练。"] and force.vitality.current == 100 and force.recovery.inner_force.current == 10, "away from water: its line first, nothing paid")
	force.vitality = CharacterResourceState.new(29, 100, 100)
	_check(_practice(force, &"force", registry, true) == ["你的气不够。"], "by water, kee 29: 你的气不够。")
	force.vitality = CharacterResourceState.new(100, 100, 100)
	force.recovery.inner_force.current = 9
	_check(_practice(force, &"force", registry, true) == ["你的内力不够"], "force 9: 你的内力不够 (as written)")
	force.recovery.inner_force.current = 10
	_practice(force, &"force", registry, true)
	_check(force.vitality.current == 70 and force.recovery.inner_force.current == 0, "30 kee and 10 force by water")
	var offered: Array[StringName] = ExertService.offered(force, _catalog)
	_check(offered.has(&"recover") and offered.has(&"refresh") and offered.has(&"regenerate") and not offered.has(&"heal"), "伏蛟功 enabled: the basic force's exerts (its own exert files do not exist): %s" % [offered])


func _test_crime_record() -> void:
	var state: CharacterState = _student()
	CrimeRecord.add_thief(state, 3)
	CrimeRecord.reset(state)
	_check(CrimeRecord.thief(state) == 2, "user.c reset(): thief - 1")
	CrimeRecord.add_thief(state, 9)
	_check(RankWords.query_rank(state.gender, &"") == "【 平  民 】" and RankWords.query_rank(state.gender, &"", CrimeRecord.thief(state)) == "【 惯  窃 】", "thief 11: 惯窃 (rankd.c, before the class)")
	CrimeRecord.halve_thief(state)
	_check(CrimeRecord.thief(state) == 5, "halved at death: 5")
	CrimeRecord.add_thief(state, -5)
	_check(not state.counters.has(CrimeRecord.THIEF), "none left: deleted")
	state.progression.potential = 150
	state.progression.potential_spent = 51
	PlayerObjectReset.apply(state)
	_check(state.progression.potential == 151, "potential - learned 99: + 1")
	PlayerObjectReset.apply(state)
	_check(state.progression.potential == 151, "100 unspent: no more")
	var dying: CharacterState = _student()
	CrimeRecord.add_thief(dying, 7)
	PlayerDeathRules.die(dying, true)
	_check(CrimeRecord.thief(dying) == 3, "killer_reward(): thief / 2")


## settle_lawsuit()'s strokes: 10 - max / 100 off current and effective; one below it left at 1
## (repaired: ES2 then wounded it to -1, a death); all three so knocks out and ends it.
func _test_sentence_rule() -> void:
	_check(NpcSentence.stroke_of(0) == 10 and NpcSentence.stroke_of(450) == 6 and NpcSentence.stroke_of(1500) == 0, "10 - max / 100, at least 0")
	var strong: CharacterState = _student()
	strong.essence = CharacterResourceState.new(100, 100, 100)
	strong.vitality = CharacterResourceState.new(100, 100, 100)
	strong.spirit = CharacterResourceState.new(100, 100, 100)
	strong.recovery.inner_force = CharacterInternalResourceState.new(0, 450)
	var beating: NpcSentence.Beating = NpcSentence.beat(strong, 3)
	_check(beating.strokes == 3 and not beating.fainted and strong.essence.effective == 70 and strong.vitality.effective == 82 and strong.spirit.current == 70, "three strokes: gin and sen 30 off, kee 18 (max_force 450)")
	var weak: CharacterState = _student()
	weak.essence = CharacterResourceState.new(25, 25, 100)
	weak.vitality = CharacterResourceState.new(100, 100, 100)
	weak.spirit = CharacterResourceState.new(100, 100, 100)
	_check(not NpcSentence.beat(weak, 3).fainted and weak.essence.effective == 1 and weak.essence.current == 1, "gin 25: 15, 5, then left at 1 (not killed)")
	var spent: CharacterState = _student()
	spent.essence = CharacterResourceState.new(5, 5, 100)
	spent.vitality = CharacterResourceState.new(5, 5, 100)
	spent.spirit = CharacterResourceState.new(5, 5, 100)
	var out: NpcSentence.Beating = NpcSentence.beat(spent, 5)
	_check(out.fainted and out.strokes == 1 and spent.vitality.effective == 1 and spent.vitality.current == 1, "all three below a stroke: left at 1, knocked out, the beating over")
	var patrol: NpcPatrol = _catalog.npc(POLICE).dealings().patrol
	_check(patrol.next_zone(&"choyin.court1", false) == &"choyin.crossroad" and patrol.next_zone(&"choyin.court1", true).is_empty() and patrol.next_zone(&"choyin.n_gate", false).is_empty() and patrol.next_zone(&"choyin.s_street2", false) == &"choyin.s_street3", "patrol(): GO from the 衙门, BACK toward it, the ends")


# --- In the town --------------------------------------------------------------------

## 陆得财 (n_street1): a player with money is sent home; without, taken (class beggar).
func _test_join(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	_check(master != null, "陆得财 in the town")
	if master == null:
		return
	await _beside(tree, session, map, master)
	var context: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(context, CurrencyDenomination.Value.SILVER, 1, &"test.silver") # TEST-ONLY: 100 coins' worth
	var service: TeacherService = _teacher(map, master)
	_check(service != null and map.player_can_afford(100), "TEST-ONLY: a silver in the pack")
	service.request_apprentice()
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, &"")
	_check(service.last_lines == ["你想要拜陆得财为师。", "陆得财正盯著你看，不知道打些什麽主意。", "陆得财说道：我们花紫会只收化子，%s您还是回去享福吧。" % respect], "a silver: sent home: %s" % [service.last_lines])
	var aside: Array[Dictionary] = _money_aside(session)
	_check(not map.player_can_afford(1), "TEST-ONLY: no money on them")
	player.apprenticeship_request.affords = map.player_can_afford
	_check(player.would_be_taken_by(master.definition()), "the teacher panel would ask first (a first master)")
	service.request_apprentice()
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.state.affiliation.class_id == &"beggar" and player.shown_title() == "花紫会第五代弟子", "taken: 花紫会第五代弟子, a beggar: %s" % [service.last_lines])
	player.state.progression.potential = 1000 # TEST-ONLY
	var learned: LearnResult = service.request_learn(&"stealing")
	_check(learned != null and learned.success and player.state.skills.raw_level(&"stealing") >= 1, "he teaches 偷窃: %s" % [service.last_lines])
	_money_back(session, aside)


## 伏蛟功 on the 武学 page: at the well (resource/water) the practice happens; on the street not.
func _test_water(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	var kept: Array = _kept(state)
	state.skills.set_raw_level(&"force", 10) # TEST-ONLY
	state.skills.set_raw_level(&"serpentforce", 5)
	state.skills.map_skill(&"force", &"serpentforce")
	state.recovery.inner_force = CharacterInternalResourceState.new(50, 100)
	state.vitality = CharacterResourceState.new(state.vitality.effective, state.vitality.effective, state.vitality.maximum)
	var dry: PracticeResult = session.martial_arts().practice(&"force")
	_check(dry != null and not dry.success and dry.refusal == &"water" and session.shared_ui().log_lines()[-1] == "伏蛟功只能在有水的地方练。", "on the street: 伏蛟功只能在有水的地方练。")
	_check(map.place_player(&"choyin.s_street1", MapPlaces.spot(map, &"choyin.s_street1", MapPlaces.zone_centre(map, &"choyin.s_street1"))), "TEST-ONLY: by the 南门广场's well")
	await tree.physics_frame
	var force: int = state.recovery.inner_force.current
	var wet: PracticeResult = session.martial_arts().practice(&"force")
	_check(wet != null and wet.success and state.recovery.inner_force.current == force - 10, "by the well: practised (10 force)")
	state.skills.unmap_skill(&"force")
	_restore(state, kept)


## steal.c on a 书生 (bridge2): the list shows what it wears; taken, unnoticed, caught.
func _test_steal(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var scholar: NpcRuntimeState = _first(map, SCHOLAR)
	_check(scholar != null, "a 书生 on the bridge")
	if scholar == null:
		return
	await _beside(tree, session, map, scholar)
	map.select_npc(scholar.character_id)
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(hud.nearby.actions_of(scholar.definition().short_name()).has("偷窃") and map.thefts.can_steal_selected(), "偷窃 on the selected 书生")
	var seen: Array[StringName] = map.thefts.seen_items(scholar)
	_check(seen.size() == 1 and map.thefts.item_name(seen[0]) == "布衣", "look.c shows his 布衣 (worn), not the book: %s" % [seen])
	_check(not map.thefts.asks_first(scholar), "a 书生 (10 exp) is no stronger: not asked")
	hud.steal_button.pressed.emit()
	_check(hud.steal_panel.is_visible_in_tree() and hud.steal_panel.shown_items() == ["布衣"], "the list: 布衣, then 随手摸一样")
	# Taken: random(sp + dp) > dp; then improve_skill's random(int) and the onlookers' random(sp).
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([100000, 0, 0])) # TEST-ONLY
	hud.steal_panel.chosen.emit(seen[0])
	_check(hud.log_lines()[-1] == "你不动声色地慢慢靠近书生，等待机会下手 ..." and map.thefts.is_stealing() and not hud.steal_panel.is_visible_in_tree(), "its line; the hand waits")
	map.thefts.begin(scholar, &"")
	_check(hud.log_lines()[-1] == "你已经在找机会下手了！", "a second steal meanwhile: refused")
	map.npc_life._advance_ambience(2.9)
	_check(map.thefts.is_stealing(), "2.9 s: not yet")
	map.npc_life._advance_ambience(0.2)
	_check(hud.log_lines().slice(-2) == ["得手了！", "你成功地偷到一件布衣！"] and _carries(session, seen[0]) and not scholar.armor.is_worn(seen[0]), "得手了！ the 布衣 is the player's, off his back: %s" % [hud.log_lines().slice(-3)])
	# Unnoticed: random(sp + dp) <= dp, random(sp) > dp / 2.
	var thief: int = CrimeRecord.thief(player.state)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 0, 100000])) # TEST-ONLY: the pick, then the two rolls
	map.thefts.begin(scholar, &"")
	map.npc_life._advance_ambience(3.0)
	_check(hud.log_lines().slice(-2) == ["书生不经意地一转头，你急忙将手缩了回去！", "还好，没有被发现。"] and CrimeRecord.thief(player.state) == thief, "unnoticed: nothing comes of it")
	# Caught: both rolls low.
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 0, 0])) # TEST-ONLY
	map.thefts.begin(scholar, &"")
	map.npc_life._advance_ambience(3.0)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter() and CrimeRecord.thief(player.state) == thief + 1 and player.busy.busy_value > 0, "caught: a fight, thief + 1, busy")
	var lines: Array[String] = hud.log_lines()
	_check(lines.has("糟糕！你失手了！") and lines.any(func(line: String) -> bool: return line.begins_with("书生一回头，正好发现你的手正抓著他身上的")), "失手了！ and what his hand was on: %s" % [lines.slice(-4)])
	_check(lines.has("书生喝道：「干什麽！」"), "干什麽！")
	session.configure_world_interaction_random_source(original)
	scholar.character_state.vitality.apply_wound(scholar.character_state.vitality.effective + 1) # TEST-ONLY: the last blow
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 30:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "TEST-ONLY: the fight over")
	hud.dismiss_current_panel()
	# One clearly stronger asks first (a 巡捕, 500000 exp); 取消 shows the list again.
	var police: NpcRuntimeState = _first(map, POLICE)
	await _beside(tree, session, map, police)
	map.select_npc(police.character_id)
	hud.refresh_live_state()
	hud.steal_button.pressed.emit()
	var shown: Array[String] = hud.steal_panel.shown_items()
	_check(shown.has("乌檀木刀") and shown.has("布衣") and not shown.has("平安符"), "a 巡捕: his blade and cloth, not the amulet he only carries: %s" % [shown])
	hud.steal_panel.chosen.emit(&"")
	_check(hud.is_asking() and hud.confirm_prompt.message.text.begins_with("%s看起来比你强得多" % police.definition().display_name), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not map.thefts.is_stealing() and hud.steal_panel.is_visible_in_tree(), "取消: no steal, the list again")
	hud.dismiss_current_panel()


## A 巡捕 walks its beat wherever the player is; one meeting a thief catches them (random(10) <
## 7): its say, crime_lv + 3, thief - 1; it leads them back toward the 衙门, their walking refused.
func _test_patrol(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var police: NpcRuntimeState = map.find_resident_npc(&"choyin.n_gate.yamen_po.1.character")
	_check(police != null and SURNAMES.has(police.definition().display_name) and NpcDefinition.unnamed_id(police.definition_id) == POLICE and police.definition_id != POLICE, "the 北门's 巡捕 drew a name: %s" % (police.definition().display_name if police != null else "none"))
	if police == null:
		return
	# Away from the player, it walks: at the 北门 (the beat's end) it turns back south.
	_check(not map.npc_life.player_shares_zone(police), "TEST-ONLY: the player is elsewhere")
	map.patrols.step(police)
	_check(police.world_location().zone_id == &"choyin.n_street1" and police.has_flag(WorldMapPatrols.FLAG_BACK), "it turns at the 北门 and walks south")
	map.npc_life.npc_walker().finish_all()
	# No thief: meeting passes.
	await _beside(tree, session, map, police)
	CrimeRecord.add_thief(player.state, -CrimeRecord.thief(player.state))
	session.configure_npc_ambience_random_source(Lowest.new()) # TEST-ONLY: random(10) = 0
	map.patrols.meet(police)
	_check(not player.in_custody(), "no caught steal on record: it passes by")
	CrimeRecord.add_thief(player.state, 2) # TEST-ONLY
	session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([7])) # TEST-ONLY
	map.patrols.meet(police)
	_check(not player.in_custody(), "random(10) 7: not caught")
	var crime: int = CrimeRecord.crime(player.state)
	session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([6])) # TEST-ONLY
	map.patrols.meet(police)
	_check(player.led_by == police.character_id and CrimeRecord.crime(player.state) == crime + 3 and CrimeRecord.thief(player.state) == 1, "random(10) 6: caught: crime_lv + 3, thief - 1")
	_check(hud.log_lines().slice(-2) == [CAUGHT_SAY, "（%s要把你押到县衙受审：被押着走不开；可以向他行贿，也可以拒捕跟他动手。）" % police.definition().display_name], "its say and the hint: %s" % [hud.log_lines().slice(-2)])
	_check(map.selected_character_id() == police.character_id, "it is selected (its 行贿 at hand)")
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	# Held: their own walking does nothing.
	var body: WorldCharacterBody2D = map.runtime_player_body()
	var at: Vector2 = body.global_position
	MapPlaces.push(tree, &"move_down", 30)
	await MapPlaces.push(tree, &"move_down", 30)
	MapPlaces.release()
	await tree.physics_frame
	_check(body.global_position.distance_to(at) < 2.0 and hud.log_lines().has("嘿嘿, 还想往哪逃?!"), "the player cannot walk away: 嘿嘿, 还想往哪逃?!")
	_check(OldPineSaveEligibility.inspect(session).outcome == OldPineSaveEligibilityResult.Outcome.BUSY, "Save waits while led")
	# A step: it walks back toward the 衙门, the player after it.
	var from: StringName = police.world_location().zone_id
	map.patrols.step(police)
	for _frame: int in range(240):
		await tree.physics_frame
		map.npc_life.npc_walker().advance(1.0 / 60.0)
	_check(police.world_location().zone_id == &"choyin.n_street2" and player.world_location().zone_id == &"choyin.n_street2", "from %s it leads the player south to n_street2" % from)


## 行贿 on the way: less than ten gold is refused (crime_lv + 1), ten gold frees them (crime_lv - 3).
func _test_bribe(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var police: NpcRuntimeState = map.find_resident_npc(player.led_by)
	if police == null:
		_check(false, "led by a 巡捕")
		return
	var context: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(context, CurrencyDenomination.Value.GOLD, 12, &"test.gold") # TEST-ONLY
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(hud.nearby.actions_of(police.definition().short_name()).has("行贿") and map.patrols.can_bribe(police), "行贿 on the 巡捕 leading the player")
	hud.bribe_button.pressed.emit()
	_check(hud.bribe_panel.is_visible_in_tree() and hud.bribe_panel.shown_money().has("黄金"), "the money they carry: %s" % [hud.bribe_panel.shown_money()])
	var crime: int = CrimeRecord.crime(player.state)
	map.patrols.bribe(&"test.gold", 9)
	_check(player.led_by == police.character_id and CrimeRecord.crime(player.state) == crime + 1 and hud.log_lines()[-1] == "你这是什么意思?......谁稀罕你的钱?!" and Finance.amount(context, CurrencyDenomination.Value.GOLD) == 12, "nine gold: refused, crime_lv + 1, the money kept")
	_check(map.patrols.last_lines == ["你这是什么意思?......谁稀罕你的钱?!"], "the panel's line under its rows (the log may be full)")
	# A step ahead of the player (its place changes as its walk starts): still bribable.
	map.patrols.step(police)
	_check(police.world_location().zone_id != player.world_location().zone_id and map.patrols.can_bribe(police), "a step ahead of the one it leads: 行贿 still at hand")
	for _frame: int in range(240):
		await tree.physics_frame
		map.npc_life.npc_walker().advance(1.0 / 60.0)
	var gold: StringName = context.select(CurrencyDenomination.Value.GOLD).item_id
	map.patrols.bribe(gold, 10)
	_check(not player.in_custody() and CrimeRecord.crime(player.state) == crime + 1 - 3 and hud.log_lines().slice(-2) == ["这怎么好?......要是让老爷知道了......", "盛情难却....我就收下了.."] and Finance.amount(context, CurrencyDenomination.Value.GOLD) == 2, "ten gold: free, crime_lv - 3, the gold his")
	_check(not police.has_flag(WorldMapPatrols.FLAG_BACK), "back to its beat (GO)")
	hud.dismiss_current_panel()


## Led to the 衙门口 and into the 大堂; 程不平's boards two seconds later, the crime cleared, out
## at the 衙门口.
func _test_court(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var police: NpcRuntimeState = map.find_resident_npc(&"choyin.crossroad.yamen_po.1.character")
	_check(police != null, "the crossroad's 巡捕")
	if police == null:
		return
	await _beside(tree, session, map, police)
	CrimeRecord.add_thief(player.state, 1) # TEST-ONLY
	CrimeRecord.clear_crime(player.state)
	session.configure_npc_ambience_random_source(Lowest.new()) # TEST-ONLY
	map.patrols.meet(police)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	_check(player.led_by == police.character_id and CrimeRecord.crime(player.state) == 3, "caught at the crossroad: crime_lv 3")
	var state: CharacterState = player.state
	var kept: Array = _kept(state)
	state.essence = CharacterResourceState.new(200, 200, 200) # TEST-ONLY
	state.vitality = CharacterResourceState.new(200, 200, 200)
	state.spirit = CharacterResourceState.new(200, 200, 200)
	state.recovery.atman = CharacterInternalResourceState.new(0, 0)
	state.recovery.inner_force = CharacterInternalResourceState.new(0, 0)
	state.recovery.mana = CharacterInternalResourceState.new(0, 0)
	map.patrols.step(police)
	for _frame: int in range(240):
		await tree.physics_frame
		map.npc_life.npc_walker().advance(1.0 / 60.0)
	_check(police.world_location().zone_id == &"choyin.court1" and player.world_location().zone_id == &"choyin.court1", "led north to the 衙门口")
	map.patrols.step(police)
	await tree.physics_frame
	await tree.physics_frame
	var court: WorldMapController = session.active_map() as WorldMapController
	_check(court.map_id() == &"choyin.yamen_compound" and player.world_location().zone_id == &"choyin.yamen" and player.awaiting_sentence and player.led_by.is_empty(), "into the 大堂")
	_check(hud.log_lines()[-1] == "老爷，人犯已带到，小人巡街去了。" and not police.has_flag(WorldMapPatrols.FLAG_BACK), "老爷，人犯已带到; it goes back to its beat")
	court.npc_life._advance_ambience(0.0)
	court.npc_life._advance_ambience(1.9)
	_check(player.awaiting_sentence, "1.9 s: not yet")
	court.npc_life._advance_ambience(0.2)
	await tree.physics_frame
	await tree.physics_frame
	var lines: Array[String] = hud.log_lines()
	var judge: String = _catalog.npc(JUDGE).display_name
	_check(lines.has("来人哪！把你拖下去打三十大板！") and lines.has("%s对你说道: 再敢犯案, 定斩不饶!" % judge) and lines.count("%s对你说道: 再敢犯案, 定斩不饶!" % judge) == 1, "the boards and the warning, once: %s" % [lines.slice(-4)])
	_check(state.essence.effective == 170 and state.vitality.effective == 170 and state.spirit.effective == 170, "three strokes of 10 off each")
	_check(CrimeRecord.crime(state) == 0 and not player.in_custody(), "the crime cleared (owner Q1), free")
	_check((session.active_map() as WorldMapController).map_id() == &"choyin.town" and player.world_location().zone_id == &"choyin.court1" and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "out at the 衙门口")
	_restore(state, kept) # Continue recomputes the maxima: no TEST-ONLY ones in the save


## The custody ends when the leader is knocked out (it holds nobody) and when the player gets
## to another map some other way (a hole, a lift: set_leader() holds in one room).
func _test_custody_ends(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var police: NpcRuntimeState = map.find_resident_npc(&"choyin.tree_tomb.yamen_po.1.character")
	if police == null:
		_check(false, "the 树王坟's 巡捕")
		return
	await _beside(tree, session, map, police)
	CrimeRecord.add_thief(player.state, 2) # TEST-ONLY
	session.configure_npc_ambience_random_source(Lowest.new()) # TEST-ONLY
	map.patrols.meet(police)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	_check(player.led_by == police.character_id, "caught at the 树王坟")
	police.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: knocked out
	map.patrols.hold_player()
	_check(not player.in_custody() and not map.runtime_player_body().held, "its leader knocked out: free")
	police.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	session.configure_npc_ambience_random_source(Lowest.new()) # TEST-ONLY
	map.patrols.meet(police)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	map.patrols.hold_player()
	_check(player.led_by == police.character_id and map.runtime_player_body().held, "caught again, held")
	# The 树王坟's hole is no way out while led (the hint promises 行贿 and a fight only).
	_check(map.select_landmark(&"choyin.tree_tomb.landmark.hole"), "the hole selected")
	map.traverse_selected_portal()
	_check(player.led_by == police.character_id and player.world_location().zone_id == &"choyin.tree_tomb" and session.shared_ui().log_lines()[-1] == "嘿嘿, 还想往哪逃?!", "爬下去 while led: refused, 嘿嘿, 还想往哪逃?!")
	_check(not session.essence_magic().drift_begin() or not player.in_custody(), "游识 while led: refused")
	map.select_npc(police.character_id)
	_check(session.handoff_to(&"choyin.temple_altar", &"choyin.altar", &"choyin.altar", &"choyin.altar.stairs_arrival").succeeded(), "TEST-ONLY: moved to another map all the same")
	await tree.physics_frame
	_check(not player.in_custody() and not map.runtime_player_body().held, "on another map: whoever led them stays behind (a safety net)")
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "TEST-ONLY: back in the town")
	await tree.physics_frame
	await tree.physics_frame
	# Led, the player attacks it and flees: away (go.c's do_flee()).
	map = session.active_map() as WorldMapController
	police = map.find_resident_npc(&"choyin.tree_tomb.yamen_po.1.character")
	await _beside(tree, session, map, police)
	CrimeRecord.add_thief(player.state, 1) # TEST-ONLY
	session.configure_npc_ambience_random_source(Lowest.new()) # TEST-ONLY
	map.patrols.meet(police)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	map.select_npc(police.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(player.led_by == police.character_id and map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "led, the player attacks it (拒捕)")
	var police_kee: CharacterResourceState = police.character_state.vitality
	var kept: Array = _kept(player.state)
	police.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: the fight lasts
	player.state.vitality = CharacterResourceState.new(100000, 100000, player.state.vitality.maximum + 100000)
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(info.action_id, coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and coordinator.last_completion() != null and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.FLED, "fled the fight")
	map.patrols.hold_player()
	_check(not player.in_custody() and not map.runtime_player_body().held, "fled: away from the one leading them")
	session.shared_ui().dismiss_current_panel()
	for opponent_id: StringName in player.relationship.opponent_ids(): # TEST-ONLY: as walking away would
		player.relationship.remove_lethal_relation(opponent_id)
		player.relationship.remove_opponent(opponent_id)
	for opponent_id: StringName in police.relationship.opponent_ids():
		police.relationship.remove_lethal_relation(opponent_id)
		police.relationship.remove_opponent(opponent_id)
	police.character_state.vitality = police_kee
	_restore(player.state, kept)


## yamen_po.c die(): its killer gets crime_lv + 5.
func _test_killed(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var police: NpcRuntimeState = map.find_resident_npc(&"choyin.s_street4.yamen_po.1.character")
	if police == null:
		_check(false, "the s_street4 巡捕")
		return
	await _beside(tree, session, map, police)
	map.select_npc(police.character_id)
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	var crime: int = CrimeRecord.crime(player.state)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 巡捕")
	police.character_state.vitality.apply_wound(police.character_state.vitality.effective + 1) # TEST-ONLY: the last blow
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 30:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(police.life_status == CharacterRuntimeLifeStatus.Value.DEAD and CrimeRecord.crime(player.state) == crime + 5 and CombatEncounterCoordinator.take_aborted_total() == 0, "killed: crime_lv + 5")
	session.shared_ui().dismiss_current_panel()
	await tree.physics_frame


## A 巡捕's drawn name survives Save/Continue; thief and crime_lv are saved.
func _test_save(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	CrimeRecord.add_thief(player.state, 2) # TEST-ONLY
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save outside custody")
	if snapshot == null:
		return
	var named: Array[String] = []
	for record: GameSaveValueTypes.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		if NpcDefinition.unnamed_id(record.npc_definition_id) == POLICE:
			named.append(String(record.npc_definition_id))
	_check(named.size() == 8 and named.all(func(id: String) -> bool: return id.contains(NpcDefinition.NAME_SUFFIX)), "the 巡捕 are saved as their named forms: %s" % [named])
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "乔阴 D")
	_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))


# --- Helpers ------------------------------------------------------------------------

## TEST-ONLY: the player's resources as they were, put back before a save.
static func _kept(state: CharacterState) -> Array:
	return [state.essence, state.vitality, state.spirit, state.recovery.atman, state.recovery.inner_force, state.recovery.mana]


static func _restore(state: CharacterState, kept: Array) -> void:
	state.essence = kept[0]
	state.vitality = kept[1]
	state.spirit = kept[2]
	state.recovery.atman = kept[3]
	state.recovery.inner_force = kept[4]
	state.recovery.mana = kept[5]


static func _fresh() -> CharacterState:
	return NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "得财").state


static func _student() -> CharacterState:
	var state: CharacterState = _fresh()
	state.progression.potential = 100 # TEST-ONLY
	return state


## 陆得财's apprentice with potential to spend.
func _member() -> CharacterState:
	var state: CharacterState = _student()
	NpcApprenticeship.new().request(state, _catalog.npc(MASTER), _catalog.family(FAMILY), 1, "小兄弟")
	return state


func _learn(student: CharacterState, skill_id: StringName) -> Array:
	var definition: NpcDefinition = _catalog.npc(MASTER)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"choyin.town.n_street1.test", &"choyin.n_street1.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
	var random := ScriptedWorldInteractionRandomSource.new([0])
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, false, random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = _catalog.skill(skill_id)
	var result: LearnResult = LearnService.learn(student, context, skill, registry.policy_for(skill_id), null, random)
	var respect: String = RankWords.query_respect(student.gender, 14, student.affiliation.class_id)
	return [result, LearnLines.lines(result, definition.display_name, skill, student, context, respect)]


func _practice(state: CharacterState, use_id: StringName, registry: SkillLearnPolicyRegistry, at_water: bool = true) -> Array[String]:
	var special: StringName = state.skills.mapped_skill(use_id)
	var skill: SkillDefinition = _catalog.skill(special)
	var result: PracticeResult = PracticeService.practice(state, use_id, skill.practice_policy(), registry.policy_for(special), false, true, null, Callable(), "", at_water)
	return ColoredLine.texts(TrainingLines.practice(result, skill))


func _teacher(map: WorldMapController, npc: NpcRuntimeState) -> TeacherService:
	for service: WorldService in map.service_nodes:
		if service is TeacherService and npc != null and (service as TeacherService).npc.character_id == npc.character_id:
			return service as TeacherService
	return null


## TEST-ONLY: the player beside the NPC.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 60.0)
	if at == Vector2.INF:
		at = MapPlaces.spot(map, zone_id, body.global_position, 140.0)
	_check(at != Vector2.INF and map.place_player(zone_id, at), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if NpcDefinition.unnamed_id(npc.definition_id) == definition_id and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return npc
	return null


func _carries(session: WorldSessionController, item_id: StringName) -> bool:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)).has(item_id)


## TEST-ONLY: the player's money into a holder of its own for a while.
func _money_aside(session: WorldSessionController) -> Array[Dictionary]:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var aside := ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"choyin.test_aside")
	var moved: Array[Dictionary] = []
	for id: StringName in context.inventory.direct_children(context.endpoint()):
		var content: ItemContentDefinition = _catalog.item(context.index.resolve(id).item_definition_id)
		if content != null and content.currency_base_value > 0:
			assert(InventoryTransferService.new().transfer(context.inventory, id, InventoryTransferDestination.new(aside, true, true, 1000000)).succeeded)
			moved.append({"id": id})
	return moved


func _money_back(session: WorldSessionController, moved: Array[Dictionary]) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	for held: Dictionary in moved:
		assert(InventoryTransferService.new().transfer(context.inventory, held["id"], InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)).succeeded)


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("choyin law: " + label)
