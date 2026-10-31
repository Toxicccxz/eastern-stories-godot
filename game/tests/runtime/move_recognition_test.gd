extends RefCounted

## 识招 (战斗决策层 4, DECISIONS「战斗内容」): the moves the player watched are counted, a tag
## is read once watched `recognise_after` times, the player's own schools' moves are known
## at once, the knob at 0 knows all; the scheduler counts the enemies' moves in a fight the
## player is in; the 百科's 见识录 lists what was watched; the count survives a save.

const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const ID: StringName = Fixtures.ENCOUNTER_ID

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	var manual_before: bool = BattlePace.manual_turns
	_test_counting_and_threshold()
	_test_own_schools()
	_test_scheduler_counts()
	_test_codex_record()
	_test_save()
	BattlePace.manual_turns = manual_before
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_counting_and_threshold() -> void:
	var state := CharacterState.new()
	var catalog: ContentCatalog = GameContent.catalog()
	var rules := CombatDecisionRules.new(true, true, 20, 50, 2, 3, 2)
	var bite: CombatActionDefinition = BeastCombatActionDefinitions.bite()
	_check(MoveRecognition.times_seen(state, bite.action_id) == 0 and not MoveRecognition.recognised(state, bite, rules, catalog), "never watched: the tag is not read")
	_check(MoveRecognition.note(state, bite.action_id) == 1 and not MoveRecognition.recognised(state, bite, rules, catalog), "watched once: not yet")
	_check(MoveRecognition.note(state, bite.action_id) == 2 and MoveRecognition.recognised(state, bite, rules, catalog) and state.known_moves == {String(bite.action_id): 2}, "watched twice (recognise_after 2): read, counted in known_moves")
	_check(MoveRecognition.recognised(state, BeastCombatActionDefinitions.action(&"claw"), CombatDecisionRules.classic(), catalog), "the knob at 0 (经典): every tag read")
	_check(MoveRecognition.recognised(state, null, rules, catalog) and MoveRecognition.note(state, &"") == 0 and MoveRecognition.note(null, bite.action_id) == 0, "nothing to read or count: harmless")
	_check(MoveRecognition.weakness(CombatMoveTags.HEAVY) == CombatMoveTags.QUICK and MoveRecognition.weakness(CombatMoveTags.QUICK) == CombatMoveTags.FEINT and MoveRecognition.weakness(CombatMoveTags.FEINT) == CombatMoveTags.GUARD and MoveRecognition.weakness(CombatMoveTags.GUARD) == CombatMoveTags.HEAVY and MoveRecognition.weakness(CombatMoveTags.NONE).is_empty(), "the weakness is the tag that beats it on the ring; 平 has none")


func _test_own_schools() -> void:
	var state := CharacterState.new()
	var catalog: ContentCatalog = GameContent.catalog()
	var rules := CombatDecisionRules.new(true, true, 20, 50, 2, 3, 2)
	var liuh: CombatActionDefinition = catalog.skill(&"liuh-ken").action_set().actions()[0]
	var punch: CombatActionDefinition = catalog.combat_actions().race_action_set(&"human").actions()[0]
	var slash: CombatActionDefinition = catalog.combat_actions().weapon_action_set(&"sword").actions()[0]
	_check(MoveRecognition.is_own(state, punch, catalog) and MoveRecognition.recognised(state, punch, rules, catalog), "the race's own moves (挥拳) are known")
	_check(not MoveRecognition.is_own(state, liuh, catalog) and not MoveRecognition.is_own(state, slash, catalog), "a school not learned, a weapon not learned: not own")
	state.skills.set_raw_level(&"liuh-ken", 1)
	state.skills.set_raw_level(&"sword", 3)
	_check(MoveRecognition.is_own(state, liuh, catalog) and MoveRecognition.recognised(state, liuh, rules, catalog), "one level of 柳家拳: its moves are known")
	_check(MoveRecognition.is_own(state, slash, catalog) and MoveRecognition.recognised(state, slash, rules, catalog), "a level of 基本剑法: the sword's verbs are known")
	_check(not MoveRecognition.is_own(state, catalog.combat_actions().weapon_action_set(&"whip").actions()[0], catalog), "not the whip's")
	state.skills.set_raw_level(&"liuh-ken", 0)
	_check(not MoveRecognition.is_own(state, liuh, catalog), "a skill at 0 is not learned")


