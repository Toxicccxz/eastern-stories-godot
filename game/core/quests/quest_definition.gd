class_name QuestDefinition
extends RefCounted

## One entry of a quest/qlist<level>.c list, as query_quest() returns it: whom to
## kill (quest_type 杀) or what to bring back (寻, whose accept_object() is commented
## out in god.c), the seconds given (`time`) and the exp_bonus, pot_bonus and score
## its completion rolls from (combatd.c killer_reward()). The player holds a copy
## (set("quest", quest)), so a task keeps its numbers.
const KILL: String = "杀"
const FIND: String = "寻"

var target: String
var type: String
var time_seconds: int
var exp_bonus: int
var pot_bonus: int
var score: int


func _init(p_target: String = "", p_type: String = KILL, p_time_seconds: int = 0, p_exp_bonus: int = 0, p_pot_bonus: int = 0, p_score: int = 0) -> void:
	target = p_target
	type = p_type
	time_seconds = p_time_seconds
	exp_bonus = p_exp_bonus
	pot_bonus = p_pot_bonus
	score = p_score


func duplicate_definition() -> QuestDefinition:
	return QuestDefinition.new(target, type, time_seconds, exp_bonus, pot_bonus, score)


func is_valid() -> bool:
	return not target.is_empty() and type in [KILL, FIND] and time_seconds > 0 and exp_bonus >= 0 and pot_bonus >= 0 and score >= 0


func equals(other: QuestDefinition) -> bool:
	return (
		other != null and other.target == target and other.type == type and other.time_seconds == time_seconds
		and other.exp_bonus == exp_bonus and other.pot_bonus == pot_bonus and other.score == score
	)


## {"target", "quest_type", "time", "exp_bonus", "pot_bonus", "score"}.
static func from_record(reader: ContentRecordReader) -> QuestDefinition:
	var definition := QuestDefinition.new(
		reader.required_text("target"), reader.required_text("quest_type"), reader.required_integer("time"),
		reader.required_integer("exp_bonus"), reader.required_integer("pot_bonus"), reader.required_integer("score"),
	)
	if not definition.is_valid():
		reader.fail("", "a quest needs a target, type 杀 or 寻, time above 0 and bonuses not below 0")
	reader.finish()
	return definition
