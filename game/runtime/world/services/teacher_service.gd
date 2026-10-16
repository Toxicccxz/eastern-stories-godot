class_name TeacherService
extends NpcService

## cmds/std/learn.c and apprentice.c with an NPC that teaches: whoever its family
## or recognize_apprentice() admits learns the skills it has that skills.json
## defines (NpcTeacher); a master with an attempt_apprentice() rule takes
## apprentices (NpcApprenticeship). Its lines go to the log; the panel shows the
## student's skills and the last lines. Enabling is the player's own (武学 page).
var ui: TeacherPanel
var last_learn: LearnResult
var last_lines: Array[String] = []


func bind_npc(p_map: WorldMapController, p_npc: NpcRuntimeState) -> void:
	super.bind_npc(p_map, p_npc)
	ui = TeacherPanel.new()
	ui.name = "TeachingUI"
	ui.configure(self)
	add_child(ui)


func verb() -> String:
	return tr("请教")


func requires_idle() -> bool:
	return true


func interact() -> void:
	ui.interact()


func can_teach() -> bool:
	return in_reach()


func teaching() -> NpcTeaching:
	return npc.definition().teaching()


func teachable_skills() -> Array[StringName]:
	return NpcTeacher.teachable_skills(npc.definition(), GameContent.catalog())


func takes_apprentices() -> bool:
	return teaching() != null and teaching().apprentice != null


## apprentice <npc>; living(ob) first ("你必须先把…弄醒。"). A master that answers later
## starts its call_out (NpcApprenticeship.Outcome.ANSWER_DUE); answer_apprentice() follows.
func request_apprentice() -> NpcApprenticeship.Outcome:
	last_lines = []
	if not can_teach() or not takes_apprentices():
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		_say([tr("你必须先把%s弄醒。") % tr(display_name())])
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var request: NpcApprenticeship = player.apprenticeship_request
	request.affords = map.player_can_afford
	var outcome: NpcApprenticeship.Outcome = player.request_apprenticeship(
		npc.definition(), GameContent.catalog().family(teaching().family_id), int(Time.get_unix_time_from_system()),
		map.npc_life.apprentice_answer_due(npc),
	)
	if outcome == NpcApprenticeship.Outcome.ANSWER_DUE:
		map.npc_life.start_apprentice_answer(npc, teaching().apprentice.answer_after)
	var lines: Array[ColoredLine] = []
	for line: String in request.lines:
		lines.append(ColoredLine.new(line))
	if outcome == NpcApprenticeship.Outcome.ATTACKED:
		# juechen/master.c: its chat line, shouted in the room (HIC, modern fixes II), grin
		# (prints nothing), kill_ob(ob).
		lines.append(ColoredLine.new(request.chat_line, ColoredLine.HIC))
		_say_colored(lines)
		map.npc_kills_player(npc)
		return outcome
	_say_colored(lines)
	return outcome


## taolord.c do_recruit(), when its call_out is due with the player before it
## (WorldMapNpcLife): its say, and its recruit or refusal. An open panel shows the lines.
## A player lying unconscious reads nothing (NpcApprenticeship.answer()).
func answer_apprentice(awake: bool = true) -> NpcApprenticeship.Outcome:
	last_lines = []
	if not takes_apprentices():
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var player: WorldPlayerRuntimeState = map.player_runtime()
	player.apprenticeship_request.affords = map.player_can_afford
	var outcome: NpcApprenticeship.Outcome = player.apprenticeship_answer(
		npc.definition(), GameContent.catalog().family(teaching().family_id), int(Time.get_unix_time_from_system()), awake,
	)
	_say(player.apprenticeship_request.lines)
	if awake:
		ui.show_answer()
	return outcome


## The master takes apprentices by an oath (萧辟尘), asked the player for it and is
## awake (an unconscious NPC's command() does nothing).
func awaits_oath() -> bool:
	return (
		takes_apprentices() and teaching().apprentice.kind == NpcTeaching.Kind.OATH
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and map.player_runtime().apprenticeship_request.awaits_oath(npc.definition().definition_id)
	)


## The master's accept test can be taken (champion.c's accept test): it takes
## apprentices by a test, is awake and free to strike (not in a fight), and the test
## would change something: the player is not its apprentice already (it would only end
## in 好徒儿) and it has not offered already (拜师 takes them; owner: not offered). A
## master with checks tests only those they pass (elon.c's do_accept() says 老身不收男徒!
## to a man and nothing to one short of 100000 combat_exp; DECISIONS 晚月庄 D).
func offers_trial() -> bool:
	var request: NpcApprenticeship = map.player_runtime().apprenticeship_request
	return (
		takes_apprentices() and teaching().apprentice.kind == NpcTeaching.Kind.TRIAL
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and npc.combat_available and not npc.relationship.is_fighting()
		and not NpcApprenticeship.is_master_of(map.player_runtime().state, npc.definition())
		and not request.is_offered(npc.definition().definition_id)
		and NpcApprenticeship.qualifies(map.player_runtime().state, teaching().apprentice)
		and not map.npc_life.trial_running(npc)
	)


## swear (master.c do_swear()): the oath ES2 accepts, from the owner's fixed button.
func swear_oath() -> NpcApprenticeship.Outcome:
	last_lines = []
	if not can_teach() or not awaits_oath():
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var outcome: NpcApprenticeship.Outcome = player.swear_oath(
		npc.definition(), GameContent.catalog().family(teaching().family_id), int(Time.get_unix_time_from_system()),
	)
	_say(player.apprenticeship_request.lines)
	return outcome


