class_name PlayerKillerReward
extends RefCounted

## adm/daemons/combatd.c killer_reward(killer, victim) for a player who killed an
## NPC (damage.c die() calls it on last_damage_from, a spar's death too). The
## player has no killed_enemy() of their own. MKS + 1; the task 朱鸿雪 gave is done
## when the victim's name is its target and its time has not run out; bellicosity
## + 1; the victim's vendetta_mark marks the killer (attack.c: its kind attacks on
## sight); killing one's own master (the generation above) leaves the family and,
## owner's deviation, counts as betraying it.
## Lines are tell_object()s to the player, in the shown language.


## killer_reward()'s set("title") for one who killed their master.
const REBEL_TITLE: String = "普通百姓"


class Result:
	extends RefCounted
	var lines: Array[ColoredLine] = []
	var quest_done: bool = false
	var exp_gain: int = 0
	var pot_gain: int = 0
	var score_gain: int = 0
	var left_family: bool = false


## killer_reward()'s rebel test: the player's family/master_id is `npc`'s and their
## generation the one below its own (killing it leaves the family).
static func is_own_master(state: CharacterState, npc: NpcDefinition) -> bool:
	if state == null or npc == null:
		return false
	var teaching: NpcTeaching = npc.teaching()
	var generation: int = 0 if teaching == null else teaching.family_generation
	return state.apprenticeship.master_teacher_id == npc.definition_id and state.family.generation == generation + 1


## `random` (n) -> MudOS random(n).
static func apply(state: CharacterState, victim: NpcDefinition, random: Callable) -> Result:
	var result := Result.new()
	if state == null or victim == null:
		return result
	state.progression.kills += 1
	_complete_quest(state, victim, random, result)
	# NPC got 10 times of bellicosity than user: a user killer gains bls (1).
	state.attributes.bellicosity += 1
	var mark: String = victim.dealings().vendetta_mark
	if not mark.is_empty():
		state.vendetta[mark] = state.vendetta.get(mark, 0) + 1
	_rebel(state, victim, result)
	return result


## killer_reward()'s quest part (added May 27, 1996).
@warning_ignore("integer_division")
static func _complete_quest(state: CharacterState, victim: NpcDefinition, random: Callable, result: Result) -> void:
	var quest: CharacterQuestState = state.quest
	if not quest.kill_counts() or victim.display_name != quest.current.target:
		return
	result.lines.append(ColoredLine.new(_t("恭喜你！你又完成了一项任务！")))
	var task: QuestDefinition = quest.current
	var exp_points: int = task.exp_bonus / 2 + random.call(task.exp_bonus / 2)
	var pot: int = task.pot_bonus / 2 + random.call(task.pot_bonus / 2)
	var score: int = task.score / 2 + random.call(task.score / 2)
	if quest.factor != 0:
		exp_points = exp_points * quest.factor / 10
		pot = pot * quest.factor / 10
		score = score * quest.factor / 10
	var progression: CharacterProgressionState = state.progression
	if progression.score < 0:
		score = -score
	progression.combat_experience += exp_points
	# killer_reward() caps unspent potential at 100 and so lowered it for a player
	# above 100. Deviation (owner, 3C): the cap only stops the gain.
	var before: int = progression.potential - progression.potential_spent
	var unspent: int = maxi(before, mini(before + pot, 100))
	progression.potential = unspent + progression.potential_spent
	progression.score += score
	# TRANSLATORS: combatd.c: the quest reward, numbers in Chinese numerals: {exp} combat experience, {pot} potential, {score} 综合评价 (score).
	result.lines.append(ColoredLine.new(_t("你被奖励了：\n{exp}点实战经验\n{pot}点潜能\n{score}点综合评价").format({
		"exp": ChineseNumber.of(exp_points), "pot": ChineseNumber.of(pot), "score": ChineseNumber.of(score),
	}), ColoredLine.HIW))
	quest.clear_task()
	if quest.finished > 9:
		quest.finished = 0
	elif quest.finished < -10:
		quest.finished = 1
	else:
		quest.finished += 1
	result.quest_done = true
	result.exp_gain = exp_points
	result.pot_gain = pot
	result.score_gain = score


## killer_reward()'s rebel part (added June 25, 1996): the killer's family/master_id
## is the victim's id and their generation the one below: family 0 (master and rank
## with it). The title (REBEL_TITLE) is the player's identity's: the caller sets it
## when `left_family`. Deviation (owner, 3C): ES2 lowers betrayer by one, so killing
## one's master washed out a betrayal and, once expelled, joining any family was no
## betrayal at all: a free way to change families. Here it costs what betraying
## costs (recruit.c): betrayer + 1 and score 0, and the player is told (ES2 is silent).
static func _rebel(state: CharacterState, victim: NpcDefinition, result: Result) -> void:
	if not is_own_master(state, victim):
		return
	var teaching: NpcTeaching = victim.teaching()
	state.apprenticeship.betrayer_count += 1
	state.progression.score = 0
	var family_name: String = "" if teaching == null else teaching.family_name
	# TRANSLATORS: the player killed their own master and is expelled from {family} (封山剑派).
	result.lines.append(ColoredLine.new(_t("你亲手杀了自己的师父，被逐出了{family}！").format({"family": _t(family_name)}), ColoredLine.HIR))
	# TRANSLATORS: what killing one's master costs, as betraying the family does: score 0 and the betrayals now counted ({count}).
	result.lines.append(ColoredLine.new(_t("弑师等同背叛师门：综合评价清零，背叛师门的次数变成 {count} 次。").format({"count": state.apprenticeship.betrayer_count})))
	state.apprenticeship.master_teacher_id = &""
	state.apprenticeship.legacy_master_name = ""
	state.family = FamilyState.new()
	var affiliation := CharacterAffiliationState.new()
	# family 0 takes the rank, title and entry time; the class is its own field.
	affiliation.class_id = state.affiliation.class_id
	state.affiliation = affiliation
	result.left_family = true


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
