extends RefCounted

## The player's own training (offense/defense routes B) in Core: enable.c with its
## lines and internal power reset, practice.c with skills.json's practice_skill()
## and valid_learn() lines, exercise.c, selflearn.c and study.c, as TrainingLines
## prints them.

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary:
	_test_skill_data()
	_test_enable()
	_test_practice()
	_test_exercise()
	_test_self_learn()
	_test_study()
	return {"assertions": _assertions, "failures": _failures}


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("martial training: " + label)


func _texts(lines: Array[ColoredLine]) -> Array[String]:
	return ColoredLine.texts(lines)


func _skill(id: StringName) -> SkillDefinition:
	return GameContent.catalog().skill(id)


func _character() -> CharacterState:
	var character := CharacterState.new()
	for resource: CharacterResourceState in [character.essence, character.vitality, character.spirit]:
		resource.maximum = 100
		resource.effective = 100
		resource.current = 100
	character.attributes.intelligence = 20
	character.attributes.spirituality = 20
	character.attributes.constitution = 20
	character.progression.potential = 100
	return character


## A 封山 student: sword 20 / fonxansword 10 enabled for sword, force 10 /
## fonxanforce 10 enabled for force, max_force 50, a sword in hand.
func _student() -> CharacterState:
	var character := _character()
	for id: StringName in [&"sword", &"force", &"fonxanforce"]:
		character.skills.set_raw_level(id, 20 if id == &"sword" else 10)
	character.skills.set_raw_level(&"fonxansword", 10)
	character.skills.map_skill(&"sword", &"fonxansword")
	character.skills.map_skill(&"force", &"fonxanforce")
	character.recovery.inner_force.maximum = 50
	character.recovery.inner_force.current = 10
	character.equipment.wield(EquippedWeaponRef.new(&"weapon:test_sword", WeaponDefinition.new(&"es2:d/snow/obj/bamboo_sword", &"sword")), false)
	return character


func _test_skill_data() -> void:
	var sword: SkillDefinition = _skill(&"fonxansword")
	var policy := sword.practice_policy() as VitalityInnerForcePracticePolicy
	_check(policy != null and [policy.required_vitality, policy.vitality_cost, policy.required_inner_force, policy.inner_force_cost] == [30, 30, 3, 3], "fonxansword.c practice_skill(): kee 30 and force 3")
	_check(sword.practice_done == "你按著所学练了一遍封山剑法。" and sword.practice_fail == "你的内力或气不够，没有办法练习封山剑法。", "fonxansword.c's practice lines")
	_check(_skill(&"fonxanforce").practice_policy() is UnpracticeablePracticePolicy, "fonxanforce.c never lets practice happen")
	_check(_skill(&"sword").practice_policy() is UnpracticeablePracticePolicy and _skill(&"sword").practice_fail.is_empty(), "a daemon without practice_skill() never progresses")
	var steps := _skill(&"chaos-steps").practice_policy() as VitalityInnerForcePracticePolicy
	_check(steps != null and steps.required_inner_force == 3 and _skill(&"chaos-steps").practice_done.is_empty(), "chaos-steps.c writes nothing on success")
	var fist := _skill(&"liuh-ken").practice_policy() as VitalityInnerForcePracticePolicy
	_check(fist != null and fist.vitality_cost == 30 and fist.inner_force_cost == 0, "liuh-ken.c spends kee only")
	_check(_skill(&"force").improved_line == "由於你的内功修炼有成，你的体质改善了。" and _skill(&"force").improved_color == ColoredLine.HIW, "force.c skill_improved() in HIW")
	var refused := SkillLearnPolicyResult.new(SkillLearnPolicyResult.Status.REJECTED, SkillLearnPolicyResult.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH)
	_check(sword.valid_learn_line(refused) == "你必须先找一把剑才能练剑法。", "a wrong weapon reads the weapon line")
	_check(_skill(&"liuh-ken").valid_learn_line(SkillLearnPolicyResult.new(SkillLearnPolicyResult.Status.REJECTED, SkillLearnPolicyResult.Reason.WEAPON_REFERENCES_NOT_EMPTY)) == "练柳家拳法必须空手。", "liuh-ken.c's empty hands line")
	_check(sword.valid_learn_line(SkillLearnPolicyResult.new(SkillLearnPolicyResult.Status.REJECTED, SkillLearnPolicyResult.Reason.GENDER_MISMATCH)).is_empty(), "a rule without an authored line leaves the command's")