func _test_scheduler_counts() -> void:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(Probe.new(&"perform.qa", CombatTacticalRequest.TargetRule.CURRENT_HOSTILE))
	f.scheduler.configure_decisions(CombatDecisionRules.new(true, true, 20, 50, 2, 3, 2))
	f.scheduler.configure_player_tactics(PLAYER, registry)
	Probe.prepare(f.bindings[0].state)
	f.encounter.set_current_target(PLAYER, ENEMY)
	BattlePace.manual_turns = true
	var player: CharacterState = f.bindings[0].state
	f.scheduler.advance(1.0, true, ID, f.bindings, f.random, f.effects)
	var moves: Array[CombatActionDefinition] = f.scheduler.player_moves(f.bindings)
	var attacks: int = 0
	var seen_ids: Dictionary[StringName, bool] = {}
	for round: int in 4:
		f.scheduler.choose_attack(moves[0].action_id, f.bindings)
		var result: CombatSchedulerAdvanceResult = f.scheduler.advance(1.0, true, ID, f.bindings, f.random, f.effects)
		for event: CombatSchedulerEvent in result.events():
			if event.actor_id == ENEMY and event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.resolution.forward_result != null and event.resolution.forward_result.action_selection_result != null and event.resolution.forward_result.action_selection_result.selected_action != null:
				attacks += 1
				seen_ids[event.resolution.forward_result.action_selection_result.selected_action.action_id] = true
	var total: int = 0
	for key: String in player.known_moves:
		total += player.known_moves[key]
	_check(attacks > 0 and total == attacks, "every move the enemy used is counted on the player: %d used, %d counted (%s)" % [attacks, total, player.known_moves])
	_check(seen_ids.keys().all(func(id: StringName) -> bool: return player.known_moves.has(String(id))), "under its own ID")
	_check(f.bindings[1].state.known_moves.is_empty(), "the enemy counts nothing of the player's")
	var classic: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	classic.scheduler.configure_decisions(CombatDecisionRules.classic())
	classic.scheduler.configure_player_tactics(PLAYER, registry)
	classic.encounter.set_current_target(PLAYER, ENEMY)
	BattlePace.manual_turns = false
	classic.scheduler.advance(3.0, true, ID, classic.bindings, classic.random, classic.effects)
	_check(classic.bindings[0].state.known_moves.is_empty(), "经典 (recognise_after 0) counts nothing")


func _test_codex_record() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state := CharacterState.new()
	var nothing: Array[CodexContent.Entry] = CodexContent.entries(CodexContent.Section.ARTS, state, catalog)
	_check(nothing.size() == 1 and nothing[0].key == "moves/race/human", "nothing learned or watched: only one's own 拳脚 (known by race)")
	var bite: CombatActionDefinition = BeastCombatActionDefinitions.bite()
	MoveRecognition.note(state, bite.action_id)
	var once: Array[CodexContent.Entry] = CodexContent.entries(CodexContent.Section.ARTS, state, catalog)
	var beasts: CodexContent.Entry = null
	for entry: CodexContent.Entry in once:
		if entry.key == "moves/race/beast":
			beasts = entry
	_check(beasts != null and beasts.title == "见识录 · 禽兽" and beasts.text().contains("咬 · ？ · 见过 1 次") and beasts.text().contains("抓 · ？") and not beasts.text().contains("抓 · ？ · 见过"), "the beasts' verbs once a bite was watched: 咬 still ？, 抓 never seen")
	MoveRecognition.note(state, bite.action_id)
	beasts = null
	for entry: CodexContent.Entry in CodexContent.entries(CodexContent.Section.ARTS, state, catalog):
		if entry.key == "moves/race/beast":
			beasts = entry
	_check(beasts != null and beasts.text().contains("咬 · 快 · 破绽：虚 · 见过 2 次"), "watched twice: 咬 is 快, broken by 虚: " + beasts.text())
	state.skills.set_raw_level(&"liuh-ken", 5)
	var own: CodexContent.Entry = null
	for entry: CodexContent.Entry in CodexContent.entries(CodexContent.Section.ARTS, state, catalog):
		if entry.key == "moves/liuh-ken":
			own = entry
	_check(own != null and own.title == "见识录 · 柳家拳" and own.text().contains("这一路的招你都认得") and own.text().contains("古松挂月 · 守 · 破绽：重"), "one's own school: every move read: " + ("-" if own == null else own.text().left(80)))
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(PacePresets.of(production, CharacterState.PACE_CLASSIC))
	_check(CodexContent.entries(CodexContent.Section.ARTS, state, catalog).all(func(entry: CodexContent.Entry) -> bool: return not entry.key.begins_with("moves/")), "经典: no 见识录 (every tag is read)")
	catalog.set_pacing(production)


func _test_save() -> void:
	var state := CharacterState.new()
	state.known_moves = {"es2:adm/daemons/race/beast/bite": 2, "es2:daemon/skill/liuh-ken/gu-song-gua-yue": 1}
	var snapshot: GameSaveValueTypes.CharacterStateSnapshot = GameSaveValueTypes.CharacterStateSnapshot.new().with_known_moves(state.known_moves)
	_check(snapshot.known_moves == state.known_moves, "the snapshot carries known_moves (the codec's round trip: game_save_json_codec_test)")


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("move recognition: " + label)
