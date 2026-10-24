extends RefCounted

## A2 经验节奏 (DECISIONS「经验节奏」): the 历练 rewards' rules, 落后补偿, the stage's
## potential cap and the 打坐 knob; every knob at ES2's value gives ES2's numbers.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_knobs()
	_test_rules_from_data()
	_test_catch_up_bounds()
	_test_scaled_keeps_the_rest()
	_test_potential_cap()
	_test_grant_once()
	_test_far_weaker_is_nothing()
	_test_lines()
	_test_combat_gain_with_catch_up()
	_test_exercise_gain()
	_test_quest_reward_cap()
	_test_save_round_trip()
	_test_journal_finals()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_knobs() -> void:
	var bare := PacingDefinition.new(1000)
	_assert_eq([bare.milestone_rewards, bare.catch_up_max_percent, bare.staged_potential_cap, bare.player_exercise_gain], [false, 0, false, 1], "constructed without the knobs: ES2 (classic)")
	var errors: Array[String] = []
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors))
	_assert_eq([read.milestone_rewards, read.catch_up_max_percent, read.staged_potential_cap, read.player_exercise_gain, errors], [false, 0, false, 1, []], "a record that leaves them out: ES2")
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "catch_up_max_percent": -1, "player_exercise_gain": 0}, "p", broken))
	_assert_eq(broken.size(), 2, "a negative catch-up and an exercise gain below 1 are refused: %s" % [broken])
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_assert_eq([pacing.milestone_rewards, pacing.catch_up_max_percent, pacing.staged_potential_cap, pacing.player_exercise_gain], [true, 100, true, 6], "pacing.json: the owner's A2 values")
	var copy: PacingDefinition = pacing.copy()
	_assert_eq([copy.milestone_rewards, copy.catch_up_max_percent, copy.staged_potential_cap, copy.player_exercise_gain], [true, 100, true, 6], "copy() keeps them")
	var es2: PacingDefinition = Es2Pacing.use()
	var classic: PacingDefinition = GameContent.catalog().pacing()
	_assert_eq([classic.milestone_rewards, classic.catch_up_max_percent, classic.staged_potential_cap, classic.player_exercise_gain], [false, 0, false, 1], "Es2Pacing: classic")
	Es2Pacing.restore(es2)


func _test_rules_from_data() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	_assert_true(rules != null, "progression.json is loaded")
	if rules == null:
		return
	_assert_eq([rules.stage(0).unit, rules.stage(149).unit, rules.stage(150).unit, rules.stage(999).unit, rules.stage(1000).unit], [15, 15, 40, 80, 150], "stages by combat_exp")
	_assert_eq([rules.reward_exp(ProgressionRules.Kind.SPAR, 200), rules.reward_exp(ProgressionRules.Kind.DEFEAT, 200), rules.reward_exp(ProgressionRules.Kind.CHAIN, 1000), rules.reward_exp(ProgressionRules.Kind.CHAIN, 1000, &"cloud.chess")], [40, 120, 750, 300], "a kind's percent of the stage's unit; a chain's own percent")
	_assert_true(rules.notable_npcs.has(&"snow.npc.fist_trainer") and rules.places.has(&"waterfog.swordtomb"), "notable NPCs and places")
	var errors: Array[String] = []
	ProgressionRules.from_record(ContentRecordReader.new({"stages": [{"min_exp": 5, "unit": 1, "potential_cap": 100}], "rewards": {"bogus": 1}}, "progression", errors))
	_assert_eq(errors.size(), 2, "stages must start at 0; kinds are known: %s" % [errors])
	var low: Array[String] = []
	ProgressionRules.from_record(ContentRecordReader.new({"stages": [{"min_exp": 0, "unit": 1, "potential_cap": 99}]}, "progression", low))
	_assert_eq(low.size(), 1, "a cap below combatd.c's 100 is refused")
	for stage: ProgressionRules.Stage in rules.stages:
		var largest: int = stage.unit * 500 / 100 * rules.potential_percent / 100
		_assert_true(stage.potential_cap >= largest, "stage %d: the cap holds a chain's whole potential (%d ≥ %d)" % [stage.min_exp, stage.potential_cap, largest])


