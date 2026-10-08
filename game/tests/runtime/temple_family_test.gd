extends RefCounted

## 茅山 B: 茅山派. 林忌 takes only men and answers two seconds after 拜师 (taolord.c
## attempt_apprentice()'s call_out("do_recruit", 2); 慢著，一个一个来 while that answer is
## due; class taoist); 僵尸侍者 and 僵尸护法 (privs -1) teach any member and nobody else;
## 谷衣心法 (max_mana five times its level; 灵神诀 and 疗伤), 天师正道 (杀气 100 at most),
## 茅山道术 (天师正道 half of it; its practice and the 观想虫, 茅山 C), 天师剑法 (max_force 80,
## practised with a sword); then the real session in the 大殿: a woman refused after the
## wait, an answer nobody is there to
## hear, one lying there, an unconscious 林忌, the answer dropped when the player leaves the
## map, a man taken (asked first as a first master), learning, the 藏经楼 open to him,
## 灵神诀 on the 武学 page and in a fight (where the answer waits), 紫光 cast at 僵尸护法,
## Save/Continue. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Master := preload("res://tests/support/snow_master.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.taoist.taolord"
const TRAINER: StringName = &"temple.npc.trainer"
const TFIGHTER: StringName = &"temple.npc.tfighter"
const FAMILY: StringName = &"family.maoshan"
const LONGSWORD: StringName = &"es2:obj/longsword"
const ASKED: String = "你想要拜林忌为师。"
const TAKES: String = "林忌说道：嗯... 想入我茅山派？也好...."
const NO_WOMEN: String = "林忌说道：贫道是出家人，不便收女徒，得罪了。"
const BUSY: String = "林忌说道：慢著，一个一个来。"
const CONCENTRATE: Array[String] = ["你闭目凝神，用谷衣心法的内力运转了一次「灵神诀」...", "一股青气从你身上散出，汇聚在你的顶心，然後缓缓淡去。"]


## Draws by bound: each bound's queue first, then the highest value (no chat fires).
class Forced extends CombatRandomSource:
	var queues: Dictionary[int, Array] = {}
	func next_below(bound: int) -> int:
		var queue: Array = queues.get(bound, [])
		if not queue.is_empty():
			return clampi(queue.pop_front(), 0, bound - 1)
		return bound - 1


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog
var _original_random: CombatRandomSource


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_apprentice_rule()
	_test_learn()
	_test_practice()
	_test_necromancy_practice()
	_test_conjured_npcs()
	_test_concentrate()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	_original_random = session.combat_random_source()
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"temple.grounds", &"temple.square", &"temple.square", &"temple.square.gate_arrival").succeeded(), "TEST-ONLY: inside the gate")
	await tree.physics_frame
	await tree.physics_frame
	await _test_refused(tree, session)
	await _test_nobody_hears(tree, session)
	await _test_answer_cases(tree, session)
	await _test_join(tree, session)
	_test_library(session)
	_test_concentrate_page(session)
	await _test_concentrate_fight(tree, session)
	await _test_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Data ---------------------------------------------------------------------------

func _test_data() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var rule: NpcTeaching.ApprenticeRule = master.teaching().apprentice
	_check(rule != null and rule.kind == NpcTeaching.Kind.REQUIREMENTS and rule.class_id == &"taoist" and rule.answer_after == 2.0 and rule.busy_say == "慢著，一个一个来。", "林忌: a requirements master who answers two seconds later, class taoist")
	_check(rule.checks.size() == 1 and rule.checks[0].gender == "男性" and rule.checks[0].requires.is_empty() and rule.checks[0].refuse_say == "贫道是出家人，不便收女徒，得罪了。" and rule.accept_say == "嗯... 想入我茅山派？也好....", "men only, with do_recruit()'s two says")
	_check(master.teaching().family_id == FAMILY and master.teaching().family_generation == 5 and master.teaching().f_master, "茅山派's fifth 天师, an F_MASTER")
	var taught: Array[StringName] = NpcTeacher.teachable_skills(master, _catalog)
	_check(taught.size() == 12 and taught.has(&"gouyee") and taught.has(&"taoism") and taught.has(&"necromancy") and taught.has(&"scratching") and taught.has(&"spells"), "he teaches all twelve of his skills: %s" % [taught])
	for id: StringName in [TRAINER, TFIGHTER]:
		var teaching: NpcTeaching = _catalog.npc(id).teaching()
		_check(teaching.family_id == FAMILY and teaching.family_generation == 6 and teaching.family_privileges == -1 and not teaching.f_master and teaching.apprentice == null and teaching.recognize_rules.is_empty(), "%s: 茅山派's sixth generation, privs -1, takes no apprentice" % id)
	_check(NpcTeacher.teachable_skills(_catalog.npc(TRAINER), _catalog).size() == 12 and NpcTeacher.teachable_skills(_catalog.npc(TFIGHTER), _catalog).size() == 11, "僵尸侍者 teaches twelve skills, 僵尸护法 eleven (no 天师剑法)")
	for id: StringName in [&"temple.npc.taoist", &"temple.npc.taoist2", &"temple.npc.guard_taoist1"]:
		_check(_catalog.npc(id).teaching() == null, "%s has no family: teaches nothing" % id)
	var gouyee: SkillDefinition = _catalog.skill(&"gouyee")
	_check(gouyee.exert_functions == [&"concentrate", &"heal"] and ExertFunctions.LABELS[&"concentrate"] == "灵神诀", "谷衣心法: 灵神诀 and 疗伤 (doc/skill/gouyee)")
	var catalog := BattleActionPresentationCatalog.new()
	var action: StringName = CombatExertTacticalPolicy.action_id_for(&"concentrate")
	_check(catalog.label_for(action) == "运功灵神诀" and catalog.tooltip_for(action) == "运功灵神诀：用 30 点内力和 10 点神恢复法力", "the battle button and its hover: %s" % catalog.tooltip_for(action))
	_check(_catalog.skill(&"taoism").kind == SkillDefinition.Kind.BASIC and _catalog.skill(&"taoism").skill_type == SkillDefinition.Type.KNOWLEDGE, "天师正道: a basic knowledge")


