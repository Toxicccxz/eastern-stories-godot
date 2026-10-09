class_name ItemContentDefinition
extends RefCounted

## One item's authored facts, read from an `items` record in game/data/.
## Immutable after from_record(); role definitions are handed out as copies.
## Field names follow the LPC object (name/long/unit/value, weapon_prop,
## armor_prop, food_*, liquid, money base_*, combined base_*); see
## docs/migration/CONTENT_DATA_FORMAT.md.
const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_ARMOR: StringName = &"armor"
const CATEGORY_CURRENCY: StringName = &"currency"
const CATEGORY_FOOD: StringName = &"food"
const CATEGORY_LIQUID: StringName = &"liquid"
const CATEGORY_MISC: StringName = &"misc"

const WEAPON_FLAG_SECONDARY: String = "secondary"
const WEAPON_FLAG_TWO_HANDED: String = "two_handed"
## `weight_dodge`: the setup() the item's create() runs, which costs a heavy one dodge
## (set("..._prop/dodge", - weight() / 3000)). std/equip.c (every std/weapon/<kind>.c but
## throwing.c, and an armor that inherits EQUIP): from 3000 weight, unless the item sets a
## dodge of its own.
const WEIGHT_DODGE_EQUIP: String = "equip"
## std/armor/<type>.c: above 3000 weight, over the armor's own dodge (it tests
## armor_apply/dodge, which nothing sets).
const WEIGHT_DODGE_ARMOR: String = "armor"
const WEIGHT_PER_DODGE: int = 3000
# TRANSLATORS: an item with no description of its own: its name and its ES2 id, e.g. 草鞋(Sandals)。
const DEFAULT_LONG: String = "{name}({id})。\n"
const ARMOR_PROPERTY_KEYS: Array[String] = [
	"armor", "armor_vs_force", "attack", "defense", "dodge", "composure", "courage",
	"intelligence", "karma", "personality", "magic", "move", "spells", "unarmed",
]
## The weapon_prop keys the mudlib sets besides damage (equip.c adds them to apply/*).
const WEAPON_APPLY_KEYS: Array[String] = [
	"attack", "defense", "dodge", "courage", "intelligence", "karma", "personality", "spells", "spirituality",
]

var _item_definition_id: StringName
var _legacy_source_paths: Array[String] = []
var _display_name: String
var _aliases: Array[String] = []
var _description: String
## No authored long: the description is feature/name.c's default.
var _default_long: bool = false
var _unit: String
var _material: String
var _own_weight: int
var _value: int
var _no_get: bool
var _female_only: bool
var _no_drop: bool
var _no_drop_line: String
var _wear_refusal: String = ""
var _max_encumbrance: int
var _weapon_definition: WeaponDefinition
var _weapon_damage: int
var _weapon_rigidity: int
var _weapon_apply: Dictionary[StringName, int] = {}
var _armor_definition: ArmorDefinition
var _stack_definition: CombinedStackDefinition
var _currency_definition: CurrencyDefinition
var _money_id: StringName
var _base_unit: String
var _food_definition: FoodDefinition
## feature/food.c finish_eat() returning 1: what the food becomes once eaten up (the
## bones of u/cloud's meats), as a record read with the food; empty for most foods.
var _leaves: Dictionary = {}
var _liquid_definition: LiquidDefinition
var _liquid_initial_content: LiquidState.Content
var _liquid_initial_remaining: int
var _liquid_initial_name: String
var _study: StudyMaterial
var _play: StringName = &""
var _hang: bool = false
var _default_amount: int = 1
var _apply: StringName = &""
var _dissolves: bool = false
var _pour: PourDefinition
var _unique: bool = false
## A weapon weapond.c bash_weapon() broke: the original's name (shown as 断掉的<name>).
var _broken_from_name: String = ""
## cmds/std/scribe.c draws 符 on it: the 桃符纸 (owner, DECISIONS 茅山 A: only on it).
var _scribe: bool = false
## A 僵尸追魂符 drawn on it (necromancy/haunt.c scribe()): the NPC definition whose name
## is written on it and that name; empty for anything else.
var _haunts: StringName = &""
var _haunts_name: String = ""