func _test_catch_up_bounds() -> void:
	_assert_eq([
		ProgressionGain.catch_up_percent(0, 300, 100),
		ProgressionGain.catch_up_percent(150, 300, 100),
		ProgressionGain.catch_up_percent(299, 300, 100),
		ProgressionGain.catch_up_percent(300, 300, 100),
		ProgressionGain.catch_up_percent(5000, 300, 100),
		ProgressionGain.catch_up_percent(0, 300, 40),
		ProgressionGain.catch_up_percent(0, 0, 100),
		ProgressionGain.catch_up_percent(0, 300, 0),
		ProgressionGain.catch_up_percent(-5, 300, 100),
	], [100, 50, 0, 0, 0, 40, 0, 0, 100], "the shortfall's share, at most the knob; 0 once there, without a region or with the knob at ES2's")


func _test_scaled_keeps_the_rest() -> void:
	var progression := CharacterProgressionState.new()
	var total: int = 0
	for step: int in 100:
		total += ProgressionGain.scaled(progression, 3, 37)
	_assert_eq([total, progression.gain_carry], [411, 0], "100 gains of 3 at +37%: 411 exactly, nothing lost to rounding")
	var plain := CharacterProgressionState.new()
	_assert_eq([ProgressionGain.scaled(plain, 3, 0), ProgressionGain.scaled(plain, 1, 0), plain.gain_carry], [3, 1, 0], "0%: the gain as it is")
	var odd := CharacterProgressionState.new()
	_assert_eq([ProgressionGain.scaled(odd, 1, 50), odd.gain_carry, ProgressionGain.scaled(odd, 1, 50), odd.gain_carry], [1, 50, 2, 0], "1 at +50% twice: 1 then 2, the half carried")


func _test_potential_cap() -> void:
	var progression := CharacterProgressionState.new(0, 95, 0)
	_assert_eq([ProgressionGain.add_potential(progression, 10, 100), progression.potential], [5, 100], "combatd.c: up to 100 unspent")
	_assert_eq(ProgressionGain.add_potential(progression, 10, 100), 0, "full: nothing more")
	var over := CharacterProgressionState.new(0, 130, 0)
	_assert_eq([ProgressionGain.add_potential(over, 10, 100), over.potential], [0, 130], "above the cap: kept, not lowered (DECISIONS 3C)")
	var rules: ProgressionRules = GameContent.catalog().progression()
	_assert_eq([ProgressionGain.potential_cap(rules, 0, false), ProgressionGain.potential_cap(rules, 5000, false), ProgressionGain.potential_cap(rules, 0, true), ProgressionGain.potential_cap(rules, 1000, true), ProgressionGain.potential_cap(null, 1000, true)], [100, 100, 100, 450, 100], "staged: the stage's cap; ES2: 100")


func _test_grant_once() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	var state := CharacterState.new()
	state.progression.combat_experience = 200
	var grant: MilestoneRewards.Grant = MilestoneRewards.grant(state, rules, ProgressionRules.Kind.SPAR, &"snow.npc.trainee", 0, 120)
	_assert_true(grant != null and grant.exp_gain == 40 and grant.potential_gain == 20, "first spar won at 200: 40 exp, 20 potential")
	_assert_eq([state.progression.combat_experience, state.progression.potential, state.milestones.keys()], [240, 20, ["spar/snow.npc.trainee"]], "given and written down")
	_assert_true(MilestoneRewards.grant(state, rules, ProgressionRules.Kind.SPAR, &"snow.npc.trainee", 0, 120) == null, "the same NPC again: nothing")
	_assert_eq(state.progression.combat_experience, 240, "nothing the second time")
	var bonus: MilestoneRewards.Grant = MilestoneRewards.grant(state, rules, ProgressionRules.Kind.REGION, &"cloud", 50, 120)
	_assert_eq([bonus.exp_gain, bonus.potential_gain, bonus.catch_up_percent], [90, 45, 50], "a region at +50%: 60 → 90 exp, 45 potential")
	var empty := ProgressionRules.new()
	empty.stages.append(rules.stages[0])
	_assert_true(MilestoneRewards.grant(state, empty, ProgressionRules.Kind.BOOK, &"x", 0, 100) == null and not state.milestones.has("book/x"), "worth nothing: not given, not written")


