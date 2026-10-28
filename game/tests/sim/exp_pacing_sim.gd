class_name ExpPacingSim
extends RefCounted

## Native (A2 经验节奏): how fast a new character's combat_exp and potential grow in play.
## Its consumers are common/progression.json and pacing.json's progression knobs (tuned
## from its report: tests/sim/run_exp_pacing_sim.gd) and their regression check
## (tests/sim/exp_pacing_sim_test.gd). One real session runs a route
## (tests/fixtures/exp_pacing_route.json): real fights, the scheduler advanced a round a
## second, real recovery between them (2 s pulses: player and NPC heal_up, food and water
## topped up, as at the well), the 历练 rewards from the game's own hooks. Walking is not
## simulated: each leg is the route's own seconds (path length at 220 px/s, from the
## maps) and the player is handed off there. Seeded; nothing here is read by the game.

const ROUND_SECONDS: float = 1.0
const PULSE_SECONDS: float = 2.0
## What a spar or an attack costs beyond its rounds: picking the target, the confirm,
## stepping into reach.
const ACTION_SECONDS: float = 6.0
## Walking to a spar partner on another map of the same town.
const NEXT_DOOR_SECONDS: float = 25.0
## One 请教 of the continuous run, with its line.
const LESSON_SECONDS: float = 1.0
## A spar run gives up after this many spars in a row that gained nothing.
const FRUITLESS_SPARS: int = 12

var tree: SceneTree
var session: WorldSessionController
## Play seconds so far.
var seconds: float = 0.0
## [{t, step, exp, pot}] after each step.
var timeline: Array[Dictionary] = []
## The first play second at which combat_exp reached each threshold.
var reached: Dictionary[int, float] = {}
## The log lines the 历练 rewards printed.
var rewards: Array[String] = []
var deaths: int = 0
## When and by whom the player died.
var death_notes: Array[String] = []
var death_times: Array[float] = []
## The first play second each specialized (family) skill reached level 1.
var first_special: Dictionary[StringName, float] = {}
## The play second max_force reached each exercise_to target.
var exercised: Dictionary[int, float] = {}
## Bounties paid.
var bounties_done: int = 0
## The last 拜师's outcome.
var joined: String = ""
## Why a spar did not begin (the NPC's name and the log's last line) -> how often.
var refusals: Dictionary[String, int] = {}
var spars: int = 0
var spar_wins: int = 0
const THRESHOLDS: Array[int] = [150, 400, 1001, 2500]


func _init(p_tree: SceneTree) -> void:
	tree = p_tree


## A New Game (Snow's inn) with seeded random streams.
func start(seed: int, gender: StringName = CharacterState.GENDER_MALE) -> bool:
	session = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("试炼", gender)
	session.deterministic_combat_seed = true
	session.combat_seed = 7000 + seed
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session.is_initialized()


func finish() -> void:
	if session != null:
		session.free()
		session = null
	await tree.process_frame


func state() -> CharacterState:
	return session.player_runtime().state


func unspent() -> int:
	return state().progression.potential - state().progression.potential_spent


## Runs the route's steps in order.
func run(route: Array) -> void:
	for step: Dictionary in route:
		var label: String = str(step.get("note", ""))
		if step.has("go"):
			var go: Dictionary = step["go"]
			await go_to(StringName(go["map"]), StringName(go["zone"]), StringName(go["spawn"]), float(step.get("walk_seconds", 0)))
		elif step.has("spar"):
			await spar(StringName(step["spar"]), int(step.get("until_exp", 0)), float(step.get("max_minutes", 30)) * 60.0, int(step.get("times", 0)))
		elif step.has("join"):
			await join(StringName(step["join"]))
		elif step.has("learn"):
			await learn(StringName(step["learn"]), step.get("skills", []), int(step.get("until_level", 999)), float(step.get("max_minutes", 20)) * 60.0)
		elif step.has("enable"):
			for use_id: String in step["enable"]:
				session.martial_arts().enable(StringName(use_id), StringName(step["enable"][use_id]))
			_pass(ACTION_SECONDS)
		elif step.has("bounties"):
			await bounties(int(step["bounties"]), float(step.get("walk_seconds", 240)), float(step.get("max_minutes", 60)) * 60.0)
		elif step.has("story"):
			story(StringName(step["story"]), float(step.get("minutes", 10)) * 60.0)
		elif step.has("exercise_to"):
			var took: float = exercise_to(int(step["exercise_to"]), float(step.get("max_minutes", 120)) * 60.0)
			if state().recovery.inner_force.maximum >= int(step["exercise_to"]):
				exercised[int(step["exercise_to"])] = seconds
			label += "（打坐 %.1f 分钟）" % (took / 60.0)
		elif step.has("rest_seconds"):
			_pass(float(step["rest_seconds"]))
		_note(label)


