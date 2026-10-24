extends RefCounted

## A2 经验节奏 PR B (DECISIONS「经验节奏」): the 雪亭驿 board's rules (BountyBoard on a
## BountyState) and the knobs; the classic knobs have no board and no 木人.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_knobs()
	_test_data()
	_test_fill_and_places()
	_test_one_at_a_time_and_refresh()
	_test_retier()
	_test_far_stronger_gets_none()
	_test_reward()
	_test_state_validity_and_save()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_knobs() -> void:
	var bare := PacingDefinition.new(1000)
	_assert_eq([bare.bounty_board, bare.training_dummies, bare.bounty_refresh_seconds], [false, false, 600], "without the knobs: no board, no 木人 (ES2)")
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_assert_eq([pacing.bounty_board, pacing.training_dummies, pacing.bounty_refresh_seconds], [true, true, 600], "pacing.json: the board and the 木人")
	var copy: PacingDefinition = pacing.copy()
	_assert_eq([copy.bounty_board, copy.training_dummies], [true, true], "copy() keeps them")
	var previous: PacingDefinition = Es2Pacing.use()
	_assert_false(GameContent.catalog().pacing().bounty_board or GameContent.catalog().pacing().training_dummies, "Es2Pacing: classic")
	var dummies: int = 0
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		if spawn.pacing == &"training_dummies":
			dummies += 1
	_assert_eq(dummies, 0, "classic: the 木人's spawns are left out")
	Es2Pacing.restore(previous)
	dummies = 0
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns_for_map(&"snow.school_compound"):
		if spawn.pacing == &"training_dummies":
			dummies += 1
	_assert_eq(dummies, 5, "the game's knobs: five 木人 in the 武馆")


func _test_data() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	_assert_true(rules != null and rules.postings == 3 and rules.tiers.size() == 5 and rules.places.size() == 7, "native/bounties.json: 3 postings, 5 tiers, 7 places")
	_assert_eq([rules.tier_for(0), rules.tier_for(399), rules.tier_for(400), rules.tier_for(1000), rules.tier_for(100000)], [0, 0, 1, 2, 4], "tiers by combat_exp")
	var dummy: NpcDefinition = GameContent.catalog().npc(&"native.npc.wooden_dummy.1")
	var outlaw: NpcDefinition = GameContent.catalog().npc(&"native.npc.outlaw.1")
	_assert_true(dummy.spar_only() and dummy.legacy_source_path.begins_with("native:") and outlaw.native_role() == NpcDefinition.ROLE_BOUNTY_TARGET and not outlaw.spar_only(), "native NPCs say where they come from and what they are")
	_assert_eq(GameContent.catalog().progression().reward_exp(ProgressionRules.Kind.BOUNTY, 1000), 180, "a bounty: 120% of the stage's unit")
	var errors: Array[String] = []
	BountyRules.from_record(ContentRecordReader.new({"postings": 0, "tiers": [{"min_exp": 5, "npc": "x", "silver": 1}], "places": []}, "b", errors))
	_assert_eq(errors.size(), 3, "postings below 1, tiers not from 0 and no place are refused: %s" % [errors])


func _test_fill_and_places() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	var state := BountyState.new()
	_assert_true(BountyBoard.tick(state, rules, 200, 0, _exp), "New Game: the board fills at once")
	_assert_eq([state.tiers, state.places, state.serial], [[0, 0, 0], [0, 3, 6], 3], "three of tier 0, places in turn (0, 3, 6 of 7)")
	_assert_false(BountyBoard.tick(state, rules, 200, 5000, _exp), "nothing changes while they stand")


