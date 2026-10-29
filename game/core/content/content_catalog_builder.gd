class_name ContentCatalogBuilder
extends RefCounted

## Collects parsed data documents and cross-checks them. A document is one
## JSON object with any of the `items`, `npcs`, `spawns`, `item_spawns`,
## `vendors`, `rooms`, `regions`, `maps`, `zones`, `portals`, `services`,
## `doors`, `landmarks`, `traps`, `exit_rules`, `skills`, `families`, `race_actions`, `weapon_actions`,
## `quest_tiers`, `quests`, `journal_chains`, `codex_topics`, `day_phases` arrays, and at most one document
## has the `pacing` object (and at most one the `progression` object).
## build() returns null when anything was reported; errors() says what.
var _errors: Array[String] = []
var _items: Dictionary[StringName, ItemContentDefinition] = {}
var _npcs: Dictionary[StringName, NpcDefinition] = {}
var _spawns: Dictionary[StringName, NpcSpawnDefinition] = {}
var _item_spawns: Dictionary[StringName, ItemSpawnDefinition] = {}
var _vendors: Dictionary[StringName, VendorDefinition] = {}
var _rooms: Dictionary[StringName, RoomDefinition] = {}
var _regions: Dictionary[StringName, RegionDefinition] = {}
var _maps: Dictionary[StringName, MapDefinition] = {}
var _zones: Dictionary[StringName, ZoneDefinition] = {}
var _portals: Dictionary[StringName, PortalDefinition] = {}
var _services: Dictionary[StringName, ServiceDefinition] = {}
var _doors: Dictionary[StringName, DoorDefinition] = {}
var _landmarks: Dictionary[StringName, WorldLandmarkDefinition] = {}
var _traps: Dictionary[StringName, RoomTrapDefinition] = {}
var _hazards: Dictionary[StringName, RoomHazardDefinition] = {}
# The NPCs a COMES step calls over (ContentCatalog.called_over()).
var _called_over: Dictionary[StringName, bool] = {}
var _exit_rules: Dictionary[StringName, ZoneExitRuleDefinition] = {}
var _skills: Dictionary[StringName, SkillDefinition] = {}
var _families: Dictionary[StringName, FamilyDefinition] = {}
var _combat_actions: CombatActionTables = CombatActionTables.new()
var _quest_tiers: Array[QuestTier] = []
var _journal_chains: Array[JournalChainDefinition] = []
var _story_quests: Array[StoryQuestDefinition] = []
var _codex_topics: Array[CodexTopicDefinition] = []
var _day_phases: Array[DayPhaseDefinition] = []
var _sky_levels: Array[String] = []
var _pacing: PacingDefinition
var _progression: ProgressionRules
var _bounties: BountyRules
var _opening: OpeningDefinition
var _origins: Dictionary[StringName, String] = {}


func errors() -> Array[String]:
	return _errors.duplicate()


func report(message: String) -> void:
	_errors.append(message)


func add_document(document: Variant, origin: String) -> void:
	if not document is Dictionary:
		_errors.append("%s: expected a JSON object" % origin)
		return
	var reader: ContentRecordReader = ContentRecordReader.new(document, origin, _errors)
	for record: ContentRecordReader in reader.children("items"):
		var definition: ItemContentDefinition = ItemContentDefinition.from_record(record)
		if _claim(definition.item_definition_id, record):
			_items[definition.item_definition_id] = definition
	for record: ContentRecordReader in reader.children("npcs"):
		var definition: NpcDefinition = NpcContentRecords.npc_from_record(record)
		if _claim(definition.definition_id, record):
			_npcs[definition.definition_id] = definition
	for record: ContentRecordReader in reader.children("spawns"):
		var definition: NpcSpawnDefinition = NpcContentRecords.spawn_from_record(record)
		if _claim(definition.spawn_id, record):
			_spawns[definition.spawn_id] = definition
	for record: ContentRecordReader in reader.children("item_spawns"):
		var definition: ItemSpawnDefinition = ItemSpawnDefinition.from_record(record)
		if _claim(definition.spawn_id, record):
			_item_spawns[definition.spawn_id] = definition
	for record: ContentRecordReader in reader.children("vendors"):
		var definition: VendorDefinition = VendorDefinition.from_record(record)
		if _claim(definition.vendor_id, record):
			_vendors[definition.vendor_id] = definition
	for record: ContentRecordReader in reader.children("rooms"):
		var definition: RoomDefinition = RoomDefinition.from_record(record)
		if _claim(definition.room_id, record):
			_rooms[definition.room_id] = definition
	for record: ContentRecordReader in reader.children("regions"):
		var definition: RegionDefinition = RegionDefinition.from_record(record)
		if _claim(definition.region_id, record):
			_regions[definition.region_id] = definition
	for record: ContentRecordReader in reader.children("maps"):
		var definition: MapDefinition = MapDefinition.from_record(record)
		if _claim(definition.map_id, record):
			_maps[definition.map_id] = definition
	for record: ContentRecordReader in reader.children("zones"):
		var definition: ZoneDefinition = ZoneDefinition.from_record(record)
		if _claim(definition.zone_id, record):
			_zones[definition.zone_id] = definition
	for record: ContentRecordReader in reader.children("portals"):
		var definition: PortalDefinition = PortalDefinition.from_record(record)
		if _claim(definition.portal_id, record):
			_portals[definition.portal_id] = definition
	for record: ContentRecordReader in reader.children("services"):
		var definition: ServiceDefinition = ServiceDefinition.from_record(record)
		if _claim(definition.service_id, record):
			_services[definition.service_id] = definition
	for record: ContentRecordReader in reader.children("doors"):
		var definition: DoorDefinition = DoorDefinition.from_record(record)
		if _claim(definition.door_id, record):
			_doors[definition.door_id] = definition
	for record: ContentRecordReader in reader.children("landmarks"):
		var definition: WorldLandmarkDefinition = WorldLandmarkDefinition.from_record(record)
		if _claim(definition.landmark_id, record):
			_landmarks[definition.landmark_id] = definition
	for record: ContentRecordReader in reader.children("traps"):
		var definition: RoomTrapDefinition = RoomTrapDefinition.from_record(record)
		if _claim(definition.trap_id, record):
			_traps[definition.trap_id] = definition
	for record: ContentRecordReader in reader.children("hazards"):
		var definition: RoomHazardDefinition = RoomHazardDefinition.from_record(record)
		if _claim(definition.hazard_id, record):
			_hazards[definition.hazard_id] = definition
	for record: ContentRecordReader in reader.children("exit_rules"):
		var definition: ZoneExitRuleDefinition = ZoneExitRuleDefinition.from_record(record)
		if _claim(definition.rule_id, record):
			_exit_rules[definition.rule_id] = definition
	for record: ContentRecordReader in reader.children("skills"):
		var definition: SkillDefinition = SkillDefinition.from_record(record)
		if _claim(definition.skill_id, record):
			_skills[definition.skill_id] = definition
	for record: ContentRecordReader in reader.children("families"):
		var definition: FamilyDefinition = FamilyDefinition.from_record(record)
		if _claim(definition.family_id, record):
			_families[definition.family_id] = definition
	for record: ContentRecordReader in reader.children("race_actions"):
		_combat_actions.add_race(record)
	for record: ContentRecordReader in reader.children("weapon_actions"):
		_combat_actions.add_weapon_actions(record)
	for record: ContentRecordReader in reader.children("quest_tiers"):
		_quest_tiers.append(QuestTier.from_record(record))
	for record: ContentRecordReader in reader.children("journal_chains"):
		_journal_chains.append(JournalChainDefinition.from_record(record))
	for record: ContentRecordReader in reader.children("quests"):
		_story_quests.append(StoryQuestDefinition.from_record(record))
	for record: ContentRecordReader in reader.children("codex_topics"):
		_codex_topics.append(CodexTopicDefinition.from_record(record))
	for record: ContentRecordReader in reader.children("day_phases"):
		_day_phases.append(DayPhaseDefinition.from_record(record))
	if reader.has("sky_levels"):
		if not _sky_levels.is_empty():
			reader.fail("sky_levels", "sky_levels is already defined")
		_sky_levels = reader.text_list("sky_levels")
	var pacing: ContentRecordReader = reader.child("pacing")
	if pacing != null:
		if _pacing != null:
			pacing.fail("", "pacing is already defined")
		_pacing = PacingDefinition.from_record(pacing)
	var progression: ContentRecordReader = reader.child("progression")
	if progression != null:
		if _progression != null:
			progression.fail("", "progression is already defined")
		_progression = ProgressionRules.from_record(progression)
	var bounties: ContentRecordReader = reader.child("bounty_board")
	if bounties != null:
		if _bounties != null:
			bounties.fail("", "bounty_board is already defined")
		_bounties = BountyRules.from_record(bounties)
	var opening: ContentRecordReader = reader.child("opening")
	if opening != null:
		if _opening != null:
			opening.fail("", "opening is already defined")
		_opening = OpeningDefinition.from_record(opening)
	reader.finish()


