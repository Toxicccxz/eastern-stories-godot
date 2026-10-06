extends RefCounted

## 振远镖局 (u/cloud/biaoju.c, package 3B): 陈剑秋 (b_header.c, F_MASTER) takes
## apprentices with cor 25 or more (attempt_apprentice()) into his family's second
## generation, class guardman; a member of another family betrays it (recruit.c:
## score 0, betrayer + 1). He teaches his skills by learn.c and std/char/master.c;
## 趟子手 (bfighter.c, privs -1) teaches the family's members too. His accept_object()
## keeps whatever he is given, with one of three answers (the letter waits for the
## 忘忧草's master_id, 乔阴县城). look.c names a member's relation; 春风快意刀 is
## practised with a blade in hand. TEST-ONLY fixtures are marked where used.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Master := preload("res://tests/support/snow_master.gd")
const HEADER: StringName = &"cloud.npc.b_header"
const FIGHTER: StringName = &"cloud.npc.bfighter"
const FAMILY: StringName = &"family.zhenyuan"
const GRASS: StringName = &"es2:d/choyin/obj/grass"
const BLADE: StringName = &"es2:obj/weapon/blade"
const TAUGHT: Array[StringName] = [&"unarmed", &"parry", &"dodge", &"blade", &"force", &"literate", &"spring-blade"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_apprentice()
	_test_betrayal()
	_test_learn()
	_test_fighter_teaches()
	_test_practice()
	_test_gifts()
	_test_relations()
	_test_loaders()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_in_the_biaoju(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var header: NpcDefinition = catalog.npc(HEADER)
	var teaching: NpcTeaching = header.teaching()
	_check(teaching.family_id == FAMILY and teaching.family_generation == 1 and teaching.f_master, "陈剑秋: 振远镖局's first generation, F_MASTER")
	_check(teaching.apprentice != null and teaching.apprentice.requires == {&"cor": 25} and teaching.apprentice.class_id == &"guardman", "attempt_apprentice(): cor 25 only; recruit_apprentice(): class guardman")
	_check(NpcTeacher.teachable_skills(header, catalog) == TAUGHT, "he teaches all seven of his skills (blade is 基本刀法 now): " + str(NpcTeacher.teachable_skills(header, catalog)))
	_check(NpcTeacher.teachable_skills(catalog.npc(FIGHTER), catalog) == TAUGHT and catalog.npc(FIGHTER).teaching().family_generation == 2 and catalog.npc(FIGHTER).teaching().apprentice == null, "趟子手: second generation, the same seven skills, takes no apprentice")
	var blade: SkillDefinition = catalog.skill(&"blade")
	_check(blade != null and blade.display_name == "基本刀法" and blade.kind == SkillDefinition.Kind.BASIC and blade.skill_type == SkillDefinition.Type.MARTIAL, "blade.c: 基本刀法, a basic martial skill")
	_check(header.talk().answer("陈天星") == PackedStringArray(["他是我师叔，如果你帮我找到忘忧草并交给我，我就介绍你去那学艺。"]) and header.talk().answer("忘忧草") == PackedStringArray(["我在乔阴县城游玩时丢的，据说被藏在一个隐蔽的地方了。"]), "inquiry 陈天星 and 忘忧草 as written")
	var grass: ItemContentDefinition = catalog.item(GRASS)
	_check(grass != null and grass.display_name == "忘忧草" and grass.value == 10000 and grass.unit == "棵", "grass.c: 忘忧草, a 棵, value 10000")
	var placed: bool = false
	for spawn: ItemSpawnDefinition in catalog.item_spawns():
		placed = placed or spawn.item_definition_id == GRASS
	for npc: NpcDefinition in catalog.npcs():
		for entry: NpcLoadoutEntry in npc.loadout_entries():
			placed = placed or entry.item_definition_id == GRASS
	for vendor: VendorDefinition in catalog.vendors():
		for key: String in vendor.goods_keys():
			placed = placed or vendor.item_definition_id(key) == GRASS
	_check(not placed, "nothing places, carries or sells a 忘忧草 before 乔阴县城 (lion.c's die())")


## attempt_apprentice(): query_cor() (effective) below 25 refuses; cps does not count.
func _test_apprentice() -> void:
	var state := _fresh()
	var request := NpcApprenticeship.new()
	_check(_recruit(state, request, 1789420000) == NpcApprenticeship.Outcome.RECRUITED, "a fresh character (cor 30) is taken")
	_check(request.lines == ["你想要拜陈剑秋为师。", "陈剑秋说道：很好，小兄弟多加努力，本镖局不会亏待你的。", "陈剑秋决定收你为弟子。", "你跪了下来向陈剑秋恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为振远镖局的第二代弟子。"], "apprentice.c, b_header.c and recruit.c lines: " + str(request.lines))
	_check(state.family.family_id == FAMILY and state.family.generation == 2 and state.apprenticeship.master_teacher_id == HEADER and state.apprenticeship.legacy_master_name == "陈剑秋", "振远镖局's second generation, 陈剑秋's apprentice")
	_check(state.affiliation.class_id == &"guardman" and state.affiliation.family_title == "弟子" and state.affiliation.entry_time_utc == 1789420000 and state.apprenticeship.betrayer_count == 0, "class guardman, 弟子, entered now, no betrayal")
	_check(NpcApprenticeship.family_title("振远镖局", 2, "弟子") == "振远镖局第二代弟子", "assign_apprentice(): 振远镖局第二代弟子")
	_check(_recruit(state, request, 1789429999) == NpcApprenticeship.Outcome.ACKNOWLEDGED and request.lines == ["你恭恭敬敬地向陈剑秋磕头请安，叫道：「师父！」"] and state.affiliation.entry_time_utc == 1789420000, "asking again greets the master")
	state = _fresh()
	state.attributes.courage = 24
	request = NpcApprenticeship.new()
	_check(_recruit(state, request, 1) == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.is_pending() and not state.family.has_family(), "cor 24: refused, the request stays pending")
	_check(request.lines == ["你想要拜陈剑秋为师。", "陈剑秋说道：走镖危险甚大，依我看小兄弟似乎不宜冒这份险？"], "走镖危险甚大: " + str(request.lines))
	_check(_recruit(state, request, 2) == NpcApprenticeship.Outcome.PENDING and request.lines == ["你想拜陈剑秋为师，但是对方还没有答应。"], "asking again while pending")
	_check(request.cancel() == NpcApprenticeship.Outcome.CANCELLED, "apprentice cancel")
	state.attributes.bellicosity = 50
	_check(_recruit(state, request, 3) == NpcApprenticeship.Outcome.RECRUITED, "cor 24 + bellicosity 50 / 50: query_cor() is 25")
	state = _fresh()
	state.attributes.courage = 25
	state.attributes.composure = 1
	_check(_recruit(state, NpcApprenticeship.new(), 4) == NpcApprenticeship.Outcome.RECRUITED, "cor exactly 25 with cps 1: only cor counts")


## recruit.c: another family's member betrays it; score 0, betrayer + 1, and the new
## family, master, class and title replace the old. The same family only changes master.
func _test_betrayal() -> void:
	var state := _fresh()
	Master.recruit(state, 1789420000)
	state.progression.score = 9
	var request := NpcApprenticeship.new()
	_check(_recruit(state, request, 1789430000) == NpcApprenticeship.Outcome.RECRUITED, "封山剑派's disciple goes to 陈剑秋")
	_check(request.lines == ["你想要拜陈剑秋为师。", "陈剑秋说道：很好，小老弟多加努力，本镖局不会亏待你的。", "你决定背叛师门，改投入陈剑秋门下！！", "你跪了下来向陈剑秋恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为振远镖局的第二代弟子。"], "the betrayal's lines (the swordsman is still a 小老弟 when he asks): " + str(request.lines))
	_check(state.progression.score == 0 and state.apprenticeship.betrayer_count == 1, "score 0, betrayer 1")
	_check(state.family.family_id == FAMILY and state.family.generation == 2 and state.apprenticeship.master_teacher_id == HEADER and state.affiliation.class_id == &"guardman" and state.affiliation.entry_time_utc == 1789430000, "the new family, master, class and entry time")
	_check(Master.recruit(state, 1789440000) == NpcApprenticeship.Outcome.RECRUITED and state.apprenticeship.betrayer_count == 2 and state.family.family_id == Master.FAMILY_ID and state.affiliation.class_id == &"swordsman", "and back to 柳淳风: betrayer 2")
	state = _fresh()
	state.family = FamilyState.new(FAMILY, 1)
	state.apprenticeship.master_teacher_id = &"test.other_master"
	state.apprenticeship.legacy_master_name = "陈天星"
	request = NpcApprenticeship.new()
	var header: NpcDefinition = GameContent.catalog().npc(HEADER)
	_check(NpcApprenticeship.would_betray(_disciple(), header) and not NpcApprenticeship.would_betray(_fresh(), header) and not NpcApprenticeship.would_betray(state, header), "the panel asks 柳淳风's disciple, not a newcomer nor a member of 振远镖局")
	_check(_recruit(state, request, 5) == NpcApprenticeship.Outcome.RECRUITED and request.lines[2] == "陈剑秋决定收你为弟子。" and state.apprenticeship.betrayer_count == 0 and state.family.generation == 2, "a member of 振远镖局 changes master without betraying: " + str(request.lines))
	_check(not NpcApprenticeship.would_betray(state, header) and not NpcApprenticeship.would_betray(_fresh(), GameContent.catalog().npc(FIGHTER)), "nor his own apprentice; 趟子手 takes no apprentice")


## learn.c with 陈剑秋 (int 23): gin cost 150/23 + 150/int, doubled for a new skill;
## random(int + exp/(1000 + exp/1000)) improves it. Outsiders get learn.c's refusal.
func _test_learn() -> void:
	var state := _fresh()
	_recruit(state, NpcApprenticeship.new(), 1)
	var gin: int = state.essence.current
	var draws := ScriptedWorldInteractionRandomSource.new([7])
	var learned: Array = _learn(state, HEADER, &"blade", draws)
	var result: LearnResult = learned[0]
	_check(result.success and result.calculated_essence_cost == (150 / 23 + 150 / 30) * 2 and state.essence.current == gin - 22, "基本刀法 from 陈剑秋 costs 22 gin")
	_check(draws.requested_bounds() == [30] and state.skills.raw_level(&"blade") == 1 and state.progression.potential_spent == 1, "random(30) improves it to 1, one potential")
	_check(learned[1].slice(0, 2) == ["你向陈剑秋请教有关「基本刀法」的疑问。", "你听了陈剑秋的指导，似乎有些心得。"], "learn.c lines: " + str(learned[1]))
	state.skills.set_raw_level(&"spring-blade", 119)
	state.progression.combat_experience = 2000000
	_check(_learn(state, HEADER, &"spring-blade", ScriptedWorldInteractionRandomSource.new([0]))[0].success, "spring-blade 119 still learns from his 120")
	state.skills.set_raw_level(&"spring-blade", 120)
	_check(_learn(state, HEADER, &"spring-blade", ScriptedWorldInteractionRandomSource.new([0]))[1] == ["这项技能你的程度已经不输你师父了。"], "not past his 120")
	state.apprenticeship.betrayer_count = 1
	state.skills.set_raw_level(&"spring-blade", 100)
	_check(_learn(state, HEADER, &"spring-blade", ScriptedWorldInteractionRandomSource.new([0]))[1] == ["陈剑秋神色间似乎对你不是十分信任，也许是想起你从前背叛师门的事情 ...。", "陈剑秋说道：嗯 .... 师父能教你的都教了，其他的你自己练吧。", "陈剑秋不愿意教你这项技能。"], "a betrayer: master.c stops at his 120 - 20")
	state.skills.set_raw_level(&"spring-blade", 99)
	_check(_learn(state, HEADER, &"spring-blade", ScriptedWorldInteractionRandomSource.new([0]))[0].success, "and teaches below it")
	var outsider := _fresh()
	draws = ScriptedWorldInteractionRandomSource.new([1])
	var refused: Array = _learn(outsider, HEADER, &"blade", draws)
	_check(refused[0].failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT and refused[1] == ["陈剑秋像是受宠若惊一样，说道：请教？这怎麽敢当？"] and draws.requested_bounds() == [3], "an outsider: reject_msg[random(3)]")
	Master.recruit(outsider, 1)
	_check(_learn(outsider, HEADER, &"blade", ScriptedWorldInteractionRandomSource.new([0]))[1] == ["陈剑秋说道：您太客气了，这怎麽敢当？"], "封山剑派's disciple is an outsider here")


## learn.c: the same family with privs -1 (create_family()) teaches; 趟子手 is no F_MASTER.
func _test_fighter_teaches() -> void:
	var state := _fresh()
	_recruit(state, NpcApprenticeship.new(), 1)
	state.skills.set_raw_level(&"spring-blade", 20)
	state.progression.combat_experience = 1000
	var learned: Array = _learn(state, FIGHTER, &"spring-blade", ScriptedWorldInteractionRandomSource.new([0]))
	_check(learned[0].success and learned[0].relationship_admission == LearnResult.RelationshipAdmission.SAME_FAMILY_FULL_PRIVILEGE, "a member learns from 趟子手 (his 40 is not over 20 × 3, but he has no prevent_learn())")
	state.skills.set_raw_level(&"spring-blade", 40)
	_check(_learn(state, FIGHTER, &"spring-blade", ScriptedWorldInteractionRandomSource.new([0]))[1] == ["这项技能你的程度已经不输你师父了。"], "up to his 40")
	_check(_learn(_fresh(), FIGHTER, &"blade", ScriptedWorldInteractionRandomSource.new([2]))[1] == ["趟子手笑著说道：您见笑了，我这点雕虫小技怎够资格「指点」您什麽？"], "an outsider gets learn.c's refusal")


## practice.c with spring-blade.c's practice_skill(): a blade in hand, then kee 40.
func _test_practice() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var spring: SkillDefinition = catalog.skill(&"spring-blade")
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var state := _fresh()
	state.skills.set_raw_level(&"blade", 10)
	state.skills.set_raw_level(&"spring-blade", 12)
	_check(SkillEnableTransition.try_enable(state.skills, spring, &"blade").applied, "enable blade spring-blade")
	var kee: int = state.vitality.current
	var result: PracticeResult = PracticeService.practice(state, &"blade", spring.practice_policy(), registry.policy_for(&"spring-blade"), false)
	_check(result.failure_reason == PracticeResult.FailureReason.PRACTICE_WEAPON_REJECTED and ColoredLine.texts(TrainingLines.practice(result, spring)) == ["你必须先找一把刀，才能练刀法。"] and state.vitality.current == kee, "bare hands: 你必须先找一把刀")
	state.equipment.wield(EquippedWeaponRef.new(&"test.sword", WeaponDefinition.new(&"es2:obj/weapon/longsword", &"sword", true)), false)
	result = PracticeService.practice(state, &"blade", spring.practice_policy(), registry.policy_for(&"spring-blade"), false)
	_check(result.failure_reason == PracticeResult.FailureReason.PRACTICE_WEAPON_REJECTED, "a sword is no blade")
	state = _fresh()
	state.skills.set_raw_level(&"blade", 10)
	state.skills.set_raw_level(&"spring-blade", 8)
	SkillEnableTransition.try_enable(state.skills, spring, &"blade")
	state.equipment.wield(EquippedWeaponRef.new(&"test.blade", WeaponDefinition.new(BLADE, &"blade", true)), false)
	state.vitality = CharacterResourceState.new(39, 39, 100)
	result = PracticeService.practice(state, &"blade", spring.practice_policy(), registry.policy_for(&"spring-blade"), false)
	_check(result.failure_reason == PracticeResult.FailureReason.PRACTICE_HOOK_REJECTED and ColoredLine.texts(TrainingLines.practice(result, spring)) == ["你的体力不够练这门刀法，还是先休息休息吧。"] and state.vitality.current == 39, "kee 39: 体力不够")
	state.vitality = CharacterResourceState.new(40, 40, 100)
	result = PracticeService.practice(state, &"blade", spring.practice_policy(), registry.policy_for(&"spring-blade"), false)
	_check(result.success and state.vitality.current == 0 and result.improvement_amount == 10 / 5 + 1 and not result.weak_mode, "kee 40: spent, improved by blade / 5 + 1")
	_check(ColoredLine.texts(TrainingLines.practice(result, spring))[-1] == "你的春风快意刀进步了！", "你的春风快意刀进步了！")


## accept_object(): every branch returns 1, so give.c hands the thing over.
func _test_gifts() -> void:
	var rules: Array[NpcObjectRule] = GameContent.catalog().npc(HEADER).dealings().object_rules
	var offer := NpcObjectRule.Offer.new(0, &"", 0, {}, {})
	offer.item_name = "钢刀"
	offer.giver_family = FAMILY
	var rule: NpcObjectRule = NpcObjectRule.decide(rules, offer)
	_check(rule.accept and rule.lines[0].sentence("陈剑秋", "") == "陈剑秋说道：你拿什么东西唬我？", "not a 忘忧草: 你拿什么东西唬我？ (and he keeps it)")
	offer.item_name = "忘忧草"
	offer.giver_family = &""
	rule = NpcObjectRule.decide(rules, offer)
	_check(rule.accept and rule.lines[0].sentence("陈剑秋", "") == "陈剑秋说道：你是何人？为什么有我的忘忧草？", "a 忘忧草 from an outsider")
	offer.giver_family = Master.FAMILY_ID
	_check(NpcObjectRule.decide(rules, offer) == rule, "封山剑派 is an outsider too")
	offer.giver_family = FAMILY
	rule = NpcObjectRule.decide(rules, offer)
	_check(rule.accept and rule.lines[0].sentence("陈剑秋", "") == "陈剑秋笑了笑说：“这不是你得到的吧？”。", "a member's 忘忧草 without master_id: 这不是你得到的吧")
	offer.item_name = "钱"
	offer.value = 10
	_check(NpcObjectRule.decide(rules, offer).lines[0].text == "你拿什么东西唬我？", "money: the same anger")


## The new record fields are checked when content loads.
func _test_loaders() -> void:
	var cases: Dictionary[String, Dictionary] = {
		"not a skill_type enable.c knows": {"weapon": "spear", "weapon_fail": "x", "kee": 1},
		"goes with weapon": {"weapon": "blade", "kee": 1},
		"checks no weapon": {"refuses": true, "weapon_fail": "x"},
	}
	for message: String in cases:
		var errors: Array[String] = []
		SkillDefinition.from_record(ContentRecordReader.new({"id": "test-blade", "name": "测试刀法", "kind": "specialized", "type": "martial", "enable": ["blade"], "legacy_source": "daemon/skill/test.c", "practice": cases[message]}, "skills[0]", errors))
		_check(errors.any(func(line: String) -> bool: return line.contains(message)), "practice %s: %s" % [cases[message], errors])
	var orphan: Array[String] = []
	SkillDefinition.from_record(ContentRecordReader.new({"id": "test-blade", "name": "测试刀法", "kind": "specialized", "type": "martial", "enable": ["blade"], "legacy_source": "daemon/skill/test.c", "practice": {"weapon_fail": "x", "kee": 1}}, "skills[0]", orphan))
	_check(orphan.any(func(line: String) -> bool: return line.contains("goes with weapon")), "weapon_fail alone: " + str(orphan))
	var builder := ContentCatalogBuilder.new()
	builder.add_document({"npcs": [{"id": "test.npc", "legacy_source": "test.c", "name": "测试", "accept_object": [
		{"giver_family": "family.nobody", "say": "x", "accept": true},
		{"item_name": "无此物", "say": "y", "accept": true},
	]}]}, "test.json")
	builder.build()
	_check(builder.errors().any(func(line: String) -> bool: return line.contains("unknown family 'family.nobody'")) and builder.errors().any(func(line: String) -> bool: return line.contains("no item named '无此物'")), "accept_object names a known family and item: " + str(builder.errors().slice(0, 6)))


## look.c's relation between members of one family.
func _test_relations() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state := _fresh()
	_check(FamilyRelation.of_npc(state, catalog.npc(HEADER), CharacterState.GENDER_MALE) == "", "no family: no relation")
	_recruit(state, NpcApprenticeship.new(), 1789420000)
	_check(FamilyRelation.of_npc(state, catalog.npc(HEADER), CharacterState.GENDER_MALE) == "师父", "陈剑秋 是你的师父")
	_check(FamilyRelation.of_npc(state, catalog.npc(FIGHTER), CharacterState.GENDER_MALE) == "同门师兄", "趟子手 (no master, enter_time 0) 是你的同门师兄")
	_check(FamilyRelation.of_npc(state, Master.definition(), CharacterState.GENDER_MALE) == "", "柳淳风 is of another family")
	var disciple := _fresh()
	Master.recruit(disciple, 1789420000)
	_check(FamilyRelation.of_npc(disciple, Master.definition(), CharacterState.GENDER_MALE) == "师父" and FamilyRelation.of_npc(disciple, catalog.npc(&"snow.npc.girl"), CharacterState.GENDER_FEMALE) == "", "封山剑派: 柳淳风 is the master; 柳绘心 is of 封山剑派北宗 (girl.c), no relation")
	var family := FamilyState.new(FAMILY, 2)
	_check(FamilyRelation.word(state, &"x", family, HEADER, 1789420001, CharacterState.GENDER_FEMALE) == "师妹" and FamilyRelation.word(state, &"x", family, HEADER, 1, CharacterState.GENDER_MALE) == "师兄", "the same master: 师妹 who came later, 师兄 who came earlier")
	_check(FamilyRelation.word(state, &"x", FamilyState.new(FAMILY, 1), &"", 1, CharacterState.GENDER_MALE) == "师伯" and FamilyRelation.word(state, &"x", FamilyState.new(FAMILY, 1), &"", 1789420001, CharacterState.GENDER_MALE) == "师叔", "the generation above: 师伯 entered first, else 师叔")
	_check(FamilyRelation.word(state, &"x", FamilyState.new(FAMILY, 0), &"", 0, CharacterState.GENDER_MALE) == "同门长辈" and FamilyRelation.word(state, &"x", FamilyState.new(FAMILY, 3), &"", 0, CharacterState.GENDER_MALE) == "师侄" and FamilyRelation.word(state, &"x", FamilyState.new(FAMILY, 4), &"", 0, CharacterState.GENDER_MALE) == "同门晚辈", "长辈, 师侄, 晚辈")


## The same rules from the biaoju: 拜师 and 请教 through his TeacherService, gifts by
## give.c, the relation in 目标详情, and a score that survives Save/Continue.
func _test_in_the_biaoju(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.duchang", &"cloud.duchang", &"cloud.duchang.stairs_return").succeeded(), "in the town (TEST-ONLY: by the 赌场's stairs)")
	await tree.physics_frame
	var header: NpcRuntimeState = _npc(map, &"cloud.biaoju.b_header.1")
	_check(header != null and _beside(map, player, &"cloud.biaoju", &"cloud.biaoju.b_header.1"), "beside 陈剑秋 in the biaoju")
	await tree.physics_frame
	var school: TeacherService = map.service(&"cloud.outdoor.biaoju.b_header") as TeacherService
	_check(school != null and school.can_teach() and school.takes_apprentices(), "he takes apprentices")
	Master.recruit(player.state, 1789420000) # TEST-ONLY: 柳淳风's disciple without the walk to Snow
	player.state.progression.score = 4 # TEST-ONLY: 3C's quests give score
	_check(player.shown_title() == "封山剑派第十四代弟子", "封山剑派's disciple: " + player.shown_title())
	school.interact()
	await tree.process_frame
	var ui: TeacherPanel = school.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and not ui.apprentice_button.visible and player.state.family.family_id == Master.FAMILY_ID and not player.apprenticeship_request.is_pending() and school.last_lines.is_empty(), "拜师 asks first (owner): nothing has happened yet")
	var warning: String = ui.confirm_text.text
	_check(warning.begins_with("你现在是封山剑派第十四代弟子。改投陈剑秋门下，就是背叛师门：") and warning.contains("综合评价清零（现在是 4）") and warning.contains("背叛师门的次数变成 1 次") and warning.contains("都换成振远镖局的"), "what betraying costs: " + warning)
	ui.keep_button.pressed.emit()
	_check(not ui.is_confirming() and ui.apprentice_button.visible and player.state.family.family_id == Master.FAMILY_ID and player.state.progression.score == 4, "不改投了: nothing changes")
	ui.apprentice_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	_check(not ui.is_confirming() and school.last_lines.slice(1, 3) == ["陈剑秋说道：很好，小姑娘多加努力，本镖局不会亏待你的。", "你决定背叛师门，改投入陈剑秋门下！！"] and player.state.progression.score == 0, "确定改投 betrays 封山剑派: " + str(school.last_lines))
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and school.last_lines == ["你恭恭敬敬地向陈剑秋磕头请安，叫道：「师父！」"], "his own apprentice is not asked")
	ui.close_panel()
	_check(player.shown_title() == "振远镖局第二代弟子" and player.facts.title == "振远镖局第二代弟子" and player.state.apprenticeship.betrayer_count == 1, "the title kept and shown: " + player.shown_title())
	var result: LearnResult = school.request_learn(&"blade")
	_check(result.success and school.last_lines[0] == "你向陈剑秋请教有关「基本刀法」的疑问。", "请教 基本刀法: " + str(school.last_lines))
	var hud: SharedGameplayUI = session.shared_ui()
	map.select_npc(header.character_id)
	_check(map.inspect_selected() and hud.inspection_text.text.ends_with("他是你的师父。"), "目标详情: " + hud.inspection_text.text)
	hud.dismiss_current_panel()
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 30, &"test.coins") # TEST-ONLY
	_add_item(session, &"test.grass", GRASS) # TEST-ONLY: no room places one yet
	var grass: ItemHandlingResult = map.give_to_selected(&"test.grass")
	_check(grass.done() and grass.lines == ["陈剑秋笑了笑说：“这不是你得到的吧？”。", "你给陈剑秋一棵忘忧草。"], "give 忘忧草: " + str(grass.lines))
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, header.character_id)
	_check(session.inventory_state().direct_children(holder).has(&"test.grass"), "he keeps it")
	var coins: ItemHandlingResult = map.give_to_selected(&"test.coins", 10)
	_check(coins.done() and coins.destroyed and coins.lines == ["陈剑秋说道：你拿什么东西唬我？", "你拿出十文钱给陈剑秋。"], "give money: " + str(coins.lines))
	player.state.progression.score = 5 # TEST-ONLY: 3C's quests give score
	var encoded: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	_check(encoded.contains("\"score\": \"5\""), "a score is saved (DecimalInt64Codec)")
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "a 振远镖局 apprentice with a score")
	_check(work._failures.is_empty(), "Save/Continue: " + str(work._failures))
	var root: Dictionary = JSON.parse_string(encoded)
	var cases: Dictionary[String, Array] = {
		"\"0\"": ["0", GameSaveResult.Outcome.INVALID_FIELD_TYPE], "a number": [5, GameSaveResult.Outcome.INVALID_FIELD_TYPE],
		"\"05\"": ["05", GameSaveResult.Outcome.INVALID_INTEGER],
	}
	for label: String in cases:
		var broken: Dictionary = root.duplicate(true)
		broken["player"]["character"]["progression"]["score"] = cases[label][0]
		_check(GameSaveJsonCodec.decode(JSON.stringify(broken)).outcome == cases[label][1], "a saved score of %s is refused" % label)
	var typo: Dictionary = root.duplicate(true)
	typo["player"]["character"]["progression"]["scores"] = "5"
	_check(GameSaveJsonCodec.decode(JSON.stringify(typo)).outcome == GameSaveResult.Outcome.INVALID_ROOT, "an unknown progression field is still refused")
	player.state.progression.score = 0
	_check(not GameSaveJsonCodec.encode(Work.capture(session)).text.contains("\"score\""), "score 0 is not written")


