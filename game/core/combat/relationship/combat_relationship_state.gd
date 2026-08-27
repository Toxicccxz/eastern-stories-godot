class_name CombatRelationshipState
extends RefCounted

## Per-character, local combat relationship facts from feature/attack.c.
## Cross-character reciprocity and legacy query("id") collision handling are
## deliberately outside this state.
var _owner_character_id: StringName
var _opponent_ids: Array[StringName] = []
var _lethal_target_ids: Array[StringName] = []
var _guarding: bool = false
var _last_opponent_id: StringName = &""

var owner_character_id: StringName:
	get:
		return _owner_character_id

var guarding: bool:
	get:
		return _guarding

var last_opponent_id: StringName:
	get:
		return _last_opponent_id


func _init(p_owner_character_id: StringName = &"") -> void:
	_owner_character_id = p_owner_character_id


func is_valid() -> bool:
	return not _owner_character_id.is_empty()


func is_fighting() -> bool:
	return not _opponent_ids.is_empty()


func has_opponent(character_id: StringName) -> bool:
	return _opponent_ids.has(character_id)


func opponent_ids() -> Array[StringName]:
	return _opponent_ids.duplicate()


func add_opponent(character_id: StringName) -> bool:
	if not _is_valid_target(character_id) or _opponent_ids.has(character_id):
		return false
	_opponent_ids.append(character_id)
	return true


func has_lethal_target(character_id: StringName) -> bool:
	return _lethal_target_ids.has(character_id)


func lethal_target_ids() -> Array[StringName]:
	return _lethal_target_ids.duplicate()


## Mirrors kill_ob's local ordering: mark lethal intent, then ensure enemy.
## IDs here are stable native CharacterIds, not legacy public query("id") values.
func mark_lethal_target(character_id: StringName) -> bool:
	if not _is_valid_target(character_id):
		return false
	var changed: bool = false
	if not _lethal_target_ids.has(character_id):
		_lethal_target_ids.append(character_id)
		changed = true
	if add_opponent(character_id):
		changed = true
	return changed


## Mirrors remove_enemy: an active local lethal marker prevents removal.
func remove_opponent(character_id: StringName) -> bool:
	if _lethal_target_ids.has(character_id) or not _opponent_ids.has(character_id):
		return false
	_opponent_ids.erase(character_id)
	return true


## Internal seam used only by source-equivalent clean_up_enemy orchestration.
## It bypasses remove_enemy() and therefore retains the separate killer marker.
## Ordinary combat transitions must use remove_opponent().
func _remove_opponent_for_cleanup(character_id: StringName) -> bool:
	if not _opponent_ids.has(character_id):
		return false
	_opponent_ids.erase(character_id)
	return true


## Mirrors remove_killer's local behavior. If no lethal marker exists, it
## still attempts ordinary opponent removal.
func remove_lethal_relation(character_id: StringName) -> bool:
	if _lethal_target_ids.has(character_id):
		_lethal_target_ids.erase(character_id)
		remove_opponent(character_id)
		return true
	return remove_opponent(character_id)


func set_guarding(value: bool) -> void:
	_guarding = value


func set_last_opponent(character_id: StringName) -> bool:
	if not _is_valid_target(character_id):
		return false
	_last_opponent_id = character_id
	return true


func clear_last_opponent() -> void:
	_last_opponent_id = &""


func _is_valid_target(character_id: StringName) -> bool:
	return is_valid() and not character_id.is_empty() and character_id != _owner_character_id