func build() -> ContentCatalog:
	_add_named_npcs()
	_add_named_items()
	_add_mastered_items()
	# What a food that is a weapon leaves is that weapon still (it can break), and the
	# broken one is food still (it leaves its own): leftovers, breaks, then theirs.
	_add_leftovers()
	_add_broken_weapons()
	_add_leftovers()
	_add_haunting_sheets()
	_check_money()
	_check_npc_loadouts()
	_resolve_npc_dealings()
	_check_spawns()
	_check_vendors()
	_check_maps()
	_resolve_zones()
	_resolve_portals()
	_check_spawn_locations()
	_resolve_services()
	_check_item_acts()
	_resolve_doors()
	_resolve_landmarks()
	_check_traps()
	_check_hazards()
	_check_exit_rules()
	_check_combat_data()
	_check_quest_tiers()
	_check_journal()
	_check_story_quests()
	_check_progression()
	_check_day_phases()
	if _pacing == null:
		_errors.append("pacing: no document defines it")
	if not _errors.is_empty():
		return null
	var catalog: ContentCatalog = ContentCatalog.new(_items, _npcs, _spawns, _vendors)
	catalog.set_world(_rooms, _regions, _maps, _zones, _portals)
	catalog.set_places(_services, _doors, _landmarks, _traps)
	catalog.set_hazards(_hazards)
	catalog.set_called_over(_called_over)
	catalog.set_exit_rules(_exit_rules)
	catalog.set_item_spawns(_item_spawns)
	catalog.set_pacing(_pacing)
	catalog.set_teaching(_skills, _families)
	catalog.set_combat_actions(_combat_actions)
	catalog.set_quest_tiers(_quest_tiers)
	catalog.set_journal(_journal_chains, _codex_topics)
	catalog.set_story_quests(_story_quests)
	catalog.set_day_phases(_day_phases)
	catalog.set_sky_levels(_sky_levels)
	catalog.set_progression(_progression)
	catalog.set_bounties(_bounties)
	catalog.set_opening(_opening)
	# Backstop for role combinations the item rules cannot represent; saves
	# validate against these projections.
	if not catalog.native_item_projections().is_valid:
		_errors.append("items: item roles are inconsistent (NativeItemDefinitionProjections)")
		return null
	return catalog


## What each food leaves once eaten up (finish_eat()): a plain item of its own.
func _add_leftovers() -> void:
	for item: ItemContentDefinition in _items.values().duplicate():
		if not item.leftover_id().is_empty() and not _items.has(item.leftover_id()):
			var left: ItemContentDefinition = ItemContentDefinition.leftover(item)
			_items[left.item_definition_id] = left


## A 僵尸追魂符 for every NPC on every paper one draws 符 on (necromancy/haunt.c scribe()),
## so a drawn sheet keeps the name written on it. A raised NPC's name is its corpse's: no
## sheet names one.
func _add_haunting_sheets() -> void:
	for paper: ItemContentDefinition in _items.values().duplicate():
		if not paper.scribe:
			continue
		for npc: NpcDefinition in _npcs.values():
			if npc.raising() == null:
				var sheet: ItemContentDefinition = ItemContentDefinition.haunting_sheet(paper, npc)
				_items[sheet.item_definition_id] = sheet


## Each name a placed NPC's create() may draw (yamen_po.c) as a form of its own, so the name
## kept is saved (a save names the NPC's definition). A summoned one is never saved.
func _add_named_npcs() -> void:
	for spawn: NpcSpawnDefinition in _spawns.values():
		var npc: NpcDefinition = _npcs.get(spawn.npc_definition_id)
		if npc == null or spawn.summoned or npc.name_pick().is_empty() or npc.names_kept():
			continue
		npc.keep_names()
		for index: int in range(npc.name_pick().size()):
			var named: NpcDefinition = npc.named(index)
			_npcs[named.definition_id] = named
			_origins[named.definition_id] = _origins.get(npc.definition_id, "")


## Each name an item's create() may draw (book.c) as a form of its own, so the name kept is saved.
func _add_named_items() -> void:
	for item: ItemContentDefinition in _items.values().duplicate():
		for index: int in range(item.name_pick().size()):
			var named: ItemContentDefinition = ItemContentDefinition.named(item, index)
			_items[named.item_definition_id] = named


## The master form of each item that records who got it (set("master_id")), so the
## player's 忘忧草 stays theirs in a save.
func _add_mastered_items() -> void:
	for item: ItemContentDefinition in _items.values().duplicate():
		if item.masters:
			var form: ItemContentDefinition = ItemContentDefinition.mastered_form(item)
			_items[form.item_definition_id] = form


## Every weapon's broken form (weapond.c bash_weapon()), so a broken one keeps its identity.
func _add_broken_weapons() -> void:
	for item: ItemContentDefinition in _items.values().duplicate():
		if item.weapon_definition() != null and not _items.has(StringName(String(item.item_definition_id) + ItemContentDefinition.BROKEN_SUFFIX)):
			var broken: ItemContentDefinition = ItemContentDefinition.broken_weapon(item)
			_items[broken.item_definition_id] = broken


