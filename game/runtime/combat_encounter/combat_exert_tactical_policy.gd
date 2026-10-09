class_name CombatExertTacticalPolicy
extends CombatTacticalActionPolicy

## exert.c in a fight: the battle panel's 运功 buttons, one policy per exert
## function. Owner decision: like Flee it waits while the player is busy, where
## ES2 refuses with exert.c's line. ExertService then runs with the encounter's
## random source; its lines go to the battle log with the execution result. A function
## that aims (chillgaze.c) works on the current target, as `exert chillgaze <target>`,
## or with none on the file's offensive_target(me), as perform does (DECISIONS 晚月庄 D).
const PREFIX: String = "exert."

var _function_id: StringName
## skill_improved() effects when the context brings none (run outside the scheduler).
var _effects: SkillImprovementEffectRegistry
## (actor_id, bindings) -> Array[SpecialSide]: the others in the actor's room, the
## fight's and bystanders' (roar.c); none gives the fight's others only.
var _room: Callable
## (character_id) -> String: kill_ob()'s warning from that character.
var _warning_of: Callable
## (character_id) -> String: that character's name as the player reads it.
var _name_of: Callable
var _aims: bool = false
var function_id: StringName:
	get: return _function_id


func _init(p_function_id: StringName, p_room: Callable = Callable(), p_warning_of: Callable = Callable(), p_name_of: Callable = Callable()) -> void:
	var function: ExertFunction = ExertFunctions.find(p_function_id)
	var aims: bool = function != null and function.aims
	super(action_id_for(p_function_id), CombatTacticalRequest.Category.INTERNAL_FORCE,
		CombatTacticalRequest.TargetRule.CURRENT_HOSTILE if aims else CombatTacticalRequest.TargetRule.SELF)
	_function_id = p_function_id
	_aims = aims
	_room = p_room
	_warning_of = p_warning_of
	_name_of = p_name_of
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


## A file that aims runs with no current target too (its offensive_target()).
func accepts_no_target() -> bool:
	return _aims


## chillgaze.c asks only is_fighting(): a killer still stares at its unconscious victim
## (offensive_target() keeps it among the enemies), as the 字诀 do.
func reaches_downed_target() -> bool:
	return _aims


## Shown only when the player's enabled force reaches the function.
func offered_to(state: CharacterState) -> bool:
	return state != null and ExertService.offered(state, GameContent.catalog(), true).has(_function_id)


## heal.c refuses in every fight: shown greyed with its line, not hidden, never failing.
func unavailable_reason(_state: CharacterState) -> String:
	var function: ExertFunction = ExertFunctions.find(_function_id)
	return "" if function == null or function.fight_refusal.is_empty() else TranslationServer.translate(function.fight_refusal)


func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
	var actor: CombatEncounterAuthorityBinding = context.actor
	var force_level: int = actor.state.skills.effective_level(
		ExertService.BASIC_FORCE, PlayerMartialArts.apply_of(actor.state, actor.armor, ExertService.BASIC_FORCE),
	)
	var offensive: Callable = Callable()
	# Held for the call: a Callable does not keep its object alive.
	var special: SpecialContext = null
	if _aims:
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(context.bindings, actor.participant_id)
		if binding != null:
			special = CombatSpecialAttackSource.context_for(binding, context.bindings, random_source, _effects)
			special.target = null if context.target == null else special.other(context.target.participant_id)
			offensive = special.target_or_offensive
	var result: ExertResult = ExertService.exert(
		actor.state, _function_id, GameContent.catalog(), force_level, true, actor.busy,
		random_source.legacy_random, context.effect_registry if context.effect_registry != null else _effects,
		actor.participant_id, _room_of(actor.participant_id, context.bindings), offensive, _name_of,
	)
	var lines: Array[ColoredLine] = result.lines
	# feature/attack.c kill_ob() tells its victim: 看起来X想杀死你！
	for killer_id: StringName in result.killers:
		if _warning_of.is_valid():
			lines.append(ColoredLine.new(_warning_of.call(killer_id), ColoredLine.HIR))
	return CombatTacticalExecutionResult.new(
		CombatTacticalExecutionResult.Outcome.APPLIED if result.succeeded() else CombatTacticalExecutionResult.Outcome.FAILED,
		_function_id, lines, null, result.killers,
	)


func _room_of(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> Array[SpecialSide]:
	var room: Array[SpecialSide] = []
	if _room.is_valid():
		room.assign(_room.call(actor_id, bindings))
		return room
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.character_id != actor_id:
			room.append(CombatNpcChat.side_of(binding, null))
	return room


func _validate(context: CombatTacticalContext) -> int:
	if context == null or context.actor == null:
		return CombatTacticalResult.Code.TARGET_INVALID
	if _aims:
		if context.target != null and context.target.participant_id == context.actor.participant_id:
			return CombatTacticalResult.Code.TARGET_INVALID
	elif context.target == null or context.target.participant_id != context.actor.participant_id or context.target.state != context.actor.state:
		return CombatTacticalResult.Code.TARGET_INVALID
	if not supports_mode(context.mode):
		return CombatTacticalResult.Code.POLICY_UNSUPPORTED
	return CombatTacticalResult.Code.ACCEPTED
