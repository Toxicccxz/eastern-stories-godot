extends RefCounted

## Combat talk and NPC specials: std/char/npc.c chat() in a fight (chat_chance_combat,
## chat_msg_combat) after the NPC's attack, and the chat functions perform_action,
## cast_spell, exert_function and command("surrender"): 封山剑法's 「封」字诀
## (counterattack.c), 茅山道术's drainerbolt and feeblebolt, 天邪神功's powerup and
## powerfade with their timed applies, cmds/std/surrender.c. Core files with scripted
## draws first, then a Snow session: 安惜迩's powerfade outside a fight, a running
## powerup through Save, the farmer's surrender and 安惜迩's specials in a fight.
## TEST-ONLY fixtures, each marked where used: characters built by hand, resources,
## bellicosity, combat experience, the random sources.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

## MudOS random(n) from a script; past its end the highest value (bound - 1).
class Pattern extends CombatRandomSource:
	var draws: Array[int] = []
	var calls: int = 0
	func _init(p_draws: Array[int] = []) -> void:
		draws = p_draws
	func next_below(bound: int) -> int:
		calls += 1
		var value: int = draws.pop_front() if not draws.is_empty() else bound - 1
		return clampi(value, 0, bound - 1)


class Seeded extends CombatRandomSource:
	var _rng := RandomNumberGenerator.new()
	func _init(seed_value: int) -> void:
		_rng.seed = seed_value
	func next_below(bound: int) -> int:
		return _rng.randi_range(0, bound - 1)


## Every chat beat fires and takes the first entry.
class Low extends WorldInteractionRandomSource:
	var calls: int = 0
	func next_below(_bound: int) -> int:
		calls += 1
		return 0


## random(n) is always 0.
class Zero extends CombatRandomSource:
	func next_below(_bound: int) -> int:
		return 0


## No chat beat fires (random(100) is 99).
class Still extends WorldInteractionRandomSource:
	func next_below(bound: int) -> int:
		return bound - 1


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _hud: SharedGameplayUI
var _ui: BattlePresentationController
var _coordinator: CombatEncounterCoordinator


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_content()
	_test_counterattack()
	_test_bolts()
	_test_celestial()
	_test_surrender()
	_test_restore_lines_are_seen()
	_test_last_hitter()
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_hud = _session.shared_ui()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	_coordinator = _session.combat_encounter_coordinator()
	await _test_powerfade_in_the_bank(tree)
	await _test_powerup_is_saved(tree)
	await _test_farmer(tree)
	await _test_annihir_fight(tree)
	await _test_fall_outside_a_fight(tree)
	await _test_fall_between_batched_beats(tree)
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Content --------------------------------------------------------------------------

func _test_content() -> void:
	var annihir: NpcTalk = _catalog.npc(&"snow.npc.annihir").talk()
	var entries: Array = annihir.combat_chat_entries()
	_check(annihir.combat_chat_chance == 40 and entries.size() == 9, "安惜迩: chat_chance_combat 40, nine entries")
	_check(entries[0] is ColoredLine and entries[0].color == ColoredLine.CYN and entries[0].text.begins_with("安惜迩似笑非笑"), "his lines keep CYN")
	var kinds: Array[String] = []
	for entry: Variant in entries.slice(4):
		var action: NpcSpecialAction = entry
		kinds.append("%s:%s:%s" % [NpcSpecialAction.Kind.find_key(action.kind), action.use, action.function_id])
	_check(kinds == ["PERFORM:sword:counterattack", "CAST:spells:drainerbolt", "CAST:spells:feeblebolt", "EXERT:force:powerup", "EXERT:force:recover"], "perform, two spells, powerup and recover: " + str(kinds))
	_check(annihir.chat_chance == 15 and annihir.chat_entries().size() == 1 and annihir.chat_entries()[0] is NpcSpecialAction, "outside a fight: exert powerfade at 15")
	var guard: Array = _catalog.npc(&"snow.npc.guard").talk().combat_chat_entries()
	_check(guard.size() == 4 and String(guard[2]).begins_with("刘安禄忽然挥出一刀"), "刘安禄's third line names him rightly (刘安录 in the source)")
	var farmer: NpcTalk = _catalog.npc(&"snow.npc.farmer").talk()
	_check(farmer.combat_chat_chance == 50 and (farmer.combat_chat_entries()[2] as NpcSpecialAction).kind == NpcSpecialAction.Kind.SURRENDER, "the farmer: two cries and surrender at 50")
	_check(_catalog.npc(&"snow.npc.girl").talk().combat_chat_chance == 25 and _catalog.npc(&"common.npc.swordsman.master").talk().combat_chat_chance == 60, "柳绘心 25, 柳淳风 60")
	_check(not _catalog.npc(&"snow.npc.crazy_dog").talk().has_combat_chat(), "the crazy dog has lines but no chance: it never talks in a fight")
	_check(_catalog.skill(&"fonxansword").perform_functions == [&"counterattack", &"swordjab", &"fakefault"], "封山剑法 performs counterattack, swordjab and fakefault")
	_check(_catalog.skill(&"celestial").exert_functions == [&"powerup", &"powerfade", &"roar"], "天邪神功 exerts powerup, powerfade and roar (no recover file)")
	_check(_catalog.skill(&"necromancy").cast_functions == [&"drainerbolt", &"feeblebolt", &"netherbolt", &"invocation", &"animate"], "茅山道术 casts the three bolts, 召护法 and 驱尸")


