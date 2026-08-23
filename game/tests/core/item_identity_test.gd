extends RefCounted

const ItemDefinitionScript := preload("res://core/items/item_definition.gd")
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")

const SWORD_DEFINITION_ID: StringName = &"item:sword_001"
const SWORD_SOURCE_PATH: String = "reference/es2/mudlib/obj/weapon/longsword.c"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_definition_identity_and_source_metadata()
	_test_definition_logical_equality_and_isolation()
	_test_instance_identity_distinction()
	_test_instance_reference_replacement_isolation()
	_test_identity_model_has_no_deferred_fields()
	_test_equipment_id_semantic_alignment()
	_test_empty_ids_are_preserved_as_unresolved()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_definition_identity_and_source_metadata() -> void:
	var definition: ItemDefinitionScript = ItemDefinitionScript.new(
		SWORD_DEFINITION_ID,
		SWORD_SOURCE_PATH,
	)
	_assert_eq(
		definition.item_definition_id,
		SWORD_DEFINITION_ID,
		"definition preserves exact stable native ID",
	)
	_assert_eq(
		definition.legacy_source_path,
		SWORD_SOURCE_PATH,
		"definition preserves exact caller-supplied legacy source path",
	)
	_assert_true(
		str(definition.item_definition_id) != definition.legacy_source_path,
		"legacy source path is not native definition identity",
	)
	_assert_true(definition is RefCounted, "definition is pure RefCounted domain data")
	var definition_variant: Variant = definition
	_assert_false(definition_variant is Node, "definition has no Node dependency")

	var same_native_id_other_path: ItemDefinitionScript = ItemDefinitionScript.new(
		SWORD_DEFINITION_ID,
		"reference/es2/mudlib/d/custom/other_sword.c",
	)
	_assert_eq(
		same_native_id_other_path.item_definition_id,
		definition.item_definition_id,
		"different legacy paths do not alter a supplied native ID",
	)
	_assert_true(
		same_native_id_other_path.legacy_source_path != definition.legacy_source_path,
		"legacy source path remains independent traceability metadata",
	)

	var same_path_other_native_id: ItemDefinitionScript = ItemDefinitionScript.new(
		&"item:sword_002",
		SWORD_SOURCE_PATH,
	)
	_assert_true(
		same_path_other_native_id.item_definition_id != definition.item_definition_id,
		"same legacy path does not derive or force native definition identity",
	)
	var unnormalized_path: String = "/Obj/Weapon/../Sword"
	var unnormalized: ItemDefinitionScript = ItemDefinitionScript.new(
		&"Item:Mixed.Case-Sword",
		unnormalized_path,
	)
	_assert_eq(
		unnormalized.item_definition_id,
		&"Item:Mixed.Case-Sword",
		"native ID case and punctuation are preserved",
	)
	_assert_eq(
		unnormalized.legacy_source_path,
		unnormalized_path,
		"legacy path is preserved without slash, case, or segment normalization",
	)


func _test_definition_logical_equality_and_isolation() -> void:
	var first: ItemDefinitionScript = ItemDefinitionScript.new(
		SWORD_DEFINITION_ID,
		SWORD_SOURCE_PATH,
	)
	var second: ItemDefinitionScript = ItemDefinitionScript.new(
		SWORD_DEFINITION_ID,
		SWORD_SOURCE_PATH,
	)
	_assert_true(first != second, "separate definition objects need not share object identity")
	_assert_eq(
		first.item_definition_id,
		second.item_definition_id,
		"equal stable IDs represent one logical definition identity",
	)

	first = ItemDefinitionScript.new(
		&"item:replacement",
		"reference/es2/mudlib/obj/replacement.c",
	)
	_assert_eq(
		second.item_definition_id,
		SWORD_DEFINITION_ID,
		"replacing one local definition reference does not affect another",
	)
	_assert_eq(
		second.legacy_source_path,
		SWORD_SOURCE_PATH,
		"separate definitions have no shared mutable defaults",
	)


func _test_instance_identity_distinction() -> void:
	var first: ItemInstanceScript = ItemInstanceScript.new(
		&"instance:a",
		SWORD_DEFINITION_ID,
	)
	var second: ItemInstanceScript = ItemInstanceScript.new(
		&"instance:b",
		SWORD_DEFINITION_ID,
	)
	_assert_eq(first.item_instance_id, &"instance:a", "first exact runtime instance ID")
	_assert_eq(second.item_instance_id, &"instance:b", "second exact runtime instance ID")
	_assert_eq(
		first.item_definition_id,
		SWORD_DEFINITION_ID,
		"first exact definition reference",
	)
	_assert_eq(
		second.item_definition_id,
		SWORD_DEFINITION_ID,
		"second exact definition reference",
	)
	_assert_eq(
		first.item_definition_id,
		second.item_definition_id,
		"instances share logical definition identity",
	)
	_assert_true(
		first.item_instance_id != second.item_instance_id,
		"instances do not share runtime identity",
	)
	_assert_true(
		first.item_instance_id != first.item_definition_id,
		"instance identity and definition identity remain distinct fields",
	)
	_assert_true(first != second, "runtime instances are separate domain objects")
	_assert_true(first is RefCounted, "instance is pure RefCounted domain data")
	var first_variant: Variant = first
	_assert_false(first_variant is Node, "instance has no Node dependency")

	var duplicate_id: ItemInstanceScript = ItemInstanceScript.new(
		first.item_instance_id,
		&"item:different_definition",
	)
	_assert_eq(
		duplicate_id.item_instance_id,
		first.item_instance_id,
		"constructor preserves duplicate ID evidence without a global registry",
	)
	_assert_true(
		duplicate_id != first,
		"Phase 4B1 does not equate object references or detect duplicate ownership",
	)
	_assert_true(
		duplicate_id.item_definition_id != first.item_definition_id,
		"one duplicate instance ID cannot identify two definitions without conflict",
	)