func _test_enable() -> void:
	var character := _character()
	character.skills.set_raw_level(&"sword", 10)
	character.skills.set_raw_level(&"fonxansword", 5)
	character.skills.set_raw_level(&"force", 10)
	character.skills.set_raw_level(&"fonxanforce", 10)
	character.skills.set_raw_level(&"dodge", 1)
	character.recovery.inner_force.maximum = 50
	character.recovery.inner_force.current = 40
	var result := SkillEnableService.enable(character, _skill(&"fonxansword"), &"sword")
	_check(result.applied and character.skills.mapped_skill(&"sword") == &"fonxansword" and character.recovery.inner_force.current == 40, "enable sword fonxansword keeps force")
	_check(_texts(TrainingLines.enable(result, _skill(&"sword"), _skill(&"fonxansword"))) == ["Ok."], "enable.c writes Ok.")
	result = SkillEnableService.enable(character, _skill(&"fonxansword"), &"parry")
	_check(not result.applied and _texts(TrainingLines.enable(result, _skill(&"parry"), _skill(&"fonxansword"))) == ["你连「基本招架」都没学会，更别提封山剑法了。"], "parry needs its basic skill")
	character.skills.set_raw_level(&"parry", 1)
	_check(SkillEnableService.enable(character, _skill(&"fonxansword"), &"parry").applied and character.skills.mapped_skill(&"parry") == &"fonxansword", "fonxansword is enabled for parry too")
	result = SkillEnableService.enable(character, _skill(&"fonxansword"), &"dodge")
	_check(_texts(TrainingLines.enable(result, _skill(&"dodge"), _skill(&"fonxansword"))) == ["这个技能不能当成这种用途。"], "valid_enable() refuses dodge")
	result = SkillEnableService.enable(character, _skill(&"chaos-steps"), &"blade")
	_check(result.failure == SkillMappingChangeResult.Failure.SKILL_NOT_KNOWN and _texts(TrainingLines.enable(result, _skill(&"blade"), _skill(&"chaos-steps"))) == ["你不会这种技能。"], "an unknown skill is refused before its use")
	result = SkillEnableService.enable(character, _skill(&"sword"), &"sword")
	_check(_texts(TrainingLines.enable(result, _skill(&"sword"), _skill(&"sword"))) == ["「基本剑法」是所有剑法的基础，不需要 enable。"], "a basic skill is the base of its use")
	result = SkillEnableService.enable(character, _skill(&"fonxanforce"), &"force")
	_check(result.applied and character.recovery.inner_force.current == 0 and character.recovery.inner_force.maximum == 50, "enabling a force skill empties force, keeps max_force")
	_check(_texts(TrainingLines.enable(result, _skill(&"force"), _skill(&"fonxanforce"))) == ["Ok.", "你改用另一种内功，内力必须重新锻炼。"], "enable.c's force line")
	character.recovery.inner_force.current = 30
	_check(SkillEnableService.enable(character, _skill(&"fonxanforce"), &"force").applied and character.recovery.inner_force.current == 0, "enable.c resets force on every force enable, the same skill too")
	character.recovery.inner_force.current = 30
	_check(SkillEnableService.disable(character, &"force") and character.skills.mapped_skill(&"force").is_empty() and character.recovery.inner_force.current == 30, "enable force none keeps force")
	_check(SkillEnableService.disable(character, &"sword") and character.skills.raw_level(&"fonxansword") == 5 and _texts(TrainingLines.disable()) == ["Ok."], "disable keeps the skill")
	result = SkillEnableService.enable(character, _skill(&"fonxansword"), &"literate")
	_check(_texts(TrainingLines.enable(result, _skill(&"literate"), _skill(&"fonxansword"))) == ["没有这个技能种类，用 enable ? 可以查看有哪些种类。"], "literate is no use")


