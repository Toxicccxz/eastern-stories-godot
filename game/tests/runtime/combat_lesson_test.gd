extends RefCounted

## 战斗拍数 D (DECISIONS「战斗拍数 D」): a guide's lesson — a LESSON encounter whose blows land
## but draw no blood, whose rounds are counted and whose guide speaks as each begins, the
## beats won counted for the verdict; the beat habits and the wound's school told to the
## one watching; and, in a running Snow session, the whole road: 打听 the town, 请教打法 on
## 李火狮, 拆招 three rounds with him (no kee lost, the verdict said and kept), the 见识录
## grown from it, the doctor reading the wound, 柳淳风's 拜师 greyed with what is short and
## his page's row for the school once its lesson was taken.

const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const ID: StringName = Fixtures.ENCOUNTER_ID
const LIUH: StringName = &"liuh-ken"
const SCHOOL: StringName = &"snow.school_compound.schoolhall.master"

var _assertions: int = 0
var _failures: Array[String] = []
var _habits: Array = []
## The fixture's draw (seeded: blows land and miss as in a fight).
var _random: CombatRandomSource
var _wounds: Array[StringName] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var manual_before: bool = BattlePace.manual_turns
	var stance_before: int = BattlePace.stance
	_test_harmless_rounds()
	_test_notes_in_a_fight()
	await _test_in_town(tree)
	BattlePace.manual_turns = manual_before
	BattlePace.stance = stance_before
	return {"assertions": _assertions, "failures": _failures.duplicate()}


static func _rules() -> CombatDecisionRules:
	return CombatDecisionRules.new(true, true, 20, 50, 2, 3, 2)


static func _modern() -> CombatBeatRules:
	var costs: Dictionary[StringName, int] = {
		CombatMoveTags.QUICK: 1, CombatMoveTags.HEAVY: 2, CombatMoveTags.FEINT: 1, CombatMoveTags.GUARD: 1, CombatBeatRules.COST_PLAIN: 1,
		&"perform/counterattack": 2, &"perform/fakefault": 1, &"perform/swordjab": 2, &"perform/qa": 2,
	}
	return CombatBeatRules.new(2, costs, 1, true, true)


## The scheduler fixture, its encounter a LESSON (the player asked the enemy for its rounds).
func _fixture(lesson: bool) -> Fixtures.SchedulerFixture:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	if lesson:
		var participants: Array[CombatParticipant] = f.encounter.participants()
		var candidates: Array[CombatTriggerCandidate] = []
		for participant: CombatParticipant in participants:
			candidates.append(CombatTriggerCandidate.new(participant.participant_id, participant.side_id))
		var trigger := CombatTrigger.new(&"lesson.fixture", CombatTriggerCause.Value.PLAYER_LESSON, CombatEncounterMode.Value.LESSON, PLAYER, candidates, WorldLocationState.new(&"test", &"arena", &"arena", CombatSliceDemoFactory.ARENA_ID))
		f.encounter = CombatEncounter.new(ID, trigger, participants, f.encounter.hostilities())
		f.encounter.activate()
		f.scheduler = CombatEncounterScheduler.new(f.encounter, CombatSchedulerConfig.new(1.0))
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(Probe.new(&"perform.qa", CombatTacticalRequest.TargetRule.CURRENT_HOSTILE))
	f.scheduler.configure_decisions(_rules())
	f.scheduler.configure_player_tactics(PLAYER, registry)
	f.scheduler.configure_styles(func(_id: StringName) -> CombatStyle: return null)
	f.scheduler.configure_beats(_modern(), func(_id: StringName) -> int: return 2)
	_habits = []
	_wounds = []
	f.scheduler.configure_insights(func(id: StringName, beat: int, tag: StringName) -> void: _habits.append([id, beat, tag]), func(id: StringName) -> void: _wounds.append(id))
	Probe.prepare(f.bindings[0].state)
	f.encounter.set_current_target(PLAYER, ENEMY)
	# A seeded draw: blows land and miss as in a fight (zero draws miss everything).
	_random = GodotCombatRandomSource.new(7, true)
	BattlePace.manual_turns = false
	BattlePace.stance = CombatStance.Value.ATTACK
	return f


