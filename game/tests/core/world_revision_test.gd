extends RefCounted

## A save is bound to the content facts Continue checks it against (OldPineWorldRestoreComposition):
## one record for every authored NPC spawn point, and each record's NPC as its definition makes it
## (its age, its race's body, the kinds of things it carries, its name on its corpse …). So such a
## fact that changes without a new WorldContentRevision turns every save of the day before into
## "存档无法读取" instead of "请开始新游戏" (全项目审查「世界修订号漏升」, DECISIONS「修订号指纹」).
## This suite binds the two: tests/fixtures/world_revisions.json keeps, row by row, each revision and
## the fingerprint of those facts it shipped with; the live catalog's must be the row of CURRENT_PUBLIC.
##
## What the fingerprint holds (content_lines()), each a fact Continue reads:
## - every spawn point: its spawn, NPC, map and zone, and whether one of it may be absent (starts
##   absent; an ordinary spawn's, indoors for the night: WorldMapNpcIdle.may_be_indoors());
## - every NPC definition: its name (a corpse's), race (body weight), age and gender (fixed or drawn), the
##   names it may draw, whether it follows every way, may leave home (a saved one on another map), its chant's stages,
##   whether it is summoned / conjured / raised, and the kinds and counts of what it carries;
## - every zone's map and combat location, every map's region; every floor item spawn point's item
##   and zone; every note maze's number of notes; every armour's type (a corpse's worn things);
## - every item fact NativeItemStateValidator checks a saved thing against: whether it stacks, a
##   food's own weight, portions and first value, a drink's own weight and portions and whether it is
##   a powder, a weapon's id, secondary hand and two hands (全项目审查第四批).
## Left out: an item definition taken away (any save holding one is refused; items are added far more
## often than taken away), the portals (only one who wandered to another map reads them), and the
## maps' drawing: their collision and zone bounds. A redrawn map can leave a saved spot where nobody
## may stand; an NPC, a corpse or a dropped thing is moved to the nearest spot, the player's save is
## refused with 「这份存档之后地图改过……」 (DECISIONS「修订号指纹」).
##
## The fingerprint changed: add a WorldContentRevision value, make it CURRENT_PUBLIC, and add its row
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
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.values().back(), "the newest WorldContentRevision is CURRENT_PUBLIC (%s)" % current)
	var fingerprint: String = content_fingerprint()
	var rows: Array = _rows()
	if OS.get_environment("UPDATE_WORLD_REVISIONS") == "1" and not rows.any(func(row: Variant) -> bool: return row is Dictionary and row.get("revision") == current):
		rows.append({"revision": current, "spawn_points": _point_count(), "fingerprint": fingerprint})
		# JSON reads every number as a float: the older rows are written back as they were.
		for row: Variant in rows:
			if row is Dictionary and row.get("spawn_points") is float:
				row["spawn_points"] = int(row["spawn_points"])
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
		"the content facts a save is checked against (%d spawn points …) are the ones %s shipped with: changed, they need a new WorldContentRevision and its row (UPDATE_WORLD_REVISIONS=1, see this suite)" % [_point_count(), current],
	)
	_test_what_it_holds()
	return {"assertions": _count, "failures": _failures.duplicate()}


## The content facts Continue checks a save against (this suite's header), in a fixed order:
## their SHA-256.
static func content_fingerprint() -> String:
	return "\n".join(content_lines()).sha256_text()


static func content_lines() -> PackedStringArray:
	var catalog: ContentCatalog = GameContent.catalog()
	var lines: PackedStringArray = PackedStringArray()
	for spawn: NpcSpawnDefinition in catalog.spawns():
		for point_id: StringName in spawn.spawn_point_ids():
			lines.append("spawn|%s|%s|%s|%s|%s|absent:%s|indoors:%s" % [point_id, spawn.spawn_id, spawn.npc_definition_id, spawn.map_id, spawn.zone_id, spawn.starts_absent, WorldMapNpcIdle.may_be_indoors(spawn, spawn.map_id)])
	for npc: NpcDefinition in catalog.npcs():
		lines.append(npc_line(npc, catalog))
	for map: MapDefinition in catalog.maps():
		lines.append("map|%s|%s" % [map.map_id, map.region_id])
		for landmark: WorldLandmarkDefinition in catalog.landmarks_for_map(map.map_id):
			if landmark.policy == &"note_maze":
				lines.append("maze|%s|%d" % [landmark.landmark_id, landmark.notes.size()])
	for zone: ZoneDefinition in catalog.zones():
		lines.append("zone|%s|%s|%s" % [zone.zone_id, zone.map_id, zone.combat_location_id])
	for spawn: ItemSpawnDefinition in catalog.item_spawns():
		for point_id: StringName in spawn.spawn_point_ids():
			lines.append("floor|%s|%s|%s" % [point_id, spawn.item_definition_id, spawn.zone_id])
	var projections: NativeItemDefinitionProjections = catalog.native_item_projections()
	for item: ItemContentDefinition in catalog.items():
		var id: StringName = item.item_definition_id
		var armor: ArmorDefinition = projections.armor_definition(id)
		if armor != null:
			lines.append("armor|%s|%s" % [id, armor.armor_type])
		# What NativeItemStateValidator checks a saved item against.
		if projections.stack_definition(id) != null:
			lines.append("stack|%s" % id)
		var food: FoodDefinition = projections.food_definition(id)
		if food != null:
			lines.append("food|%s|weight:%d|portions:%d|value:%d" % [id, food.own_weight, food.initial_portions, food.initial_value])
		var drink: LiquidDefinition = projections.liquid_definition(id)
		if drink != null:
			lines.append("drink|%s|weight:%d|portions:%d" % [id, drink.own_weight, drink.maximum_portions])
		if projections.is_powder(id):
			lines.append("powder|%s" % id)
		var weapon: WeaponDefinition = projections.weapon_definition(id)
		if weapon != null:
			lines.append("weapon|%s|%s|secondary:%s|two_handed:%s" % [id, weapon.weapon_id, weapon.can_wield_as_secondary, weapon.is_two_handed])
	lines.sort()
	return lines


