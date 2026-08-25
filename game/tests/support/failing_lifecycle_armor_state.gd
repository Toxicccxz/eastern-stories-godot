extends ArmorState

const FailingArmorTransitionResultType := preload(
	"res://core/armor/armor_transition_result.gd"
)

var _reported_instance_id: StringName


func _init(p_reported_instance_id: StringName = &"") -> void:
	_reported_instance_id = p_reported_instance_id


func is_worn(item_instance_id: StringName) -> bool:
	return (
		item_instance_id != &""
		and item_instance_id == _reported_instance_id
	)


func remove(item_instance_id: StringName) -> ArmorTransitionResult:
	return FailingArmorTransitionResultType.new(
		FailingArmorTransitionResultType.Outcome.NOT_WORN,
		false,
		false,
		item_instance_id,
	)
