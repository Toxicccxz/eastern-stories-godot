class_name NpcContentRecords
extends RefCounted

## Reads `npcs` and `spawns` records from game/data/ into the existing typed
## definitions. Field names follow the LPC NPC object; see
## docs/migration/CONTENT_DATA_FORMAT.md.
const ATTRIBUTE_KEYS: Array[String] = ["str", "cor", "int", "spi", "cps", "per", "con", "kar"]
const RESOURCE_TRACK_KEYS: Array[String] = ["gin", "kee", "sen"]
const APPLY_KEYS: Array[String] = ["attack", "damage", "armor", "dodge"]
const RACE_IDS: Array[StringName] = [
	NpcCharacterStateFactory.HUMAN_RACE_ID,
	NpcCharacterStateFactory.BEAST_RACE_ID,
]


static func npc_from_record(reader: ContentRecordReader) -> NpcDefinition:
	var definition_id: String = reader.required_text("id")
	var legacy_source: String = reader.required_text("legacy_source")
	var display_name: String = reader.required_text("name")
	var aliases: Array[StringName] = _string_names(reader.text_list("aliases"))
	var race_id: StringName = StringName(
		reader.text("race", String(NpcCharacterStateFactory.HUMAN_RACE_ID))
	)
	if not RACE_IDS.has(race_id):
		reader.fail("race", "unsupported race '%s'" % race_id)
	var title: String = reader.text("title")
	var has_gender: bool = reader.has("gender")
	var gender_roll: NpcRandomText = _random_text(reader, "gender")
	var gender: String = gender_roll.first_choice() if gender_roll != null else reader.text("gender")
	var has_age: bool = reader.has("age")
	var age_roll: NpcRandomInteger = _random_integer(reader, "age")
	var age: int = age_roll.base if age_roll != null else reader.integer("age")
	var description: String = reader.text("long")
	var combat_experience_roll: NpcRandomInteger = _random_integer(reader, "combat_exp")
	var combat_experience: int = (
		combat_experience_roll.base if combat_experience_roll != null else reader.integer("combat_exp")
	)
	var score_roll: NpcRandomInteger = _random_integer(reader, "score")
	var score: int = score_roll.base if score_roll != null else reader.integer("score")
	var attitude: int = _attitude(reader)
	var skills: Array[NpcSkillLevelDefinition] = []
	var skill_levels: Dictionary[String, int] = reader.integer_map("skills")
	for skill_id: String in skill_levels:
		skills.append(NpcSkillLevelDefinition.new(StringName(skill_id), skill_levels[skill_id]))
	var skill_map: Dictionary[StringName, StringName] = {}
	var authored_map: Dictionary[String, String] = reader.text_map("skill_map")
	for use_id: String in authored_map:
		skill_map[StringName(use_id)] = StringName(authored_map[use_id])
	var loadout: Array[NpcLoadoutEntry] = []
	for carry: ContentRecordReader in reader.children("carry"):
		loadout.append(_loadout_entry(carry))
	var capabilities: Array[StringName] = _string_names(reader.text_list("capabilities"))
	var attributes: NpcBaseAttributeOverrides = _attribute_overrides(reader)
	var resources: NpcResourceOverrides = _resource_overrides(reader)
	var combat_facts: NpcAuthoredCombatFacts = _combat_facts(reader)
	reader.finish()
	var definition: NpcDefinition = NpcDefinition.new(
		StringName(definition_id),
		legacy_source,
		display_name,
		aliases,
		race_id,
		has_gender,
		StringName(gender),
		has_age,
		age,
		attributes,
		resources,
		combat_experience,
		score,
		attitude,
		skills,
		loadout,
		capabilities,
		description,
		combat_facts,
	).with_creation_facts(title, skill_map, gender_roll, age_roll, combat_experience_roll, score_roll)
	if not definition.is_valid():
		reader.fail("", "is not a valid NPC definition (aliases, gender, skills, skill_map, carry or random values)")
	return definition


static func spawn_from_record(reader: ContentRecordReader) -> NpcSpawnDefinition:
	var points: Array[StringName] = _string_names(reader.text_list("points"))
	var definition: NpcSpawnDefinition = NpcSpawnDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("npc")),
		StringName(reader.required_text("map")),
		StringName(reader.required_text("zone")),
		points,
		points.size(),
		reader.required_text("legacy_room"),
		reader.required_integer("legacy_quantity"),
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
		reader.integer("presence_radius", NpcSpawnDefinition.DEFAULT_PRESENCE_RADIUS),
	)
	reader.finish()
	if definition.presence_radius <= 0:
		reader.fail("presence_radius", "must be positive")
	if not definition.is_valid():
		reader.fail("", "is not a valid spawn (points must be unique and match legacy_quantity)")
	return definition


static func _attitude(reader: ContentRecordReader) -> int:
	var attitude: String = reader.text("attitude", "peaceful")
	match attitude:
		"peaceful":
			return NpcDefinition.Attitude.PEACEFUL
		"aggressive":
			return NpcDefinition.Attitude.AGGRESSIVE
		"friendly":
			return NpcDefinition.Attitude.FRIENDLY
		"heroism":
			return NpcDefinition.Attitude.HEROISM
	reader.fail("attitude", "unsupported attitude '%s'" % attitude)
	return NpcDefinition.Attitude.PEACEFUL


