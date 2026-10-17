extends RefCounted

## 现代化修正 III (DECISIONS「响应性」): pacing.json's responsiveness knobs. Left out they are
## ES2's (each call_out's own seconds, a master's test struck in one go, a 2 s heart beat,
## no fade); the game's: an NPC answers what the player just did within 0.4 s, a master's
## test comes 0.7 s a blow, and the card shows what the player waits for (busy, their
## steal, a test, a told sequence with 继续, 朱鸿雪's task time, an NPC lying unconscious, a
## robber about to attack, who shouts his 买路财 line the moment the player comes near).
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const TAOLORD: StringName = &"common.npc.taoist.taolord"
const CHAMPION: StringName = &"common.npc.fighter.champion"
const GANGSTER: StringName = &"cloud.npc.gangster"
const SHAOWEI: StringName = &"latemoon.npc.shaowei"
const NO_WOMEN: String = "林忌说道：贫道是出家人，不便收女徒，得罪了。"
const TOLL_SHOUT: String = "强盗喝道：呔！此山是我开，此树乃我栽。要想从此过，留下 买路财！"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_knobs()
	_test_heart_beat()
	_test_reaction_beat()
	_test_hurry()
	_test_trial_steps()
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_card(tree, session)
	await _test_making(tree, session)
	await _test_apprentice_answer(tree, session)
	await _test_trial(tree, session)
	await _test_toll(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- The knobs -------------------------------------------------------------------------

func _test_knobs() -> void:
	var bare := PacingDefinition.new(1000)
	_check(
		[bare.reaction_seconds(2.0), bare.reaction_seconds(0.3), bare.trial_blow_seconds, bare.heart_beat_seconds, bare.dim_fade_seconds] == [2.0, 0.3, 0.0, 2.0, 0.0],
		"constructed without them: ES2 (each call_out's own time, the test in one go, a 2 s beat, no fade)",
	)
	var errors: Array[String] = []
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors))
	_check(errors.is_empty() and read.reaction_seconds(1.0) == 1.0 and read.trial_blow_seconds == 0.0 and read.heart_beat_seconds == 2.0 and read.dim_fade_seconds == 0.0, "a record that leaves them out: ES2 %s" % [errors])
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "reaction_beat_ms": -1, "trial_blow_ms": -1, "heart_beat_ms": 0, "dim_fade_ms": -1}, "p", broken))
	_check(broken.size() == 4, "negative times and a heart beat of 0 are refused: %s" % [broken])
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_check(
		[pacing.reaction_seconds(2.0), pacing.reaction_seconds(1.0), pacing.reaction_seconds(0.0), pacing.trial_blow_seconds, pacing.heart_beat_seconds, pacing.dim_fade_seconds] == [0.4, 0.4, 0.0, 0.7, 2.0, 0.4],
		"pacing.json: answers within 0.4 s (never later than ES2's own), 0.7 s a blow, the 2 s beat, a 0.4 s fade",
	)


## heart_beat_ms drives the beat: one of 1 s ticks twice as often as ES2's 2 s.
func _test_heart_beat() -> void:
	var pulses: Array[int] = []
	for seconds: float in [2.0, 1.0]:
		var character := CharacterState.new()
		character.vitality = CharacterResourceState.new(10, 100, 100)
		var cadence := PlayerRecoveryCadence.new(Fives.new(), true, null, 1, 1, seconds)
		var busy := ActionBusyState.new()
		busy.start_busy(10)
		pulses.append(cadence.advance(4.0, character, busy).pulses)
	_check(pulses == [2, 4] and PlayerRecoveryCadence.new(Fives.new()).pulse_seconds == 2.0, "4 s are two beats of 2 s, four of 1 s; none given: 2 s (%s)" % [pulses])


