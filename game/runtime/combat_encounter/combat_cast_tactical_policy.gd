class_name CombatCastTacticalPolicy
extends CombatTacticalActionPolicy

## cast.c in a fight: the battle panel's 施法 buttons, one policy per spell file and,
## for a file that does something else at its caster (dun.c), one more for that
## (cast <spell> on <me>). At an enemy it goes against the current target (cast
## <spell> on <target>), or with none while the player has none yet (the file's
## offensive_target()). Like exert and perform it waits while the player is busy, where
## cast.c refuses. CastService then runs with the encounter's random source; the
## file's lines go to the battle log with the execution result, the soldier it calls
## comes in on the player's side and a cast that took the player away ends the fight
## for them (DISENGAGED) with the room they went to.
const PREFIX: String = "cast."
const SELF_SUFFIX: String = ".self"

var _function_id: StringName
var _at_self: bool
## (actor_id) -> bool: the actor's room is no_magic.
var _no_magic: Callable
## (caster_id, NPC definition ID) -> character ID of the NPC that came, or "".
var _summon_for: Callable
## (character_id) -> NpcRuntimeState, null for the player.
var _npc_for: Callable
## skill_improved() effects when the context brings none (run outside the scheduler).
var _effects: SkillImprovementEffectRegistry
var function_id: StringName:
	get: return _function_id
var at_self: bool:
	get: return _at_self


func _init(
	p_function_id: StringName, p_at_self: bool = false, p_no_magic: Callable = Callable(),
	p_summon_for: Callable = Callable(), p_npc_for: Callable = Callable(),
) -> void:
	super(action_id_for(p_function_id, p_at_self), CombatTacticalRequest.Category.SPELL,
		CombatTacticalRequest.TargetRule.SELF if p_at_self else CombatTacticalRequest.TargetRule.CURRENT_HOSTILE)
	_function_id = p_function_id
	_at_self = p_at_self
	_no_magic = p_no_magic
	_summon_for = p_summon_for
	_npc_for = p_npc_for
	_effects = SkillImprovementEffectRegistry.new()
	_effects.register_legacy_defaults()


static func action_id_for(p_function_id: StringName, p_at_self: bool = false) -> StringName:
	return StringName(PREFIX + String(p_function_id) + (SELF_SUFFIX if p_at_self else ""))


## The spell file an action ID names, or &"" for another action.
static func function_for(action_id: StringName) -> StringName:
	var text: String = String(action_id)
	if not text.begins_with(PREFIX):
		return &""
	return StringName(text.trim_prefix(PREFIX).trim_suffix(SELF_SUFFIX))


## Whether the action ID names a cast at the caster.
static func is_self(action_id: StringName) -> bool:
	return String(action_id).begins_with(PREFIX) and String(action_id).ends_with(SELF_SUFFIX)


func validate_request(context: CombatTacticalContext) -> int:
	return _validate(context)


func validate_execution(context: CombatTacticalContext) -> int:
	return _validate(context)


func supports_mode(mode: int) -> bool:
	return mode in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]


func accepts_no_target() -> bool:
	return not _at_self


## Shown when the enabled spells skill reaches the file (and the file does something
## at its caster, for the cast at oneself).
func offered_to(state: CharacterState) -> bool:
	if state == null or not CastService.offered(state, GameContent.catalog()).has(_function_id):
		return false
	var function: CastFunction = SpecialFunctions.cast(_function_id)
	return function != null and (not _at_self or not function.self_label.is_empty())


func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	var bindings: Array[CombatSliceCharacterBinding] = context.bindings
	var actor: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, context.actor.participant_id)
	if actor == null:
		return CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED, _function_id)
	var special: SpecialContext = CombatSpecialAttackSource.context_for(
		actor, bindings, random_source, context.effect_registry if context.effect_registry != null else _effects,
	)
	if _at_self:
		special.target = special.me
	else:
		special.target = null if context.target == null else special.other(context.target.participant_id)
	var no_magic: bool = _no_magic.is_valid() and bool(_no_magic.call(actor.character_id))
	var cast: bool = CastService.cast(special, _function_id, no_magic)
	var allies: Array[StringName] = CombatNpcChat.bring_summons(actor.character_id, special, _summon_for, _npc_for)
	var outcome: int = CombatTacticalExecutionResult.Outcome.APPLIED if cast else CombatTacticalExecutionResult.Outcome.FAILED
	if not special.departure.is_empty():
		outcome = CombatTacticalExecutionResult.Outcome.DISENGAGED
	return CombatTacticalExecutionResult.new(outcome, _function_id, [], special.report()).with_allies(allies).with_departure(special.departure)


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if _at_self and (context.target == null or context.target.participant_id != context.actor.participant_id):
		return CombatTacticalResult.Code.TARGET_INVALID
	if not _at_self and context.target != null and context.target.participant_id == context.actor.participant_id:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