## A catalog that defines skills is a game's: its fights need the race and weapon
## moves and the dodge.c and parry.c lines every narration falls back to.
func _check_combat_data() -> void:
	if _skills.is_empty():
		return
	if _combat_actions.race_action_set(&"human") == null:
		_errors.append("race_actions: no moves for race 'human'")
	if not _combat_actions.weapon_action_set(&"").is_valid():
		_errors.append("weapon_actions: no 'slash' action")
	var dodge: SkillDefinition = _skills.get(&"dodge")
	if dodge == null or dodge.dodge_messages.is_empty():
		_errors.append("skills: 'dodge' needs dodge_messages")
	var parry: SkillDefinition = _skills.get(&"parry")
	if parry == null or parry.parry_messages_armed.is_empty() or parry.parry_messages_unarmed.is_empty():
		_errors.append("skills: 'parry' needs parry_messages armed and unarmed")
	# What a practice conjures is a conjured NPC, and its draw reads a skill (PracticeConjuring).
	for skill: SkillDefinition in _skills.values():
		var conjuring: PracticeConjuring = skill.practice_policy().conjuring
		if conjuring == null:
			continue
		if not _skills.has(conjuring.skill_id):
			_errors.append("skills: '%s' conjures by an unknown skill '%s'" % [skill.skill_id, conjuring.skill_id])
		for npc_id: StringName in conjuring.npc_ids:
			if not _npcs.has(npc_id) or _npcs[npc_id].conjuring() == null:
				_errors.append("skills: '%s' conjures '%s', which is no conjured NPC" % [skill.skill_id, npc_id])
			elif not _npcs[npc_id].loadout_entries().is_empty():
				# A save leaves a standing conjured NPC out: it must hold no item.
				_errors.append("skills: '%s' conjures '%s', which carries something" % [skill.skill_id, npc_id])


## god.c's levels rise; each is one qlist file.
func _check_quest_tiers() -> void:
	for index: int in range(1, _quest_tiers.size()):
		if _quest_tiers[index].min_exp <= _quest_tiers[index - 1].min_exp:
			_errors.append("quest_tiers: min_exp %d does not rise above %d" % [_quest_tiers[index].min_exp, _quest_tiers[index - 1].min_exp])


## The 任务 page's chains name items, NPCs and topics the game has; the 百科's topics and
## the chains have unique IDs.
func _check_journal() -> void:
	var chains: Dictionary[StringName, bool] = {}
	for chain: JournalChainDefinition in _journal_chains:
		if chains.has(chain.chain_id):
			_errors.append("journal_chains: duplicate chain '%s'" % chain.chain_id)
		chains[chain.chain_id] = true
		for entry: JournalEntryDefinition in chain.entries:
			var origin: String = "journal_chains.%s" % chain.key_of(entry)
			_check_condition(origin + ".when", entry)
			if not entry.quote_npc.is_empty():
				var quoted: NpcDefinition = _npcs.get(entry.quote_npc)
				if quoted == null or not quoted.talk().has_answer(entry.quote_topic) or quoted.talk().answer(entry.quote_topic).is_empty():
					_errors.append("%s.quote: '%s' says nothing about '%s'" % [origin, entry.quote_npc, entry.quote_topic])
	var topics: Dictionary[StringName, bool] = {}
	for topic: CodexTopicDefinition in _codex_topics:
		if topics.has(topic.topic_id):
			_errors.append("codex_topics: duplicate topic '%s'" % topic.topic_id)
		topics[topic.topic_id] = true


## A condition (a journal entry's `when`, a quest's `starts` or a step's `done`) names an
## item, NPC, topic, milestone kind, skill, family or zone the game has.
func _check_condition(origin: String, entry: JournalEntryDefinition) -> void:
	match entry.when:
		JournalEntryDefinition.When.ITEM:
			if not _items.has(StringName(entry.key)):
				_errors.append("%s.item: no item '%s'" % [origin, entry.key])
		JournalEntryDefinition.When.SEEN:
			if not _npcs.has(StringName(entry.key)):
				_errors.append("%s.seen: no NPC '%s'" % [origin, entry.key])
		JournalEntryDefinition.When.HEARD:
			var npc: NpcDefinition = _npcs.get(StringName(entry.key))
			if npc == null or not npc.talk().inquiry_topics().has(entry.topic):
				_errors.append("%s.heard: '%s' has no topic '%s'" % [origin, entry.key, entry.topic])
		JournalEntryDefinition.When.CHAT:
			if not _npcs.has(StringName(entry.key)):
				_errors.append("%s.chat: no NPC '%s'" % [origin, entry.key])
		JournalEntryDefinition.When.MILESTONE:
			if not MilestoneRewards.KIND_NAMES.values().has(entry.key.get_slice("/", 0)) or entry.key.get_slice_count("/") < 2:
				_errors.append("%s.milestone: expected '<kind>/<id>', got '%s'" % [origin, entry.key])
		JournalEntryDefinition.When.SKILL_AT_LEAST:
			if not _skills.has(StringName(entry.key)):
				_errors.append("%s.skill_at_least: no skill '%s'" % [origin, entry.key])
		JournalEntryDefinition.When.FAMILY:
			if not _families.has(StringName(entry.key)):
				_errors.append("%s.family: no family '%s'" % [origin, entry.key])
		JournalEntryDefinition.When.ZONE:
			if not _zones.has(StringName(entry.key)):
				_errors.append("%s.zone: no zone '%s'" % [origin, entry.key])


## The quests (任务系统) have unique IDs, name quests, zones and maps the game has, and
## their conditions name what the game has.
func _check_story_quests() -> void:
	var quests: Dictionary[StringName, bool] = {}
	for quest: StoryQuestDefinition in _story_quests:
		if quests.has(quest.quest_id):
			_errors.append("quests: duplicate quest '%s'" % quest.quest_id)
		quests[quest.quest_id] = true
	for quest: StoryQuestDefinition in _story_quests:
		var origin: String = "quests.%s" % quest.quest_id
		if quest.starts != null:
			_check_condition(origin + ".starts", quest.starts)
		for other: StringName in quest.requires + quest.excludes:
			if other == quest.quest_id:
				_errors.append("%s: names itself" % origin)
			elif not quests.has(other):
				_errors.append("%s: no quest '%s'" % [origin, other])
		for step: StoryQuestDefinition.Step in quest.steps:
			var at: String = "%s.%s" % [origin, step.step_id]
			if step.condition != null:
				_check_condition(at + ".done", step.condition)
			for option: StoryQuestDefinition.Option in step.options:
				_check_condition("%s.%s.done" % [at, option.option_id], option.condition)
			if step.target != null:
				var zone: ZoneDefinition = _zones.get(step.target.zone_id)
				if not _maps.has(step.target.map_id):
					_errors.append("%s.target: no map '%s'" % [at, step.target.map_id])
				if zone == null:
					_errors.append("%s.target: no zone '%s'" % [at, step.target.zone_id])
				elif zone.map_id != step.target.map_id:
					_errors.append("%s.target: zone '%s' is not on map '%s'" % [at, step.target.zone_id, step.target.map_id])


## The progression table names NPCs, zones and chains the game has.
## natured.c turns through the phases in order, the day being their lengths' sum (1440).
func _check_day_phases() -> void:
	# natured.c's weather_msg: one line a level, SkyState.LEVELS of them.
	if not _sky_levels.is_empty() and _sky_levels.size() != SkyState.LEVELS:
		_errors.append("sky_levels: %d lines, not %d" % [_sky_levels.size(), SkyState.LEVELS])
	if _day_phases.is_empty():
		return
	var total: int = 0
	var seen: Dictionary[StringName, bool] = {}
	for phase: DayPhaseDefinition in _day_phases:
		total += phase.minutes
		if seen.has(phase.phase_id):
			_errors.append("day_phases: duplicate phase '%s'" % phase.phase_id)
		seen[phase.phase_id] = true
	if total != DayClock.DAY_MINUTES:
		_errors.append("day_phases: the phases add up to %d minutes, not %d" % [total, DayClock.DAY_MINUTES])


