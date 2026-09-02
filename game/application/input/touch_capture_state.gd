class_name TouchCaptureState
extends RefCounted

enum Owner { IGNORED, PAD, POINTER }

var pad_index: int = -1
var pointer_index: int = -1
var _contacts: Dictionary[int, Owner] = {}


func press(index: int, begins_in_pad: bool, pad_enabled: bool, pointer_enabled: bool) -> Owner:
	if index < 0 or _contacts.has(index):
		return Owner.IGNORED
	var owner: Owner = Owner.IGNORED
	if begins_in_pad:
		if pad_enabled and pad_index == -1:
			pad_index = index
			owner = Owner.PAD
	elif pointer_enabled and pointer_index == -1:
		pointer_index = index
		owner = Owner.POINTER
	_contacts[index] = owner
	return owner


func owner_of(index: int) -> Owner:
	return _contacts.get(index, Owner.IGNORED)


func release(index: int) -> Owner:
	var owner: Owner = owner_of(index)
	if index == pad_index:
		pad_index = -1
	if index == pointer_index:
		pointer_index = -1
	_contacts.erase(index)
	return owner


func quarantine_pointer() -> void:
	if pointer_index != -1:
		_contacts[pointer_index] = Owner.IGNORED
		pointer_index = -1


func cancel() -> void:
	# Keep held indices quarantined until their actual release, never promote them.
	for index: int in _contacts:
		_contacts[index] = Owner.IGNORED
	pad_index = -1
	pointer_index = -1


static func pad_direction(position: Vector2, bounds: Rect2) -> Vector2i:
	if bounds.size != Vector2(192, 192) or not bounds.has_point(position):
		return Vector2i.ZERO
	var cell: Vector2i = Vector2i((position - bounds.position) / 64.0)
	return cell - Vector2i.ONE