func _advance(f: Fixtures.SchedulerFixture, seconds: float = 1.0) -> CombatSchedulerAdvanceResult:
	return f.scheduler.advance(seconds, true, ID, f.bindings, _random, f.effects)


func _chat_lines(result: CombatSchedulerAdvanceResult, actor_id: StringName) -> Array[String]:
	var lines: Array[String] = []
	for event: CombatSchedulerEvent in result.events():
		if event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.actor_id == actor_id and event.chat != null:
			for line: VisionLine in event.chat.lines():
				lines.append(line.template)
	return lines


func _hits(result: CombatSchedulerAdvanceResult) -> int:
	var hits: int = 0
	for event: CombatSchedulerEvent in result.events():
		if event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.resolution != null and event.resolution.forward_result != null:
			var ordinary: CombatOrdinaryAttackResult = event.resolution.forward_result.ordinary_attack_result
			if ordinary != null and ordinary.has_base_result and ordinary.base_result.outcome == CombatAttackResult.Outcome.HIT:
				hits += 1
	return hits


## Under LESSON every blow is harmless: it lands (the skeletons read it) and takes no kee;
## the rounds are counted; the guide's line opens each round; a beat won is counted.
func _test_harmless_rounds() -> void:
	var f: Fixtures.SchedulerFixture = _fixture(true)
	var lines: Array[String] = ["一回合不是一招。", "看我这一拳。", ""]
	_check(f.scheduler.configure_lesson(ENEMY, func(index: int) -> String: return lines[index] if index < lines.size() else ""), "the lesson configured before the first advance")
	f.bindings[1].state.skills.set_raw_level(LIUH, 40)
	var player_kee: int = f.bindings[0].state.vitality.current
	var enemy_kee: int = f.bindings[1].state.vitality.current
	var hits: int = 0
	var rounds: Array[CombatSchedulerAdvanceResult] = []
	for round: int in 3:
		var result: CombatSchedulerAdvanceResult = _advance(f, 1.0)
		rounds.append(result)
		hits += _hits(result)
	_check(hits > 0, "blows landed in three rounds (%d)" % hits)
	_check(f.bindings[0].state.vitality.current == player_kee and f.bindings[1].state.vitality.current == enemy_kee and f.bindings[0].state.vitality.effective == f.bindings[0].state.vitality.maximum, "nobody lost kee or took a wound: %d/%d" % [f.bindings[0].state.vitality.current, f.bindings[1].state.vitality.current])
	_check(f.scheduler.rounds_completed() == 3, "three rounds completed: %d" % f.scheduler.rounds_completed())
	_check(_chat_lines(rounds[0], ENEMY).has("$N说道：一回合不是一招。") and _chat_lines(rounds[1], ENEMY).has("$N说道：看我这一拳。") and not _chat_lines(rounds[2], ENEMY).any(func(line: String) -> bool: return line.begins_with("$N说道：")), "the guide's line as each round begins, none for the empty third: %s" % [_chat_lines(rounds[0], ENEMY)])
	var first_event: CombatSchedulerEvent = rounds[0].events()[0]
	_check(first_event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and first_event.actor_id == ENEMY, "said before anyone acts")
	_check(_wounds.is_empty(), "no blood drawn: no wound noted")
	_check(not _habits.is_empty() and _habits.all(func(note: Array) -> bool: return note[0] == ENEMY and note[1] >= 1 and note[1] <= 2), "the enemy's beats noted by their number (1 or 2), never the player's: %s" % [_habits])
	# A beat won by the school is counted (柳家拳: a landed hit while close).
	var earned: int = f.scheduler.earned_count(ENEMY)
	var won: int = 0
	for round: CombatSchedulerAdvanceResult in rounds:
		for line: String in _chat_lines(round, ENEMY):
			if line.contains("抢得一拍"):
				won += 1
	_check(earned == won, "the beats won are counted as the log says them (%d)" % earned)
	# A plain spar in the same fixture draws blood (the kee goes down).
	var spar: Fixtures.SchedulerFixture = _fixture(false)
	spar.bindings[1].state.skills.set_raw_level(LIUH, 40)
	var before: int = spar.bindings[0].state.vitality.current + spar.bindings[1].state.vitality.current
	for _round: int in 3:
		_advance(spar, 1.0)
	_check(spar.bindings[0].state.vitality.current + spar.bindings[1].state.vitality.current < before and spar.scheduler.rounds_completed() == 3 and _chat_lines(CombatSchedulerAdvanceResult.new(), ENEMY).is_empty(), "outside a lesson the same blows take kee; the rounds are counted all the same")
	_check(not spar.scheduler.configure_lesson(ENEMY, Callable()), "a lesson cannot be configured once the fight ran")


