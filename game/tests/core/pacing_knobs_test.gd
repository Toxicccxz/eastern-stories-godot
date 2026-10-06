extends RefCounted

## The single-player pacing knobs (common/pacing.json, DECISIONS pacing knobs): a
## record without them is ES2's pace, a gain of 1 gives exactly what the ported rule
## gives, and a gain above 1 scales only what the rule yields (same draws, same gates).

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_defaults_are_es2()
	_test_production_values()
	_test_exp_gain_on_hit()
	_test_exp_gain_on_dodge_and_parry()
	_test_npc_side_keeps_es2_gain()
	_test_recovery_gain()
	_test_recovery_cadence_carries_gain()
	_test_quest_time()
	_test_toll_delay()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_defaults_are_es2() -> void:
	var bare := PacingDefinition.new(1000)
	_assert_eq([bare.player_exp_gain, bare.player_recovery_gain, bare.quest_time_percent, bare.room_reset_seconds], [1, 1, 100, 1800], "constructed without knobs: ES2")
	var errors: Array[String] = []
	var reader := ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors)
	var read: PacingDefinition = PacingDefinition.from_record(reader)
	_assert_eq([read.player_exp_gain, read.player_recovery_gain, read.quest_time_percent, errors], [1, 1, 100, []], "a record that leaves them out: ES2")
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "player_exp_gain": 0, "player_recovery_gain": -1, "quest_time_percent": 0}, "p", broken))
	_assert_eq(broken.size(), 3, "gains below 1 and a zero percent are refused: %s" % [broken])


func _test_production_values() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_assert_eq([pacing.player_exp_gain, pacing.player_recovery_gain, pacing.quest_time_percent], [3, 3, 150], "pacing.json: owner's ×3 exp, ×3 recovery, ×1.5 task time")


## combatd.c "(7) Give experience" for a player hit by an NPC, then the player hitting.
func _test_exp_gain_on_hit() -> void:
	var hit_bounds: Array = []
	for gain: int in [1, 3]:
		var defender: CharacterState = _character(1)
		var rng := ScriptedCombatRandomSource.new([0, 3, 3, 0, 0, 0, 7])
		_complete(_input(0, 1), _character(), defender, false, 1, true, gain, rng)
		_assert_eq([defender.progression.combat_experience, defender.progression.potential], [1 + gain, gain], "hit player, gain %d: exp and potential" % gain)
		hit_bounds.append(rng.requested_bounds())
	_assert_eq(hit_bounds[0], hit_bounds[1], "the same draws either way: %s" % [hit_bounds])
	var capped: CharacterState = _character(1)
	capped.progression.potential = 108
	capped.progression.potential_spent = 10
	_complete(_input(0, 1), _character(), capped, false, 1, true, 3, ScriptedCombatRandomSource.new([0, 3, 3, 0, 0, 0, 7]))
	_assert_eq([capped.progression.combat_experience, capped.progression.potential], [4, 110], "98 unspent: potential only up to 100 unspent, exp all of it")
	var full: CharacterState = _character(1)
	full.progression.potential = 110
	full.progression.potential_spent = 10
	_complete(_input(0, 1), _character(), full, false, 1, true, 3, ScriptedCombatRandomSource.new([0, 3, 3, 0, 0, 0, 7]))
	_assert_eq(full.progression.potential, 110, "100 unspent: no potential, as ES2")
	var bounds: Array = []
	for gain: int in [1, 3]:
		var attacker: CharacterState = _character(0, 20, 20, 50, 100)
		attacker.skills.set_raw_level(&"unarmed", 3)
		var rng := ScriptedCombatRandomSource.new([0, 10, 1, 0, 0, 31, 0])
		_complete(_input(0, 1, 1, 3, 0, 0, false, 10, 0), attacker, _character(1), true, gain, false, 1, rng)
		_assert_eq([attacker.progression.combat_experience, attacker.progression.potential], [gain, gain], "player lands a hit, gain %d" % gain)
		_assert_eq(attacker.skills.learned_progress(&"unarmed"), 1, "the skill still improves by one (gain %d)" % gain)
		bounds.append(rng.requested_bounds())
	_assert_eq(bounds[0], bounds[1], "a gain draws nothing more: %s" % [bounds])


