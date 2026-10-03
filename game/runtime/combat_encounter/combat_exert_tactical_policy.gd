class_name CombatExertTacticalPolicy
extends CombatTacticalActionPolicy

## exert.c in a fight: the battle panel's 运功 buttons, one policy per exert
## function. Owner decision: like Flee it waits while the player is busy, where
## ES2 refuses with exert.c's line. ExertService then runs with the encounter's
## random source; its lines go to the battle log with the execution result.
const PREFIX: String = "exert."

var _function_id: StringName
var _effects: SkillImprovementEffectRegistry
var function_id: StringName:
	get: return _function_id


func _init(p_function_id: StringName) -> void:
	super(action_id_for(p_function_id), CombatTacticalRequest.Category.INTERNAL_FORCE, CombatTacticalRequest.TargetRule.SELF)
	_function_id = p_function_id
	_effects = SkillImprovementEffectRegistry.new()
	_effects.register_legacy_defaults()


static func action_id_for(p_function_id: StringName) -> StringName:
	return StringName(PREFIX + String(p_function_id))


## The exert function an action ID names, or &"" for another action.
static func function_for(action_id: StringName) -> StringName:
	var text: String = String(action_id)
	return StringName(text.trim_prefix(PREFIX)) if text.begins_with(PREFIX) else &""


func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)


func supports_mode(mode: int) -> bool:
	return mode in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]


## Shown only when the player's enabled force reaches the function.
func offered_to(state: CharacterState) -> bool:
	return state != null and ExertService.offered(state, GameContent.catalog()).has(_function_id)


func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	var actor: CombatEncounterAuthorityBinding = context.actor
	var force_level: int = actor.state.skills.effective_level(
		ExertService.BASIC_FORCE, PlayerMartialArts.apply_of(actor.state, actor.armor, ExertService.BASIC_FORCE),
	)
	var result: ExertResult = ExertService.exert(
		actor.state, _function_id, GameContent.catalog(), force_level, true, actor.busy,
		random_source.legacy_random, _effects,
	)
	return CombatTacticalExecutionResult.new(
		CombatTacticalExecutionResult.Outcome.APPLIED if result.succeeded() else CombatTacticalExecutionResult.Outcome.FAILED,
		_function_id, result.lines,
	)


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null or context.target == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if context.target.participant_id != context.actor.participant_id or context.target.state != context.actor.state:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
