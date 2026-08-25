class_name DeathContext
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const TransferDestinationType := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const OwnerContextType := preload(
	"res://core/items/lifecycle/item_lifecycle_owner_context.gd"
)

## Already-decided death facts. This does not own CharacterState, CombatState,
## a runtime object, or physical world placement.
var _victim_character_id: StringName
var _victim_is_ghost: bool
var _victim_is_wizard: bool
var _victim_environment: TransferDestinationType
var _victim_owner: OwnerContextType
var _victim_display_name: String
var _victim_gender: StringName
var _victim_age: int
var _victim_body_own_weight: int
var _victim_maximum_encumbrance: int
var _victim_matches_sword_soul_alias: bool
var _killer_world_endpoint: ContainmentEndpointType
var _legacy_rewear_actor_gender: StringName
var _killer_was_present: bool

var victim_character_id: StringName:
	get: return _victim_character_id
var victim_is_ghost: bool:
	get: return _victim_is_ghost
var victim_is_wizard: bool:
	get: return _victim_is_wizard
var victim_environment: TransferDestinationType:
	get: return _duplicate_destination(_victim_environment)
var victim_owner: OwnerContextType:
	get: return _victim_owner
var victim_display_name: String:
	get: return _victim_display_name
var victim_gender: StringName:
	get: return _victim_gender
var victim_age: int:
	get: return _victim_age
var victim_body_own_weight: int:
	get: return _victim_body_own_weight
var victim_maximum_encumbrance: int:
	get: return _victim_maximum_encumbrance
var victim_matches_sword_soul_alias: bool:
	get: return _victim_matches_sword_soul_alias
var killer_world_endpoint: ContainmentEndpointType:
	get:
		return (
			null
			if _killer_world_endpoint == null
			else _killer_world_endpoint.duplicate_snapshot()
		)
var legacy_rewear_actor_gender: StringName:
	get: return _legacy_rewear_actor_gender
var killer_was_present: bool:
	get: return _killer_was_present


func _init(
	p_victim_character_id: StringName = &"",
	p_victim_is_ghost: bool = false,
	p_victim_is_wizard: bool = false,
	p_victim_environment: TransferDestinationType = null,
	p_victim_owner: OwnerContextType = null,
	p_victim_display_name: String = "",
	p_victim_gender: StringName = &"",
	p_victim_age: int = 0,
	p_victim_body_own_weight: int = 0,
	p_victim_maximum_encumbrance: int = 0,
	p_victim_matches_sword_soul_alias: bool = false,
	p_killer_world_endpoint: ContainmentEndpointType = null,
	p_legacy_rewear_actor_gender: StringName = &"",
	p_killer_was_present: bool = false,
) -> void:
	_victim_character_id = p_victim_character_id
	_victim_is_ghost = p_victim_is_ghost
	_victim_is_wizard = p_victim_is_wizard
	_victim_environment = _duplicate_destination(p_victim_environment)
	_victim_owner = p_victim_owner
	_victim_display_name = p_victim_display_name
	_victim_gender = p_victim_gender
	_victim_age = p_victim_age
	_victim_body_own_weight = p_victim_body_own_weight
	_victim_maximum_encumbrance = p_victim_maximum_encumbrance
	_victim_matches_sword_soul_alias = p_victim_matches_sword_soul_alias
	_killer_world_endpoint = (
		null
		if p_killer_world_endpoint == null
		else p_killer_world_endpoint.duplicate_snapshot()
	)
	_legacy_rewear_actor_gender = p_legacy_rewear_actor_gender
	_killer_was_present = p_killer_was_present or p_killer_world_endpoint != null


func is_valid() -> bool:
	if (
		_victim_character_id == &""
		or _victim_environment == null
		or _victim_environment.endpoint == null
		or not _victim_environment.endpoint.is_valid()
		or _victim_owner == null
		or not _victim_owner.is_complete()
		or _victim_owner.character_id != _victim_character_id
	):
		return false
	return true


func victim_endpoint() -> ContainmentEndpointType:
	return ContainmentEndpointType.new(
		ContainmentEndpointType.Kind.CHARACTER,
		_victim_character_id,
	)


func _duplicate_destination(
	value: TransferDestinationType,
) -> TransferDestinationType:
	if value == null:
		return null
	return TransferDestinationType.new(
		value.endpoint,
		value.is_available,
		value.is_containment_capable,
		value.maximum_contents_weight,
	)
