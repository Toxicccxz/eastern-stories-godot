extends RefCounted

## The player's perform with 封山剑法 (cmds/std/perform.c): 「封」 counterattack.c,
## 「逐」 swordjab.c and 「缺」 fakefault.c, use as practice. Core files with scripted
## draws and recorded attacks first, then real do_attack()s between two fighters,
## then a Snow session: the battle panel's actions, the queue waiting while busy,
## each 字诀 against a trainee, 「缺」's strike when it ends in the fight and its quiet
## end outside one.
## TEST-ONLY fixtures, each marked where used: characters built by hand, skill
## levels, combat experience, resources, the random sources.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")


## do_attack() as a special file asks for it, recorded with the performer's applies
## at that moment; no attack really runs.
class Recorder extends SpecialAttackSource:
	var calls: Array[String] = []
	var applies: Array[String] = []
	var watched: CharacterState

	func attack(attacker_id: StringName, victim_id: StringName) -> SpecialAttack:
		calls.append("%s>%s" % [attacker_id, victim_id])
		if watched != null:
			var timed: CharacterTimedApplies = watched.timed_applies
			applies.append("%d/%d/%d" % [timed.value(&"attack"), timed.value(&"damage"), timed.value(&"dodge")])
		return SpecialAttack.new(attacker_id, victim_id)


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog
var _session: OldPineWorldSessionController
var _player: WorldPlayerRuntimeState
var _ui: BattlePresentationController
var _coordinator: CombatEncounterCoordinator
var _requests: int = 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_content()
	_test_offered()
	_test_perform_command()
	_test_swordjab()
	_test_fakefault()
	_test_remove_effect()
	_test_timed_entries()
	_test_real_attacks()
	_test_attribution()
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	_coordinator = _session.combat_encounter_coordinator()
	await _arm(tree)
	await _test_fight(tree)
	await _test_downed_target(tree)
	await _test_fakefault_outlives_its_fight(tree)
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Content and the command ---------------------------------------------------------

func _test_content() -> void:
	var labels: Array[String] = []
	for function_id: StringName in SpecialFunctions.PERFORMS:
		labels.append(SpecialFunctions.perform(function_id).label)
	_check(labels == ["「封」字诀", "「逐」字诀", "「缺」字诀"], "doc/skill/fonxansword names them: " + str(labels))
	_check(SpecialFunctions.perform(&"powerfocus") == null, "「点」字诀 (powerfocus) has no file")
	var catalog := BattleActionPresentationCatalog.new()
	_check(catalog.label_for(CombatPerformTacticalPolicy.action_id_for(&"swordjab")) == "使出「逐」字诀", "the battle button: " + catalog.label_for(&"perform.swordjab"))
	_check(SpecialFunctions.ending(&"fonxansword") is FakefaultPerform and SpecialFunctions.ending(&"powerup") == null, "fakefault.c ends its own timed apply; powerup is an exert")


func _test_offered() -> void:
	var state: CharacterState = _fighter(1000)
	_check(PerformService.offered(state, _catalog).is_empty(), "bare-handed: perform reads unarmed, nothing")
	state.equipment.wield(Martial.sword(), false)
	_check(PerformService.offered(state, _catalog) == [&"counterattack", &"swordjab", &"fakefault"], "a sword with 封山剑法 enabled: the three")
	state.skills.unmap_skill(&"sword")
	_check(PerformService.offered(state, _catalog).is_empty(), "封山剑法 not enabled for sword: none")
	var policy := CombatPerformTacticalPolicy.new(&"fakefault")
	_check(policy.category == CombatTacticalRequest.Category.MARTIAL_SPECIAL and policy.target_rule == CombatTacticalRequest.TargetRule.CURRENT_HOSTILE and policy.blocks_when_busy, "a 字诀 targets the current enemy and waits while busy")


