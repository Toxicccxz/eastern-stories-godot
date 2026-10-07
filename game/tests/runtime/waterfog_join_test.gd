extends RefCounted

## 水烟阁 B: joining 天邪派 and learning from its masters. 萧辟尘's oath (master.c
## attempt_apprentice() and do_swear(); owner: a fixed 发誓恪守门规 button), 於兰天武's
## three-blow test (champion.c do_accept(); owner: asked first), recruit.c's offer when
## the student has not asked, his privs 0 (learn.c: only his own learn from him), the
## arts' valid_learn() and practice_skill() (天邪神功 by 杀气, 天邪神掌's two lines,
## 七宝天岚舞's sen), the 正厅's join (std/room/class_guild.c) and score.c's rank.
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Master := preload("res://tests/support/snow_master.gd")
const MASTER: StringName = &"common.npc.fighter.master"
const CHAMPION: StringName = &"common.npc.fighter.champion"
const CELESTIAL: StringName = &"family.celestial"
const LONGSWORD: StringName = &"es2:obj/longsword"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_oath()
	_test_trial_rule()
	_test_learn()
	_test_practice()
	_test_data()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_hall(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## 萧辟尘: asked for an oath once, 多说无益 when asked again; the oath recruits; an oath
## sworn after the request moved on is recruit.c's offer, taken by the next 拜师.
func _test_oath() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var master: NpcDefinition = catalog.npc(MASTER)
	var family: FamilyDefinition = catalog.family(CELESTIAL)
	var rule: NpcTeaching.ApprenticeRule = master.teaching().apprentice
	_check(rule.kind == NpcTeaching.Kind.OATH and rule.oath == "守门规" and rule.class_id.is_empty() and master.teaching().family_privileges == -1, "萧辟尘 takes apprentices by an oath, gives no class, teaches every member")
	var state: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	var request := NpcApprenticeship.new()
	_check(request.swear(state, master, family, 1, "小姑娘") == NpcApprenticeship.Outcome.NOT_ASKED and request.lines.is_empty(), "no oath asked: swear is no command")
	_check(request.request(state, master, family, 100, "小姑娘") == NpcApprenticeship.Outcome.ASKED and request.lines == ["你想要拜萧辟尘为师。", "萧辟尘说道：我天邪派门规甚严，小姑娘如果真的有心，且发个誓来。"], "拜师: he asks for an oath (its (swear) dropped): %s" % [request.lines])
	_check(request.awaits_oath(MASTER) and not state.family.has_family() and not request.takes_at_once(state, master) and request.recruit_takes_at_once(state, master), "nothing yet; the oath would take her at once")
	_check(request.request(state, master, family, 101, "小姑娘") == NpcApprenticeship.Outcome.PENDING and request.lines == ["你想拜萧辟尘为师，但是对方还没有答应。"], "asking again while it waits")
	request.cancel()
	_check(request.request(state, master, family, 102, "小姑娘") == NpcApprenticeship.Outcome.ASKED and request.lines == ["你想要拜萧辟尘为师。", "萧辟尘说道：多说无益，若不发誓恪守门规，便是跪著求我也没用。"], "asked again with the oath still owed: 多说无益")
	_check(request.swear(state, master, family, 200, "小姑娘") == NpcApprenticeship.Outcome.RECRUITED and request.lines == ["你发誓道：守门规", "萧辟尘说道：这就是了。", "萧辟尘决定收你为弟子。", "你跪了下来向萧辟尘恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为天邪派的第十七代弟子。"], "the oath: 这就是了, and he takes her: %s" % [request.lines])
	_check(NpcApprenticeship.is_master_of(state, master) and state.family.family_id == CELESTIAL and state.family.generation == 17 and state.affiliation.class_id.is_empty() and state.affiliation.entry_time_utc == 200 and not request.is_pending(), "天邪派's seventeenth generation; no class (fighter masters give none)")
	_check(not request.awaits_oath(MASTER) and request.swear(state, master, family, 201, "小姑娘") == NpcApprenticeship.Outcome.NOT_ASKED, "the oath is sworn once")
	_check(request.request(state, master, family, 202, "小姑娘") == NpcApprenticeship.Outcome.ACKNOWLEDGED and request.lines == ["你恭恭敬敬地向萧辟尘磕头请安，叫道：「师父！」"], "his apprentice greets him")
	# A 封山剑派 disciple: the oath after the request moved to 柳淳风 is an offer.
	var other: CharacterState = _fresh(CharacterState.GENDER_MALE)
	var asked := NpcApprenticeship.new()
	asked.request(other, master, family, 1, "壮士")
	_check(Master.recruit(other, 2, asked) == NpcApprenticeship.Outcome.RECRUITED and other.affiliation.class_id == &"swordsman" and asked.awaits_oath(MASTER), "TEST-ONLY: he then joins 封山剑派 (class swordsman); the oath is still owed")
	_check(asked.swear(other, master, family, 3, "壮士") == NpcApprenticeship.Outcome.OFFERED and asked.lines == ["你发誓道：守门规", "萧辟尘说道：这就是了。", "萧辟尘想要收你为弟子。", "如果你愿意拜萧辟尘为师父，就向他拜师。"], "recruit.c without his request: an offer: %s" % [asked.lines])
	_check(asked.is_offered(MASTER) and asked.takes_at_once(other, master) and NpcApprenticeship.would_betray(other, master) and other.family.family_id == Master.FAMILY_ID, "still 封山剑派; the next 拜师 betrays it")
	other.progression.score = 9 # TEST-ONLY
	_check(asked.request(other, master, family, 4, "壮士") == NpcApprenticeship.Outcome.RECRUITED and asked.lines == ["你决定背叛师门，改投入萧辟尘门下！！", "你跪了下来向萧辟尘恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为天邪派的第十七代弟子。"], "apprentice.c's first branch: betrayal: %s" % [asked.lines])
	_check(other.apprenticeship.betrayer_count == 1 and other.progression.score == 0 and other.affiliation.class_id == &"swordsman" and not asked.is_offered(MASTER), "betrayer 1, score 0, still a swordsman's class")


## 於兰天武's rule: what 拜师 says, then the test: a failure after any of the three blows,
## or the three stood and his recruit (at once when the request waits on him, else an offer).
func _test_trial_rule() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var champion: NpcDefinition = catalog.npc(CHAMPION)
	var family: FamilyDefinition = catalog.family(CELESTIAL)
	var rule: NpcTeaching.ApprenticeRule = champion.teaching().apprentice
	_check(rule.kind == NpcTeaching.Kind.TRIAL and rule.blows.size() == 3 and rule.class_id.is_empty() and champion.teaching().family_privileges == 0, "於兰天武: a three-blow test, no class, privs 0")
	var state: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	var request := NpcApprenticeship.new()
	_check(request.request(state, champion, family, 1, "小姑娘") == NpcApprenticeship.Outcome.ASKED and request.lines == ["你想要拜於兰天武为师。", "於兰天武说道：小姑娘若真的有心，不妨让我看看你的所学", "如果想拜师的话，就请接受测试"], "拜师: his say() (shown, owner) and tell_object(): %s" % [request.lines])
	var fails: Array[String] = ["於兰天武叹了口气，说道：连第一招都撑不过，真是自不量力....", "於兰天武「哼」地一声，说道：便是有这许多不怕死的家伙....", "於兰天武叹道：可惜，难道老夫一身武功竟无传人...."]
	var says: Array[String] = ["於兰天武点了点头，说道：很好，这是第一招....", "於兰天武说道：这是第二招....", "於兰天武说道：第三招来了...."]
	for failing: int in 3:
		var struck: Array[int] = [0]
		var result: NpcApprenticeTrial.Result = NpcApprenticeTrial.run(rule, request,
			func() -> Array[ColoredLine]:
				struck[0] += 1
				var seen: Array[ColoredLine] = [ColoredLine.new("（一招）")]
				return seen,
			func() -> bool: return struck[0] <= failing,
			func() -> NpcApprenticeship.Outcome: return NpcApprenticeship.Outcome.AUTHORITY_FAILURE)
		var expected: Array[String] = []
		for blow: int in failing + 1:
			expected.append_array([says[blow], "（一招）"])
		expected.append(fails[failing])
		_check(result.outcome == NpcApprenticeTrial.Outcome.FAILED and result.blows == failing + 1 and ColoredLine.texts(result.lines) == expected, "not stood after blow %d: its line ends it: %s" % [failing + 1, ColoredLine.texts(result.lines)])
	_check(not state.family.has_family() and request.is_pending_with(CHAMPION), "failing changes nothing")
	var never: NpcApprenticeTrial.Result = NpcApprenticeTrial.run(rule, request,
		func() -> Variant: return null,
		func() -> bool: return true,
		func() -> NpcApprenticeship.Outcome: return request.npc_recruit(state, champion, family, 4))
	_check(never.outcome == NpcApprenticeTrial.Outcome.NOT_RUN and never.lines.is_empty() and never.blows == 0 and not state.family.has_family(), "no blow could be struck: no test, nothing said, nobody taken")
	var passed: NpcApprenticeTrial.Result = NpcApprenticeTrial.run(rule, request,
		func() -> Array[ColoredLine]:
			var seen: Array[ColoredLine] = []
			return seen,
		func() -> bool: return true,
		func() -> NpcApprenticeship.Outcome: return request.npc_recruit(state, champion, family, 5))
	_check(passed.outcome == NpcApprenticeTrial.Outcome.PASSED and passed.recruit == NpcApprenticeship.Outcome.RECRUITED and ColoredLine.texts(passed.lines) == says + ["於兰天武哈哈大笑，说道：今日老夫终於觅得一个可造之才！", "於兰天武决定收你为弟子。", "你跪了下来向於兰天武恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为天邪派的第十六代弟子。"], "three stood: 可造之才, and he takes her: %s" % [ColoredLine.texts(passed.lines)])
	_check(state.family.generation == 16 and NpcApprenticeship.is_master_of(state, champion), "天邪派's sixteenth generation, his apprentice")
	_check(request.npc_recruit(state, champion, family, 6) == NpcApprenticeship.Outcome.ACKNOWLEDGED and request.lines == ["於兰天武拍拍你的头，说道：「好徒儿！」"], "his own apprentice passing again: 好徒儿 (the panel does not offer it)")
	var stranger: CharacterState = _fresh(CharacterState.GENDER_MALE)
	var none := NpcApprenticeship.new()
	_check(none.npc_recruit(stranger, champion, family, 7) == NpcApprenticeship.Outcome.OFFERED and none.lines == ["於兰天武想要收你为弟子。", "如果你愿意拜於兰天武为师父，就向他拜师。"] and none.is_offered(CHAMPION) and not stranger.family.has_family(), "passed without asking him: an offer")
	_check(none.npc_recruit(stranger, champion, family, 7) == NpcApprenticeship.Outcome.OFFERED and none.lines.is_empty(), "offered again: recruit.c tells only him (对方还没有答应)")
	_check(none.request(stranger, champion, family, 8, "壮士") == NpcApprenticeship.Outcome.RECRUITED and none.lines == ["你决定拜於兰天武为师。", "你跪了下来向於兰天武恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为天邪派的第十六代弟子。"], "then 拜师 takes him at once (no family: no betrayal, as recruit.c; apprentice.c compared without asking): %s" % [none.lines])
	_check(stranger.apprenticeship.betrayer_count == 0 and NpcApprenticeship.would_change_master(stranger, GameContent.catalog().npc(MASTER)) and not NpcApprenticeship.would_change_master(stranger, champion), "no betrayal counted; going to 萧辟尘 would change master inside the family")


## learn.c with the two masters: 於兰天武 (privs 0) teaches only his apprentices; 萧辟尘
## every member. valid_learn(): 天邪神功 by 杀气 (query_skill() without raw: half the
## level, 50 a point), 七宝天岚舞 for women of spi 20, 六阴追魂剑法 max_force 100 and a sword.
func _test_learn() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var master: NpcDefinition = catalog.npc(MASTER)
	var champion: NpcDefinition = catalog.npc(CHAMPION)
	var family: FamilyDefinition = catalog.family(CELESTIAL)
	var his: CharacterState = _student(CharacterState.GENDER_FEMALE)
	NpcApprenticeship.new().npc_recruit(his, champion, family, 1) # an offer only
	var taken := NpcApprenticeship.new()
	taken.request(his, champion, family, 1, "小姑娘")
	taken.npc_recruit(his, champion, family, 2)
	_check(NpcApprenticeship.is_master_of(his, champion), "TEST-ONLY: 於兰天武's apprentice")
	_check((_learn(his, CHAMPION, &"force", [0])[0] as LearnResult).success, "his apprentice learns from him")
	var theirs: CharacterState = _student(CharacterState.GENDER_FEMALE)
	var sworn := NpcApprenticeship.new()
	sworn.request(theirs, master, family, 1, "小姑娘")
	sworn.swear(theirs, master, family, 2, "小姑娘")
	var refused: Array = _learn(theirs, CHAMPION, &"force", [0])
	_check(not (refused[0] as LearnResult).success and theirs.skills.raw_level(&"force") == 0 and (refused[1] as Array).size() == 1 and String(refused[1][0]).begins_with("於兰天武"), "萧辟尘's apprentice: 於兰天武 (privs 0) politely refuses: %s" % [refused[1]])
	_check((_learn(theirs, MASTER, &"force", [0])[0] as LearnResult).success, "萧辟尘 teaches his own")
	_check((_learn(his, MASTER, &"force", [0])[0] as LearnResult).success, "and any member (privs -1, his raw 100 over three times hers)")
	theirs.skills.set_raw_level(&"celestial", 1)
	_check((_learn(theirs, MASTER, &"celestial", [0])[0] as LearnResult).success, "天邪神功 at 1: half of it is 0, no 杀气 needed")
	theirs.skills.set_raw_level(&"celestial", 2)
	theirs.attributes.bellicosity = 49 # TEST-ONLY
	var short: Array = _learn(theirs, MASTER, &"celestial", [0])
	_check(not (short[0] as LearnResult).success and short[1] == ["你的杀气不够，无法领悟更高深的天邪神功。"], "at 2 (half: 1) it takes 50 杀气: %s" % [short[1]])
	theirs.attributes.bellicosity = 50 # TEST-ONLY
	_check((_learn(theirs, MASTER, &"celestial", [0])[0] as LearnResult).success, "50 is enough")
	_check(_learn(_member(CharacterState.GENDER_MALE), MASTER, &"stormdance", [0])[1] == ["七宝天岚舞只有女性才能练。"], "七宝天岚舞: women only")
	var dancer: CharacterState = _member(CharacterState.GENDER_FEMALE)
	dancer.attributes.spirituality = 19 # TEST-ONLY
	_check(_learn(dancer, MASTER, &"stormdance", [0])[1] == ["你的灵性不够，没有办法练七宝天岚舞。"], "spi 19 is not enough")
	dancer.attributes.spirituality = 20 # TEST-ONLY
	_check((_learn(dancer, MASTER, &"stormdance", [0])[0] as LearnResult).success and dancer.skills.raw_level(&"stormdance") >= 0 and dancer.skills.has_raw_level(&"stormdance"), "spi 20: she learns it")
	var swordsman: CharacterState = _member(CharacterState.GENDER_MALE)
	_check(_learn(swordsman, MASTER, &"six-chaos-sword", [0])[1] == ["你的内力不够，没有办法练六阴追魂剑。"], "六阴追魂剑法: max_force 100 first")
	swordsman.recovery.inner_force.maximum = 100 # TEST-ONLY
	_check(_learn(swordsman, MASTER, &"six-chaos-sword", [0])[1] == ["你必须先找一把剑才能练剑法。"], "then a sword in hand")


## practice.c: valid_learn() first, then practice_skill(): 天邪神功 refuses; 天邪神掌's kee
## and force lines; 七宝天岚舞 costs sen; 六阴追魂剑法's line and its 杀气 on a level.
func _test_practice() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var palm: CharacterState = _member(CharacterState.GENDER_MALE)
	palm.skills.set_raw_level(&"unarmed", 10)
	palm.skills.set_raw_level(&"celestrike", 5)
	palm.skills.set_raw_level(&"celestial", 19)
	palm.skills.map_skill(&"unarmed", &"celestrike")
	palm.recovery.inner_force.maximum = 100
	palm.recovery.inner_force.current = 10
	_check(_practice(palm, &"unarmed", registry) == ["你的天邪神功火候不足，无法练天邪掌法。"], "天邪神掌: 天邪神功 20 first")
	palm.skills.set_raw_level(&"celestial", 20)
	palm.vitality = CharacterResourceState.new(29, 100, 100)
	_check(_practice(palm, &"unarmed", registry) == ["你的体力不够了，休息一下再练吧。"], "kee 29: its kee line")
	palm.vitality = CharacterResourceState.new(100, 100, 100)
	palm.recovery.inner_force.current = 4
	_check(_practice(palm, &"unarmed", registry) == ["你的内力不够了，休息一下再练吧。"], "force 4: its other line")
	palm.recovery.inner_force.current = 10
	var done: Array[String] = _practice(palm, &"unarmed", registry)
	_check(done.back() == "你的天邪神掌进步了！" and palm.vitality.current == 70 and palm.recovery.inner_force.current == 5, "practised: 30 kee and 5 force: %s" % [done])
	var dancer: CharacterState = _member(CharacterState.GENDER_FEMALE)
	dancer.attributes.spirituality = 20
	dancer.skills.set_raw_level(&"dodge", 10)
	dancer.skills.set_raw_level(&"stormdance", 5)
	dancer.skills.map_skill(&"dodge", &"stormdance")
	dancer.spirit = CharacterResourceState.new(29, 100, 100)
	_check(_practice(dancer, &"dodge", registry) == ["你的精神太差了，不能练七宝天岚舞。"], "七宝天岚舞: sen 29")
	dancer.spirit = CharacterResourceState.new(30, 100, 100)
	_check(_practice(dancer, &"dodge", registry).back() == "你的七宝天岚舞进步了！" and dancer.spirit.current == 0 and dancer.vitality.current == dancer.vitality.maximum, "sen 30: practised, 30 sen and no kee")
	var force: CharacterState = _member(CharacterState.GENDER_MALE)
	force.skills.set_raw_level(&"force", 10)
	force.skills.set_raw_level(&"celestial", 2)
	force.skills.map_skill(&"force", &"celestial")
	_check(_practice(force, &"force", registry) == ["你的杀气不够，无法领悟更高深的天邪神功。"], "天邪神功: valid_learn()'s 杀气 first")
	force.attributes.bellicosity = 50
	_check(_practice(force, &"force", registry) == ["天邪神功只能用学的，或是从运用(exert)中增加熟练度。"], "then it refuses practice")
	var blade: CharacterState = _member(CharacterState.GENDER_MALE)
	blade.skills.set_raw_level(&"sword", 30)
	blade.skills.set_raw_level(&"six-chaos-sword", 1)
	blade.skills.map_skill(&"sword", &"six-chaos-sword")
	blade.recovery.inner_force.maximum = 100
	blade.recovery.inner_force.current = 10
	blade.equipment.wield(EquippedWeaponRef.new(&"test.sword", catalog.item(LONGSWORD).weapon_definition()), false) # TEST-ONLY
	var chaos: Array[String] = _practice(blade, &"sword", registry)
	_check(chaos[0] == "你按著所学练了一遍六阴追魂剑法。" and blade.skills.raw_level(&"six-chaos-sword") == 2 and blade.attributes.bellicosity == 100, "六阴追魂剑法: its line; level 2 and 100 杀气 (skill_improved()): %s" % [chaos])
	var bat: CharacterState = _member(CharacterState.GENDER_MALE)
	bat.skills.set_raw_level(&"dodge", 10)
	bat.skills.set_raw_level(&"pyrobat-steps", 5)
	bat.skills.map_skill(&"dodge", &"pyrobat-steps")
	bat.vitality = CharacterResourceState.new(29, 100, 100)
	_check(_practice(bat, &"dodge", registry) == ["你的体力太差了，不能练火蝠身法。"], "火蝠身法: kee 29")


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var dance: SkillDefinition = catalog.skill(&"stormdance")
	_check(dance != null and dance.display_name == "七宝天岚舞" and dance.can_enable_for(&"dodge") and not dance.can_enable_for(&"move") and dance.dodge_messages.size() == 5, "七宝天岚舞: dodge only, five dodges")
	_check(NpcTeacher.teachable_skills(catalog.npc(MASTER), catalog).has(&"stormdance"), "萧辟尘 teaches it")
	var npcs: String = FileAccess.get_file_as_string("res://data/common/npcs.json")
	_check(npcs.contains("得接我三招不死，你想试试？") and not npcs.contains("(accept test)") and not npcs.contains("(swear)"), "the command hints are gone from the lines (owner)")
	var joiner: CharacterState = _fresh(CharacterState.GENDER_MALE)
	_check(ClassGuild.join(joiner, &"fighter") == ClassGuild.Outcome.JOINED and joiner.affiliation.class_id == &"fighter", "class_guild.c do_join(): no class, a 武者")
	_check(ClassGuild.join(joiner, &"fighter") == ClassGuild.Outcome.REFUSED and ClassGuild.join(_member(CharacterState.GENDER_MALE), &"") == ClassGuild.Outcome.INVALID, "a class already: refused; no class to give: nothing")
	var swordsman: CharacterState = _fresh(CharacterState.GENDER_MALE)
	Master.recruit(swordsman, 1)
	_check(ClassGuild.join(swordsman, &"fighter") == ClassGuild.Outcome.REFUSED and swordsman.affiliation.class_id == &"swordsman", "柳淳风's disciple (剑士) is refused")
	_check(RankWords.query_rank(CharacterState.GENDER_FEMALE, &"fighter") == "【 女武者 】" and RankWords.query_rank(CharacterState.GENDER_MALE, &"fighter") == "【 武  者 】" and RankWords.query_rank(CharacterState.GENDER_MALE, &"") == "【 平  民 】" and RankWords.query_rank(CharacterState.GENDER_MALE, &"dancer") == "【 平  民 】", "rankd.c query_rank()")


## In the 正厅: 萧辟尘's panel (拜师, the oath asked first as a first master), the sign's
## join, 於兰天武's test asked first, passed by a strong player, failed by a weak one
## (who falls on the heart beat after).
func _test_hall(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"waterfog.pavilion", &"waterfog.guildhall", &"waterfog.guildhall", &"waterfog.entrance.yard_arrival").succeeded() or session.handoff_to(&"waterfog.pavilion", &"waterfog.entrance", &"waterfog.entrance", &"waterfog.entrance.yard_arrival").succeeded(), "in the pavilion")
	await tree.physics_frame
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var master: NpcRuntimeState = _first(map, MASTER)
	var champion: NpcRuntimeState = _first(map, CHAMPION)
	_check(map.relocate_player(&"waterfog.guildhall", master.spawn_point_id), "beside 萧辟尘")
	await tree.physics_frame
	var hall: TeacherService = map.service(&"waterfog.pavilion.guildhall.master") as TeacherService
	hall.ui.interact()
	var ui: TeacherPanel = hall.ui
	_check(ui.panel.visible and ui.oath_button != null and not ui.oath_button.visible and ui.trial_button == null, "his panel: 拜师; no oath owed yet")
	ui.apprentice_button.pressed.emit()
	ui.refresh()
	_check(not ui.is_confirming() and hall.last_lines.size() == 2 and ui.oath_button.visible, "拜师 asks for the oath, not a question: %s" % [hall.last_lines])
	ui.oath_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("拜萧辟尘为师，便成为天邪派的弟子") and ui.confirm_button.text == "确定发誓" and not player.state.family.has_family(), "the oath makes her his: asked first as a first master: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.shown_title() == "天邪派第十七代弟子" and hall.last_lines[0] == "你发誓道：守门规", "sworn: 天邪派第十七代弟子: %s" % [hall.last_lines])
	ui.refresh()
	_check(not ui.oath_button.visible, "no oath owed any more")
	ui.close_panel()
	# The sign: join.
	_check(map.select_landmark(&"waterfog.guildhall.landmark.sign"), "the 樟木匾")
	hud.refresh_live_state()
	_check(hud.portal_action_is_enabled() and hud.portal_button.text == "加入武者同盟", "its action: 加入武者同盟")
	hud.portal_button.pressed.emit()
	_check(player.state.affiliation.class_id == &"fighter" and hud.log_lines().back() == "恭喜，从今天起您已经成为一名武者！", "join: a 武者")
	hud.portal_button.pressed.emit()
	_check(hud.log_lines().back() == "你已经参加了其他公会。" and player.state.affiliation.class_id == &"fighter", "join again: refused")
	hud.open_character()
	_check(hud._presentation_layout.character.sheet.text.contains(RankWords.query_rank(player.state.gender, &"fighter") + "天邪派第十七代弟子"), "score.c's rank on the sheet")
	hud.dismiss_current_panel()
	# 於兰天武's test: a strong player who asked him first.
	_check(map.relocate_player(&"waterfog.guildhall", champion.spawn_point_id), "beside 於兰天武")
	await tree.physics_frame
	session.configure_combat_random_source(Specials.Pattern.new([])) # TEST-ONLY: every roll its highest: every blow lands in full
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY
	var test: TeacherService = map.service(&"waterfog.pavilion.guildhall.champion") as TeacherService
	test.ui.interact()
	var panel: TeacherPanel = test.ui
	_check(panel.trial_button != null and panel.trial_button.visible and panel.oath_button == null, "his panel offers the test")
	panel.apprentice_button.pressed.emit()
	panel.trial_button.pressed.emit()
	var asked: String = panel.confirm_text.text
	_check(panel.is_confirming() and asked.begins_with("於兰天武的三招是真打") and asked.contains("伤得太重会死") and asked.contains("你现在是萧辟尘的嫡传弟子；三招都接住，便改拜於兰天武为师，萧辟尘就不再是你的师父。") and asked.contains("以后萧辟尘只教你他的等级超过你三倍的武功。") and panel.confirm_button.text == "接受测试", "asked first: real blows, a fall, death, and what passing does (a change of master): %s" % asked)
	panel.keep_button.pressed.emit()
	_check(not panel.is_confirming() and player.state.vitality.current == 100000, "不试了: nothing happens")
	panel.trial_button.pressed.emit()
	panel.confirm_button.pressed.emit()
	var lines: Array[String] = test.last_lines
	_check(lines[0] == "於兰天武点了点头，说道：很好，这是第一招...." and lines.has("於兰天武说道：第三招来了....") and lines.has("於兰天武哈哈大笑，说道：今日老夫终於觅得一个可造之才！"), "three blows stood: %s" % [lines])
	_check(lines.filter(func(line: String) -> bool: return line.contains("妖刀狗屠")).size() >= 3 and player.state.vitality.current < 100000, "his blade's blows land, told as in a fight")
	_check(NpcApprenticeship.is_master_of(player.state, champion.definition()) and player.state.family.generation == 16 and player.shown_title() == "天邪派第十六代弟子" and player.state.affiliation.class_id == &"fighter", "his apprentice now (same family: no betrayal), still a 武者")
	panel.refresh()
	_check(not panel.trial_button.visible, "no test for his own apprentice (owner)")
	var learned: LearnResult = test.request_learn(&"celestrike")
	_check(learned.failure_reason != LearnResult.FailureReason.RECOGNITION_REJECTED and learned.failure_reason != LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, "he teaches his apprentice")
	panel.close_panel()
	# Back to 萧辟尘 by the oath: a change of master, asked first.
	_check(map.relocate_player(&"waterfog.guildhall", master.spawn_point_id), "beside 萧辟尘 again")
	await tree.physics_frame
	hall.ui.interact()
	ui.apprentice_button.pressed.emit()
	ui.oath_button.pressed.emit()
	var change: String = ui.confirm_text.text
	_check(ui.is_confirming() and change.begins_with("你现在是於兰天武的嫡传弟子。改拜萧辟尘为师，於兰天武就不再是你的师父") and change.contains("於兰天武只教嫡传弟子，以后不再教你。"), "the oath would change master: asked first: %s" % change)
	ui.confirm_button.pressed.emit()
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.state.family.generation == 17, "萧辟尘's apprentice again")
	ui.close_panel()
	# A weak one: falls on the heart beat after the first blow.
	_check(map.relocate_player(&"waterfog.guildhall", champion.spawn_point_id), "beside 於兰天武 again")
	await tree.physics_frame
	player.state.vitality = CharacterResourceState.new(50, 100000, 100000) # TEST-ONLY: a wound does not kill
	test.ui.interact()
	panel.refresh()
	_check(panel.trial_button.visible, "萧辟尘's apprentice may take it")
	player.apprenticeship_request._offers[CHAMPION] = true # TEST-ONLY: as if he had offered
	panel.refresh()
	_check(not panel.trial_button.visible, "not offered while his offer stands (拜师 takes her)")
	player.apprenticeship_request._offers.erase(CHAMPION)
	panel.refresh()
	panel.trial_button.pressed.emit()
	_check(panel.confirm_text.text.contains("三招都接住，於兰天武便愿意收你为徒，再向他拜师即可。"), "not asked him first: passing would be an offer")
	panel.confirm_button.pressed.emit()
	_check(test.last_lines.back() == "於兰天武叹了口气，说道：连第一招都撑不过，真是自不量力...." and test.last_lines.size() >= 3, "the first blow not stood: %s" % [test.last_lines])
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and player.relationship.last_damage_from_id == champion.character_id, "she falls unconscious; he hit her last")
	await tree.process_frame
	await tree.process_frame
	_check(not panel.panel.visible, "the panel closes")


