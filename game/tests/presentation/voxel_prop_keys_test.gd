extends RefCounted

## Every key a voxel look or building carries is one the drawing reads (data/common/voxel_prop_keys.json):
## a key nobody reads is a value its author wrote that the picture never shows. The registry's kinds
## are the props files' kinds, and every list of kinds the view keeps names one of them.
const REGISTRY: String = "res://data/common/voxel_prop_keys.json"
const PROPS: String = "res://presentation/voxel/props"
const WORLD: String = "res://scenes/world"
var assertions: int = 0
var failures: Array[String] = []
var registry: Dictionary = {}
var kinds: Dictionary = {}


func run_all() -> Dictionary:
	registry = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	kinds = registry["kinds"]
	_check_kinds_drawn()
	_check_kind_lists()
	_check_configs()
	_check_furnishings()
	return {"assertions": assertions, "failures": failures}


## The kinds a props file's draw() matches, read from its source: the registry has those, no more.
func _check_kinds_drawn() -> void:
	var drawn: Dictionary = {}
	var label := RegEx.create_from_string("^\\t\\t((?:\"[a-z_0-9]+\",\\s*)*\"[a-z_0-9]+\"):")
	var word := RegEx.create_from_string("\"([a-z_0-9]+)\"")
	for file: String in DirAccess.get_files_at(PROPS):
		if not file.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(PROPS.path_join(file))
		var start: int = source.find("\nfunc draw(")
		# A map prop's draw takes its footprint (w, d); a carried item's look (voxel_item_*) does not.
		if start < 0 or not source.substr(start, source.find("\n", start + 1) - start).contains("w: float"):
			continue
		var end: int = source.find("\nfunc ", start + 1)
		for line: String in source.substr(start, end - start if end > 0 else -1).split("\n"):
			var found: RegExMatch = label.search(line)
			if found != null:
				for name: RegExMatch in word.search_all(found.get_string(1)):
					drawn[name.get_string(1)] = true
	var unregistered: Array = drawn.keys().filter(func(kind: String) -> bool: return not kinds.has(kind))
	var undrawn: Array = kinds.keys().filter(func(kind: String) -> bool: return not drawn.has(kind))
	_check(drawn.size() > 300 and unregistered.is_empty(), "every kind the props files draw is in the registry (%d drawn): %s" % [drawn.size(), unregistered])
	_check(undrawn.is_empty(), "every kind in the registry is drawn by a props file: %s" % [undrawn])


## Kinds the view, the room life and their ambience name are kinds the props files draw.
func _check_kind_lists() -> void:
	var lists: Dictionary = {
		"VoxelMapGeometry.OVERHEAD_KINDS": VoxelMapGeometry.OVERHEAD_KINDS,
		"VoxelMapGeometry.MOUNTED_KINDS": VoxelMapGeometry.MOUNTED_KINDS,
		"VoxelLife.HEAT": VoxelLife.HEAT,
		"VoxelLife.TABLES": VoxelLife.TABLES,
		"VoxelLife.LAMP_HEIGHT": VoxelLife.LAMP_HEIGHT.keys(),
		"VoxelLife.SELF_SMOKING": VoxelLife.SELF_SMOKING,
	}
	for group: String in VoxelLife.ANCHORS:
		lists["VoxelLife.ANCHORS.%s" % group] = VoxelLife.ANCHORS[group]
	for name: String in VoxelLife.HANGING_KINDS:
		lists["VoxelLife.HANGING_KINDS.%s" % name] = [VoxelLife.HANGING_KINDS[name]["kind"]]
	for list_name: String in lists:
		var strays: Array = (lists[list_name] as Array).filter(func(kind: String) -> bool: return not kinds.has(kind))
		_check(strays.is_empty(), "%s names only kinds the props files draw: %s" % [list_name, strays])


## Each region's voxel configs: props, door looks, floor-item looks and buildings.
func _check_configs() -> void:
	var common: Array = registry["common"]
	var building: Dictionary = registry["building"]
	var stray: Array[String] = []
	var doorless: Array[String] = []
	var configs: int = 0
	for region: String in DirAccess.get_directories_at("res://data"):
		var folder: String = "res://data/%s/voxel" % region
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file: String in DirAccess.get_files_at(folder):
			if not file.ends_with(".json") or file in ["flora.json", "light.json"]:
				continue
			var path: String = folder.path_join(file)
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			configs += 1
			for prop: Dictionary in config.get("props", []):
				stray.append_array(_stray_keys(prop, common, "%s props" % path))
			for door: String in config.get("door_looks", {}):
				stray.append_array(_stray_keys(config["door_looks"][door], common + registry["door"], "%s door %s" % [path, door]))
			for item: String in config.get("items", {}):
				stray.append_array(_stray_keys(config["items"][item], common, "%s item %s" % [path, item]))
			for entry: Dictionary in config.get("buildings", []):
				var where: String = "%s building %s" % [path, entry.get("rect", [])]
				for key: String in entry:
					if key != "note" and not key in building["keys"]:
						stray.append("%s: %s" % [where, key])
				for mass: Dictionary in entry.get("masses", []):
					for key: String in mass:
						if key != "note" and not key in building["keys"] and not key in building["mass"]:
							stray.append("%s mass: %s" % [where, key])
				# A door's board, flag, gate leaves and lanterns stand only at a door the building draws.
				if (entry.get("portals", []) as Array).is_empty() and (entry.get("arches", []) as Array).is_empty() and (entry.get("doors", []) as Array).is_empty():
					for key: String in building["door_only"]:
						if entry.has(key):
							doorless.append("%s: %s" % [where, key])
	_check(configs > 150, "the voxel configs are read (%d)" % configs)
	_check(stray.is_empty(), "every key in a voxel config is one its kind (or a building) reads: %s" % [stray])
	_check(doorless.is_empty(), "no building without a door carries a door's board, flag, gate or lanterns: %s" % [doorless])


## The layouts' furniture looks, as painted into each scene's Furnishings (with the room life's pieces).
func _check_furnishings() -> void:
	var common: Array = registry["common"]
	var stray: Array[String] = []
	var looks: int = 0
	for region: String in DirAccess.get_directories_at(WORLD):
		for file: String in DirAccess.get_files_at(WORLD.path_join(region)):
			if not file.ends_with(".tscn"):
				continue
			var path: String = WORLD.path_join(region).path_join(file)
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				if line.begins_with("metadata/look = "):
					var look: Variant = JSON.parse_string(line.trim_prefix("metadata/look = "))
					looks += 1
					stray.append_array(_stray_keys(look as Dictionary, common, "%s (tools/maps/layouts/%s.json)" % [path, region]))
	_check(looks > 1000, "the layouts' furniture looks are read (%d)" % looks)
	_check(stray.is_empty(), "every key in a layout look is one its kind reads: %s" % [stray])


func _stray_keys(look: Dictionary, common: Array, where: String) -> Array[String]:
	var kind: String = String(look.get("kind", ""))
	if not kinds.has(kind):
		return ["%s: unknown kind \"%s\"" % [where, kind]]
	var own: Array = kinds[kind]["keys"]
	var out: Array[String] = []
	for key: String in look:
		if not key in common and not key in own:
			out.append("%s: %s.%s" % [where, kind, key])
	return out


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
