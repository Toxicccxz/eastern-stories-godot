class_name NpcContentRecords
extends RefCounted

## Reads `npcs` and `spawns` records from game/data/ into the existing typed
## definitions. Field names follow the LPC NPC object; see
## docs/migration/CONTENT_DATA_FORMAT.md.
const ATTRIBUTE_KEYS: Array[String] = ["str", "cor", "int", "spi", "cps", "per", "con", "kar"]
const RESOURCE_TRACK_KEYS: Array[String] = ["gin", "kee", "sen"]
## Internal power: current and max of force, atman and mana (no eff_ tier).
const INTERNAL_RESOURCE_KEYS: Array[String] = ["force", "max_force", "atman", "max_atman", "mana", "max_mana"]
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
	var nickname: String = reader.text("nickname")
	var class_id: StringName = StringName(reader.text("class"))
	var rank_respect: String = ""
	var rank_info: ContentRecordReader = reader.child("rank_info")
	if rank_info != null:
		rank_respect = rank_info.required_text("respect")
		rank_info.finish()
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
	var attitude_roll: NpcRandomText = _random_text(reader, "attitude")
	var attitude: int = _attitude_named(attitude_roll.first_choice(), reader) if attitude_roll != null else _attitude(reader)
	if attitude_roll != null and not (_attitude_known(attitude_roll.first_choice()) and _attitude_known(attitude_roll.other_choice())):
		reader.fail("attitude", "unsupported attitude in the rule")
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
		loadout.append(_carry_entry(carry))
	var capabilities: Array[StringName] = _string_names(reader.text_list("capabilities"))
	var attributes: NpcBaseAttributeOverrides = _attribute_overrides(reader)
	var resources: NpcResourceOverrides = _resource_overrides(reader)
	var internal_power: Dictionary[StringName, int] = {}
	var authored_resources: Dictionary[String, int] = reader.integer_map("resources")
	for key: String in INTERNAL_RESOURCE_KEYS:
		if authored_resources.has(key):
			internal_power[StringName(key)] = authored_resources[key]
	if reader.has("force_factor"):
		internal_power[&"force_factor"] = reader.integer("force_factor")
	# apply/<key>: a value, or a rule create() draws (set_temp("apply/dodge", 3 + random(2))).
	var apply: Dictionary[StringName, int] = {}
	var apply_rolls: Dictionary[StringName, NpcRandomInteger] = {}
	var apply_reader: ContentRecordReader = reader.child("apply")
	if apply_reader != null:
		for key: String in apply_reader.keys():
			if not NpcAuthoredCombatFacts.APPLY_KEYS.has(StringName(key)):
				apply_reader.fail(key, "unsupported apply value")
				apply_reader.integer(key) # consumed: reported once, as unsupported
			elif apply_reader.is_object(key):
				apply_rolls[StringName(key)] = _random_integer(apply_reader, key)
			else:
				apply[StringName(key)] = apply_reader.required_integer(key)
		apply_reader.finish()
	var combat_facts: NpcAuthoredCombatFacts = _combat_facts(reader, apply)
	var fight_rules: Array[NpcFightRule] = []
	for rule: ContentRecordReader in reader.children("accept_fight"):
		fight_rules.append(_fight_rule(rule))
	var talk: NpcTalk = _talk(reader)
	var dealings: NpcDealings = NpcDealings.from_record(reader)
	var teaching: NpcTeaching = NpcTeaching.from_record(reader)
	var bellicosity: int = reader.integer("bellicosity")
	var hit_reader: ContentRecordReader = reader.child("hit_ob")
	var hit_condition: NpcHitCondition = NpcHitCondition.from_record(hit_reader) if hit_reader != null else null
	var killed_reader: ContentRecordReader = reader.child("killed_enemy")
	var killed_enemy: NpcKilledEnemy = NpcKilledEnemy.from_record(killed_reader) if killed_reader != null else null
	var name_pick: Array[String] = reader.text_list("name_pick")
	var summoned_reader: ContentRecordReader = reader.child("summoned")
	var summoning: NpcSummoning = NpcSummoning.from_record(summoned_reader) if summoned_reader != null else null
	var conjured_reader: ContentRecordReader = reader.child("conjured")
	var conjuring: NpcConjuring = NpcConjuring.from_record(conjured_reader) if conjured_reader != null else null
	var raised_reader: ContentRecordReader = reader.child("raised")
	var raising: NpcRaising = NpcRaising.from_record(raised_reader) if raised_reader != null else null
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
	).with_creation_facts(title, skill_map, gender_roll, age_roll, combat_experience_roll, score_roll).with_fight_rules(fight_rules).with_talk(talk).with_naming(nickname, rank_respect, class_id).with_dealings(dealings).with_teaching(teaching).with_internal_power(internal_power).with_bellicosity(bellicosity).with_combat_hooks(hit_condition, killed_enemy).with_rolls(apply_rolls, attitude_roll).with_summoning(name_pick, summoning).with_conjuring(conjuring).with_raising(raising)
	if summoning != null and conjuring != null:
		reader.fail("conjured", "an NPC is either summoned to its caster's side or conjured against its owner")
	if raising != null and (summoning != null or conjuring != null or not name_pick.is_empty()):
		reader.fail("raised", "a raised NPC is named after its corpse and neither summoned nor conjured")
	if not name_pick.is_empty() and not name_pick.has(display_name):
		reader.fail("name_pick", "names the NPC's own name among them")
	if bellicosity < 0:
		reader.fail("bellicosity", "must not be negative")
	if not definition.is_valid():
		reader.fail("", "is not a valid NPC definition (aliases, gender, skills, skill_map, carry, random values or talk)")
	return definition


