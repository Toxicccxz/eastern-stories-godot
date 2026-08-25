extends EquipmentState

const FailingTransitionResultType := preload(
	"res://core/equipment/equipment_transition_result.gd"
)

var _reported_instance_id: StringName


func _init(p_reported_instance_id: StringName = &"") -> void:
	_reported_instance_id = p_reported_instance_id


func has_weapon_instance(instance_id: StringName) -> bool:
	return instance_id != &"" and instance_id == _reported_instance_id


func unwield(instance_id: StringName) -> EquipmentTransitionResult:
	return FailingTransitionResultType.new(
		FailingTransitionResultType.Outcome.NOT_WIELDED,
		false,
		false,
		instance_id,
	)