func _check_progression() -> void:
	if _progression == null:
		return
	for npc_id: StringName in _progression.notable_npcs:
		if not _npcs.has(npc_id):
			_errors.append("progression.notable_npcs: no NPC '%s'" % npc_id)
	for zone_id: StringName in _progression.places:
		if not _zones.has(zone_id):
			_errors.append("progression.places: no zone '%s'" % zone_id)
	var chains: Dictionary[StringName, bool] = {}
	for chain: JournalChainDefinition in _journal_chains:
		chains[chain.chain_id] = true
	for chain_id: StringName in _progression.chain_percent:
		if not chains.has(chain_id):
			_errors.append("progression.chain_percent: no chain '%s'" % chain_id)
	var quests: Dictionary[StringName, bool] = {}
	for quest: StoryQuestDefinition in _story_quests:
		quests[quest.quest_id] = true
	for quest_id: StringName in _progression.quest_percent:
		if not quests.has(quest_id):
			_errors.append("progression.quest_percent: no quest '%s'" % quest_id)
	if _bounties == null:
		return
	for tier: BountyRules.Tier in _bounties.tiers:
		var npc: NpcDefinition = _npcs.get(tier.npc_id)
		if npc == null or npc.native_role() != NpcDefinition.ROLE_BOUNTY_TARGET:
			_errors.append("bounty_board.tiers: '%s' is no NPC of native role bounty_target" % tier.npc_id)
	for place: BountyRules.Place in _bounties.places:
		var zone: ZoneDefinition = _zones.get(place.zone_id)
		if zone == null or zone.map_id != place.map_id:
			_errors.append("bounty_board.places: no zone '%s' on map '%s'" % [place.zone_id, place.map_id])


## IDs are unique across every kind, so one ID never means two things.
func _claim(id: StringName, record: ContentRecordReader) -> bool:
	if id.is_empty():
		return false
	if _origins.has(id):
		record.fail("id", "'%s' is already defined at %s" % [id, _origins[id]])
		return false
	_origins[id] = record.path
	return true


func _check_money() -> void:
	var seen: Dictionary[StringName, StringName] = {}
	for definition: ItemContentDefinition in _items.values():
		if definition.money_id.is_empty():
			continue
		var origin: String = _origins[definition.item_definition_id]
		if not ContentCatalog.MONEY_DENOMINATIONS.has(definition.money_id):
			_errors.append("%s.money.money_id: unsupported money '%s'" % [
				origin, definition.money_id,
			])
		elif seen.has(definition.money_id):
			_errors.append("%s.money.money_id: '%s' is already %s" % [
				origin, definition.money_id, seen[definition.money_id],
			])
		seen[definition.money_id] = definition.item_definition_id
	# feature/finance.c pays in gold, silver and coin; all three must exist.
	for money_id: StringName in ContentCatalog.MONEY_DENOMINATIONS:
		if not seen.has(money_id):
			_errors.append("items: no money item with money_id '%s'" % money_id)


func _check_npc_loadouts() -> void:
	for definition: NpcDefinition in _npcs.values():
		var origin: String = _origins[definition.definition_id]
		var entries: Array[NpcLoadoutEntry] = []
		for authored: NpcLoadoutEntry in definition.loadout_entries():
			entries.append_array(authored.possible_entries())
		for index: int in range(entries.size()):
			var entry: NpcLoadoutEntry = entries[index]
			var path: String = "%s.carry[%d]" % [origin, index]
			var item: ItemContentDefinition = _items.get(entry.item_definition_id)
			if item == null:
				_errors.append("%s.item: unknown item '%s'" % [path, entry.item_definition_id])
			elif not item.contains.is_empty():
				_errors.append("%s.item: '%s' is made holding things; an NPC's carried one is not yet" % [path, entry.item_definition_id])
			elif (
				entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY
				and item.weapon_definition() == null
			):
				_errors.append("%s.equip: '%s' is not a weapon" % [path, entry.item_definition_id])
			elif (
				entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WEAR
				and item.armor_definition() == null
			):
				_errors.append("%s.equip: '%s' is not armor" % [path, entry.item_definition_id])


## A vendor NPC's goods exist; a family an NPC heads or rules test is defined.
## A constable's beat: known zones on one map, each next to the one before (a room's exit
## between them); its court a known zone.
func _check_patrol(origin: String, patrol: NpcPatrol) -> void:
	var map_id: StringName = &""
	for index: int in range(patrol.route.size()):
		var zone: ZoneDefinition = _zones.get(patrol.route[index])
		if zone == null:
			_errors.append("%s.patrol.route: unknown zone '%s'" % [origin, patrol.route[index]])
			return
		if map_id.is_empty():
			map_id = zone.map_id
		elif zone.map_id != map_id:
			_errors.append("%s.patrol.route: '%s' is not on %s" % [origin, zone.zone_id, map_id])
		if index > 0 and not _rooms_lead_between(_zones[patrol.route[index - 1]], zone):
			_errors.append("%s.patrol.route: no exit between '%s' and '%s'" % [origin, patrol.route[index - 1], zone.zone_id])
	if not _zones.has(patrol.arrest.court_zone_id):
		_errors.append("%s.patrol.arrest.court: unknown zone '%s'" % [origin, patrol.arrest.court_zone_id])


func _rooms_lead_between(a: ZoneDefinition, b: ZoneDefinition) -> bool:
	for pair: Array in [[a, b], [b, a]]:
		var to_rooms: Array[StringName] = (pair[1] as ZoneDefinition).room_ids()
		for room_id: StringName in (pair[0] as ZoneDefinition).room_ids():
			var room: RoomDefinition = _rooms.get(room_id)
			if room != null and room.exits().values().any(func(target: StringName) -> bool: return to_rooms.has(target)):
				return true
	return false


