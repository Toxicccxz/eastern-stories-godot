class_name CombatSettleTacticalPolicy
extends CombatTacticalActionPolicy

## d/village/npc/meloner.c do_return() in the fight (NpcSettle, WorldMapDebts): the battle
## panel's 还瓜钱 while the NPC of `definition_id` who caught the player fights them. One
## action per NPC definition that has a settle (its label is the NPC's own). Paid, its say,
## and it walks out of the fight home (move(): the LPC never stopped the fight, it left the
## room); short of money, buy.c's line and the fight goes on. It waits while the player is
## busy, as every command does (ES2's busy check).
const PREFIX: String = "combat.settle."

var _definition_id: StringName
## (NPC definition ID) -> whether one of them who caught the player fights them now.
var _offered: Callable
## (NPC definition ID) -> {"settled": bool, "lines": Array[String], "npc": character ID, "home": zone ID}.
var _settle: Callable


func _init(p_definition_id: StringName = &"", p_offered: Callable = Callable(), p_settle: Callable = Callable()) -> void:
	super(StringName(PREFIX + String(p_definition_id)), CombatTacticalRequest.Category.TACTICAL_DEFENSE, CombatTacticalRequest.TargetRule.SELF)
	_definition_id = p_definition_id
	_offered = p_offered
	_settle = p_settle


## The NPC definition a settle action is for ("" for any other action).
static func definition_for(action_id: StringName) -> StringName:
	var text: String = String(action_id)
	return StringName(text.trim_prefix(PREFIX)) if text.begins_with(PREFIX) else &""


func supports_mode(mode: int) -> bool:
	return mode == CombatEncounterMode.Value.LETHAL


func offered_to(_state: CharacterState) -> bool:
	return _offered.is_valid() and bool(_offered.call(_definition_id))


func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)


func execute(context: CombatTacticalContext, _random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	if _validate(context) != CombatTacticalResult.Code.ACCEPTED or not _settle.is_valid():
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, action_id)
	var done: Dictionary = _settle.call(_definition_id)
	var lines: Array[ColoredLine] = []
	for text: String in done.get("lines", []):
		lines.append(ColoredLine.new(text))
	if not bool(done.get("settled", false)):
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, action_id, lines)
	return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED, action_id, lines).with_walk_out(done["npc"], done["home"])


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null or context.target == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if context.target.participant_id != context.actor.participant_id or context.target.state != context.actor.state:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode) or not offered_to(context.actor.state):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
