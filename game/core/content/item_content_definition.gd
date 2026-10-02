class_name ItemContentDefinition
extends RefCounted

## One item's authored facts, read from an `items` record in game/data/.
## Immutable after from_record(); role definitions are handed out as copies.
## Field names follow the LPC object (name/long/unit/value, weapon_prop,
## armor_prop, food_*, liquid, money base_*); see docs/migration/CONTENT_DATA_FORMAT.md.
const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_ARMOR: StringName = &"armor"
const CATEGORY_CURRENCY: StringName = &"currency"
const CATEGORY_FOOD: StringName = &"food"
const CATEGORY_LIQUID: StringName = &"liquid"
const CATEGORY_MISC: StringName = &"misc"

const WEAPON_FLAG_SECONDARY: String = "secondary"
const WEAPON_FLAG_TWO_HANDED: String = "two_handed"
const ARMOR_TYPE_CLOTH: StringName = &"cloth"
## std/armor/cloth.c setup(): cloth heavier than this gets dodge -weight/3000.
const CLOTH_DODGE_WEIGHT_STEP: int = 3000
const ARMOR_PROPERTY_KEYS: Array[String] = [
	"armor", "armor_vs_force", "attack", "defense", "dodge", "composure", "courage",
	"intelligence", "karma", "personality", "magic", "move", "spells", "unarmed",
]

var _item_definition_id: StringName
var _legacy_source_paths: Array[String] = []
var _display_name: String
var _aliases: Array[String] = []
var _description: String
var _unit: String
var _material: String
var _own_weight: int
var _value: int
var _no_get: bool
var _weapon_definition: WeaponDefinition
var _weapon_damage: int
var _armor_definition: ArmorDefinition
var _stack_definition: CombinedStackDefinition
var _currency_definition: CurrencyDefinition
var _money_id: StringName
var _base_unit: String
var _food_definition: FoodDefinition
var _liquid_definition: LiquidDefinition
var _liquid_initial_content: LiquidState.Content
var _liquid_initial_remaining: int
var _liquid_initial_name: String

var item_definition_id: StringName:
	get: return _item_definition_id
var display_name: String:
	get: return _display_name
var description: String:
	get: return _description
var unit: String:
	get: return _unit
var material: String:
	get: return _material
var own_weight: int:
	get: return _own_weight
## LPC query("value"); 0 when the object never sets it.
var value: int:
	get: return _value
## LPC set("no_get"): get.c refuses it (这个东西拿不起来。).
var no_get: bool:
	get: return _no_get
var weapon_skill_type: StringName:
	get: return &"" if _weapon_definition == null else _weapon_definition.skill_type
var weapon_damage: int:
	get: return _weapon_damage
var can_wield_secondary: bool:
	get: return _weapon_definition != null and _weapon_definition.can_wield_as_secondary
var is_two_handed: bool:
	get: return _weapon_definition != null and _weapon_definition.is_two_handed
var is_stack: bool:
	get: return _stack_definition != null
var stack_base_weight: int:
	get: return 0 if _stack_definition == null else _stack_definition.base_weight
var currency_base_value: int:
	get: return 0 if _currency_definition == null else _currency_definition.base_value
var money_id: StringName:
	get: return _money_id
var base_unit: String:
	get: return _base_unit
var liquid_initial_name: String:
	get: return _liquid_initial_name
var category: StringName:
	get:
		if _currency_definition != null:
			return CATEGORY_CURRENCY
		if _weapon_definition != null:
			return CATEGORY_WEAPON
		if _armor_definition != null:
			return CATEGORY_ARMOR
		if _food_definition != null:
			return CATEGORY_FOOD
		if _liquid_definition != null:
			return CATEGORY_LIQUID
		return CATEGORY_MISC