## A greeting and a call_out answering the player: the reaction beat, or ES2's time.
func _test_reaction_beat() -> void:
	var ambience := NpcAmbience.new(null)
	ambience.start_greeting(&"a")
	ambience.start_reaction(&"b", 2.0, NpcAmbience.RECRUIT)
	_check(ambience.due_greetings(0.35).is_empty() and ambience.due_calls(0.35, NpcAmbience.RECRUIT).is_empty(), "not yet at 0.35 s")
	_check(ambience.due_greetings(0.06) == [&"a"] and ambience.due_calls(0.06, NpcAmbience.RECRUIT) == [&"b"], "the greeting and the master's answer at 0.4 s")
	ambience.start_greeting(&"h", true)
	_check(ambience.due_greetings(0.5).is_empty() and ambience.due_greetings(0.5) == [&"h"], "a greeting that harms keeps ES2's second (the time to walk past)")
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.npc(&"chuenyu.npc.jiading3").talk().greeting_harms() and not catalog.npc(&"snow.npc.waiter").talk().greeting_harms(), "the 家丁's greeting (kill) harms; the waiter's does not")
	var es2: PacingDefinition = Es2Pacing.use()
	ambience.start_greeting(&"a")
	ambience.start_reaction(&"b", 2.0, NpcAmbience.RECRUIT)
	_check(ambience.due_greetings(0.9).is_empty() and ambience.due_greetings(0.1) == [&"a"], "ES2: the greeting a second on (call_out(\"greeting\", 1))")
	_check(ambience.due_calls(1.5, NpcAmbience.RECRUIT).is_empty() and ambience.due_calls(0.5, NpcAmbience.RECRUIT) == [&"b"], "ES2: the answer two seconds on (call_out(\"do_recruit\", 2))")
	Es2Pacing.restore(es2)


## 继续: the next of a told sequence comes now; the rest keep their spacing.
func _test_hurry() -> void:
	var ambience := NpcAmbience.new(null)
	ambience.start_call(&"maker", 2.0, NpcAmbience.MAKE)
	_check(ambience.hurry_call(&"maker", NpcAmbience.MAKE) and not ambience.hurry_call(&"maker", NpcAmbience.MAKE), "继续 brings it; again in the same frame: nothing more to bring")
	_check(ambience.due_calls(0.0, NpcAmbience.MAKE) == [&"maker"], "a making's next line: now")
	_check(not ambience.hurry_call(&"maker", NpcAmbience.MAKE), "none left: nothing hurried")
	for index: int in 3:
		ambience.start_call(&"g", 5.0 * (index + 1), NpcAmbience.own_call(index))
	ambience.start_call(&"g", 7.0, NpcAmbience.own_call(3)) # not part of the sequence
	var told: Array[int] = [0, 1, 2]
	_check(ambience.hurry_own_calls(&"g", told), "the gargoyle's lines hurried")
	_check(ambience.due_own_calls(0.0) == [[&"g", 0]], "the gargoyle's first line now")
	_check(is_equal_approx(ambience.call_left(&"g", NpcAmbience.own_call(1)), 5.0) and is_equal_approx(ambience.call_left(&"g", NpcAmbience.own_call(3)), 7.0), "the next five seconds after it; a call outside the sequence keeps its time")
	var rest: Array[int] = [1, 2]
	ambience.hurry_own_calls(&"g", rest)
	_check(ambience.due_own_calls(0.0) == [[&"g", 1]] and is_equal_approx(ambience.call_left(&"g", NpcAmbience.own_call(2)), 5.0), "and the second")


