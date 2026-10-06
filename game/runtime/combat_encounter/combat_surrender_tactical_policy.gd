class_name CombatSurrenderTacticalPolicy
extends CombatTacticalActionPolicy

## cmds/std/surrender.c for the player: the battle panel's 投降 (SurrenderCommand).
## A last opponent (before the first blow, any opponent) that stands and is killing
## the player refuses (求饶 line, the fight goes on); otherwise every enemy not
## killing the player stops fighting, the player stops fighting them all and loses
## 50 score (to 0). Owner decision, as for
## exert and perform: it waits while the player is busy (surrender.c has no busy
## check). In a fight to the death whose enemies are all down and nobody fights any
## more, the player has disengaged: the fight ends as Flee ends it (ES2 would go on
## when a killer came to; the port's fight cannot wait for that).
const ACTION_ID: StringName = &"combat.surrender"

## () -> the player's age, for rankd.c query_rude() in the refusal.
var _player_age: Callable


func _init(p_player_age: Callable = Callable()) -> void:
	super(ACTION_ID, CombatTacticalRequest.Category.TACTICAL_DEFENSE, CombatTacticalRequest.TargetRule.SELF)
	_player_age = p_player_age


func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)


func supports_mode(mode: int) -> bool:
	return mode in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]


func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	var bindings: Array[CombatSliceCharacterBinding] = context.bindings
	var actor: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, context.actor.participant_id)
	if actor == null:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, ACTION_ID)
	var special: SpecialContext = CombatSpecialAttackSource.context_for(actor, bindings, random_source, null)
	if actor.is_user and _player_age.is_valid():
		special.me.age = _player_age.call()
	var accepted: bool = SurrenderCommand.run(special) and not actor.relationship.is_fighting()
	if accepted and context.mode == CombatEncounterMode.Value.LETHAL and not _anyone_fighting(bindings):
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.DISENGAGED, ACTION_ID, [], special.report())
	return CombatTacticalExecutionResult.new(
		CombatTacticalExecutionResult.Outcome.APPLIED if accepted else CombatTacticalExecutionResult.Outcome.FAILED,
		ACTION_ID, [], special.report(),
	)


## Someone standing who still fights someone (a killer lying unconscious keeps its
## enemies but strikes nobody).
static func _anyone_fighting(bindings: Array[CombatSliceCharacterBinding]) -> bool:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.exists_in_encounter and binding.life_status == CombatSliceLifeStatus.Value.ACTIVE and binding.relationship.is_fighting():
			return true
	return false


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null or context.target == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if context.target.participant_id != context.actor.participant_id or context.target.state != context.actor.state:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