# --- Joining ------------------------------------------------------------------------

func _test_apprentice_rule() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var family: FamilyDefinition = _catalog.family(FAMILY)
	var man: CharacterState = _fresh(CharacterState.GENDER_MALE)
	var request := NpcApprenticeship.new()
	_check(request.takes_at_once(man, master), "a man would be taken (the panel asks first)")
	_check(request.request(man, master, family, 1, "壮士") == NpcApprenticeship.Outcome.ANSWER_DUE and request.lines == [ASKED], "拜师: only his request so far: %s" % [request.lines])
	_check(request.is_pending_with(MASTER) and not man.family.has_family() and not request.takes_at_once(man, master), "the request waits on him")
	_check(request.request(man, master, family, 2, "壮士") == NpcApprenticeship.Outcome.PENDING and request.lines == ["你想拜林忌为师，但是对方还没有答应。"], "asked again: 对方还没有答应 (apprentice.c)")
	_check(request.answer(man, master, family, 3, "壮士") == NpcApprenticeship.Outcome.RECRUITED, "his answer takes him")
	_check(request.lines == [TAKES, "林忌决定收你为弟子。", "你跪了下来向林忌恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为茅山派的第六代弟子。"], "也好, then recruit.c: %s" % [request.lines])
	_check(NpcApprenticeship.is_master_of(man, master) and man.family.family_id == FAMILY and man.family.generation == 6 and man.affiliation.class_id == &"taoist" and man.affiliation.entry_time_utc == 3 and not request.is_pending(), "茅山派's sixth generation, class taoist")
	_check(NpcApprenticeship.family_title("茅山派", 6, man.affiliation.family_title) == "茅山派第六代弟子" and RankWords.query_rank(man.gender, &"taoist") == "【 道  士 】", "茅山派第六代弟子, a 道士")
	_check(request.request(man, master, family, 4, "道长") == NpcApprenticeship.Outcome.ACKNOWLEDGED, "his apprentice greets him")
	# A woman: the answer refuses; the request still waits (apprentice.c), until withdrawn.
	var woman: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	request = NpcApprenticeship.new()
	_check(not request.takes_at_once(woman, master), "a woman would not be taken (no question)")
	_check(request.request(woman, master, family, 1, "姑娘") == NpcApprenticeship.Outcome.ANSWER_DUE, "a woman's 拜师 waits for his answer too")
	_check(request.answer(woman, master, family, 2, "姑娘") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == [NO_WOMEN] and not woman.family.has_family(), "不便收女徒: %s" % [request.lines])
	_check(request.request(woman, master, family, 3, "姑娘") == NpcApprenticeship.Outcome.PENDING, "her request still waits on him")
	# Withdrawn and asked again while his answer is due: 慢著; the answer then takes him.
	var other: CharacterState = _fresh(CharacterState.GENDER_MALE)
	request = NpcApprenticeship.new()
	request.request(other, master, family, 1, "壮士")
	request.cancel()
	_check(request.request(other, master, family, 2, "壮士", NpcApprenticeship.COMMONER_TITLE, "", "", true) == NpcApprenticeship.Outcome.MASTER_BUSY and request.lines == [ASKED, BUSY] and request.is_pending_with(MASTER), "asked while his answer is due: 慢著，一个一个来: %s" % [request.lines])
	_check(request.answer(other, master, family, 3, "壮士") == NpcApprenticeship.Outcome.RECRUITED and NpcApprenticeship.is_master_of(other, master), "the one answer takes him")
	# Withdrawn, not asked again: his recruit is an offer, taken by the next 拜师.
	var third: CharacterState = _fresh(CharacterState.GENDER_MALE)
	request = NpcApprenticeship.new()
	request.request(third, master, family, 1, "壮士")
	request.cancel()
	_check(request.answer(third, master, family, 2, "壮士") == NpcApprenticeship.Outcome.OFFERED and request.lines == [TAKES, "林忌想要收你为弟子。", "如果你愿意拜林忌为师父，就向他拜师。"] and not third.family.has_family(), "withdrawn: 也好, then an offer: %s" % [request.lines])
	_check(request.takes_at_once(third, master) and request.request(third, master, family, 3, "壮士") == NpcApprenticeship.Outcome.RECRUITED and request.lines[0] == "你决定拜林忌为师。", "拜师 takes the offer at once")
	# A 封山剑派 disciple: his answer is a betrayal (asked first on the panel).
	var swordsman: CharacterState = _fresh(CharacterState.GENDER_MALE)
	Master.recruit(swordsman, 1)
	swordsman.progression.score = 120
	request = NpcApprenticeship.new()
	_check(NpcApprenticeship.would_betray(swordsman, master) and request.takes_at_once(swordsman, master), "柳淳风's disciple would betray 封山剑派")
	request.request(swordsman, master, family, 2, "壮士")
	_check(request.answer(swordsman, master, family, 3, "壮士") == NpcApprenticeship.Outcome.RECRUITED and request.lines[1] == "你决定背叛师门，改投入林忌门下！！", "betrayal: %s" % [request.lines])
	_check(swordsman.family.family_id == FAMILY and swordsman.progression.score == 0 and swordsman.apprenticeship.betrayer_count == 1 and swordsman.affiliation.class_id == &"taoist", "score 0, one betrayal, a 道士 now")


