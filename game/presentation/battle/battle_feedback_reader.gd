class_name BattleFeedbackReader
extends RefCounted

const RECENT_LINES: int = 3

## Chinese reasons for a refused or failed request, by CombatTacticalResult.Code.
const TACTICAL_REASONS: Dictionary[int, String] = {
	CombatTacticalResult.Code.ACCEPTED: "已接受",
	CombatTacticalResult.Code.CANCELLED: "已取消",
	CombatTacticalResult.Code.INVALID_REQUEST: "请求无效",
	CombatTacticalResult.Code.INACTIVE: "战斗已经结束",
	CombatTacticalResult.Code.APPLICATION_BLOCKED: "游戏暂停中",
	CombatTacticalResult.Code.WORLD_GATE_MISMATCH: "世界状态不符",
	CombatTacticalResult.Code.NOT_PLAYER: "只能由你下令",
	CombatTacticalResult.Code.AUTHORITY_INVALID: "战斗状态无效",
	CombatTacticalResult.Code.ACTOR_UNAVAILABLE: "你现在无法行动",
	CombatTacticalResult.Code.UNKNOWN_ACTION: "没有这个操作",
	CombatTacticalResult.Code.CATEGORY_MISMATCH: "操作类型不符",
	CombatTacticalResult.Code.TARGET_INVALID: "目标无效",
	CombatTacticalResult.Code.PREREQUISITE_FAILED: "条件不足",
	CombatTacticalResult.Code.DUPLICATE_REQUEST: "重复的请求",
	CombatTacticalResult.Code.STALE_CANCEL: "要取消的操作已经变了",
	CombatTacticalResult.Code.SEQUENCE_EXHAUSTED: "操作次数已用尽",
	CombatTacticalResult.Code.POLICY_UNSUPPORTED: "这个操作还不能用",
}

## Chinese receipts for a target change, by CombatTargetResult.Code.
const TARGET_REASONS: Dictionary[int, String] = {
	CombatTargetResult.Code.NO_ACTIVE_ENCOUNTER: "没有进行中的战斗",
	CombatTargetResult.Code.INVALID_REQUEST: "请求无效",
	CombatTargetResult.Code.STALE_ENCOUNTER: "战斗已经变了",
	CombatTargetResult.Code.APPLICATION_BLOCKED: "游戏暂停中",
	CombatTargetResult.Code.WORLD_GATE_MISMATCH: "世界状态不符",
	CombatTargetResult.Code.INVALID_ACTOR: "你现在无法行动",
	CombatTargetResult.Code.BINDING_MISMATCH: "战斗状态不符",
	CombatTargetResult.Code.TARGET_UNAVAILABLE: "无法选为目标",
	CombatTargetResult.Code.UNCHANGED: "目标未变",
	CombatTargetResult.Code.CHANGED: "已更换目标",
}

var catalog: BattleActionPresentationCatalog = BattleActionPresentationCatalog.new()
var _narrator: BattleNarrator
var _encounter_id: StringName = &""
var _last_order: int = 0
var _recent: Array[BattleNarrationLine] = []
var last_consumed_order: int:
	get: return _last_order


## The dodge and parry wording is picked with `rng` (seed it in tests).
func _init(rng: RandomNumberGenerator = null) -> void:
	_narrator = BattleNarrator.new(rng)


## The last few lines of the current or last encounter, newest last.
func recent() -> Array[BattleNarrationLine]:
	return _recent.duplicate()


## Only successful authoritative completion may become a world result message.
## No rewards, lifecycle, thaw, or completion decision belongs to this projection.
static func completion_text(receipt: CombatEncounterCompletionResult, player_life: int) -> String:
	if receipt == null or not receipt.succeeded() or receipt.terminal_result == null:
		return ""
	match receipt.terminal_result.kind:
		CombatEncounterResultKind.Value.VICTORY:
			return TranslationServer.translate("你赢了这场战斗。选择倒下对手的尸体可以查看或搜刮。")
		CombatEncounterResultKind.Value.DEFEAT:
			if player_life == CharacterRuntimeLifeStatus.Value.DEAD:
				return TranslationServer.translate("你输了这场战斗，你死了。")
			return TranslationServer.translate("你输了这场战斗，昏了过去。")
		CombatEncounterResultKind.Value.SPAR_CONCLUDED:
			return TranslationServer.translate("切磋结束。")
		CombatEncounterResultKind.Value.FLED:
			return TranslationServer.translate("你逃离了战斗。走远一些才能摆脱危险。")
		CombatEncounterResultKind.Value.ABORTED:
			return TranslationServer.translate("战斗出错，已中止。")
	return TranslationServer.translate("战斗结束。")