func _practice(character: CharacterState, use: StringName) -> Array[ColoredLine]:
	var special: SkillDefinition = _skill(character.skills.mapped_skill(use))
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var result := PracticeService.practice(
		character, use, null if special == null else special.practice_policy(),
		null if special == null else registry.policy_for(special.skill_id), false,
	)
	return TrainingLines.practice(result, special)


func _test_practice() -> void:
	var character := _student()
	var lines := _practice(character, &"sword")
	_check(_texts(lines) == ["你按著所学练了一遍封山剑法。", "你的封山剑法进步了！"] and lines[1].color == ColoredLine.HIY, "practice sword: practice_skill()'s line, then practice.c's in HIY")
	_check(character.vitality.current == 70 and character.recovery.inner_force.current == 7 and character.skills.learned_progress(&"fonxansword") == 5, "kee 30, force 3, progress sword/5+1")
	character.skills.set_learned_progress(&"fonxansword", 120)
	lines = _practice(character, &"sword")
	_check(_texts(lines) == ["你按著所学练了一遍封山剑法。", "你的「封山剑法」进步了！", "你的封山剑法进步了！"] and lines[1].color == ColoredLine.HIC and character.skills.raw_level(&"fonxansword") == 11, "a level: improve_skill()'s HIC line between")
	character.recovery.inner_force.current = 2
	_check(_texts(_practice(character, &"sword")) == ["你的内力或气不够，没有办法练习封山剑法。"] and character.vitality.current == 40, "practice_skill()'s notify_fail; nothing spent")
	character.recovery.inner_force.current = 10
	character.recovery.inner_force.maximum = 49
	_check(_texts(_practice(character, &"sword")) == ["你的内力不够，没有办法练封山剑法。"], "valid_learn(): max_force 50")
	character.recovery.inner_force.maximum = 50
	character.skills.unmap_skill(&"force")
	_check(_texts(_practice(character, &"sword")) == ["封山剑法必须配合封山派内功才能练。"], "valid_learn(): fonxanforce enabled")
	character.skills.map_skill(&"force", &"fonxanforce")
	character.equipment.unwield(&"weapon:test_sword")
	_check(_texts(_practice(character, &"sword")) == ["你必须先找一把剑才能练剑法。"], "valid_learn(): a sword in hand")
	_check(_texts(_practice(character, &"force")) == ["封山派内功只能用学的，或是从运用(exert)中增加熟练度。"], "fonxanforce cannot be practised")
	_check(_texts(_practice(character, &"parry")) == ["你只能练习用 enable 指定的特殊技能。"], "an unmapped use")
	character.vitality.current = 100
	character.skills.set_raw_level(&"dodge", 10)
	character.skills.set_raw_level(&"chaos-steps", 1)
	character.skills.map_skill(&"dodge", &"chaos-steps")
	_check(_texts(_practice(character, &"dodge")) == ["你的倒乱七星步法进步了！"] and character.recovery.inner_force.current == 7, "chaos-steps: no line of its own")
	character.skills.set_raw_level(&"unarmed", 5)
	character.skills.set_raw_level(&"liuh-ken", 5)
	character.skills.map_skill(&"unarmed", &"liuh-ken")
	character.equipment.wield(EquippedWeaponRef.new(&"weapon:test_sword", WeaponDefinition.new(&"es2:d/snow/obj/bamboo_sword", &"sword")), false)
	_check(_texts(_practice(character, &"unarmed")) == ["练柳家拳法必须空手。"], "liuh-ken.c: empty hands")
	character.skills.set_raw_level(&"liuh-ken", 0)
	_check(_texts(_practice(character, &"unarmed")) == ["你好像还没「学会」这项技能吧？最好先去请教别人。"], "the enabled skill at 0")