func _test_exp_gain_on_dodge_and_parry() -> void:
	for gain: int in [1, 3]:
		var dodger: CharacterState = _character(1, 20, 20, 50, 100)
		dodger.attributes.intelligence_modifier = 100
		_complete(_input(0, 1), _character(0, 20, 20), dodger, false, 1, true, gain, ScriptedCombatRandomSource.new([0, 0, 51]))
		_assert_eq([dodger.progression.combat_experience, dodger.skills.learned_progress(&"dodge")], [1 + gain, 1], "dodge, gain %d: exp; dodge improves by one" % gain)
		var parrier: CharacterState = _character(1, 20, 20, 50, 100)
		_complete(_input(0, 1), _character(), parrier, false, 1, true, gain, ScriptedCombatRandomSource.new([0, 3, 0, 51]))
		_assert_eq([parrier.progression.combat_experience, parrier.skills.learned_progress(&"parry")], [1 + gain, 1], "parry, gain %d" % gain)


## The runtime gives the gain to the player's side only; an NPC's side carries 1.
func _test_npc_side_keeps_es2_gain() -> void:
	var npc: CharacterState = _character(1)
	_complete(_input(0, 1), _character(), npc, true, 3, false, 1, ScriptedCombatRandomSource.new([0, 3, 3, 0, 0, 0, 7]))
	_assert_eq([npc.progression.combat_experience, npc.progression.potential], [2, 1], "an NPC hit by the player grows at ES2's pace")
	_assert_false(CombatProgressionFacts.new(&"x", true, 20, 20, &"unarmed", true, 0).is_valid(), "a gain below 1 is not valid facts")


## damage.c heal_up(): gain times gin/kee/sen, the effective repair and atman/force/mana.
func _test_recovery_gain() -> void:
	var counts: Array[int] = []
	for gain: int in [1, 3]:
		var character: CharacterState = _character()
		character.attributes.constitution = 30
		character.vitality = CharacterResourceState.new(50, 100, 100)
		character.essence = CharacterResourceState.new(95, 98, 100)
		character.recovery.food = 10
		character.recovery.water = 10
		character.recovery.inner_force.maximum = 50
		character.recovery.inner_force.current = 20
		counts.append(CharacterRecovery.apply_tick(character, RecoverySkillLevels.new(0, 10, 0), true, false, gain))
		# kee: con/3 + force/10 = 10 + 2.
		_assert_eq(character.vitality.current, 50 + 12 * gain, "kee +12 x %d" % gain)
		_assert_eq([character.essence.current, character.essence.effective], [98, 99 if gain == 1 else 100], "gin capped at effective; effective +1 x %d up to maximum" % gain)
		_assert_eq(character.recovery.inner_force.current, 20 + 5 * gain, "force + raw force/2 x %d" % gain)
		_assert_eq([character.recovery.food, character.recovery.water], [9, 9], "food and water: one each, as ES2 (gain %d)" % gain)
	_assert_eq(counts[0], counts[1], "the update flags count the same")


func _test_recovery_cadence_carries_gain() -> void:
	var kee: Array[int] = []
	for gain: int in [1, 3]:
		var character: CharacterState = _character()
		character.attributes.constitution = 30
		character.vitality = CharacterResourceState.new(10, 100, 100)
		character.recovery.food = 10
		character.recovery.water = 10
		# The countdown starts at 5: the sixth 2 s pulse is the heal_up tick.
		var cadence := PlayerRecoveryCadence.new(Fives.new(), true, null, gain)
		cadence.advance(12.0, character, ActionBusyState.new())
		kee.append(character.vitality.current)
	_assert_eq(kee, [20, 40], "one tick: kee +10, or +30 with the player's gain 3")


## god.c's qlist time, scaled when she gives the task; the qlist entry is untouched.
func _test_quest_time() -> void:
	_assert_eq([QuestGiver.given_seconds(40, 150), QuestGiver.given_seconds(50, 150), QuestGiver.given_seconds(100, 150), QuestGiver.given_seconds(600, 150)], [60, 75, 150, 900], "40/50/100/600 s at 150%")
	_assert_eq([QuestGiver.given_seconds(40, 100), QuestGiver.given_seconds(1, 50)], [40, 1], "100% is god.c's time; never below one second")
	var quests: Array[QuestDefinition] = [QuestDefinition.new("疯狗", QuestDefinition.KILL, 40, 20, 10, 5)]
	var tier := QuestTier.new(1000, "qlist1000.c", quests)
	var tiers: Array[QuestTier] = [tier]
	for percent: int in [100, 150]:
		var state: CharacterState = _character(1001)
		var result: QuestGiver.Result = QuestGiver.give(state, tiers, func(_target: String) -> bool: return true, func(_n: int) -> int: return 0, percent)
		@warning_ignore("integer_division")
		var seconds: int = 40 * percent / 100
		_assert_eq([result.outcome, state.quest.current.time_seconds, state.quest.remaining_ms], [QuestGiver.Outcome.GIVEN, seconds, seconds * 1000], "%d%%: the task's time" % percent)
		_assert_true(result.lines[-1].text.contains(QuestStatus.period(seconds)), "she says the time she gives: " + result.lines[-1].text)
	_assert_eq(tier.quests[0].time_seconds, 40, "the qlist entry keeps god.c's 40 s")


