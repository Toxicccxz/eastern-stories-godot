class_name CoplanarFaces
extends RefCounted

## Finds faces that fight in the depth buffer (z-fighting): two boxes of one place (parent), in
## different colours, whose faces look the same way, lie in one plane and overlap by more than an
## edge. Such a face flickers while the camera moves (owner, 2026-11-11). Reads what Shapes kept
## while `keep_flushed` was set. Undersides are left out: no camera of the game sees them. A
## stone (Shapes.shard) shows one flat face, its top: the part of it any of its shapes covers.

const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
## Faces nearer than this to one plane fight too (a collar 0.0002 before the face it touches);
## settled faces are at least Shapes.COPLANAR_STEP apart.
const NEAR: float = 0.0008
## How far across a stone's top (Shapes._stone_mesh), as a part of its size, it surely reaches
## whichever way its corners were chipped.
const STONE_TOP: float = 0.6


## The fights among `entries` (Shapes.flushed), described, at most `limit` of them.
## `for_map`: as the map's camera sees them (Shapes.settle_for_map): no north faces, no slivers or
## specks, no overlap narrower than a sliver. The ground's cells, which Shapes leaves as they are,
## are checked all the same: nothing may lie flush on them.
static func fights(entries: Array[Dictionary], limit: int = 20, for_map: bool = false) -> PackedStringArray:
	var by_parent: Dictionary = {}
	for entry: Dictionary in entries:
		var stone: bool = not entry["mesh"] is BoxMesh
		var parent: Variant = entry["parent"]
		if not by_parent.has(parent):
			by_parent[parent] = []
		var colors: PackedColorArray = entry["colors"]
		var transforms: Array = entry["transforms"]
		for i: int in transforms.size():
			var colour: String = String(entry["color"]) if colors.is_empty() else colors[i].to_html(false)
			(by_parent[parent] as Array).append([transforms[i], colour, entry.get("by", 0), stone])
	var found := PackedStringArray()
	for parent: Variant in by_parent:
		var place: String = String((parent as Node).name) if parent is Node else "?"
		if parent is Node and (parent as Node).get_meta("flat", false):
			place += " (flat)"
		_fights_in(by_parent[parent], place, found, limit, for_map)
		if found.size() >= limit:
			break
	return found


static func _fights_in(boxes: Array, place: String, found: PackedStringArray, limit: int, for_map: bool) -> void:
	var cells: Dictionary = {}
	for box: Array in boxes:
		var t: Transform3D = box[0]
		var stone: bool = box[3]
		for axis: int in ([1] if stone else [0, 1, 2]):
			var column: Vector3 = t.basis[axis]
			var length: float = column.length()
			if length < 0.00001:
				continue
			for side: float in ([1.0] if stone else [1.0, -1.0]):
				var normal: Vector3 = column / length * side
				var half_a: Vector3 = t.basis[(axis + 1) % 3] * (0.5 * STONE_TOP if stone else 0.5)
				var half_b: Vector3 = t.basis[(axis + 2) % 3] * (0.5 * STONE_TOP if stone else 0.5)
				if normal.y < -0.99 or (for_map and (Shapes._unseen_on_map(normal) or minf(half_a.length(), half_b.length()) < Shapes.SLIVER * 0.5 or maxf(half_a.length(), half_b.length()) < Shapes.SPECK * 0.5)):
					continue
				var centre: Vector3 = t.origin + column * 0.5 * side
				var face: Array = [normal, normal.dot(centre), centre, half_a, half_b, box[1], box[2]]
				var key := Vector4i(roundi(normal.x * 64.0), roundi(normal.y * 64.0), roundi(normal.z * 64.0), roundi(float(face[1]) * 2000.0))
				var reach: Vector3 = (face[3] as Vector3).abs() + (face[4] as Vector3).abs()
				var low := Vector3i((centre - reach).floor())
				var high := Vector3i((centre + reach).floor())
				var covered: Array[Vector3i] = []
				for x: int in range(low.x, high.x + 1):
					for y: int in range(low.y, high.y + 1):
						for z: int in range(low.z, high.z + 1):
							covered.append(Vector3i(x, y, z))
				var keys: Array[Vector4i] = []
				var floor_n := Vector3i((normal * 64.0).floor())
				var ceil_n := Vector3i((normal * 64.0).ceil())
				for x: int in range(floor_n.x, ceil_n.x + 1):
					for y: int in range(floor_n.y, ceil_n.y + 1):
						for z: int in range(floor_n.z, ceil_n.z + 1):
							for shift: int in [-2, -1, 0, 1, 2]:
								keys.append(Vector4i(x, y, z, key.w + shift))
				var seen: Dictionary = {}
				for near_key: Vector4i in keys:
					for cell: Vector3i in covered:
						var near: Variant = cells.get([near_key, cell])
						if near == null:
							continue
						for other: Array in near:
							if seen.has(other) or other[5] == face[5] or absf(float(other[1]) - float(face[1])) > NEAR or not Shapes._same_way(other[0], normal):
								continue
							seen[other] = true
							if Shapes._faces_overlap(centre, face[3], face[4], other[2], other[3], other[4], Shapes.SLIVER if for_map else 0.0005):
								found.append("%s: %s and %s meet in the plane %s·p=%.4f at %s%s" % [place, face[5], other[5], normal.snapped(Vector3.ONE * 0.01), float(face[1]), centre.snapped(Vector3.ONE * 0.001), "" if face[6] == other[6] else " (drawn by two Shapes)"])
								if found.size() >= limit:
									return
				for cell: Vector3i in covered:
					var at: Array = [key, cell]
					if not cells.has(at):
						cells[at] = []
					(cells[at] as Array).append(face)
