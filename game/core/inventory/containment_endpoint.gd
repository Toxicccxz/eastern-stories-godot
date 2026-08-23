class_name ContainmentEndpoint
extends RefCounted

## Native stable identities for the three parent shapes needed by Phase 4B2.
## A legacy corpse inherits ITEM, so it is represented by Kind.ITEM rather
## than by a separate runtime-object wrapper.
enum Kind {
	INVALID,
	CHARACTER,
	ITEM,
	WORLD,
}

var _kind: int
var _endpoint_id: StringName

var kind: int:
	get:
		return _kind

var endpoint_id: StringName:
	get:
		return _endpoint_id


func _init(
	p_kind: int = Kind.INVALID,
	p_endpoint_id: StringName = &"",
) -> void:
	_kind = p_kind
	_endpoint_id = p_endpoint_id


func is_valid() -> bool:
	return (
		_kind >= Kind.CHARACTER
		and _kind <= Kind.WORLD
		and _endpoint_id != &""
	)


func same_identity(other: ContainmentEndpoint) -> bool:
	return other != null and _kind == other.kind and _endpoint_id == other.endpoint_id


func duplicate_snapshot() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(_kind, _endpoint_id)