# --- Learning -----------------------------------------------------------------------

func _test_learn() -> void:
	var stranger: CharacterState = _student(CharacterState.GENDER_MALE)
	for id: StringName in [TRAINER, TFIGHTER]:
		var refused: Array = _learn(stranger, id, &"sword", [0])
		_check((refused[0] as LearnResult).failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT and refused[1].size() == 1 and _reject_lines(_catalog.npc(id).display_name).has(refused[1][0]), "%s politely refuses one not of 茅山派 (no recognize_apprentice()): %s" % [id, refused[1]])
	var disciple: CharacterState = _member()
	for id: StringName in [TRAINER, TFIGHTER, MASTER]:
		_check((_learn(disciple, id, &"sword", [0])[0] as LearnResult).success, "%s teaches 林忌's apprentice" % id)
	# 谷衣心法: max_mana five times query_skill("gouyee") (half the raw level).
	var mind: CharacterState = _member()
	_check((_learn(mind, MASTER, &"gouyee", [0])[0] as LearnResult).success, "谷衣心法's first level needs no mana (0 * 5)")
	mind.skills.set_raw_level(&"gouyee", 10) # TEST-ONLY
	mind.recovery.mana = CharacterInternalResourceState.new(0, 24)
	var short: Array = _learn(mind, MASTER, &"gouyee", [0])
	_check(not (short[0] as LearnResult).success and short[1] == ["你的魔力不够，无法提升谷衣心法的造诣。"], "at 10 (query_skill 5) max_mana 24 is short of 25: %s" % [short[1]])
	mind.recovery.mana = CharacterInternalResourceState.new(0, 25)
	_check((_learn(mind, MASTER, &"gouyee", [0])[0] as LearnResult).success, "25 is enough")
	# 天师正道: 杀气 above 100 stops it.
	var calm: CharacterState = _member()
	calm.attributes.bellicosity = 101 # TEST-ONLY
	_check(_learn(calm, MASTER, &"taoism", [0])[1] == ["你的杀气太重，无法修炼天师正道。"], "杀气 101: 天师正道 refused")
	calm.attributes.bellicosity = 100
	_check((_learn(calm, MASTER, &"taoism", [0])[0] as LearnResult).success, "杀气 100: learnt")
	# 茅山道术: query_skill("taoism") at least half of query_skill("necromancy").
	var magus: CharacterState = _member()
	magus.skills.set_raw_level(&"necromancy", 10) # TEST-ONLY: query_skill 5, half of it 2
	magus.skills.set_raw_level(&"taoism", 3) # query_skill 1
	_check(_learn(magus, MASTER, &"necromancy", [0])[1] == ["你的天师正道修为不够，无法领悟更高深的茅山道术。"], "天师正道 1 is short of 2")
	magus.skills.set_raw_level(&"taoism", 4)
	_check((_learn(magus, MASTER, &"necromancy", [0])[0] as LearnResult).success, "天师正道 2: 茅山道术 learnt")
	# 天师剑法: max_force 80.
	var blade: CharacterState = _member()
	blade.recovery.inner_force = CharacterInternalResourceState.new(0, 79)
	_check(_learn(blade, MASTER, &"scratching", [0])[1] == ["你的内力不够，没有办法练天师剑法。"], "max_force 79: refused")
	blade.recovery.inner_force = CharacterInternalResourceState.new(0, 80)
	_check((_learn(blade, MASTER, &"scratching", [0])[0] as LearnResult).success, "80: learnt (no sword needed to learn it)")


func _test_practice() -> void:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var blade: CharacterState = _member()
	blade.skills.set_raw_level(&"sword", 10)
	blade.skills.set_raw_level(&"scratching", 5)
	blade.skills.map_skill(&"sword", &"scratching")
	blade.recovery.inner_force = CharacterInternalResourceState.new(5, 80)
	_check(_practice(blade, &"sword", registry) == ["你必须先找一把剑才能练剑法。"], "bare-handed: a sword first")
	blade.equipment.wield(EquippedWeaponRef.new(&"test.sword", _catalog.item(LONGSWORD).weapon_definition()), false) # TEST-ONLY
	blade.recovery.inner_force = CharacterInternalResourceState.new(4, 80)
	_check(_practice(blade, &"sword", registry) == ["你的内力或气不够，没有办法练习天师剑法。"], "force 4: its line")
	blade.recovery.inner_force = CharacterInternalResourceState.new(5, 80)
	blade.vitality = CharacterResourceState.new(29, 100, 100)
	_check(_practice(blade, &"sword", registry) == ["你的内力或气不够，没有办法练习天师剑法。"], "kee 29: the same line")
	blade.vitality = CharacterResourceState.new(100, 100, 100)
	var done: Array[String] = _practice(blade, &"sword", registry)
	_check(done[0] == "你按著所学练了一遍天师剑法。" and blade.vitality.current == 70 and blade.recovery.inner_force.current == 0, "practised: 30 kee and 5 force: %s" % [done])
	blade.recovery.inner_force = CharacterInternalResourceState.new(5, 79)
	_check(_practice(blade, &"sword", registry) == ["你的内力不够，没有办法练天师剑法。"], "valid_learn() first: max_force 79")
	var mind: CharacterState = _member()
	mind.skills.set_raw_level(&"force", 10)
	mind.skills.set_raw_level(&"gouyee", 2)
	mind.skills.map_skill(&"force", &"gouyee")
	mind.recovery.mana = CharacterInternalResourceState.new(0, 5)
	_check(_practice(mind, &"force", registry) == ["谷衣心法只能用学的，或是从运用(exert)中增加熟练度。"], "谷衣心法 refuses practice")