static func from_record(reader: ContentRecordReader) -> ItemContentDefinition:
	var definition: ItemContentDefinition = ItemContentDefinition.new()
	definition._item_definition_id = StringName(reader.required_text("id"))
	definition._legacy_source_paths = reader.text_list("legacy_sources")
	if definition._legacy_source_paths.is_empty():
		reader.fail("legacy_sources", "needs at least one LPC source path")
	definition._display_name = reader.required_text("name")
	definition._aliases = reader.text_list("aliases")
	definition._unit = reader.text("unit")
	definition._material = reader.text("material")
	definition._value = reader.integer("value")
	if definition._value < 0:
		reader.fail("value", "must not be negative")
	definition._no_get = reader.boolean("no_get", false)
	var money: ContentRecordReader = reader.child("money")
	if money != null:
		definition._read_money(money)
		if reader.has("weight"):
			reader.fail("weight", "money weight comes from money.base_weight")
	else:
		definition._own_weight = reader.required_integer("weight")
	if definition._own_weight < 0:
		reader.fail("weight", "must not be negative")
	definition._description = _long_or_default(reader, definition)
	var weapon: ContentRecordReader = reader.child("weapon")
	if weapon != null:
		definition._read_weapon(weapon)
	var armor: ContentRecordReader = reader.child("armor")
	if armor != null:
		definition._read_armor(armor)
	var food: ContentRecordReader = reader.child("food")
	if food != null:
		definition._read_food(food)
	var liquid: ContentRecordReader = reader.child("liquid")
	if liquid != null:
		definition._read_liquid(liquid)
	# The food rules (hockshop value, save validation) assume a plain item.
	if food != null and (weapon != null or armor != null or money != null):
		reader.fail("food", "food that is also a weapon, armor or money is not supported yet")
	reader.finish()
	return definition


func aliases() -> Array[String]:
	return _aliases.duplicate()


func legacy_source_paths() -> Array[String]:
	return _legacy_source_paths.duplicate()


func item_definition() -> ItemDefinition:
	return ItemDefinition.new(_item_definition_id, _primary_source())


func weapon_definition() -> WeaponDefinition:
	if _weapon_definition == null:
		return null
	return WeaponDefinition.new(
		_weapon_definition.weapon_id,
		_weapon_definition.skill_type,
		_weapon_definition.can_wield_as_secondary,
		_weapon_definition.is_two_handed,
		_weapon_definition.legacy_source_path,
	)


func armor_definition() -> ArmorDefinition:
	if _armor_definition == null:
		return null
	return ArmorDefinition.new(
		_armor_definition.item_definition_id,
		_armor_definition.armor_type,
		_armor_definition.numeric_modifiers,
	)


func stack_definition() -> CombinedStackDefinition:
	if _stack_definition == null:
		return null
	return CombinedStackDefinition.new(
		_stack_definition.item_definition_id,
		_stack_definition.stack_compatibility_id,
		_stack_definition.base_weight,
	)


func currency_definition() -> CurrencyDefinition:
	if _currency_definition == null:
		return null
	return CurrencyDefinition.new(
		_currency_definition.item_definition_id,
		_currency_definition.base_value,
	)


func food_definition() -> FoodDefinition:
	return null if _food_definition == null else _food_definition.duplicate_definition()


func liquid_definition() -> LiquidDefinition:
	return null if _liquid_definition == null else _liquid_definition.duplicate_definition()


## The state a freshly created container starts with (LPC `set("liquid", ...)`).
func fresh_liquid_state() -> LiquidState:
	if _liquid_definition == null:
		return null
	return LiquidState.new(_liquid_initial_content, _liquid_initial_remaining)


func loadout_item_definition() -> NpcLoadoutItemDefinition:
	return NpcLoadoutItemDefinition.new(
		item_definition(),
		_own_weight,
		_weapon_definition,
		_weapon_damage,
		_stack_definition,
		_currency_definition,
		_legacy_source_paths,
		_armor_definition,
	)


func is_valid() -> bool:
	return (
		not _item_definition_id.is_empty()
		and not _display_name.is_empty()
		and not _description.is_empty()
		and not _legacy_source_paths.is_empty()
		and _own_weight >= 0
	)


func _primary_source() -> String:
	return "" if _legacy_source_paths.is_empty() else _legacy_source_paths[0]


## feature/name.c long(): short() + "。\n" when no "long" is authored, where
## short() is name + "(" + capitalize(id) + ")".
static func _long_or_default(
	reader: ContentRecordReader,
	definition: ItemContentDefinition,
) -> String:
	if reader.has("long"):
		return reader.required_text("long")
	if definition._aliases.is_empty():
		reader.fail("long", "needs either long or an alias for the default description")
		return ""
	var primary_id: String = definition._aliases[0]
	return "%s(%s)。\n" % [
		definition._display_name,
		primary_id.substr(0, 1).to_upper() + primary_id.substr(1),
	]


