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
	if staging_parent == null or not staging_parent.is_inside_tree():
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"staging_parent",
		)
	var prepared: OldPineWorldRestoreResult = (
		OldPineWorldRestoreComposition.prepare(snapshot)
	)
	if prepared.outcome != Result.Outcome.SUCCESS or prepared.preparation == null:
		return prepared
	var candidate: OldPineWorldSessionController = (
		SESSION_SCENE.instantiate() as OldPineWorldSessionController
	)
	if candidate == null or not candidate.configure_restore(prepared.preparation):
		if candidate != null:
			candidate.free()
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"candidate.configure_restore",
		)
	staging_parent.add_child(candidate)
	if (
		not candidate.is_restore_candidate_staged()
		or candidate.active_map_child_count() != 1
	):
		var failure: int = candidate.restore_failure_outcome()
		if candidate.get_parent() == staging_parent:
			staging_parent.remove_child(candidate)
		candidate.free()
		return Result.failure(
			failure,
			"candidate.initialize",
		)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		candidate,
		prepared.preparation,
	)
