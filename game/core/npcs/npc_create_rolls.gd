class_name NpcCreateRolls
extends RefCounted

## What create() draws for each NPC it makes, in its own order (d/city/shangshu/npc/huyuan.c:
## set("str", 20 + random(15)) ... set_skill("blade", 30 + random(50))): attributes, internal
## power, combat_exp, the chat chances and skill levels, each `base + random(n)`. Drawn right
## after the NPC's name and age; the values are its own (CharacterState and its chat chances,
## saved), so a save keeps what was drawn. A field drawn here is not authored elsewhere.
const ATTRIBUTE_KEYS: Array[String] = ["str", "cor", "int", "spi", "cps", "per", "con", "kar"]
const POWER_KEYS: Array[String] = ["force", "max_force", "atman", "max_atman", "mana", "max_mana", "force_factor"]
const OTHER_KEYS: Array[String] = ["combat_exp", "chat_chance", "chat_chance_combat"]


class Roll:
	extends RefCounted
	## An attribute, power or other key; empty for a skill.
	var key: String = ""
	var skill_id: StringName = &""
	var roll: NpcRandomInteger


var rolls: Array[Roll] = []


## [{key | skill, base, plus_random}] in create()'s order.
static func from_records(readers: Array[ContentRecordReader]) -> NpcCreateRolls:
	var result := NpcCreateRolls.new()
	var seen: Dictionary[String, bool] = {}
	for reader: ContentRecordReader in readers:
		var entry := Roll.new()
		if reader.has("key") == reader.has("skill"):
			reader.fail("", "names a key or a skill")
		entry.key = reader.text("key")
		entry.skill_id = StringName(reader.text("skill"))
		if not entry.key.is_empty() and not (ATTRIBUTE_KEYS + POWER_KEYS + OTHER_KEYS).has(entry.key):
			reader.fail("key", "expected one of %s" % [ATTRIBUTE_KEYS + POWER_KEYS + OTHER_KEYS])
		var name: String = entry.key if entry.skill_id.is_empty() else "skill:" + String(entry.skill_id)
		if seen.has(name):
			reader.fail("", "%s is drawn twice" % name)
		seen[name] = true
		entry.roll = NpcRandomInteger.new(reader.required_integer("base"), 1, reader.required_integer("plus_random"))
		reader.finish()
		if not entry.roll.is_valid():
			reader.fail("plus_random", "must be positive")
		result.rolls.append(entry)
	return result


func is_empty() -> bool:
	return rolls.is_empty()


## The rule for `key` (an attribute, power or other key), or null when create() does not draw it.
func roll_of(key: String) -> NpcRandomInteger:
	for entry: Roll in rolls:
		if entry.key == key:
			return entry.roll
	return null


## The skills it draws levels for.
func skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Roll in rolls:
		if not entry.skill_id.is_empty():
			result.append(entry.skill_id)
	return result


## Each draw in order: {key or "skill:<id>": value}; null when the source answers out of range.
func resolve(random_source: NpcInitializationRandomSource) -> Variant:
	var drawn: Dictionary[String, int] = {}
	for entry: Roll in rolls:
		var value: Variant = entry.roll.resolve(random_source)
		if value == null:
			return null
		drawn[entry.key if entry.skill_id.is_empty() else "skill:" + String(entry.skill_id)] = value
	return drawn
