class_name MainlineFightSim
extends RefCounted

## Native (DECISIONS「主线必打的仗」): the main story's must-win fights as the game fights them, for
## tuning their foes (tests/sim/run_mainline_fight_sim.gd prints the table) and for pinning the
## result (tests/runtime/boss_strength_test.gd). One session per fight: the player is grown to the
## story path's arrival exp (tests/support/grown_character.gd, the sword build), the whole group and
## the helpers the story guarantees stand where the fight opens, and the fight runs through the real
## coordinator and scheduler — the player's 2 beats a round, each NPC's own (`beats`), NPC specials,
## the room joining, the allies' rule (fights_beside_player), 了结 / 放过, wounds and ripostes.
## The player's orders are a fixed plain policy: every beat the first move that is not 守 and can be
## paid for, at the first enemy still standing; the default stance (攻), no specials, no exert, no
## items, no 收势; the fallen are let be (放过). Seeded (the combat random source); nothing here is read by the game.
##
## A loss is the moment the player would have fallen (kee or effective kee below 0): the player
## fights on a buffer of BUFFER kee so the fight can be run out without the death flow, and the
## foes are worn down once it is lost. Each duel starts from full kee, force and conditions cleared
## on both sides, the foes and the summoned helpers brought back where they stand.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")

const BUFFER: int = 1000000
## Scheduler steps (one second of the fight's clock each) before a duel is called a loss.
const MAX_STEPS: int = 4000

