extends RefCounted

## 晚月庄 D: 晚月庄 the family. 蓝止萍 (daemon/class/dancer/master.c) answers two seconds
## after 拜师 (慢著，一个一个来 meanwhile), takes only women (男人都不是好东西，滚开！), strokes
## a young beauty's face (per above 25, under 20) and gives class dancer; 瑷伦 (elon.c) wants
## 100000 combat_exp and a woman, takes a family's member for a traitor (asked first), and
## tests with three lashes (asked first; the first one not stood says nothing); whom she takes
## is 晚月庄第一代弟子 (默认: either way in, not on an offer). 安妮儿 refuses everyone. Every
## 晚月庄 NPC (privs -1) teaches a member; the two F_MASTERs teach one not their own only what
## they know three times as well. The player's arts: 柔虹指 (women, empty hands; sen before
## force), 寒雪鞭法 (max_force 150, a whip), 七宝天岚舞, 意寒功 (learnt or used only): 意寒睨 on
## the battle panel at the current target, named in its lines, and the player's blows carry its
## cold. 无名老妇's force for a real member. Save/Continue. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const LAN: StringName = &"common.npc.dancer.master"
const ELON: StringName = &"latemoon.npc.room.elon"
const ANNIHI: StringName = &"latemoon.npc.room.annihi"
const YUMAY: StringName = &"latemoon.npc.yumay"
const OLD: StringName = &"latemoon.npc.room.old"
const SERVANT: StringName = &"latemoon.npc.servant"
const FAMILY: StringName = &"family.latemoon"
const WHIP: StringName = &"es2:obj/weapon/whip"
const TOKEN: StringName = &"es2:d/latemoon/room/npc/obj/token"
const LAN_ASKED: String = "你想要拜蓝止萍为师。"
const LAN_TAKES: String = "蓝止萍说道：很好，只要你对本庄主忠心耿耿，好处是少不了的。"
const LAN_FONDLES: String = "蓝止萍暧昧地抚摸著你的脸，说道：特别是像你这样的女孩 ...."
const NO_MEN: String = "蓝止萍说道：男人都不是好东西，滚开！"
const ELON_ASKED: String = "你想要拜瑷伦为师。"
const GO_TO_LAN: String = "拜师! 不敢当，我都老了!你去找「芷萍」好了，看她收不收你?"
const LASHES: Array[String] = ["瑷伦说道：小心了，这是第一鞭...", "瑷伦面露微笑：好！第二鞭来了...", "瑷伦鼓励道：很不错，看这最后一鞭..."]
const LASH_FAILS: Array[String] = ["", "瑷伦叹了口气道：看来还是不行啊...", "瑷伦叹了口气道：太可惜了！"]
const PASSED: String = "瑷伦露出慈祥的面容：看来我没看错人。"


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


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_lan_rule()
	_test_elon_rule()
	_test_annihi_rule()
	_test_learn()
	_test_practice()
	_test_chillgaze_lines()
	var session: WorldSessionController = await _session(tree)
	await _test_lan_in_hall(tree, session)
	await _test_learn_in_manor(tree, session)
	await _test_old_force(tree, session)
	await _test_elon_traitor(tree, session)
	await _test_elon_lashes(tree, session)
	await _test_annihi_in_wing(tree, session)
	await _test_chillgaze_fight(tree, session)
	await _test_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Data ---------------------------------------------------------------------------