var item_definition_id: StringName:
	get: return _item_definition_id
var display_name: String:
	get:
		if not _haunts.is_empty():
			# TRANSLATORS: haunt.c scribe(): a 桃符纸 with 僵尸追魂符 drawn on it and someone's name ({name}) written on it.
			return TranslationServer.translate("僵尸追魂符（{name}）").format({"name": TranslationServer.translate(_haunts_name)})
		if _broken_from_name.is_empty():
			return _display_name
		# TRANSLATORS: weapond.c bash_weapon(): a weapon broken in two, set("name", "断掉的" + name).
		return TranslationServer.translate("断掉的{weapon}").format({"weapon": TranslationServer.translate(_broken_from_name)})
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
## LPC set("female_only"): wear.c lets only a 女性 character wear it; also an item whose
## own wear() refuses anyone else (d/latemoon/obj/skirt.c).
var female_only: bool:
	get: return _female_only
## That wear()'s own notify_fail() ("" for wear.c's 这是女人的衣衫，……羞也不羞？).
var wear_refusal: String:
	get: return _wear_refusal
## LPC set("no_drop"): drop.c, give.c and put.c refuse it.
var no_drop: bool:
	get: return _no_drop
## drop.c's refusal when no_drop is a string ("" for 这样东西不能随意丢弃。).
var no_drop_line: String:
	get: return _no_drop_line
## LPC set("rigidity"): weapond.c bash_weapon() adds it to the weapon's side; 0 unset.
var weapon_rigidity: int:
	get: return _weapon_rigidity
## feature/move.c set_max_encumbrance(): a container holds this much (put in,
## get from); 0 for anything that is not a container.
var max_encumbrance: int:
	get: return _max_encumbrance
var weapon_skill_type: StringName:
	get: return &"" if _weapon_definition == null else _weapon_definition.skill_type
var weapon_damage: int:
	get: return _weapon_damage
## equip.c wield(): the weapon_prop values other than damage the wielder gains as
## apply/<key> (thin_sword.c's courage -4).
var weapon_apply: Dictionary[StringName, int]:
	get: return _weapon_apply.duplicate()
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
## set("skill", ...): what study.c teaches from the item; null for most items.
var study: StudyMaterial:
	get: return _study
## An item one can play or blow (bamboo_pipe.c do_play()): what its room hears
## (`pipe` for environment()->pipe_notify()); empty for most items.
var play: StringName:
	get: return _play
## rope.c add_action("hang_self", "hang"): one can hang oneself with it.
var hang: bool:
	get: return _hang
## cmds/std/scribe.c: 符 can be drawn on it (the 桃符纸).
var scribe: bool:
	get: return _scribe
## The NPC definition whose name a 僵尸追魂符 carries (haunt.c), or empty.
var haunts: StringName:
	get: return _haunts
## combined.c: the amount create() gives a new one (set_amount); 1 for anything else.
var default_amount: int:
	get: return _default_amount
## What `apply` does with the item (ItemApplyFunctions: snake_drug.c, hurt_drug.c);
## empty for most items.
var apply: StringName:
	get: return _apply
## obj/dust.c: the item dissolves a corpse (do_dissolve).
var dissolves: bool:
	get: return _dissolves
## A powder one can pour into a drink (std/medicine/powder.c, poison_dust.c do_pour());
## null for most items.
var pour: PourDefinition:
	get: return _pour
