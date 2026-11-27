extends RefCounted

## A2 经验节奏 PR B (DECISIONS「经验节奏」): the 雪亭驿 board's rules (BountyBoard on a
## BountyState) and the knobs; the classic knobs have no board and no 木人. 成长曲线 D: the four tiers
## the story opens, the ceiling at twice, no gaps, why the board is empty.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_knobs()
	_test_data()
	_test_fill_and_places()
	_test_one_at_a_time_and_refresh()
	_test_retier()
	_test_far_stronger_gets_none()
	_test_growth_d()
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
	_assert_true(rules != null and rules.postings == 3 and rules.tiers.size() == 9 and rules.places.size() == 17, "native/bounties.json: 3 postings, 9 tiers, 7 places of the board's and 10 of the last four tiers'")
	_assert_eq([rules.tier_for(0), rules.tier_for(399), rules.tier_for(400), rules.tier_for(1000), rules.tier_for(100000)], [0, 0, 1, 2, 8], "tiers by combat_exp")
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


## A2's rule without the ceiling knob (远不如你, four times), on A2's five tiers.
func _test_far_stronger_gets_none() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	var state := BountyState.new()
	var a2: Callable = func(tier: int) -> bool: return tier < 5
	BountyBoard.tick(state, rules, 100000, 0, _exp, a2)
	_assert_eq(state.tiers, [-1, -1, -1], "100000 against the 杀人魔头 (5500): far weaker, nothing posted")
	_assert_eq([BountyBoard.worthy_tier(rules, 20000, _exp, a2), BountyBoard.worthy_tier(rules, 22000, _exp, a2)], [4, -1], "20000: still worth the top tier; 22000 (four times and more): none")


## 成长曲线 D (DECISIONS「成长曲线 D」): four tiers after the fifth, seventh and ninth chapters and
## the finale, found in those chapters' regions; an outlaw is outgrown at twice its exp; a player
## past the highest tier they reached is offered the next one the story has opened; the empty
## board says why.
func _test_growth_d() -> void:
	var rules: BountyRules = GameContent.catalog().bounties()
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_assert_eq([pacing.bounty_ceiling_percent, PacingDefinition.new(1000).bounty_ceiling_percent, pacing.copy().bounty_ceiling_percent], [200, 0, 200], "pacing.json: the ceiling at twice; none without the knob (远不如你); copy() keeps it")
	var chapters: Array[String] = ["main.chapter5#done", "main.chapter7#done", "main.chapter9#done", "main.finale#done"]
	var regions: Array[StringName] = [&"choyin_east", &"fanfang", &"city", &"village"]
	for index: int in 4:
		var tier: BountyRules.Tier = rules.tiers[5 + index]
		var outlaw: NpcDefinition = GameContent.catalog().npc(tier.npc_id)
		var places: Array = tier.place_indices.map(func(place: int) -> StringName: return WorldProgressionRewards.region_of_zone(rules.places[place].zone_id).region_id)
		_assert_true(outlaw != null and outlaw.native_role() == NpcDefinition.ROLE_BOUNTY_TARGET and outlaw.combat_experience == tier.min_exp and tier.after != null and tier.after.key == chapters[index] and not tier.after_hint.is_empty() and places.all(func(region: StringName) -> bool: return region == regions[index]), "tier %d: %s at %d exp, after %s, found in %s (%s)" % [5 + index, tier.npc_id, tier.min_exp, chapters[index], regions[index], places])
	_assert_true(rules.tiers.slice(0, 5).all(func(tier: BountyRules.Tier) -> bool: return tier.after == null and tier.place_indices == [0, 1, 2, 3, 4, 5, 6]), "A2's five tiers: no story to wait on, the board's seven places")
	var player := CharacterState.new()
	var opens: Callable = func(tier: int) -> bool: return rules.tiers[tier].open_for(player)
	var ceiling: int = pacing.bounty_ceiling_percent
	_assert_eq([BountyBoard.worthy_tier(rules, 150, _exp, opens, ceiling), BountyBoard.worthy_tier(rules, 250, _exp, opens, ceiling)], [0, 1], "150: the 流窜毛贼 (100); 250, twice him: the 剪径贼 (400), though 400 is not reached — no gap")
	_assert_eq([BountyBoard.worthy_tier(rules, 9000, _exp, opens, ceiling), BountyBoard.worthy_tier(rules, 12000, _exp, opens, ceiling), BountyBoard.waiting_tier(rules, 12000, _exp, opens, ceiling)], [4, -1, 5], "9000: the 杀人魔头 (5500); 12000, twice him, before 乔阴 is done: none — the 越狱死囚 waits on the story")
	player.quests["main.chapter5#done"] = 1 # TEST-ONLY
	var state := BountyState.new()
	BountyBoard.tick(state, rules, 12000, 0, _exp, opens, ceiling)
	_assert_true(state.tiers == [5, 5, 5] and state.places.all(func(place: int) -> bool: return rules.tiers[5].place_indices.has(place)), "乔阴 done: the 越狱死囚 is posted, in 乔阴东郊 (%s, %s)" % [state.tiers, state.places])
	_assert_eq([state.places[0] != state.places[1], state.places[1] != state.places[2], state.places[0] != state.places[2]], [true, true, true], "its three postings in three places (one at a time through a tier's own three): %s" % [state.places])
	_assert_eq([BountyBoard.place_stride(7), BountyBoard.place_stride(3), BountyBoard.place_stride(1)], [3, 1, 3], "the stride: 3 through the board's seven, 1 through a tier's three")
	_assert_eq([BountyBoard.worthy_tier(rules, 16000, _exp, opens, ceiling), BountyBoard.waiting_tier(rules, 16000, _exp, opens, ceiling)], [-1, 6], "16000, twice him: none — the 劫船海寇 waits on 番坊")
	for key: String in chapters:
		player.quests[key] = 1 # TEST-ONLY
	_assert_eq([BountyBoard.worthy_tier(rules, 69999, _exp, opens, ceiling), BountyBoard.worthy_tier(rules, 70000, _exp, opens, ceiling), BountyBoard.waiting_tier(rules, 70000, _exp, opens, ceiling)], [8, -1, -2], "after the finale: the 逆灵宫余孽 (35000) until twice him; then none, and none left to wait for")
	var errors: Array[String] = []
	BountyRules.from_record(ContentRecordReader.new({"tiers": [{"min_exp": 0, "npc": "x", "silver": 1, "after": {"quest": "q#done"}}], "places": [{"map": "m", "zone": "z"}]}, "b", errors))
	_assert_true(errors.size() == 1 and errors[0].contains("after_hint"), "a tier that waits on the story says when (after_hint): %s" % [errors])
	for percent: int in [0, 101, 200, 100, 50, -5]:
		var read: Array[String] = []
		PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "bounty_ceiling_percent": percent}, "p", read))
		var refused: bool = read.size() == 1 and read[0].contains("bounty_ceiling_percent")
		_assert_true(refused == (percent != 0 and percent <= 100) and (refused or read.is_empty()), "bounty_ceiling_percent %d: %s" % [percent, "refused" if refused else "read"] + (" %s" % [read] if not read.is_empty() else ""))


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