## The must-win fights (the list: DECISIONS「主线必打的仗」). `exps`: the story path's arrival exp,
## the lower (main story only) first; `enemies` / `allies`: [spawn, point] as they stand; `followers`:
## NPC definitions that follow the player there whatever was chosen (郭承), summoned beside them;
## `mood`: the scene's mood put on each foe that has it (吕隼's 拿下: `fighting`);
## `helped`: whether the story guarantees help there (the nine-in-ten band); `away`: spawns whose NPCs
## stand in the room but are not in the story's fight, taken off the map (the 冰龙厅's six guardian
## dragons, DECISIONS「冰龙守者」「终章 B」: they pounce on the four taoists, or lie beaten — the sim's
## player strikes first, and a first strike brings the whole room in; the 甬道's keyless jailers, gone
## once 「见过唤首」, the mark the keyed pair stand on).
const FIGHTS: Array[Dictionary] = [
	{"label": "第一章 山洞 黑衣道士", "zone": &"oldpine.caves.mouth", "point": &"oldpine.caves.mouth.cave5.black_taoist.1", "enemies": [["native.caves.black_taoist", "oldpine.caves.mouth.cave5.black_taoist.1"]], "exps": [1820, 4127], "weapon": &"es2:obj/longsword"},
	{"label": "第三章 祭坛 鬼卒×2", "zone": &"niling.altar", "point": &"niling.altar.hell_runner.1", "enemies": [["niling.altar.hell_runners", "niling.altar.hell_runner.1"], ["niling.altar.hell_runners", "niling.altar.hell_runner.2"]], "exps": [4695, 8837], "weapon": &"es2:obj/longsword"},
	{"label": "第三章 救人 带钥匙的狱卒×2", "zone": &"niling.corridor", "point": &"niling.corridor.jailer_keyed.1", "enemies": [["niling.corridor.jailers_keyed", "niling.corridor.jailer_keyed.1"], ["niling.corridor.jailers_keyed", "niling.corridor.jailer_keyed.2"]], "away": [&"niling.corridor.jailers"], "exps": [4695, 8837], "weapon": &"es2:obj/longsword"},
	{"label": "第五章 树洞 鬼卒×2", "zone": &"choyin.tomb3", "point": &"choyin.tomb3.hell_runner.1", "enemies": [["native.tomb3.hell_runners", "choyin.tomb3.hell_runner.1"], ["native.tomb3.hell_runners", "choyin.tomb3.hell_runner.2"]], "exps": [8442, 13712], "weapon": &"es2:obj/longsword"},
	{"label": "第六章 借兵 踏平工地", "zone": &"guanbei.fence_gate", "point": &"guanbei.fence_gate.pei_zhao.1", "enemies": [["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.1"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.2"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.3"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.4"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.5"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.6"], ["guanbei.fence_gate.pei_zhao", "guanbei.fence_gate.pei_zhao.1"], ["guanbei.fence_gate.lu_sun", "guanbei.fence_gate.lu_sun.1"]], "allies": [["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.1"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.2"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.3"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.4"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.5"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.6"]], "followers": [&"native.npc.guo_cheng"], "mood": "fighting", "helped": true, "exps": [11625, 17432], "weapon": &"es2:obj/longsword"},
	{"label": "第六章 潜入 守夜武官×2", "zone": &"guanbei.sheds", "point": &"guanbei.sheds.night_watch_fighting.1", "enemies": [["guanbei.sheds.night_watch_fighting", "guanbei.sheds.night_watch_fighting.1"], ["guanbei.sheds.night_watch_fighting", "guanbei.sheds.night_watch_fighting.2"]], "followers": [&"native.npc.guo_cheng"], "helped": true, "exps": [11625, 17432], "weapon": &"es2:obj/longsword"},
	{"label": "终章 湖畔 鬼卒×3（潜入的路）", "zone": &"village.lakeside", "point": &"village.lakeside.finale_runner.1", "enemies": [["native.lakeside.finale_runners", "village.lakeside.finale_runner.1"], ["native.lakeside.finale_runners", "village.lakeside.finale_runner.2"], ["native.lakeside.finale_runners", "village.lakeside.finale_runner.3"]], "exps": [37275, 52294], "weapon": &"native:lancheng/xuanmang"},
	{"label": "终章 冰龙厅 商玦", "zone": &"village.lakebottom2", "point": &"village.lakebottom2.shang_jue_fighting.1", "enemies": [["native.lakebottom2.shang_jue_fighting", "village.lakebottom2.shang_jue_fighting.1"]], "exps": [37275, 52294], "away": [&"village.icecave.lakebottom2.dragons"], "weapon": &"native:lancheng/xuanmang"},
	{"label": "终章 冰龙厅 商玦+四道士（打过冰龙）", "zone": &"village.lakebottom2", "point": &"village.lakebottom2.shang_jue_fighting.1", "enemies": [["native.lakebottom2.shang_jue_fighting", "village.lakebottom2.shang_jue_fighting.1"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.1"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.2"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.3"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.4"]], "exps": [37275, 52294], "away": [&"village.icecave.lakebottom2.dragons"], "weapon": &"native:lancheng/xuanmang"},
	{"label": "终章 侮天鬼（穿宝衣·没拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.1", "enemies": [["native.seal_altar.wutian_gui", "village.seal_altar.demon.1"]], "exps": [37275, 52294], "weapon": &"native:lancheng/xuanmang"},
	{"label": "终章 侮天鬼（没宝衣·没拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.2", "enemies": [["native.seal_altar.wutian_gui_blazing", "village.seal_altar.demon.2"]], "exps": [37275, 52294], "weapon": &"native:lancheng/xuanmang"},
	{"label": "终章 侮天鬼（穿宝衣·拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.3", "enemies": [["native.seal_altar.wutian_gui_grown", "village.seal_altar.demon.3"]], "exps": [37275, 52294], "weapon": &"native:lancheng/xuanmang"},
	{"label": "终章 侮天鬼（没宝衣·拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.4", "enemies": [["native.seal_altar.wutian_gui_grown_blazing", "village.seal_altar.demon.4"]], "exps": [37275, 52294], "weapon": &"native:lancheng/xuanmang"},
	{"label": "第九章 揭发 庾子建（冯策并肩，选择）", "zone": &"imperial.throne_hall", "point": &"imperial.throne_hall.yu_drawn.1", "enemies": [["imperial.throne_hall.yu_drawn", "imperial.throne_hall.yu_drawn.1"]], "allies": [["imperial.throne_hall.feng_ce_beside", "imperial.throne_hall.feng_ce_beside.1"]], "helped": true, "exps": [32234], "weapon": &"es2:obj/longsword"},
]


## One fight at one exp: the duels won, the rounds each won duel took, the lineup that fought, the
## game's 战前预判 before the first duel.
class Result:
	extends RefCounted
	var label: String = ""
	var experience: int = 0
	var duels: int = 0
	var wins: int = 0
	var won_rounds: Array[int] = []
	## Who was in the fight on each side (the first duel's), for checking the lineup is the story's.
	var enemies_in: int = 0
	var allies_in: int = 0
	var expected_enemies: int = 0
	var expected_allies: int = 0
	## The most participants in any duel that were neither the player nor the story's lineup.
	var others_in: int = 0
	## The forecast's verdict (CombatForecast.Verdict) and its rounds ratio; -1 when none.
	var forecast: int = -1
	var forecast_ratio: float = -1.0
	var stuck: int = 0
	## Duels left out: not every foe came into the fight, or it closed with a foe never down.
	var short_lineup: int = 0
	var notes: Array[String] = []

	func rate() -> float:
		return 0.0 if duels == 0 else float(wins) / float(duels)

	func median_rounds() -> int:
		if won_rounds.is_empty():
			return -1
		var sorted: Array[int] = won_rounds.duplicate()
		sorted.sort()
		return sorted[sorted.size() / 2]

	func lineup_ok() -> bool:
		return enemies_in == expected_enemies and allies_in == expected_allies and others_in == 0


