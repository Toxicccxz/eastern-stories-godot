class_name OldPineWorldRestoreService
extends RefCounted

const SESSION_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const Result := preload(
	"res://runtime/persistence/oldpine_world_restore_result.gd"
)


## Constructs a hidden, process-disabled candidate under the caller-owned
## staging parent. This does not replace or mutate any currently playable
## Session; candidate commit/swap remains Phase 10B4.
static func build_candidate(
	snapshot: GameSaveSnapshot,
	staging_parent: Node,
) -> OldPineWorldRestoreResult:
	var begun: OldPineWorldRestoreResult = begin_candidate(snapshot, staging_parent, 0)
	return begun if begun.candidate == null else finish_candidate(begun)


## build_candidate's first half: the candidate is made and added under staging_parent, where
## its start runs — over frames with `slice_usec` (DECISIONS「加载画面」: wait for the
## candidate's start_done), inside this call without. A failure has no candidate.
static func begin_candidate(
	snapshot: GameSaveSnapshot,
	staging_parent: Node,
	slice_usec: int,
) -> OldPineWorldRestoreResult:
	if staging_parent == null or not staging_parent.is_inside_tree():
		if snapshot != null:
			snapshot.take_derived() # not prepared: what a check kept goes now
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"staging_parent",
		)
	var prepared: OldPineWorldRestoreResult = (
		OldPineWorldRestoreComposition.prepare(snapshot)
	)
	if prepared.outcome != Result.Outcome.SUCCESS or prepared.preparation == null:
		return prepared
	# Continue is ES2's login: setup() runs race/human.c again for the player.
	var player: WorldPlayerRuntimeState = prepared.preparation.player
	CharacterDerivedValues.refresh_human_player_maxima(player.state, player.facts.age)
	var candidate: WorldSessionController = (
		SESSION_SCENE.instantiate() as WorldSessionController
	)
	if candidate == null or not candidate.configure_restore(prepared.preparation):
		if candidate != null:
			candidate.free()
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"candidate.configure_restore",
		)
	candidate.start_slice_usec = slice_usec
	staging_parent.add_child(candidate)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		candidate,
		prepared.preparation,
	)


## build_candidate's second half, once the candidate's start is over: it stands staged with
## one active map, or it is freed and the failure says why.
static func finish_candidate(begun: OldPineWorldRestoreResult) -> OldPineWorldRestoreResult:
	var candidate: WorldSessionController = begun.candidate
	if (
		not candidate.start_finished()
		or not candidate.is_restore_candidate_staged()
		or candidate.active_map_child_count() != 1
	):
		var failure: int = candidate.restore_failure_outcome()
		if candidate.get_parent() != null:
			candidate.get_parent().remove_child(candidate)
		candidate.free()
		return Result.failure(
			failure,
			"candidate.initialize",
		)
	return begun