## champion.c's blows one step at a time: the same lines and outcome as in one go.
func _test_trial_steps() -> void:
	var rule: NpcTeaching.ApprenticeRule = GameContent.catalog().npc(CHAMPION).teaching().apprentice
	var request := NpcApprenticeship.new()
	var make := func(failing: int) -> NpcApprenticeTrial.Run:
		var struck: Array[int] = [0]
		return NpcApprenticeTrial.start(rule, request,
			func() -> Array[ColoredLine]:
				struck[0] += 1
				var seen: Array[ColoredLine] = [ColoredLine.new("（一招）")]
				return seen,
			func() -> bool: return failing < 0 or struck[0] <= failing,
			func() -> NpcApprenticeship.Outcome: return NpcApprenticeship.Outcome.AUTHORITY_FAILURE)
	var test: NpcApprenticeTrial.Run = make.call(-1)
	var first: Array[String] = ColoredLine.texts(test.step())
	_check(first == ["於兰天武点了点头，说道：很好，这是第一招....", "（一招）"] and not test.finished and test.result.blows == 1 and test.blow_count() == 3, "the first blow alone: %s" % [first])
	test.step()
	var last: Array[String] = ColoredLine.texts(test.step())
	_check(test.finished and test.result.outcome == NpcApprenticeTrial.Outcome.PASSED and last[0] == "於兰天武说道：第三招来了...." and last.has("於兰天武哈哈大笑，说道：今日老夫终於觅得一个可造之才！"), "the third: 可造之才: %s" % [last])
	var whole: NpcApprenticeTrial.Result = NpcApprenticeTrial.run(rule, NpcApprenticeship.new(),
		func() -> Array[ColoredLine]:
			var seen: Array[ColoredLine] = [ColoredLine.new("（一招）")]
			return seen,
		func() -> bool: return true,
		func() -> NpcApprenticeship.Outcome: return NpcApprenticeship.Outcome.AUTHORITY_FAILURE)
	_check(ColoredLine.texts(whole.lines) == ColoredLine.texts(test.result.lines), "in one go (ES2): the same lines")
	var steps: Array[int] = []
	var joined: Array[String] = []
	for step: Array in whole.steps:
		steps.append(step.size())
		var lines: Array[ColoredLine] = []
		lines.assign(step)
		joined.append_array(ColoredLine.texts(lines))
	_check(steps == [2, 2, 3] and joined == ColoredLine.texts(whole.lines), "and blow by blow for the telling: %s" % [steps])
	var failing: NpcApprenticeTrial.Run = make.call(1)
	failing.step()
	var second: Array[String] = ColoredLine.texts(failing.step())
	_check(failing.finished and failing.result.outcome == NpcApprenticeTrial.Outcome.FAILED and second.back() == "於兰天武「哼」地一声，说道：便是有这许多不怕死的家伙....", "the second not stood: its line ends it")


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var white: NpcHooks = catalog.npc(&"death.npc.wgargoyle").hooks()
	var black: NpcHooks = catalog.npc(&"death.npc.bgargoyle").hooks()
	var white_told: Array = white.calls.map(func(call: NpcHooks.Call) -> bool: return call.hurry)
	var black_told: Array = black.calls.map(func(call: NpcHooks.Call) -> bool: return call.hurry)
	_check(white_told == [true, true, true, true, true] and black_told == [false, true, true, true, true, true], "the gargoyles' lines may be hurried; the black one's attack on the living may not: %s %s" % [white_told, black_told])
	var xiaojuan: NpcHooks = catalog.npc(&"chuenyu.npc.xiaojuan2").hooks()
	_check(xiaojuan != null and xiaojuan.calls[0].reaction and xiaojuan.calls[0].after == 3.0 and not xiaojuan.calls[1].reaction, "小娟's cry answers the player's arrival (ES2 3 s kept in the data); her following does not")
	var gangster: NpcDefinition = catalog.npc(GANGSTER)
	_check(gangster.dealings().toll_shout == 0 and NpcTalk.line(gangster.talk().chat_entries()[0]) == TOLL_SHOUT, "the robber shouts his first chat line")
	var errors: Array[String] = []
	NpcDealings.from_record(ContentRecordReader.new({"toll_shout": 0}, "npc", errors))
	_check(errors.size() == 1, "a shout without a toll that waits is refused: %s" % [errors])


# --- In the world ----------------------------------------------------------------------