## Walks `walk_seconds` and arrives at `spawn_id` in `zone_id`: the arrival's rewards.
func go_to(map_id: StringName, zone_id: StringName, spawn_id: StringName, walk_seconds: float) -> void:
	_pass(walk_seconds)
	session.handoff_to(map_id, zone_id, zone_id, spawn_id)
	await _settle()
	_look()


## Spars the spawn group's NPCs in turn: until combat_exp reaches `until_exp` (0: no
## bound), `times` spars were fought (0: no bound), `max_seconds` passed, or
## FRUITLESS_SPARS in a row gained nothing.
func spar(spawn_id: StringName, until_exp: int, max_seconds: float, times: int) -> void:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	if spawn == null:
		push_error("sim: no spawn %s" % spawn_id)
		return
	var points: Array[StringName] = spawn.spawn_point_ids()
	var stand: StringName = points[1] if points.size() > 1 else points[0]
	await _stand_by(spawn, stand)
	var started: float = seconds
	var fought: int = 0
	var fruitless: int = 0
	var refused: int = 0
	var turn: int = 0
	while seconds - started < max_seconds and (until_exp <= 0 or state().progression.combat_experience < until_exp) and (times <= 0 or fought < times) and fruitless < FRUITLESS_SPARS and refused < 30:
		var map: WorldMapController = session.active_map() as WorldMapController
		var members: Array[NpcRuntimeState] = []
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.spawn_id == spawn_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.exists_in_map:
				members.append(npc)
		if members.is_empty():
			break
		var npc: NpcRuntimeState = members[turn % members.size()]
		turn += 1
		var exp_before: int = state().progression.combat_experience
		map.select_npc(npc.character_id)
		var begun: CombatSliceInitiationResult = map.spar_selected()
		_pass(ACTION_SECONDS)
		if begun.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
			# npc.c accept_fight(): not at 90% yet; the player waits a little.
			var said: Array[String] = session.shared_ui().log_lines()
			var why: String = "%s: %s (%s / %s)" % [npc.definition().display_name, said.back() if not said.is_empty() else "?", session.player_runtime().world_location().combat_location_id, npc.world_location().combat_location_id]
			refusals[why] = int(refusals.get(why, 0)) + 1
			refused += 1
			_pass(10.0)
			continue
		refused = 0
		fought += 1
		spars += 1
		var lines_before: int = session.shared_ui().log_lines().size()
		_fight()
		var log: Array[String] = session.shared_ui().log_lines()
		for index: int in range(lines_before, log.size()):
			if log[index].begins_with("【历练】你第一次在切磋中胜过了") or log[index].begins_with("【历练】你第一次击败了"):
				spar_wins += 1
		_rest()
		fruitless = 0 if state().progression.combat_experience > exp_before else fruitless + 1


## apprentice <the master of spawn_id> (TeacherService, as the popup's 拜师 does).
func join(spawn_id: StringName) -> void:
	var teacher: TeacherService = await _teacher(spawn_id)
	if teacher == null:
		return
	var outcome: NpcApprenticeship.Outcome = teacher.request_apprentice()
	_pass(ACTION_SECONDS)
	if outcome == NpcApprenticeship.Outcome.ANSWER_DUE:
		outcome = teacher.answer_apprentice()
	joined = NpcApprenticeship.Outcome.find_key(outcome)