func _test_far_weaker_is_nothing() -> void:
	_assert_false(MilestoneRewards.opponent_counts(1000, 100), "1000 against 100: far weaker, nothing")
	_assert_true(MilestoneRewards.opponent_counts(1000, 400), "1000 against 400: weaker, counts")
	_assert_true(MilestoneRewards.opponent_counts(0, 100), "a beginner against a trainee: counts")


func _test_lines() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	var state := CharacterState.new()
	state.progression.combat_experience = 1000
	state.progression.potential = 400
	var grant: MilestoneRewards.Grant = MilestoneRewards.grant(state, rules, ProgressionRules.Kind.CHAIN, &"green.jade", 20, 450)
	var lines: Array[ColoredLine] = MilestoneRewards.lines(grant, "玉佩")
	_assert_eq(ColoredLine.texts(lines), ["【历练】你了结了「玉佩」这段经历：实战经验 +900，潜能 +50。（落后补偿 +20%）", "潜能已满（最多 450 点未用），多出的 400 点没有记下。先去请教师父或研读书籍，用掉一些潜能吧。"], "the reward, its catch-up, and what the cap kept back")
	_assert_eq(lines[0].color, ColoredLine.HIY, "in yellow")


func _test_combat_gain_with_catch_up() -> void:
	var facts := CombatProgressionFacts.new(&"p", true, 20, 20, &"unarmed", true, 3).with_progression(50, 100)
	var state := CharacterState.new()
	var gained: Array[int] = []
	for hit: int in 4:
		gained.append(CombatProgressionService._gain_of(state, facts))
	_assert_eq([gained, state.progression.gain_carry], [[4, 5, 4, 5], 0], "3 at +50%: 4.5 a blow, carried")
	var es2 := CombatProgressionFacts.new(&"p", true, 20, 20, &"unarmed", true, 1)
	_assert_eq([es2.gain_percent, es2.potential_cap, CombatProgressionService._gain_of(CharacterState.new(), es2)], [0, 100, 1], "ES2: +1, cap 100")
	_assert_false(CombatProgressionFacts.new(&"p", true, 20, 20, &"unarmed", true, 1).with_progression(0, 99).is_valid(), "a cap below 100 is invalid")


func _test_exercise_gain() -> void:
	for multiplier: int in [1, 6]:
		var state := _exerciser()
		var result: CultivationResult = CultivationService.exercise(state, 30, false, 0, false, multiplier)
		# 30 * (5 + 30) / 300 = 3 force a time; ×6 = 18.
		_assert_eq(state.recovery.inner_force.current, 3 * multiplier, "打坐 30 kee, ×%d" % multiplier)
		_assert_true(result.success, "it is taken")
	var none := _exerciser()
	none.attributes.constitution = 0
	none.skills.set_raw_level(&"force", 0)
	CultivationService.exercise(none, 10, false, 0, false, 6)
	_assert_eq(none.recovery.inner_force.current, 0, "a step that gains nothing stays nothing (全身酸麻)")