## std/money.c: a combined item whose weight and value scale with the amount.
func _read_money(money: ContentRecordReader) -> void:
	_money_id = StringName(money.required_text("money_id"))
	_base_unit = money.required_text("base_unit")
	var base_value: int = money.required_integer("base_value")
	var base_weight: int = money.required_integer("base_weight")
	if base_value < 1:
		money.fail("base_value", "must be positive")
	if base_weight < 0:
		money.fail("base_weight", "must not be negative")
	money.finish()
	_own_weight = base_weight
	# The merge key is the LPC base_name() of the money object.
	_stack_definition = CombinedStackDefinition.new(
		_item_definition_id,
		StringName("/" + _primary_source().trim_suffix(".c")),
		base_weight,
	)
	_currency_definition = CurrencyDefinition.new(_item_definition_id, base_value)


func _read_weapon(weapon: ContentRecordReader) -> void:
	var skill: String = weapon.required_text("skill")
	_weapon_damage = weapon.required_integer("damage")
	if _weapon_damage < 0:
		weapon.fail("damage", "must not be negative")
	var secondary: bool = false
	var two_handed: bool = false
	for flag: String in weapon.text_list("flags"):
		match flag:
			WEAPON_FLAG_SECONDARY:
				secondary = true
			WEAPON_FLAG_TWO_HANDED:
				two_handed = true
			_:
				weapon.fail("flags", "unsupported weapon flag '%s'" % flag)
	weapon.finish()
	_weapon_definition = WeaponDefinition.new(
		_item_definition_id, StringName(skill), secondary, two_handed, _primary_source(),
	)


func _read_armor(armor: ContentRecordReader) -> void:
	var armor_type: StringName = StringName(armor.required_text("type"))
	var props: Dictionary[String, int] = armor.integer_map("props")
	for key: String in props:
		if not ARMOR_PROPERTY_KEYS.has(key):
			armor.fail("props." + key, "unsupported armor_prop")
	armor.finish()
	if armor_type == ARMOR_TYPE_CLOTH and _own_weight > CLOTH_DODGE_WEIGHT_STEP:
		@warning_ignore("integer_division")
		props["dodge"] = -(_own_weight / CLOTH_DODGE_WEIGHT_STEP)
	var values: Array[int] = []
	for key: String in ARMOR_PROPERTY_KEYS:
		values.append(props.get(key, 0))
	_armor_definition = ArmorDefinition.new(
		_item_definition_id,
		armor_type,
		ArmorNumericModifiers.new(
			values[0], values[1], values[2], values[3], values[4], values[5], values[6],
			values[7], values[8], values[9], values[10], values[11], values[12], values[13],
		),
	)


func _read_food(food: ContentRecordReader) -> void:
	_food_definition = FoodDefinition.new(
		_item_definition_id,
		food.required_integer("remaining"),
		food.required_integer("supply"),
		_value,
		_own_weight,
	)
	food.finish()
	if not _food_definition.is_valid():
		food.fail("", "remaining and supply must be positive")


func _read_liquid(liquid: ContentRecordReader) -> void:
	var maximum: int = liquid.required_integer("max_liquid")
	var liquid_type: String = liquid.required_text("type")
	_liquid_initial_name = liquid.required_text("name")
	_liquid_initial_remaining = liquid.required_integer("remaining")
	var drunk_apply: int = liquid.integer("drunk_apply")
	liquid.finish()
	# LiquidState only models the two contents the game can produce so far.
	match liquid_type:
		"alcohol":
			_liquid_initial_content = LiquidState.Content.RED_WINE
		"water":
			_liquid_initial_content = LiquidState.Content.CLEAR_WATER
		_:
			liquid.fail("type", "unsupported liquid type '%s'" % liquid_type)
	_liquid_definition = LiquidDefinition.new(
		_item_definition_id,
		maximum,
		LiquidDefinition.DRINK_HYDRATION,
		drunk_apply,
		_own_weight,
		_value,
	)
	if (
		not _liquid_definition.is_valid()
		or _liquid_initial_remaining < 0
		or _liquid_initial_remaining > maximum
	):
		liquid.fail("", "max_liquid must be positive and remaining within it")
