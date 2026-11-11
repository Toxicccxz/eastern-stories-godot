class_name StoryKeeps
extends RefCounted

## Native (主线卡死点; owner 2026-11-10「只能击倒」; DECISIONS「主线卡死点」): one a story step hangs
## on (its `keeps`) is knocked down, never killed, until the step is done: the player's side holds
## its blow when they fall (no 了结), and a wound that would kill them only fells them, whoever deals
## it. A modern RPG's essential character: the story never waits on someone who is no more. Once the
## step is done — or the quest ended or was cut short, or the step waits on an option another was
## taken over — they are as anyone else. ES2 has no such people: anyone could be killed.


## Whether the NPC definition `npc_id` is kept now for the player of `state`.
static func holds(state: CharacterState, npc_id: StringName, quests: Array[StoryQuestDefinition]) -> bool:
	if state == null or npc_id.is_empty():
		return false
	for quest: StoryQuestDefinition in quests:
		if not _pending(state, quest, quests):
			continue
		for step: StoryQuestDefinition.Step in quest.steps:
			if step.keeps.has(npc_id) and _step_pending(state, quest, step):
				return true
	return false


## Neither done nor cut short, nor kept from ever starting by another one started (`excludes`).
static func _pending(state: CharacterState, quest: StoryQuestDefinition, quests: Array[StoryQuestDefinition]) -> bool:
	if StoryQuestLog.is_done(state, quest) or StoryQuestLog.is_lapsed(state, quest):
		return false
	if StoryQuestLog.is_started(state, quest):
		return true
	for other: StoryQuestDefinition in quests:
		if other == quest:
			continue
		if (quest.excludes.has(other.quest_id) or other.excludes.has(quest.quest_id)) and StoryQuestLog.is_started(state, other):
			return false
	return true


## Not done yet, and not skipped for good: a step that waits on an option (`only_after`) is
## skipped once its branch was taken another way.
static func _step_pending(state: CharacterState, quest: StoryQuestDefinition, step: StoryQuestDefinition.Step) -> bool:
	if StoryQuestLog.step_done(state, quest, step):
		return false
	if step.only_after.is_empty():
		return true
	var branch: StoryQuestDefinition.Step = quest.step_of_option(step.only_after)
	return branch == null or not StoryQuestLog.step_done(state, quest, branch) or StoryQuestLog.took(state, quest, step.only_after)