## `inquiry` {topic: [line | {"mark_asker"}] | {"eff_kee_percent": [{"at_least", "say"}]} |
## {"rules": [NpcInquiryRule]}}, `relay_say` {phrase: [{"say" | "emote" | "line" | "whisper"}]}, `chat_chance`
## with `chat_msg` [line | {"say", "color"} | {"action": "random_move"} | {"action": "drink",
## ...} | a special], `chat_chance_combat` with `chat_msg_combat` [line | {"say", "color"} |
## a special] (NpcSpecialAction: perform, cast, exert, surrender) and `greeting` {"say"},
## {"one_of": [{"say" | "emote" | "line"} | act], "out_of"?: n} (switch(random(n)); a draw
## past the lines says nothing) or {"rules": [act]} (the first that is for the player), an
## act being a ScriptedAct record (its `steps`).
static func _talk(reader: ContentRecordReader) -> NpcTalk:
	var inquiry: Dictionary[String, PackedStringArray] = {}
	var kee_answers: Dictionary[String, Array] = {}
	var answer_marks: Dictionary[String, Array] = {}
	var rules: Dictionary[String, Array] = {}
	var topics: ContentRecordReader = reader.child("inquiry")
	if topics != null:
		for topic: String in topics.keys():
			if not topics.is_object(topic):
				var said := PackedStringArray()
				var marks: Array[String] = []
				for entry: Variant in topics.strings_or_children(topic):
					if entry is String:
						said.append(entry)
						continue
					# A function among the lines (oldman2.c set_flag()): it marks the asker.
					var action: ContentRecordReader = entry
					marks.append(action.required_text("mark_asker"))
					action.finish()
				inquiry[topic] = said
				if not marks.is_empty():
					answer_marks[topic] = marks
				continue
			var answer: ContentRecordReader = topics.child(topic)
			if answer.has("rules"):
				var branches: Array[NpcInquiryRule] = []
				for rule: ContentRecordReader in answer.children("rules"):
					branches.append(NpcInquiryRule.from_record(rule))
				rules[topic] = branches
				answer.finish()
				continue
			var cases: Array[NpcTalk.KeeAnswer] = []
			for case: ContentRecordReader in answer.children("eff_kee_percent"):
				cases.append(NpcTalk.KeeAnswer.new(case.required_integer("at_least"), case.required_text("say")))
				case.finish()
			answer.finish()
			kee_answers[topic] = cases
		topics.finish()
	var relay_say: Dictionary[String, Array] = {}
	var heard: ContentRecordReader = reader.child("relay_say")
	if heard != null:
		for phrase: String in heard.keys():
			var lines: Array[NpcLine] = []
			for said: ContentRecordReader in heard.children(phrase):
				var line: NpcLine = NpcLine.from_record(said)
				said.finish()
				if line != null:
					lines.append(line)
			relay_say[phrase] = lines
		heard.finish()
	var entries: Array = _chat_entries(reader, "chat_msg", false)
	var chance: int = reader.integer("chat_chance")
	if reader.has("chat_chance") != reader.has("chat_msg"):
		reader.fail("chat_chance", "chat_chance and chat_msg come together")
	var combat_entries: Array = _chat_entries(reader, "chat_msg_combat", true)
	var combat_chance: int = reader.integer("chat_chance_combat")
	if reader.has("chat_chance_combat") != reader.has("chat_msg_combat"):
		reader.fail("chat_chance_combat", "chat_chance_combat and chat_msg_combat come together")
	var greeting: Array[ScriptedAct] = []
	var greeting_out_of: int = 0
	var greet: ContentRecordReader = reader.child("greeting")
	if greet != null:
		greeting_out_of = greet.integer("out_of")
		if int(greet.has("say")) + int(greet.has("one_of")) + int(greet.has("rules")) != 1:
			greet.fail("", "needs exactly one of say, one_of and rules")
		elif greet.has("say"):
			greeting.append(ScriptedAct.of_line(NpcLine.new(false, greet.required_text("say"))))
		# A choice is a line, or an act (ScriptedAct) when it has steps.
		for choice: ContentRecordReader in greet.children("one_of"):
			if choice.has("steps"):
				greeting.append(ScriptedAct.from_record(choice))
				continue
			var line: NpcLine = NpcLine.from_record(choice)
			choice.finish()
			if line != null:
				greeting.append(ScriptedAct.of_line(line))
		for rule: ContentRecordReader in greet.children("rules"):
			greeting.append(ScriptedAct.from_record(rule))
		greet.finish()
		if greet.has("out_of") and (not greet.has("one_of") or greeting_out_of <= greeting.size()):
			greet.fail("out_of", "needs one_of and more draws than lines")
	return NpcTalk.new(inquiry, chance, entries, greeting, kee_answers, combat_chance, combat_entries).with_greeting_out_of(greeting_out_of, greet != null and greet.has("rules")).with_actions(answer_marks, rules, relay_say)


