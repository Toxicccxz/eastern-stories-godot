class_name CombatFleeTacticalPolicy
extends CombatTacticalActionPolicy

## CXR9 owner-authorized continuous-world disengage. LPC go.c randomizes an
## exit, not escape success. No exit selection, cost, RNG, or world mutation here.
const ACTION_ID: StringName = &"combat.flee"

func _init() -> void:
	super(ACTION_ID, CombatTacticalRequest.Category.FLEE, CombatTacticalRequest.TargetRule.SELF)

func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)

func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)

func supports_mode(mode: int) -> bool:
	return mode in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]

func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null or context.target == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if (context.target.participant_id != context.actor.participant_id
		or context.target.state != context.actor.state
		or context.target.busy != context.actor.busy
		or context.target.relationship != context.actor.relationship
		or context.target.armor != context.actor.armor):
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED

func execute(_context: CombatTacticalContext, _random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.DISENGAGED)