func _test_perform_command() -> void:
	var sides: Array[SpecialSide] = _pair(1000, 10)
	var me: SpecialSide = sides[0]
	var npc: SpecialSide = sides[1]
	me.busy.start_busy(1)
	var context := _context(me, npc, Specials.Pattern.new())
	_check(not PerformService.perform(context, &"counterattack") and context.report().lines()[0].template == "( 你上一个动作还没有完成，不能施用外功。)", "busy: perform.c's refusal")
	me.busy.advance()
	me.state.skills.unmap_skill(&"sword")
	context = _context(me, npc, Specials.Pattern.new())
	_check(not PerformService.perform(context, &"counterattack") and context.fail_line.template == "你请先用 enable 指令选择你要使用的外功。", "nothing enabled for the sword")
	me.state.skills.map_skill(&"sword", &"fonxansword")
	var random := Specials.Pattern.new([999, 49])
	context = _context(me, npc, random)
	var progress: int = me.state.skills.learned_progress(&"fonxansword")
	_check(PerformService.perform(context, &"counterattack"), "「封」 against the named target")
	_check(random.calls == 2 and npc.busy.busy_value == 4 and me.busy.busy_value == 1, "no offensive_target() draw; the target busy 100 / 2 / 20 + 2 = 4: %d" % npc.busy.busy_value)
	_check(me.state.skills.learned_progress(&"fonxansword") == progress + 1 and me.state.skills.raw_level(&"fonxansword") == 100, "random(120) 49 < query_skill(fonxansword) 50: practised in weak mode, no level")
	me.busy.advance()
	random = Specials.Pattern.new([999, 50])
	context = _context(me, _pair(1000, 10)[1], random)
	PerformService.perform(context, &"counterattack")
	_check(me.state.skills.learned_progress(&"fonxansword") == progress + 1, "random(120) 50 is not below 50: no practice")
	me.busy.advance()
	random = Specials.Pattern.new([999, 0])
	context = _context(me, npc, random)
	_check(not PerformService.perform(context, &"counterattack") and random.calls == 0, "a busy target refuses before any draw: no practice either")
	_check(context.report().lines().size() == 1 and context.report().lines()[0].template == "$n目前正自顾不暇，放胆攻击吧！", "the file's own refusal is the last notify_fail()")


# --- 「逐」 -------------------------------------------------------------------------------

func _test_swordjab() -> void:
	var counts: Dictionary = {1: [999, 0, 0, 119], 2: [999, 1, 1, 0, 119], 3: [999, 2, 2, 2, 2, 119]}
	for expected: int in counts:
		var sides: Array[SpecialSide] = _pair(1000, 10)
		var draws: Array[int] = []
		draws.assign(counts[expected])
		var random := Specials.Pattern.new(draws)
		var recorder := Recorder.new()
		var context := _context(sides[0], sides[1], random, recorder)
		_check(PerformService.perform(context, &"swordjab"), "「逐」 performs")
		_check(recorder.calls.size() == expected and random.calls == expected + 3, "i < random(3) + 1 drawn before each attack: %d attacks, %d draws" % [recorder.calls.size(), random.calls])
		_check(context.attacks.size() == expected and context.attacks[0].line_index == 1 and recorder.calls[0] == "player>npc", "owner: the line first, then the attacks")
		_check(context.lines[0].template == "$N使出封山剑法「逐」字诀，剑法一紧，剑光罩向$n，$p已显吃力。" and context.lines[0].color == ColoredLine.CYN, "its line in CYN")
		_check(sides[0].state.vitality.effective == 190 and sides[0].state.vitality.current == 190 and not sides[0].busy.is_busy(), "eff_kee - 10 (kee follows it down), no busy")
	var sides: Array[SpecialSide] = _pair(1000, 1500)
	var recorder := Recorder.new()
	var context := _context(sides[0], sides[1], Specials.Pattern.new([999, 119]), recorder)
	_check(PerformService.perform(context, &"swordjab") and recorder.calls.is_empty(), "random(exp) 999 not above 1500 * 2 / 3: no attack")
	_check(context.lines[0].template.ends_with("$p从容化解") and sides[0].state.vitality.effective == 190, "从容化解, and eff_kee - 10 all the same")
	sides = _pair(1000, 10)
	sides[0].state.vitality = CharacterResourceState.new(5, 5, 200)
	PerformService.perform(_context(sides[0], sides[1], Specials.Pattern.new([999, 0, 119])), &"swordjab")
	_check(sides[0].state.is_death_threshold_reached(), "eff_kee below zero: char.c heart_beat() kills")
	sides = _pair(1000, 10)
	sides[0].relationship.remove_opponent(&"npc")
	context = _context(sides[0], sides[1], Specials.Pattern.new())
	_check(not PerformService.perform(context, &"swordjab") and context.fail_line.template == "「逐」字诀只能对战斗中的对手使用。" and sides[0].state.vitality.effective == 200, "not fighting the target: refused, nothing spent")


