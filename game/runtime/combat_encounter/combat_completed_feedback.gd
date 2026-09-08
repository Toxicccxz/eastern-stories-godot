class_name CombatCompletedFeedback
extends RefCounted

## Last successful encounter's event values only: no live scheduler or bindings.
## Transient, replaced at next start, never saved or used for gameplay decisions.
var _encounter_id: StringName
var _ordinary: Array[CombatSchedulerEvent]
var _targets: Array[CombatOrderedTargetEvent]
var _tactical: Array[CombatTacticalEvent]
var encounter_id: StringName:
	get: return _encounter_id

func _init(id: StringName, scheduler: CombatEncounterScheduler) -> void:
	_encounter_id = id
	_ordinary = scheduler.events()
	_targets = scheduler.target_events_after(0)
	_tactical = [] if scheduler.player_tactics() == null else scheduler.player_tactics().events_after(0)

func ordinary_after(order: int) -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for event: CombatSchedulerEvent in _ordinary:
		if event.progression_order > order:
			result.append(event.duplicate_snapshot())
	return result

func targets_after(order: int) -> Array[CombatOrderedTargetEvent]:
	var result: Array[CombatOrderedTargetEvent] = []
	for event: CombatOrderedTargetEvent in _targets:
		if event.progression_order > order:
			result.append(CombatOrderedTargetEvent.new(event.event, event.progression_order))
	return result

func tactical_after(order: int) -> Array[CombatTacticalEvent]:
	var result: Array[CombatTacticalEvent] = []
	for event: CombatTacticalEvent in _tactical:
		if event.progression_order > order:
			result.append(event.duplicate_snapshot())
	return result