func read_new(
	coordinator: CombatEncounterCoordinator, projection: BattlePresentationProjection,
) -> Array[BattleFeedbackProjection]:
	if not projection.active:
		return [] # Keep the completed history until a new encounter replaces it.
	if projection.encounter_id != _encounter_id:
		_encounter_id = projection.encounter_id
		_last_order = 0
		_recent.clear()
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	if scheduler == null:
		var completed: CombatCompletedFeedback = coordinator.completed_feedback()
		if completed == null or completed.encounter_id != projection.encounter_id:
			return []
		return _read_events(completed.targets_after(_last_order), completed.ordinary_after(_last_order), completed.tactical_after(_last_order), projection)
	if coordinator.active_encounter().encounter_id != projection.encounter_id:
		return []
	var tactical: CombatTacticalRuntime = scheduler.player_tactics()
	var tactics: Array[CombatTacticalEvent] = []
	if tactical != null: # NPC-only encounters have no player tactics.
		tactics = tactical.events_after(_last_order)
	return _read_events(scheduler.target_events_after(_last_order), scheduler.events_after(_last_order), tactics, projection)


## Every event read moves the cursor; only those that print something become entries.
func _read_events(targets: Array[CombatOrderedTargetEvent], ordinary: Array[CombatSchedulerEvent], tactics: Array[CombatTacticalEvent], projection: BattlePresentationProjection) -> Array[BattleFeedbackProjection]:
	var read: Array[BattleFeedbackProjection] = []
	for ordered: CombatOrderedTargetEvent in targets:
		read.append(BattleFeedbackProjection.new(ordered.progression_order, _target(ordered.event, projection)))
	for event: CombatSchedulerEvent in ordinary:
		read.append(BattleFeedbackProjection.new(event.progression_order, _narrator.opportunity(event, projection)))
	for event: CombatTacticalEvent in tactics:
		read.append(BattleFeedbackProjection.new(event.progression_order, _tactical(event)))
	read.sort_custom(_earlier)
	var next: Array[BattleFeedbackProjection] = []
	for entry: BattleFeedbackProjection in read:
		_last_order = maxi(_last_order, entry.progression_order)
		if entry.lines().is_empty():
			continue
		next.append(entry)
		_recent.append_array(entry.lines())
	if _recent.size() > RECENT_LINES:
		_recent = _recent.slice(_recent.size() - RECENT_LINES)
	return next


static func _earlier(a: BattleFeedbackProjection, b: BattleFeedbackProjection) -> bool:
	return a.progression_order < b.progression_order


static func reason(code: int) -> String:
	return TranslationServer.translate(TACTICAL_REASONS.get(code, "未知结果"))


static func target_reason(code: int) -> String:
	return TranslationServer.translate(TARGET_REASONS.get(code, "未知结果"))


## Only the player's own target changes are told; ES2 prints none.
static func _target(event: CombatEncounterEvent, projection: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	if event.actor_id == projection.player_id and not event.current_target_id.is_empty():
		var template: String = "你的目标是%s。" if event.previous_target_id.is_empty() else "你把目标转向%s。"
		lines.append(BattleNarrationLine.new(
			TranslationServer.translate(template) % TranslationServer.translate(projection.display_name(event.current_target_id))
		))
	return lines


## The player's queued actions (Flee): queued, given up, refused and their end.
func _tactical(event: CombatTacticalEvent) -> Array[BattleNarrationLine]:
	var label: String = catalog.label_for(event.action.request.action_id)
	var text: String = ""
	match event.kind:
		CombatTacticalEvent.Kind.QUEUED:
			text = tr("你准备%s。") % label
		CombatTacticalEvent.Kind.CANCELLED:
			# Only the player's own cancel; a refusal or the fight's end said why already.
			if event.reason == CombatTacticalResult.Code.CANCELLED:
				text = tr("你放弃了%s。") % label
		CombatTacticalEvent.Kind.REJECTED, CombatTacticalEvent.Kind.EXECUTION_REJECTED:
			text = tr("你无法%s：%s。") % [label, reason(event.reason)]
		CombatTacticalEvent.Kind.RESOLVED:
			match (-1 if event.execution == null else event.execution.outcome):
				CombatTacticalExecutionResult.Outcome.DISENGAGED:
					text = tr("你脱离了战斗。")
				CombatTacticalExecutionResult.Outcome.APPLIED:
					text = tr("%s生效了。") % label
				CombatTacticalExecutionResult.Outcome.FAILED:
					text = tr("%s失败了。") % label
				_:
					text = tr("%s无法执行。") % label
	var lines: Array[BattleNarrationLine] = []
	if not text.is_empty():
		lines.append(BattleNarrationLine.new(text))
	return lines