func _test_data() -> void:
	var lan: NpcDefinition = _catalog.npc(LAN)
	var rule: NpcTeaching.ApprenticeRule = lan.teaching().apprentice
	_check(rule != null and rule.kind == NpcTeaching.Kind.REQUIREMENTS and rule.answer_after == 2.0 and rule.busy_say == "慢著，一个一个来。" and rule.class_id == &"dancer", "蓝止萍: answers two seconds later, class dancer")
	_check(rule.checks.size() == 1 and rule.checks[0].gender == "女性" and rule.checks[0].refuse_say == "男人都不是好东西，滚开！" and rule.accept_say == "很好，只要你对本庄主忠心耿耿，好处是少不了的。", "women only, with do_recruit()'s two says")
	_check(rule.accept_vision != null and rule.accept_vision.per_above == 25 and rule.accept_vision.age_below == 20 and rule.title.is_empty(), "the 暧昧 line for per above 25 under 20; assign_apprentice()'s title")
	_check(lan.teaching().family_id == FAMILY and lan.teaching().family_generation == 1 and lan.teaching().f_master, "晚月庄's 庄主 (generation 1), an F_MASTER")
	var elon: NpcDefinition = _catalog.npc(ELON)
	var trial: NpcTeaching.ApprenticeRule = elon.teaching().apprentice
	_check(trial.kind == NpcTeaching.Kind.TRIAL and trial.checks.size() == 2 and trial.checks[0].requires == {&"combat_exp": 100000} and trial.checks[1].gender == "女性" and trial.commoners_only == "{title}{nickname}{name}要叛师！！！", "瑷伦: 100000 combat_exp, then women, then commoners only")
	_check(trial.blows.size() == 3 and trial.blows[0].fail.is_empty() and trial.success == PASSED and trial.title == "晚月庄第一代弟子" and trial.class_id.is_empty(), "three lashes (the first one's sigh and shake print nothing), 晚月庄第一代弟子, no class")
	_check(elon.teaching().family_generation == 0 and elon.teaching().f_master, "the founder (generation 0), an F_MASTER")
	_check(_catalog.npc(ANNIHI).teaching().apprentice.kind == NpcTeaching.Kind.REFUSES, "安妮儿 refuses everyone")
	var members: int = 0
	for npc: NpcDefinition in _catalog.npcs():
		var teaching: NpcTeaching = npc.teaching()
		if teaching == null or teaching.family_id != FAMILY or npc.definition_id in [LAN, ELON]:
			continue
		members += 1
		_check(teaching.family_privileges == -1 and not teaching.f_master and teaching.apprentice == null, "%s: privs -1, takes no apprentice" % npc.definition_id)
	_check(members == 14, "the manor's fourteen other members teach: %d" % members)
	for id: StringName in [LAN, ELON]:
		var taught: Array[StringName] = NpcTeacher.teachable_skills(_catalog.npc(id), _catalog)
		_check(taught.has(&"tenderzhi") and taught.has(&"snowwhip") and taught.has(&"iceforce") and taught.has(&"stormdance") and taught.has(&"whip"), "%s teaches the family's arts: %s" % [id, taught])
	var practice: PracticePolicy = _catalog.skill(&"tenderzhi").practice_policy()
	_check(practice is VitalityInnerForcePracticePolicy and (practice as VitalityInnerForcePracticePolicy).spirit_first, "柔虹指 checks sen first")
	var errors: Array[String] = []
	SkillDefinition.from_record(ContentRecordReader.new({"id": "x", "name": "x", "kind": "basic", "type": "martial", "legacy_source": "x.c", "practice": {"force": 10, "sen_first": true}}, "x", errors))
	_check(errors.size() == 1 and errors[0].contains("sen_first"), "sen_first without sen fails the load: %s" % [errors])
	var catalog := BattleActionPresentationCatalog.new()
	var action: StringName = CombatExertTacticalPolicy.action_id_for(&"chillgaze")
	_check(catalog.label_for(action) == "运功意寒睨" and catalog.tooltip_for(action) == "运功意寒睨：用 50 点内力和 20 点神以目光摄住对手，伤其精（对手可能避开）", "the battle button and its hover: %s" % catalog.tooltip_for(action))
	_check(CombatExertTacticalPolicy.new(&"chillgaze").target_rule == CombatTacticalRequest.TargetRule.CURRENT_HOSTILE and CombatExertTacticalPolicy.new(&"chillgaze").accepts_no_target() and CombatExertTacticalPolicy.new(&"recover").target_rule == CombatTacticalRequest.TargetRule.SELF, "意寒睨 aims at the current target (or none); the others at oneself")


# --- Joining ------------------------------------------------------------------------

func _test_lan_rule() -> void:
	var lan: NpcDefinition = _catalog.npc(LAN)
	var family: FamilyDefinition = _catalog.family(FAMILY)
	var man: CharacterState = _fresh(CharacterState.GENDER_MALE)
	var request := NpcApprenticeship.new()
	_check(not request.takes_at_once(man, lan), "a man would not be taken: no question")
	_check(request.request(man, lan, family, 1, "壮士") == NpcApprenticeship.Outcome.ANSWER_DUE and request.lines == [LAN_ASKED], "拜师: only the request: %s" % [request.lines])
	_check(request.answer(man, lan, family, 2, "壮士") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == [NO_MEN] and not man.family.has_family(), "two seconds later: 滚开")
	var girl: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	girl.attributes.personality = 26 # TEST-ONLY
	request = NpcApprenticeship.new()
	_check(request.takes_at_once(girl, lan), "a woman would be taken (the panel asks first)")
	request.request(girl, lan, family, 1, "小姑娘", NpcApprenticeship.COMMONER_TITLE, "", "", false, 14)
	_check(request.answer(girl, lan, family, 2, "小姑娘", true, 14) == NpcApprenticeship.Outcome.RECRUITED, "her answer takes her")
	_check(request.lines == [LAN_TAKES, LAN_FONDLES, "蓝止萍决定收你为弟子。", "你跪了下来向蓝止萍恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为晚月庄的第二代弟子。"], "per 26 at 14: the say, the 暧昧 line, recruit.c: %s" % [request.lines])
	_check(girl.family.family_id == FAMILY and girl.family.generation == 2 and girl.affiliation.class_id == &"dancer" and NpcApprenticeship.member_title("晚月庄", 2, girl.affiliation.family_title, lan) == "晚月庄第二代弟子", "晚月庄第二代弟子, a dancer")
	for case: Array in [[25, 14], [30, 20]]:
		var other: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
		other.attributes.personality = case[0] # TEST-ONLY
		var asked := NpcApprenticeship.new()
		asked.request(other, lan, family, 1, "姑娘", NpcApprenticeship.COMMONER_TITLE, "", "", false, case[1])
		asked.answer(other, lan, family, 2, "姑娘", true, case[1])
		_check(asked.lines.size() == 4 and asked.lines[0] == LAN_TAKES and asked.lines[1] == "蓝止萍决定收你为弟子。", "per %d at %d: no 暧昧 line" % [case[0], case[1]])
	var third: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	request = NpcApprenticeship.new()
	request.request(third, lan, family, 1, "姑娘")
	request.cancel()
	_check(request.request(third, lan, family, 2, "姑娘", NpcApprenticeship.COMMONER_TITLE, "", "", true) == NpcApprenticeship.Outcome.MASTER_BUSY and request.lines == [LAN_ASKED, "蓝止萍说道：慢著，一个一个来。"], "asked while her answer is due: 慢著: %s" % [request.lines])


