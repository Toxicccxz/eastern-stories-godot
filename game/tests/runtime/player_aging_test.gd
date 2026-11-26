extends RefCounted

## 成长曲线 C (owner 2026-11-19「都照推荐」, plan Q6; DECISIONS「成长曲线 C」): the player grows up with
## experience, pacing.json's player_age_by_exp: 15 at 4000, 16 at 6500, 17 at 9000, 18 at 12000, 19
## at 20000, 20 at 30000 (ES2 ages by time online: obj/user.c update_age()). Each year gives race/
## human.c's 20 more max 精 and 气 (神 the same until 30) and is told once; a death's lost exp takes
## no year back; a save keeps the age; NPCs speak to the age (a man 壮士 from 20, a woman 姑娘 from 18).

const TestAging := preload("res://tests/support/test_aging.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_rule()
	TestAging.use()
	var session: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	_test_in_play(session)
	session.free()
	await tree.process_frame
	TestAging.restore()
	_test_words()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_rule() -> void:
	var steps: Array[PlayerAging.Step] = TestAging._steps
	_check(steps.size() == 6 and steps[0].min_exp == 4000 and steps[0].age == 15 and steps.back().min_exp == 30000 and steps.back().age == 20, "pacing.json: 15 at 4000 … 20 at 30000 (%d steps)" % steps.size())
	_check(PlayerAging.grown_age(14, 3999, steps) == 14 and PlayerAging.grown_age(14, 4000, steps) == 15 and PlayerAging.grown_age(14, 11999, steps) == 17 and PlayerAging.grown_age(14, 1000000, steps) == 20, "the age by exp")
	_check(PlayerAging.grown_age(18, 5000, steps) == 18, "an age reached is kept when exp is lower")
	var none: Array[PlayerAging.Step] = []
	_check(PlayerAging.grown_age(14, 1000000, none) == 14, "no table: 14 for good")
	var errors: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"player_age_by_exp": [{"exp": 100, "age": 16}, {"exp": 50, "age": 17}]}, "pacing", errors))
	_check(not errors.is_empty(), "a table whose exp does not rise is refused: %s" % [errors])
	_check(TestAging.production_age(30000) == 20 and TestAging.production_age(0) == 14, "production_age reads pacing.json's whatever the runner turned off")


func _test_in_play(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	_check(player.facts.age == 14 and state.vitality.maximum == 100 and state.essence.maximum == 100, "New Game: 14, 气 100, 精 100")
	state.progression.combat_experience = 6500 # TEST-ONLY: two steps at once
	var before: int = session.shared_ui().log_lines().size()
	session.advance_player_recovery(0.1)
	var told: Array[String] = session.shared_ui().log_lines().slice(before)
	_check(player.facts.age == 16 and state.vitality.maximum == 140 and state.essence.maximum == 140 and state.spirit.maximum == 100, "6500 exp: 16, 气 140, 精 140, 神 100 (%d, %d / %d / %d)" % [player.facts.age, state.vitality.maximum, state.essence.maximum, state.spirit.maximum])
	_check(told.size() == 1 and told[0] == "【长大】你十六岁了：气的上限多了 40 点，精的上限多了 40 点。", "told once: %s" % [told])
	session.advance_player_recovery(0.1)
	_check(session.shared_ui().log_lines().size() == before + 1, "nothing more on the next beat")
	# A death's 1% (or any loss) takes no year back.
	state.progression.combat_experience = 6000 # TEST-ONLY
	session.advance_player_recovery(0.1)
	_check(player.facts.age == 16 and state.vitality.maximum == 140, "less exp: still 16")
	# The age goes with max_force's quarter (race/human.c): 打坐 after growing up keeps both.
	state.recovery.inner_force.maximum = 200 # TEST-ONLY
	CharacterDerivedValues.refresh_human_player_maxima(state, player.facts.age)
	_check(state.vitality.maximum == 190, "气 = 140 + max_force / 4 (%d)" % state.vitality.maximum)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-11-26T00:00:00Z").snapshot
	_check(snapshot != null and snapshot.player.identity.age == 16, "a save keeps the age (%s)" % ["null" if snapshot == null else str(snapshot.player.identity.age)])
	state.progression.combat_experience = 30000 # TEST-ONLY
	session.advance_player_recovery(0.1)
	_check(player.facts.age == 20 and state.essence.maximum == 220, "30000: 20, 精 220")


## NPCs' forms of address follow the age (rank_words.gd: RankWords.query_respect()).
func _test_words() -> void:
	_check(RankWords.query_respect(CharacterState.GENDER_MALE, 19, &"") != "壮士" and RankWords.query_respect(CharacterState.GENDER_MALE, 20, &"") == "壮士", "a man: 壮士 from 20")
	_check(RankWords.query_respect(CharacterState.GENDER_FEMALE, 17, &"") != "姑娘" and RankWords.query_respect(CharacterState.GENDER_FEMALE, 18, &"") == "姑娘", "a woman: 姑娘 from 18")


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("长大", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