# --- 「缺」 -------------------------------------------------------------------------------

func _test_fakefault() -> void:
	var cases: Array = [[100, 100, 7], [0, 0, 10], [200, 200, 2], [300, 300, 2]]
	for case: Array in cases:
		var sides: Array[SpecialSide] = _pair(1000, 10, case[0], case[1])
		var context := _context(sides[0], sides[1], Specials.Pattern.new([999, 119]))
		var skill: int = case[2]
		_check(PerformService.perform(context, &"fakefault"), "「缺」 performs")
		var timed: CharacterTimedApplies = sides[0].state.timed_applies
		var entry: CharacterTimedApplies.Entry = timed.entries()[0]
		_check(
			timed.value(&"attack") == -skill * 3 and timed.value(&"dodge") == (12 - skill) * 5 and entry.remaining_ms == skill * 1000 and entry.target_id == &"npc",
			"sword %d, 封山剑法 %d: skill %d, attack %d, dodge %d for %d ms" % [case[0], case[1], skill, timed.value(&"attack"), timed.value(&"dodge"), entry.remaining_ms],
		)
		_check(not sides[0].busy.is_busy() and context.lines.size() == 1 and context.lines[0].template == "$N剑招陡变，空门大开，诱使$n进招，", "no busy, one line")
	var sides: Array[SpecialSide] = _pair(1000, 10)
	PerformService.perform(_context(sides[0], sides[1], Specials.Pattern.new([999, 119])), &"fakefault")
	var context := _context(sides[0], sides[1], Specials.Pattern.new([999, 119]))
	_check(not PerformService.perform(context, &"fakefault") and context.fail_line.template == "你已经在运用中了。" and sides[0].state.timed_applies.entries().size() == 1, "owner: one at a time")
	sides = _pair(1000, 2000)
	context = _context(sides[0], sides[1], Specials.Pattern.new([999, 119]))
	_check(PerformService.perform(context, &"fakefault") and sides[0].state.timed_applies.is_empty() and sides[0].busy.busy_value == 1, "random(exp) 999 not above 2000 / 2: busy 1, nothing applied")
	_check(context.lines.size() == 2 and context.lines[1].template == "可是$n看破了$N的企图，并没有上当。", "seen through")
	sides = _pair(1000, 10)
	sides[1].living = false
	context = _context(sides[0], sides[1], Specials.Pattern.new())
	_check(not PerformService.perform(context, &"fakefault") and context.fail_line.template == "你要对谁使用'缺'字诀？", "an unconscious target")
	sides[1].living = true
	sides[1].location_id = &"elsewhere"
	context = _context(sides[0], sides[1], Specials.Pattern.new())
	_check(not PerformService.perform(context, &"fakefault") and context.fail_line.template == "你要对谁使用'缺'字诀？", "a target elsewhere")
	sides = _pair(1000, 10)
	sides[0].relationship.remove_opponent(&"npc")
	context = _context(sides[0], sides[1], Specials.Pattern.new())
	_check(not PerformService.perform(context, &"fakefault") and context.fail_line.template == "'缺'字诀只能在战斗中使用。", "not fighting the target")