## learn <skill> from the teacher of spawn_id, the skills in turn, until each is at
## `until_level`, potential runs out, the teacher has no more, or `max_seconds` passed;
## the player rests while gin is low (learn.c's gin cost).
func learn(spawn_id: StringName, skills: Array, until_level: int, max_seconds: float) -> void:
	var teacher: TeacherService = await _teacher(spawn_id)
	if teacher == null:
		return
	var started: float = seconds
	var settles: int = 0
	var open: Array = skills.duplicate()
	while not open.is_empty() and seconds - started < max_seconds and unspent() > 0:
		var s: CharacterState = state()
		if s.essence.current * 100 < s.essence.maximum * 40:
			while s.essence.current * 100 < s.essence.maximum * 95 and seconds - started < max_seconds:
				_pulse()
			continue
		var skill_id := StringName(open[0])
		if s.skills.raw_level(skill_id) >= until_level:
			open.pop_front()
			continue
		var result: LearnResult = teacher.request_learn(skill_id, true)
		_pass(LESSON_SECONDS)
		if result == null or not result.success or result.completion not in [LearnResult.Completion.PROGRESSED, LearnResult.Completion.LEVEL_INCREASED]:
			if result != null and result.completion == LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
				continue
			if result != null and result.failure_reason == LearnResult.FailureReason.TEACHER_UNAVAILABLE and settles < 3:
				# The body has not entered the zone's area yet.
				settles += 1
				await _settle()
				continue
			# The teacher's cap, learn.c's combat_exp gate, no potential: the next skill.
			var map: WorldMapController = session.active_map() as WorldMapController
			var tb: WorldCharacterBody2D = map.runtime_body_for_character(teacher.npc.character_id)
			var why: String = "%s %s: %s present=%s act=%s dist=%.0f zones %s/%s" % [teacher.display_name(), skill_id, "null" if result == null else "%s/%s" % [LearnResult.FailureReason.find_key(result.failure_reason), LearnResult.Completion.find_key(result.completion)], teacher.npc_present(), map.can_act(teacher.requires_idle()), -1.0 if tb == null else tb.global_position.distance_to(map.runtime_player_body().global_position), session.player_runtime().world_location().zone_id, teacher.npc.world_location().zone_id]
			refusals[why] = int(refusals.get(why, 0)) + 1
			open.pop_front()
			continue
		var definition: SkillDefinition = GameContent.catalog().skill(skill_id)
		if definition != null and definition.kind == SkillDefinition.Kind.SPECIALIZED and s.skills.raw_level(skill_id) >= 1 and not first_special.has(skill_id):
			first_special[skill_id] = seconds
		open.push_back(open.pop_front())


## 雪亭驿's bounties, `count` of them: each taken at the board (BountyService's 揭榜), walked
## to (`walk_seconds` there and back), its outlaw met where it comes out and fought to the
## end (attacked; 了结 or 放过 as the HUD asks: here 了结), then rest. A board with nothing
## for the player, or the time spent, ends the run; so does a fall.
func bounties(count: int, walk_seconds: float, max_seconds: float) -> void:
	var started: float = seconds
	var board: WorldBounties = session.bounties()
	for bounty: int in count:
		if seconds - started >= max_seconds:
			break
		var postings: Array[WorldBounties.Posting] = board.postings()
		while postings.is_empty() and seconds - started < max_seconds:
			_pass(30.0)
			board.advance(30.0)
			postings = board.postings()
		if postings.is_empty() or not board.take(postings[0].slot):
			break
		var posting: WorldBounties.Posting = board.taken()
		_pass(walk_seconds / 2.0)
		var map_definition: MapDefinition = GameContent.catalog().map(posting.place.map_id)
		if session.active_map_id() != posting.place.map_id:
			# Onto the map at its entry (its zone: the marker's ID less its last part), then on foot.
			var entry: String = String(map_definition.entry_spawn_id)
			var entry_zone := StringName(entry.substr(0, entry.rfind(".")))
			session.handoff_to(posting.place.map_id, entry_zone, entry_zone, map_definition.entry_spawn_id)
			await _settle()
		var map: WorldMapController = session.active_map() as WorldMapController
		if session.player_runtime().world_location().zone_id != posting.place.zone_id:
			var area: WorldPhysicalZoneArea2D = map.physical_zone(posting.place.zone_id)
			var spot: Vector2 = Vector2.INF if area == null else MapPlaces.spot(map, posting.place.zone_id, area.global_position)
			if spot.is_finite():
				map.runtime_player_body().global_position = spot
				session.player_runtime().set_world_location(map.location_for_zone(posting.place.zone_id))
			await _settle()
		# The outlaw comes out only while no fight holds the place (WorldBounties.look()): on a
		# slow machine (CI) more play time passes between frames, and one of the place's own
		# aggressors may reach the player first. As a player would, fight that one out, rest,
		# and look again, a few times.
		var outlaw: NpcRuntimeState = null
		for attempt: int in 6:
			if session.combat_encounter_coordinator().has_active_encounter():
				var paused: int = BattlePace.after_knockout
				BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
				_fight()
				BattlePace.after_knockout = paused
				_rest()
				await _settle()
			_look()
			await _settle()
			for npc: NpcRuntimeState in session.world_npcs():
				if npc.definition().definition_id == posting.tier.npc_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
					outlaw = npc
			if outlaw != null or deaths > 0:
				break
		if outlaw == null:
			push_error("sim: no outlaw came out at %s" % posting.place.zone_id)
			board.give_up()
			continue
		if not session.combat_encounter_coordinator().has_active_encounter():
			map.select_npc(outlaw.character_id)
			map.attack_selected()
		_pass(ACTION_SECONDS)
		var previous: int = BattlePace.after_knockout
		BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
		_fight()
		BattlePace.after_knockout = previous
		bounties_done += 1 if board.taken() == null else 0
		if board.taken() != null:
			board.give_up()
		_rest()
		_pass(walk_seconds / 2.0)
		if deaths > 0 or session.player_runtime().life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			break