## necromancy.c practice_skill() (茅山 C): the 观想虫 still standing refuses first, then
## mana 10 and sen 30 (each its line); paid, random(sen) < 5 conjures instead of improving:
## random(query_skill("spells", 1)) < 10 a 观想虫, else a 观想兽. sen 0 always conjures.
func _test_necromancy_practice() -> void:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var policy: PracticePolicy = _catalog.skill(&"necromancy").practice_policy()
	_check(policy is VitalityInnerForcePracticePolicy and (policy as VitalityInnerForcePracticePolicy).mana_cost == 10 and (policy as VitalityInnerForcePracticePolicy).spirit_cost == 30, "10 mana and 30 sen a practice")
	_check(policy.conjuring != null and policy.conjuring.chance_below == 5 and policy.conjuring.skill_id == &"spells" and policy.conjuring.npc_ids == [&"common.npc.mind_bug", &"common.npc.mind_beast"] and policy.conjuring.below == [10], "random(sen) < 5 conjures; random(spells) < 10 the 观想虫, else the 观想兽")
	var mind: CharacterState = _member()
	mind.skills.set_raw_level(&"taoism", 20) # TEST-ONLY
	mind.skills.set_raw_level(&"spells", 10)
	mind.skills.set_raw_level(&"necromancy", 10)
	mind.skills.map_skill(&"spells", &"necromancy")
	mind.recovery.mana = CharacterInternalResourceState.new(100, 100)
	mind.spirit = CharacterResourceState.new(100, 100, 100)
	var draws := Forced.new()
	_check(_practice_with(mind, registry, draws, "观想虫") == ["你的魂魄还没有全部收回，赶快杀死你的观想虫吧！"] and mind.recovery.mana.current == 100 and mind.spirit.current == 100, "its 观想虫 still stands: refused first, nothing paid")
	mind.recovery.mana.current = 9
	_check(_practice_with(mind, registry, draws) == ["你的法力不够。"] and mind.spirit.current == 100, "mana 9: 你的法力不够")
	mind.recovery.mana.current = 100
	mind.spirit.current = 29
	_check(_practice_with(mind, registry, draws) == ["你的精神无法集中。"] and mind.recovery.mana.current == 100, "sen 29: 你的精神无法集中")
	mind.spirit.current = 100
	draws.queues[70] = [5]
	var learned: int = mind.skills.learned_progress(&"necromancy")
	var done: Array[String] = _practice_with(mind, registry, draws)
	_check(done == ["你闭目凝神，神游物外，开始修习茅山道术中的法术....", "你的茅山道术进步了！"] and mind.recovery.mana.current == 90 and mind.spirit.current == 70, "random(70) 5: practised for 10 mana and 30 sen: %s" % [done])
	_check(mind.skills.learned_progress(&"necromancy") == learned + 3, "practice.c: spells 10 / 5 + 1")
	draws.queues[40] = [4]
	draws.queues[10] = [9]
	var result: PracticeResult = PracticeService.practice(mind, &"spells", policy, registry.policy_for(&"necromancy"), false, true, null, draws.legacy_random)
	var lines: Array[String] = ColoredLine.texts(TrainingLines.practice(result, _catalog.skill(&"necromancy"), "观想虫"))
	_check(result.failure_reason == PracticeResult.FailureReason.PRACTICE_CONJURED and result.conjured_npc_id == &"common.npc.mind_bug" and mind.skills.learned_progress(&"necromancy") == learned + 3, "random(40) 4, random(10) 9: a 观想虫 and no progress")
	_check(lines == ["你闭目凝神，神游物外，开始修习茅山道术中的法术....", "可是你心思一乱，变出了一只面目狰狞的观想虫！", "你的魂魄正被观想虫缠住，快把它除掉吧！"] and mind.recovery.mana.current == 80 and mind.spirit.current == 40, "paid all the same: %s" % [lines])
	mind.skills.set_raw_level(&"spells", 20) # TEST-ONLY
	mind.spirit.current = 30
	draws.queues[20] = [10]
	result = PracticeService.practice(mind, &"spells", policy, registry.policy_for(&"necromancy"), false, true, null, draws.legacy_random)
	_check(result.conjured_npc_id == &"common.npc.mind_beast" and mind.spirit.current == 0, "sen 30 leaves 0: random(0) is 0 and conjures; random(20) 10: a 观想兽")


## obj/npc/mind_bug.c and mind_beast.c: combat_exp from the owner's raw spells (500 and
## 2000 a level), die()'s random(spi / 2) + 1 and random(spi) + 1, and their lines.
func _test_conjured_npcs() -> void:
	var bug: NpcConjuring = _catalog.npc(&"common.npc.mind_bug").conjuring()
	var beast: NpcConjuring = _catalog.npc(&"common.npc.mind_beast").conjuring()
	_check(bug != null and bug.skill_id == &"spells" and bug.combat_experience(10) == 5000 and beast.combat_experience(10) == 20000, "combat_exp: spells 10 makes a 5000 观想虫, a 20000 观想兽")
	var bounds: Array[int] = []
	var record := func(n: int) -> int:
		bounds.append(n)
		return n - 1
	_check(bug.improvement(25, record) == 12 and beast.improvement(25, record) == 25 and bounds == [12, 25], "spi 25: random(12) + 1 and random(25) + 1: %s" % [bounds])
	_check(bug.killed_by_owner == ["你杀死了你的观想虫，并且从中悟到了一些咒术的道理。"] and bug.killed_by_other == ["你的观想虫被人杀死了！", "你觉得一阵天旋地转...."], "its die() lines")
	_check(_catalog.npc(&"common.npc.mind_bug").race_id == NpcCharacterStateFactory.BEAST_RACE_ID and _catalog.npc(&"common.npc.mind_beast").loadout_entries().is_empty(), "beasts that carry nothing")


