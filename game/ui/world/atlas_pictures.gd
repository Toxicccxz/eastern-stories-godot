class_name AtlasPictures
extends RefCounted

## What tools/maps/atlas left for the 地图 page (DECISIONS「总图」): each place's miniature and
## where its rooms and doors lie in the picture. The 沙盘 is drawn in the voxel view's own
## projection (north up and to the right), so a place's world position gives its picture's.

const DIRECTORY: String = "res://assets/textures/atlas/"
const BAKE: String = DIRECTORY + "bake.json"
const COS_X: float = 0.7071
const COS_Y: float = 0.4631

## A road between two places on the 沙盘: its layer, the two layers of the stub it shows from
## one end, and the line it runs along, `a` to `b`, on the 沙盘.
class Road:
	extends RefCounted
	var a: StringName
	var b: StringName
	var file: String
	var at: Vector2
	## The stubs' corners; Vector2.INF when the land hides that end.
	var stub_a: Vector2 = Vector2.INF
	var stub_b: Vector2 = Vector2.INF
	var line: PackedVector2Array


## Pixels per world unit.
var px: float = 4.0
## The 沙盘's corners in projected units.
var low: Vector2 = Vector2.ZERO
var high: Vector2 = Vector2.ZERO
var roads: Array[Road] = []
var _cells: Dictionary = {}


static func read() -> AtlasPictures:
	var pictures := AtlasPictures.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BAKE))
	if parsed is Dictionary:
		pictures.px = float(parsed["px"])
		var frame: Array = parsed["frame"]
		pictures.low = Vector2(frame[0], frame[1])
		pictures.high = Vector2(frame[2], frame[3])
		pictures._cells = parsed["cells"]
		for row: Dictionary in parsed.get("roads", []):
			pictures.roads.append(_road(row))
	return pictures


static func _road(row: Dictionary) -> Road:
	var road := Road.new()
	road.a = StringName(row["a"])
	road.b = StringName(row["b"])
	road.file = row["file"]
	road.at = _corner(row["at"])
	road.stub_a = _corner(row["stub_a"])
	road.stub_b = _corner(row["stub_b"])
	for point: Array in row["line"]:
		road.line.append(Vector2(point[0], point[1]))
	return road


static func _corner(at: Array) -> Vector2:
	return Vector2.INF if at.is_empty() else Vector2(at[0], at[1])


## A baked layer: the land, the mist, a road.
func layer(file: String) -> Texture2D:
	return load(DIRECTORY + file + ".png") as Texture2D


## The road joining two places, whichever way round; null when none does.
func road_between(first: StringName, second: StringName) -> Road:
	for road: Road in roads:
		if (road.a == first and road.b == second) or (road.a == second and road.b == first):
			return road
	return null


## The 沙盘's size in picture pixels.
func stage_size() -> Vector2:
	return (high - low) * px


## Where a world position lies on the 沙盘.
func to_stage(at: Vector2) -> Vector2:
	return (Vector2((at.x - at.y) * COS_X, (at.x + at.y) * COS_Y) - low) * px


func has_picture(map_id: StringName) -> bool:
	return _cells.has(String(map_id))


func texture(map_id: StringName) -> Texture2D:
	return load(DIRECTORY + String(map_id) + ".png") as Texture2D


## The top left of the picture of the place at `at`.
func corner(map_id: StringName, at: Vector2) -> Vector2:
	var anchor: Array = _cells[String(map_id)]["anchor"]
	return to_stage(at) - Vector2(anchor[0], anchor[1])


## How far below the place's middle its picture ends.
func below(map_id: StringName) -> float:
	var cell: Dictionary = _cells[String(map_id)]
	return float(cell["size"][1]) - float(cell["anchor"][1])


## A room ("zone:<id>") or the door to another map ("door:<id>") in the place's picture;
## Vector2.INF when the bake has none.
func pin(map_id: StringName, key: String) -> Vector2:
	var pins: Dictionary = _cells.get(String(map_id), {}).get("pins", {})
	if not pins.has(key):
		return Vector2.INF
	return Vector2(pins[key][0], pins[key][1])
