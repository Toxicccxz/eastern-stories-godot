class_name ItemApplyFunctions
extends RefCounted

## What `apply` does with a carried item: the item's own do_apply(), named in its data
## (`apply`). Each rule reads and changes the character and says whether the item is
## used up (one unit of a stack, or the whole object); the caller does the using up.
## Lines are translated, with 你 for $N (message_vision as the player sees it).
const SNAKE_DRUG: StringName = &"snake_drug"
const HURT_DRUG: StringName = &"hurt_drug"
## d/latemoon/park/npc/obj/flower.c do_eat(): `eat pistil`, not apply.
const ROSE_PISTIL: StringName = &"rose_pistil"
## d/choyin/obj/tablet.c do_eat(): `eat tablet`, not apply.
const TABLET: StringName = &"tablet"
const IDS: Array[StringName] = [SNAKE_DRUG, HURT_DRUG, ROSE_PISTIL, TABLET]


class Result:
	extends RefCounted
	## false: notify_fail(); `lines` holds its message and nothing changed.
	var accepted: bool = false
	var lines: Array[String] = []
	## The item is used up: add_amount(-1) on a stack, destruct() on anything else.
	var used_up: bool = false


static func has(apply_id: StringName) -> bool:
	return IDS.has(apply_id)


## The item's button: 吃 for what ES2 eats (flower.c, tablet.c add_action("do_eat", "eat")), else 使用.
static func verb(apply_id: StringName) -> String:
	return "吃" if apply_id in [ROSE_PISTIL, TABLET] else "使用"


static func apply(apply_id: StringName, character: CharacterState, fighting: bool) -> Result:
	match apply_id:
		SNAKE_DRUG:
			return _snake_drug(character)
		HURT_DRUG:
			return _hurt_drug(character, fighting)
		ROSE_PISTIL:
			return _rose_pistil(character)
		TABLET:
			return _tablet(character)
	var unknown := Result.new()
	return unknown


## obj/drug/snake_drug.c do_apply(): one dose lowers snake_poison by one. Its first
## message_vision has no "\n", so the second one goes on the same line.
static func _snake_drug(character: CharacterState) -> Result:
	var result := Result.new()
	var poison: int = _duration(character, ConditionIds.SNAKE_POISON)
	if poison <= 0:
		result.lines.append(TranslationServer.translate("你没有中蛇毒。"))
		return result
	character.conditions.add_or_replace_duration(ConditionIds.SNAKE_POISON, poison - 1)
	var after: String = "但是你中的蛇毒并没有完全清除。" if poison - 1 != 0 else "你终于清除了体内所有的蛇毒！"
	# TRANSLATORS: snake_drug.c: 你服下蛇药，顿时感觉好多了。 and, on the same line, whether the poison is gone ({after}).
	result.lines.append(TranslationServer.translate("你服下蛇药，顿时感觉好多了。{after}").format({"after": TranslationServer.translate(after)}))
	if poison - 1 != 0:
		# One dose lowers the poison by one against a bite's 20, so a dose seemed to do
		# nothing. Deviation (owner, modern fixes): the player reads what is left.
		# TRANSLATORS: after a dose of 蛇药: the snake poison left ({left}); a dose takes away one, and so does each bout of the poison.
		result.lines.append(TranslationServer.translate("体内的蛇毒还剩 {left} 分：每服一剂解去一分，每次毒发也会消退一分。").format({"left": poison - 1}))
	result.accepted = true
	result.used_up = true
	return result


## obj/drug/hurt_drug.c apply_medicine(): not in a fight; eff_kee + min(20, max - eff).
static func _hurt_drug(character: CharacterState, fighting: bool) -> Result:
	var result := Result.new()
	if fighting:
		result.lines.append(TranslationServer.translate("战斗中不能用药治伤!"))
		return result
	var diff: int = character.vitality.maximum - character.vitality.effective
	if diff == 0:
		result.lines.append(TranslationServer.translate("你没有受伤啊?"))
		return result
	var value: int = mini(20, diff)
	result.lines.append(TranslationServer.translate("你敷上金疮药 ."))
	character.vitality.effective += value
	result.accepted = true
	result.used_up = true
	return result


## flower.c do_eat(): sen back 50 (receive_heal) and rose_poison 10 less, or 0 below 10
## (apply_condition: a 0 still flares once, rose_poison.c). Deviation (**默认**, 晚月庄 B):
## one not poisoned stays so; ES2 gave them that 0, and its one bout (你中的火玫瑰毒发作了！,
## 20 sen of wound) came right after the cure.
static func _rose_pistil(character: CharacterState) -> Result:
	var result := Result.new()
	result.lines.append(TranslationServer.translate("你拿出一朵小花蕊，一口给吞了下去。"))
	result.lines.append(TranslationServer.translate("只见你脸上泛起一阵红晕，整个人看起来好多了!"))
	character.spirit.heal(50)
	if character.conditions.has_condition(ConditionIds.ROSE_POISON):
		var poison: int = _duration(character, ConditionIds.ROSE_POISON)
		character.conditions.add_or_replace_duration(ConditionIds.ROSE_POISON, 0 if poison < 10 else poison - 10)
	result.accepted = true
	result.used_up = true
	return result


## tablet.c do_eat(): the line, then receive_heal() of 5 gin, 30 kee and 5 sen (up to their
## eff_), and one 仙丹 of the stack is gone (add_amount(-1)).
static func _tablet(character: CharacterState) -> Result:
	var result := Result.new()
	result.lines.append(TranslationServer.translate("你拿出一粒仙丹，纳入口中. 吃的太急, 鼻涕眼泪流了满脸.."))
	character.essence.heal(5)
	character.vitality.heal(30)
	character.spirit.heal(5)
	result.accepted = true
	result.used_up = true
	return result


## query_condition() of a duration condition; 0 when absent (or not a duration).
static func _duration(character: CharacterState, condition_id: StringName) -> int:
	var payload: DurationConditionPayload = character.conditions.get_condition(condition_id) as DurationConditionPayload
	return 0 if payload == null else payload.remaining