# --- 灵神诀 -------------------------------------------------------------------------

## concentrate.c: 30 force and 10 sen for 10 + query_skill("force") / 5 mana, to max_mana.
func _test_concentrate() -> void:
	var state: CharacterState = _taoist()
	_check(ExertService.offered(state, _catalog) == [&"heal", &"concentrate", &"recover", &"refresh", &"regenerate"], "谷衣心法 enabled: 疗伤, 灵神诀 and d/force's three: %s" % [ExertService.offered(state, _catalog)])
	var result: ExertResult = _exert(state, &"concentrate", false)
	_check(result.succeeded() and state.recovery.mana.current == 17 and state.recovery.inner_force.current == 70 and state.spirit.current == 90, "query_skill(force) 35: 17 mana for 30 force and 10 sen")
	_check(ColoredLine.texts(result.lines) == CONCENTRATE and result.lines[0].color == ColoredLine.HIY and result.lines[1].color == ColoredLine.HIY, "its two lines in HIY, $P as 你: %s" % [ColoredLine.texts(result.lines)])
	state.recovery.mana.current = 90
	_exert(state, &"concentrate", false)
	_check(state.recovery.mana.current == 100, "past max_mana: set to it")
	state.recovery.mana.current = 150 # TEST-ONLY: above the maximum
	_exert(state, &"concentrate", false)
	_check(state.recovery.mana.current == 100, "above max_mana: set back to it, as written")
	state.recovery.inner_force.current = 100
	var busy := ActionBusyState.new()
	var fighting: ExertResult = ExertService.exert(state, &"concentrate", _catalog, 35, true, busy, _never, SkillImprovementEffectRegistry.new())
	_check(fighting.succeeded() and busy.busy_value == 1, "in a fight: busy 1")
	state.recovery.inner_force.current = 29
	var short: ExertResult = _exert(state, &"concentrate", false)
	_check(not short.succeeded() and ColoredLine.texts(short.lines) == ["你的内力不够。"] and state.recovery.inner_force.current == 29, "force 29: 你的内力不够")
	state.recovery.inner_force.current = 100
	state.spirit.current = 5
	_exert(state, &"concentrate", false)
	_check(state.spirit.current == -1 and state.life_threshold() != CharacterState.LifeThreshold.ACTIVE, "sen 5: below 0, the user falls")
	# heal.c is fonxanforce's, word for word.
	var hurt: CharacterState = _taoist()
	hurt.recovery.inner_force = CharacterInternalResourceState.new(150, 100)
	hurt.vitality = CharacterResourceState.new(60, 60, 100)
	var healed: ExertResult = _exert(hurt, &"heal", false)
	_check(healed.succeeded() and ColoredLine.texts(healed.lines) == ["你全身放松，坐下来开始运功疗伤。"] and hurt.vitality.effective == 77 and hurt.recovery.inner_force.current == 100, "疗伤: eff_kee + 10 + 35 / 5 for 50 force")
	# Use is practice: random(120) below query_skill("force") improves 谷衣心法 (weak mode).
	var practised: CharacterState = _taoist()
	var used: ExertResult = ExertService.exert(practised, &"concentrate", _catalog, 35, false, ActionBusyState.new(), func(_n: int) -> int: return 0, SkillImprovementEffectRegistry.new())
	_check(used.skill_improvement != null and used.skill_improvement.skill_id == &"gouyee", "random(120) 0 < 35: 谷衣心法 gains from use")


# --- The session --------------------------------------------------------------------

## A woman's 拜师: no question; two seconds later 不便收女徒, in the log and on the panel;
## 僵尸侍者 will not teach her either. She withdraws.
func _test_refused(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	player.state.gender = CharacterState.GENDER_FEMALE # TEST-ONLY
	await _beside(tree, session, map, master)
	var service: TeacherService = map.service(&"temple.grounds.temple1.taolord") as TeacherService
	_check(service != null and service.takes_apprentices(), "林忌 takes apprentices")
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and service.last_lines == [ASKED] and map.npc_life.apprentice_answer_due(master), "no question; only her request: %s" % [service.last_lines])
	map.advance_npc_heartbeat(1.5)
	_check(session.shared_ui().log_lines()[-1] == ASKED, "1.5 seconds: no answer yet")
	map.advance_npc_heartbeat(0.5)
	_check(session.shared_ui().log_lines()[-1] == NO_WOMEN and ui.apprentice_feedback.text == NO_WOMEN and not player.state.family.has_family(), "two seconds: 不便收女徒, in the log and on the panel")
	ui.refresh()
	_check(ui.cancel_button.visible, "her request still waits: 取消拜师请求 shows")
	ui.cancel_button.pressed.emit()
	_check(service.last_lines == ["你改变主意不想拜林忌为师了。"] and not player.apprenticeship_request.is_pending(), "withdrawn")
	ui.close_panel()
	await _beside(tree, session, map, _first(map, TRAINER))
	var trainer: TeacherService = map.service(&"temple.grounds.temple1.trainer") as TeacherService
	player.state.progression.potential = 1000 # TEST-ONLY
	var refused: LearnResult = trainer.request_learn(&"sword")
	_check(refused.failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT and trainer.last_lines.size() == 1 and _reject_lines("僵尸侍者").has(trainer.last_lines[0]), "僵尸侍者 will not teach one not of 茅山派: %s" % [trainer.last_lines])
	player.state.gender = CharacterState.GENDER_MALE # TEST-ONLY