## accept test (champion.c do_accept()): the master's blows (NpcApprenticeTrial), each
## a do_attack() outside any fight; a player whose kee went below zero falls on the
## heart beat that follows (char.c), run here at once. ES2 strikes them in one go; with
## pacing.json's trial_blow_ms the first comes now and each other that long after
## (WorldMapNpcLife's call_out: the menu and a fight hold it), the result unchanged
## (DECISIONS「响应性」). Returns the result so far.
func take_trial() -> NpcApprenticeTrial.Result:
	last_lines = []
	if not can_teach() or not offers_trial():
		return NpcApprenticeTrial.Result.new()
	var test: NpcApprenticeTrial.Run = _start_trial()
	var spacing: float = GameContent.catalog().pacing().trial_blow_seconds
	if spacing <= 0.0:
		while not test.finished:
			test.step()
		return _trial_over(test)
	trial_step(test)
	if not test.finished:
		map.npc_life.start_trial(npc, self, test, spacing)
	return test.result


## The next blow of a test under way (its call_out came due): its lines in the log and
## the panel, and the end when it was the last. One who left the master's room between
## blows has walked out of the test.
func trial_step(test: NpcApprenticeTrial.Run) -> void:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	if test.result.blows > 0 and not _trial_stands(player):
		test.abandon()
		_trial_over(test)
		return
	_say_colored(test.step())
	last_lines = ColoredLine.texts(test.result.lines)
	if test.finished:
		_trial_over(test)
	ui.show_answer()


## A test that ended between blows (the master gone, the player off the map): failed.
func trial_abandoned(test: NpcApprenticeTrial.Run) -> void:
	_trial_over(test)


func _start_trial() -> NpcApprenticeTrial.Run:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var master: NpcDefinition = npc.definition()
	var family: FamilyDefinition = GameContent.catalog().family(teaching().family_id)
	var cast: BattlePresentationProjection = BattleProjectionBuilder.cast_of(map.session, [npc.character_id])
	var narrator := BattleNarrator.new()
	var attack := func() -> Variant:
		var seen: Array[ColoredLine] = []
		var blow: CombatSliceOpportunityResult = map.attack_player_outside_fight(npc)
		if blow == null:
			return null
		for line: BattleNarrationLine in narrator.attack_chain(blow.forward_result, blow.chain_result, cast, blow.post_action_lines(), blow.reverse_post_action_lines()):
			seen.append(ColoredLine.new(line.text, line.color))
		return seen
	var stands := _trial_stands.bind(player)
	var recruit := func() -> NpcApprenticeship.Outcome:
		return player.recruited_by(master, family, int(Time.get_unix_time_from_system()))
	return NpcApprenticeTrial.start(teaching().apprentice, player.apprenticeship_request, attack, stands, recruit)


## Whether the student still stands before the master (champion.c's checks after a blow).
func _trial_stands(player: WorldPlayerRuntimeState) -> bool:
	var location: WorldLocationState = player.world_location()
	return (
		player.state.vitality.current >= 0 and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and location != null and npc.exists_in_map and location.zone_id == npc.world_location().zone_id
	)


## The test is over: a failed one is the master's refusal, so a request waiting on it is
## over (DECISIONS 山烟寺 C); struck all at once (ES2), its lines are said now; one left
## below zero falls.
func _trial_over(test: NpcApprenticeTrial.Run) -> NpcApprenticeTrial.Result:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var result: NpcApprenticeTrial.Result = test.result
	if result.outcome == NpcApprenticeTrial.Outcome.FAILED:
		player.apprenticeship_request.end_request(npc.definition().definition_id)
	if GameContent.catalog().pacing().trial_blow_seconds <= 0.0:
		_say_colored(result.lines)
	if player.state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		map.player_fall_below_zero()
	return result


func cancel_apprentice() -> NpcApprenticeship.Outcome:
	last_lines = []
	if not can_teach():
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var request: NpcApprenticeship = map.player_runtime().apprenticeship_request
	var outcome: NpcApprenticeship.Outcome = request.cancel()
	_say(request.lines)
	return outcome


## learn <skill> from <npc>, with fresh facts on every request.
func request_learn(skill_id: StringName) -> LearnResult:
	last_lines = []
	var catalog: ContentCatalog = GameContent.catalog()
	var random: WorldInteractionRandomSource = map.world_interaction_random_source()
	if not teachable_skills().has(skill_id) or not can_teach() or random == null:
		last_learn = LearnResult.new(skill_id)
		last_learn.failure_reason = LearnResult.FailureReason.TEACHER_UNAVAILABLE
		return last_learn
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, player.relationship.is_fighting(), random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = catalog.skill(skill_id)
	last_learn = LearnService.learn(player.state, context, skill, registry.policy_for(skill_id), map.encounter_skill_effect_registry(), random)
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	_say_colored(LearnLines.colored(last_learn, display_name(), skill, player.state, context, respect))
	return last_learn


func _say(lines: Array[String]) -> void:
	var colored: Array[ColoredLine] = []
	for line: String in lines:
		colored.append(ColoredLine.new(line))
	_say_colored(colored)


func _say_colored(lines: Array[ColoredLine]) -> void:
	last_lines = ColoredLine.texts(lines)
	if map.session != null and not lines.is_empty():
		map.session.shared_ui().append_colored_lines(lines)
