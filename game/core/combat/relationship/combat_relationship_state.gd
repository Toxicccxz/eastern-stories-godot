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
## damage.c receive_damage()/receive_wound(): set_temp("last_damage_from", who) on
## every blow that lands (0 damage too); nothing clears it. A temp: not saved.
var _last_damage_from_id: StringName = &""

var owner_character_id: StringName:
	get:
		return _owner_character_id

var guarding: bool:
	get:
		return _guarding

var last_opponent_id: StringName:
	get:
		return _last_opponent_id

var last_damage_from_id: StringName:
	get:
		return _last_damage_from_id


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


## kill_ob() given back after a held one (DECISIONS「了结 / 放过」): the lethal mark again,
## and the enemy unless `opponents_before` is null (it was none), each right after the last
## of those that stood before it (`lethal_before`, `opponents_before`) still there, else
## first, so select_opponent() draws as it would have.
func restore_lethal_target(character_id: StringName, lethal_before: Array[StringName], opponents_before: Variant) -> bool:
	if not _is_valid_target(character_id):
		return false
	if not _lethal_target_ids.has(character_id):
		_lethal_target_ids.insert(_after(_lethal_target_ids, lethal_before), character_id)
	if opponents_before is Array and not _opponent_ids.has(character_id):
		_opponent_ids.insert(_after(_opponent_ids, opponents_before), character_id)
	return true


static func _after(ids: Array[StringName], before: Array) -> int:
	var at: int = 0
	for index: int in ids.size():
		if before.has(ids[index]):
			at = index + 1
	return at


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


## Narrow source-equivalent remove_all_enemy() local mutation. The caller
## owns reciprocal requests; legacy killer intent, guarding, and last-opponent
## facts deliberately survive this transition.
func clear_opponents_preserving_lethal_targets() -> void:
	_opponent_ids.clear()


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


func set_last_damage_from(character_id: StringName) -> void:
	if _is_valid_target(character_id):
		_last_damage_from_id = character_id


## No one hurt the character last (a death of their own doing: rope.c's hang).
func clear_last_damage_from() -> void:
	_last_damage_from_id = &""


func clear_last_opponent() -> void:
	_last_opponent_id = &""


func _is_valid_target(character_id: StringName) -> bool:
	return is_valid() and not character_id.is_empty() and character_id != _owner_character_id