## npc.c chat() entries: lines, coloured lines and chat functions; random_move and
## drink only outside a fight, match_weapon (萧辟尘's consider()) only in one.
static func _chat_entries(reader: ContentRecordReader, key: String, in_fight: bool) -> Array:
	var entries: Array = []
	for entry: Variant in reader.strings_or_children(key):
		if entry is String:
			entries.append(entry)
			continue
		var record: ContentRecordReader = entry
		if record.has("say") and not record.has("action"):
			var color := StringName(record.required_text("color"))
			if not ColoredLine.COLORS.has(color):
				record.fail("color", "expected one of %s" % ", ".join(ColoredLine.COLORS))
			entries.append(ColoredLine.new(record.required_text("say"), color))
			record.finish()
			continue
		var action: String = record.required_text("action")
		if NpcSpecialAction.KINDS.has(action):
			entries.append(NpcSpecialAction.from_record(record, action))
		elif action == "random_move" and not in_fight:
			entries.append(NpcTalk.RANDOM_MOVE)
		elif action == "drink" and not in_fight:
			entries.append(NpcDrinkAction.from_record(record))
		elif action == "match_weapon" and in_fight:
			entries.append(NpcWeaponMatch.from_record(record))
		elif NpcFightChat.is_action(action) and in_fight:
			entries.append(NpcFightChat.from_record(record, action))
		elif action == "emote" and not in_fight:
			# An emote command(): data/emoted.o is not in the mudlib, so it prints nothing.
			record.required_text("verb")
			entries.append(NpcTalk.SILENT_EMOTE)
		else:
			record.fail("action", "'%s' is not a %s action (%s)" % [action, key,
				"perform, cast, exert, surrender, match_weapon, wield, call_partner, say_by_age, poison" if in_fight else "random_move, drink, emote, perform, cast, exert, surrender"])
		record.finish()
	return entries


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
		NpcSpawnDefinition.InitialSpawnPolicy.SUMMONED if reader.boolean("summoned", false) else NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
		reader.integer("presence_radius", NpcSpawnDefinition.DEFAULT_PRESENCE_RADIUS),
	)
	if reader.has("draw"):
		if reader.boolean("summoned", false):
			reader.fail("draw", "a drawn spawn is not also summoned")
		definition.with_draw_group(StringName(reader.required_text("draw")))
	reader.finish()
	if definition.presence_radius <= 0:
		reader.fail("presence_radius", "must be positive")
	if not definition.is_valid():
		reader.fail("", "is not a valid spawn (points must be unique and match legacy_quantity)")
	return definition