## Tuning, this run only (run_mainline_fight_sim.gd's `tune=`): NPC definition ID -> {"exp": n,
## "skills": {skill: raw level}, "kee": n, "force": n} put on each foe of that definition as a duel opens.
var tune: Dictionary = {}
## Print each duel's end (run_mainline_fight_sim.gd's `verbose`).
var verbose: bool = false
## The stance the player holds (CombatStance; the default 攻).
var stance: int = CombatStance.Value.ATTACK
var tree: SceneTree
var session: WorldSessionController
var map: WorldMapController
var _enemies: Array[NpcRuntimeState] = []
var _allies: Array[NpcRuntimeState] = []
var _fight: Dictionary = {}
var _experience: int = 0
## Each foe's and helper's exp as first seen, by spawn point (a duel's blows add to it).
var _base_exp: Dictionary[StringName, int] = {}


func _init(p_tree: SceneTree) -> void:
	tree = p_tree


## The fight with this label, or empty.
static func fight(label: String) -> Dictionary:
	for entry: Dictionary in FIGHTS:
		if entry["label"] == label:
			return entry
	return {}


## Each of `experiences` (the fight's own `exps` when empty): `duels` duels from `seed`.
func run(entry: Dictionary, duels: int, seed: int = 7, experiences: Array = []) -> Array[Result]:
	var results: Array[Result] = []
	var paces: Array = [BattlePace.manual_turns, BattlePace.stance, BattlePace.after_knockout, BattlePace.opening]
	BattlePace.manual_turns = true
	BattlePace.stance = stance
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	BattlePace.opening = BattlePace.Opening.OFF
	if await _open(entry):
		for experience: Variant in (entry["exps"] if experiences.is_empty() else experiences):
			results.append(await _run_at(int(experience), duels, seed))
	else:
		var failed := Result.new()
		failed.label = entry["label"]
		failed.notes.append("could not set the fight up")
		results.append(failed)
	await close()
	BattlePace.manual_turns = paces[0]
	BattlePace.stance = paces[1]
	BattlePace.after_knockout = paces[2]
	BattlePace.opening = paces[3]
	return results


func close() -> void:
	if session != null:
		session.free()
		session = null
		map = null
	await tree.process_frame