func _test_elon_rule() -> void:
	var elon: NpcDefinition = _catalog.npc(ELON)
	var family: FamilyDefinition = _catalog.family(FAMILY)
	var weak: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	var request := NpcApprenticeship.new()
	_check(not request.would_attack(weak, elon, "封山剑派第十四代弟子"), "short of 100000: her say comes before the traitor check")
	_check(request.request(weak, elon, family, 1, "姑娘", "封山剑派第十四代弟子", "封山剑派第十四代弟子", "晚客") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == [ELON_ASKED, "瑷伦说道：" + GO_TO_LAN], "short of 100000: go to 芷萍: %s" % [request.lines])
	var man: CharacterState = _fresh(CharacterState.GENDER_MALE)
	man.progression.combat_experience = 100000 # TEST-ONLY
	request = NpcApprenticeship.new()
	_check(not request.would_attack(man, elon, "封山剑派第十四代弟子") and request.request(man, elon, family, 1, "壮士", "封山剑派第十四代弟子", "封山剑派第十四代弟子", "晚客") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines[1] == "瑷伦说道：老身不收男徒!", "a man with a family's title: 老身不收男徒!, not attacked")
	var member: CharacterState = _member()
	member.progression.combat_experience = 100000 # TEST-ONLY
	request = NpcApprenticeship.new()
	_check(request.would_attack(member, elon, "晚月庄第二代弟子") and not request.takes_at_once(member, elon), "蓝止萍's apprentice would be taken for a traitor")
	_check(request.request(member, elon, family, 1, "姑娘", "晚月庄第二代弟子", "晚月庄第二代弟子", "晚客") == NpcApprenticeship.Outcome.ATTACKED and request.lines == [ELON_ASKED] and request.chat_line == "瑷伦大声喝道：晚月庄第二代弟子晚客要叛师！！！", "要叛师: %s" % request.chat_line)
	_check(not request.is_pending() and NpcApprenticeship.is_master_of(member, _catalog.npc(LAN)), "the attack ends the request (默认, DECISIONS 山烟寺 C); still 蓝止萍's")
	_check(request.would_attack(member, elon, "晚月庄第二代弟子"), "asked again, she would attack again (asked first)")
	var girl: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	girl.progression.combat_experience = 100000 # TEST-ONLY
	var class_before: StringName = girl.affiliation.class_id
	request = NpcApprenticeship.new()
	_check(request.request(girl, elon, family, 1, "姑娘") == NpcApprenticeship.Outcome.ASKED and request.lines == [ELON_ASKED, "瑷伦说道：姑娘若真的有心，不妨让我看看你的所学", "如果想拜师的话，就请接受测试"], "a commoner of 100000: the test: %s" % [request.lines])
	for failing: int in 3:
		var struck: Array[int] = [0]
		var result: NpcApprenticeTrial.Result = NpcApprenticeTrial.run(elon.teaching().apprentice, request,
			func() -> Array[ColoredLine]:
				struck[0] += 1
				var seen: Array[ColoredLine] = [ColoredLine.new("（一鞭）")]
				return seen,
			func() -> bool: return struck[0] <= failing,
			func() -> NpcApprenticeship.Outcome: return NpcApprenticeship.Outcome.AUTHORITY_FAILURE)
		var expected: Array[String] = []
		for lash: int in failing + 1:
			expected.append_array([LASHES[lash], "（一鞭）"])
		if not LASH_FAILS[failing].is_empty():
			expected.append(LASH_FAILS[failing])
		_check(result.outcome == NpcApprenticeTrial.Outcome.FAILED and ColoredLine.texts(result.lines) == expected, "lash %d not stood: %s" % [failing + 1, ColoredLine.texts(result.lines)])
	var passed: NpcApprenticeTrial.Result = NpcApprenticeTrial.run(elon.teaching().apprentice, request,
		func() -> Array[ColoredLine]:
			var seen: Array[ColoredLine] = []
			return seen,
		func() -> bool: return true,
		func() -> NpcApprenticeship.Outcome: return request.npc_recruit(girl, elon, family, 5))
	_check(passed.recruit == NpcApprenticeship.Outcome.RECRUITED and ColoredLine.texts(passed.lines) == LASHES + [PASSED, "瑷伦决定收你为弟子。", "你跪了下来向瑷伦恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为晚月庄的第一代弟子。"], "three stood: 看来我没看错人, and she takes her: %s" % [ColoredLine.texts(passed.lines)])
	_check(girl.family.generation == 1 and girl.affiliation.class_id == class_before and NpcApprenticeship.member_title("晚月庄", 1, girl.affiliation.family_title, elon) == "晚月庄第一代弟子" and NpcApprenticeship.family_title("晚月庄", 1, "弟子") == "晚月庄开山祖师", "晚月庄第一代弟子, not assign_apprentice()'s 开山祖师; her class kept")
	var stranger: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	var none := NpcApprenticeship.new()
	_check(none.npc_recruit(stranger, elon, family, 7) == NpcApprenticeship.Outcome.OFFERED and none.lines == ["瑷伦想要收你为弟子。", "如果你愿意拜瑷伦为师父，就向她拜师。"], "passed without asking her: an offer, 向她拜师: %s" % [none.lines])