func _test_remove_effect() -> void:
	var sides: Array[SpecialSide] = _pair(1000, 10)
	var me: SpecialSide = sides[0]
	PerformService.perform(_context(me, sides[1], Specials.Pattern.new([999, 119])), &"fakefault")
	var ended: Array[CharacterTimedApplies.Entry] = me.state.timed_applies.advance_entries(7000)
	_check(ended.size() == 1 and ended[0].target_id == &"npc" and me.state.timed_applies.value(&"attack") == 0, "seven seconds later the entry ends, its applies gone")
	var recorder := Recorder.new()
	recorder.watched = me.state
	var context := _context(me, sides[1], Specials.Pattern.new(), recorder)
	SpecialFunctions.ending(ended[0].effect_id).remove_effect(context, ended[0])
	_check(context.lines.size() == 1 and context.lines[0].template == "$N突然对$n发出奋力一击！" and context.lines[0].color == ColoredLine.CYN, "奋力一击")
	_check(recorder.calls == ["player>npc", "npc>player"], "one attack each way: " + str(recorder.calls))
	_check(recorder.applies == ["50/15/25", "50/15/25"], "skill 7: attack (12 - 7) * 10, damage (12 - 7) * 3, the dodge still on: " + str(recorder.applies))
	_check(me.state.timed_applies.value(&"attack") == 0 and me.state.timed_applies.value(&"damage") == 0 and me.state.timed_applies.value(&"dodge") == 0, "then all taken back")
	for case: String in ["target unconscious", "target elsewhere", "performer unconscious"]:
		sides = _pair(1000, 10)
		if case == "target unconscious":
			sides[1].living = false
		elif case == "target elsewhere":
			sides[1].location_id = &"elsewhere"
		else:
			sides[0].living = false
		recorder = Recorder.new()
		context = _context(sides[0], sides[1], Specials.Pattern.new(), recorder)
		SpecialFunctions.ending(&"fonxansword").remove_effect(context, ended[0])
		_check(context.lines.is_empty() and recorder.calls.is_empty(), "%s: the applies just go back" % case)


func _test_timed_entries() -> void:
	var timed := CharacterTimedApplies.new()
	timed.start(&"a", {&"attack": -21}, 2000, &"npc")
	_check(timed.entries()[0].target_id == &"npc" and timed.advance(1000).is_empty() and timed.advance(1000) == [&"a"], "advance() still names what ended")
	timed.hold({&"attack": 50, &"dodge": 25})
	timed.hold({&"attack": 5})
	timed.release({&"attack": 50, &"dodge": 25})
	_check(timed.value(&"attack") == 5 and timed.value(&"dodge") == 0 and timed.is_empty(), "hold() adds for the moment, release() takes it back")
	timed.release({&"attack": 5})
	_check(timed.value(&"attack") == 0, "nothing held")


# --- Real attacks -------------------------------------------------------------------------

