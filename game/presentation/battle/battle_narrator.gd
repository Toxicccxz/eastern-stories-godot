class_name BattleNarrator
extends RefCounted

## Turns committed combat results into ES2's lines (combatd.c do_attack() and
## fight()), as message_vision() shows them to the player. It never touches the
## combat random source: winner and guard lines use Core's draws, and the dodge
## and parry line is picked here because it only changes the words (DECISIONS).
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_rng = rng


## The lines one resolved combat opportunity printed, in do_attack() order, or what
## an NPC's chat() or a timed special's end said or did.
func opportunity(event: CombatSchedulerEvent, cast: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	if event.kind == CombatSchedulerEvent.Kind.NPC_CHAT and event.chat != null:
		if event.chat.special() != null:
			return special(event.chat.special(), cast)
		return seen(event.chat.lines(), cast)
	if event.kind == CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED and event.special != null:
		return special(event.special, cast)
	if event.kind != CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED or event.resolution == null:
		return lines
	var result: CombatSliceOpportunityResult = event.resolution
	if result.outcome == CombatSliceOpportunityResult.Outcome.ENTERED_GUARDING:
		var decision: CombatFightDecisionResult = result.fight_decision_result
		if decision != null and decision.has_guard_presentation_index:
			lines.append(BattleNarrationLine.new(vision(
				tr(Es2CombatMessages.GUARD[decision.guard_presentation_index]), event.actor_id, event.target_id, cast)))
		return lines
	if result.forward_result == null:
		return lines
	return attack_chain(result.forward_result, result.chain_result, cast, result.post_action_lines(), result.reverse_post_action_lines())


## One forward do_attack() and, when the victim answers, the riposte line and
## the counter (`chain`'s reverse attack; null when there is none). `told` and
## `reverse_told` are what the player sees of each attack's post_action (throw_weapon,
## bash_weapon), printed after that attack, before the riposte (combatd.c).
func attack_chain(
	forward: CombatSingleAttackExecutionResult, chain: CombatAttackChainResult, cast: BattlePresentationProjection,
	told: Array[ColoredLine] = [], reverse_told: Array[ColoredLine] = [],
) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	if not forward.post_action_reached:
		return lines # Only an aborting fight stops short; its abort line tells it.
	_attack(lines, forward.ordinary_attack_result, _selected(forward.action_selection_result),
		forward.post_action_weapon_present, forward.post_action_weapon_id, forward.post_relationship_result, cast)
	for line: ColoredLine in told:
		lines.append(BattleNarrationLine.new(line.text, -1, line.color))
	if not forward.has_riposte_request:
		return lines
	# The riposte request runs from the victim back at the attacker.
	var request: CombatRiposteRequest = forward.riposte_request
	if request.attack_type == CombatAttackType.Value.QUICK:
		lines.append(BattleNarrationLine.new(vision(tr(Es2CombatMessages.QUICK_COUNTER), request.victim_id, &"", cast)))
	else:
		lines.append(BattleNarrationLine.new(vision(tr(Es2CombatMessages.RIPOSTE_COUNTER), request.attacker_id, request.victim_id, cast)))
	if chain != null and chain.reverse_execution_reached:
		_attack(lines, chain.reverse_ordinary_result, _selected(chain.reverse_action_selection_result),
			chain.reverse_weapon_present, chain.reverse_weapon_profile_id, chain.reverse_relationship_result, cast)
		for line: ColoredLine in reverse_told:
			lines.append(BattleNarrationLine.new(line.text, -1, line.color))
	return lines


## One do_attack(): the action, how it ended, then report_status() and
## winner_msg after a blow that drew kee.
func _attack(
	lines: Array[BattleNarrationLine], ordinary: CombatOrdinaryAttackResult, action: CombatActionDefinition,
	armed: bool, weapon_id: StringName, relationship: CombatPostRelationshipResult,
	cast: BattlePresentationProjection,
) -> void:
	if ordinary == null or not ordinary.has_base_result or action == null:
		return
	var base: CombatAttackResult = ordinary.base_result
	if base.outcome not in [CombatAttackResult.Outcome.DODGE, CombatAttackResult.Outcome.PARRY, CombatAttackResult.Outcome.HIT]:
		return
	var me: StringName = base.attacker_id
	var victim: StringName = base.defender_id
	var limb: String = String(base.calculation.selected_limb)
	var weapon: String = _weapon_name(armed, weapon_id)
	if base.calculation.hit_condition_applied and victim == cast.player_id:
		# hit_ob() tell_object()s the victim at once, before do_attack() prints its result.
		var hit: NpcHitCondition = base.calculation.hit_condition
		lines.append(BattleNarrationLine.new(tr(hit.message), -1, hit.color))
	if not action.legacy_action_text.is_empty():
		# TRANSLATORS: combatd.c: an attack's own line ({action}, e.g. $N用爪子往$n的$l一抓) and its "！".
		lines.append(BattleNarrationLine.new(vision(
			_limb_and_weapon(tr("{action}！").format({"action": tr(action.legacy_action_text)}), limb, weapon), me, victim, cast)))
	if base.has_standard_force_result and base.standard_force_result.outcome == StandardForceHitResult.Outcome.REFLECTION:
		# combatd.c adds the force hit's line before the damage line.
		lines.append(BattleNarrationLine.new(vision(
			tr(Es2CombatMessages.force_reflection_message(base.standard_force_result.reflection_mutation.requested_wound)), me, victim, cast)))
	if base.calculation.force_wound > 0 and base.calculation.force_hit_wound != null:
		# iceforce.c hit_ob() returns its line in place of the force hit's number.
		lines.append(BattleNarrationLine.new(vision(tr(base.calculation.force_hit_wound.message), me, victim, cast)))
	if not base.calculation.martial_message.is_empty():
		# spicyclaw.c hit_ob() returns its line after the force hit's.
		lines.append(BattleNarrationLine.new(vision(_limb_and_weapon(tr(base.calculation.martial_message), limb, weapon), me, victim, cast)))
	var damage: int = -1
	var outcome: String
	match base.outcome:
		CombatAttackResult.Outcome.DODGE:
			var participant: BattleParticipantProjection = cast.participant(victim)
			outcome = _pick(Es2CombatMessages.dodge_messages(&"" if participant == null else participant.dodge_skill_id))
		CombatAttackResult.Outcome.PARRY:
			outcome = _pick(Es2CombatMessages.parry_messages(armed))
		CombatAttackResult.Outcome.HIT:
			damage = base.resource_mutation.requested_damage
			outcome = Es2CombatMessages.damage_message(damage, String(action.damage_type))
	var type: String = tr(Es2CombatMessages.damage_type_word(String(action.damage_type)))
	lines.append(BattleNarrationLine.new(
		vision(_limb_and_weapon(tr(outcome).format({"type": type}), limb, weapon), me, victim, cast), damage if damage > 0 else -1))
	if damage <= 0:
		return
	var status: CombatStatusReportBoundaryResult = ordinary.status_report_result
	if status != null and status.outcome == CombatStatusReportBoundaryResult.Outcome.VALIDATED:
		var words: String = (
			Es2CombatMessages.effective_status_message(status.ratio)
			if status.value_source == CombatStatusReportBoundaryResult.ValueSource.EFFECTIVE_VITALITY
			else Es2CombatMessages.status_message(status.ratio)
		)
		# TRANSLATORS: combatd.c: how the one hit looks now ({status}, e.g. 受伤不轻，看起来状况并不太好。).
		lines.append(BattleNarrationLine.new(vision(tr("( $N{status} )").format({"status": tr(words)}), victim, &"", cast)))
	if relationship != null and relationship.has_winner_presentation_index:
		lines.append(BattleNarrationLine.new(vision(
			tr(Es2CombatMessages.WINNER[relationship.winner_presentation_index]), me, victim, cast)))


## A special file's lines with its attacks where it made them, each told as an
## ordinary do_attack() is.
func special(report: SpecialReport, cast: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	var said: Array[VisionLine] = report.lines()
	var attacks: Array[SpecialAttack] = report.attacks()
	var next: int = 0
	for index: int in range(said.size() + 1):
		while next < attacks.size() and attacks[next].line_index <= index:
			var attack: SpecialAttack = attacks[next]
			if attack.attacked():
				lines.append_array(attack_chain(attack.forward, attack.chain, cast, attack.told, attack.reverse_told))
			elif attack.guard_index >= 0:
				# fight() guarded instead (hasten.c): its guard_msg.
				lines.append(BattleNarrationLine.new(vision(tr(Es2CombatMessages.GUARD[attack.guard_index]), attack.attacker_id, attack.victim_id, cast)))
			next += 1
		if index < said.size():
			lines.append_array(seen([said[index]], cast))
	return lines


## message_vision() lines (VisionLine) as the player sees them: a line said or a
## special's, in its colour; report_status() worded by combatd.c status_msg().
static func seen(vision_lines: Array[VisionLine], cast: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	for line: VisionLine in vision_lines:
		if line.is_status():
			lines.append(BattleNarrationLine.new(vision(tr_status(line.status_ratio), line.actor_id, &"", cast)))
			continue
		var text: String = _t(line.template).strip_edges()
		if not line.slots.is_empty():
			var slots: Dictionary = {}
			for key: String in line.slots:
				slots[key] = _t(line.slots[key])
			text = text.format(slots)
		if not line.actor_name.is_empty():
			text = text.replace("$N", _t(line.actor_name))
		lines.append(BattleNarrationLine.new(vision(text, line.actor_id, line.target_id, cast), -1, line.color))
	return lines


## combatd.c report_status(): ( $N<status> ), the template _attack() tells a blow's with.
static func tr_status(ratio: int) -> String:
	return _t("( $N{status} )").format({"status": _t(Es2CombatMessages.status_message(ratio))})


func _pick(messages: Array[String]) -> String:
	return messages[_rng.randi_range(0, messages.size() - 1)]


static func _selected(selection: CombatActionSelectionResult) -> CombatActionDefinition:
	return null if selection == null or not selection.succeeded else selection.selected_action


## do_attack(): $w is the weapon's name, else the action's own "weapon" word,
## else it stays as written. No ported action has a "weapon" word (human.c,
## beast.c and liuh-ken.c set none), so an unarmed $w stays.
static func _weapon_name(armed: bool, weapon_id: StringName) -> String:
	if not armed:
		return ""
	var item: ItemContentDefinition = GameContent.catalog().item(weapon_id)
	return "" if item == null else item.display_name


## `limb` and `weapon` as authored; they go in translated.
static func _limb_and_weapon(text: String, limb: String, weapon: String) -> String:
	text = text.replace("$l", _t(limb))
	return text if weapon.is_empty() else text.replace("$w", _t(weapon))


## adm/simul_efun/message.c message_vision(msg, me, you) as the player sees it:
## as me, as you, or as someone else in the room. `message` is already in the shown
## language; the names, 你 and the pronouns go in translated.
static func vision(message: String, me: StringName, you: StringName, cast: BattlePresentationProjection) -> String:
	var viewer: StringName = cast.player_id
	var my_name: String = _t(cast.display_name(me))
	# TRANSLATORS: message_vision(): the player, for $N/$n/$P/$p in the ES2 combat lines.
	var player: String = _t("你")
	if viewer == me:
		message = message.replace("$P", player).replace("$N", player)
		if not you.is_empty():
			message = message.replace("$p", _t(Es2CombatMessages.pronoun(cast.gender(you)))).replace("$n", _t(cast.display_name(you)))
		return message
	if not you.is_empty() and viewer == you:
		return (message.replace("$P", _t(Es2CombatMessages.pronoun(cast.gender(me)))).replace("$p", player)
			.replace("$N", my_name).replace("$n", player))
	message = message.replace("$P", my_name).replace("$N", my_name)
	if not you.is_empty():
		var your_name: String = _t(cast.display_name(you))
		message = message.replace("$p", your_name).replace("$n", your_name)
	return message


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