## In a fight (no lesson) the enemy's blows that draw blood name it to the one watching;
## under ES2's one beat nothing is noted.
func _test_notes_in_a_fight() -> void:
	var drew: int = 0
	var seed: int = 0
	# A seed under which the enemy drew blood within eight rounds (the first that does).
	while drew == 0 and seed < 6:
		seed += 1
		var f: Fixtures.SchedulerFixture = _fixture(false)
		_random = GodotCombatRandomSource.new(seed, true)
		f.bindings[1].state.skills.set_raw_level(LIUH, 40)
		for _round: int in 8:
			for event: CombatSchedulerEvent in _advance(f, 1.0).events():
				if event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.actor_id == ENEMY and event.resolution != null and event.resolution.forward_result != null:
					var ordinary: CombatOrdinaryAttackResult = event.resolution.forward_result.ordinary_attack_result
					if ordinary != null and ordinary.has_base_result and ordinary.base_result.outcome == CombatAttackResult.Outcome.HIT and ordinary.base_result.resource_mutation != null and ordinary.base_result.resource_mutation.requested_damage > 0:
						drew += 1
	_check(drew > 0 and _wounds.size() == drew and _wounds.all(func(id: StringName) -> bool: return id == ENEMY), "every blow of the enemy's that drew the player's blood is noted (%d of %d, seed %d): %s" % [_wounds.size(), drew, seed, _wounds])
	var classic: Fixtures.SchedulerFixture = Fixtures.new()._fixture(false)
	classic.scheduler.configure_decisions(CombatDecisionRules.classic())
	classic.scheduler.configure_insights(func(id: StringName, beat: int, tag: StringName) -> void: _habits.append([id, beat, tag]), func(id: StringName) -> void: _wounds.append(id))
	_habits = []
	_wounds = []
	classic.encounter.set_current_target(PLAYER, ENEMY)
	classic.scheduler.advance(3.0, true, ID, classic.bindings, classic.random, classic.effects)
	_check(_habits.is_empty() and _wounds.is_empty(), "经典 (识招 off): nothing noted")


