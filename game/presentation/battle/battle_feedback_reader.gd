class_name BattleFeedbackReader
extends RefCounted

var _encounter_id: StringName = &""
var _last_order: int = 0
var _recent: Array[BattleFeedbackProjection] = []
var last_consumed_order: int:
	get: return _last_order


func recent() -> Array[BattleFeedbackProjection]:
	return _recent.duplicate()


func read_new(
	coordinator: CombatEncounterCoordinator, projection: BattlePresentationProjection,
) -> Array[BattleFeedbackProjection]:
	if projection.encounter_id != _encounter_id:
		_encounter_id = projection.encounter_id
		_last_order = 0
		_recent.clear()
	if not projection.active:
		return []
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	if scheduler == null:
		return []
	var next: Array[BattleFeedbackProjection] = []
	for event: CombatSchedulerEvent in scheduler.events_after(_last_order):
		next.append(BattleFeedbackProjection.new(event.progression_order, _ordinary(event, projection)))
	var tactical: CombatTacticalRuntime = scheduler.player_tactics()
	if tactical != null:
		for event: CombatTacticalEvent in tactical.events_after(_last_order):
			next.append(BattleFeedbackProjection.new(event.progression_order, _tactical(event, projection)))
	next.sort_custom(_earlier)
	for entry: BattleFeedbackProjection in next:
		_last_order = entry.progression_order
		_recent.append(entry)
		if _recent.size() > 3:
			_recent.pop_front()
	return next


static func _earlier(a: BattleFeedbackProjection, b: BattleFeedbackProjection) -> bool:
	return a.progression_order < b.progression_order


static func reason(code: int) -> String:
	if code not in CombatTacticalResult.Code.values():
		return "Unknown result"
	return String(CombatTacticalResult.Code.keys()[code]).capitalize()


static func _tactical(event: CombatTacticalEvent, projection: BattlePresentationProjection) -> String:
	var action: CombatQueuedAction = event.action
	var detail: String = reason(event.reason)
	if event.execution != null:
		detail = String(CombatTacticalExecutionResult.Outcome.keys()[event.execution.outcome]).capitalize()
	if event.kind == CombatTacticalEvent.Kind.REPLACED:
		detail = "replaced by %s" % event.replacement_request_id
	return "%s · %s · %s: %s" % [
		projection.display_name(action.request.actor_id), action.request.action_id,
		String(CombatTacticalEvent.Kind.keys()[event.kind]).capitalize(), detail,
	]


static func _ordinary(event: CombatSchedulerEvent, projection: BattlePresentationProjection) -> String:
	var actor: String = projection.display_name(event.actor_id)
	var target: String = projection.display_name(event.target_id)
	if event.kind == CombatSchedulerEvent.Kind.PARTICIPANT_SKIPPED:
		return "%s · %s" % [actor, String(CombatSchedulerEvent.SkipReason.keys()[event.skip_reason]).capitalize()]
	var result: CombatSliceOpportunityResult = event.resolution
	var text: String = "%s · %s" % [actor, String(CombatSliceOpportunityResult.Outcome.keys()[result.outcome]).capitalize()]
	if result.forward_result != null:
		text += _attack(result.forward_result.ordinary_attack_result, actor, target)
	if result.chain_result != null and result.chain_result.reverse_execution_reached:
		text += " · Riposte" + _attack(result.chain_result.reverse_ordinary_result, target, actor)
	return text


static func _attack(result: CombatOrdinaryAttackResult, actor: String, target: String) -> String:
	if result == null or not result.has_base_result:
		return ""
	var base: CombatAttackResult = result.base_result
	match base.outcome:
		CombatAttackResult.Outcome.DODGE: return " · %s dodges %s" % [target, actor]
		CombatAttackResult.Outcome.PARRY: return " · %s parries %s" % [target, actor]
		CombatAttackResult.Outcome.HIT:
			return " · %s hits %s (%d damage)" % [actor, target, base.resource_mutation.requested_damage]
	return ""