# --- 「封」字诀 --------------------------------------------------------------------------

func _test_counterattack() -> void:
	var cases: Array = [["柳淳风", 1000000, 150, 5], ["安惜迩", 200000, 100, 4], ["柳绘心", 1000, 40, 3]]
	for case: Array in cases:
		var me: SpecialSide = _side(&"npc", _character(case[1], {"sword": 0, "fonxansword": case[2]}, {"sword": "fonxansword"}), [&"player"])
		var player: SpecialSide = _side(&"player", _character(0), [&"npc"])
		var random := Pattern.new([0, case[1] - 1])
		var context := _context(me, [player], random)
		_check(NpcSpecials.run(_perform(), context), "%s performs" % case[0])
		_check(player.busy.busy_value == case[3] and me.busy.busy_value == 1, "%s: the target busy fonxansword %d / 2 / 20 + 2 = %d, the performer 1: %d" % [case[0], case[2], case[3], player.busy.busy_value])
		_check(random.calls == 2 and context.lines.size() == 1 and context.lines[0].template.ends_with("结果$p被$P攻了个措手不及！") and context.lines[0].color == ColoredLine.CYN and context.lines[0].target_id == &"player", "%s: offensive_target(), random(exp), the line in CYN" % case[0])
	var me: SpecialSide = _side(&"npc", _character(1000, {"sword": 0, "fonxansword": 40}, {"sword": "fonxansword"}), [&"player"])
	var player: SpecialSide = _side(&"player", _character(10), [&"npc"])
	var context := _context(me, [player], Pattern.new([0, 5]))
	_check(NpcSpecials.run(_perform(), context) and not player.busy.is_busy() and me.busy.busy_value == 1, "random(exp) 5 not above 10 / 2: seen through, the performer busy 1")
	_check(context.lines[0].template.ends_with("可是$p看破了$P的企图，并没有上当。"), "the line says so")
	me.busy.advance()
	player.busy.start_busy(2)
	context = _context(me, [player], Pattern.new([0, 999]))
	_check(not NpcSpecials.run(_perform(), context) and not me.busy.is_busy() and player.busy.busy_value == 2 and context.lines.is_empty(), "a busy target: notify_fail, nothing happens")
	_check(context.fail_line.template == "$n目前正自顾不暇，放胆攻击吧！", "its line goes to the performer alone")
	var unarmed: SpecialSide = _side(&"npc", _character(1000, {"fonxansword": 40}), [&"player"])
	_check(not NpcSpecials.run(_perform(), _context(unarmed, [_side(&"player", _character(0), [&"npc"])], Pattern.new())), "no skill enabled for sword: perform_action() does nothing")


# --- drainerbolt and feeblebolt ------------------------------------------------------

