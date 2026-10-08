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
## The current encounter's opening lines, which the log already holds.
var _opening: Array[BattleNarrationLine] = []
var last_consumed_order: int:
	get: return _last_order


## The dodge and parry wording is picked with `rng` (seed it in tests).
func _init(rng: RandomNumberGenerator = null) -> void:
	_narrator = BattleNarrator.new(rng)


## The last few lines of the current or last encounter, newest last.
func recent() -> Array[BattleNarrationLine]:
	return _recent.duplicate()


## recent() without the opening lines: the fight's result adds these to the log,
## which got the opening when the fight began.
func recent_events() -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	for line: BattleNarrationLine in _recent:
		if not _opening.has(line):
			lines.append(line)
	return lines


## Lines told outside the encounter's events (enforce.c's): they join the recent
## lines, which are returned.
func note(lines: Array[BattleNarrationLine]) -> Array[BattleNarrationLine]:
	_recent.append_array(lines)
	if _recent.size() > RECENT_LINES:
		_recent = _recent.slice(_recent.size() - RECENT_LINES)
	return _recent.duplicate()


## Only successful authoritative completion may become a world result message.
## No rewards, lifecycle, thaw, or completion decision belongs to this projection.
## `departed`: the player left the fight by a spell that took them away (dun.c).
static func completion_text(receipt: CombatEncounterCompletionResult, player_life: int, departed: bool = false) -> String:
	if receipt == null or not receipt.succeeded() or receipt.terminal_result == null:
		return ""
	if departed and receipt.terminal_result.kind == CombatEncounterResultKind.Value.FLED:
		return TranslationServer.translate("你借遁术脱离了战斗。")
	match receipt.terminal_result.kind:
		CombatEncounterResultKind.Value.VICTORY:
			# Nobody fights anyone any more, but someone of the other side still stands
			# (a sparring partner who withstood 天邪虎啸, or who outlasted the 天将).
			if receipt.terminal_result.losing_side_ids().is_empty():
				return TranslationServer.translate("双方都停了手，战斗结束。")
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
	var read: Array[BattleFeedbackProjection] = []
	if projection.encounter_id != _encounter_id:
		_encounter_id = projection.encounter_id
		_last_order = 0
		_recent.clear()
		_opening = opening_lines(coordinator, projection.encounter_id)
		if not _opening.is_empty():
			read.append(BattleFeedbackProjection.new(0, _opening))
			note(_opening)
	read.append_array(_read_new_events(coordinator, projection))
	return read


## What was said as the fight began, then kill_ob()'s warnings in HIR red
## (CombatEncounterCoordinator.note_opening()).
static func opening_lines(coordinator: CombatEncounterCoordinator, encounter_id: StringName) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	for text: String in coordinator.opening_lines(encounter_id):
		lines.append(BattleNarrationLine.new(text))
	for text: String in coordinator.opening_warnings(encounter_id):
		lines.append(BattleNarrationLine.new(text, -1, ColoredLine.HIR))
	return lines


func _read_new_events(
	coordinator: CombatEncounterCoordinator, projection: BattlePresentationProjection,
) -> Array[BattleFeedbackProjection]:
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	if scheduler == null:
		var completed: CombatCompletedFeedback = coordinator.completed_feedback()
		if completed == null or completed.encounter_id != projection.encounter_id:
			return []
		return _read_events(completed.targets_after(_last_order), completed.ordinary_after(_last_order), completed.tactical_after(_last_order), projection, completed.announcements_after(_last_order))
	if coordinator.active_encounter().encounter_id != projection.encounter_id:
		return []
	var tactical: CombatTacticalRuntime = scheduler.player_tactics()
	var tactics: Array[CombatTacticalEvent] = []
	if tactical != null: # NPC-only encounters have no player tactics.
		tactics = tactical.events_after(_last_order)
	return _read_events(scheduler.target_events_after(_last_order), scheduler.events_after(_last_order), tactics, projection, scheduler.announcements_after(_last_order))


## Every event read moves the cursor; only those that print something become entries.
func _read_events(targets: Array[CombatOrderedTargetEvent], ordinary: Array[CombatSchedulerEvent], tactics: Array[CombatTacticalEvent], projection: BattlePresentationProjection, announcements: Array[CombatLifecycleAnnouncement] = []) -> Array[BattleFeedbackProjection]:
	var read: Array[BattleFeedbackProjection] = []
	for announcement: CombatLifecycleAnnouncement in announcements:
		read.append(BattleFeedbackProjection.new(announcement.progression_order, _announce(announcement, projection)))
	for ordered: CombatOrderedTargetEvent in targets:
		read.append(BattleFeedbackProjection.new(ordered.progression_order, _target(ordered.event, projection)))
	for event: CombatSchedulerEvent in ordinary:
		read.append(BattleFeedbackProjection.new(event.progression_order, _narrator.opportunity(event, projection)))
	for event: CombatTacticalEvent in tactics:
		read.append(BattleFeedbackProjection.new(event.progression_order, _tactical(event, projection)))
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


## combatd.c announce() as the player reads it (message_vision()): someone else's fall
## or death. The player's own is not told here: unconcious() blocks their messages and
## the life screen says it.
static func _announce(announcement: CombatLifecycleAnnouncement, projection: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	if announcement.victim_id == projection.player_id:
		return lines
	var name: String = TranslationServer.translate(projection.display_name(announcement.victim_id))
	if announcement.event == CombatLifecycleAnnouncement.UNCONSCIOUS:
		# TRANSLATORS: combatd.c announce("unconcious"): {name} falls unconscious in the fight.
		lines.append(BattleNarrationLine.new(TranslationServer.translate("{name}脚下一个不稳，跌在地上一动也不动了。").format({"name": name})))
	elif announcement.event == CombatLifecycleAnnouncement.DEAD:
		# TRANSLATORS: combatd.c announce("dead"): {name} dies in the fight.
		lines.append(BattleNarrationLine.new(TranslationServer.translate("{name}死了。").format({"name": name})))
	return lines


static func _earlier(a: BattleFeedbackProjection, b: BattleFeedbackProjection) -> bool:
	return a.progression_order < b.progression_order


static func reason(code: int) -> String:
	return TranslationServer.translate(TACTICAL_REASONS.get(code, "未知结果"))


static func target_reason(code: int) -> String:
	return TranslationServer.translate(TARGET_REASONS.get(code, "未知结果"))


## Only the player's own target changes are told; ES2 prints none. The first target is
## not (owner, modern fixes II): the opening lines already say who the player fights.
static func _target(event: CombatEncounterEvent, projection: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	if event.actor_id == projection.player_id and not event.current_target_id.is_empty() and not event.previous_target_id.is_empty():
		lines.append(BattleNarrationLine.new(
			TranslationServer.translate("你把目标转向%s。") % TranslationServer.translate(projection.display_name(event.current_target_id))
		))
	return lines


## The player's queued actions (Flee, exert, perform): queued, given up, refused
## and their end; an action that printed lines (exert.c's) ends with them, a perform
## with its file's lines and attacks.
func _tactical(event: CombatTacticalEvent, projection: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	if event.kind == CombatTacticalEvent.Kind.RESOLVED and event.execution != null and event.execution.special != null and not event.execution.special.is_empty():
		return _narrator.special(event.execution.special, projection)
	if event.kind == CombatTacticalEvent.Kind.RESOLVED and event.execution != null and not event.execution.lines().is_empty():
		for line: ColoredLine in event.execution.lines():
			lines.append(BattleNarrationLine.new(line.text, -1, line.color))
		return lines
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
	if not text.is_empty():
		lines.append(BattleNarrationLine.new(text))
	return lines
