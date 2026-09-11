class_name SourceEntrySaveRepository
extends GameSaveRepository

## Public Shell boundary. The shared codec/restorer still support explicit
## technical regression fixtures, but public Continue/Recovery must not load them.
func _read_snapshot(path: String) -> GameSaveResult:
	var result: GameSaveResult = super._read_snapshot(path)
	if result.succeeded() and not _is_public_source(result.snapshot):
		return _unsupported_profile()
	return result


func _save_impl(snapshot: GameSaveSnapshot) -> GameSaveResult:
	if snapshot != null and not _is_public_source(snapshot):
		return _unsupported_profile()
	return super._save_impl(snapshot)


static func _is_public_source(snapshot: GameSaveSnapshot) -> bool:
	return snapshot.world_content_revision == WorldContentRevision.Value.SOURCE_ENTRY_V1


static func _unsupported_profile() -> GameSaveResult:
	return GameSaveResult.failure(
		GameSaveResult.Outcome.INVALID_SNAPSHOT,
		"world_content_revision",
		"Technical world profiles are unsupported by public Continue/Recovery.",
	)
