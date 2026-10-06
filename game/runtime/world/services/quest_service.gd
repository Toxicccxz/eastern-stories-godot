class_name QuestService
extends NpcService

## The `quest` command an NPC adds in its init() (u/cloud/npc/god.c, `quest_giver`):
## QuestGiver gives or renews the task; when it returns 0 (too weak, a task still
## running) the command goes on to cmds/usr/quest.c (QuestStatus). No panel: the
## lines go to the log. god.c checks neither busy nor living.
var last_outcome: QuestGiver.Outcome = QuestGiver.Outcome.NONE_AVAILABLE
var last_lines: Array[ColoredLine] = []


func verb() -> String:
	return tr("任务")


func interact() -> void:
	request_quest()


func request_quest() -> QuestGiver.Outcome:
	last_lines = []
	if not in_reach():
		return last_outcome
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = map.player_runtime().state
	var result: QuestGiver.Result = QuestGiver.give(
		state, catalog.quest_tiers(), catalog.quest_target_available,
		map.world_interaction_random_source().legacy_random, catalog.pacing().quest_time_percent,
	)
	last_outcome = result.outcome
	last_lines = result.lines.duplicate()
	if result.outcome != QuestGiver.Outcome.GIVEN:
		for line: String in QuestStatus.lines(state.quest):
			last_lines.append(ColoredLine.new(line))
	if map.session != null:
		map.session.shared_ui().append_colored_lines(last_lines)
	return last_outcome
