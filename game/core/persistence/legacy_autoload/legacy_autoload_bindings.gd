class_name LegacyAutoloadBindings
extends RefCounted

const BindingType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_binding.gd"
)

var _is_valid: bool = true
var _bindings: Dictionary[String, BindingType] = {}

var is_valid: bool:
	get: return _is_valid


func _init(p_bindings: Array[BindingType] = []) -> void:
	for binding: BindingType in p_bindings:
		if (
			binding == null
			or not binding.is_valid()
			or _bindings.has(binding.legacy_program_path)
		):
			_is_valid = false
			continue
		_bindings[binding.legacy_program_path] = binding.duplicate_snapshot()


func binding_for(legacy_program_path: String) -> BindingType:
	var binding: BindingType = _bindings.get(legacy_program_path)
	return null if binding == null else binding.duplicate_snapshot()


func legacy_program_paths() -> Array[String]:
	var result: Array[String] = []
	result.assign(_bindings.keys())
	result.sort()
	return result
