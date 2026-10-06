class_name ItemApplyFunctions
extends RefCounted

## What `apply` does with a carried item: the item's own do_apply(), named in its data
## (`apply`). Each rule reads and changes the character and says whether the item is
## used up (one unit of a stack, or the whole object); the caller does the using up.
## Lines are translated, with 你 for $N (message_vision as the player sees it).
const SNAKE_DRUG: StringName = &"snake_drug"
const HURT_DRUG: StringName = &"hurt_drug"
const IDS: Array[StringName] = [SNAKE_DRUG, HURT_DRUG]


class Result:
	extends RefCounted
	## false: notify_fail(); `lines` holds its message and nothing changed.
	var accepted: bool = false
	var lines: Array[String] = []
	## The item is used up: add_amount(-1) on a stack, destruct() on anything else.
	var used_up: bool = false


static func has(apply_id: StringName) -> bool:
	return IDS.has(apply_id)


static func apply(apply_id: StringName, character: CharacterState, fighting: bool) -> Result:
	match apply_id:
		SNAKE_DRUG:
			return _snake_drug(character)
		HURT_DRUG:
			return _hurt_drug(character, fighting)
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
		# TRANSLATORS: after a dose of 蛇药: the snake poison left ({left}); each dose takes away one.
		result.lines.append(TranslationServer.translate("体内的蛇毒还剩 {left} 分，每服一剂解去一分。").format({"left": poison - 1}))
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


## query_condition() of a duration condition; 0 when absent (or not a duration).
static func _duration(character: CharacterState, condition_id: StringName) -> int:
	var payload: DurationConditionPayload = character.conditions.get_condition(condition_id) as DurationConditionPayload
	return 0 if payload == null else payload.remaining