func _exercise(character: CharacterState, kee: int, modifier: int = 0) -> Array[String]:
	return _texts(TrainingLines.exercise(CultivationService.exercise(character, kee, false, modifier)))


func _test_exercise() -> void:
	var character := _student()
	character.skills.unmap_skill(&"force")
	_check(_exercise(character, 30) == ["你必须先用 enable 选择你要用的内功心法。"], "exercise needs an enabled force")
	character.skills.map_skill(&"force", &"fonxanforce")
	_check(_exercise(character, 9) == ["你最少要花 10 点「气」才能练功。"], "at least 10 kee")
	character.spirit.current = 69
	_check(_exercise(character, 30) == ["你现在精神状况太差了，无法凝神专一！"], "sen below 70%")
	character.spirit.current = 100
	character.recovery.inner_force.current = 10
	_check(_exercise(character, 30) == ["你坐下来运气用功，一股内息开始在体内流动。"] and character.recovery.inner_force.current == 13 and character.vitality.current == 70, "30 kee * (force 10 + con 20) / 300 = 3")
	character.recovery.inner_force.maximum = 49
	character.recovery.inner_force.current = 98
	_check(_exercise(character, 30) == ["你坐下来运气用功，一股内息开始在体内流动。", "你的内力增强了！"] and character.recovery.inner_force.maximum == 50 and character.recovery.inner_force.current == 50, "past twice max_force: max_force + 1")
	character.vitality.current = 100
	character.skills.set_raw_level(&"force", 1)
	character.skills.set_raw_level(&"fonxanforce", 1)
	character.recovery.inner_force.maximum = 10
	character.recovery.inner_force.current = 20
	_check(_exercise(character, 30)[1] == "当你的内息遍布全身经脉时却没有功力提升的迹象，似乎内力修为已经遇到了瓶颈。" and character.recovery.inner_force.maximum == 10, "cap (force 1 + query_skill(force) 1 / 5) * 10")
	character.recovery.inner_force.current = 20
	_check(_exercise(character, 30, 4)[1] == "你的内力增强了！", "apply/force raises the cap (query_skill)")
	character.attributes.constitution = 5
	character.skills.set_raw_level(&"force", 0)
	_check(_exercise(character, 30) == ["你坐下来运气用功，一股内息开始在体内流动。", "但是当你行功完毕，只觉得全身酸麻。"], "no gain")


func _test_self_learn() -> void:
	var character := _character()
	character.skills.set_raw_level(&"sword", 39)
	var random := ScriptedWorldInteractionRandomSource.new([7])
	var result := SelfLearningService.self_learn(character, &"sword", false, 0, null, random)
	_check(_texts(TrainingLines.self_learn(result, _skill(&"sword"))) == ["你得有「基本剑法」的入门知识才行。"], "selflearn needs 40")
	_check(_texts(TrainingLines.self_learn(SelfLearningService.self_learn(character, &"literate", false, 0), _skill(&"literate"))) == ["这项技能不能通过自学取得进步！"], "only selflearn.c's list")
	character.skills.set_raw_level(&"sword", 40)
	character.progression.combat_experience = 100
	result = SelfLearningService.self_learn(character, &"sword", false, 0, null, random)
	_check(_texts(TrainingLines.self_learn(result, _skill(&"sword"))) == ["你开始钻研有关「基本剑法」的问题。", "也许是缺乏实战经验，结果是一无所获。"] and character.essence.current == 85 and random.call_count() == 0, "40^3/10 exp needed; gin spent, no draw")
	character.progression.combat_experience = 6400
	result = SelfLearningService.self_learn(character, &"sword", false, 0, null, random)
	_check(_texts(TrainingLines.self_learn(result, _skill(&"sword"))) == ["你开始钻研有关「基本剑法」的问题。", "你苦思冥想，似乎有些心得。"] and random.requested_bounds() == [60] and character.skills.learned_progress(&"sword") == 7 and character.progression.potential_spent == 1, "random(int + level) once; one potential")
	character.essence.current = 15
	result = SelfLearningService.self_learn(character, &"sword", false, 0, null, random)
	_check(_texts(TrainingLines.self_learn(result, _skill(&"sword")))[1] == "你今天太累了，结果什麽也没有学到。" and character.essence.current == 0, "gin must exceed 300/int")
	character.progression.potential_spent = 100
	result = SelfLearningService.self_learn(character, &"sword", false, 0, null, random)
	_check(_texts(TrainingLines.self_learn(result, _skill(&"sword"))) == ["你的潜能已经发挥到极限了，没有办法再成长了。"], "no potential left")