func _resolve_npc_dealings() -> void:
	for definition: NpcDefinition in _npcs.values():
		var origin: String = _origins[definition.definition_id]
		var vendor_id: StringName = definition.dealings().vendor_id
		if not vendor_id.is_empty() and not _vendors.has(vendor_id):
			_errors.append("%s.vendor: unknown vendor '%s'" % [origin, vendor_id])
		for rule: NpcObjectRule in definition.dealings().object_rules:
			if not rule.giver_family.is_empty() and not _families.has(rule.giver_family):
				_errors.append("%s.accept_object: unknown family '%s'" % [origin, rule.giver_family])
			if not rule.item_name.is_empty() and not _items.values().any(func(item: ItemContentDefinition) -> bool: return item.display_name == rule.item_name):
				_errors.append("%s.accept_object: no item named '%s'" % [origin, rule.item_name])
			if not rule.gives.is_empty() and not _items.has(rule.gives):
				_errors.append("%s.accept_object.gives: unknown item '%s'" % [origin, rule.gives])
			if rule.gives_master and not _items.has(ItemContentDefinition.master_id(rule.gives)):
				_errors.append("%s.accept_object.gives_master: '%s' records no master" % [origin, rule.gives])
			for topic: String in rule.forgets:
				if not definition.talk().inquiry_topics().has(topic):
					_errors.append("%s.accept_object.forgets: no inquiry '%s'" % [origin, topic])
			if not rule.move_zone_id.is_empty() and not _zones.has(rule.move_zone_id):
				_errors.append("%s.accept_object.move: unknown zone '%s'" % [origin, rule.move_zone_id])
			if rule.make != null and (rule.make.gives.is_empty() or not _items.has(rule.make.gives)):
				_errors.append("%s.accept_object.make: unknown item '%s'" % [origin, rule.make.gives])
			if not rule.item_alias.is_empty() and not _answers_to(rule.item_alias):
				_errors.append("%s.accept_object: no item answers to '%s'" % [origin, rule.item_alias])
		var patrol: NpcPatrol = definition.dealings().patrol
		if patrol != null:
			_check_patrol(origin, patrol)
		var sentence: NpcSentence = definition.dealings().sentence
		if sentence != null and not _zones.has(sentence.out_zone_id):
			_errors.append("%s.sentence.out: unknown zone '%s'" % [origin, sentence.out_zone_id])
		var settle: NpcSettle = definition.dealings().settle
		if settle != null and (not _items.has(settle.item_id) or _items[settle.item_id].value <= 0):
			_errors.append("%s.settle.item: '%s' is no item with a value" % [origin, settle.item_id])
		var hooks: NpcHooks = definition.hooks()
		if hooks != null and not hooks.die_item_id.is_empty():
			if not _items.has(hooks.die_item_id):
				_errors.append("%s.die_carries: unknown item '%s'" % [origin, hooks.die_item_id])
			elif hooks.die_item_master and not _items.has(ItemContentDefinition.master_id(hooks.die_item_id)):
				_errors.append("%s.die_carries: '%s' records no master" % [origin, hooks.die_item_id])
		if hooks != null:
			for index: int in hooks.calls.size():
				_check_act(hooks.calls[index].act, "%s.calls[%d]" % [origin, index], true, false, definition)
				if hooks.calls[index].act.moves_player():
					_errors.append("%s.calls[%d]: a call_out moves nobody" % [origin, index])
		var talk: NpcTalk = definition.talk()
		for topic: String in talk.inquiry_topics():
			for inquiry_rule: NpcInquiryRule in talk.inquiry_rules(topic):
				if not inquiry_rule.gives.is_empty() and not _items.has(inquiry_rule.gives):
					_errors.append("%s.inquiry.%s.gives: unknown item '%s'" % [origin, topic, inquiry_rule.gives])
				for forgotten: String in inquiry_rule.forgets:
					if not talk.inquiry_topics().has(forgotten):
						_errors.append("%s.inquiry.%s.forgets: no inquiry '%s'" % [origin, topic, forgotten])
				if inquiry_rule.make != null and not inquiry_rule.make.gives.is_empty() and not _items.has(inquiry_rule.make.gives):
					_errors.append("%s.inquiry.%s.make: unknown item '%s'" % [origin, topic, inquiry_rule.make.gives])
				if not inquiry_rule.hands_over.is_empty() and not _items.has(inquiry_rule.hands_over):
					_errors.append("%s.inquiry.%s.hands_over: unknown item '%s'" % [origin, topic, inquiry_rule.hands_over])
		for act: ScriptedAct in talk.greeting_choices():
			# A greeting draws its rolls from the NPCs' stream (WorldMapNpcLife._greet()).
			_check_act(act, "%s.greeting" % origin, true, true, definition)
		var teaching: NpcTeaching = definition.teaching()
		if teaching == null:
			continue
		if teaching.has_family():
			var family_id: StringName = &""
			for family: FamilyDefinition in _families.values():
				if family.display_name == teaching.family_name:
					family_id = family.family_id
			if family_id.is_empty():
				_errors.append("%s.family.name: no family named '%s' (families.json)" % [origin, teaching.family_name])
			teaching.family_id = family_id
		for rule: NpcTeaching.RecognizeRule in teaching.recognize_rules:
			if not rule.family_id.is_empty() and not _families.has(rule.family_id):
				_errors.append("%s.recognize_apprentice: unknown family '%s'" % [origin, rule.family_id])


func _check_spawns() -> void:
	var point_owners: Dictionary[StringName, StringName] = {}
	# A draw group is the spawns one room's reset() draws from: one zone, one room, two or more.
	var group_first: Dictionary[StringName, NpcSpawnDefinition] = {}
	var group_size: Dictionary[StringName, int] = {}
	for definition: NpcSpawnDefinition in _spawns.values():
		if not definition.drawn:
			continue
		var first: NpcSpawnDefinition = group_first.get(definition.draw_group, definition)
		group_first[definition.draw_group] = first
		group_size[definition.draw_group] = group_size.get(definition.draw_group, 0) + 1
		if first.zone_id != definition.zone_id or first.legacy_source_room_path != definition.legacy_source_room_path:
			_errors.append("%s.draw: '%s' spans more than one zone or room" % [_origins[definition.spawn_id], definition.draw_group])
	for group: StringName in group_size:
		if group_size[group] < 2:
			_errors.append("%s.draw: '%s' has nothing to draw from" % [_origins[group_first[group].spawn_id], group])
	for definition: NpcSpawnDefinition in _spawns.values():
		var origin: String = _origins[definition.spawn_id]
		if not _npcs.has(definition.npc_definition_id):
			_errors.append("%s.npc: unknown NPC '%s'" % [origin, definition.npc_definition_id])
		elif _npcs[definition.npc_definition_id].conjuring() != null:
			# Its create() reads who practised, and a save keeps none standing (NpcConjuring).
			_errors.append("%s.npc: '%s' is only conjured by a practice" % [origin, definition.npc_definition_id])
		for point_id: StringName in definition.spawn_point_ids():
			if point_owners.has(point_id):
				_errors.append("%s.points: '%s' is already used by %s" % [
					origin, point_id, point_owners[point_id],
				])
			if String(point_id).begins_with(SummonedNpc.PREFIX):
				_errors.append("%s.points: '%s' is named as a summoned NPC's" % [origin, point_id])
			point_owners[point_id] = definition.spawn_id
	for definition: ItemSpawnDefinition in _item_spawns.values():
		var origin: String = _origins[definition.spawn_id]
		var item: ItemContentDefinition = _items.get(definition.item_definition_id)
		if item == null:
			_errors.append("%s.item: unknown item '%s'" % [origin, definition.item_definition_id])
		elif not item.contains.is_empty():
			_errors.append("%s.item: '%s' is made holding things; one lying in a room is not yet" % [origin, definition.item_definition_id])
		for point_id: StringName in definition.spawn_point_ids():
			if point_owners.has(point_id):
				_errors.append("%s.points: '%s' is already used by %s" % [
					origin, point_id, point_owners[point_id],
				])
			point_owners[point_id] = definition.spawn_id


func _check_vendors() -> void:
	for definition: VendorDefinition in _vendors.values():
		var origin: String = _origins[definition.vendor_id]
		for key: String in definition.goods_keys():
			var item_id: StringName = definition.item_definition_id(key)
			if not _items.has(item_id):
				_errors.append("%s.goods.%s: unknown item '%s'" % [origin, key, item_id])
			elif not _items[item_id].contains.is_empty():
				_errors.append("%s.goods.%s: '%s' is made holding things; a bought one is not yet" % [origin, key, item_id])


func _check_maps() -> void:
	for definition: MapDefinition in _maps.values():
		if not _regions.has(definition.region_id):
			_errors.append("%s.region: unknown region '%s'" % [
				_origins[definition.map_id], definition.region_id,
			])


## Each room belongs to at most one zone; the zone takes its text from its
## first room.
func _resolve_zones() -> void:
	var room_owners: Dictionary[StringName, StringName] = {}
	for zone_id: StringName in _zones.keys():
		var definition: ZoneDefinition = _zones[zone_id]
		var origin: String = _origins[zone_id]
		if not _maps.has(definition.map_id):
			_errors.append("%s.map: unknown map '%s'" % [origin, definition.map_id])
		for room_id: StringName in definition.room_ids():
			if not _rooms.has(room_id):
				_errors.append("%s.rooms: unknown room '%s'" % [origin, room_id])
			elif room_owners.has(room_id):
				_errors.append("%s.rooms: '%s' is already in %s" % [origin, room_id, room_owners[room_id]])
			room_owners[room_id] = zone_id
		for link_id: StringName in definition.link_ids():
			var linked: ZoneDefinition = _zones.get(link_id)
			if linked == null or linked.map_id != definition.map_id or link_id == zone_id:
				_errors.append("%s.links: '%s' is not another zone of %s" % [origin, link_id, definition.map_id])
		var room_ids: Array[StringName] = definition.room_ids()
		if not room_ids.is_empty() and _rooms.has(room_ids[0]):
			_zones[zone_id] = definition.with_primary_room(_rooms[room_ids[0]])