## F_UNIQUE: only one of it may exist in the world (violate_unique()).
var unique: bool:
	get: return _unique
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
	definition._female_only = reader.boolean("female_only", false)
	definition._wear_refusal = reader.text("wear_refusal")
	if not definition._wear_refusal.is_empty() and not definition._female_only:
		reader.fail("wear_refusal", "only a female_only item refuses with its own line")
	if reader.has("no_drop"):
		definition._no_drop = true
		if reader.is_text("no_drop"):
			definition._no_drop_line = reader.required_text("no_drop")
		elif not reader.boolean("no_drop", false):
			reader.fail("no_drop", "true or drop.c's line")
	definition._play = StringName(reader.text("play"))
	definition._hang = reader.boolean("hang", false)
	definition._apply = StringName(reader.text("apply"))
	if not definition._apply.is_empty() and not ItemApplyFunctions.has(definition._apply):
		reader.fail("apply", "unknown apply '%s'" % definition._apply)
	definition._dissolves = reader.boolean("dissolve", false)
	definition._scribe = reader.boolean("scribe", false)
	definition._unique = reader.boolean("unique", false)
	var pour: ContentRecordReader = reader.child("pour")
	if pour != null:
		definition._pour = PourDefinition.from_record(pour)
		if not ConditionIds.ALL.has(definition._pour.condition):
			reader.fail("pour", "unknown condition '%s'" % definition._pour.condition)
	definition._max_encumbrance = reader.integer("max_encumbrance")
	if definition._max_encumbrance < 0:
		reader.fail("max_encumbrance", "must not be negative")
	var money: ContentRecordReader = reader.child("money")
	var combined: ContentRecordReader = reader.child("combined")
	if money != null:
		definition._read_money(money)
		if reader.has("weight"):
			reader.fail("weight", "money weight comes from money.base_weight")
		if combined != null:
			reader.fail("combined", "money is already combined")
	elif combined != null:
		definition._read_combined(combined)
		if reader.has("weight"):
			reader.fail("weight", "a combined item's weight comes from combined.base_weight")
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
	var study: ContentRecordReader = reader.child("study")
	if study != null:
		definition._study = StudyMaterial.from_record(study)
	# The food rules (hockshop value, save validation) assume a plain item.
	if food != null and (weapon != null or armor != null or money != null or combined != null):
		reader.fail("food", "food that is also a weapon, armor or money is not supported yet")
	reader.finish()
	return definition


## The ID the catalog gives what a food leaves once eaten (LEFTOVER_SUFFIX after its own).
const LEFTOVER_SUFFIX: String = "#eaten"


## The ID of what this food leaves once eaten up, or empty when it leaves nothing.
func leftover_id() -> StringName:
	return &"" if _leaves.is_empty() else StringName(String(_item_definition_id) + LEFTOVER_SUFFIX)


## finish_eat(): set_name(<bone>, ({ <ids> })), set_weight(), set("long"); food.c set
## value 0 on the first bite. What is left is no food: a plain thing (a dog takes a bone).
## Owner (polish, A11): its aliases add "bone" to finish_eat()'s "rib" (dog.c asks for
## id("bone")), and it counts in 根, where ES2 kept the meat's 斤.
static func leftover(source: ItemContentDefinition) -> ItemContentDefinition:
	var left := ItemContentDefinition.new()
	left._item_definition_id = source.leftover_id()
	left._legacy_source_paths = source._legacy_source_paths.duplicate()
	left._display_name = source._leaves["name"]
	left._aliases.assign(source._leaves["aliases"])
	left._description = source._leaves["long"]
	left._unit = source._unit if String(source._leaves["unit"]).is_empty() else source._leaves["unit"]
	left._material = source._material
	left._own_weight = source._leaves["weight"]
	left._value = 0
	return left


## The ID the catalog gives a weapon's broken form (BROKEN_SUFFIX after the weapon's).
const BROKEN_SUFFIX: String = "#broken"