func _test_quest_reward_cap() -> void:
	var state := CharacterState.new()
	state.progression.combat_experience = 5000
	state.progression.potential = 95
	var quest := QuestDefinition.new()
	quest.target = "宝官"
	quest.type = QuestDefinition.KILL
	quest.exp_bonus = 40
	quest.pot_bonus = 30
	quest.score = 4
	quest.time_seconds = 100
	state.quest.assign(quest, 10)
	var victim: NpcDefinition = GameContent.catalog().npc(&"cloud.npc.judge")
	PlayerKillerReward.apply(state, victim, func(_n: int) -> int: return 0, 900)
	_assert_eq(state.progression.potential, 110, "the stage cap (900) lets 15 + 0 potential in: 95 → 110")
	var es2 := CharacterState.new()
	es2.progression.potential = 95
	es2.quest.assign(quest.duplicate_definition(), 10)
	PlayerKillerReward.apply(es2, victim, func(_n: int) -> int: return 0)
	_assert_eq(es2.progression.potential, 100, "ES2's cap of 100")


func _test_save_round_trip() -> void:
	var plain: GameSaveResult = GameSaveJsonCodec.encode(GameSaveTestFixture.substantial())
	_assert_false(plain.text.contains("\"milestones\"") or plain.text.contains("\"gain_carry\""), "nothing written while there is none (old saves read as before)")
	var root: Dictionary = JSON.parse_string(plain.text)
	# Integers are written as canonical decimal strings.
	root["player"]["character"]["milestones"] = {"spar/snow.npc.trainee": "1", "region/cloud": "2"}
	root["player"]["character"]["progression"]["gain_carry"] = "37"
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(root, "	", false))
	_assert_true(decoded.snapshot != null, "read: %s" % decoded.detail)
	if decoded.snapshot == null:
		return
	var character: GameSaveValueTypes.CharacterStateSnapshot = decoded.snapshot.player.character
	_assert_eq([character.milestones, character.progression.gain_carry], [{"spar/snow.npc.trainee": 1, "region/cloud": 2}, 37], "the ledger and the carry read back")
	var again: GameSaveResult = GameSaveJsonCodec.encode(decoded.snapshot)
	_assert_true(again.text.contains("\"milestones\"") and again.text.contains("\"gain_carry\": \"37\""), "and written again")
	root["player"]["character"]["progression"]["gain_carry"] = "0"
	_assert_true(GameSaveJsonCodec.decode(JSON.stringify(root)).snapshot == null, "a carry of 0 is never written: refused")


func _test_journal_finals() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	var finals: int = 0
	for chain: JournalChainDefinition in GameContent.catalog().journal_chains():
		for entry: JournalEntryDefinition in chain.entries:
			if entry.final:
				finals += 1
	_assert_eq(finals, 23, "journal.json: 23 final entries over the chains that end")
	var state := CharacterState.new()
	state.journal["green.jade/jade"] = 1
	var finished: Array[JournalChainDefinition] = JournalLog.finished_chains(state, GameContent.catalog().journal_chains())
	_assert_eq(finished.map(func(c: JournalChainDefinition) -> StringName: return c.chain_id), [&"green.jade"], "the 玉佩 chain ends with the jade")
	state.journal["green.jade/elder"] = 2
	_assert_eq(JournalLog.finished_chains(state, GameContent.catalog().journal_chains()).size(), 1, "other entries change nothing")
	_assert_true(rules.chain_percent.has(&"snow.wei_wuji"), "small chains have their own percent")


func _exerciser() -> CharacterState:
	var state := CharacterState.new()
	state.attributes.constitution = 30
	state.vitality = CharacterResourceState.new(100, 100, 100)
	state.spirit = CharacterResourceState.new(100, 100, 100)
	state.essence = CharacterResourceState.new(100, 100, 100)
	state.skills.set_raw_level(&"force", 5)
	state.skills.set_raw_level(&"fonxanforce", 5)
	state.skills.map_skill(&"force", &"fonxanforce")
	state.recovery.inner_force.maximum = 40
	return state


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