func _resolve_portals() -> void:
	for portal_id: StringName in _portals.keys():
		var definition: PortalDefinition = _portals[portal_id]
		var origin: String = _origins[portal_id]
		var source: ZoneDefinition = _zones.get(definition.source_zone_id)
		var destination: ZoneDefinition = _zones.get(definition.destination_zone_id)
		if source == null:
			_errors.append("%s.from_zone: unknown zone '%s'" % [origin, definition.source_zone_id])
		if destination == null:
			_errors.append("%s.to_zone: unknown zone '%s'" % [origin, definition.destination_zone_id])
		if not _rooms.has(definition.legacy_room_id):
			_errors.append("%s.legacy_room: unknown room '%s'" % [origin, definition.legacy_room_id])
		if source != null and destination != null:
			_portals[portal_id] = definition.with_maps(source.map_id, destination.map_id)


func _check_spawn_locations() -> void:
	var places: Array[Array] = []
	for definition: NpcSpawnDefinition in _spawns.values():
		places.append([definition.spawn_id, definition.map_id, definition.zone_id])
	for definition: ItemSpawnDefinition in _item_spawns.values():
		places.append([definition.spawn_id, definition.map_id, definition.zone_id])
	for place: Array in places:
		var origin: String = _origins[place[0]]
		var zone: ZoneDefinition = _zones.get(place[2])
		if not _maps.has(place[1]):
			_errors.append("%s.map: unknown map '%s'" % [origin, place[1]])
		elif zone == null or zone.map_id != place[1]:
			_errors.append("%s.zone: '%s' is not a zone of %s" % [origin, place[2], place[1]])


func _resolve_services() -> void:
	for service_id: StringName in _services.keys():
		var definition: ServiceDefinition = _services[service_id]
		var origin: String = _origins[service_id]
		var zone: ZoneDefinition = _zones.get(definition.zone_id)
		if zone == null:
			_errors.append("%s.zone: unknown zone '%s'" % [origin, definition.zone_id])
			continue
		_services[service_id] = definition.with_map(zone.map_id)
		if definition.act != null:
			for act: ScriptedAct in definition.act.acts:
				_check_act(act, "%s.act" % origin, false, true)
			var stronger: StringName = definition.act.stronger_npc_id
			if not stronger.is_empty() and (not _npcs.has(stronger) or not _zones.has(definition.act.stronger_zone_id)):
				_errors.append("%s.act.stronger: unknown NPC '%s' or zone '%s'" % [origin, stronger, definition.act.stronger_zone_id])
		if definition.dance == null:
			continue
		# A dance moves the dancer through a portal leaving the dance floor's room.
		for step: DanceDefinition.Step in definition.dance.steps:
			var portal: PortalDefinition = _portals.get(step.portal_id)
			if portal == null:
				_errors.append("%s.dance: unknown portal '%s'" % [origin, step.portal_id])
			elif portal.source_zone_id != definition.zone_id:
				_errors.append("%s.dance: portal '%s' does not leave %s" % [origin, step.portal_id, definition.zone_id])


## A carried item's own command (bracelet.c pray) names what exists; what study.c teaches
## from an item is a skill the game has; what a container is made holding exists and fits.
func _check_item_acts() -> void:
	for item: ItemContentDefinition in _items.values():
		var origin: String = _origins.get(item.item_definition_id, String(item.item_definition_id))
		var held_weight: int = 0
		for held_id: StringName in item.contains:
			var held: ItemContentDefinition = _items.get(held_id)
			if held == null or held_id == item.item_definition_id:
				_errors.append("%s.contains: unknown item '%s'" % [origin, held_id])
			elif not held.contains.is_empty():
				_errors.append("%s.contains: '%s' holds things itself" % [origin, held_id])
			else:
				held_weight += held.own_weight
		if held_weight > item.max_encumbrance and not item.contains.is_empty():
			_errors.append("%s.contains: more than it holds (%d > %d)" % [origin, held_weight, item.max_encumbrance])
		if item.act != null:
			for act: ScriptedAct in item.act.acts:
				_check_act(act, "%s.act" % origin)
			if not item.act.stronger_npc_id.is_empty():
				_errors.append("%s.act.stronger: only a room's command asks so" % origin)
		# A catalog built without skills (a test's partial one) has none to check against.
		if item.study != null and not _skills.is_empty() and not _skills.has(item.study.skill_id):
			_errors.append("%s.study: unknown skill '%s'" % [origin, item.study.skill_id])


## Some item answers to `alias` (id()).
func _answers_to(alias: String) -> bool:
	return _items.values().any(func(item: ItemContentDefinition) -> bool: return item.aliases().has(alias))


func _resolve_doors() -> void:
	for door_id: StringName in _doors.keys():
		var definition: DoorDefinition = _doors[door_id]
		var origin: String = _origins[door_id]
		var maps: Dictionary[StringName, bool] = {}
		# Its first zone's map first.
		var ids: Array[StringName] = []
		for zone_id: StringName in definition.zone_ids():
			var zone: ZoneDefinition = _zones.get(zone_id)
			if zone == null:
				_errors.append("%s.zones: unknown zone '%s'" % [origin, zone_id])
			else:
				maps[zone.map_id] = true
				if not ids.has(zone.map_id):
					ids.append(zone.map_id)
		if not _rooms.has(definition.legacy_room_id):
			_errors.append("%s.legacy_room: unknown room '%s'" % [origin, definition.legacy_room_id])
		if not definition.found_by.is_empty() and not _mark_found_by_landmark(definition.found_by):
			_errors.append("%s.found_by: no find_way landmark gives the mark '%s'" % [origin, definition.found_by])
		if maps.size() > 1 and not _portal_joins(definition.zone_ids()):
			_errors.append("%s.zones: a door's zones share one map or a portal joins them" % origin)
		elif not maps.is_empty():
			_doors[door_id] = definition.with_maps(ids)


## A find_way landmark gives `mark` (a door's found_by has a clue that finds it).
func _mark_found_by_landmark(mark: String) -> bool:
	for landmark: WorldLandmarkDefinition in _landmarks.values():
		if landmark.policy == &"find_way" and landmark.mark == mark:
			return true
	return false


## A portal leads from one of the two zones into the other (a building's door).
func _portal_joins(zone_ids: Array[StringName]) -> bool:
	for portal: PortalDefinition in _portals.values():
		if zone_ids.has(portal.source_zone_id) and zone_ids.has(portal.destination_zone_id) and portal.source_zone_id != portal.destination_zone_id:
			return true
	return false