## TEST-ONLY: the player sees chain `chain_id` through in `duration` (its entries are
## recorded, as if each condition had held in turn): the reward comes from the game's
## own look(). The time is the route's estimate of walking, asking and fighting for it.
func story(chain_id: StringName, duration: float) -> void:
	_pass(duration)
	for chain: JournalChainDefinition in GameContent.catalog().journal_chains():
		if chain.chain_id == chain_id:
			for entry: JournalEntryDefinition in chain.entries:
				state().journal[chain.key_of(entry)] = state().journal.size() + 1
	_look()


func _teacher(spawn_id: StringName) -> TeacherService:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	if spawn == null:
		push_error("sim: no spawn %s" % spawn_id)
		return null
	await _stand_by(spawn, spawn.spawn_point_ids()[0])
	var map: WorldMapController = session.active_map() as WorldMapController
	for node: Node in map.service_nodes:
		if node is TeacherService and (node as TeacherService).npc.spawn_id == spawn_id:
			return node
	push_error("sim: nobody teaches at %s" % spawn_id)
	return null


## 打坐 (30 kee a time, as the 武学 page's default) until max_force reaches `target`:
## each time while the player can, else 2 s pulses of recovery.
func exercise_to(target: int, max_seconds: float) -> float:
	var started: float = seconds
	if state().skills.mapped_skill(&"force").is_empty():
		push_error("sim: 打坐 needs an enabled force skill")
		return 0.0
	var arts: PlayerMartialArts = session.martial_arts()
	while state().recovery.inner_force.maximum < target and seconds - started < max_seconds:
		if state().recovery.inner_force.maximum >= CultivationService.exercise_cap(state(), arts.apply_modifier(&"force")):
			# exercise.c's bottleneck: 基本内功 must grow first.
			break
		var result: CultivationResult = arts.exercise(30, true)
		if result != null and result.success:
			# One command: a second or so of the player's time.
			_pass(1.0)
		else:
			_pass(PULSE_SECONDS)
	return seconds - started


## Walks next door (or across the street) to `spawn`'s zone: a handoff onto `stand` from
## another map; on the same map the body is put beside the spawn's NPC (TEST-ONLY, as the
## suites' _place()).
func _stand_by(spawn: NpcSpawnDefinition, stand: StringName) -> void:
	var location: WorldLocationState = session.player_runtime().world_location()
	if session.active_map_id() == spawn.map_id and location.zone_id == spawn.zone_id:
		return
	_pass(NEXT_DOOR_SECONDS)
	if session.active_map_id() != spawn.map_id:
		session.handoff_to(spawn.map_id, spawn.zone_id, spawn.zone_id, stand)
	else:
		var map: WorldMapController = session.active_map() as WorldMapController
		var body: WorldCharacterBody2D = null
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.spawn_id == spawn.spawn_id and body == null:
				body = map.runtime_body_for_character(npc.character_id)
		if body != null:
			# A free spot within reach (MapPlacementValidator: no wall, no body, no furniture).
			for offset: Vector2 in [Vector2(0, 40), Vector2(40, 0), Vector2(-40, 0), Vector2(0, -40), Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30), Vector2(-30, -30), Vector2(0, 70), Vector2(70, 0), Vector2(-70, 0), Vector2(0, -70)]:
				if MapPlacementValidator.is_valid_character_position(map, spawn.zone_id, body.global_position + offset):
					map.runtime_player_body().global_position = body.global_position + offset
					break
		session.player_runtime().set_world_location(map.location_for_zone(spawn.zone_id))
	await _settle()
	_look()


