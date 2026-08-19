class_name ConditionSystem
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const ConditionEffectType := preload("res://core/conditions/condition_effect.gd")
const ConditionPayloadType := preload("res://core/conditions/condition_payload.gd")
const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const ConditionUpdateResultType := preload(
	"res://core/conditions/condition_update_result.gd"
)
const SnakePoisonConditionEffectType := preload(
	"res://core/conditions/effects/snake_poison_condition_effect.gd"
)
const BandagedConditionEffectType := preload(
	"res://core/conditions/effects/bandaged_condition_effect.gd"
)

var _effects: Dictionary[StringName, ConditionEffectType] = {}


func _init() -> void:
	register_effect(SnakePoisonConditionEffectType.new())
	register_effect(BandagedConditionEffectType.new())


## Explicit registration replaces LPC file-path/call_other dispatch. It is also
## the narrow injection point used to prove flag aggregation in tests.
func register_effect(effect: ConditionEffectType) -> void:
	_effects[effect.condition_id()] = effect


## Performs exactly one update over a stable snapshot. It does not schedule,
## wait, inspect heartbeat state, or call CharacterRecovery.
func update_once(character: CharacterStateType) -> ConditionUpdateResultType:
	var result: ConditionUpdateResultType = ConditionUpdateResultType.new()
	var condition_ids: Array[StringName] = character.conditions.sorted_condition_ids()
	for condition_id: StringName in condition_ids:
		var payload: ConditionPayloadType = character.conditions.get_condition(condition_id)
		if payload == null:
			continue
		var effect: ConditionEffectType = _effects.get(condition_id) as ConditionEffectType
		if effect == null:
			continue
		var flags: int = effect.update(character, payload)
		result.include_flags(flags)
		if (flags & ConditionUpdateFlagsType.CONTINUE) == 0:
			character.conditions.remove_condition(condition_id)
	return result
