class_name ExertService
extends RefCounted

## cmds/std/exert.c, `exert <function>` on oneself: the enabled force's own
## function file first (its exert_function_file()), else the basic force's
## (/d/force). The last notify_fail() is the line a refusal shows, so a function
## that ran and refused leaves its own. Use is practice: after the enabled force's
## function, random(120) < query_skill("force") improves that skill in weak mode (a
## player gains progress, never a level); after the basic force's, random(force * 4)
## < force improves force.
const BASIC_FORCE: StringName = &"force"
const SPECIAL_ROLL: int = 120
const BASIC_ROLL_MULTIPLIER: int = 4


## The functions `exert` reaches with the enabled force, in ExertFunctions order;
## none without one. Only the player is offered functions (NPCs exert from their chat).
## Outside a fight a function that only works in one (roar) is not offered: its file
## would refuse whatever the player had. One that works on another (lifeheal) is
## offered on the selected NPC instead (offered_at()).
static func offered(character: CharacterState, catalog: ContentCatalog, fighting: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	var mapped: StringName = character.skills.mapped_skill(BASIC_FORCE)
	if mapped.is_empty():
		return out
	for function_id: StringName in ExertFunctions.ORDER:
		if not fighting and ExertFunctions.find(function_id).fight_only:
			continue
		if ExertFunctions.find(function_id).targets_other:
			continue
		if _has(catalog.skill(mapped), function_id) or _has(catalog.skill(BASIC_FORCE), function_id):
			out.append(function_id)
	return out


## The functions the enabled force reaches that work on the one the command names
## (exert lifeheal <someone>), in ExertFunctions order: the HUD offers them on the
## selected NPC.
static func offered_at(character: CharacterState, catalog: ContentCatalog) -> Array[StringName]:
	var out: Array[StringName] = []
	var mapped: StringName = character.skills.mapped_skill(BASIC_FORCE)
	if mapped.is_empty():
		return out
	for function_id: StringName in ExertFunctions.ORDER:
		if ExertFunctions.find(function_id).targets_other and (_has(catalog.skill(mapped), function_id) or _has(catalog.skill(BASIC_FORCE), function_id)):
			out.append(function_id)
	return out


## `force_level` is query_skill("force") with apply/force; `random` is MudOS
## random(n) (n <= 0 gives 0 without a draw). `actor_id` is the character's ID and
## `room` the others in its room (roar.c), with their fights. `offensive` gives the one a
## file that aims works on (ExertContext.offensive), `name_of` names others in its lines.
## `target` is the one `exert <function> <target>` names (lifeheal.c), `target_name` its
## name as the character reads it.
static func exert(
	character: CharacterState,
	function_id: StringName,
	catalog: ContentCatalog,
	force_level: int,
	is_fighting: bool,
	busy: ActionBusyState,
	random: Callable,
	effects: SkillImprovementEffectRegistry,
	actor_id: StringName = &"",
	room: Array[SpecialSide] = [],
	offensive: Callable = Callable(),
	name_of: Callable = Callable(),
	target: SpecialSide = null,
	target_name: String = "",
) -> ExertResult:
	var result := ExertResult.new(function_id)
	if busy.is_busy():
		return _refused(result, ExertResult.Failure.BUSY, "( 你上一个动作还没有完成，不能施用内功。)")
	var mapped: StringName = character.skills.mapped_skill(BASIC_FORCE)
	if mapped.is_empty():
		return _refused(result, ExertResult.Failure.FORCE_NOT_ENABLED, "你请先用 enable 指令选择你要使用的内功。")
	var context := ExertContext.new(character, force_level, is_fighting, busy, actor_id, random, room)
	context.offensive = offensive
	context.name_of = name_of
	context.target = target
	context.target_name = target_name
	context.fail_line = _t("你所学的内功中没有这种功能。")
	var function: ExertFunction = ExertFunctions.find(function_id)
	if function != null and _has(catalog.skill(mapped), function_id) and function.exert(context):
		_took_effect(result, context)
		if random.call(SPECIAL_ROLL) < force_level:
			_improve(result, character, mapped, true, catalog, effects)
		return result
	if function != null and _has(catalog.skill(BASIC_FORCE), function_id) and function.exert(context):
		_took_effect(result, context)
		var force: int = character.skills.raw_level(BASIC_FORCE)
		if random.call(force * BASIC_ROLL_MULTIPLIER) < force:
			_improve(result, character, BASIC_FORCE, false, catalog, effects)
		return result
	result.failure = ExertResult.Failure.REFUSED
	result.lines = [ColoredLine.new(context.fail_line)]
	return result


static func _took_effect(result: ExertResult, context: ExertContext) -> void:
	result.lines = context.lines
	result.fainted = context.fainted
	result.killers = context.killers


static func _improve(
	result: ExertResult, character: CharacterState, skill_id: StringName, weak_mode: bool,
	catalog: ContentCatalog, effects: SkillImprovementEffectRegistry,
) -> void:
	result.skill_improvement = character.skills.improve_skill(skill_id, 1, character.attributes.spirituality, weak_mode)
	result.authored_effect = effects.apply(character, result.skill_improvement)
	result.lines.append_array(TrainingLines.improved(result.skill_improvement, result.authored_effect, catalog.skill(skill_id)))


static func _has(skill: SkillDefinition, function_id: StringName) -> bool:
	return skill != null and skill.exert_functions.has(function_id)


static func _refused(result: ExertResult, failure: ExertResult.Failure, line: String) -> ExertResult:
	result.failure = failure
	result.lines = [ColoredLine.new(_t(line))]
	return result


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
