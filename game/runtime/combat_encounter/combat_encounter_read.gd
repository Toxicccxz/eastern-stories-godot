class_name CombatEncounterRead
extends RefCounted

## One read of the running fight (CombatEncounterCoordinator.read()), for the battle panel's
## projection, which asks every frame: the fighters' bindings and the player's moves are
## derived once for all of its questions, where the coordinator's own queries derive them
## again for each (a duel's projection cost 11 ms a frame that way). It changes nothing, and
## it is good only for the frame it was made in.
var _scheduler: CombatEncounterScheduler
var _bindings: Array[CombatSliceCharacterBinding] = []
var _moves: Array[CombatActionDefinition] = []
var _moves_read: bool = false


func _init(scheduler: CombatEncounterScheduler = null, p_bindings: Array[CombatSliceCharacterBinding] = []) -> void:
	_scheduler = scheduler
	_bindings = p_bindings


func bindings() -> Array[CombatSliceCharacterBinding]:
	return _bindings


## The moves the player may choose from now, locked ones included.
func player_moves() -> Array[CombatActionDefinition]:
	if not _moves_read:
		_moves_read = true
		if _scheduler != null:
			_moves = _scheduler.player_moves(_bindings)
	return _moves


## The player's locked moves, by ID, with why (够不着).
func locked_moves() -> Dictionary[StringName, String]:
	if _scheduler == null:
		return {}
	return _scheduler.locked_among(player_moves(), _bindings)


## The player's moves costing more beats than they have left, by ID, with why (手不够).
func unaffordable_moves() -> Dictionary[StringName, String]:
	if _scheduler == null:
		return {}
	return _scheduler.unaffordable_among(player_moves(), _bindings)


## The cost in beats of one of the player's moves (its tag's), 1 without a fight.
func move_cost(move: CombatActionDefinition) -> int:
	return 1 if _scheduler == null or move == null else _scheduler.beat_rules().cost_of_tag(move.tag)


## The beats `actor_id` holds now (CombatEncounterCoordinator.beats_now()).
func beats_now(actor_id: StringName) -> CombatRoundBeats:
	return null if _scheduler == null else _scheduler.beats_now(actor_id, _bindings)


## The move an NPC will use on its next beat, null when none is drawn (or it is a perform).
func next_move(actor_id: StringName) -> CombatActionDefinition:
	return null if _scheduler == null else _scheduler.next_move(actor_id, _bindings)


## The skeleton of the school `actor_id` fights with (its 打法词, how it wins a beat, the
## skill behind it); null when it has none or the round is ES2's one beat.
func skeleton(actor_id: StringName) -> CombatSchoolSkeleton:
	return null if _scheduler == null else _scheduler.school_skeleton(actor_id, _bindings)