## The card's waits: busy, a steal, 朱鸿雪's task; an NPC lying unconscious says when it
## comes to.
func _test_card(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	hud.waits.refresh()
	_check(hud.waits.texts().is_empty() and not hud._presentation_layout.waits.visible, "nothing to wait for: no waits shown")
	player.busy.start_busy(3) # TEST-ONLY
	hud.waits.refresh()
	var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
	var left: int = ceili(3 * cadence.pulse_seconds - cadence.accumulated_seconds)
	_check(hud.waits.texts() == ["忙碌：约 %d 秒后空下来" % left] and hud._presentation_layout.waits.visible, "busy 3: about six seconds: %s" % [hud.waits.texts()])
	player.busy.advance()
	hud.waits.refresh()
	_check(hud.waits._shown[0].progress > 0.3, "a beat later the bar has moved")
	player.busy.advance()
	player.busy.advance()
	hud.waits.refresh()
	_check(hud.waits.texts().is_empty(), "free again: gone")
	var npc: NpcRuntimeState = _awake_resident(map)
	map.thefts._pending = {"npc": npc.character_id, "item": &"x", "sp": 1, "dp": 1, "left": 1.5} # TEST-ONLY: a steal half done
	hud.waits.refresh()
	_check(hud.waits.texts() == ["等待机会对%s下手" % npc.definition().display_name] and is_equal_approx(hud.waits._shown[0].progress, 0.5), "the steal: steal.c's three seconds, half gone")
	map.thefts._pending = {}
	player.state.quest.assign(QuestDefinition.new("疯狗", QuestDefinition.KILL, 40, 20, 10, 5), 1) # TEST-ONLY
	player.state.quest.advance(10000)
	hud.waits.refresh()
	_check(hud.waits.texts() == ["朱鸿雪的任务：还有三十秒"] and is_equal_approx(hud.waits._shown[0].progress, 0.25), "朱鸿雪's task: its time left: %s" % [hud.waits.texts()])
	player.state.quest.advance(40000)
	hud.waits.refresh()
	_check(hud.waits.texts() == ["朱鸿雪的任务：时间已过"], "and when it has run out")
	player.state.quest.clear_task()
	# An NPC lying unconscious beside the player.
	await _beside(tree, session, map, npc)
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	npc.set_revive_in_ms(29500)
	hud.nearby.refresh()
	_check(_status(hud, npc) == ["昏迷不醒，约 30 秒后醒来"], "its popup says when it comes to: %s" % [_status(hud, npc)])
	npc.set_revive_in_ms(0)
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	hud.nearby.refresh()
	_check(_status(hud, npc).is_empty(), "awake: no line")


## 筱薇's making (shaowei.c: a line every 2 s): shown with 继续, which brings the next line now.
func _test_making(_tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var maker: NpcRuntimeState = _awake_resident(map)
	var making: NpcMaking = null
	for rule: NpcObjectRule in GameContent.catalog().npc(SHAOWEI).dealings().object_rules:
		if rule.make != null:
			making = rule.make
	map.npc_life.start_making(maker, making) # TEST-ONLY: her making, by someone at hand
	hud.waits.refresh()
	var name: String = maker.definition().display_name
	_check(hud.waits.texts() == ["%s：第 0 / 5 句" % name] and hud.waits.can_hurry(), "her making: no line yet, 继续 offered: %s" % [hud.waits.texts()])
	_check(hud.waits.hurry(), "继续")
	map.npc_life._advance_ambience(0.0)
	hud.waits.refresh()
	_check(hud.log_lines().back().contains("你要作竹蜻蜓呀"), "its first line at once: %s" % hud.log_lines().back())
	_check(hud.waits.texts() == ["%s：第 1 / 5 句" % name], "one told: %s" % [hud.waits.texts()])
	map.npc_life._advance_ambience(1.9)
	hud.waits.refresh()
	_check(hud.waits.texts() == ["%s：第 1 / 5 句" % name], "untouched, the next keeps shaowei.c's two seconds")
	for line: int in 4:
		hud.waits.hurry()
		map.npc_life._advance_ambience(0.0)
	hud.waits.refresh()
	_check(hud.waits.texts().is_empty() and not map.npc_life.makings.has(maker.character_id), "all told: the dragonfly made, nothing to wait for")


## 林忌's answer to 拜师 (taolord.c: call_out("do_recruit", 2)): within the reaction beat.
func _test_apprentice_answer(tree: SceneTree, session: WorldSessionController) -> void:
	# 林忌's 灵心观大殿 is its own map since the remap: TEST-ONLY in at its door from the square.
	var map: WorldMapController = MapPlaces.enter(session, &"temple.temple1", &"temple.temple1.square_entry")
	_check(map != null and map.map_id() == &"temple.temple1_house", "TEST-ONLY: inside 茅山's 灵心观大殿 (its own map)")
	await tree.physics_frame
	await tree.physics_frame
	var master: NpcRuntimeState = _first(map, TAOLORD)
	await _beside(tree, session, map, master)
	map.npc_life._advance_ambience(0.0) # TEST-ONLY: the arrival noted
	# 拜师 from the interaction popup: its confirm page says who he is (family, what he
	# teaches); 确认 closes the popup, and his answer comes in world time.
	var hud: SharedGameplayUI = session.shared_ui()
	hud.refresh_exploration()
	_check(hud.nearby.choose(master.character_id) and hud.interact(), "his popup")
	var service: TeacherService = map.service(&"temple.temple1_house.temple1.taolord") as TeacherService
	# His 请教 is a page; its own 拜师 button gives way to the popup's row.
	_check(hud.interaction_panel.press(service.verb()) and hud._presentation_layout.page() == service.ui.panel and not service.ui.apprentice_button.visible, "%s: his panel in the popup, without its own 拜师" % service.verb())
	hud.dismiss_current_panel()
	_check(hud.interaction_panel.press("拜师"), "his popup's 拜师")
	var page: ConfirmPrompt = hud.confirm_prompt
	_check(hud.interaction_open() and hud._presentation_layout.page() == page and page.detail.text.contains("门派：") and page.detail.text.contains("传授："), "拜师: who he is, on its page: %s" % page.detail.text)
	_check(not page.message.text.is_empty() and page.confirm_button.text == "确定拜师", "then its question and 确定拜师: %s" % page.message.text)
	page.confirm_button.pressed.emit()
	_check(not hud._presentation_layout.frame.visible and map.npc_life.apprentice_answer_due(master), "确定拜师: the popup closes; his answer is due")
	# While it waits, 取消拜师请求 is a row, asked on its page too: 取消 keeps the request.
	_check(hud.interact() and hud.interaction_panel.press("取消拜师请求") and hud._presentation_layout.page() == page and page.confirm_button.text == "确定取消", "取消拜师请求: its confirm page")
	page.cancel()
	_check(session.player_runtime().apprenticeship_request.is_pending(), "取消: the request still waits")
	hud._presentation_layout.close_frame()
	map.npc_life._advance_ambience(0.3)
	_check(map.npc_life.apprentice_answer_due(master), "0.3 s: not yet")
	map.npc_life._advance_ambience(0.15)
	_check(not map.npc_life.apprentice_answer_due(master) and session.shared_ui().log_lines().has(NO_WOMEN), "0.4 s: 不便收女徒 (ES2: two seconds): %s" % [session.shared_ui().log_lines().slice(-3)])


## 於兰天武's test: struck whole at once (ES2), a passed one told a blow every 0.7 s (the menu
## holds the telling; the card shows which blow); a failed one told at once with the fall.
func _test_trial(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"waterfog.pavilion", &"waterfog.guildhall", &"waterfog.guildhall", &"waterfog.entrance.yard_arrival").succeeded() or session.handoff_to(&"waterfog.pavilion", &"waterfog.entrance", &"waterfog.entrance", &"waterfog.entrance.yard_arrival").succeeded(), "TEST-ONLY: in the pavilion")
	await tree.physics_frame
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var champion: NpcRuntimeState = _first(map, CHAMPION)
	await _beside(tree, session, map, champion)
	map.npc_life._advance_ambience(0.0) # TEST-ONLY: the arrival noted
	var original: CombatRandomSource = session.combat_random_source()
	session.configure_combat_random_source(Specials.Pattern.new([])) # TEST-ONLY: every blow lands in full
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY
	var service: TeacherService = map.service(&"waterfog.pavilion.guildhall.champion") as TeacherService
	service.ui.interact()
	var panel: TeacherPanel = service.ui
	panel.refresh()
	_check(panel.trial_button != null and panel.trial_button.visible, "his test is offered (offers_trial %s)" % service.offers_trial())
	panel.trial_button.pressed.emit()
	_check(panel.is_confirming(), "asked first (panel %s, in reach %s, blocked %s)" % [panel.panel.visible, service.can_teach(), ExplorationPresentationBlocker.is_blocked(tree)])
	if not panel.is_confirming():
		return
	panel.confirm_button.pressed.emit()
	var blow: int = roundi((100000 - player.state.vitality.current) / 3.0)
	_check(blow > 0 and player.apprenticeship_request.is_offered(CHAMPION), "all three blows struck at once, his offer made (champion.c in one command): about %d a blow" % blow)
	_check(not service.last_lines.is_empty() and service.last_lines[0] == "於兰天武点了点头，说道：很好，这是第一招...." and not service.last_lines.has("於兰天武说道：这是第二招....") and map.npc_life.trial_running(champion), "the first blow told, the second not yet: %s" % [service.last_lines])
	panel.refresh()
	hud.waits.refresh()
	_check(not panel.trial_button.visible and hud.waits.texts() == ["於兰天武的测试：第 1 / 3 招"], "no second test meanwhile; the card: the first of three: %s" % [hud.waits.texts()])
	var told: int = service.last_lines.size()
	session.hold_world_time(&"test") # TEST-ONLY: as the menu does
	session._process(1.0)
	_check(service.last_lines.size() == told, "the menu open: the telling waits")
	session.release_world_time(&"test")
	map.npc_life._advance_ambience(0.6)
	_check(not service.last_lines.has("於兰天武说道：这是第二招...."), "0.6 s: not yet")
	map.npc_life._advance_ambience(0.15)
	_check(service.last_lines.has("於兰天武说道：这是第二招....") and not service.last_lines.has("於兰天武说道：第三招来了...."), "0.7 s: the second")
	map.npc_life._advance_ambience(0.75)
	_check(service.last_lines.has("於兰天武说道：第三招来了....") and service.last_lines.has("於兰天武哈哈大笑，说道：今日老夫终於觅得一个可造之才！") and not map.npc_life.trial_running(champion), "the third and 可造之才: %s" % [service.last_lines])
	_check(panel.apprentice_feedback.text.contains("可造之才"), "the panel shows the whole test")
	player.apprenticeship_request._offers.erase(CHAMPION) # TEST-ONLY
	# Standing one blow but not two: told at once, and the fall comes with it.
	player.state.vitality = CharacterResourceState.new(roundi(blow * 1.5), 100000, 100000) # TEST-ONLY
	panel.refresh()
	panel.trial_button.pressed.emit()
	panel.confirm_button.pressed.emit()
	_check(service.last_lines.has("於兰天武说道：这是第二招....") and service.last_lines.back() == "於兰天武「哼」地一声，说道：便是有这许多不怕死的家伙...." and not map.npc_life.trial_running(champion), "the second not stood: the whole test at once: %s" % [service.last_lines])
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "and she falls with it")
	await tree.process_frame
	panel.close_panel()
	session.configure_combat_random_source(original)
	player.state.vitality = CharacterResourceState.new(100, 100, 100) # TEST-ONLY
	player.state.essence = CharacterResourceState.new(100, 100, 100)
	player.state.spirit = CharacterResourceState.new(100, 100, 100)
	for second: int in 12:
		if player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session._process(1.0) # the quick wake
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "TEST-ONLY: up again")