## The answer comes while the player stands in the square: no one hears it, nothing changes.
func _test_nobody_hears(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	var service: TeacherService = map.service(&"temple.grounds.temple1.taolord") as TeacherService
	_check(service.request_apprentice() == NpcApprenticeship.Outcome.ANSWER_DUE, "拜师 (no panel: the question is the panel's)")
	_check(map.relocate_player(&"temple.square", &"temple.square.gate_arrival"), "TEST-ONLY: out into the square at once")
	await tree.physics_frame
	await tree.physics_frame
	var lines: int = session.shared_ui().log_lines().size()
	map.advance_npc_heartbeat(2.0)
	_check(not map.npc_life.apprentice_answer_due(master) and session.shared_ui().log_lines().size() == lines and not player.state.family.has_family(), "his answer came and went unheard; no recruit (recruit.c finds nobody)")
	_check(player.apprenticeship_request.is_pending_with(MASTER), "the request still waits on him")
	player.apprenticeship_request.cancel()


## His answer to one lying before him: the request waiting on him takes nobody (recruit.c's
## !living(ob)); one withdrawn meanwhile is offered all the same; nothing is read. An
## unconscious 林忌 says nothing (unconcious() disables his commands). Leaving the map drops
## the answer: it would come while the player is away and find nobody; a deactivation that
## is rolled back (a failed Continue) keeps it.
func _test_answer_cases(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var request: NpcApprenticeship = player.apprenticeship_request
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	var service: TeacherService = map.service(&"temple.grounds.temple1.taolord") as TeacherService
	service.request_apprentice()
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: lying there
	var lines: int = session.shared_ui().log_lines().size()
	map.advance_npc_heartbeat(2.0)
	_check(not map.npc_life.apprentice_answer_due(master) and not player.state.family.has_family() and request.is_pending_with(MASTER) and session.shared_ui().log_lines().size() == lines, "lying there: no recruit, nothing read, the request still waits")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	request.cancel()
	service.request_apprentice()
	request.cancel()
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	lines = session.shared_ui().log_lines().size()
	map.advance_npc_heartbeat(2.0)
	_check(request.is_offered(MASTER) and not player.state.family.has_family() and session.shared_ui().log_lines().size() == lines, "withdrawn and lying there: offered all the same, unread")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	request._offers.erase(MASTER) # TEST-ONLY
	service.request_apprentice()
	master.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	lines = session.shared_ui().log_lines().size()
	map.npc_life._advance_ambience(2.0) # TEST-ONLY: the call_outs alone (the heart beat would wake him)
	_check(not map.npc_life.apprentice_answer_due(master) and session.shared_ui().log_lines().size() == lines and not player.state.family.has_family() and request.is_pending_with(MASTER), "an unconscious 林忌: his answer does nothing")
	master.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	request.cancel()
	service.request_apprentice()
	_check(map.suspend_for_session_swap() and map.resume_after_session_swap_rollback() and map.npc_life.apprentice_answer_due(master), "a Continue that is rolled back keeps his answer due")
	await tree.physics_frame
	_check(session.handoff_to(&"temple.mountain", &"temple.entrance", &"temple.entrance", &"temple.entrance.gate_return").succeeded(), "TEST-ONLY: out of the gate at once")
	await tree.physics_frame
	await tree.physics_frame
	_check(not map.npc_life.apprentice_answer_due(master), "the player left the map: his answer is dropped")
	_check(session.handoff_to(&"temple.grounds", &"temple.square", &"temple.square", &"temple.square.gate_arrival").succeeded(), "TEST-ONLY: back inside")
	await tree.physics_frame
	await tree.physics_frame
	await _beside(tree, session, map, master)
	map.advance_npc_heartbeat(3.0)
	_check(not player.state.family.has_family() and request.is_pending_with(MASTER), "back before him: no answer comes, the request still waits")
	request.cancel()


## A man's 拜师: asked first (a first master); withdrawn and asked again before the answer:
## 慢著; the answer takes him; he learns; the panel shows it all.
func _test_join(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	var service: TeacherService = map.service(&"temple.grounds.temple1.taolord") as TeacherService
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("拜林忌为师，便成为茅山派的弟子") and ui.confirm_button.text == "确定拜师", "a first master: asked first: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	_check(service.last_lines == [ASKED] and not player.state.family.has_family(), "confirmed: his request; no answer yet")
	map.advance_npc_heartbeat(1.0)
	ui.refresh()
	ui.cancel_button.pressed.emit()
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming(), "asked first again")
	ui.confirm_button.pressed.emit()
	_check(service.last_lines == [ASKED, BUSY], "asked again while his answer is due: 慢著: %s" % [service.last_lines])
	map.advance_npc_heartbeat(1.0)
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.shown_title() == "茅山派第六代弟子" and player.state.affiliation.class_id == &"taoist", "his one answer takes the player: 茅山派第六代弟子, a 道士")
	_check(service.last_lines[0] == TAKES and ui.apprentice_feedback.text.begins_with(TAKES) and session.shared_ui().log_lines().has("恭喜您成为茅山派的第六代弟子。"), "也好 and recruit.c's lines, in the log and on the panel: %s" % [service.last_lines])
	_check(not map.npc_life.apprentice_answer_due(master), "no second answer")
	map.advance_npc_heartbeat(3.0)
	_check(session.shared_ui().log_lines()[-1] == "恭喜您成为茅山派的第六代弟子。", "nothing more comes")
	player.state.progression.potential = 1000 # TEST-ONLY
	var learned: LearnResult = service.request_learn(&"taoism")
	_check(_taught(learned) and service.last_lines[0] == "你向林忌请教有关「天师正道」的疑问。", "林忌 teaches his apprentice 天师正道: %s" % [service.last_lines])
	ui.close_panel()
	await _beside(tree, session, map, _first(map, TRAINER))
	var trainer: TeacherService = map.service(&"temple.grounds.temple1.trainer") as TeacherService
	learned = trainer.request_learn(&"sword")
	_check(_taught(learned) and trainer.last_lines[0] == "你向僵尸侍者请教有关「基本剑法」的疑问。", "僵尸侍者 teaches him now: %s" % [trainer.last_lines])
	await _beside(tree, session, map, _first(map, TFIGHTER))
	var tfighter: TeacherService = map.service(&"temple.grounds.temple1.tfighter") as TeacherService
	learned = tfighter.request_learn(&"dodge")
	_check(_taught(learned), "and 僵尸护法")


## road2.c's invisible wall lets 茅山派 in: the player joined.
func _test_library(session: WorldSessionController) -> void:
	var wall: ZoneExitRuleDefinition = _catalog.exit_rules_between(&"temple.road2", &"temple.book_room1")[0]
	var state: CharacterState = session.player_runtime().state
	_check(not wall.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, state.apprenticeship.master_teacher_id, state.family.family_id), false), "the 藏经楼 is open to him")