func _test_bolts() -> void:
	# drainerbolt: random(1), random(max_mana) 100, random(ap + dp) 5 > 0, random(30) 7, random(20) 3.
	var pair: Array[SpecialSide] = _casters()
	var me: SpecialSide = pair[0]
	var player: SpecialSide = pair[1]
	var context := _context(me, [player], Pattern.new([0, 100, 5, 7, 3]))
	var learned: int = me.state.skills.learned_progress(&"necromancy")
	_check(NpcSpecials.run(_cast(&"drainerbolt"), context), "drainerbolt")
	var damage: int = 1000 / 20 + 7 - (0 + 3)
	_check(player.state.essence.current == 200 - damage and player.state.essence.effective == 200 - damage / 3, "gin %d and a wound of a third: %d / %d" % [damage, player.state.essence.current, player.state.essence.effective])
	_check(me.state.essence.current == 100 + damage and me.state.recovery.mana.current == 975 and me.state.spirit.current == 280 and me.busy.busy_value == 2, "drained into the caster, 25 mana and 20 sen, busy 2")
	_check(me.state.skills.learned_progress(&"necromancy") == learned + 1 and context.damaged == [&"player"], "necromancy practised; the player's last_damage_from")
	var lines: Array[VisionLine] = context.lines
	_check(lines.size() == 3 and lines[0].color == ColoredLine.HIM and lines[0].template.contains("紫光射向$n") and lines[1].color == ColoredLine.HIR and lines[2].is_status() and lines[2].actor_id == &"player", "the purple flash (HIM), the hit (HIR), report_status(target)")
	pair = _casters()
	context = _context(pair[0], [pair[1]], Pattern.new([0, 100, 5, 7, 3]))
	_check(NpcSpecials.run(_cast(&"feeblebolt"), context) and pair[1].state.spirit.current == 200 - damage and pair[1].state.spirit.effective == 200 - damage / 3 and pair[0].state.spirit.current == 290, "feeblebolt takes sen (10 sen to cast)")
	_check(context.lines[0].color == ColoredLine.HIW and context.lines[0].template.contains("白光"), "a white flash")
	pair = _casters()
	context = _context(pair[0], [pair[1]], Pattern.new([0, 49]))
	_check(NpcSpecials.run(_cast(&"drainerbolt"), context) and context.lines.is_empty() and pair[0].state.recovery.mana.current == 975 and not pair[0].busy.is_busy(), "random(max_mana) below 50: it fails, the cost is spent, no busy")
	pair = _casters()
	pair[1].state.progression.combat_experience = 1000
	context = _context(pair[0], [pair[1]], Pattern.new([0, 100, 999]))
	_check(NpcSpecials.run(_cast(&"drainerbolt"), context) and context.lines.size() == 2 and context.lines[1].template == "但是被$n躲开了。" and pair[1].state.essence.current == 200 and pair[0].busy.busy_value == 2, "random(ap + dp) not above dp: dodged, no status line")
	pair = _casters()
	pair[1].state.recovery.mana = CharacterInternalResourceState.new(0, 3000)
	context = _context(pair[0], [pair[1]], Pattern.new([0, 100, 5, 7, 3]))
	_check(NpcSpecials.run(_cast(&"drainerbolt"), context) and context.lines[1].template.ends_with("无声无息地钻入地下！") and context.damaged.is_empty() and pair[1].state.essence.current == 200, "the target's max_mana / 30 takes it all: through and into the ground")
	pair = _casters()
	pair[0].state.recovery.mana.current = 20
	context = _context(pair[0], [pair[1]], Pattern.new())
	_check(not NpcSpecials.run(_cast(&"drainerbolt"), context) and context.fail_line.template == "你的法力不够！" and pair[0].state.spirit.current == 300, "too little mana: refused, nothing spent")


# --- powerup and powerfade -----------------------------------------------------------

func _test_celestial() -> void:
	var state: CharacterState = _character(200000, {"force": 100, "celestial": 100}, {"force": "celestial"})
	state.recovery.inner_force = CharacterInternalResourceState.new(1000, 1000)
	var me: SpecialSide = _side(&"annihir", state, [])
	var context := _context(me, [], Pattern.new())
	_check(NpcSpecials.run(_exert(&"powerup"), context), "powerup")
	_check(state.recovery.inner_force.current == 900 and state.attributes.bellicosity == 175, "100 force; bellicosity 100 + query_skill(force) 150 / 2")
	var entries: Array[CharacterTimedApplies.Entry] = state.timed_applies.entries()
	_check(entries.size() == 1 and entries[0].remaining_ms == 150000 and state.timed_applies.value(&"attack") == 50 and state.timed_applies.value(&"dodge") == 50, "apply/attack and apply/dodge + 50 for 150 s")
	_check(not me.busy.is_busy() and context.lines.size() == 1 and context.lines[0].color == ColoredLine.HIR and context.lines[0].actor_id == &"annihir", "outside a fight no busy; the line in HIR")
	_check(not NpcSpecials.run(_exert(&"powerup"), _context(me, [], Pattern.new())) and state.recovery.inner_force.current == 900, "again while it runs: 你已经在运功中了")
	_check(not NpcSpecials.run(_exert(&"powerfade"), _context(me, [], Pattern.new())), "no powerfade while powerup runs")
	_check(state.timed_applies.advance(149999).is_empty() and state.timed_applies.advance(1) == [&"powerup"] and state.timed_applies.value(&"attack") == 0, "remove_effect() after 150 s")
	context = _context(me, [], Pattern.new())
	_check(NpcSpecials.run(_exert(&"powerfade"), context) and state.attributes.bellicosity == 25 and state.recovery.inner_force.current == 800 and state.spirit.current == 100, "powerfade: bellicosity - (100 + 150 / 3), 100 force, 100 sen")
	_check(context.lines[0].color == ColoredLine.HIC and context.lines[0].template.begins_with("$N微一凝神，运起天邪神功，放慢呼吸"), "its line in HIC")
	_check(NpcSpecials.run(_exert(&"powerfade"), _context(me, [], Pattern.new())) and state.attributes.bellicosity == -125, "while some bellicosity is left")
	_check(not NpcSpecials.run(_exert(&"powerfade"), _context(me, [], Pattern.new())) and state.recovery.inner_force.current == 700, "毫无杀气: refused")
	_check(not NpcSpecials.run(_exert(&"recover"), _context(me, [], Pattern.new())) and state.recovery.inner_force.current == 700, "recover: 天邪神功 has no such file, nothing happens")
	var fighting: SpecialSide = _side(&"annihir", state, [&"player"])
	_check(NpcSpecials.run(_exert(&"powerup"), _context(fighting, [], Pattern.new())) and fighting.busy.busy_value == 3, "in a fight powerup leaves its user busy 3")
	_check(PlayerMartialArts.apply_of(state, ArmorState.new(), &"attack") == 50, "query_temp(apply/attack) counts it")