## A sword and 封山剑法 against a bare-handed fighter in a spar, every draw the
## highest: three real do_attack()s land, told after the line as ordinary blows are.
## The first decides the spar (winner_msg, both stop fighting); the others still land,
## as do_attack() asks nobody whether they fight.
func _test_real_attacks() -> void:
	var player_state: CharacterState = _fighter(1000000)
	player_state.equipment.wield(Martial.sword(), false)
	var player := Martial.binding(&"player", player_state)
	var npc_state: CharacterState = _fighter(10)
	npc_state.vitality = CharacterResourceState.new(5000, 5000, 5000)
	var npc := Martial.binding(&"npc", npc_state, false)
	player.relationship.add_opponent(&"npc")
	npc.relationship.add_opponent(&"player")
	var bindings: Array[CombatSliceCharacterBinding] = [player, npc]
	var random := Specials.Pattern.new()
	var effects := SkillImprovementEffectRegistry.new()
	var context: SpecialContext = CombatSpecialAttackSource.context_for(player, bindings, random, effects)
	context.target = context.other(&"npc")
	_check(context.enemies.size() == 1 and context.target != null and context.target.location_id == &"test", "the fight as the files see it")
	_check(PerformService.perform(context, &"swordjab"), "「逐」 with real attacks")
	var report: SpecialReport = context.report()
	_check(report.attacks().size() == 3 and report.is_complete(), "three attacks, each chain complete")
	_check(npc_state.vitality.current < 5000 and report.last_hitter(&"npc") == &"player", "they hurt the target; its last_damage_from is the player")
	var winners: int = 0
	for attack: SpecialAttack in report.attacks():
		if attack.forward.post_relationship_result.has_winner_presentation_index:
			winners += 1
	_check(winners == 1 and report.attacks()[0].forward.post_relationship_result.has_winner_presentation_index, "the first blow decides the spar, once")
	_check(not player.relationship.is_fighting() and not npc.relationship.is_fighting(), "both stop fighting")
	var cast := BattlePresentationProjection.new(&"test", CombatEncounterMode.Value.SPAR, &"player", &"npc", [
		BattleParticipantProjection.new(&"player", "你"), BattleParticipantProjection.new(&"npc", "学徒"),
	])
	var told: Array[BattleNarrationLine] = BattleNarrator.new().special(report, cast)
	_check(told.size() >= 4 and told[0].text.contains("「逐」字诀") and told[0].color == ColoredLine.CYN, "the line first: " + (told[0].text if not told.is_empty() else ""))
	var hits: int = 0
	for line: BattleNarrationLine in told:
		if line.damage > 0:
			hits += 1
	_check(hits == 3, "then three blows with their damage: %d" % hits)


## damage.c last_damage_from for a special's victims: its last landed blow, else the
## performer when the file hurt them, through the fight's lifecycle check.
func _test_attribution() -> void:
	var report := SpecialReport.new(&"player", [], [], [&"npc"])
	_check(report.last_hitter(&"npc") == &"player" and report.last_hitter(&"player") == &"", "a file's own damage is the performer's")
	var event := CombatSchedulerEvent.new(1, 1, 1.0, CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED, CombatSchedulerEvent.SkipReason.NONE, &"player", &"npc", null, 1, null, report)
	_check(event.is_valid() and CombatEncounterResolution.last_hitter(event, &"npc") == &"player", "a timed special's end is an event the lifecycle reads")
	var tactical := CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED, &"swordjab", [], report)
	_check(CombatEncounterResolution._special_of(null, tactical) == report and tactical.duplicate_snapshot().special == report, "and so is a perform's result")
	var unfinished := SpecialReport.new(&"player", [], [SpecialAttack.new(&"player", &"npc")])
	_check(not unfinished.is_complete(), "an attack whose chain did not finish fails the fight's check")


# --- Snow --------------------------------------------------------------------------------