## 灵神诀 on the 武学 page, with 谷衣心法 enabled.
func _test_concentrate_page(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	_make_taoist(state)
	# TEST-ONLY: the maxima race/human.c gives that max_force and max_mana (Continue recomputes them).
	CharacterDerivedValues.refresh_human_player_maxima(state, player.facts.age)
	state.spirit.current = state.spirit.effective
	var hud: SharedGameplayUI = session.shared_ui()
	hud.open_martial_arts()
	var page: MartialArtsPage = hud.martial_arts_page()
	page.refresh()
	_check(page.buttons.has("exert:concentrate") and page.buttons["exert:concentrate"].text == "灵神诀", "运功: 灵神诀")
	page.buttons["exert:concentrate"].pressed.emit()
	_check(ColoredLine.texts(session.martial_arts().last_lines).slice(0, 2) == CONCENTRATE and state.recovery.mana.current == 17 and state.recovery.inner_force.current == 70, "its lines; 17 mana: %s" % [ColoredLine.texts(session.martial_arts().last_lines)])
	_check(hud.log_lines().has(CONCENTRATE[1]), "in the log")
	hud.dismiss_current_panel()


## In a spar with 僵尸护法 (茅山派 only): 运功灵神诀 on the battle panel, then busy 1; a due
## answer of 林忌 waits while the fight stands the world still; 施法「紫光」 at 僵尸护法.
func _test_concentrate_fight(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var tfighter: NpcRuntimeState = _first(map, TFIGHTER)
	await tree.physics_frame
	await tree.physics_frame
	await _beside(tree, session, map, tfighter)
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no chat; every roll its highest
	player.state.recovery.mana.current = 0
	map.select_npc(tfighter.character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "僵尸护法 spars with a member")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	ui.refresh_projection()
	var labels: Array[String] = []
	for info: CombatTacticalActionInfo in ui.current_projection().actions():
		labels.append(ui.action_catalog.label_for(info.action_id))
	_check(labels.has("运功灵神诀") and labels.has("运功疗伤"), "the battle panel offers 运功灵神诀: %s" % [labels])
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var action: StringName = CombatExertTacticalPolicy.action_id_for(&"concentrate")
	coordinator.submit_player_action(CombatTacticalRequest.new(&"concentrate:1", coordinator.active_encounter().encounter_id, player.character_id, action, CombatTacticalRequest.Category.INTERNAL_FORCE))
	coordinator.advance_scheduler(0.0)
	ui.refresh_projection()
	var log: String = ui.log_panel._text.get_parsed_text()
	_check(player.state.recovery.mana.current == 17 and player.busy.busy_value == 1, "17 mana, busy 1")
	_check(log.contains(CONCENTRATE[0]) and log.contains(CONCENTRATE[1]), "its lines in the battle log")
	var master: NpcRuntimeState = _first(map, MASTER)
	map.npc_life.start_apprentice_answer(master, 2.0) # TEST-ONLY: an answer due
	session.advance_npc_heartbeat(3.0)
	_check(map.npc_life.apprentice_answer_due(master), "in a fight the world stands still: the answer waits")
	# 茅山道术 enabled: 紫光 at him (every roll its highest: no failure, a hit).
	player.state.skills.set_raw_level(&"spells", 20) # TEST-ONLY
	player.state.skills.set_raw_level(&"necromancy", 20)
	player.state.skills.map_skill(&"spells", &"necromancy")
	while player.busy.is_busy():
		player.busy.advance() # TEST-ONLY: 灵神诀's busy over
	ui.refresh_projection()
	labels.clear()
	for info: CombatTacticalActionInfo in ui.current_projection().actions():
		labels.append(ui.action_catalog.label_for(info.action_id))
	_check(labels.has("施法「紫光」") and labels.has("施法「白光」") and labels.has("施法「青光」") and labels.has("施法「召护法」"), "茅山道术 enabled: the three bolts and 召护法 on the battle panel: %s" % [labels])
	player.state.recovery.mana.current = 50
	coordinator.submit_player_action(CombatTacticalRequest.new(&"drainer:1", coordinator.active_encounter().encounter_id, player.character_id, CombatCastTacticalPolicy.action_id_for(&"drainerbolt"), CombatTacticalRequest.Category.SPELL))
	coordinator.advance_scheduler(0.0)
	ui.refresh_projection()
	log = ui.log_panel._text.get_parsed_text()
	_check(player.state.recovery.mana.current == 25 and player.busy.busy_value == 2 and log.contains("你口中喃喃地念著咒文，左手一挥，手中聚起一团紫光射向僵尸护法！"), "紫光: 25 mana, busy 2, the bolt flies: %s" % log.right(160))
	await _flee(tree, session)
	await _beside(tree, session, map, master)
	session.advance_npc_heartbeat(2.0)
	_check(not map.npc_life.apprentice_answer_due(master) and session.shared_ui().log_lines().has("林忌拍拍你的头，说道：「好徒儿！」"), "after the fight it comes: 好徒儿 for his apprentice")


## Save/Continue keeps the family, the master, the class and 谷衣心法.
func _test_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.busy.advance() # TEST-ONLY: the fight's busy may linger
	while player.busy.is_busy():
		player.busy.advance()
	session.configure_combat_random_source(_original_random)
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "茅山 B")
	_check(walker._failures.is_empty(), "Save/Continue restores 林忌's apprentice exactly: " + str(walker._failures))


# --- Helpers ------------------------------------------------------------------------

## learn.c's reject_msg lines as `npc` says them.
static func _reject_lines(npc: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in NpcRecognitionPolicy.REJECT_LINES:
		out.append(line % npc)
	return out


## The teacher admitted the student (learn.c went past recognize_apprentice()).
static func _taught(result: LearnResult) -> bool:
	return result.failure_reason not in [LearnResult.FailureReason.RECOGNITION_REJECTED, LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT]


static func _fresh(gender: StringName) -> CharacterState:
	return NewPlayerInitializationPolicy.create(gender, "茅山").state


static func _student(gender: StringName) -> CharacterState:
	var state: CharacterState = _fresh(gender)
	state.progression.potential = 100 # TEST-ONLY
	return state


## 林忌's apprentice with potential to spend.
func _member() -> CharacterState:
	var state: CharacterState = _student(CharacterState.GENDER_MALE)
	var request := NpcApprenticeship.new()
	request.request(state, _catalog.npc(MASTER), _catalog.family(FAMILY), 1, "壮士")
	request.answer(state, _catalog.npc(MASTER), _catalog.family(FAMILY), 2, "壮士")
	return state


## TEST-ONLY: force 30 and 谷衣心法 20 enabled (query_skill("force") 35), 100 force, mana
## 0 of 100, sen 100.
func _taoist() -> CharacterState:
	var state: CharacterState = _member()
	_make_taoist(state)
	state.spirit = CharacterResourceState.new(100, 100, 100)
	return state


## TEST-ONLY: force 30 and 谷衣心法 20 enabled, 100 force, mana 0 of 100.
static func _make_taoist(state: CharacterState) -> void:
	state.skills.set_raw_level(&"force", 30)
	state.skills.set_raw_level(&"gouyee", 20)
	state.skills.map_skill(&"force", &"gouyee")
	state.recovery.inner_force = CharacterInternalResourceState.new(100, 100)
	state.recovery.mana = CharacterInternalResourceState.new(0, 100)


func _exert(state: CharacterState, function_id: StringName, fighting: bool) -> ExertResult:
	var level: int = state.skills.effective_level(&"force")
	return ExertService.exert(state, function_id, _catalog, level, fighting, ActionBusyState.new(), _never, SkillImprovementEffectRegistry.new())


## random(n) at its highest: nothing improves.
func _never(n: int) -> int:
	return n - 1


## learn <skill> from the NPC standing at full sen; [LearnResult, its lines].
func _learn(student: CharacterState, npc_id: StringName, skill_id: StringName, draws: Array[int]) -> Array:
	var definition: NpcDefinition = _catalog.npc(npc_id)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"temple.grounds.temple1.test", &"temple.temple1.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
	var random := ScriptedWorldInteractionRandomSource.new(draws)
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, false, random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = _catalog.skill(skill_id)
	var result: LearnResult = LearnService.learn(student, context, skill, registry.policy_for(skill_id), null, random)
	var respect: String = RankWords.query_respect(student.gender, 14, student.affiliation.class_id)
	return [result, LearnLines.lines(result, definition.display_name, skill, student, context, respect)]


func _practice(state: CharacterState, use_id: StringName, registry: SkillLearnPolicyRegistry) -> Array[String]:
	var special: StringName = state.skills.mapped_skill(use_id)
	var skill: SkillDefinition = _catalog.skill(special)
	var result: PracticeResult = PracticeService.practice(state, use_id, skill.practice_policy(), registry.policy_for(special), false)
	return ColoredLine.texts(TrainingLines.practice(result, skill))


## practice spells with `draws` (legacy_random) and the name of a 观想虫 still standing.
func _practice_with(state: CharacterState, registry: SkillLearnPolicyRegistry, draws: CombatRandomSource, standing: String = "") -> Array[String]:
	var skill: SkillDefinition = _catalog.skill(&"necromancy")
	var result: PracticeResult = PracticeService.practice(state, &"spells", skill.practice_policy(), registry.policy_for(&"necromancy"), false, true, null, draws.legacy_random, standing)
	return ColoredLine.texts(TrainingLines.practice(result, skill))


## TEST-ONLY: the player beside the NPC, where its teaching reaches.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 60.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	for attempt: int in range(400):
		if not coordinator.has_active_encounter():
			break
		if coordinator.active_encounter().queued_player_action() == null:
			var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
			coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the spar is over: " + coordinator.last_abort_detail())
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
	await tree.process_frame


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("茅山 B: " + label)