## What Continue reads of one NPC definition.
static func npc_line(npc: NpcDefinition, catalog: ContentCatalog) -> String:
	var roll: NpcRandomInteger = npc.age_roll()
	var age: String = "drawn %d %d %d" % [roll._base, roll._sign, roll._bound] if roll != null else ("fixed %d" % npc.age if npc.has_authored_age else "none")
	var drawn: NpcRandomText = npc.gender_roll()
	var gender: String = "drawn %d %d %s %s" % [drawn._bound, drawn._below, drawn._then, drawn._else] if drawn != null else ("fixed %s" % npc.gender if npc.has_authored_gender else "none")
	var names: PackedStringArray = PackedStringArray(npc.name_pick())
	names.sort()
	var hooks: NpcHooks = npc.hooks()
	var talks: Array[NpcTalk] = [npc.talk()]
	if hooks != null:
		for mood: NpcMood in hooks.moods.values():
			if mood.talk != null:
				talks.append(mood.talk)
	var leaves: bool = catalog.called_over(npc.definition_id)
	for talk: NpcTalk in talks:
		leaves = leaves or (talk != null and (talk.chat_entries().has(NpcTalk.RANDOM_MOVE) or talk.combat_chat_entries().has(NpcTalk.RANDOM_MOVE)))
	# The kinds of what it carries and how many records each makes (either side of a choice).
	var carried: Dictionary[String, int] = {}
	for authored: NpcLoadoutEntry in npc.loadout_entries():
		for entry: NpcLoadoutEntry in authored.possible_entries():
			var content: ItemContentDefinition = catalog.item(entry.item_definition_id)
			var count: int = 1 if content != null and content.stack_definition() != null else entry.quantity
			carried[String(entry.item_definition_id)] = carried.get(String(entry.item_definition_id), 0) + count
	var kinds: PackedStringArray = PackedStringArray()
	for id: String in carried:
		kinds.append("%s*%d" % [id, carried[id]])
	kinds.sort()
	return "npc|%s|%s|%s|age:%s|gender:%s|names:%s|follows:%s|leaves:%s|chants:%d|made:%s%s%s|carries:%s" % [
		npc.definition_id, npc.display_name, npc.race_id, age, gender, ",".join(names),
		hooks != null and hooks.follows_every_way, leaves, 0 if hooks == null else hooks.chant_stages.size(),
		npc.summoning() != null, npc.conjuring() != null, npc.raising() != null, ",".join(kinds),
	]


## Each kind of fact is in the fingerprint, and a fact Continue
## does not read (an NPC's long description) is not in it.
func _test_what_it_holds() -> void:
	var lines: PackedStringArray = content_lines()
	for kind: String in ["spawn|", "npc|", "map|", "zone|", "floor|", "maze|", "armor|", "stack|", "food|", "drink|", "powder|", "weapon|"]:
		_check(Array(lines).any(func(line: String) -> bool: return line.begins_with(kind)), "the fingerprint holds %s lines" % kind.trim_suffix("|"))
	var waiter: NpcDefinition = GameContent.catalog().npc(&"snow.npc.waiter")
	var line: String = npc_line(waiter, GameContent.catalog())
	_check(line.contains("|店小二|human|") and line.contains("age:") and line.contains("carries:"), "an NPC's line: its name, race, age and what it carries: %s" % line)
	_check(not waiter.description.is_empty() and not line.contains(waiter.description.strip_edges()), "its description is not a fact Continue reads")


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