## A hazard's room is its zone's, one hazard a zone; its act acts on the player alone.
func _check_hazards() -> void:
	var zones_taken: Dictionary[StringName, bool] = {}
	for hazard_id: StringName in _hazards.keys():
		var hazard: RoomHazardDefinition = _hazards[hazard_id]
		var origin: String = _origins[hazard_id]
		var zone: ZoneDefinition = _zones.get(hazard.zone_id)
		if zone == null:
			_errors.append("%s.zone: unknown zone '%s'" % [origin, hazard.zone_id])
		elif not zone.room_ids().has(hazard.room_id):
			_errors.append("%s.room: '%s' is not a room of %s" % [origin, hazard.room_id, hazard.zone_id])
		elif zones_taken.has(hazard.zone_id):
			_errors.append("%s.zone: %s has a hazard already" % [origin, hazard.zone_id])
		zones_taken[hazard.zone_id] = true
		if hazard.act != null:
			if hazard.act.moves_player():
				_errors.append("%s.act: a hazard does not move the player" % origin)
			if not hazard.act.applies_to(&"", &"") or hazard.act.draws() or not hazard.act.ask.is_empty():
				_errors.append("%s.act: a hazard acts on whoever stands there (no conditions, rolls or question)" % origin)
			if hazard.act.steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.COMES):
				_errors.append("%s.act: a hazard brings no NPC" % origin)
			_check_act(hazard.act, "%s.act" % origin)


## A trap shuts a door a rule alone operates, between the zone it is left from
## and the one outside; what it calls in is a summoned spawn of that zone.
func _check_traps() -> void:
	for trap_id: StringName in _traps.keys():
		var trap: RoomTrapDefinition = _traps[trap_id]
		var origin: String = _origins[trap_id]
		var door: DoorDefinition = _doors.get(trap.door_id)
		if door == null:
			_errors.append("%s.door: unknown door '%s'" % [origin, trap.door_id])
		elif door.operable or not door.starts_open or not door.zone_ids().has(trap.from_zone_id):
			_errors.append("%s.door: '%s' must start open, be a rule's (operable false) and border %s" % [origin, trap.door_id, trap.from_zone_id])
		for zone_id: StringName in [trap.from_zone_id, trap.to_zone_id]:
			if not _zones.has(zone_id):
				_errors.append("%s: unknown zone '%s'" % [origin, zone_id])
		if not _rooms.has(trap.room_id):
			_errors.append("%s.room: unknown room '%s'" % [origin, trap.room_id])
		if not trap.summon_spawn_id.is_empty():
			var spawn: NpcSpawnDefinition = _spawns.get(trap.summon_spawn_id)
			if spawn == null or not spawn.summoned or spawn.zone_id != trap.from_zone_id:
				_errors.append("%s.summon: '%s' must be a summoned spawn of %s" % [origin, trap.summon_spawn_id, trap.from_zone_id])


## An exit rule refuses a way between two zones a room exit joins, in a room of the
## first: a walk on one map, or a portal between them; `present` and `npc` are NPCs that exist.
func _check_exit_rules() -> void:
	for rule_id: StringName in _exit_rules.keys():
		var rule: ZoneExitRuleDefinition = _exit_rules[rule_id]
		var origin: String = _origins[rule_id]
		for zone_id: StringName in [rule.from_zone_id, rule.to_zone_id]:
			if not _zones.has(zone_id):
				_errors.append("%s: unknown zone '%s'" % [origin, zone_id])
		var from_zone: ZoneDefinition = _zones.get(rule.from_zone_id)
		var to_zone: ZoneDefinition = _zones.get(rule.to_zone_id)
		if from_zone != null and not from_zone.room_ids().has(rule.room_id):
			_errors.append("%s.room: '%s' is not a room of %s" % [origin, rule.room_id, rule.from_zone_id])
		# The rule is checked where the player walks from one zone into the next on a map,
		# or takes a passage between them.
		var portal_between: bool = false
		for portal: PortalDefinition in _portals.values():
			portal_between = portal_between or (portal.source_zone_id == rule.from_zone_id and portal.destination_zone_id == rule.to_zone_id)
		if from_zone != null and to_zone != null and from_zone.map_id != to_zone.map_id and not portal_between:
			_errors.append("%s: %s and %s are not on one map and no portal joins them" % [origin, rule.from_zone_id, rule.to_zone_id])
		# The question puts the player inside by a move, which a passage's own bookkeeping
		# (its mark, its arrival) would miss: it guards a walk on one map only.
		if (rule.asks or rule.counts_tries) and (portal_between or (from_zone != null and to_zone != null and from_zone.map_id != to_zone.map_id)):
			_errors.append("%s: an ask or tries rule guards a walk between two zones of one map, not a passage" % origin)
		if (rule.condition in [ZoneExitRuleDefinition.Condition.WEAPON_IN_HAND, ZoneExitRuleDefinition.Condition.HELD] or not rule.present_npc_id.is_empty()) and not _npcs.has(rule.present_npc_id):
			_errors.append("%s.present: unknown NPC '%s'" % [origin, rule.present_npc_id])
		for npc_id: StringName in rule.present_npc_ids:
			if not _npcs.has(npc_id):
				_errors.append("%s.present: unknown NPC '%s'" % [origin, npc_id])
		if rule.condition == ZoneExitRuleDefinition.Condition.NOT_APPRENTICE_OF and not _npcs.has(rule.npc_id):
			_errors.append("%s.npc: unknown NPC '%s'" % [origin, rule.npc_id])
		if rule.condition == ZoneExitRuleDefinition.Condition.NOT_FAMILY and not _families.has(rule.family_id):
			_errors.append("%s.family: unknown family '%s'" % [origin, rule.family_id])
		if rule.condition == ZoneExitRuleDefinition.Condition.TAKES_BACK and rule.item_ids.is_empty() and not _items.has(rule.item_id):
			_errors.append("%s.item: unknown item '%s'" % [origin, rule.item_id])
		for item_id: StringName in rule.item_ids:
			if not _items.has(item_id):
				_errors.append("%s.items: unknown item '%s'" % [origin, item_id])