func _test_annihi_rule() -> void:
	var annihi: NpcDefinition = _catalog.npc(ANNIHI)
	var state: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	state.progression.combat_experience = 1000000 # TEST-ONLY
	var request := NpcApprenticeship.new()
	_check(not request.takes_at_once(state, annihi) and not request.would_attack(state, annihi, "晚月庄第二代弟子"), "安妮儿 takes nobody, attacks nobody")
	_check(request.request(state, annihi, _catalog.family(annihi.teaching().family_id), 1, "姑娘") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == ["你想要拜安妮儿为师。", "安妮儿说道：" + GO_TO_LAN] and not state.family.has_family(), "her say, and nothing more: %s" % [request.lines])


# --- Learning -----------------------------------------------------------------------

func _test_learn() -> void:
	var stranger: CharacterState = _student(CharacterState.GENDER_FEMALE)
	var refused: Array = _learn(stranger, YUMAY, &"dodge", [0])
	_check((refused[0] as LearnResult).failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT and _reject_lines("蓝雨梅").has(refused[1][0]), "蓝雨梅 politely refuses one not of 晚月庄: %s" % [refused[1]])
	var member: CharacterState = _member()
	_check(_taught(_learn(member, YUMAY, &"dodge", [0])[0]), "蓝雨梅 teaches a member")
	_check(_taught(_learn(member, LAN, &"tenderzhi", [0])[0]), "蓝止萍 teaches her apprentice")
	member.skills.set_raw_level(&"tenderzhi", 43) # TEST-ONLY: 瑷伦's 130 is above 43 * 3
	_check(_taught(_learn(member, ELON, &"tenderzhi", [0])[0]), "瑷伦 teaches one not her own while she knows it three times as well")
	member.skills.set_raw_level(&"tenderzhi", 44) # 130 <= 132
	var prevented: Array = _learn(member, ELON, &"tenderzhi", [0])
	_check((prevented[0] as LearnResult).failure_reason == LearnResult.FailureReason.TEACHER_PREVENTED and prevented[1] == ["瑷伦说道：虽然你是我门下的弟子，可是并非我的嫡传弟子 ....", "瑷伦说道：我只能教你这些粗浅的本门功夫，其他的还是去找你师父学吧。", "瑷伦不愿意教你这项技能。"], "44: prevent_learn(): %s" % [prevented[1]])
	_check(_taught(_learn(member, LAN, &"tenderzhi", [0])[0]), "her own master teaches on")
	var armed: CharacterState = _member()
	armed.equipment.wield(EquippedWeaponRef.new(&"test.whip", _catalog.item(WHIP).weapon_definition()), false) # TEST-ONLY
	_check(_learn(armed, LAN, &"tenderzhi", [0])[1] == ["练柔虹指必须空手。"], "柔虹指 with a whip in hand: 必须空手")
	var man: CharacterState = _member()
	man.gender = CharacterState.GENDER_MALE # TEST-ONLY: a member who is a man
	_check(_learn(man, YUMAY, &"stormdance", [0])[1] == ["七宝天岚舞只有女性才能练。"], "七宝天岚舞 for women only")
	var whip: CharacterState = _member()
	whip.recovery.inner_force = CharacterInternalResourceState.new(0, 149)
	_check(_learn(whip, LAN, &"snowwhip", [0])[1] == ["你的内力不够，没有办法练寒雪鞭法, 多练些内力再来吧。"], "寒雪鞭法 at max_force 149")
	whip.recovery.inner_force = CharacterInternalResourceState.new(0, 150)
	_check(_learn(whip, LAN, &"snowwhip", [0])[1] == ["你必须先找一条鞭子才能练鞭法。"], "150, bare-handed: a whip first")
	whip.equipment.wield(EquippedWeaponRef.new(&"test.whip", _catalog.item(WHIP).weapon_definition()), false) # TEST-ONLY
	_check(_taught(_learn(whip, LAN, &"snowwhip", [0])[0]), "with a whip: learnt")