## weapond.c bash_weapon() breaking a weapon in two: set("name", "断掉的" + name),
## value / 10, set("weapon_prop", 0) (no longer wieldable); the rest stays as it was.
static func broken_weapon(source: ItemContentDefinition) -> ItemContentDefinition:
	var broken := ItemContentDefinition.new()
	broken._item_definition_id = StringName(String(source._item_definition_id) + BROKEN_SUFFIX)
	broken._legacy_source_paths = source._legacy_source_paths.duplicate()
	broken._display_name = source._display_name
	broken._broken_from_name = source._display_name
	broken._aliases = source._aliases.duplicate()
	broken._description = source._description
	broken._default_long = source._default_long
	broken._unit = source._unit
	broken._material = source._material
	broken._own_weight = source._own_weight
	@warning_ignore("integer_division")
	broken._value = source._value / 10
	# A broken stack (飞刀) stays one, of broken ones: it no longer joins whole ones.
	if source._stack_definition != null:
		broken._base_unit = source._base_unit
		broken._default_amount = source._default_amount
		broken._stack_definition = CombinedStackDefinition.new(
			broken._item_definition_id,
			StringName(String(source._stack_definition.stack_compatibility_id) + BROKEN_SUFFIX),
			source._stack_definition.base_weight,
		)
	return broken


## The ID the catalog gives a 僵尸追魂符 drawn on a paper (HAUNT_SUFFIX and the NPC's ID
## after the paper's).
const HAUNT_SUFFIX: String = "#haunt="


## necromancy/haunt.c scribe() on a 桃符纸 for `npc`: set_name("僵尸追魂符", ({ "sheet" })),
## the paper's long, unit and weight unchanged. The written name is part of what it is:
## sheets for one name stack together, for another they do not.
static func haunting_sheet(paper: ItemContentDefinition, npc: NpcDefinition) -> ItemContentDefinition:
	var sheet := ItemContentDefinition.new()
	sheet._item_definition_id = haunting_sheet_id(paper._item_definition_id, npc.definition_id)
	sheet._legacy_source_paths = paper._legacy_source_paths.duplicate()
	sheet._display_name = paper._display_name
	sheet._haunts = npc.definition_id
	sheet._haunts_name = npc.display_name
	sheet._aliases.assign(["sheet"])
	sheet._description = paper._description
	sheet._default_long = paper._default_long
	sheet._unit = paper._unit
	sheet._material = paper._material
	sheet._own_weight = paper._own_weight
	sheet._value = paper._value
	if paper._stack_definition != null:
		sheet._base_unit = paper._base_unit
		sheet._default_amount = 1
		sheet._stack_definition = CombinedStackDefinition.new(
			sheet._item_definition_id,
			StringName(String(paper._stack_definition.stack_compatibility_id) + HAUNT_SUFFIX + String(npc.definition_id)),
			paper._stack_definition.base_weight,
		)
	return sheet


static func haunting_sheet_id(paper_id: StringName, npc_definition_id: StringName) -> StringName:
	return StringName(String(paper_id) + HAUNT_SUFFIX + String(npc_definition_id))


## The ID of `id`'s broken form (every weapon has one in the catalog).
static func broken_id(id: StringName) -> StringName:
	return StringName(String(id) + BROKEN_SUFFIX)


## The weapon a broken form was (`id` itself for anything else).
static func unbroken_id(id: StringName) -> StringName:
	var text: String = String(id)
	return StringName(text.trim_suffix(BROKEN_SUFFIX)) if text.ends_with(BROKEN_SUFFIX) else id


func is_broken() -> bool:
	return not _broken_from_name.is_empty()


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


## The LPC liquid/name of what the container holds: its own alcohol keeps its authored
## name (陶壶's 米酒, the wineskin's 红酒); do_fill() makes it 清水.
func liquid_name(content: LiquidState.Content) -> String:
	if content == LiquidState.Content.RED_WINE and _liquid_initial_content == LiquidState.Content.RED_WINE and not _liquid_initial_name.is_empty():
		return _liquid_initial_name
	return LiquidState.content_name(content)


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
	definition._default_long = true
	return DEFAULT_LONG.format({"name": definition._display_name, "id": definition._default_id()})


