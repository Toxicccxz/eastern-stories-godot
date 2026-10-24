class_name MilestoneRewards
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): the one-time 历练 rewards. Each is
## given once, for one key in CharacterState.milestones ("<kind>/<id>": the NPC definition
## beaten, the chain ended, the book read through, the region or zone first come to), worth
## the player's stage at the time (ProgressionRules). ES2 gives none of these.

const KIND_NAMES: Dictionary[ProgressionRules.Kind, String] = {
	ProgressionRules.Kind.SPAR: "spar", ProgressionRules.Kind.DEFEAT: "defeat",
	ProgressionRules.Kind.CHAIN: "chain", ProgressionRules.Kind.BOOK: "book",
	ProgressionRules.Kind.REGION: "region", ProgressionRules.Kind.PLACE: "place",
}


class Grant:
	extends RefCounted
	var kind: ProgressionRules.Kind
	var key: String
	var exp_gain: int
	var potential_gain: int
	## Potential the cap kept back (said, not silently lost).
	var potential_cut: int
	var potential_cap: int
	## The 落后补偿 percent the gain had.
	var catch_up_percent: int


static func key_of(kind: ProgressionRules.Kind, id: StringName) -> String:
	return "%s/%s" % [KIND_NAMES[kind], id]


static func granted(state: CharacterState, kind: ProgressionRules.Kind, id: StringName) -> bool:
	return state.milestones.has(key_of(kind, id))


## Beating someone far weaker (RelativeStrength 远不如你) is worth nothing, and is not
## written down: a stronger one of that kind may still come.
static func opponent_counts(player_exp: int, opponent_exp: int) -> bool:
	return RelativeStrength.band(player_exp, opponent_exp) != RelativeStrength.Band.MUCH_WEAKER


## Gives the reward of `kind` for `id` once: the stage's exp (with `catch_up` percent more)
## and its potential share up to `potential_cap` unspent. Null when already given or
## worth nothing (the key is then not written).
@warning_ignore("integer_division")
static func grant(
	state: CharacterState, rules: ProgressionRules, kind: ProgressionRules.Kind, id: StringName,
	catch_up: int, potential_cap: int,
) -> Grant:
	if state == null or rules == null or id.is_empty():
		return null
	var key: String = key_of(kind, id)
	if state.milestones.has(key):
		return null
	var progression: CharacterProgressionState = state.progression
	var base: int = rules.reward_exp(kind, progression.combat_experience, id if kind == ProgressionRules.Kind.CHAIN else &"")
	if base <= 0:
		return null
	state.milestones[key] = state.milestones.size() + 1
	var grant := Grant.new()
	grant.kind = kind
	grant.key = key
	grant.catch_up_percent = catch_up
	grant.exp_gain = ProgressionGain.scaled(progression, base, catch_up)
	progression.combat_experience += grant.exp_gain
	var potential: int = grant.exp_gain * rules.potential_percent / 100
	grant.potential_gain = ProgressionGain.add_potential(progression, potential, potential_cap)
	grant.potential_cut = potential - grant.potential_gain
	grant.potential_cap = potential_cap
	return grant


## The log lines for `grant`: what was done (`name` of whom or what, shown language), the
## gain, the catch-up, and what the cap kept back.
static func lines(grant: Grant, name: String) -> Array[ColoredLine]:
	var result: Array[ColoredLine] = []
	if grant == null:
		return result
	var done: String
	match grant.kind:
		ProgressionRules.Kind.SPAR:
			# TRANSLATORS: native 历练 reward (A2): the first spar the player won against {name}.
			done = _t("你第一次在切磋中胜过了{name}")
		ProgressionRules.Kind.DEFEAT:
			# TRANSLATORS: native 历练 reward (A2): the first time the player beat {name}, someone of note.
			done = _t("你第一次击败了{name}")
		ProgressionRules.Kind.CHAIN:
			# TRANSLATORS: native 历练 reward (A2): the player saw the story {name} (a 任务 chain's title) through.
			done = _t("你了结了「{name}」这段经历")
		ProgressionRules.Kind.BOOK:
			# TRANSLATORS: native 历练 reward (A2): the player has read {name} through (it teaches them no more).
			done = _t("你读通了{name}")
		_:
			# TRANSLATORS: native 历练 reward (A2): the player's first time in {name} (a region or a named place).
			done = _t("你第一次来到{name}")
	var gain: String
	if grant.potential_gain > 0:
		# TRANSLATORS: native 历练 reward (A2): {done} what was done, then the gain.
		gain = _t("【历练】{done}：实战经验 +{exp}，潜能 +{pot}。")
	else:
		# TRANSLATORS: native 历练 reward (A2) with no potential added: {done} what was done, then the gain.
		gain = _t("【历练】{done}：实战经验 +{exp}。")
	gain = gain.format({"done": done.format({"name": name}), "exp": grant.exp_gain, "pot": grant.potential_gain})
	if grant.catch_up_percent > 0:
		# TRANSLATORS: native (A2) after a reward line: the catch-up bonus it had, {percent} (e.g. 40).
		gain += _t("（落后补偿 +{percent}%）").format({"percent": grant.catch_up_percent})
	result.append(ColoredLine.new(gain, ColoredLine.HIY))
	if grant.potential_cut > 0:
		result.append(ColoredLine.new(cut_line(grant.potential_cap, grant.potential_cut)))
	return result


## The cap kept `cut` potential back: said once, with what to do.
static func cut_line(cap: int, cut: int) -> String:
	# TRANSLATORS: native (A2): potential is full ({cap} unspent at most); {cut} points were not kept.
	return _t("潜能已满（最多 {cap} 点未用），多出的 {cut} 点没有记下。先去请教师父或研读书籍，用掉一些潜能吧。").format({"cap": cap, "cut": cut})


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
