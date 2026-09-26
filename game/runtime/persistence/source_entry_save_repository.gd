class_name SourceEntrySaveRepository
extends GameSaveRepository

## Public support is checked in the codec before entity decoding/composition.
## Technical regression fixtures retain the base repository explicitly.
func _requires_current_public_contract() -> bool:
	return true


func _read_snapshot(path: String) -> GameSaveResult:
	var result: GameSaveResult = super._read_snapshot(path)
	if not result.succeeded():
		return result
	return _validated_current(result.snapshot)


func _save_impl(snapshot: GameSaveSnapshot) -> GameSaveResult:
	var validated: GameSaveResult = _validated_current(snapshot)
	if not validated.succeeded():
		return validated
	return super._save_impl(snapshot)


static func _validated_current(snapshot: GameSaveSnapshot) -> GameSaveResult:
	if snapshot == null:
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_SNAPSHOT, "root")
	var support: GameSaveResult = WorldContentRevision.public_support(snapshot.world_content_revision)
	if not support.succeeded():
		return support
	# Same production catalog/ledger authority as capture and staged restore.
	# Pure preparation: no Nodes, files, fresh NPC factory or gameplay RNG.
	var prepared: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	if prepared.preparation == null:
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_SNAPSHOT, prepared.path, prepared.detail)
	return GameSaveResult.success(snapshot)