# --- surrender -------------------------------------------------------------------------

func _test_surrender() -> void:
	var farmer: SpecialSide = _side(&"farmer", _character(20), [&"player"], [&"player"])
	farmer.state.gender = CharacterState.GENDER_MALE
	farmer.age = 33
	farmer.relationship.set_last_opponent(&"player")
	var player: SpecialSide = _side(&"player", _character(0), [&"farmer"], [&"farmer"])
	var context := _context(farmer, [player], Pattern.new(), [player])
	_check(NpcSpecials.run(_surrender(), context), "surrender")
	var line: VisionLine = context.lines[0]
	_check(line.template == "$n向$N求饶，但是$N大声说道：{rude}废话少说，纳命来！" and line.actor_id == &"player" and line.target_id == &"farmer" and line.slots == {"rude": "臭贼"}, "the killer refuses: the farmer begs (the source's $N/$n are swapped), rankd.c's 臭贼")
	_check(farmer.relationship.has_opponent(&"player") and player.relationship.has_opponent(&"farmer"), "the fight goes on")
	player.living = false
	context = _context(farmer, [player], Pattern.new(), [player])
	_check(NpcSpecials.run(_surrender(), context) and not farmer.relationship.is_fighting() and farmer.relationship.has_lethal_target(&"player"), "an unconscious opponent: remove_all_enemy(), killing stays")
	_check(player.relationship.has_opponent(&"farmer"), "the player kills the farmer: remove_enemy() refuses")
	_check(context.lines[0].template == "$N说道：「不打了，不打了，我投降....。」" and context.lines[0].color == ColoredLine.HIW, "and gives up, in HIW")
	var sparring: SpecialSide = _side(&"player", _character(0), [&"farmer"])
	var farmer2: SpecialSide = _side(&"farmer", _character(20), [&"player"])
	farmer2.relationship.set_last_opponent(&"player")
	_check(NpcSpecials.run(_surrender(), _context(farmer2, [sparring], Pattern.new(), [sparring])) and not sparring.relationship.is_fighting() and not farmer2.relationship.is_fighting(), "an opponent that is not killing it stops too")
	_check(not NpcSpecials.run(_surrender(), _context(farmer2, [], Pattern.new())), "not fighting: 投降？现在没有人在打你啊")


# --- In Snow ---------------------------------------------------------------------------