## gangster.c init(): call_out("greeting", 1), the time to leave the room; crossing the
## native ridge takes 1.2-1.5 s, so the robbers wait 2 s (DECISIONS). Only the greeting waits.
func _test_toll_delay() -> void:
	var robber: NpcDefinition = GameContent.catalog().npc(&"cloud.npc.gangster")
	var player: CharacterState = _character()
	_assert_eq(robber.toll_attack_delay_ms({}, player), 2000, "the greeting comes two seconds after the player comes into reach")
	_assert_eq(robber.toll_attack_delay_ms({NpcDefinition.FLAG_FOUGHT_PLAYER: true}, player), 0, "once he has fought the player he attacks at once")
	var errors: Array[String] = []
	NpcDealings.from_record(ContentRecordReader.new({"toll_attack_delay_ms": 1000}, "npc", errors))
	_assert_eq(errors.size(), 1, "a delay without attack_unless_mark is refused: %s" % [errors])


class Fives:
	extends RecoveryCadenceRandomSource

	func draw_reset_tick() -> int:
		return 5


func _complete(input: CombatAttackInput, attacker: CharacterState, defender: CharacterState, attacker_is_user: bool, attacker_gain: int, defender_is_user: bool, defender_gain: int, rng: ScriptedCombatRandomSource) -> CombatOrdinaryAttackResult:
	return CombatAttackCompletionService.resolve(
		input, attacker, defender,
		CombatProgressionFacts.new(input.attacker.character_id, attacker_is_user, attacker.attributes.intelligence, attacker.attributes.spirituality, input.attacker.projected_attack_skill_type, true, attacker_gain),
		CombatProgressionFacts.new(input.defender.character_id, defender_is_user, defender.attributes.intelligence, defender.attributes.spirituality, &"unarmed", true, defender_gain),
		CombatBusyInterruptProjection.new(CombatBusyInterruptProjection.BusyKind.NOT_BUSY, CombatBusyInterruptProjection.InterruptKind.INTEGER),
		null, rng,
	)


## tests/core/combat_progression_busy_completion_test.gd's fixture input.
func _input(attacker_exp: int = 0, defender_exp: int = 1, attack_level: int = 3, dodge_level: int = 2, parry_level: int = 2, unarmed_level: int = 2, busy: bool = false, apply_damage: int = 10, base_strength: int = 6) -> CombatAttackInput:
	return CombatAttackInput.new(
		CombatAttackerSnapshot.new(
			&"attacker-1", true, attacker_exp, 0, 0, &"unarmed", attack_level, 0, apply_damage,
			CombatStrengthProjection.new(base_strength, 0, 0), false, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
			&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE, CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, null, &"force", 0,
		),
		CombatDefenderSnapshot.new(&"defender-1", true, busy, defender_exp, 0, 0, dodge_level, parry_level, unarmed_level, 0, 0, false, [&"头", &"右臂"]),
		CombatActionDefinition.new(&"ordinary-action", 0, 0, &"伤害"),
	)


func _character(combat_experience: int = 0, base_intelligence: int = 20, base_spirituality: int = 20, gin_current: int = 100, gin_maximum: int = 100) -> CharacterState:
	var character := CharacterState.new()
	character.attributes.intelligence = base_intelligence
	character.attributes.spirituality = base_spirituality
	character.essence = CharacterResourceState.new(gin_current, gin_maximum, gin_maximum)
	character.vitality = CharacterResourceState.new(100, 100, 100)
	character.spirit = CharacterResourceState.new(100, 100, 100)
	character.progression.combat_experience = combat_experience
	return character


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