## `{"base": b, "plus_random": n}` is b + random(n), `"minus_random"` b - random(n);
## null when the field is absent or a plain integer.
static func _random_integer(reader: ContentRecordReader, key: String) -> NpcRandomInteger:
	if not reader.is_object(key):
		return null
	var roll: ContentRecordReader = reader.child(key)
	var base: int = roll.required_integer("base")
	# An unusable rule still stands in for the field, so it is never read as a plain value.
	var result: NpcRandomInteger = NpcRandomInteger.new(base, 1, 0)
	if roll.has("plus_random") == roll.has("minus_random"):
		roll.fail("", "needs exactly one of plus_random and minus_random")
	elif roll.has("plus_random"):
		result = NpcRandomInteger.new(base, 1, roll.required_integer("plus_random"))
	else:
		result = NpcRandomInteger.new(base, -1, roll.required_integer("minus_random"))
	roll.finish()
	if roll.has("plus_random") != roll.has("minus_random") and not result.is_valid():
		roll.fail("", "random bound must be positive")
	return result


## `{"random": n, "below": k, "then": a, "else": b}`: a when random(n) < k.
static func _random_text(reader: ContentRecordReader, key: String) -> NpcRandomText:
	if not reader.is_object(key):
		return null
	var roll: ContentRecordReader = reader.child(key)
	var result: NpcRandomText = NpcRandomText.new(
		roll.required_integer("random"),
		roll.required_integer("below"),
		roll.required_text("then"),
		roll.required_text("else"),
	)
	roll.finish()
	if not result.is_valid():
		roll.fail("", "random bound must be positive")
	return result


## carry_object(path) with optional ->wield()/->wear(); add_money(id, amount).
static func _loadout_entry(carry: ContentRecordReader) -> NpcLoadoutEntry:
	var item_id: String = carry.required_text("item")
	var source: String = carry.required_text("source")
	var amount: int = carry.integer("amount", 1)
	var intent: int = NpcLoadoutEntry.EquipmentIntent.NONE
	match carry.text("equip"):
		"":
			pass
		"wield":
			intent = NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY
		"wear":
			intent = NpcLoadoutEntry.EquipmentIntent.WEAR
		_:
			carry.fail("equip", "expected 'wield' or 'wear'")
	carry.finish()
	return NpcLoadoutEntry.new(StringName(item_id), amount, intent, source)


static func _attribute_overrides(reader: ContentRecordReader) -> NpcBaseAttributeOverrides:
	var authored: Dictionary[String, int] = reader.integer_map("attributes")
	for key: String in authored:
		if not ATTRIBUTE_KEYS.has(key):
			reader.fail("attributes." + key, "unsupported attribute")
	return NpcBaseAttributeOverrides.new(
		authored.has("str"), authored.get("str", 0),
		authored.has("cor"), authored.get("cor", 0),
		authored.has("int"), authored.get("int", 0),
		authored.has("spi"), authored.get("spi", 0),
		authored.has("cps"), authored.get("cps", 0),
		authored.has("per"), authored.get("per", 0),
		authored.has("con"), authored.get("con", 0),
		authored.has("kar"), authored.get("kar", 0),
	)


## LPC gin/kee/sen with their eff_ and max_ variants.
static func _resource_overrides(reader: ContentRecordReader) -> NpcResourceOverrides:
	var authored: Dictionary[String, int] = reader.integer_map("resources")
	var tracks: Array[NpcResourceTrackOverride] = []
	var known: Array[String] = []
	for track: String in RESOURCE_TRACK_KEYS:
		known.append_array([track, "eff_" + track, "max_" + track])
		tracks.append(NpcResourceTrackOverride.new(
			authored.has(track), authored.get(track, 0),
			authored.has("eff_" + track), authored.get("eff_" + track, 0),
			authored.has("max_" + track), authored.get("max_" + track, 0),
		))
	for key: String in authored:
		if not known.has(key):
			reader.fail("resources." + key, "unsupported resource")
	return NpcResourceOverrides.new(tracks[0], tracks[1], tracks[2])


## limbs/verbs and set_temp("apply/...") intrinsics authored on the NPC itself.
static func _combat_facts(reader: ContentRecordReader) -> NpcAuthoredCombatFacts:
	var has_facts: bool = reader.has("limbs") or reader.has("verbs") or reader.has("apply")
	var limbs: Array[String] = reader.text_list("limbs")
	var verbs: Array[StringName] = _string_names(reader.text_list("verbs"))
	var apply: Dictionary[String, int] = reader.integer_map("apply")
	for key: String in apply:
		if not APPLY_KEYS.has(key):
			reader.fail("apply." + key, "unsupported apply value")
	if not has_facts:
		return null
	return NpcAuthoredCombatFacts.new(
		limbs,
		verbs,
		apply.get("attack", 0),
		apply.get("damage", 0),
		apply.get("armor", 0),
		apply.get("dodge", 0),
	)


static func _string_names(values: Array[String]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: String in values:
		result.append(StringName(value))
	return result