func _test_one_at_a_time_and_refresh() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	var state := BountyState.new()
	BountyBoard.tick(state, rules, 200, 0, _exp)
	_assert_true(BountyBoard.take(state, 1), "揭榜 slot 1")
	_assert_false(BountyBoard.take(state, 0), "one at a time")
	BountyBoard.close(state, 600000)
	_assert_eq([state.active, state.tiers[1], state.refill_ms[1]], [-1, -1, 600000], "done: the slot is empty for the refresh")
	BountyBoard.tick(state, rules, 200, 599999, _exp)
	_assert_eq(state.tiers[1], -1, "not yet")
	BountyBoard.tick(state, rules, 200, 1, _exp)
	_assert_eq([state.tiers[1], state.places[1]], [0, 2], "after 600 s of play: a new one, the next place (9 % 7)")
	_assert_false(BountyBoard.take(state, 5) or BountyBoard.take(null, 0), "no such slot")


func _test_retier() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	var state := BountyState.new()
	BountyBoard.tick(state, rules, 200, 0, _exp)
	BountyBoard.take(state, 0)
	BountyBoard.tick(state, rules, 1200, 0, _exp)
	_assert_eq(state.tiers, [0, 2, 2], "grown to 1200: the postings not taken are put up anew for tier 2; the one taken stays")


func _test_far_stronger_gets_none() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	var state := BountyState.new()
	BountyBoard.tick(state, rules, 100000, 0, _exp)
	_assert_eq(state.tiers, [-1, -1, -1], "100000 against the 杀人魔头 (6500): far weaker, nothing posted")
	_assert_eq(BountyBoard.worthy_tier(rules, 25000, _exp), 4, "25000: still worth the top tier")


func _test_reward() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	var state := CharacterState.new()
	state.progression.combat_experience = 1000
	var first: MilestoneRewards.Grant = MilestoneRewards.award(state, rules, ProgressionRules.Kind.BOUNTY, 0, true)
	var second: MilestoneRewards.Grant = MilestoneRewards.award(state, rules, ProgressionRules.Kind.BOUNTY, 0, true)
	_assert_true(first != null and second != null and first.exp_gain == 180 and state.milestones.is_empty(), "a bounty is paid each time, written down nowhere")
	_assert_eq(ColoredLine.texts(MilestoneRewards.lines(first, "采花贼")), ["【历练】你完成了官府悬赏「采花贼」：实战经验 +180，潜能 +90。"], "its line")


func _test_state_validity_and_save() -> void:
	var state := BountyState.new()
	_assert_true(state.is_default() and state.is_valid(), "a new board: default, valid")
	state.fit(3)
	state.tiers[0] = 1
	state.places[0] = 4
	state.active = 0
	state.serial = 7
	_assert_true(state.is_valid(), "one taken")
	var broken: BountyState = state.duplicate_state()
	broken.places[0] = -1
	_assert_false(broken.is_valid(), "a posting without a place is invalid")
	var root: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(GameSaveTestFixture.substantial()).text)
	root["player"]["character"]["bounty"] = {"tiers": ["1", "-1", "-1"], "places": ["4", "-1", "-1"], "refill_ms": ["0", "300000", "0"], "active": "0", "serial": "7"}
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(root))
	_assert_true(decoded.snapshot != null, "a saved board reads: %s" % decoded.detail)
	if decoded.snapshot != null:
		var read: BountyState = decoded.snapshot.player.character.bounty
		_assert_eq([read.tiers, read.places, read.refill_ms, read.active, read.serial], [[1, -1, -1], [4, -1, -1], [0, 300000, 0], 0, 7], "the same board")
		_assert_true(GameSaveJsonCodec.encode(decoded.snapshot).text.contains("\"bounty\""), "written again")
	root["player"]["character"]["bounty"]["active"] = "1"
	_assert_true(GameSaveJsonCodec.decode(JSON.stringify(root)).snapshot == null, "the slot taken must hold a posting: refused")
	_assert_false(GameSaveJsonCodec.encode(GameSaveTestFixture.substantial()).text.contains("\"bounty\""), "a board never posted is not written")


func _exp(npc_id: StringName) -> int:
	return GameContent.catalog().npc(npc_id).combat_experience


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