func _test_practice() -> void:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var dancer: CharacterState = _member()
	dancer.skills.set_raw_level(&"unarmed", 20)
	dancer.skills.set_raw_level(&"tenderzhi", 10)
	dancer.skills.map_skill(&"unarmed", &"tenderzhi")
	dancer.recovery.inner_force = CharacterInternalResourceState.new(0, 100)
	dancer.spirit = CharacterResourceState.new(29, 100, 100)
	_check(_practice(dancer, &"unarmed", registry) == ["你的精神无法集中了，休息一下再练吧。"], "sen 29 and no force: sen is checked first")
	dancer.spirit = CharacterResourceState.new(100, 100, 100)
	dancer.recovery.inner_force.current = 9
	_check(_practice(dancer, &"unarmed", registry) == ["你的内力不够了。"] and dancer.spirit.current == 100, "force 9: 你的内力不够了")
	dancer.recovery.inner_force.current = 10
	var done: Array[String] = _practice(dancer, &"unarmed", registry)
	_check(done == ["你的柔虹指进步了！"] and dancer.spirit.current == 70 and dancer.recovery.inner_force.current == 0, "practised for 30 sen and 10 force: %s" % [done])
	dancer.equipment.wield(EquippedWeaponRef.new(&"test.whip", _catalog.item(WHIP).weapon_definition()), false) # TEST-ONLY
	dancer.recovery.inner_force.current = 10
	_check(_practice(dancer, &"unarmed", registry) == ["练柔虹指必须空手。"], "with a whip in hand: valid_learn() first")
	var lasher: CharacterState = _member()
	lasher.skills.set_raw_level(&"whip", 20)
	lasher.skills.set_raw_level(&"snowwhip", 10)
	lasher.skills.map_skill(&"whip", &"snowwhip")
	lasher.recovery.inner_force = CharacterInternalResourceState.new(5, 150)
	lasher.equipment.wield(EquippedWeaponRef.new(&"test.whip", _catalog.item(WHIP).weapon_definition()), false) # TEST-ONLY
	lasher.vitality = CharacterResourceState.new(29, 100, 100)
	_check(_practice(lasher, &"whip", registry) == ["你的内力或气不够，没有办法练习寒雪鞭法。"], "kee 29: its line")
	lasher.vitality = CharacterResourceState.new(100, 100, 100)
	done = _practice(lasher, &"whip", registry)
	_check(done[0] == "你按著所学练了一遍寒雪鞭法。" and lasher.vitality.current == 70 and lasher.recovery.inner_force.current == 0, "寒雪鞭法 practised for 30 kee and 5 force: %s" % [done])
	var still: CharacterState = _member()
	still.skills.set_raw_level(&"force", 20)
	still.skills.set_raw_level(&"iceforce", 10)
	still.skills.map_skill(&"force", &"iceforce")
	_check(_practice(still, &"force", registry) == ["意寒功只能用学的，或是从运用(exert)中增加熟练度。"], "意寒功 refuses practice")


## chillgaze.c as the player reads it: their target named; looked away from, or shivering.
func _test_chillgaze_lines() -> void:
	var me: CharacterState = _member()
	me.skills.set_raw_level(&"force", 40)
	me.skills.set_raw_level(&"iceforce", 40)
	me.skills.map_skill(&"force", &"iceforce")
	me.recovery.inner_force = CharacterInternalResourceState.new(200, 200)
	me.attributes.force_factor = 10
	me.progression.combat_experience = 1000
	_check(ExertService.offered(me, _catalog, true).has(&"chillgaze") and not ExertService.offered(me, _catalog, false).has(&"chillgaze"), "意寒睨 offered in a fight only")
	var target := SpecialSide.new(&"servant", _fresh(CharacterState.GENDER_FEMALE), ActionBusyState.new())
	target.state.progression.combat_experience = 100
	target.state.recovery.inner_force = CharacterInternalResourceState.new(0, 50)
	var names := func(id: StringName) -> String: return "婢女" if id == &"servant" else String(id)
	var aimed := func() -> SpecialSide: return target
	var busy := ActionBusyState.new()
	var result: ExertResult = ExertService.exert(me, &"chillgaze", _catalog, 40, true, busy, func(n: int) -> int: return 0 if n == 100 else n - 1, SkillImprovementEffectRegistry.new(), &"player", [], aimed, names)
	_check(result.succeeded() and ColoredLine.texts(result.lines).slice(0, 2) == ["你眼神忽然发出异光，双瞳犹如两把利刃般盯著婢女！", "婢女被你的目光所摄，不自禁地打了个寒噤。"] and result.lines[0].color == ColoredLine.HIB, "the stare at 婢女, she shivers: %s" % [ColoredLine.texts(result.lines)])
	_check(target.state.essence.current == target.state.essence.maximum - 17 and busy.busy_value == 4 and me.recovery.inner_force.current == 150, "gin 10 * 2 - 50 / 15 = 17; busy 4; 50 force")
	me.progression.combat_experience = 100
	var away: ExertResult = ExertService.exert(me, &"chillgaze", _catalog, 40, true, ActionBusyState.new(), func(n: int) -> int: return n - 1, SkillImprovementEffectRegistry.new(), &"player", [], aimed, names)
	_check(ColoredLine.texts(away.lines).slice(0, 2) == ["你眼神忽然发出异光，双瞳犹如两把利刃般盯著婢女！", "婢女很快地转过头去，避开了你的目光。"], "random(100) 99 over 100 / 2: she looks away: %s" % [ColoredLine.texts(away.lines)])
	var nobody: ExertResult = ExertService.exert(me, &"chillgaze", _catalog, 40, true, ActionBusyState.new(), func(n: int) -> int: return n - 1, SkillImprovementEffectRegistry.new(), &"player", [], func() -> SpecialSide: return null, names)
	_check(not nobody.succeeded() and ColoredLine.texts(nobody.lines) == ["你要对谁施展「意寒睨」之术？"], "no enemy: 你要对谁施展")


# --- The session --------------------------------------------------------------------

func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("晚客", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	var state: CharacterState = session.player_runtime().state
	state.attributes.personality = 28 # TEST-ONLY: a beauty
	state.progression.potential = 1000
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.latemoon1", &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival").succeeded(), "TEST-ONLY: in the hall")
	await tree.physics_frame
	await tree.physics_frame
	return session


