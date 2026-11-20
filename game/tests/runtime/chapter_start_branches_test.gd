extends RefCounted

## The dev launcher 从第几章开始 (tests/dev/chapter_start) on every road through the main story (第三章 rescue / chase,
## 第六章 借兵 / 潜入, 第七章 大秦人 / 浪人, 第八章 pull / keep, 第九章 揭发 / 私了 / 皇叔, 第十章 who drew 旋芒): what its
## starts write, read by the game's own conditions —
## - 第十章's bells: of the 风铃阁's ten (lancheng.whirl.self's at_least 6), as many ring as ChapterStart.bells says;
## - 终章's roll call: of finale.helpers' bands, as many come as ChapterStart.roll_call says;
## - what Spec.problems() refuses is what the data refuses: 揭发 where the proofs fall short of the act's own
##   at_least (the start's things in hand counted), 自己拔 under six bells, 旋芒 with a 皇叔 who never came to court.
## One New Game; each road written by the chapter fixtures on a cleared ledger (ChapterStart._write_story).

const Check := preload("res://tests/support/chapter_start_check.gd")
const Fixtures := preload("res://tests/support/story_fixtures.gd")
const Transaction := preload("res://tests/runtime/oldpine_save_load_transaction_test.gd")
const HOST_SCENE: PackedScene = preload("res://scenes/runtime/oldpine_game_runtime_host.tscn")

var _checks: Check = Check.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	_check(host.configure_manual_before_start(GameSaveStorageProfile.isolated_test("chapter-start-branches"), Transaction.MemoryFiles.new()), "a test profile")
	tree.root.add_child(host)
	await tree.process_frame
	host.opening_card = false
	_check(host.request_new_game("凌雪", CharacterState.GENDER_FEMALE), "New Game")
	await host.new_game_completed
	for frame: int in 4:
		await tree.process_frame
	var session: WorldSessionController = host.current_session()
	if session != null and session.is_initialized():
		_test_roads(session)
	host.get_parent().remove_child(host)
	host.free()
	await tree.process_frame
	return _checks.result()


func _test_roads(session: WorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var bells_when: JournalEntryDefinition = catalog.service(&"lancheng.whirl.self").act.acts[5].when
	var expose_when: JournalEntryDefinition = catalog.service(&"imperial.front_hall.expose").act.acts[2].when
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	_check(bells_when.when == JournalEntryDefinition.When.AT_LEAST and bells_when.amount == 6 and bells_when.parts.size() == 10, "the 云台's 自己拔: six of ten bells")
	_check(helpers.when == JournalEntryDefinition.When.AT_LEAST and helpers.amount == 3, "终章's roll call: three bands for 能灭它")
	var state: CharacterState = session.player_runtime().state
	var table: Array[String] = []
	var roads: int = 0
	for chased: bool in [false, true]:
		for raid: bool in [true, false]:
			for rome: bool in [true, false]:
				for pulled: bool in [false, true]:
					for side: String in ["expose", "deal", "uncle"]:
						var spec: ChapterStart.Spec = ChapterStart.spec(&"main.finale", {"chased": chased, "raid": raid, "rome": rome, "pulled": pulled, "side": side})
						var label: String = spec.describe()
						# 第九章's 揭发, read before the choice is made: the ledger 第九章 leaves and the things the start carries.
						state.marks.clear()
						state.quests.clear()
						var tenth: ChapterStart.Spec = ChapterStart.spec(&"main.chapter10", {"chased": chased, "raid": raid, "rome": rome, "pulled": pulled, "side": side})
						var written: Dictionary = Fixtures.record(ChapterStart._write_story.bind(session, tenth))
						var held: Dictionary[StringName, bool] = {}
						for item_id: StringName in (written["given"] as Dictionary).keys() + ChapterStart.carried(tenth):
							if not (written["taken"] as Dictionary).has(item_id):
								held[item_id] = true
						var expose_holds: bool = JournalLog.holds(expose_when, state, {}, held)
						if side == "expose":
							_check(expose_holds == tenth.problems().is_empty(), "%s: 揭发 %s by the data, %s by the start (%s)" % [label, "possible" if expose_holds else "short of proofs", "allowed" if tenth.problems().is_empty() else "refused", tenth.problems()])
						# 第十章 done: the bells and the roll call, for each hand 旋芒 is in.
						for who: String in ["self", "uncle", "xiao"]:
							spec.who = who
							state.marks.clear()
							state.quests.clear()
							ChapterStart._write_story(session, spec)
							var rung: int = bells_when.parts.filter(func(part: JournalEntryDefinition) -> bool: return JournalLog.holds(part, state, {}, {})).size()
							var come: int = helpers.parts.filter(func(part: JournalEntryDefinition) -> bool: return JournalLog.holds(part, state, {}, {})).size()
							_check(rung == ChapterStart.bells(spec), "%s: %d bells ring, ChapterStart.bells says %d" % [label, rung, ChapterStart.bells(spec)])
							_check(come == ChapterStart.roll_call(spec), "%s: %d bands come, ChapterStart.roll_call says %d" % [label, come, ChapterStart.roll_call(spec)])
							var by_data: bool = (side != "expose" or expose_holds)
							match who:
								"self": by_data = by_data and JournalLog.holds(bells_when, state, {}, {})
								"uncle": by_data = by_data and state.marks.get("皇叔入朝", 0) == 1
							_check(by_data == spec.problems().is_empty(), "%s: reachable by the data %s, by the start %s (%s)" % [label, by_data, spec.problems().is_empty(), spec.problems()])
							if who == "self":
								table.append("%s：铃 %d，帮手 %d%s" % [label.trim_suffix("，旋芒在你手里"), rung, come, "" if by_data else "（自己拔不了）" if side != "expose" or expose_holds else "（揭发凑不够）"])
							roads += 1
	_check(roads == 144, "every road: %d" % roads)
	print("  bells and roll call by road:\n  " + "\n  ".join(table))


func _check(ok: bool, label: String) -> void:
	_checks._check(ok, label)