func _test_instance_reference_replacement_isolation() -> void:
	var first: ItemInstanceScript = ItemInstanceScript.new(
		&"instance:replaceable",
		SWORD_DEFINITION_ID,
	)
	var second: ItemInstanceScript = ItemInstanceScript.new(
		&"instance:stable",
		SWORD_DEFINITION_ID,
	)
	first = ItemInstanceScript.new(&"instance:replacement", &"item:replacement")
	_assert_eq(
		second.item_instance_id,
		&"instance:stable",
		"replacing one local instance reference does not affect another",
	)
	_assert_eq(
		second.item_definition_id,
		SWORD_DEFINITION_ID,
		"instances have no shared mutable definition reference default",
	)
	_assert_eq(first.item_instance_id, &"instance:replacement", "replacement remains independent")


func _test_identity_model_has_no_deferred_fields() -> void:
	var definition: ItemDefinitionScript = ItemDefinitionScript.new()
	var instance: ItemInstanceScript = ItemInstanceScript.new()
	var forbidden_definition_fields: Array[StringName] = [
		&"name",
		&"short",
		&"long",
		&"aliases",
		&"unit",
		&"weight",
		&"value",
		&"components",
		&"callbacks",
	]
	for field_name: StringName in forbidden_definition_fields:
		_assert_false(
			_has_property(definition, field_name),
			"definition omits deferred/display field '%s'" % field_name,
		)

	var forbidden_instance_fields: Array[StringName] = [
		&"parent",
		&"environment",
		&"owner",
		&"inventory",
		&"quantity",
		&"equipped",
		&"durability",
		&"world_position",
		&"save_state",
		&"payload",
	]
	for field_name: StringName in forbidden_instance_fields:
		_assert_false(
			_has_property(instance, field_name),
			"instance omits deferred/runtime field '%s'" % field_name,
		)


func _test_equipment_id_semantic_alignment() -> void:
	var item_definition: ItemDefinitionScript = ItemDefinitionScript.new(
		SWORD_DEFINITION_ID,
		SWORD_SOURCE_PATH,
	)
	var weapon_definition: WeaponDefinitionScript = WeaponDefinitionScript.new(
		SWORD_DEFINITION_ID,
		&"sword",
		false,
		false,
		SWORD_SOURCE_PATH,
	)
	_assert_eq(
		weapon_definition.weapon_id,
		item_definition.item_definition_id,
		"WeaponDefinition.weapon_id aligns with ItemDefinition identity",
	)

	var item_instance: ItemInstanceScript = ItemInstanceScript.new(
		&"instance:equipment_alignment",
		SWORD_DEFINITION_ID,
	)
	var equipped_reference: EquippedWeaponRefScript = EquippedWeaponRefScript.new(
		&"instance:equipment_alignment",
		weapon_definition,
	)
	_assert_eq(
		equipped_reference.instance_id,
		item_instance.item_instance_id,
		"EquippedWeaponRef.instance_id aligns with ItemInstance identity",
	)
	_assert_eq(
		equipped_reference.weapon_id,
		item_instance.item_definition_id,
		"equipment definition snapshot aligns without object dependency",
	)


func _test_empty_ids_are_preserved_as_unresolved() -> void:
	var definition: ItemDefinitionScript = ItemDefinitionScript.new(
		&"",
		SWORD_SOURCE_PATH,
	)
	_assert_eq(
		definition.item_definition_id,
		&"",
		"definition ID is not inferred from a non-empty legacy path",
	)
	_assert_eq(
		definition.legacy_source_path,
		SWORD_SOURCE_PATH,
		"unresolved definition still preserves traceability metadata",
	)

	var instance: ItemInstanceScript = ItemInstanceScript.new(&"", &"")
	_assert_eq(instance.item_instance_id, &"", "empty instance ID is preserved unresolved")
	_assert_eq(instance.item_definition_id, &"", "empty definition reference is preserved unresolved")


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false


func _assert_true(condition: bool, label: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(label + ": expected true")


func _assert_false(condition: bool, label: String) -> void:
	_assertion_count += 1
	if condition:
		_failures.append(label + ": expected false")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