## What a ScriptedAct names exists: the item it gives, the zone it moves the player to,
## the condition it applies, an item that answers to what it `carries`, the NPC it asks
## to be `present`, the item it asks `exists`. Only an NPC's
## greeting (`by_npc`) closes doors, attacks or gains force; a move to another map ends an
## act, so it is its last step. A mood it puts on is one of the NPC's (`npc`), the item an NPC
## wields an item and the NPC that leaves with it an NPC. (Spawn points are the scene's: the
## map checks them.)
func _check_act(act: ScriptedAct, origin: String, by_npc: bool = false, drawn: bool = false, npc: NpcDefinition = null) -> void:
	if act.draws() and not drawn:
		# Only a room's command (ActService) and a greeting draw for their branch; elsewhere the rolls would never be made.
		_errors.append("%s.kar_above: only a room's command or a greeting rolls" % origin)
	if not act.carries.is_empty() and not _answers_to(act.carries):
		_errors.append("%s.carries: no item answers to '%s'" % [origin, act.carries])
	if not act.exists.is_empty() and not _items.has(act.exists):
		_errors.append("%s.exists: unknown item '%s'" % [origin, act.exists])
	if not act.present.is_empty() and not _npcs.has(act.present):
		_errors.append("%s.present: unknown NPC '%s'" % [origin, act.present])
	if not act.npc_in.is_empty() and (not by_npc or not _zones.has(act.npc_in)):
		_errors.append("%s.npc_in: an NPC's own act, in a known zone ('%s')" % [origin, act.npc_in])
	if not act.present_in_npc.is_empty() and (not _npcs.has(act.present_in_npc) or not _zones.has(act.present_in_zone)):
		_errors.append("%s.present_in: unknown NPC '%s' or zone '%s'" % [origin, act.present_in_npc, act.present_in_zone])
	if act.draws() and not act.ask.is_empty():
		# The branch is drawn for when the command runs, after any question (ActService).
		_errors.append("%s: a branch that rolls asks nothing of its own" % origin)
	var acting: bool = by_npc
	for index: int in act.steps.size():
		var step: ScriptedAct.Step = act.steps[index]
		if not acting and step.kind in [ScriptedAct.Kind.CLOSE_DOOR, ScriptedAct.Kind.KILL, ScriptedAct.Kind.NPC_FORCE, ScriptedAct.Kind.NPC_FLAG, ScriptedAct.Kind.NPC_MOOD, ScriptedAct.Kind.NPC_WIELD, ScriptedAct.Kind.LEAVE]:
			_errors.append("%s: step %d needs the NPC of a greeting or one that came" % [origin, index])
		if step.kind == ScriptedAct.Kind.COMES:
			acting = true
			_called_over[step.npc_id] = true
			if not _npcs.has(step.npc_id) or not _zones.has(step.zone_id):
				_errors.append("%s.comes: unknown NPC '%s' or zone '%s'" % [origin, step.npc_id, step.zone_id])
		if step.kind == ScriptedAct.Kind.REINCARNATE and index != act.steps.size() - 1:
			_errors.append("%s: reincarnate is the act's last step" % origin)
		if step.kind == ScriptedAct.Kind.MOVE and index != act.steps.size() - 1 and _zones.has(step.zone_id) and not by_npc:
			# A greeting's move stays on its NPC's map (WorldMapActs); a room's or an item's may
			# leave it, and nothing after it would happen there.
			_errors.append("%s: a move is the act's last step" % origin)
		match step.kind:
			ScriptedAct.Kind.GIVE:
				var given: Array[StringName] = step.pick.duplicate()
				if given.is_empty():
					given.append(step.item_id)
				for item_id: StringName in given:
					if not _items.has(item_id):
						_errors.append("%s.give: unknown item '%s'" % [origin, item_id])
			ScriptedAct.Kind.MOVE:
				if not _zones.has(step.zone_id):
					_errors.append("%s.move: unknown zone '%s'" % [origin, step.zone_id])
			ScriptedAct.Kind.NPC_MOOD:
				if npc == null or npc.hooks() == null or not npc.hooks().moods.has(step.flag):
					_errors.append("%s.npc_mood: '%s' is no mood of the NPC's" % [origin, step.flag])
			ScriptedAct.Kind.NPC_WIELD:
				if not _items.has(step.item_id) or _items[step.item_id].weapon_definition() == null:
					_errors.append("%s.npc_wield: '%s' is no weapon" % [origin, step.item_id])
			ScriptedAct.Kind.LEAVE:
				if not step.npc_id.is_empty() and not _npcs.has(step.npc_id):
					_errors.append("%s.leave: unknown NPC '%s'" % [origin, step.npc_id])
			ScriptedAct.Kind.CONDITION:
				if not ConditionIds.ALL.has(step.condition_id):
					_errors.append("%s.condition: unknown condition '%s'" % [origin, step.condition_id])


## A note_maze's enter portal leads into its zone, and each note names a way out of it: a
## portal from the zone back into it on its map (its legacy_command the way).
func _resolve_note_maze(definition: WorldLandmarkDefinition, origin: String) -> void:
	var enter: PortalDefinition = _portals.get(definition.enter_portal_id)
	if enter == null or enter.destination_zone_id != definition.zone_id:
		_errors.append("%s.enter: '%s' must be a portal into %s" % [origin, definition.enter_portal_id, definition.zone_id])
	var ways: Array[StringName] = []
	for portal: PortalDefinition in _portals.values():
		if portal.source_zone_id == definition.zone_id and portal.destination_zone_id == definition.zone_id:
			ways.append(StringName(portal.legacy_command))
	for note: WorldLandmarkDefinition.MazeNote in definition.notes:
		if not ways.has(note.way):
			_errors.append("%s.notes: no way '%s' leads out of %s" % [origin, note.way, definition.zone_id])


## A landmark's portals leave from its own zone; a hidden passage's second
## portal is the way back, from where the first leads to the landmark's zone.
func _resolve_landmarks() -> void:
	var hidden_owners: Dictionary[StringName, StringName] = {}
	for landmark_id: StringName in _landmarks.keys():
		if not _landmarks[landmark_id].is_hidden_passage:
			for portal_id: StringName in _landmarks[landmark_id].portal_ids():
				hidden_owners[portal_id] = landmark_id
	for landmark_id: StringName in _landmarks.keys():
		var definition: WorldLandmarkDefinition = _landmarks[landmark_id]
		var origin: String = _origins[landmark_id]
		var zone: ZoneDefinition = _zones.get(definition.zone_id)
		if zone == null:
			_errors.append("%s.zone: unknown zone '%s'" % [origin, definition.zone_id])
			continue
		var portal_ids: Array[StringName] = definition.portal_ids()
		for index: int in portal_ids.size():
			var portal: PortalDefinition = _portals.get(portal_ids[index])
			if portal == null:
				_errors.append("%s.portals: unknown portal '%s'" % [origin, portal_ids[index]])
			elif definition.is_hidden_passage and index == 1:
				var down: PortalDefinition = _portals.get(portal_ids[0])
				if down != null and (portal.source_zone_id != down.destination_zone_id or portal.destination_zone_id != definition.zone_id):
					_errors.append("%s.portals: '%s' does not lead from %s back to %s" % [origin, portal.portal_id, down.destination_zone_id, definition.zone_id])
			elif portal.source_zone_id != definition.zone_id:
				_errors.append("%s.portals: '%s' does not leave from %s" % [origin, portal.portal_id, definition.zone_id])
			if definition.is_hidden_passage:
				# A hidden portal is closed until its one landmark opens it; no other landmark uses it.
				if hidden_owners.has(portal_ids[index]):
					_errors.append("%s.portals: '%s' is already used by %s" % [origin, portal_ids[index], hidden_owners[portal_ids[index]]])
				hidden_owners[portal_ids[index]] = landmark_id
		for role: String in ["buried", "reward"]:
			if not definition.item(role).is_empty() and not _items.has(definition.item(role)):
				_errors.append("%s.items: unknown item '%s'" % [origin, definition.item(role)])
		if not definition.guard_npc_id.is_empty() and not _npcs.has(definition.guard_npc_id):
			_errors.append("%s.guard: unknown NPC '%s'" % [origin, definition.guard_npc_id])
		if definition.policy == &"note_maze":
			_resolve_note_maze(definition, origin)
		if definition.policy == &"dial_below":
			# It stands where the dial's way down leads, by the way back up.
			var dial: WorldLandmarkDefinition = _landmarks.get(definition.opens)
			var up: PortalDefinition = null if dial == null or dial.policy != &"dial" else _portals.get(dial.portal_ids()[1])
			if up == null or up.source_zone_id != definition.zone_id:
				_errors.append("%s.opens: '%s' must be a dial whose way up leaves from %s" % [origin, definition.opens, definition.zone_id])
		if not definition.spawn_id.is_empty():
			var spawn: NpcSpawnDefinition = _spawns.get(definition.spawn_id)
			if spawn == null or not spawn.summoned or spawn.zone_id != definition.zone_id:
				_errors.append("%s.spawn: '%s' must be a summoned spawn of %s" % [origin, definition.spawn_id, definition.zone_id])
		_landmarks[landmark_id] = definition.with_map(zone.map_id)
