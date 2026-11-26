class_name StoryKeyTerms
extends RefCounted

## 关键信息高亮 (过场演出 A; DECISIONS「关键信息高亮」): the names a line is lit for by itself —
## whom the player's next quest steps send them to, where, and for what. They come from the quest
## data (a step's `target` and what does it), so a lit word always says what the 任务 page says,
## and no line has to be marked for it. Message IDs, as authored: KeySpans finds each in the
## shown line in the shown language.

## How far ahead of the step to do a quest's names are taken: that step and this many after it
## (a scene is often itself the step to do; what it sends the player to is the one after).
const STEPS_AHEAD: int = 1


## The names of what the steps to come lead to, for a player with `state`: every active quest's
## step to do and the STEPS_AHEAD after it, and the first step of a quest that waits on an active
## one (the chapter that begins when this one ends). Not the place the player stands in
## (`here_zone_id`) nor the people there (`present_npc_ids`, definition IDs): what is in front of
## them is not where they go next.
static func upcoming(catalog: ContentCatalog, state: CharacterState, here_zone_id: StringName = &"", present_npc_ids: Array[StringName] = []) -> Array[String]:
	var names: Array[String] = []
	if catalog == null or state == null:
		return names
	var quests: Array[StoryQuestDefinition] = catalog.story_quests()
	var steps: Array[StoryQuestDefinition.Step] = []
	var active: Dictionary[StringName, bool] = {}
	for quest: StoryQuestDefinition in quests:
		if not StoryQuestLog.is_active(state, quest):
			continue
		active[quest.quest_id] = true
		var ahead: int = -1
		for step: StoryQuestDefinition.Step in quest.steps:
			var skipped: bool = not step.only_after.is_empty() and not StoryQuestLog.took(state, quest, step.only_after)
			if ahead < 0:
				if skipped or StoryQuestLog.step_done(state, quest, step):
					continue
				ahead = 0
			elif skipped:
				continue
			if ahead > STEPS_AHEAD:
				break
			steps.append(step)
			ahead += 1
	for quest: StoryQuestDefinition in quests:
		if not quest.steps.is_empty() and not StoryQuestLog.is_started(state, quest) and quest.requires.any(func(id: StringName) -> bool: return active.has(id)):
			steps.append(quest.steps[0])
	var here: Array[String] = _place_names(catalog, here_zone_id)
	for step: StoryQuestDefinition.Step in steps:
		for target: StoryQuestDefinition.Target in [step.target, step.target_after]:
			if target == null:
				continue
			for npc_id: StringName in target.npc_ids:
				_add_npc(catalog, npc_id, present_npc_ids, names)
			if target.zone_id != here_zone_id:
				for place: String in _place_names(catalog, target.zone_id):
					if not here.has(place):
						_add(place, names)
		_add_condition(catalog, step.condition, present_npc_ids, names)
		for option: StoryQuestDefinition.Option in step.options:
			_add_condition(catalog, option.condition, present_npc_ids, names)
	return names


## A zone as people call it: its room, its place on the 地图 page, its region.
static func _place_names(catalog: ContentCatalog, zone_id: StringName) -> Array[String]:
	var names: Array[String] = []
	var zone: ZoneDefinition = null if zone_id.is_empty() else catalog.zone(zone_id)
	if zone == null:
		return names
	names.append(zone.display_name)
	var atlas: AtlasTable = catalog.atlas()
	var cell: AtlasCell = null if atlas == null else atlas.cell(zone.map_id)
	if cell == null and atlas != null:
		cell = atlas.cell(atlas.home_of(catalog, zone.map_id))
	if cell != null:
		names.append(cell.name)
	var map: MapDefinition = catalog.map(zone.map_id)
	var region: RegionDefinition = null if map == null else catalog.region(map.region_id)
	if region != null:
		names.append(region.display_name)
	return names


## What a step is done by names someone or something too: whom to ask, whom to meet, what to bring.
static func _add_condition(catalog: ContentCatalog, condition: JournalEntryDefinition, present_npc_ids: Array[StringName], names: Array[String]) -> void:
	if condition == null:
		return
	match condition.when:
		JournalEntryDefinition.When.HEARD, JournalEntryDefinition.When.SEEN, JournalEntryDefinition.When.CHAT:
			_add_npc(catalog, StringName(condition.key), present_npc_ids, names)
		JournalEntryDefinition.When.ITEM, JournalEntryDefinition.When.WEARING:
			var item: ItemContentDefinition = catalog.item(StringName(condition.key))
			if item != null:
				_add(item.display_name, names)
		JournalEntryDefinition.When.ANY, JournalEntryDefinition.When.ALL, JournalEntryDefinition.When.AT_LEAST:
			for part: JournalEntryDefinition in condition.parts:
				_add_condition(catalog, part, present_npc_ids, names)


static func _add_npc(catalog: ContentCatalog, npc_id: StringName, present_npc_ids: Array[StringName], names: Array[String]) -> void:
	if npc_id.is_empty() or present_npc_ids.has(npc_id):
		return
	var npc: NpcDefinition = catalog.npc(npc_id)
	if npc != null:
		_add(npc.display_name, names)


static func _add(name: String, names: Array[String]) -> void:
	if not name.is_empty() and not names.has(name):
		names.append(name)
