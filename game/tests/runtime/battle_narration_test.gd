extends RefCounted

## The battle log in ES2's words: combatd.c's damage, status, winner and guard
## tables, dodge.c and parry.c, message_vision() from the player's side, the
## riposte lines, and a real 切磋 in Snow read through the battle panel.
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Draws := preload("res://tests/support/scripted_combat_random_source.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const TRAINEE: StringName = &"snow.school2.trainee.1.character"

var assertions: int = 0
var failures: Array[String] = []


## Scripted draws; a negative value counts back from the bound (-1 is the
## highest draw). Past the script every draw is the highest.
class Pattern extends CombatRandomSource:
	var draws: Array[int] = []
	var calls: int = 0
	func _init(p_draws: Array[int] = []) -> void:
		draws = p_draws
	func next_below(bound: int) -> int:
		calls += 1
		var value: int = draws.pop_front() if not draws.is_empty() else -1
		return bound + value if value < 0 else value


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_tables()
	_message_vision()
	_dodge_from_the_player_side()
	_parry_by_the_attacker_weapon()
	_hit_status_and_winner()
	_riposte_lines()
	await _spar_in_snow(tree)
	return {"assertions": assertions, "failures": failures}


func _tables() -> void:
	var damage := Callable(Es2CombatMessages, "damage_message")
	check(damage.call(0, "瘀伤") == "结果没有造成任何伤害。", "damage 0")
	check(damage.call(9, "割伤") == "结果只是轻轻地划破$p的皮肉。" and damage.call(10, "割伤") == "结果在$p$l划出一道细长的血痕。", "割伤 10")
	check(damage.call(159, "割伤") == "结果「嗤」地一声划出一道又长又深的伤口，溅得$N满脸鲜血！", "割伤 159")
	check(damage.call(160, "割伤") == "结果只听见$n一声惨嚎，$w已在$p$l划出一道深及见骨的可怕伤口！！", "割伤 160")
	check(damage.call(30, "□伤") == damage.call(30, "割伤"), "the source's □伤 case shares 割伤")
	check(damage.call(79, "刺伤") == "结果「噗」地一声刺进$n的$l，使$p不由自主地退了几步！", "刺伤 79")
	check(damage.call(80, "刺伤") == "结果「噗嗤」地一声，$w已在$p$l刺出一个血肉□糊的血窟窿！", "刺伤 80 keeps the source's □")
	check(damage.call(119, "瘀伤") == "结果「砰」地一声，$n退了两步！" and damage.call(120, "瘀伤") == "结果这一下「砰」地一声打得$n连退了好几步，差一点摔倒！", "瘀伤 120")
	check(damage.call(239, "瘀伤") == "结果重重地击中，$n「哇」地一声吐出一口鲜血！" and damage.call(240, "瘀伤") == "结果只听见「砰」地一声巨响，$n像一捆稻草般飞了出去！！", "瘀伤 240")
	# The other types: a degree line whose {type} the narrator fills (damage_type_word()).
	var typed := func(amount: int, type: String) -> String:
		return Es2CombatMessages.damage_message(amount, type).format({"type": Es2CombatMessages.damage_type_word(type)})
	check(typed.call(9, "咬伤") == "结果只是勉强造成一处轻微咬伤！" and typed.call(29, "咬伤") == "结果造成一处咬伤！" and typed.call(30, "咬伤") == "结果造成一处严重咬伤！", "other types: degree + type")
	check(typed.call(229, "抓伤") == "结果造成极其严重的抓伤！" and typed.call(230, "抓伤") == "结果造成非常可怕的严重抓伤！", "抓伤 230")
	check(typed.call(25, "砍伤") == "结果造成一处砍伤！", "weapond.c's 砍伤 falls to the default branch")
	check(typed.call(50, "") == "结果造成颇为严重的伤害！", "no type reads 伤害")
	var status := Callable(Es2CombatMessages, "status_message")
	check(status.call(100) == "看起来充满活力，一点也不累。" and status.call(96) == "似乎有些疲惫，但是仍然十分有活力。" and status.call(95) == "看起来可能有些累了。", "status_msg top")
	check(status.call(11) == "摇头晃脑、歪歪斜斜地站都站不稳，眼看就要倒在地上。" and status.call(10) == "已经陷入半昏迷状态，随时都可能摔倒晕去。" and status.call(-3) == status.call(10), "status_msg bottom")
	var effective := Callable(Es2CombatMessages, "effective_status_message")
	check(effective.call(100) == "看起来气血充盈，并没有受伤。" and effective.call(61) == "受伤不轻，看起来状况并不太好。" and effective.call(60) == "气息粗重，动作开始散乱，看来所受的伤著实不轻。", "eff_status_msg 60")
	check(effective.call(6) == "受伤过重，已经奄奄一息，命在旦夕了。" and effective.call(5) == "受伤过重，已经有如风中残烛，随时都可能断气。", "eff_status_msg 5")
	check(Es2CombatMessages.WINNER.size() == CombatPostRelationshipService.WINNER_PRESENTATION_COUNT, "one winner line per Core draw")
	check(Es2CombatMessages.GUARD.size() == CombatFightDecisionService.GUARD_PRESENTATION_COUNT, "one guard line per Core draw")
	check(Es2CombatMessages.parry_messages(true).size() == 4 and Es2CombatMessages.parry_messages(false).size() == 2, "parry.c two sets")
	check(Es2CombatMessages.dodge_messages(&"").size() == 5 and Es2CombatMessages.dodge_messages(&"dodge") == Es2CombatMessages.dodge_messages(&""), "dodge.c")
	var steps: Array[String] = Es2CombatMessages.dodge_messages(&"chaos-steps")
	check(steps.size() == 7 and steps[6] == "但是$n一招「瑶光音迟」使出，早已绕到$N身後！", "chaos-steps.c: a mapped dodge skill's own lines")
	check(Es2CombatMessages.dodge_messages(&"liuh-ken") == Es2CombatMessages.dodge_messages(&""), "a mapped skill without dodge lines reads dodge.c's")
	check(Es2CombatMessages.pronoun(CharacterState.GENDER_MALE) == "他" and Es2CombatMessages.pronoun(CharacterState.GENDER_FEMALE) == "她" and Es2CombatMessages.pronoun(CharacterState.GENDER_ANIMAL_MALE) == "它" and Es2CombatMessages.pronoun(&"") == "它", "gender.c pronouns")


func _message_vision() -> void:
	var line: String = "$N看了$n一眼，$P心想$p不好惹。"
	var as_me := _cast(&"p", &"p", "雪工", CharacterState.GENDER_FEMALE, &"n", "武馆弟子", CharacterState.GENDER_MALE)
	check(BattleNarrator.vision(line, &"p", &"n", as_me) == "你看了武馆弟子一眼，你心想他不好惹。", "as $N: you, then the other's name and pronoun")
	check(BattleNarrator.vision(line, &"n", &"p", as_me) == "武馆弟子看了你一眼，他心想你不好惹。", "as $n: their name and pronoun, then you")
	var bystander := _cast(&"x", &"p", "雪工", CharacterState.GENDER_FEMALE, &"n", "武馆弟子", CharacterState.GENDER_MALE)
	check(BattleNarrator.vision(line, &"n", &"p", bystander) == "武馆弟子看了雪工一眼，武馆弟子心想雪工不好惹。", "a bystander reads names for every token")
	check(BattleNarrator.vision(Es2CombatMessages.GUARD[4], &"p", &"", as_me) == "你慢慢地移动著脚步，伺机出手。", "a line about one person")


func _dodge_from_the_player_side() -> void:
	var actor := Martial.binding(&"actor")
	var target := Martial.binding(&"target")
	target.state.gender = CharacterState.GENDER_FEMALE
	var rng := Draws.new([0, 0, 0])
	var forward := Martial.execute(actor, target, rng)
	check(forward.ordinary_attack_result.base_result.outcome == CombatAttackResult.Outcome.DODGE, "fixture dodges")
	var cast := _cast(&"actor", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_FEMALE)
	var calls: int = rng.call_count()
	var lines := _texts(BattleNarrator.new(_seeded(1)).attack_chain(forward, null, cast))
	check(rng.call_count() == calls, "narration draws nothing from the combat source")
	check(lines.size() == 2 and lines[0] == "你使一招「古松挂月」，对准对手的头部「呼」地一拳！", "the action from the attacker's side %s" % str(lines))
	var dodges: Array[String] = []
	for message: String in Es2CombatMessages.dodge_messages(&"dodge"):
		dodges.append(message.replace("$p", "她").replace("$n", "对手").replace("$l", "头部"))
	check(lines.size() == 2 and lines[1] in dodges, "a dodge.c line about her %s" % str(lines))
	check(_texts(BattleNarrator.new(_seeded(1)).attack_chain(forward, null, cast)) == lines, "the same seed picks the same words")
	var picked: Dictionary[String, bool] = {}
	for seed: int in range(20):
		picked[_texts(BattleNarrator.new(_seeded(seed)).attack_chain(forward, null, cast))[1]] = true
	check(picked.size() > 1, "the dodge line varies with the presentation's own draws")


func _parry_by_the_attacker_weapon() -> void:
	var bystander := _cast(&"", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_MALE)
	for armed: bool in [true, false]:
		var actor := Martial.binding(&"actor")
		if armed:
			actor.state.equipment.wield(Martial.sword(), false)
		var forward := Martial.execute(actor, Martial.binding(&"target"), Pattern.new([0, 0, -1, 0]))
		check(forward.ordinary_attack_result.base_result.outcome == CombatAttackResult.Outcome.PARRY, "fixture parries, armed %s" % armed)
		var lines := _texts(BattleNarrator.new(_seeded(3)).attack_chain(forward, null, bystander))
		var parries: Array[String] = []
		for message: String in Es2CombatMessages.parry_messages(armed):
			parries.append(message.replace("$p", "对手").replace("$n", "对手"))
		check(lines.size() == 2 and lines[1] in parries, "parry.c by the attacker's weapon, armed %s %s" % [armed, str(lines)])
		if armed:
			check(lines[0] == "学徒挥动长剑，斩向对手的头部！", "$w is the weapon's name %s" % str(lines))


func _hit_status_and_winner() -> void:
	var actor := Martial.binding(&"actor")
	var target := Martial.binding(&"target")
	target.state.gender = CharacterState.GENDER_FEMALE
	actor.relationship.add_opponent(&"target")
	target.relationship.add_opponent(&"actor")
	var forward := Martial.execute(actor, target, Pattern.new(), true)
	var base: CombatAttackResult = forward.ordinary_attack_result.base_result
	check(base.outcome == CombatAttackResult.Outcome.HIT and forward.post_relationship_result.has_winner_presentation_index, "fixture hits and Core draws the winner line")
	if base.outcome != CombatAttackResult.Outcome.HIT or not forward.post_relationship_result.has_winner_presentation_index:
		return
	var damage: int = base.resource_mutation.requested_damage
	var status: CombatStatusReportBoundaryResult = forward.ordinary_attack_result.status_report_result
	var winner: String = Es2CombatMessages.WINNER[forward.post_relationship_result.winner_presentation_index]
	var words: String = Es2CombatMessages.damage_message(damage, "瘀伤")
	var as_attacker := _cast(&"actor", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_FEMALE)
	var lines: Array[BattleNarrationLine] = BattleNarrator.new(_seeded(0)).attack_chain(forward, null, as_attacker)
	check(_texts(lines) == [
		"你步履一沉，左拳拉开，右拳使出「荒山虎吟」击向对手右脚！",
		words.replace("$N", "你").replace("$p", "她").replace("$n", "对手").replace("$l", "右脚"),
		"( 对手%s )" % Es2CombatMessages.status_message(status.ratio),
		winner.replace("$N", "你").replace("$n", "对手"),
	], "action, damage_msg, report_status and winner_msg from the attacker's side %s" % str(_texts(lines)))
	check(lines.size() == 4 and lines[1].damage == damage and lines[1].rich_text().ends_with("（-%d）[/font_size][/color]" % damage) and not lines[0].has_damage, "the damage rides on its line, small and grey")
	var as_victim := _cast(&"target", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_FEMALE)
	lines = BattleNarrator.new(_seeded(0)).attack_chain(forward, null, as_victim)
	check(_texts(lines) == [
		"学徒步履一沉，左拳拉开，右拳使出「荒山虎吟」击向你右脚！",
		words.replace("$N", "学徒").replace("$p", "你").replace("$n", "你").replace("$l", "右脚"),
		"( 你%s )" % Es2CombatMessages.status_message(status.ratio),
		winner.replace("$N", "学徒").replace("$n", "你"),
	], "the same blow from the victim's side %s" % str(_texts(lines)))


func _riposte_lines() -> void:
	var cast := _cast(&"actor", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_MALE)
	for quick: bool in [true, false]:
		var actor := Martial.binding(&"actor")
		var target := Martial.binding(&"target")
		target.relationship.set_guarding(true)
		var forward := Martial.execute(actor, target, Draws.new([1, 0, 0, 0 if quick else 5]), true)
		check(forward.has_riposte_request, "fixture ripostes, quick %s" % quick)
		if not forward.has_riposte_request:
			continue
		var projection := CombatSliceProjectionBuilder.build_reverse_projection(target, actor, forward.riposte_request)
		var chain := CombatAttackChainCompletionService.complete(forward, projection, Draws.new([3, 0, 0]))
		var lines := _texts(BattleNarrator.new(_seeded(0)).attack_chain(forward, chain, cast))
		var counter: String = "你一击不中，露出了破绽！" if quick else "对手见你攻击失误，趁机发动攻击！"
		check(lines.size() == 5 and lines[2] == counter, "combatd.c riposte line %s" % str(lines))
		check(lines.size() == 5 and lines[3] == "对手步履一沉，左拳拉开，右拳使出「荒山虎吟」击向你头部！" and lines[4].begins_with("但是"), "then the counter itself %s" % str(lines))


func _spar_in_snow(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "fixture walks out to the square")
	for frame: int in range(5):
		await tree.process_frame
	var map := session.active_map() as WorldMapController
	map.relocate_player(&"snow.school2", &"snow.school2.trainee.6")
	map.select_npc(TRAINEE)
	map.spar_selected()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	check(coordinator.has_active_encounter(), "the trainee accepts the spar")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var reader := BattleFeedbackReader.new(_seeded(7))
	var projection := BattleProjectionBuilder.build(session)
	var lines: Array[String] = []
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		projection = BattleProjectionBuilder.build(session)
		ui.refresh_projection()
		coordinator.advance_scheduler(1.0)
		rounds += 1
		var random_before: int = session.combat_random_source().capture_random_state().state
		for entry: BattleFeedbackProjection in reader.read_new(coordinator, projection):
			lines.append_array(_texts(entry.lines()))
		check(session.combat_random_source().capture_random_state().state == random_before, "reading the log draws nothing")
	ui.refresh_projection()
	for entry: BattleFeedbackProjection in reader.read_new(coordinator, projection):
		lines.append_array(_texts(entry.lines()))
	check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.SPAR_CONCLUDED, "the spar ends (%d rounds)" % rounds)
	var latin := RegEx.create_from_string("[A-Za-z$]")
	var foreign: Array = lines.filter(func(line: String) -> bool: return line.is_empty() or latin.search(line) != null)
	check(not lines.is_empty() and foreign.is_empty(), "every line is Chinese with its tokens resolved %s" % str(foreign))
	check(lines.any(func(line: String) -> bool: return line.begins_with("你")), "the player reads 你")
	check(lines.any(func(line: String) -> bool: return line.begins_with("( ")), "report_status after a blow")
	var winners: Array[String] = []
	for message: String in Es2CombatMessages.WINNER:
		winners.append(message.replace("$N", "你").replace("$n", "武馆弟子"))
		winners.append(message.replace("$N", "武馆弟子").replace("$n", "你"))
	check(lines.back() in winners, "the spar ends on winner_msg %s" % str(lines.slice(-4)))
	var log_text: String = ui.log_panel._text.get_parsed_text()
	check(log_text.contains(lines.back()) and log_text.contains("（-"), "the panel's log has the winner line and grey damage")
	check(session.shared_ui().log_lines().back().begins_with("切磋结束。\n"), "the world log closes with 切磋结束。 and the last lines")
	session.free()
	await tree.process_frame


static func _cast(
	player: StringName, a: StringName, a_name: String, a_gender: StringName,
	b: StringName, b_name: String, b_gender: StringName,
) -> BattlePresentationProjection:
	return BattlePresentationProjection.new(&"narration", CombatEncounterMode.Value.SPAR, player, b, [
		BattleParticipantProjection.new(a, a_name, &"a", false, b, null, null, null, null, null, null, 0, 0, 0, true, false, a_gender),
		BattleParticipantProjection.new(b, b_name, &"b", true, a, null, null, null, null, null, null, 0, 0, 0, true, true, b_gender),
	])


static func _seeded(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _texts(lines: Array[BattleNarrationLine]) -> Array[String]:
	var texts: Array[String] = []
	for line: BattleNarrationLine in lines:
		texts.append(line.text)
	return texts


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("battle narration: " + label)