func _study(character: CharacterState, material: StudyMaterial, fighting: bool = false) -> StudyResult:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	return StudyService.study(character, material, registry.policy_for(material.skill_id), fighting)


func _test_study() -> void:
	var book: StudyMaterial = GameContent.catalog().item(&"es2:obj/old_book").study
	_check(book != null and book.skill_id == &"force" and book.max_skill == 10 and book.sen_cost == 30 and book.difficulty == 20, "obj/old_book.c teaches force to 10")
	var character := _character()
	_check(_texts(TrainingLines.study(_study(character, book), _skill(&"force"))) == ["你是个文盲，先学学读书识字(literate)吧。"], "study needs literate")
	character.skills.set_raw_level(&"literate", 5)
	_check(_texts(TrainingLines.study(_study(character, book, true), _skill(&"force"))) == ["你无法在战斗中专心下来研读新知！"], "not in a fight")
	var result := _study(character, book)
	_check(_texts(TrainingLines.study(result, _skill(&"force"))) == ["你的「基本内功」进步了！", "你研读有关基本内功的技巧，似乎有点心得。"], "a first study: force 0 -> 1 (literate 5/5+1 = 2 > 1)")
	_check(result.sen_cost == 30 and character.spirit.current == 70 and character.skills.raw_level(&"force") == 1 and character.progression.potential_spent == 0, "30 sen at int 20; study spends no potential")
	character.attributes.intelligence = 10
	_check(_study(character, book).sen_cost == 45, "30 + 30 * (20 - 10) / 20")
	character.attributes.intelligence = 27
	_check(_study(character, book).sen_cost == 20, "30 + 30 * (20 - 27) / 20 truncates toward zero")
	character.attributes.intelligence = 70
	var spirit: int = character.spirit.current
	result = _study(character, book)
	_check(result.outcome == StudyResult.Outcome.LEGACY_NEGATIVE_COST and character.spirit.current == spirit, "a negative cost changes nothing")
	character.attributes.intelligence = 20
	character.spirit.current = 29
	_check(_texts(TrainingLines.study(_study(character, book), _skill(&"force"))) == ["你现在过於疲倦，无法专心下来研读新知。"], "sen below the cost")
	character.spirit.current = 100
	character.skills.set_raw_level(&"force", 10)
	_check(_study(character, book).outcome == StudyResult.Outcome.STUDIED, "max_skill 10 still reads at 10")
	character.skills.set_raw_level(&"force", 11)
	_check(_texts(TrainingLines.study(_study(character, book), _skill(&"force"))) == ["你研读了一会儿，但是发现上面所说的对你而言都太浅了，没有学到任何东西。"], "past max_skill")
	var manual := StudyMaterial.new()
	manual.skill_id = &"fonxansword"
	manual.exp_required = 100
	manual.sen_cost = 30
	manual.difficulty = 20
	manual.max_skill = 10
	_check(_texts(TrainingLines.study(_study(character, manual), _skill(&"fonxansword"))) == ["你的实战经验不足，再怎麽读也没用。"], "exp_required")
	manual.exp_required = 0
	_check(_texts(TrainingLines.study(_study(character, manual), _skill(&"fonxansword"))) == ["你的内力不够，没有办法练封山剑法。"], "valid_learn()'s line replaces study.c's")