## The whole road in Snow.
func _test_in_town(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	for _n: int in 20:
		await tree.process_frame
	session.set_process(false)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	var hud: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	state.vitality = CharacterResourceState.new(300, 300, 300)
	# 李火狮 on the training ground: 请教打法 and 拆招 among his rows.
	var map: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.fist_trainer.1")
	var trainer: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school2.fist_trainer.1")
	_check(map != null and trainer != null, "on the training ground with 李火狮")
	if map == null or trainer == null:
		session.free()
		return
	await _stand_by(tree, map, player, trainer)
	hud.refresh_exploration()
	var labels: Array[String] = hud.nearby.actions_of(trainer.short_name())
	_check(labels.has("请教打法") and labels.has("拆招") and labels.has("打听") and labels.find("请教打法") < labels.find("拆招"), "his rows: %s" % [labels])
	var rows: Array[InteractionOption] = hud.nearby.options_for(map, hud.nearby.find(trainer.character_id))
	var lesson_row: InteractionOption = rows.filter(func(row: InteractionOption) -> bool: return row.label == "拆招")[0]
	_check(lesson_row.hint.contains("三回合") and lesson_row.available(), "拆招's hover says what it is")
	# 请教打法: his 打听 opened on 打法; the lines heard are kept.
	_check(map.select_npc(trainer.character_id) and map.ask_topics_selected().has("打法"), "打法 among his topics: %s" % [map.ask_topics_selected()])
	var taught: Array[String] = map.ask_selected("打法")
	_check(taught.size() == 5 and taught[1].contains("柳家拳没什么花样") and taught[4].contains("胆识 20、定力 20"), "李火狮 teaches in his own words, the master's conditions in them: %s" % [taught])
	_check(CombatInsights.taught(state, LIUH), "kept on the 见识录")
	# Refusals in his words: hurt, or of another family.
	var guide: FamilyDefinition.SchoolGuide = map.selection.selected_guide()
	_check(guide != null and map.selection.lesson_refusal(trainer, guide).is_empty(), "a whole commoner is taken on")
	state.vitality = CharacterResourceState.new(300, 150, 300)
	_check(map.selection.lesson_refusal(trainer, guide) == guide.refuse_hurt, "hurt: refused in his words")
	state.vitality = CharacterResourceState.new(300, 300, 300)
	state.family.family_id = &"family.zhenyuan"
	_check(map.selection.lesson_refusal(trainer, guide) == guide.refuse_family, "another family's member: refused")
	hud.refresh_exploration()
	var greyed: Array[InteractionOption] = hud.nearby.options_for(map, hud.nearby.find(trainer.character_id)).filter(func(row: InteractionOption) -> bool: return row.label == "拆招")
	_check(greyed.size() == 1 and not greyed[0].available() and greyed[0].reason == guide.refuse_family, "the row greyed with his words: %s" % (greyed[0].reason if not greyed.is_empty() else "-"))
	state.family.family_id = &"family.fonxan"
	_check(map.selection.lesson_refusal(trainer, guide).is_empty(), "his own family's member: taken on")
	state.family.family_id = &""
	# 拆招: three rounds, no kee lost on either side, the verdict said and kept.
	BattlePace.manual_turns = false
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var trainer_kee: int = trainer.character_state.vitality.current
	var started: CombatSliceInitiationResult = map.selection.lesson_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED and coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.LESSON and coordinator.lesson_guide() == guide, "the lesson began as its own kind of fight")
	var said: Array[String] = []
	var steps: int = 0
	while coordinator.has_active_encounter() and steps < 12:
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		said.append_array(_chat_lines(advanced, trainer.character_id))
		steps += 1
	var receipt: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(not coordinator.has_active_encounter() and receipt != null and receipt.succeeded() and receipt.terminal_result.kind == CombatEncounterResultKind.Value.LESSON_CONCLUDED and steps <= 4, "over after three rounds (%d steps), concluded as a lesson" % steps)
	_check(state.vitality.current == 300 and state.vitality.effective == 300 and trainer.character_state.vitality.current == trainer_kee, "nobody lost kee: %d / %d" % [state.vitality.current, trainer.character_state.vitality.current])
	_check(said.any(func(line: String) -> bool: return line.contains("一回合不是一招")) and said.any(func(line: String) -> bool: return line.contains("最后一回合")), "his three lines as the rounds began: %s" % [said])
	var verdict: int = CombatInsights.lesson_verdict(state, LIUH)
	_check(verdict != 0 and hud.message_log.log_lines().any(func(line: String) -> bool: return line.begins_with("李火狮说道：") and line.contains(CombatInsights.verdict_line(guide, verdict).left(8))), "his verdict (%d) said and kept: %s" % [verdict, hud.message_log.log_lines().slice(-3)])
	_check(state.insights.keys().any(func(key: String) -> bool: return key.begins_with("habit/snow.npc.fist_trainer/liuh-ken/")), "his beats noted under his school: %s" % [state.insights.keys()])
	_check(CombatInsights.wounded_by(state).is_empty(), "no wound from a lesson")
	# The 见识录 of 柳家拳 grew from the road: the way (his moves watched three times), the
	# teaching, the verdict.
	var entry: CodexContent.Entry = null
	for candidate: CodexContent.Entry in CodexContent.entries(CodexContent.Section.ARTS, state, catalog):
		if candidate.key == "moves/liuh-ken":
			entry = candidate
	_check(entry != null and entry.text().contains("打法 · 抢压：") and entry.text().contains("李火狮讲过：") and entry.text().contains("李火狮拆过招，说：") and not entry.text().contains("见过 0 次"), "柳家拳's 见识录 entry: %s" % ("-" if entry == null else entry.text()))
	# The doctor reads the wound's school; the woodcutter beside him says his line.
	CombatInsights.set_wounded_by(state, LIUH)
	var shop: WorldMapController = MapPlaces.enter(session, &"snow.herbshop", &"snow.herbshop.herbalist.1")
	var doctor: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.herbshop.herbalist.1")
	var woodcutter: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.herbshop.woodcutter.1")
	_check(shop != null and doctor != null and woodcutter != null, "in the herb shop with 杨掌柜 and the woodcutter")
	if shop != null and doctor != null and woodcutter != null:
		await _stand_by(tree, shop, player, doctor)
		_check(shop.select_npc(doctor.character_id) and shop.ask_selected("伤口").any(func(line: String) -> bool: return line.contains("拳伤")) and CombatInsights.has_heard(state, "hearsay/liuh-ken/5"), "杨掌柜 reads a fist's wound and the line is kept")
		state.marks.erase("wounded_by/liuh-ken")
		_check(shop.ask_selected("伤口").any(func(line: String) -> bool: return line.contains("没什么新伤")), "unhurt: nothing to read")
		await _stand_by(tree, shop, player, woodcutter)
		_check(shop.select_npc(woodcutter.character_id) and shop.ask_selected("柳家拳").any(func(line: String) -> bool: return line.contains("贴上去")) and CombatInsights.has_heard(state, "hearsay/liuh-ken/1"), "the woodcutter's hearsay heard and kept")
	# 柳淳风's 拜师: greyed with what is short; his page's row for the school whose lesson was taken.
	var hall: WorldMapController = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	var master: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.schoolhall.master.1")
	_check(hall != null and master != null, "in the hall with 柳淳风")
	if hall != null and master != null:
		await _stand_by(tree, hall, player, master)
		state.attributes.courage = 30 # TEST-ONLY
		state.attributes.composure = 10
		hud.refresh_exploration()
		var apprentice: Array[InteractionOption] = hud.nearby.options_for(hall, hud.nearby.find(master.character_id)).filter(func(row: InteractionOption) -> bool: return row.label == "拜师")
		_check(apprentice.size() == 1 and not apprentice[0].available() and apprentice[0].reason == "还差：定力 ≥ 20（你 %d）" % NpcApprenticeship.requirement_value(state, &"cps"), "拜师 greyed with what is short: %s" % (apprentice[0].reason if not apprentice.is_empty() else "-"))
		state.attributes.composure = 30
		hud.refresh_exploration()
		apprentice = hud.nearby.options_for(hall, hud.nearby.find(master.character_id)).filter(func(row: InteractionOption) -> bool: return row.label == "拜师")
		_check(apprentice.size() == 1 and apprentice[0].available(), "both met: 拜师 can be pressed")
		var school: TeacherService = hall.service(SCHOOL) as TeacherService
		var profile: String = "" if school == null else hud.nearby._profile(school)
		_check(profile.contains("柳家拳：先打实一拳") and not profile.contains("封山剑法："), "his page: 柳家拳's way (its lesson taken), nothing of 封山剑法 yet: %s" % profile)
	session.free()
	await tree.process_frame


## The player stands beside `npc` (as a visitor walks up to them).
func _stand_by(tree: SceneTree, map: WorldMapController, player: WorldPlayerRuntimeState, npc: NpcRuntimeState) -> void:
	var body: Node2D = map.runtime_body_for_character(npc.character_id)
	var placed: bool = body != null
	if placed:
		placed = false
		for offset: Vector2 in [Vector2(0, 56), Vector2(56, 0), Vector2(-56, 0), Vector2(0, -56), Vector2(40, 40), Vector2(-40, 40)]:
			if map.place_player(npc.world_location().zone_id, body.global_position + offset):
				placed = true
				break
	_check(placed, "standing beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.process_frame
	player.set_world_location(map.location_for_zone(npc.world_location().zone_id))


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("combat lesson: " + label)
