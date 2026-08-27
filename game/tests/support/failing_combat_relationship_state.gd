extends CombatRelationshipState

var fail_remove_id: StringName = &""


func _init(p_owner_character_id: StringName = &"") -> void:
	super(p_owner_character_id)


func remove_opponent(character_id: StringName) -> bool:
	if character_id == fail_remove_id:
		return false
	return super(character_id)