## A man's 拜师 with 蓝止萍: no question, 滚开 two seconds later. A young beauty's: asked
## first (a first master), then her answer strokes her face and takes her.
func _test_lan_in_hall(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var lan: NpcRuntimeState = await _beside(tree, map, session, LAN)
	var service: TeacherService = _teacher(map, lan)
	_check(service != null and service.takes_apprentices(), "蓝止萍 takes apprentices")
	if service == null:
		return
	player.state.gender = CharacterState.GENDER_MALE # TEST-ONLY
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and service.last_lines == [LAN_ASKED] and map.npc_life.apprentice_answer_due(lan), "a man: no question; his request")
	map.advance_npc_heartbeat(2.0)
	_check(session.shared_ui().log_lines()[-1] == NO_MEN and not player.state.family.has_family(), "two seconds: 滚开")
	ui.refresh()
	ui.cancel_button.pressed.emit()
	player.state.gender = CharacterState.GENDER_FEMALE # TEST-ONLY
	_check(player.facts.age < 20, "a New Game character is under 20: %d" % player.facts.age)
	ui.refresh()
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("拜蓝止萍为师，便成为晚月庄的弟子"), "a first master: asked first: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	map.advance_npc_heartbeat(2.0)
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.has(LAN_TAKES) and log.has(LAN_FONDLES) and log.has("恭喜您成为晚月庄的第二代弟子。"), "her answer, the 暧昧 line, recruit.c: %s" % [log.slice(-5)])
	_check(NpcApprenticeship.is_master_of(player.state, lan.definition()) and player.shown_title() == "晚月庄第二代弟子" and player.facts.title == "晚月庄第二代弟子" and player.state.affiliation.class_id == &"dancer", "晚月庄第二代弟子, a dancer")
	var learned: LearnResult = service.request_learn(&"tenderzhi")
	_check(_taught(learned) and service.last_lines[0] == "你向蓝止萍请教有关「柔虹指」的疑问。", "she teaches her apprentice 柔虹指: %s" % [service.last_lines])
	ui.close_panel()


## 蓝雨梅 in the reception room teaches the member.
func _test_learn_in_manor(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var yumay: NpcRuntimeState = await _beside(tree, map, session, YUMAY)
	var service: TeacherService = _teacher(map, yumay)
	_check(service != null and _taught(service.request_learn(&"stormdance")), "蓝雨梅 teaches the member 七宝天岚舞: %s" % [[] if service == null else service.last_lines])


## old.c: a member below 160 max_force gets her force for a 杀手令牌 (晚月庄 C), now that
## the player is one.
func _test_old_force(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var state: CharacterState = session.player_runtime().state
	var old: NpcRuntimeState = await _beside(tree, map, session, OLD)
	map.npc_life._advance_ambience(1.0)
	_check(map.select_npc(old.character_id), "无名老妇 selected")
	state.recovery.inner_force = CharacterInternalResourceState.new(40, 100) # TEST-ONLY
	state.attributes.karma = 30
	var original: WorldInteractionRandomSource = map.world_interaction_random_source()
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([30])) # TEST-ONLY: random(50) = 30
	var given: ItemHandlingResult = map.give_to_selected(map.give_new_item_to_player(TOKEN))
	map.replace_world_interaction_random_source(original)
	_check(given.done() and given.lines[0] == "无名老妇说道：作为感谢，我传你一些内力。" and state.recovery.inner_force.maximum == 120 and state.recovery.inner_force.current == 0, "a member of 100: her force (+20): %s" % [given.lines])


## 瑷伦 and 蓝止萍's apprentice of 100000 combat_exp: 拜师 is asked first (要叛师 and a fight
## to the death); 不拜了 changes nothing; confirmed, she shouts and attacks.
func _test_elon_traitor(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	var elon: NpcRuntimeState = await _beside(tree, map, session, ELON)
	var service: TeacherService = _teacher(map, elon)
	_check(service != null and service.takes_apprentices() and service.offers_trial(), "瑷伦 takes apprentices; her test is offered to a woman of 100000")
	if service == null:
		return
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("瑷伦只收没有门派的普通百姓为徒。你现在是晚月庄第二代弟子，向她拜师") and ui.confirm_text.text.contains("她会当你要背叛师门") and ui.confirm_text.text.contains("生死之战"), "asked first, 她: %s" % ui.confirm_text.text)
	ui.keep_button.pressed.emit()
	_check(not ui.is_confirming() and not session.combat_encounter_coordinator().has_active_encounter() and not player.apprenticeship_request.is_pending(), "不拜了: nothing happens")
	ui.apprentice_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter() and elon.relationship.has_lethal_target(player.character_id), "she attacks to kill")
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.has(ELON_ASKED) and log.has("瑷伦大声喝道：晚月庄第二代弟子晚客要叛师！！！") and log.has("看起来瑷伦想杀死你！"), "the request, her shout, kill_ob()'s warning: %s" % [log.slice(-4)])
	await _flee(tree, session)
	player.apprenticeship_request.cancel()