## After a handoff: physics frames so the body and its zone settle.
func _settle() -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _fight() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(ROUND_SECONDS)
		rounds += 1
		seconds += ROUND_SECONDS
		if advanced.cycles_processed == 0 and coordinator.has_active_encounter():
			break
	CombatEncounterCoordinator.take_aborted_total()
	# The fight's result is shown; the lines that wait for it follow.
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
	_look()
	if session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.DEAD or state().ghost:
		deaths += 1
		death_times.append(seconds)
		death_notes.append("%.1f min, exp %d, by %s" % [seconds / 60.0, state().progression.combat_experience, session.player_runtime().relationship.last_damage_from_id])


## Until kee and effective kee are full again (or the player has come to and healed).
func _rest() -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rested: float = 0.0
	while rested < 3600.0:
		var s: CharacterState = player.state
		if player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and s.vitality.current >= s.vitality.maximum and s.vitality.effective >= s.vitality.maximum and s.essence.current * 100 >= s.essence.maximum * 70:
			break
		_pulse()
		rested += PULSE_SECONDS


func _pass(duration: float) -> void:
	var left: float = duration
	while left > 0.0:
		_pulse()
		left -= PULSE_SECONDS


func _pulse() -> void:
	var s: CharacterState = state()
	s.recovery.food = maxi(s.recovery.food, 300)
	s.recovery.water = maxi(s.recovery.water, 300)
	session.advance_player_recovery(PULSE_SECONDS)
	session.advance_npc_heartbeat(PULSE_SECONDS)
	session.bounties().advance(PULSE_SECONDS)
	seconds += PULSE_SECONDS
	_reach()


func _look() -> void:
	var before: int = session.shared_ui().log_lines().size()
	session.record_journal()
	var log: Array[String] = session.shared_ui().log_lines()
	for index: int in range(maxi(0, before - 40), log.size()):
		if log[index].begins_with("【历练】") and not rewards.has(log[index]):
			rewards.append(log[index])
	_reach()


func _reach() -> void:
	for threshold: int in THRESHOLDS:
		if not reached.has(threshold) and state().progression.combat_experience >= threshold:
			reached[threshold] = seconds


func _note(label: String) -> void:
	timeline.append({"t": seconds, "step": label, "exp": state().progression.combat_experience, "pot": unspent()})


## The report: the timeline, when each threshold was reached, the rewards.
func report() -> String:
	var lines: Array[String] = []
	for row: Dictionary in timeline:
		lines.append("%7.1f min  exp %6d  pot %4d  %s" % [row["t"] / 60.0, row["exp"], row["pot"], row["step"]])
	for threshold: int in THRESHOLDS:
		lines.append("exp %d at %s" % [threshold, "%.1f min" % (reached[threshold] / 60.0) if reached.has(threshold) else "never"])
	for skill_id: StringName in first_special:
		lines.append("first %s at %.1f min" % [skill_id, first_special[skill_id] / 60.0])
	for target: int in exercised:
		lines.append("max_force %d at %.1f min" % [target, exercised[target] / 60.0])
	lines.append("joined: %s; skills %s" % [joined, _skills_text()])
	lines.append("bounties paid %d" % bounties_done)
	for note: String in death_notes:
		lines.append("died: " + note)
	lines.append("spars %d (first wins rewarded %d), deaths %d" % [spars, spar_wins, deaths])
	for why: String in refusals:
		lines.append("refused %d× %s" % [refusals[why], why])
	lines.append("rewards: %d" % rewards.size())
	for line: String in rewards:
		lines.append("  " + line)
	return "\n".join(lines)


## TEST-ONLY: a 封山剑派 beginner who can 打坐 to 50: 基本内功 5 and 封山派内功 5 learnt and
## enabled (exercise.c's bottleneck (5 + 5/5) * 10 = 60), constitution `con`.
static func prepare_exercise(s: CharacterState, con: int) -> void:
	s.attributes.constitution = con
	s.skills.set_raw_level(&"force", 5)
	s.skills.set_raw_level(&"fonxanforce", 5)
	s.skills.map_skill(&"force", &"fonxanforce")


func _skills_text() -> String:
	var parts: Array[String] = []
	for skill_id: StringName in state().skills.learned_skill_ids():
		parts.append("%s %d" % [skill_id, state().skills.raw_level(skill_id)])
	return ", ".join(parts)


static func load_route(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
