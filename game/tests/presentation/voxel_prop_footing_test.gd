extends RefCounted

## Decor tall enough to walk into (a kind's `tall` in data/common/voxel_prop_keys.json) stands, in a
## voxel config, on ground that blocks on the 2D map (a wall, rock, water, the town's boundary, a
## layout's blocked box) or is raised clear of the floor (`elevation`) or hung on a wall: nobody
## walks through a lamp post or a banner pole. Every painted map, 逆灵宫 and 雪亭镇 with the rest.
## A gateway's posts stand at the ends of its width; the way runs on under its beam.
const REGISTRY: String = "res://data/common/voxel_prop_keys.json"
const WORLD: String = "res://scenes/world"
## Raised this far (units) a prop is clear of whoever walks beneath.
const CLEAR: float = 0.9
var assertions: int = 0
var failures: Array[String] = []


func run_all() -> Dictionary:
	var kinds: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(REGISTRY)) as Dictionary)["kinds"]
	var tall: Dictionary = {}
	for kind: String in kinds:
		if kinds[kind].get("tall", false):
			tall[kind] = kinds[kind]
	_check(tall.size() > 100 and tall.has("lantern_post") and tall.has("banner") and tall.has("lantern"), "the tall kinds are read (%d)" % tall.size())
	var found := RegEx.create_from_string("layout_path = \"([^\"]+)\"")
	var maps: int = 0
	var regions: Dictionary = {}
	for region: String in DirAccess.get_directories_at(WORLD):
		for file: String in DirAccess.get_files_at(WORLD.path_join(region)):
			if not file.ends_with(".tscn"):
				continue
			var path: String = WORLD.path_join(region).path_join(file)
			var named: RegExMatch = found.search(FileAccess.get_file_as_string(path))
			if named == null:
				continue
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(named.get_string(1)))
			var map := (load(path) as PackedScene).instantiate() as Node2D
			var loose: Array[String] = _loose(map, config, tall)
			map.free()
			maps += 1
			regions[region] = true
			_check(loose.is_empty(), "tall decor in %s (%s) stands on blocking ground: %s" % [file, named.get_string(1), loose])
	_check(maps > 150 and regions.has("niling") and regions.has("snow"), "every painted map is walked (%d maps, %d regions)" % [maps, regions.size()])
	return {"assertions": assertions, "failures": failures}


func _loose(map: Node2D, config: Dictionary, tall: Dictionary) -> Array[String]:
	var loose: Array[String] = []
	for prop: Dictionary in config.get("props", []):
		var kind: String = String(prop["kind"])
		if not prop.has("at"):
			continue
		var at := Vector2(float(prop["at"][0]), float(prop["at"][1]))
		if kind == "gateway":
			# Its posts at the ends of its width, along its own x as turned (the view turns it about
			# the up axis: its x runs to the map's (cos, -sin)).
			var half: Vector2 = Vector2(float(prop["size"][0]) / 2.0 - 6.4, 0).rotated(-deg_to_rad(float(prop.get("rotation", 0))))
			for post: Vector2 in [at - half, at + half]:
				if not TerrainProbe.blocks_at(map, post):
					loose.append("gateway post %s" % post)
			continue
		if not tall.has(kind) or float(prop.get("elevation", 0.0)) >= CLEAR or prop.get("wall_mounted", false):
			continue
		# Its box: its own `size`, or without one the spot it stands on.
		var size: Array = prop.get("size", [16, 16])
		var box := Vector2(float(size[0]), float(size[1]))
		if absi(roundi(float(prop.get("rotation", 0)))) % 180 == 90:
			box = Vector2(box.y, box.x)
		var area := Rect2(at - box / 2.0, box)
		for y: int in range(floori(area.position.y / 16.0), ceili(area.end.y / 16.0)):
			var open: bool = false
			for x: int in range(floori(area.position.x / 16.0), ceili(area.end.x / 16.0)):
				var cell := Vector2(x * 16 + 8, y * 16 + 8)
				if not TerrainProbe.blocks_at(map, cell):
					loose.append("%s %s (open at %s)" % [kind, prop["at"], cell])
					open = true
					break
			if open:
				break
	return loose


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
