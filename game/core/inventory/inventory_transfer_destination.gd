class_name InventoryTransferDestination
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)

var _endpoint: ContainmentEndpointType
var _is_available: bool
var _is_containment_capable: bool
var _maximum_contents_weight: int

var endpoint: ContainmentEndpointType:
	get:
		return null if _endpoint == null else _endpoint.duplicate_snapshot()

var is_available: bool:
	get:
		return _is_available

var is_containment_capable: bool:
	get:
		return _is_containment_capable

var maximum_contents_weight: int:
	get:
		return _maximum_contents_weight


func _init(
	p_endpoint: ContainmentEndpointType = null,
	p_is_available: bool = false,
	p_is_containment_capable: bool = false,
	p_maximum_contents_weight: int = 0,
) -> void:
	_endpoint = null if p_endpoint == null else p_endpoint.duplicate_snapshot()
	_is_available = p_is_available
	_is_containment_capable = p_is_containment_capable
	_maximum_contents_weight = p_maximum_contents_weight
