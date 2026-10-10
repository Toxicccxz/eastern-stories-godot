class_name CombatPerformTacticalPolicy
extends CombatTacticalActionPolicy

## perform.c in a fight: the battle panel's 字诀 buttons, one policy per perform
## file, against the current target (perform <action> <target>), or with none while
## the player has none yet (perform <action>: the file's offensive_target()). Owner
## decision, as for exert: it waits while the player is busy, where ES2 refuses with
## perform.c's line. PerformService then runs with the encounter's random source;
## the file's lines and attacks go to the battle log with the execution result.
const PREFIX: String = "perform."

var _function_id: StringName
## skill_improved() effects when the context brings none (run outside the scheduler).
var _effects: SkillImprovementEffectRegistry
var function_id: StringName:
	get: return _function_id


func _init(p_function_id: StringName) -> void:
	super(action_id_for(p_function_id), CombatTacticalRequest.Category.MARTIAL_SPECIAL, CombatTacticalRequest.TargetRule.CURRENT_HOSTILE)
	_function_id = p_function_id
	_effects = SkillImprovementEffectRegistry.new()
	_effects.register_legacy_defaults()


static func action_id_for(p_function_id: StringName) -> StringName:
	return StringName(PREFIX + String(p_function_id))


## The perform file an action ID names, or &"" for another action.
static func function_for(action_id: StringName) -> StringName:
	var text: String = String(action_id)
	return StringName(text.trim_prefix(PREFIX)) if text.begins_with(PREFIX) else &""


func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)


func supports_mode(mode: int) -> bool:
	return mode in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]


func accepts_no_target() -> bool:
	return true


## swordjab.c and counterattack.c only ask is_fighting(): a killer still fights its
## unconscious victim. fakefault.c refuses one itself.
func reaches_downed_target() -> bool:
	return true


## Shown only when what is in hand reaches the file (a sword with 封山剑法 enabled), or
## 行动 or 轻功 does (步玄七诀's 「玄羽乱舞」: perform move.hasten).
func offered_to(state: CharacterState) -> bool:
	return state != null and PerformService.offered(state, GameContent.catalog()).has(_function_id)


func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	var bindings: Array[CombatSliceCharacterBinding] = context.bindings
	var actor: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, context.actor.participant_id)
	if actor == null:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, _function_id)
	var special: SpecialContext = CombatSpecialAttackSource.context_for(
		actor, bindings, random_source, context.effect_registry if context.effect_registry != null else _effects,
	)
	special.target = null if context.target == null else special.other(context.target.participant_id)
	var performed: bool = PerformService.perform(special, _function_id)
	return CombatTacticalExecutionResult.new(
		CombatTacticalExecutionResult.Outcome.APPLIED if performed else CombatTacticalExecutionResult.Outcome.FAILED,
		_function_id, [], special.report(),
	)


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if context.target != null and context.target.participant_id == context.actor.participant_id:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