## Her test, not asked first: three lashes stood make an offer (no title yet, 默认); 拜师
## then changes master (asked first): 晚月庄第一代弟子, still a dancer.
func _test_elon_lashes(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var elon: NpcRuntimeState = await _beside(tree, map, session, ELON)
	var service: TeacherService = _teacher(map, elon)
	if service == null:
		return
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY
	player.state.gender = CharacterState.GENDER_MALE # TEST-ONLY
	_check(not service.offers_trial(), "no test for a man (老身不收男徒!)")
	player.state.gender = CharacterState.GENDER_FEMALE
	player.state.progression.combat_experience = 99999 # TEST-ONLY
	_check(not service.offers_trial(), "none short of 100000")
	player.state.progression.combat_experience = 100000
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.refresh()
	_check(ui.trial_button.visible, "the test is offered")
	ui.trial_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("瑷伦的三招是真打") and ui.confirm_text.text.contains("三招都接住，瑷伦便愿意收你为徒，再向她拜师即可。"), "asked first; passing makes an offer: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	var lines: Array[String] = service.last_lines
	_check(lines[0] == LASHES[0] and lines.has(LASHES[2]) and lines.has(PASSED) and lines.has("如果你愿意拜瑷伦为师父，就向她拜师。"), "three lashes stood, then her offer: %s" % [lines])
	_check(player.apprenticeship_request.is_offered(ELON) and player.shown_title() == "晚月庄第二代弟子" and player.facts.title == "晚月庄第二代弟子", "offered; the title comes only when she takes her")
	ui.refresh()
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("你现在是蓝止萍的嫡传弟子。改拜瑷伦为师") and ui.confirm_text.text.contains("以后蓝止萍只教你她的等级超过你三倍的武功。"), "a change of master: asked first: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	_check(NpcApprenticeship.is_master_of(player.state, elon.definition()) and player.state.family.generation == 1 and player.shown_title() == "晚月庄第一代弟子" and player.facts.title == "晚月庄第一代弟子" and player.state.affiliation.class_id == &"dancer", "瑷伦's apprentice: 晚月庄第一代弟子, still a dancer")
	ui.refresh()
	_check(not ui.trial_button.visible, "no test for her own apprentice")
	ui.close_panel()


## 安妮儿's 拜师: no question, her say; the refusal ends the request (默认, DECISIONS 山烟寺 C).
func _test_annihi_in_wing(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var annihi: NpcRuntimeState = await _beside(tree, map, session, ANNIHI)
	var service: TeacherService = _teacher(map, annihi)
	_check(service != null and service.takes_apprentices() and not service.offers_trial(), "安妮儿's panel has 拜师, no test")
	if service == null:
		return
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and service.last_lines == ["你想要拜安妮儿为师。", "安妮儿说道：" + GO_TO_LAN] and session.shared_ui().log_lines()[-1] == "安妮儿说道：" + GO_TO_LAN, "no question; her say: %s" % [service.last_lines])
	ui.refresh()
	_check(not ui.cancel_button.visible and not player.apprenticeship_request.is_pending() and NpcApprenticeship.is_master_of(player.state, _catalog.npc(ELON)), "the request is over (no 取消拜师请求); still 瑷伦's")
	ui.close_panel()


## In a fight with a 婢女: 运功意寒睨 at her, named in the battle log; the player's blows
## with 意寒功 enabled carry its cold (iceforce.c hit_ob(): iceshock).
func _test_chillgaze_fight(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	# TEST-ONLY: 意寒功 300 enabled, force to spare, far above the 婢女.
	state.skills.set_raw_level(&"force", 100)
	state.skills.set_raw_level(&"iceforce", 300)
	state.skills.map_skill(&"force", &"iceforce")
	state.recovery.inner_force = CharacterInternalResourceState.new(1000, 1000)
	state.attributes.force_factor = 10
	state.progression.combat_experience = 1000000
	state.spirit = CharacterResourceState.new(500, 500, 500)
	var servant: NpcRuntimeState = await _beside(tree, map, session, SERVANT)
	servant.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: she outlasts the blows
	var original: CombatRandomSource = session.combat_random_source()
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: every roll its highest
	map.select_npc(servant.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "attacking a 婢女")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	ui.refresh_projection()
	var labels: Array[String] = []
	for info: CombatTacticalActionInfo in ui.current_projection().actions():
		labels.append(ui.action_catalog.label_for(info.action_id))
	_check(labels.has("运功意寒睨"), "the battle panel offers 运功意寒睨: %s" % [labels])
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var gin: int = servant.character_state.essence.current
	coordinator.submit_player_action(CombatTacticalRequest.new(&"gaze:1", coordinator.active_encounter().encounter_id, player.character_id, CombatExertTacticalPolicy.action_id_for(&"chillgaze"), CombatTacticalRequest.Category.INTERNAL_FORCE))
	coordinator.advance_scheduler(0.0)
	ui.refresh_projection()
	var log: String = ui.log_panel._text.get_parsed_text()
	_check(log.contains("你眼神忽然发出异光，双瞳犹如两把利刃般盯著婢女！") and log.contains("婢女被你的目光所摄，不自禁地打了个寒噤。"), "the stare at her, named: %s" % log.right(200))
	_check(state.recovery.inner_force.current == 950 and player.busy.is_busy() and servant.character_state.essence.current == gin - 17, "50 force, busy; gin 10 * 2 - 50 / 15 = 17")
	var cold: String = "你的招式挟著一股阴寒无比的劲风使得婢女不禁打了个寒噤。"
	# Every roll its highest would leave both sides circling (伺机出手) for ever.
	session.configure_combat_random_source(original)
	for beat: int in 60:
		if log.contains(cold) or not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
		log = ui.log_panel._text.get_parsed_text()
	_check(log.contains(cold) and servant.character_state.conditions.has_condition(ConditionIds.ICE_SHOCK), "a blow carries 意寒功's cold, and iceshock: %s" % log.right(300))
	# With no current target the file's own offensive_target() finds her (the only enemy).
	while player.busy.is_busy():
		player.busy.advance() # TEST-ONLY
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var policy := CombatExertTacticalPolicy.new(&"chillgaze", Callable(), Callable(), func(id: StringName) -> String: return session.encounter_display_name(id))
	var context := CombatTacticalContext.new(session.resolve_encounter_binding(player.character_id), null, CombatEncounterMode.Value.LETHAL, null, bindings)
	_check(policy.validate_execution(context) == CombatTacticalResult.Code.ACCEPTED, "no current target: accepted")
	var untargeted: CombatTacticalExecutionResult = policy.execute(context, Forced.new())
	_check(ColoredLine.texts(untargeted.lines()).slice(0, 1) == ["你眼神忽然发出异光，双瞳犹如两把利刃般盯著婢女！"], "no current target: offensive_target() is the 婢女: %s" % [ColoredLine.texts(untargeted.lines())])
	# Her unconscious in the fight to the death: the gaze still reaches her (a 字诀 would too).
	while player.busy.is_busy():
		player.busy.advance() # TEST-ONLY
	servant.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	var force: int = state.recovery.inner_force.current
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: she does not look away
	var queued: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(&"gaze:2", coordinator.active_encounter().encounter_id, player.character_id, CombatExertTacticalPolicy.action_id_for(&"chillgaze"), CombatTacticalRequest.Category.INTERNAL_FORCE))
	coordinator.advance_scheduler(0.0)
	session.configure_combat_random_source(original)
	_check(queued.code == CombatTacticalResult.Code.ACCEPTED and state.recovery.inner_force.current == force - 50, "her lying there: the queued gaze still stares at her (50 force)")
	servant.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY
	await _flee(tree, session)


## Save/Continue keeps 瑷伦's apprentice, her title and 意寒功.
func _test_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	while player.busy.is_busy():
		player.busy.advance() # TEST-ONLY
	# TEST-ONLY: Continue recomputes max gin, kee and sen (race/human.c); the fixtures above set them by hand.
	CharacterDerivedValues.refresh_human_player_maxima(player.state, player.facts.age)
	for resource: CharacterResourceState in [player.state.essence, player.state.vitality, player.state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save")
	if snapshot == null:
		return
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "晚月庄 D")
	_check(walker._failures.is_empty(), "Save/Continue restores 瑷伦's apprentice exactly: " + str(walker._failures))


# --- Helpers ------------------------------------------------------------------------

static func _fresh(gender: StringName) -> CharacterState:
	return NewPlayerInitializationPolicy.create(gender, "晚月").state


static func _student(gender: StringName) -> CharacterState:
	var state: CharacterState = _fresh(gender)
	state.progression.potential = 100 # TEST-ONLY
	return state


## 蓝止萍's apprentice with potential to spend.
func _member() -> CharacterState:
	var state: CharacterState = _student(CharacterState.GENDER_FEMALE)
	var request := NpcApprenticeship.new()
	request.request(state, _catalog.npc(LAN), _catalog.family(FAMILY), 1, "姑娘")
	request.answer(state, _catalog.npc(LAN), _catalog.family(FAMILY), 2, "姑娘")
	return state


## learn.c's reject_msg lines as `npc` says them.
static func _reject_lines(npc: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in NpcRecognitionPolicy.REJECT_LINES:
		out.append(line % npc)
	return out


## The teacher admitted the student (learn.c went past recognize_apprentice() and prevent_learn()).
static func _taught(result: LearnResult) -> bool:
	return result != null and result.failure_reason not in [LearnResult.FailureReason.RECOGNITION_REJECTED, LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, LearnResult.FailureReason.TEACHER_PREVENTED, LearnResult.FailureReason.SKILL_LEARN_REJECTED]


## learn <skill> from the NPC standing at full sen; [LearnResult, its lines].
func _learn(student: CharacterState, npc_id: StringName, skill_id: StringName, draws: Array[int]) -> Array:
	var definition: NpcDefinition = _catalog.npc(npc_id)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"latemoon.manor.test", &"latemoon.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
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


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _teacher(map: WorldMapController, npc: NpcRuntimeState) -> TeacherService:
	for service: WorldService in map.service_nodes:
		if service is TeacherService and npc != null and (service as TeacherService).npc.character_id == npc.character_id:
			return service as TeacherService
	return null


## TEST-ONLY: the player beside the NPC, where its teaching reaches.
func _beside(tree: SceneTree, map: WorldMapController, session: WorldSessionController, definition_id: StringName) -> NpcRuntimeState:
	var npc: NpcRuntimeState = _npc(map, definition_id)
	var body: WorldCharacterBody2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = Vector2.INF if body == null else MapPlaces.spot(map, npc.world_location().zone_id, body.global_position + Vector2(0, 56), 60.0)
	if at != Vector2.INF:
		map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(npc.world_location().zone_id)), "TEST-ONLY: beside %s" % definition_id)
	await tree.physics_frame
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	return npc


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
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight is over: " + coordinator.last_abort_detail())
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("晚月庄 D: " + label)
