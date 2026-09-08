extends CombatTacticalActionPolicy

## TEST ONLY. Deliberately synthetic probe, not ES2 combat/cost/balance.
## No execution counters/character caches: exact mutation and RNG are the evidence.
var _fail_execution: bool


func _init(
	id: StringName = &"qa.probe",
	rule: int = CombatTacticalRequest.TargetRule.SINGLE_HOSTILE,
	p_category: int = CombatTacticalRequest.Category.MARTIAL_SPECIAL,
	item_busy: bool = true,
	fail_execution: bool = false,
) -> void:
	super(id, p_category, rule, item_busy)
	_fail_execution = fail_execution


func validate_request(context: CombatTacticalContext) -> int:
	return _prerequisites(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _prerequisites(context)


func _prerequisites(context: CombatTacticalContext) -> int:
	var state: CharacterState = context.actor.state
	if (
		state.recovery.inner_force.current < 1
		or state.skills.raw_level(&"qa.tactical") < 1
		or state.skills.mapped_skill(&"qa.use") != &"qa.tactical"
		or state.equipment.primary_weapon_skill_type() != &"sword"
	):
		return CombatTacticalResult.Code.PREREQUISITE_FAILED
	return CombatTacticalResult.Code.ACCEPTED


func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	if _fail_execution:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, &"qa.failed")
	var draw: int = random_source.next_below(7)
	if draw < 0 or draw >= 7:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, &"qa.bad_draw")
	context.actor.state.recovery.inner_force.current -= 1
	if context.target != null:
		context.target.state.recovery.atman.current += 1
	return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED, &"qa.applied")


static func prepare(state: CharacterState) -> void:
	## QA setup before route, never production defaults or balance edits.
	state.recovery.inner_force.current = 10
	state.skills.set_raw_level(&"qa.tactical", 1)
	state.skills.map_skill(&"qa.use", &"qa.tactical")