## 卧龙岗: the robber shouts the moment a passer-by who owes the toll comes near; his name
## turns red; one who paid hears nothing.
func _test_toll(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad.snow_entry")
	await tree.physics_frame
	await tree.physics_frame
	var robber: NpcRuntimeState = _first(map, GANGSTER)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var body: CharacterBody2D = map.runtime_player_body()
	var robber_at: Vector2 = map.runtime_body_for_character(robber.character_id).global_position
	var ridge: Rect2 = map.physical_zone(&"cloud.dragonhill.hummock").global_rect()
	var said: int = hud.log_lines().size()
	body.global_position = robber_at + Vector2(0, 60) # TEST-ONLY: in his reach
	player.set_world_location(map.location_for_zone(&"cloud.dragonhill.hummock"))
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.05)
	_check(hud.log_lines().slice(said).has(TOLL_SHOUT) and map.hostilities.toll_pending(robber) and not session.combat_encounter_coordinator().has_active_encounter(), "he shouts at once; his attack still waits: %s" % [hud.log_lines().slice(said)])
	hud.nearby.refresh()
	_check(_status(hud, robber).has("正等着你留下买路财"), "his popup says he waits for the toll: %s" % [_status(hud, robber)])
	var over: Label = map.runtime_body_for_character(robber.character_id).get_node("NameLabel") as Label
	_check(over.get_theme_color("font_color") == WorldCharacterBody2D.ALERT_NAME_COLOR, "and over his head")
	body.global_position = Vector2(ridge.get_center().x, ridge.position.y + 12) # stepped back out of reach
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.05)
	_check(not map.hostilities.toll_pending(robber) and not over.has_theme_color_override("font_color"), "out of his reach: nothing pending, his name plain again")
	said = hud.log_lines().size()
	body.global_position = robber_at + Vector2(0, 60)
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.05)
	_check(not hud.log_lines().slice(said).has(TOLL_SHOUT) and map.hostilities.toll_pending(robber), "back in reach on the same visit: no second shout, his time starts again")
	# Off the ridge and back, paid.
	body.global_position = map.physical_zone(&"cloud.dragonhill.nroad").global_rect().get_center()
	player.set_world_location(map.location_for_zone(&"cloud.dragonhill.nroad"))
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.05)
	_check(not map.hostilities.toll_shouted.has(robber.character_id), "left the ridge: the next visit is a new arrival")
	player.state.marks["强盗"] = 1 # TEST-ONLY: the toll paid
	said = hud.log_lines().size()
	body.global_position = robber_at + Vector2(0, 60)
	player.set_world_location(map.location_for_zone(&"cloud.dragonhill.hummock"))
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.05)
	_check(not hud.log_lines().slice(said).has(TOLL_SHOUT) and not map.hostilities.toll_pending(robber), "paid: no shout, nothing pending")
	hud.nearby.refresh()
	_check(not _status(hud, robber).has("正等着你留下买路财"), "and no waiting")
	player.state.marks.erase("强盗")
	body.global_position = Vector2(ridge.get_center().x, ridge.position.y + 12)
	await tree.physics_frame
	await tree.physics_frame


# --- Helpers ---------------------------------------------------------------------------

class Fives:
	extends RecoveryCadenceRandomSource

	func draw_reset_tick() -> int:
		return 5


func _awake_resident(map: WorldMapController) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and map.runtime_body_for_character(npc.character_id) != null:
			return npc
	return null


## How the interaction popup says `npc` is now (its warmer lines); [] when it is not in reach.
func _status(hud: SharedGameplayUI, npc: NpcRuntimeState) -> Array:
	var thing: WorldNearbyThing = hud.nearby.find(npc.character_id)
	return [] if thing == null else hud.nearby.about(thing)[0]


func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 60.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("响应性: " + label)