static func _fresh() -> CharacterState:
	return NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "镖师").state


static func _disciple() -> CharacterState:
	var state := _fresh()
	Master.recruit(state, 1)
	return state


func _recruit(state: CharacterState, request: NpcApprenticeship, entry_time_utc: int) -> NpcApprenticeship.Outcome:
	var catalog: ContentCatalog = GameContent.catalog()
	var respect: String = RankWords.query_respect(state.gender, 14, state.affiliation.class_id)
	return request.request(state, catalog.npc(HEADER), catalog.family(FAMILY), entry_time_utc, respect)


## learn <skill> from the NPC standing at full sen; [LearnResult, its lines].
func _learn(student: CharacterState, npc_id: StringName, skill_id: StringName, random: WorldInteractionRandomSource) -> Array:
	var catalog: ContentCatalog = GameContent.catalog()
	var definition: NpcDefinition = catalog.npc(npc_id)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"cloud.outdoor.biaoju.test", &"cloud.biaoju.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, false, random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = catalog.skill(skill_id)
	var result: LearnResult = LearnService.learn(student, context, skill, registry.policy_for(skill_id), null, random)
	var respect: String = RankWords.query_respect(student.gender, 14, student.affiliation.class_id)
	return [result, LearnLines.lines(result, definition.display_name, skill, student, context, respect)]


func _add_item(session: OldPineWorldSessionController, id: StringName, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var item: ItemInstance = ItemInstance.new(id, definition_id)
	_check(context.inventory.register_item(item, content.own_weight) and context.index.register_snapshot(item) and context.inventory._apply_reparent(id, context.endpoint()), "test item %s" % id)


func _beside(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return player.set_world_location(map.location_for_zone(zone_id))
	return false


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("biaoju: " + label)
