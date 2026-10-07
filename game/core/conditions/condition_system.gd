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
const DrunkConditionEffectType := preload(
	"res://core/conditions/effects/drunk_condition_effect.gd"
)
const SlumberDrugConditionEffectType := preload(
	"res://core/conditions/effects/slumber_drug_condition_effect.gd"
)

var _effects: Dictionary[StringName, ConditionEffectType] = {}


func _init() -> void:
	register_effect(SnakePoisonConditionEffectType.new())
	register_effect(BandagedConditionEffectType.new())
	register_effect(DrunkConditionEffectType.new())
	register_effect(SlumberDrugConditionEffectType.new())


## Explicit registration replaces LPC file-path/call_other dispatch. It is also
## the narrow injection point used to prove flag aggregation in tests.
func register_effect(effect: ConditionEffectType) -> void:
	_effects[effect.condition_id()] = effect


## The HUD names of the character's shown conditions, in update order (translated).
func shown_names(character: CharacterStateType) -> Array[String]:
	var names: Array[String] = []
	for condition_id: StringName in character.conditions.sorted_condition_ids():
		var effect: ConditionEffectType = _effects.get(condition_id) as ConditionEffectType
		if effect != null and not effect.shown_name().is_empty():
			names.append(TranslationServer.translate(effect.shown_name()))
	return names


## Performs exactly one update over a stable snapshot. It does not schedule,
## wait, inspect heartbeat state, or call CharacterRecovery. `conscious` is
## living(me) for the daemons that ask it.
func update_once(character: CharacterStateType, conscious: bool = true) -> ConditionUpdateResultType:
	var result: ConditionUpdateResultType = ConditionUpdateResultType.new()
	var condition_ids: Array[StringName] = character.conditions.sorted_condition_ids()
	var living: bool = conscious
	for condition_id: StringName in condition_ids:
		var payload: ConditionPayloadType = character.conditions.get_condition(condition_id)
		if payload == null:
			continue
		var effect: ConditionEffectType = _effects.get(condition_id) as ConditionEffectType
		if effect == null:
			continue
		var report := ConditionReport.new(living)
		var flags: int = effect.tick(character, payload, report)
		living = report.conscious
		result.knocked_out = result.knocked_out or report.knocked_out
		result.updated += 1
		result.include_flags(flags)
		for line: ColoredLine in report.lines:
			result.lines.append(ColoredLine.new(TranslationServer.translate(line.text), line.color))
		result.room_lines.append_array(report.room_lines)
		if (flags & ConditionUpdateFlagsType.CONTINUE) == 0:
			character.conditions.remove_condition(condition_id)
	return result