## One `accept_fight` rule: {"family"?, "gender"?, "emote"?, "say"?, "accept", "kill"?}.
static func _fight_rule(reader: ContentRecordReader) -> NpcFightRule:
	var rule := NpcFightRule.new(
		StringName(reader.text("family")), StringName(reader.text("gender")),
		reader.text("emote"), reader.text("say"), reader.boolean("accept", false), reader.boolean("kill", false),
	)
	if rule.kill and not rule.accept:
		reader.fail("kill", "only an accepted spar becomes a kill")
	if not reader.has("accept"):
		reader.fail("accept", "is required")
	reader.finish()
	return rule


## NpcDefinition.Attitude of an LPC attitude name (peaceful for an unknown one).
static func attitude_of(attitude: String) -> int:
	match attitude:
		"aggressive":
			return NpcDefinition.Attitude.AGGRESSIVE
		"friendly":
			return NpcDefinition.Attitude.FRIENDLY
		"heroism":
			return NpcDefinition.Attitude.HEROISM
	return NpcDefinition.Attitude.PEACEFUL


static func _attitude_known(attitude: String) -> bool:
	return attitude in ["peaceful", "aggressive", "friendly", "heroism"]


static func _attitude(reader: ContentRecordReader) -> int:
	return _attitude_named(reader.text("attitude", "peaceful"), reader)


static func _attitude_named(attitude: String, reader: ContentRecordReader) -> int:
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


## A carry entry, or `{"random": n, "below": k, "then": entry, "else": entry}`: the
## first when random(n) < k (worker2.c: random(50) > 40 wields a hammer, else a rope).
static func _carry_entry(carry: ContentRecordReader) -> NpcLoadoutEntry:
	if not carry.has("random"):
		return _loadout_entry(carry)
	var bound: int = carry.required_integer("random")
	var below: int = carry.required_integer("below")
	var first: ContentRecordReader = carry.child("then")
	var second: ContentRecordReader = carry.child("else")
	if first == null or second == null:
		carry.fail("", "a choice needs then and else")
		carry.finish()
		return NpcLoadoutEntry.new()
	var entry: NpcLoadoutEntry = _loadout_entry(first).with_choice(bound, below, _loadout_entry(second))
	carry.finish()
	if bound <= 0:
		carry.fail("random", "must be positive")
	return entry


## carry_object(path) with optional ->wield()/->wear(); add_money(id, amount), whose
## amount may be a rule create() draws ({"base", "plus_random"}).
static func _loadout_entry(carry: ContentRecordReader) -> NpcLoadoutEntry:
	var item_id: String = carry.required_text("item")
	var source: String = carry.required_text("source")
	var amount_roll: NpcRandomInteger = _random_integer(carry, "amount")
	var amount: int = 1 if amount_roll != null else carry.integer("amount", 1)
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
	return NpcLoadoutEntry.new(StringName(item_id), amount, intent, source).with_amount_roll(amount_roll)


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
		if not known.has(key) and not INTERNAL_RESOURCE_KEYS.has(key):
			reader.fail("resources." + key, "unsupported resource")
	return NpcResourceOverrides.new(tracks[0], tracks[1], tracks[2])


## limbs/verbs and set_temp("apply/...") intrinsics authored on the NPC itself.
## limbs, verbs and the fixed apply/<key> values (`apply`, read with its rules).
static func _combat_facts(reader: ContentRecordReader, apply: Dictionary[StringName, int]) -> NpcAuthoredCombatFacts:
	var has_facts: bool = reader.has("limbs") or reader.has("verbs") or not apply.is_empty()
	var limbs: Array[String] = reader.text_list("limbs")
	var verbs: Array[StringName] = _string_names(reader.text_list("verbs"))
	if not has_facts:
		return null
	return NpcAuthoredCombatFacts.new(limbs, verbs, apply)


static func _string_names(values: Array[String]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: String in values:
		result.append(StringName(value))
	return result
