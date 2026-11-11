extends RefCounted

## A save is bound to the world's spawn points: Continue wants one record for every authored NPC
## spawn point and refuses a save that lacks one or has one too many (OldPineWorldRestoreComposition).
## So spawn points that change without a new WorldContentRevision turn every save of the day before
## into "存档无法读取" instead of "请开始新游戏" (全项目审查「世界修订号漏升」). This suite binds the two:
## tests/fixtures/world_revisions.json keeps, row by row, each revision and the fingerprint of the
## spawn points it shipped with; the live catalog's fingerprint must be the row of CURRENT_PUBLIC.
##
## Spawn points changed: add a WorldContentRevision value, make it CURRENT_PUBLIC, and add its row
## (never edit an older one):
##
##     UPDATE_WORLD_REVISIONS=1 <godot> --headless --path game --script res://tests/run_suite.gd -- res://tests/core/world_revision_test.gd
##
## The update only appends a row for a revision that has none; a revision's row is never rewritten.

const FIXTURE: String = "res://tests/fixtures/world_revisions.json"

var _count: int = 0
var _failures: Array[String] = []


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	var current: String = WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC)
	var fingerprint: String = spawn_fingerprint()
	var rows: Array = _rows()
	if OS.get_environment("UPDATE_WORLD_REVISIONS") == "1" and not rows.any(func(row: Variant) -> bool: return row is Dictionary and row.get("revision") == current):
		rows.append({"revision": current, "spawn_points": _point_count(), "fingerprint": fingerprint})
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify({"revisions": rows}, "\t", false) + "\n")
		file.close()
	_check(not rows.is_empty(), "the fixture reads and holds the revisions")
	# A revision may ship the spawn points of the one before (a package that changed other
	# content): rows may share a fingerprint, never a revision.
	var revisions: Dictionary[String, bool] = {}
	var order: int = -1
	for row: Variant in rows:
		if not _check(row is Dictionary and row.get("revision") is String and row.get("fingerprint") is String, "a row is {revision, spawn_points, fingerprint}: %s" % [row]):
			continue
		var revision: String = row["revision"]
		_check(WorldContentRevision.parsed(revision) > order, "%s is a WorldContentRevision later than the row before" % revision)
		_check(not revisions.has(revision), "%s has one row" % revision)
		order = maxi(order, WorldContentRevision.parsed(revision))
		revisions[revision] = true
	var last: Variant = rows.back() if not rows.is_empty() else null
	_check(last is Dictionary and last.get("revision") == current, "the last row is CURRENT_PUBLIC (%s)" % current)
	_check(
		last is Dictionary and last.get("fingerprint") == fingerprint,
		"the spawn points (%d) are the ones %s shipped with: changed, they need a new WorldContentRevision and its row (UPDATE_WORLD_REVISIONS=1, see this suite)" % [_point_count(), current],
	)
	return {"assertions": _count, "failures": _failures.duplicate()}


## The NPC spawn points a save holds one record each for, with the spawn, NPC and map each
## belongs to (Continue checks all four), in a fixed order: their SHA-256.
static func spawn_fingerprint() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		for point_id: StringName in spawn.spawn_point_ids():
			lines.append("%s|%s|%s|%s" % [point_id, spawn.spawn_id, spawn.npc_definition_id, spawn.map_id])
	lines.sort()
	return "\n".join(lines).sha256_text()


static func _point_count() -> int:
	var count: int = 0
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		count += spawn.spawn_point_ids().size()
	return count


func _rows() -> Array:
	if not FileAccess.file_exists(FIXTURE):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	return (parsed as Dictionary).get("revisions", []) if parsed is Dictionary else []


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append(label)
	return ok
