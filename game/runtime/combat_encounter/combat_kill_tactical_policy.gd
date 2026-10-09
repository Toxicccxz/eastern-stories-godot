class_name CombatKillTacticalPolicy
extends CombatTacticalActionPolicy

## cmds/std/kill.c from the battle panel, for a player who stands in a fight fighting
## nobody (beside the NPC they raised, which a 僵尸追魂符 sent after someone): the first
## one of the other side still standing whom the player's side fights (`victim`). kill.c's
## room check (这里不准战斗。), its words, me->kill_ob(obj) and the NPC's obj->kill_ob(me):
## the two fight to the death, and the one fought now has two enemies (attack.c
## select_opponent()). It waits while the player is busy, as 投降 does.
const ACTION_ID: StringName = &"combat.kill"

## () -> StringName: whom kill.c would name now, or "" (the battle panel offers nothing).
var _victim: Callable
## () -> String: kill.c's refusal in the player's room (这里不准战斗。), or "".
var _refusal: Callable
## (character_id) -> String: kill.c's words to that one, in the shown language.
var _words_to: Callable
## (character_id) -> String: kill_ob()'s warning from that one.
var _warning_of: Callable


func _init(p_victim: Callable = Callable(), p_refusal: Callable = Callable(), p_words_to: Callable = Callable(), p_warning_of: Callable = Callable()) -> void:
	super(ACTION_ID, CombatTacticalRequest.Category.TACTICAL_DEFENSE, CombatTacticalRequest.TargetRule.SELF)
	_victim = p_victim
	_refusal = p_refusal
	_words_to = p_words_to
	_warning_of = p_warning_of


func supports_mode(mode: int) -> bool:
	return mode == CombatEncounterMode.Value.LETHAL


func offered_to(_state: CharacterState) -> bool:
	return _victim.is_valid() and not StringName(_victim.call()).is_empty()


func unavailable_reason(_state: CharacterState) -> String:
	return "" if not _refusal.is_valid() else String(_refusal.call())


func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)


func execute(context: CombatTacticalContext, _random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	var refusal: String = unavailable_reason(null)
	if not refusal.is_empty():
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, ACTION_ID, [ColoredLine.new(refusal)])
	var victim_id: StringName = _victim.call()
	var actor: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(context.bindings, context.actor.participant_id)
	var target: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(context.bindings, victim_id)
	if actor == null or target == null:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, ACTION_ID)
	if CombatSliceOpportunityExecutor.initiate_lethal_combat(actor, target).outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, ACTION_ID)
	var lines: Array[ColoredLine] = [ColoredLine.new(_words_to.call(victim_id))]
	# feature/attack.c kill_ob() tells its victim: 看起来X想杀死你！
	lines.append(ColoredLine.new(_warning_of.call(victim_id), ColoredLine.HIR))
	var killers: Array[StringName] = [victim_id]
	return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED, ACTION_ID, lines, null, killers)


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null or context.target == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if context.target.participant_id != context.actor.participant_id or context.target.state != context.actor.state:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode) or not offered_to(null):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