## npc.c chat() outside a fight: 安惜迩's one chat function, exert powerfade.
func _test_powerfade_in_the_bank(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.bank", &"snow.bank.annihir.1"), "in the bank")
	await tree.physics_frame
	var annihir: NpcRuntimeState = _npc(map, &"snow.bank.annihir.1")
	var state: CharacterState = annihir.character_state
	var low := Low.new()
	_session.configure_npc_ambience_random_source(low)
	var shown_before: int = _hud.log_lines().size()
	_session.advance_npc_heartbeat(2.0)
	_check(low.calls == 2 and state.attributes.bellicosity == 0 and _hud.log_lines().size() == shown_before, "a chat beat picks powerfade; no bellicosity: it refuses, nothing shown (%d draws)" % low.calls)
	state.attributes.bellicosity = 175 # TEST-ONLY: what a powerup leaves.
	var force: int = state.recovery.inner_force.current
	var sen: int = state.spirit.current
	_session.advance_npc_heartbeat(2.0)
	_session.configure_npc_ambience_random_source(Still.new())
	var shown: String = _hud.log_lines().back()
	_check(shown == "安惜迩微一凝神，运起天邪神功，放慢呼吸，开始收敛自己的杀气 ....", "the log: " + shown)
	_check(_hud.combat_log.text.ends_with("[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[ColoredLine.HIC].to_html(false), shown]), "in HIC")
	_check(state.attributes.bellicosity == 25 and state.recovery.inner_force.current == force - 100 and state.spirit.current == sen - 100, "bellicosity 25, 100 force and 100 sen spent")


## A powerup that runs on is saved and counts down on world time.
func _test_powerup_is_saved(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var annihir: NpcRuntimeState = _npc(map, &"snow.bank.annihir.1")
	var state: CharacterState = annihir.character_state
	# TEST-ONLY: his powerup outside a fight (npc.c only exerts it in one).
	var side := SpecialSide.new(annihir.character_id, state, annihir.busy, annihir.relationship)
	_check(NpcSpecials.run(_exert(&"powerup"), _context(side, [], Pattern.new())), "powerup")
	_session.advance_npc_heartbeat(2.5)
	_check(state.timed_applies.entries()[0].remaining_ms == 147500, "world time wears it down: %d" % state.timed_applies.entries()[0].remaining_ms)
	var snapshot: GameSaveSnapshot = Work.capture(_session)
	_check(snapshot != null, "Save with a powerup running")
	if snapshot == null:
		return
	var encoded: String = GameSaveJsonCodec.encode(snapshot).text
	var at: int = encoded.find("\"timed_applies\"")
	_check(at >= 0 and encoded.substr(at, 200).contains("147500"), "written in the save: " + encoded.substr(at, 200))
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded)
	var saved: Array[CharacterTimedApplies.Entry] = []
	for npc: GameSaveValueTypes.NpcSpawnStateSnapshot in decoded.snapshot.npc_spawn_states:
		if npc.character_id == annihir.character_id:
			saved = npc.character.timed_applies
	_check(saved.size() == 1 and saved[0].effect_id == &"powerup" and saved[0].remaining_ms == 147500 and saved[0].applies == {&"attack": 50, &"dodge": 50}, "read back")
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(restored.succeeded(), "Continue " + restored.path)
	if restored.succeeded():
		var back: NpcRuntimeState = restored.candidate.world_map_of(&"snow.outdoor").find_resident_npc(annihir.character_id)
		var entries: Array[CharacterTimedApplies.Entry] = []
		if back != null:
			entries = back.character_state.timed_applies.entries()
		_check(entries.size() == 1 and entries[0].remaining_ms == 147500 and back.character_state.timed_applies.value(&"dodge") == 50, "Continue: 安惜迩's powerup runs on with 147.5 s")
		restored.candidate.free()
		await tree.process_frame
	_check(not GameSaveJsonCodec.decode(encoded.replace("147500", "0")).succeeded(), "an entry with no time left fails closed")
	for broken: Callable in [
		func(list: Array) -> void: list.append(list[0].duplicate(true)),
		func(list: Array) -> void: list[0]["applies"] = {},
		func(list: Array) -> void: list.clear(),
	]:
		var root: Dictionary = JSON.parse_string(encoded)
		for npc: Dictionary in root["npc_spawn_states"]:
			if npc["character"].has("timed_applies"):
				broken.call(npc["character"]["timed_applies"])
		_check(not GameSaveJsonCodec.decode(JSON.stringify(root)).succeeded(), "a twice-named, empty or unbonused entry fails closed")
	state.timed_applies.advance(147500)
	_check(state.timed_applies.is_empty(), "and ends")


## The farmer's combat talk; command("surrender") against a player who attacked him.
func _test_farmer(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	# TEST-ONLY: kee to outlast the farmer while he talks.
	_player.state.vitality = CharacterResourceState.new(5000, 5000, 5000)
	_check(_beside(map, &"snow.sroad2", &"snow.sroad2.farmer.1"), "beside a farmer")
	await tree.physics_frame
	var farmer: NpcRuntimeState = _npc(map, &"snow.sroad2.farmer.1")
	map.select_npc(farmer.character_id)
	_session.configure_combat_random_source(Seeded.new(7))
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the farmer")
	_ui.refresh_projection()
	var bindings: Array[CombatSliceCharacterBinding] = _session.encounter_combat_bindings(_coordinator.active_encounter())
	var me: CombatSliceCharacterBinding = _binding(bindings, farmer.character_id)
	var player: CombatSliceCharacterBinding = _binding(bindings, _player.character_id)
	me.relationship.set_last_opponent(_player.character_id)
	var chat := CombatNpcChat.new(func(id: StringName) -> NpcRuntimeState: return map.find_resident_npc(id))
	var result: CombatNpcChatResult = chat.beat(me, [player], [player], Pattern.new([0, 2]), SkillImprovementEffectRegistry.new())
	var shown: Array[BattleNarrationLine] = BattleNarrator.seen(result.lines(), _ui.current_projection())
	_check(shown.size() == 1 and shown[0].text == "农夫向你求饶，但是你大声说道：臭贼废话少说，纳命来！", "surrender, refused, as the player reads it: " + (shown[0].text if not shown.is_empty() else ""))
	_check(chat.beat(me, [player], [player], Pattern.new([50]), SkillImprovementEffectRegistry.new()) == null, "random(100) 50 is not below 50: nothing")
	# A busy beat (continue_action()) says nothing; the next one does, every draw 0.
	_session.configure_combat_random_source(Zero.new())
	farmer.busy.start_busy(1) # TEST-ONLY
	var scheduler: CombatEncounterScheduler = _coordinator.active_scheduler()
	var before: int = scheduler.events().size()
	_coordinator.advance_scheduler(1.0)
	_check(_chats(scheduler.events().slice(before), farmer.character_id).is_empty(), "busy: no chat")
	before = scheduler.events().size()
	_coordinator.advance_scheduler(1.0)
	var said: Array[CombatSchedulerEvent] = _chats(scheduler.events().slice(before), farmer.character_id)
	_check(said.size() == 1 and said[0].chat.lines()[0].template.begins_with("农夫叫道：杀人哪！"), "not busy: random(100) 0 < 50, the first line")
	_session.configure_combat_random_source(Seeded.new(7))
	var heard: bool = false
	for _round: int in range(60):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
		_ui.refresh_projection()
		heard = heard or _log().contains("农夫叫道") or _log().contains("农夫向你求饶")
		if heard:
			break
	_check(heard, "the battle log has his combat talk: " + _log().right(200))
	await _flee(tree)


## 安惜迩 in a fight: lines in CYN, 「封」, the bolts and powerup, round by round.
func _test_annihir_fight(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_heal()
	# TEST-ONLY: enough of everything to last while he tries all he has.
	_player.state.essence = CharacterResourceState.new(5000, 5000, 5000)
	_player.state.vitality = CharacterResourceState.new(5000, 5000, 5000)
	_player.state.spirit = CharacterResourceState.new(5000, 5000, 5000)
	_player.state.progression.combat_experience = 0
	_check(_beside(map, &"snow.bank", &"snow.bank.annihir.1"), "in the bank")
	await tree.physics_frame
	var annihir: NpcRuntimeState = _npc(map, &"snow.bank.annihir.1")
	map.select_npc(annihir.character_id)
	_session.configure_combat_random_source(Seeded.new(11))
	var attack: CombatSliceInitiationResult = map.attack_selected()
	_check(attack.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 安惜迩: %s, player %s" % [CombatSliceInitiationResult.Outcome.find_key(attack.outcome), CharacterRuntimeLifeStatus.Value.find_key(_player.life_status)])
	var scheduler: CombatEncounterScheduler = _coordinator.active_scheduler()
	var seen: Dictionary[String, bool] = {}
	var order: int = 0
	var wearing: bool = false
	var wore: bool = false
	for _round: int in range(300):
		if not _coordinator.has_active_encounter() or (seen.has_all(["said", "held", "bolt", "powerup"]) and wore):
			break
		_coordinator.advance_scheduler(1.0)
		_ui.refresh_projection()
		if wearing:
			var left: Array[CharacterTimedApplies.Entry] = annihir.character_state.timed_applies.entries()
			_check(left.size() == 1 and left[0].remaining_ms == 149000, "a round of the fight is a second of powerup")
			wearing = false
			wore = true
		for event: CombatSchedulerEvent in scheduler.events_after(order):
			order = event.progression_order
			if event.kind != CombatSchedulerEvent.Kind.NPC_CHAT:
				continue
			var first: VisionLine = event.chat.lines()[0]
			if first.color == ColoredLine.CYN and first.template.begins_with("安惜迩"):
				seen["said"] = true
				var said: BattleNarrationLine = BattleNarrator.seen([first], _ui.current_projection())[0]
				_check(_log().contains(first.template.strip_edges()) and said.rich_text().begins_with("[color=#%s]" % SharedGameplayUI.ES2_COLORS[ColoredLine.CYN].to_html(false)), "said, in CYN: " + said.rich_text())
			elif first.template.begins_with("$N使出封山剑法"):
				seen["counterattack"] = true
				if first.template.ends_with("措手不及！"):
					_check(_player.busy.busy_value == 4, "「封」 holds the player 4 rounds (fonxansword 100): %d" % _player.busy.busy_value)
					seen["held"] = true
			elif first.template.contains("射向$n"):
				if event.chat.damaged(_player.character_id):
					seen["bolt"] = true
					var text: String = _log()
					_check(text.contains("安惜迩口中喃喃地念著咒文") and text.contains("( 你"), "the bolt, its hit and report_status() in the battle log")
			elif first.template.contains("爆豆般的声响"):
				seen["powerup"] = true
				wearing = true
				_check(annihir.busy.busy_value == 3 and annihir.character_state.timed_applies.entries()[0].remaining_ms == 150000, "powerup: busy 3, 150 s to run")
				_check(annihir.character_state.attributes.bellicosity >= 175, "bellicosity up")
	for key: String in ["said", "held", "bolt", "powerup"]:
		_check(seen.has(key), "安惜迩 shows %s in the fight" % key)
	_check(wore, "the round after powerup was watched")
	await _flee(tree)


## recover.c's line is message_vision(): an NPC's is seen by everyone in the room.
func _test_restore_lines_are_seen() -> void:
	var state: CharacterState = _character(0)
	state.recovery.inner_force = CharacterInternalResourceState.new(100, 100)
	state.vitality = CharacterResourceState.new(50, 200, 200)
	var context := ExertContext.new(state, 10, true, ActionBusyState.new(), &"npc")
	_check(ExertFunctions.find(&"recover").exert(context), "recover")
	_check(context.lines.size() == 1 and context.lines[0].text == "你深深吸了几口气，脸色看起来好多了。", "its user reads 你")
	_check(context.vision_lines.size() == 1 and context.vision_lines[0].template == "$N深深吸了几口气，脸色看起来好多了。" and context.vision_lines[0].actor_id == &"npc", "everyone else reads $N")


## damage.c last_damage_from: a spell's victim was hurt by its caster.
func _test_last_hitter() -> void:
	var chat := CombatNpcChatResult.new([VisionLine.new("x", &"annihir", &"player")], [&"player"])
	var event := CombatSchedulerEvent.new(1, 1, 1.0, CombatSchedulerEvent.Kind.NPC_CHAT, CombatSchedulerEvent.SkipReason.NONE, &"annihir", &"", null, 1, chat)
	_check(event.is_valid() and CombatEncounterResolution.last_hitter(event, &"player") == &"annihir", "the caster is the player's last_damage_from")
	_check(CombatEncounterResolution.last_hitter(event, &"annihir") == &"", "nobody hurt the caster")


## std/char.c heart_beat() outside a fight: powerfade's 100 sen takes 安惜迩 below zero
## and he falls on his next beat.
func _test_fall_outside_a_fight(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var annihir: NpcRuntimeState = _npc(map, &"snow.bank.annihir.1")
	var state: CharacterState = annihir.character_state
	_check(_beside(map, &"snow.bank", &"snow.bank.annihir.1"), "back in the bank")
	await tree.physics_frame
	_check(annihir.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not annihir.relationship.is_fighting(), "安惜迩 is up and not fighting")
	# TEST-ONLY: bellicosity to calm, sen spent on his spells, nothing running.
	state.timed_applies.advance(1000000)
	state.attributes.bellicosity = 175
	state.recovery.inner_force.current = 1000
	state.spirit.current = 50
	# No mana: a heal_up() due in the step (con/3 + mana/10 sen) must not save him.
	state.recovery.mana.current = 0
	while annihir.busy.is_busy():
		annihir.busy.advance()
	_session.configure_npc_ambience_random_source(Low.new())
	_session.advance_npc_heartbeat(2.0)
	_session.configure_npc_ambience_random_source(Still.new())
	_check(state.spirit.current == -1 and annihir.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "powerfade: sen below zero (%d)" % state.spirit.current)
	_session.advance_npc_heartbeat(0.1)
	_check(annihir.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and annihir.revive_in_ms > 0, "he falls on his next beat and will come to")


## Several beats in one step (a long frame) fall before each beat's chat too (Codex
## on #49): one powerfade takes him below zero, the next beat he falls instead of
## calming down again.
func _test_fall_between_batched_beats(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var annihir: NpcRuntimeState = _npc(map, &"snow.bank.annihir.1")
	var state: CharacterState = annihir.character_state
	# TEST-ONLY: he comes to at once (revive()), then bellicosity to calm, little sen
	# and plenty of force.
	annihir.set_revive_in_ms(1)
	_session.advance_npc_heartbeat(0.1)
	_check(annihir.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "安惜迩 comes to")
	# The frame first: world time flows in it, and a heart beat due on a slow machine
	# would heal the sen set below before the step under test. No mana either: a
	# heal_up() inside the step (the NPC's tick is drawn unseeded) restores con/3 +
	# mana/10 sen, and one powerfade must still take him below zero.
	await tree.physics_frame
	state.spirit = CharacterResourceState.new(20, 300, 300)
	state.recovery.mana.current = 0
	state.attributes.bellicosity = 175
	state.recovery.inner_force.current = 1000
	_session.configure_npc_ambience_random_source(Low.new())
	_session.advance_npc_heartbeat(4.0)
	_session.configure_npc_ambience_random_source(Still.new())
	var falls: Array[CombatSliceLifecycleResult] = map.last_lifecycle_results()
	var fall: String = "none" if falls.is_empty() else "%s for %s" % [CombatSliceLifecycleResult.Outcome.find_key(falls.back().outcome), falls.back().victim_id]
	_check(state.recovery.inner_force.current == 900 and state.attributes.bellicosity == 25, "one powerfade in two beats: force %d, bellicosity %d, last fall %s" % [state.recovery.inner_force.current, state.attributes.bellicosity, fall])
	_check(annihir.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "he falls on the second beat of the same step: %s, last fall %s" % [CharacterRuntimeLifeStatus.Value.find_key(annihir.life_status), fall])


# --- Helpers ---------------------------------------------------------------------------

func _chats(events: Array[CombatSchedulerEvent], actor_id: StringName) -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for event: CombatSchedulerEvent in events:
		if event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.actor_id == actor_id:
			result.append(event)
	return result


func _character(experience: int, levels: Dictionary = {}, mapped: Dictionary = {}) -> CharacterState:
	var state := CharacterState.new()
	state.progression.combat_experience = experience
	for skill: String in levels:
		state.skills.set_raw_level(StringName(skill), levels[skill])
	for use: String in mapped:
		state.skills.map_skill(StringName(use), StringName(mapped[use]))
	state.essence = CharacterResourceState.new(200, 200, 200)
	state.vitality = CharacterResourceState.new(200, 200, 200)
	state.spirit = CharacterResourceState.new(200, 200, 200)
	return state


func _side(id: StringName, state: CharacterState, opponents: Array[StringName], lethal: Array[StringName] = []) -> SpecialSide:
	var relationship := CombatRelationshipState.new(id)
	for other: StringName in opponents:
		relationship.add_opponent(other)
	for other: StringName in lethal:
		relationship.mark_lethal_target(other)
	return SpecialSide.new(id, state, ActionBusyState.new(), relationship)


func _context(me: SpecialSide, enemies: Array[SpecialSide], random: CombatRandomSource, others: Array[SpecialSide] = []) -> SpecialContext:
	return SpecialContext.new(me, enemies, random.legacy_random, _catalog, SkillImprovementEffectRegistry.new(), others if not others.is_empty() else enemies)


## TEST-ONLY: 安惜迩's spells (100, necromancy 100) with 1000 mana, 300 sen and 100 of
## 300 gin, against a player with 200 of each and no mana.
func _casters() -> Array[SpecialSide]:
	var state: CharacterState = _character(200000, {"spells": 100, "necromancy": 100}, {"spells": "necromancy"})
	state.recovery.mana = CharacterInternalResourceState.new(1000, 1000)
	state.spirit = CharacterResourceState.new(300, 300, 300)
	state.essence = CharacterResourceState.new(100, 300, 300)
	return [_side(&"annihir", state, [&"player"]), _side(&"player", _character(0), [&"annihir"])]


func _perform() -> NpcSpecialAction:
	return NpcSpecialAction.new(NpcSpecialAction.Kind.PERFORM, &"sword", &"counterattack")


func _cast(spell: StringName) -> NpcSpecialAction:
	return NpcSpecialAction.new(NpcSpecialAction.Kind.CAST, &"", spell)


func _exert(function_id: StringName) -> NpcSpecialAction:
	return NpcSpecialAction.new(NpcSpecialAction.Kind.EXERT, &"", function_id)


func _surrender() -> NpcSpecialAction:
	return NpcSpecialAction.new(NpcSpecialAction.Kind.SURRENDER)


func _binding(bindings: Array[CombatSliceCharacterBinding], id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.character_id == id:
			return binding
	return null


func _finish(tree: SceneTree) -> void:
	for _second: int in range(600):
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight ends: " + _coordinator.last_abort_detail())
	_ui.refresh_projection()
	await tree.process_frame


func _flee(tree: SceneTree) -> void:
	for attempt: int in range(200):
		if not _coordinator.has_active_encounter():
			break
		if _coordinator.active_encounter().queued_player_action() == null:
			var info: CombatTacticalActionInfo = _coordinator.action_infos()[0]
			_coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), _coordinator.active_encounter().encounter_id, _player.character_id, info.action_id, info.category))
		_coordinator.advance_scheduler(1.0)
	_check(not _coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "fled: " + _coordinator.last_abort_detail())
	_ui.refresh_projection()
	await tree.process_frame


func _log() -> String:
	return _ui.log_panel._text.get_parsed_text()


## TEST-ONLY: whole again between fights.
func _heal() -> void:
	var state: CharacterState = _player.state
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


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
	if not ok: _failures.append("combat specials: " + label)