## The description in the shown language. The default one is put together again from
## its parts, so that the name is translated and the ES2 id kept as written.
func shown_description() -> String:
	if not _default_long:
		return TranslationServer.translate(_description)
	return TranslationServer.translate(DEFAULT_LONG).format({
		"name": TranslationServer.translate(_display_name),
		"id": _default_id(),
	})


func _default_id() -> String:
	var primary_id: String = _aliases[0]
	return primary_id.substr(0, 1).to_upper() + primary_id.substr(1)


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


## std/item/combined.c (COMBINED_ITEM, THROWING): an amount whose weight is amount x
## base_weight, merged into a character's stack of the same file (base_name()).
func _read_combined(combined: ContentRecordReader) -> void:
	_base_unit = combined.required_text("base_unit")
	var base_weight: int = combined.required_integer("base_weight")
	_default_amount = combined.required_integer("amount")
	if base_weight < 0:
		combined.fail("base_weight", "must not be negative")
	if _default_amount < 1:
		combined.fail("amount", "must be positive")
	combined.finish()
	_own_weight = base_weight
	_stack_definition = CombinedStackDefinition.new(
		_item_definition_id,
		StringName("/" + _primary_source().trim_suffix(".c")),
		base_weight,
	)


func _read_weapon(weapon: ContentRecordReader) -> void:
	var skill: String = weapon.required_text("skill")
	_weapon_damage = weapon.required_integer("damage")
	if _weapon_damage < 0:
		weapon.fail("damage", "must not be negative")
	_weapon_rigidity = weapon.integer("rigidity")
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
	var apply: Dictionary[String, int] = weapon.integer_map("apply")
	for key: String in apply:
		if not WEAPON_APPLY_KEYS.has(key):
			weapon.fail("apply." + key, "unsupported weapon_prop (damage is the weapon's damage)")
		_weapon_apply[StringName(key)] = apply[key]
	var weight_dodge: String = weapon.text("weight_dodge")
	if weight_dodge == WEIGHT_DODGE_EQUIP:
		# equip.c: if( !query("weapon_prop/dodge") && (weight() >= 3000) ). Its armor_prop/dodge
		# for the same weapon (which let wear.c put a heavy weapon on) is not ported.
		if _weapon_apply.get(&"dodge", 0) == 0 and _own_weight >= WEIGHT_PER_DODGE:
			_weapon_apply[&"dodge"] = _weight_dodge()
	elif not weight_dodge.is_empty():
		weapon.fail("weight_dodge", "a weapon's setup() is std/equip.c's ('%s')" % WEIGHT_DODGE_EQUIP)
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
	match armor.text("weight_dodge"):
		"":
			pass
		WEIGHT_DODGE_EQUIP:
			if props.get("dodge", 0) == 0 and _own_weight >= WEIGHT_PER_DODGE:
				props["dodge"] = _weight_dodge()
		WEIGHT_DODGE_ARMOR:
			if _own_weight > WEIGHT_PER_DODGE:
				props["dodge"] = _weight_dodge()
		var other:
			armor.fail("weight_dodge", "unknown setup() '%s'" % other)
	armor.finish()
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


## - weight() / 3000.
func _weight_dodge() -> int:
	@warning_ignore("integer_division")
	return -(_own_weight / WEIGHT_PER_DODGE)


func _read_food(food: ContentRecordReader) -> void:
	_food_definition = FoodDefinition.new(
		_item_definition_id,
		food.required_integer("remaining"),
		food.required_integer("supply"),
		_value,
		_own_weight,
	)
	var leaves: ContentRecordReader = food.child("leaves")
	if leaves != null:
		_leaves = {
			"name": leaves.required_text("name"), "aliases": leaves.text_list("aliases"),
			"weight": leaves.required_integer("weight"), "long": leaves.required_text("long"),
			"unit": leaves.text("unit"),
		}
		leaves.finish()
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