## TEST-ONLY: sword and 封山剑法 at 100 (enabled), a million combat_exp and plenty of
## everything; then the 竹剑 from the weapon storage, wielded.
func _arm(tree: SceneTree) -> void:
	var state: CharacterState = _player.state
	state.skills.set_raw_level(&"sword", 100)
	state.skills.set_raw_level(&"fonxansword", 100)
	state.skills.map_skill(&"sword", &"fonxansword")
	state.progression.combat_experience = 1000000
	state.essence = CharacterResourceState.new(5000, 5000, 5000)
	state.vitality = CharacterResourceState.new(5000, 5000, 5000)
	state.spirit = CharacterResourceState.new(5000, 5000, 5000)
	var map: WorldMapController = _session.active_map() as WorldMapController
	var sword: StringName = ItemSpawnDefinition.item_instance_id(_session.item_id_allocator().scope, &"snow.weapon_storage.bamboo_sword.1")
	_check(_beside(map, &"snow.weapon_storage", &"snow.weapon_storage.bamboo_sword.1") and map.select_floor_item(sword) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the 竹剑 taken")
	await tree.physics_frame
	_check(not _offered().has(&"perform.swordjab"), "not in hand yet: no 字诀")
	_check(_session.wield_player_item(sword) != null and _player.state.equipment.primary_weapon_skill_type() == &"sword", "the 竹剑 wielded")
	_check(_offered() == [&"perform.counterattack", &"perform.swordjab", &"perform.fakefault"], "the three 字诀 offered: " + str(_offered()))


## A lethal fight with a trainee (TEST-ONLY: kee to last, every draw the highest):
## 「封」 before any round (no target picked yet: offensive_target()) holds him, 「逐」
## waits while the player is busy and then strikes three times after its line, 「缺」
## against the current target ends seven rounds later with the strike both ways.
func _test_fight(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.1"), "beside a trainee")
	await tree.physics_frame
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.1")
	trainee.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	map.select_npc(trainee.character_id)
	_session.configure_combat_random_source(Specials.Pattern.new())
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the trainee")
	var scheduler: CombatEncounterScheduler = _coordinator.active_scheduler()
	_check(_coordinator.active_encounter().current_target_for(_player.character_id).is_empty(), "no target picked before the first round")
	_check(_submit(&"perform.counterattack") == CombatTacticalResult.Code.ACCEPTED, "「封」 queued all the same (perform <action>)")
	_coordinator.advance_scheduler(0.0)
	_ui.refresh_projection()
	_check(trainee.busy.busy_value == 4 and _player.busy.busy_value == 1, "「封」 runs between rounds: the trainee busy 4, the player 1")
	var held: CombatTacticalEvent = _last_resolved(scheduler)
	_check(held != null and held.action.resolved_target_id.is_empty() and held.execution.special.lines()[0].target_id == trainee.character_id, "queued with no target: offensive_target() found the trainee")
	_check(_log().contains("你使出封山剑法「封」字诀") and _log().contains("措手不及"), "its line in the battle log")
	_check(_submit(&"perform.swordjab") == CombatTacticalResult.Code.ACCEPTED, "「逐」 queued")
	_coordinator.advance_scheduler(0.0)
	_check(scheduler.player_tactics().queue_status() == CombatQueuedAction.Status.WAITING_FOR_BUSY and _player.state.vitality.effective == 5000, "it waits while the player is busy")
	_coordinator.advance_scheduler(1.0)
	_coordinator.advance_scheduler(0.0)
	_ui.refresh_projection()
	_check(_coordinator.active_encounter().queued_player_action() == null and _player.state.vitality.effective == 4990, "then runs: eff_kee 4990 (%d)" % _player.state.vitality.effective)
	var jab: CombatTacticalEvent = _last_resolved(scheduler)
	_check(jab != null and jab.execution.special != null and jab.execution.special.attacks().size() == 3, "three attacks at the highest draws")
	var text: String = _log()
	var line: int = text.find("你使出封山剑法「逐」字诀")
	_check(line >= 0 and text.find("竹剑", line) > line, "the line, then the blows with the 竹剑")
	var round_ms_before: int = 0
	_coordinator.advance_scheduler(1.0)
	_check(_coordinator.active_encounter().current_target_for(_player.character_id) == trainee.character_id, "a round later the trainee is the current target")
	_check(_submit(&"perform.fakefault") == CombatTacticalResult.Code.ACCEPTED, "「缺」 queued against him")
	_coordinator.advance_scheduler(0.0)
	var timed: CharacterTimedApplies = _player.state.timed_applies
	_check(timed.value(&"attack") == -21 and timed.value(&"dodge") == 25 and timed.entries()[0].target_id == trainee.character_id, "「缺」: query_skill(sword) 150, skill 7")
	var order: int = scheduler.events_after(0).back().progression_order
	var strike: CombatSchedulerEvent = null
	for _round: int in range(7):
		round_ms_before = timed.entries()[0].remaining_ms if not timed.is_empty() else 0
		_coordinator.advance_scheduler(1.0)
		for event: CombatSchedulerEvent in scheduler.events_after(order):
			order = event.progression_order
			if event.kind == CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED:
				strike = event
		if strike != null:
			break
	_ui.refresh_projection()
	_check(strike != null and round_ms_before == 1000 and timed.is_empty() and timed.value(&"attack") == 0, "seven rounds later it ends at the start of a round")
	_check(strike != null and strike.special.attacks().size() == 2 and strike.special.is_complete() and strike.target_id == trainee.character_id, "the strike: one attack each way")
	_check(_log().contains("你突然对") and _log().contains("发出奋力一击！"), "奋力一击 in the battle log")
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "nothing aborted: " + _coordinator.last_abort_detail())
	_check(_coordinator.has_active_encounter(), "the fight goes on")


## A killer still fights its unconscious victim (TEST-ONLY: the trainee's kee below
## zero): 「缺」 refuses him, 「逐」 strikes him and he dies of it.
func _test_downed_target(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.1")
	var scheduler: CombatEncounterScheduler = _coordinator.active_scheduler()
	trainee.character_state.vitality.current = -1
	_coordinator.advance_scheduler(0.0)
	_check(trainee.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and _coordinator.has_active_encounter(), "the trainee falls; the fight to the death goes on")
	_check(_coordinator.active_encounter().current_target_for(_player.character_id) == trainee.character_id, "and he is still the player's target")
	_check(_submit(&"perform.fakefault") == CombatTacticalResult.Code.ACCEPTED, "「缺」 may name him")
	_coordinator.advance_scheduler(0.0)
	var refused: CombatTacticalEvent = _last_resolved(scheduler)
	_check(refused.execution.outcome == CombatTacticalExecutionResult.Outcome.FAILED and refused.execution.special.lines()[0].template == "你要对谁使用'缺'字诀？" and _player.state.timed_applies.is_empty(), "but fakefault.c refuses an unconscious target")
	_check(_submit(&"perform.swordjab") == CombatTacticalResult.Code.ACCEPTED, "「逐」 at him")
	_coordinator.advance_scheduler(0.0)
	var jab: CombatTacticalEvent = _last_resolved(scheduler)
	_check(jab.execution.special.attacks().size() == 3 and jab.execution.special.is_complete(), "swordjab.c only asks is_fighting(): three blows land")
	_check(trainee.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "he dies of them (%s)" % CharacterRuntimeLifeStatus.Value.find_key(trainee.life_status))
	for _second: int in range(5):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight is won: " + _coordinator.last_abort_detail())
	await tree.process_frame


## 「缺」 outliving its fight (a spar decided by the first blow, both standing):
## owner, it strikes nobody in the next fight with the same trainee, and on world
## time it only takes its applies back.
func _test_fakefault_outlives_its_fight(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.2")
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.2"), "beside another trainee")
	await tree.physics_frame
	# TEST-ONLY: he lasts the next fight.
	trainee.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	var timed: CharacterTimedApplies = _player.state.timed_applies
	_spar_with_fakefault(trainee)
	_check(timed.entries().size() == 1 and timed.entries()[0].target_id.is_empty(), "「缺」 outlives the spar and forgets whom it named")
	map.select_npc(trainee.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a new fight with the same trainee")
	var scheduler: CombatEncounterScheduler = _coordinator.active_scheduler()
	var strikes: int = 0
	for _round: int in range(8):
		_coordinator.advance_scheduler(1.0)
		if timed.is_empty():
			break
	for event: CombatSchedulerEvent in scheduler.events_after(0):
		if event.kind == CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED:
			strikes += 1
	_check(timed.is_empty() and _coordinator.has_active_encounter(), "it ends during the new fight")
	_check(strikes == 0, "without a strike")
	trainee.character_state.vitality = CharacterResourceState.new(-1, -1, 100000) # TEST-ONLY: end it.
	for _second: int in range(5):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "that fight is over: " + _coordinator.last_abort_detail())
	var other: NpcRuntimeState = _npc(map, &"snow.school2.trainee.3")
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.3"), "beside a third trainee")
	await tree.physics_frame
	_spar_with_fakefault(other)
	_check(timed.entries().size() == 1, "「缺」 running after the spar")
	_session.advance_player_timed_applies(10.0)
	_check(timed.is_empty() and timed.value(&"attack") == 0 and timed.value(&"dodge") == 0, "world time ends it: attack and dodge back")
	await tree.process_frame


## A spar with `trainee`, 「缺」 at once (no target yet), then the first blow decides it
## (TEST-ONLY: the trainee busy, so fight() attacks him at once).
func _spar_with_fakefault(trainee: NpcRuntimeState) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	map.select_npc(trainee.character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar with %s" % trainee.character_id)
	_check(_submit(&"perform.fakefault") == CombatTacticalResult.Code.ACCEPTED, "「缺」 at once")
	_coordinator.advance_scheduler(0.0)
	_check(_player.state.timed_applies.entries().size() == 1 and _player.state.timed_applies.entries()[0].target_id == trainee.character_id, "「缺」 names him")
	trainee.busy.start_busy(1)
	for _second: int in range(5):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the first blow decides the spar: " + _coordinator.last_abort_detail())


# --- Helpers -------------------------------------------------------------------------------

## TEST-ONLY: 200 of each resource, sword and 封山剑法 at the given levels, 封山剑法
## enabled for sword.
func _fighter(experience: int, sword: int = 100, fonxansword: int = 100) -> CharacterState:
	var state := CharacterState.new()
	state.progression.combat_experience = experience
	state.skills.set_raw_level(&"sword", sword)
	state.skills.set_raw_level(&"fonxansword", fonxansword)
	state.skills.map_skill(&"sword", &"fonxansword")
	state.essence = CharacterResourceState.new(200, 200, 200)
	state.vitality = CharacterResourceState.new(200, 200, 200)
	state.spirit = CharacterResourceState.new(200, 200, 200)
	return state


## The player with a sword (`experience`, the levels given) fighting an NPC.
func _pair(experience: int, npc_experience: int, sword: int = 100, fonxansword: int = 100) -> Array[SpecialSide]:
	var state: CharacterState = _fighter(experience, sword, fonxansword)
	state.equipment.wield(Martial.sword(), false)
	var me: SpecialSide = _side(&"player", state, &"npc")
	me.is_user = true
	var npc: SpecialSide = _side(&"npc", _fighter(npc_experience, 0, 0), &"player")
	return [me, npc]


func _side(id: StringName, state: CharacterState, opponent: StringName) -> SpecialSide:
	var relationship := CombatRelationshipState.new(id)
	relationship.add_opponent(opponent)
	var side := SpecialSide.new(id, state, ActionBusyState.new(), relationship,
		func(key: StringName) -> int: return state.timed_applies.value(key))
	side.location_id = &"here"
	return side


func _context(me: SpecialSide, target: SpecialSide, random: CombatRandomSource, attacks: SpecialAttackSource = null) -> SpecialContext:
	var context := SpecialContext.new(me, [target], random.legacy_random, _catalog, SkillImprovementEffectRegistry.new(), [target])
	context.target = target
	context.attack_source = attacks
	return context


func _offered() -> Array[StringName]:
	var ids: Array[StringName] = []
	for info: CombatTacticalActionInfo in _coordinator.action_infos():
		if info.category == CombatTacticalRequest.Category.MARTIAL_SPECIAL:
			ids.append(info.action_id)
	return ids


func _submit(action_id: StringName) -> int:
	_requests += 1
	var encounter: CombatEncounter = _coordinator.active_encounter()
	return _coordinator.submit_player_action(CombatTacticalRequest.new(
		StringName("perform-test:%d" % _requests), encounter.encounter_id, _player.character_id, action_id,
		CombatTacticalRequest.Category.MARTIAL_SPECIAL,
	)).code


func _last_resolved(scheduler: CombatEncounterScheduler) -> CombatTacticalEvent:
	var events: Array[CombatTacticalEvent] = scheduler.player_tactics().events()
	for index: int in range(events.size() - 1, -1, -1):
		if events[index].kind == CombatTacticalEvent.Kind.RESOLVED:
			return events[index]
	return null


func _log() -> String:
	return _ui.log_panel._text.get_parsed_text()


func _to_snow(tree: SceneTree) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(map: WorldMapController, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return _player.set_world_location(map.location_for_zone(zone_id))
	return false


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("player perform: " + label)