func _settle() -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _open(entry: Dictionary) -> bool:
	_fight = entry
	session = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("强度", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	map = MapPlaces.enter(session, entry["zone"], entry["point"])
	if map == null:
		return false
	# Before a frame passes, so a bystander's aggression opens no fight.
	_withdraw_away()
	await _settle()
	_enemies = _bring_all(entry.get("enemies", []))
	_allies = _bring_all(entry.get("allies", []))
	for definition_id: StringName in entry.get("followers", []):
		var follower: NpcRuntimeState = _follower(definition_id)
		if follower != null:
			_allies.append(follower)
	await _settle()
	if _enemies.size() != entry["enemies"].size():
		return false
	_wield(entry["weapon"])
	return true


func _run_at(experience: int, duels: int, seed: int) -> Result:
	var result := Result.new()
	result.label = _fight["label"]
	result.experience = experience
	result.expected_enemies = _enemies.size()
	result.expected_allies = _allies.size()
	_experience = experience
	session.configure_combat_random_source(Specials.Seeded.new(seed))
	for duel: int in duels:
		await _reset()
		if duel == 0:
			var forecast: CombatForecast = CombatForecastBuilder.for_attack(map, _enemies[0])
			if forecast != null:
				result.forecast = forecast.verdict
				result.forecast_ratio = forecast.rounds_to_win / forecast.rounds_to_lose if forecast.rounds_to_lose != INF and forecast.rounds_to_lose > 0.0 else 0.0
		var outcome: Array = await _duel(result, duel == 0)
		if outcome.size() > 2 and not outcome[2]:
			result.short_lineup += 1
			continue
		result.duels += 1
		if outcome[0]:
			result.wins += 1
			result.won_rounds.append(outcome[1])
	return result


## Everyone back as the fight opens: the foes and helpers standing at their points and whole, the
## player whole (on the buffer), nobody's fight remembered.
func _reset() -> void:
	# Grown anew each duel: what a duel taught (exp, skills, potential) is not carried into the next.
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	Grown.grow(state, _experience, 50, true)
	state.attributes.force_factor = 0
	# The last duel's dead taken away (a corpse a duel would fill the room).
	for corpse: CorpseState in map.corpses._corpse_states.duplicate():
		map.corpses._destruct_corpse(corpse)
	for pair: Array in _fight.get("enemies", []) + _fight.get("allies", []):
		_bring(pair)
	_enemies = _refind(_fight.get("enemies", []))
	var allies: Array[NpcRuntimeState] = _refind(_fight.get("allies", []))
	for npc: NpcRuntimeState in _allies:
		if not _fight.get("allies", []).any(func(pair: Array) -> bool: return npc.spawn_point_id == StringName(pair[1])):
			if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
				map.npc_life.revive(npc, false)
			allies.append(npc)
	_allies = allies
	# Who follows the player there, back if they fell for good.
	for definition_id: StringName in _fight.get("followers", []):
		var follower: NpcRuntimeState = null
		for npc: NpcRuntimeState in _allies:
			if npc.definition().definition_id == definition_id:
				follower = npc
		if follower == null or follower.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not follower.exists_in_map:
			_allies.erase(follower)
			follower = _follower(definition_id)
			if follower != null:
				_allies.append(follower)
	for npc: NpcRuntimeState in _enemies + _allies:
		if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			map.npc_life.revive(npc, false)
		_tune(npc)
		# The scene's mood (吕隼's 拿下: 裴照 and 吕隼 draw in `fighting`).
		var hooks: NpcHooks = npc.definition().hooks()
		if _fight.has("mood") and hooks != null and hooks.moods.has(_fight["mood"]) and _enemies.has(npc):
			npc.put_in_mood(hooks.moods[_fight["mood"]])
		_whole(npc.character_state)
		_forget(npc.relationship)
		npc.busy.restore(0, 0)
	_forget(session.player_runtime().relationship)
	session.player_runtime().busy.restore(0, 0)
	_withdraw_away()
	await _settle()


func _tune(npc: NpcRuntimeState) -> void:
	var facts: Dictionary = tune.get(String(npc.definition().definition_id), {})
	var s: CharacterState = npc.character_state
	# Back to the exp it was made with (a duel's blows taught them too), then this run's tuning.
	if not _base_exp.has(npc.spawn_point_id):
		_base_exp[npc.spawn_point_id] = s.progression.combat_experience
	s.progression.combat_experience = _base_exp[npc.spawn_point_id]
	if facts.has("exp"):
		s.progression.combat_experience = int(facts["exp"])
	for skill: String in facts.get("skills", {}):
		s.skills.set_raw_level(StringName(skill), int(facts["skills"][skill]))
	if facts.has("kee"):
		s.vitality = CharacterResourceState.new(int(facts["kee"]), int(facts["kee"]), int(facts["kee"]))
	if facts.has("force"):
		s.recovery.inner_force.maximum = int(facts["force"])


func _forget(relationship: CombatRelationshipState) -> void:
	for id: StringName in relationship.lethal_target_ids():
		relationship.remove_lethal_relation(id)
	relationship.clear_opponents_preserving_lethal_targets()
	relationship.clear_last_opponent()
	relationship.clear_last_damage_from()


func _whole(s: CharacterState) -> void:
	s.conditions.clear()
	for resource: CharacterResourceState in [s.essence, s.vitality, s.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	s.recovery.inner_force.current = s.recovery.inner_force.maximum


## One duel: [won, rounds].
func _duel(result: Result, first: bool) -> Array:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var real_kee: int = player.state.vitality.maximum
	map.select_npc(_enemies[0].character_id)
	map.attack_selected()
	if not coordinator.has_active_encounter():
		session.advance_npc_heartbeat(1.0)
		map.hostilities.process_pending_aggression()
	if not coordinator.has_active_encounter():
		var why: String = "no fight opened" if player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE else "the player lies fallen (精 / 神)"
		if not result.notes.has(why):
			result.notes.append(why)
		if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			result.stuck += 1
		return [false, 0, false]
	var encounter: CombatEncounter = coordinator.active_encounter()
	var enemies_in: int = 0
	var allies_in: int = 0
	for npc: NpcRuntimeState in _enemies:
		enemies_in += 1 if encounter.participant_for(npc.character_id) != null else 0
	for npc: NpcRuntimeState in _allies:
		allies_in += 1 if encounter.participant_for(npc.character_id) != null else 0
	if first or enemies_in > result.enemies_in:
		result.enemies_in = enemies_in
		result.allies_in = allies_in
	result.others_in = maxi(result.others_in, _others_in(encounter, player.character_id))
	var full: bool = enemies_in == _enemies.size()
	var my_side: StringName = encounter.participant_for(player.character_id).side_id
	# The buffer: the fight runs on, the loss is read off it.
	var s: CharacterState = player.state
	s.vitality = CharacterResourceState.new(s.vitality.maximum + BUFFER, s.vitality.maximum + BUFFER, s.vitality.maximum + BUFFER)
	var lost: bool = false
	var lost_rounds: int = 0
	var rounds: int = 0
	var steps: int = 0
	# Each foe that was down (fallen or gone) at some point of the fight.
	var downed: Dictionary[StringName, bool] = {}
	while coordinator.has_active_encounter() and steps < MAX_STEPS:
		steps += 1
		for npc: NpcRuntimeState in _enemies:
			if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not npc.exists_in_map:
				downed[npc.character_id] = true
		# 放过: the fallen are let be (a 了结 would leave a corpse a duel; they wake on their own time).
		for victim: StringName in coordinator.held_victims():
			coordinator.spare_downed(victim)
		if coordinator.waiting_for_player():
			_order(coordinator)
		coordinator.advance_scheduler(1.0)
		if map.combat_lifecycle._lifecycle_failed:
			var last: Array = map.combat_lifecycle._last_lifecycle_results
			var note: String = "lifecycle failed: %s" % ("?" if last.is_empty() or last[-1] == null else CombatSliceLifecycleResult.Outcome.find_key(last[-1].outcome))
			if not result.notes.has(note):
				result.notes.append(note)
		if coordinator.has_active_encounter() and coordinator.active_scheduler() != null:
			rounds = coordinator.active_scheduler().rounds_completed()
			result.others_in = maxi(result.others_in, _others_in(coordinator.active_encounter(), player.character_id))
		if not lost and (s.vitality.current < BUFFER or s.vitality.effective < BUFFER):
			lost = true
			lost_rounds = rounds
			for npc: NpcRuntimeState in _enemies:
				npc.character_state.vitality = CharacterResourceState.new(1, 1, npc.character_state.vitality.maximum)
	if coordinator.has_active_encounter():
		result.stuck += 1
		lost = true
		for npc: NpcRuntimeState in _enemies:
			npc.character_state.vitality = CharacterResourceState.new(-1, 1, npc.character_state.vitality.maximum)
		for step: int in 200:
			if not coordinator.has_active_encounter():
				break
			coordinator.advance_scheduler(1.0)
	session.shared_ui().dismiss_current_panel()
	s.vitality = CharacterResourceState.new(real_kee, real_kee, real_kee)
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		lost = true
	# Won: the player stands and the fight ended in their side's victory (not fled, not aborted).
	for npc: NpcRuntimeState in _enemies:
		if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not npc.exists_in_map:
			downed[npc.character_id] = true
	# A fight over with a foe never down and the player standing was no fight (it closed at once):
	# the duel does not count.
	if not lost and downed.size() < _enemies.size():
		if not result.notes.has("closed with a foe never down"):
			result.notes.append("closed with a foe never down")
		full = false
	var completion: CombatEncounterCompletionResult = coordinator.last_completion()
	var ending: CombatEncounterResult = null if completion == null else completion.terminal_result
	if not lost and (ending == null or ending.kind != CombatEncounterResultKind.Value.VICTORY or not ending.winning_side_ids().has(my_side)):
		lost = true
		var note: String = "ended %s" % ("?" if ending == null else CombatEncounterResultKind.Value.find_key(ending.kind))
		if not result.notes.has(note):
			result.notes.append(note)
	if verbose:
		var foes: Array = _enemies.map(func(npc: NpcRuntimeState) -> String: return "%s %d/%d %s" % [npc.definition().display_name, npc.character_state.vitality.current, npc.character_state.vitality.maximum, CharacterRuntimeLifeStatus.Value.find_key(npc.life_status)])
		print("  duel: %s rounds %d (lost at %d) steps %d ending %s foes %s" % ["won" if not lost else "lost", rounds, lost_rounds, steps, "?" if ending == null else CombatEncounterResultKind.Value.find_key(ending.kind), foes])
	return [not lost, rounds if not lost else lost_rounds, full]


## How many in `encounter` are neither the player nor the story's lineup (a bystander the room brought in).
func _others_in(encounter: CombatEncounter, player_id: StringName) -> int:
	var others: int = 0
	for participant: CombatParticipant in encounter.participants():
		var id: StringName = participant.participant_id
		if id != player_id and not (_enemies + _allies).any(func(npc: NpcRuntimeState) -> bool: return npc.character_id == id):
			others += 1
	return others


## The `away` spawns' NPCs off the map (withdrawn: alive, to no fight).
func _withdraw_away() -> void:
	for spawn_id: StringName in _fight.get("away", []):
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
		for point: StringName in ([] as Array[StringName]) if spawn == null else spawn.spawn_point_ids():
			map.npcs.withdraw(map.npcs.npc_at_point(point))


## The plain policy's order for this beat.
func _order(coordinator: CombatEncounterCoordinator) -> void:
	var encounter: CombatEncounter = coordinator.active_encounter()
	var player_id: StringName = session.player_runtime().character_id
	for npc: NpcRuntimeState in _enemies:
		if npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and encounter.participant_for(npc.character_id) != null and coordinator.player_can_target(npc.character_id):
			if encounter.current_target_for(player_id) != npc.character_id:
				coordinator.change_player_target(CombatTargetRequest.new(encounter.encounter_id, player_id, npc.character_id))
			break
	var unaffordable: Dictionary[StringName, String] = coordinator.unaffordable_moves()
	var locked: Dictionary[StringName, String] = coordinator.locked_moves()
	for move: CombatActionDefinition in coordinator.player_moves():
		if move.tag != CombatMoveTags.GUARD and not unaffordable.has(move.action_id) and not locked.has(move.action_id):
			if coordinator.choose_attack(move.action_id):
				return
	coordinator.yield_round()


func _bring_all(pairs: Array) -> Array[NpcRuntimeState]:
	var out: Array[NpcRuntimeState] = []
	for pair: Array in pairs:
		var npc: NpcRuntimeState = _bring(pair)
		if npc != null:
			out.append(npc)
	return out


## One [spawn, point]: summoned / appeared / made anew if dead; the NPC there, or null.
func _bring(pair: Array) -> NpcRuntimeState:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(StringName(pair[0]))
	var npc: NpcRuntimeState = map.npcs.npc_at_point(StringName(pair[1]))
	if spawn != null and spawn.summoned and (npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD):
		map.summon(StringName(pair[0]))
		npc = map.npcs.npc_at_point(StringName(pair[1]))
	if npc != null and npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD and spawn != null:
		map.npcs._respawn_npc(spawn, npc)
		npc = map.npcs.npc_at_point(StringName(pair[1]))
	if npc != null and not npc.exists_in_map and spawn != null:
		map.npcs.appear(npc, spawn)
	return npc


func _refind(pairs: Array) -> Array[NpcRuntimeState]:
	var out: Array[NpcRuntimeState] = []
	for pair: Array in pairs:
		var npc: NpcRuntimeState = map.npcs.npc_at_point(StringName(pair[1]))
		if npc != null:
			out.append(npc)
	return out


## One who follows the player there whatever was chosen (郭承): made beside the player as their own,
## following (the fights_beside rule takes them in as the fight opens).
func _follower(definition_id: StringName) -> NpcRuntimeState:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = map.npcs._new_beside(player.character_id, GameContent.catalog().npc(definition_id))
	if npc == null:
		return null
	map.npcs.summoners[npc.character_id] = player.character_id
	npc.set_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER, true)
	return npc


func _wield(definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var item := ItemInstance.new(&"sim:weapon", definition_id)
	context.inventory.register_item(item, GameContent.catalog().item(definition_id).own_weight)
	context.index.register_snapshot(item)
	context.inventory._apply_reparent(item.item_instance_id, context.endpoint())
	OldPineEquipmentInteractionAdapter.new().wield(session.player_runtime(), item.item_instance_id, session._inventory, session._item_index)


## The forecast verdict's word.
static func verdict_word(verdict: int) -> String:
	match verdict:
		CombatForecast.Verdict.SURE_WIN: return "稳赢"
		CombatForecast.Verdict.FAVOURED: return "占优"
		CombatForecast.Verdict.EVEN: return "五五开"
		CombatForecast.Verdict.UNFAVOURED: return "吃亏"
		CombatForecast.Verdict.SURE_LOSS: return "必败"
	return "—"