static func _fresh(gender: StringName) -> CharacterState:
	return NewPlayerInitializationPolicy.create(gender, "天邪").state


## A fresh character with potential to spend.
static func _student(gender: StringName) -> CharacterState:
	var state: CharacterState = _fresh(gender)
	state.progression.potential = 100 # TEST-ONLY
	return state


## 萧辟尘's apprentice with potential to spend.
static func _member(gender: StringName) -> CharacterState:
	var state: CharacterState = _student(gender)
	var request := NpcApprenticeship.new()
	var catalog: ContentCatalog = GameContent.catalog()
	request.request(state, catalog.npc(MASTER), catalog.family(CELESTIAL), 1, "壮士")
	request.swear(state, catalog.npc(MASTER), catalog.family(CELESTIAL), 2, "壮士")
	return state


## learn <skill> from the NPC standing at full sen; [LearnResult, its lines].
func _learn(student: CharacterState, npc_id: StringName, skill_id: StringName, draws: Array[int]) -> Array:
	var catalog: ContentCatalog = GameContent.catalog()
	var definition: NpcDefinition = catalog.npc(npc_id)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"waterfog.pavilion.guildhall.test", &"waterfog.guildhall.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
	var random := ScriptedWorldInteractionRandomSource.new(draws)
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, false, random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = catalog.skill(skill_id)
	var result: LearnResult = LearnService.learn(student, context, skill, registry.policy_for(skill_id), null, random)
	var respect: String = RankWords.query_respect(student.gender, 14, student.affiliation.class_id)
	return [result, LearnLines.lines(result, definition.display_name, skill, student, context, respect)]


func _practice(state: CharacterState, use_id: StringName, registry: SkillLearnPolicyRegistry) -> Array[String]:
	var special: StringName = state.skills.mapped_skill(use_id)
	var skill: SkillDefinition = GameContent.catalog().skill(special)
	var result: PracticeResult = PracticeService.practice(state, use_id, skill.practice_policy(), registry.policy_for(special), false)
	return ColoredLine.texts(TrainingLines.practice(result, skill))


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
