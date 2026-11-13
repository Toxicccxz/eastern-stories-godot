class_name BattleArena
extends Node3D

## 战斗演出 B (DECISIONS「战斗演出 B」): the stage a fight is fought on — owner 2026-11-08: an
## uneven square base in thin steps, like a low pyramid, laid quickly out of voxel bricks under
## the fighters. Three steps, each a brick narrower all round than the one below; the top holds
## every fighter's place with a brick to spare; every step's edge loses and gains a few bricks,
## its bricks a little uneven in height and colour, so the base reads laid by hand. It is laid
## from the bottom step up, row by row from the far side to the near, each brick dropping into
## place; a row's knock sounds as it lands. Its look is the mode's (battle_stage.json): a 切磋's
## pale boards with flags at the corners and a gong; a 死斗's blood-dark cracked stone, loose
## rubble round the foot, braziers at the corners, a low drum and a scrape of steel. A 切磋 that
## turns 死斗 is restained from the middle out. At the fight's end it is taken down, top step first.
## 战斗演出 D (DECISIONS「战斗演出 D」): the stage is no longer cut to the map's free cells — it is
## the standard size for the fighters' places (formation()), laid in its own square turned to
## face the camera, and raised over the map (BattleStageOpening moves it; a lamp of its own over
## it). 战斗演出 E (DECISIONS「战斗演出 E」): the two sides read on it — the top's left half (the
## player's) lit from its front edge in the player's side colour, the right half in the other
## side's (the mode says how strongly), a dark seam down the middle; every step's front edge a
## lighter row, so the steps read as steps. Owner 2026-11-09: the steps thinner, their edges more
## broken, and glowing bricks set among them like old rune stones (the look's `glow_bricks`: a
## 切磋's jade, a 死斗's embers, a 拆招's gold), breathing slowly (glow_brick.gdshader).
## Presentation only: the base is drawn in the voxel world, never in the 2D map; it moves no
## body, blocks nothing and is not saved.

signal laid
const DATA_PATH: String = "res://data/common/battle_stage.json"
## A 2D cell is this many pixels (the map's walking grid; a brick's side).
const CELL: float = 16.0

static var _data: Dictionary = {}

## The steps, bottom first: each the cells it covers ({Vector2i: true}), and the cells' 2D
## origin (the grid the map's tiles sit on).
var steps: Array[Dictionary] = []
## The stage's own grid: a cell's centre at every multiple of CELL (the stage's middle at 0, 0).
var origin: Vector2 = -Vector2(CELL, CELL) / 2.0
var look_key: String = ""
var _look: Dictionary = {}
var _arena: Dictionary = {}
## Each brick: [step, cell, rest Vector3, start seconds, colour Color, instance slot, drop, its
## MultiMesh's index in _meshes (each step has a stone one and a glowing one), glows].
var _bricks: Array[Array] = []
var _meshes: Array[MultiMeshInstance3D] = []
var _clock: float = 0.0
var _brick_seconds: float = 0.04
var _laying: bool = false
var _laid_at: float = 0.0
var _rows: Array[float] = []
var _next_row_sound: int = 0
var _last_row_sound: float = -1.0
var _row_sound_flip: bool = false
var _dressing: Array[Node3D] = []
var _flames: Array[MeshInstance3D] = []
## 战斗特效 (DECISIONS「战斗特效」): the base answers a blow. Each hop of its bricks: [the clock
## when it began, its middle (the base's x and z), how far it reaches, how high at the middle,
## how long a brick is in the air]; the braziers' lights and the flags, and the flare they are
## in: [the clock when it began, how long, how strong].
var _jolts: Array[Array] = []
## How many bricks the last frame of a hop set above where they lie (tests).
var _lifted: int = 0
var _flame_lights: Array[OmniLight3D] = []
var _flags: Array[Node3D] = []
var _flare: Array[float] = []
## A hop spreads outward this many seconds a unit.
const RIPPLE: float = 0.05
const FLAME_LIGHT: float = 0.9
const FLAG_SNAP: float = 0.32
var _restyle: Dictionary = {}
var _taking_down: float = -1.0
var _take_down_seconds: float = 0.3
## The clock when the base began coming down while still being laid (INF: it was laid).
var _taken_at: float = INF
var _rng := RandomNumberGenerator.new()
var _seed: int = 0
var _light: OmniLight3D
## A re-lay (one joined): no finishing sounds again.
var _quiet: bool = false


## The stage's data (battle_stage.json), read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## The look's key for a fight's mode: spar, lesson, else lethal (a story fight too).
static func look_for(mode: int) -> String:
	match mode:
		CombatEncounterMode.Value.SPAR:
			return "spar"
		CombatEncounterMode.Value.LESSON:
			return "lesson"
	return "lethal"


## The steps of a base under `fighters` (2D cells; `player` among them first-class): `free`
## says whether a cell may hold a brick. Bottom step first, each a dictionary of its cells.
## `tiers` steps; the top is the fighters' box grown by `margin`, at most `max_cells` across and
## deep (else centred on the player); each step below grows by one all round. `jitter` of each
## step's edge cells are dropped and as many added just outside (`rng` decides), then every
## step is cut to what the one below holds and to the free cells.
static func plan(fighters: Array[Vector2i], player: Vector2i, free: Callable, tiers: int, margin: int, max_cells: Vector2i, jitter: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var box := Rect2i(player, Vector2i.ONE)
	for cell: Vector2i in fighters:
		box = box.expand(cell).expand(cell + Vector2i.ONE)
	box = box.grow(margin)
	if box.size.x > max_cells.x or box.size.y > max_cells.y:
		var size := Vector2i(mini(box.size.x, max_cells.x), mini(box.size.y, max_cells.y))
		box = Rect2i(player - size / 2, size)
	var result: Array[Dictionary] = []
	for index: int in tiers:
		var grow: int = tiers - 1 - index
		var rect: Rect2i = box.grow(grow)
		var cells: Dictionary = {}
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				cells[Vector2i(x, y)] = true
		# The hand-laid edge: some edge bricks left out, some laid just beyond.
		var edge: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if cell.x == rect.position.x or cell.y == rect.position.y or cell.x == rect.end.x - 1 or cell.y == rect.end.y - 1:
				edge.append(cell)
		edge.sort()
		for cell: Vector2i in edge:
			var corner: bool = (cell.x == rect.position.x or cell.x == rect.end.x - 1) and (cell.y == rect.position.y or cell.y == rect.end.y - 1)
			if corner:
				continue
			var roll: float = rng.randf()
			if roll < jitter * 0.5:
				cells.erase(cell)
			elif roll < jitter:
				var out: Vector2i = cell
				if cell.x == rect.position.x:
					out.x -= 1
				elif cell.x == rect.end.x - 1:
					out.x += 1
				elif cell.y == rect.position.y:
					out.y -= 1
				else:
					out.y += 1
				cells[out] = true
		result.append(cells)
	# Every brick on one below it (the top steps cut to the lower), and only on free ground.
	for index: int in result.size():
		var cells: Dictionary = result[index]
		for cell: Vector2i in cells.keys():
			if not free.call(cell) or (index > 0 and not result[index - 1].has(cell)):
				cells.erase(cell)
	return result


## The 2D cell `point` falls in.
func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(((point - origin) / CELL).floor())


## The centre of `cell` in 2D.
func centre_of(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## Whether the top step holds `point` (the stage's own 2D, px): one standing there stands on it.
func holds(point: Vector2) -> bool:
	return not steps.is_empty() and steps.back().has(cell_of(point))


## The top step's height over the ground.
func top_height() -> float:
	return float(steps.size()) * float(_arena.get("tier_height", 0.1))


## The base's footprint in its own frame (units; x along its x, y along its z), `margin` wider
## all round (its rubble, a lunge to the edge).
func footprint(margin: float) -> Rect2:
	if steps.is_empty() or steps[0].is_empty():
		return Rect2()
	var box := Rect2(centre_of(steps[0].keys()[0]), Vector2.ZERO)
	for cell: Vector2i in steps[0]:
		box = box.expand(centre_of(cell) - Vector2(CELL, CELL) / 2.0).expand(centre_of(cell) + Vector2(CELL, CELL) / 2.0)
	return Rect2(box.position / VoxelMapGeometry.UNIT, box.size / VoxelMapGeometry.UNIT).grow(margin)


## The number of bricks (tests).
func brick_count() -> int:
	return _bricks.size()


## Whether the base is still being laid.
func laying() -> bool:
	return _laying


## The fighters' places on the stage (its own 2D, px: x to the camera's right, y toward the
## camera), by `formation` (battle_stage.json): the player on the left, their side's others
## behind them (further left), the other side on the right facing them, `rows` to a column (the
## first in front), each column's back rows a little further out. `mine`: the player first, then
## those on their side; `theirs`: the other side, the one the player faces first.
static func formation(mine: Array[StringName], theirs: Array[StringName], data_formation: Dictionary) -> Dictionary[StringName, Vector2]:
	var spots: Dictionary[StringName, Vector2] = {}
	var gap: float = float(data_formation.get("gap", 2.4))
	var column: float = float(data_formation.get("column", 1.1))
	var row: float = float(data_formation.get("row", 1.0))
	var rows: int = maxi(1, int(data_formation.get("rows", 3)))
	var stagger: float = float(data_formation.get("stagger", 0.35))
	for side: int in 2:
		var ids: Array[StringName] = mine if side == 0 else theirs
		var sign: float = -1.0 if side == 0 else 1.0
		# The player stands alone in front; their helpers' columns are behind them.
		var columns: Array[Array] = []
		var rest: Array[StringName] = ids.duplicate()
		if side == 0 and not rest.is_empty():
			columns.append([rest.pop_front()])
		while not rest.is_empty():
			var count: int = mini(rows, rest.size())
			columns.append(rest.slice(0, count))
			rest = rest.slice(count)
		for at: int in columns.size():
			var people: Array = columns[at]
			for index: int in people.size():
				var depth: float = (float(index) - float(people.size() - 1) / 2.0) * row
				if people.size() == 3:
					depth = [0.0, -row, row][index]
				var out: float = gap / 2.0 + float(at) * column + stagger * signf(-depth)
				spots[people[index]] = Vector2(sign * out, depth) * VoxelMapGeometry.UNIT
	return spots


## Lays a standard base under `spots` (formation()'s places, the stage's own px), `player` the
## player's, in `mode`'s look; `seconds_scale` scales the feel's times (the 战斗速度, the short
## opening); `short`: each whole step drops at once. `place_seed`: the same place, the same base.
func lay(spots: Array[Vector2], player: Vector2, mode: int, seconds_scale: float = 1.0, short: bool = false, place_seed: int = 0) -> void:
	_arena = data().get("arena", {})
	look_key = look_for(mode)
	_look = data().get("looks", {}).get(look_key, {})
	_seed = place_seed
	_plan_steps(spots, player)
	_build(seconds_scale, short)


func _plan_steps(spots: Array[Vector2], player: Vector2) -> void:
	_rng.seed = _seed
	var cells: Array[Vector2i] = []
	for point: Vector2 in spots:
		cells.append(cell_of(point))
	var all_free := func(_cell: Vector2i) -> bool: return true
	var size: Array = _arena.get("max_cells", [28, 20])
	steps = plan(cells, cell_of(player), all_free, int(_arena.get("tiers", 3)), int(_arena.get("margin", 2)), Vector2i(int(size[0]), int(size[1])), float(_arena.get("jitter", 0.18)), _rng)


## One who joined: the base laid again (quickly) when `spots` no longer all stand on its top.
func grow_to(spots: Array[Vector2], player: Vector2) -> void:
	if steps.is_empty() or spots.all(holds):
		return
	_laying = false
	_restyle = {}
	for node: Node3D in _dressing:
		if is_instance_valid(node):
			node.queue_free()
	_dressing.clear()
	_flames.clear()
	# What answered a blow goes with the dressing (the base's clock starts over when it is built
	# again): no hop or flare carries over.
	_flags.clear()
	_flame_lights.clear()
	_flare = []
	for mesh: MultiMeshInstance3D in _meshes:
		mesh.queue_free()
	_meshes.clear()
	_jolts.clear()
	_plan_steps(spots, player)
	# Laid wider at once, quietly (the fight goes on on it).
	_quiet = true
	_build(0.0, true)
	_quiet = false


## Whether the room around `point` (2D, on `map`) is small: few free cells within eight (the
## camera pitches less there, so the view stays inside the room).
static func small_room(map: WorldMapController, point: Vector2) -> bool:
	var blocked: Array[Rect2] = _blocked_rects(map)
	var parts: WorldMapStaticNodes = map.static_nodes()
	var free := func(cell: Vector2i) -> bool:
		var centre: Vector2 = point + Vector2(cell) * CELL
		if not parts.walkable_tile(centre):
			return false
		for rect: Rect2 in blocked:
			if rect.has_point(centre):
				return false
		return true
	return _free_around(Vector2i.ZERO, free) < int(data().get("arena", {}).get("small_cells", 64))


## Whether the room around `cell` is small: its free cells within eight cells.
static func _free_around(cell: Vector2i, free: Callable) -> int:
	var count: int = 0
	for y: int in range(cell.y - 8, cell.y + 9):
		for x: int in range(cell.x - 8, cell.x + 9):
			if free.call(Vector2i(x, y)):
				count += 1
	return count


## The map's walls, door wings and furniture as 2D rectangles (what makes a room small).
static func _blocked_rects(map: WorldMapController) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for collision: CollisionShape2D in map.static_nodes().static_shapes:
		if collision.disabled or collision.shape == null:
			continue
		rects.append(collision.global_transform * collision.shape.get_rect())
	return rects


func _build(seconds_scale: float, short: bool) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var brick: float = float(_arena.get("brick", 0.5))
	var gap: float = float(_arena.get("gap", 0.03))
	var tier_height: float = float(_arena.get("tier_height", 0.1))
	var height_jitter: float = float(_arena.get("height_jitter", 0.02))
	var drop: float = float(_arena.get("drop_height", 0.35))
	_brick_seconds = maxf(0.0, feel.arena_brick_seconds * seconds_scale)
	# Rows: each step's cells by their 2D row, far (low y) to near; bottom step first.
	var rows: Array[Array] = []
	for index: int in steps.size():
		var by_row: Dictionary = {}
		for cell: Vector2i in steps[index]:
			if not by_row.has(cell.y):
				by_row[cell.y] = []
			by_row[cell.y].append(cell)
		var keys: Array = by_row.keys()
		keys.sort()
		for y: Variant in keys:
			var row: Array = by_row[y]
			row.sort()
			rows.append([index, row])
	if short:
		# The short opening: each whole step drops at once.
		var merged: Array[Array] = []
		for index: int in steps.size():
			var all: Array = []
			for row: Array in rows:
				if row[0] == index:
					all.append_array(row[1])
			merged.append([index, all])
		rows = merged
	var row_seconds: float = feel.arena_row_seconds * seconds_scale
	var cap: float = feel.arena_build_max_seconds * seconds_scale
	if rows.size() > 0 and row_seconds * rows.size() + _brick_seconds > cap:
		row_seconds = maxf(0.0, (cap - _brick_seconds) / float(rows.size()))
	var tiers_colours: Array = _look.get("tiers", [])
	var rim := Color(String(_look.get("rim", "a3301f")))
	_meshes.clear()
	for index: int in steps.size():
		var mesh := MultiMeshInstance3D.new()
		mesh.name = "Step%d" % index
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		var box := BoxMesh.new()
		box.size = Vector3(brick - gap, tier_height, brick - gap)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		box.material = material
		multi.mesh = box
		multi.instance_count = steps[index].size()
		mesh.multimesh = multi
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mesh)
		_meshes.append(mesh)
	# The glowing bricks: which cells (their own draw, so the stone's stays the same at one place),
	# then a MultiMesh of them per step after the stone ones.
	var glow_look: Dictionary = _look.get("glow_bricks", {})
	var glow_rng := RandomNumberGenerator.new()
	glow_rng.seed = _seed + 97
	var glowing: Dictionary = {}
	var glow_counts: Array[int] = []
	for index: int in steps.size():
		var count: int = 0
		for cell: Vector2i in steps[index]:
			var edge: bool = _on_edge(steps[index], cell)
			var share: float = float(glow_look.get("edge", 0.0)) if edge else (float(glow_look.get("top", 0.0)) if index == steps.size() - 1 else 0.0)
			if glow_rng.randf() < share:
				glowing[Vector3i(cell.x, cell.y, index)] = true
				count += 1
		glow_counts.append(count)
	for index: int in steps.size():
		var mesh := MultiMeshInstance3D.new()
		mesh.name = "Glow%d" % index
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		var box := BoxMesh.new()
		box.size = Vector3(brick - gap, tier_height, brick - gap)
		if _glow_material == null:
			_glow_material = ShaderMaterial.new()
			_glow_material.shader = GLOW_SHADER
		box.material = _glow_material
		multi.mesh = box
		multi.instance_count = glow_counts[index]
		mesh.multimesh = multi
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		_meshes.append(mesh)
		_meshes[index].multimesh.instance_count = steps[index].size() - glow_counts[index]
	var glow_colours: Array = glow_look.get("colours", ["ffb347"])
	_lamp()
	var counters: Array[int] = []
	counters.resize(steps.size() * 2)
	_bricks.clear()
	_rows.clear()
	for order: int in rows.size():
		var index: int = rows[order][0]
		var row: Array = rows[order][1]
		var start: float = float(order) * row_seconds
		_rows.append(start + _brick_seconds)
		var colours: Array = tiers_colours[mini(index, tiers_colours.size() - 1)] if not tiers_colours.is_empty() else ["7a6034"]
		for at: int in row.size():
			var cell: Vector2i = row[at]
			var top_edge: bool = index == steps.size() - 1 and _on_edge(steps[index], cell)
			var colour: Color = rim if top_edge else Color(String(colours[_rng.randi_range(0, colours.size() - 1)]))
			var shade: float = _rng.randf_range(-0.05, 0.05)
			colour = colour.lightened(shade) if shade > 0.0 else colour.darkened(-shade)
			# 战斗演出 E: a step's front edge (toward the camera) a lighter row.
			if not top_edge and not steps[index].has(cell + Vector2i(0, 1)):
				colour = colour.lightened(FRONT_EDGE_LIGHTEN)
			var centre: Vector2 = centre_of(cell)
			var rest := Vector3(centre.x / VoxelMapGeometry.UNIT, (float(index) + 0.5) * tier_height + _rng.randf_range(-height_jitter, height_jitter), centre.y / VoxelMapGeometry.UNIT)
			var glows: bool = glowing.has(Vector3i(cell.x, cell.y, index))
			if glows:
				colour = Color(String(glow_colours[glow_rng.randi_range(0, glow_colours.size() - 1)]))
			var mesh_index: int = index + (steps.size() if glows else 0)
			var slot: int = counters[mesh_index]
			counters[mesh_index] += 1
			# Short rows: the bricks of a row land a little one after another.
			var stagger: float = minf(row_seconds * 0.6, 0.004 * float(at)) if not short else 0.0
			_bricks.append([index, cell, rest, start + stagger, colour, slot, drop, mesh_index, glows])
			_meshes[mesh_index].multimesh.set_instance_color(slot, colour)
			_meshes[mesh_index].multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), rest))
	_clock = 0.0
	_next_row_sound = 0
	_last_row_sound = -1.0
	_laying = true
	_laid_at = (_rows.back() if not _rows.is_empty() else 0.0)
	set_process(true)
	if _rows.is_empty() or _laid_at <= 0.0:
		_finish_laying()


const FRONT_EDGE_LIGHTEN: float = 0.22
const GLOW_SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 colour : source_color = vec4(1.0);
uniform float strength = 0.5;
void fragment() {
	// UV.y 0 at the back, 1 at the front edge: brightest at the front, gone by the back third.
	float rise = smoothstep(0.3, 1.0, UV.y);
	ALBEDO = colour.rgb * strength * rise;
}
"""
static var _glow_shader: Shader
const GLOW_SHADER: Shader = preload("res://presentation/voxel/shaders/glow_brick.gdshader")
var _glow_material: ShaderMaterial


## The glowing bricks laid now (tests).
func glowing_bricks() -> int:
	var count: int = 0
	for brick: Array in _bricks:
		if bool(brick[8]):
			count += 1
	return count


## 战斗演出 E: each half of the top lit in its side's colour from the front edge (the look's
## `glow`: how strongly, the player's side and the other), the dark seam between them.
func _sides_glow(look: Dictionary) -> void:
	if steps.is_empty() or steps.back().is_empty():
		return
	var sides: Dictionary = data().get("sides", {})
	var glow: Dictionary = look.get("glow", {})
	var top := Rect2(centre_of(steps.back().keys()[0]), Vector2.ZERO)
	for cell: Vector2i in steps.back():
		top = top.expand(centre_of(cell) - Vector2(CELL, CELL) / 2.0).expand(centre_of(cell) + Vector2(CELL, CELL) / 2.0)
	top = Rect2(top.position / VoxelMapGeometry.UNIT, top.size / VoxelMapGeometry.UNIT)
	var height: float = top_height() + 0.012
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER_CODE
	var holder := Node3D.new()
	holder.name = "SidesGlow"
	add_child(holder)
	_dressing.append(holder)
	for side: int in 2:
		var key: String = "mine" if side == 0 else "theirs"
		var left: float = top.position.x if side == 0 else 0.0
		var right: float = 0.0 if side == 0 else top.end.x
		if right - left <= 0.0:
			continue
		var plane := PlaneMesh.new()
		plane.size = Vector2(right - left, top.size.y)
		var material := ShaderMaterial.new()
		material.shader = _glow_shader
		material.set_shader_parameter("colour", Color(String(sides.get(key, "4f8f78" if side == 0 else "c8402a"))))
		material.set_shader_parameter("strength", float(glow.get(key, 0.4)))
		plane.material = material
		var mesh := MeshInstance3D.new()
		mesh.name = "Glow_" + key
		mesh.mesh = plane
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = Vector3((left + right) / 2.0, height, top.get_center().y)
		holder.add_child(mesh)
	var seam: MeshInstance3D = _box(holder, Vector3(0.07, 0.016, top.size.y), Vector3(0.0, height, top.get_center().y), Color(String(sides.get("seam", "140b07"))))
	seam.name = "Seam"


## How strongly each half of the top glows now ([mine, theirs]; tests).
func glow_strengths() -> Array[float]:
	var found: Array[float] = []
	for node: Node3D in _dressing:
		if is_instance_valid(node) and node.name == "SidesGlow":
			for key: String in ["mine", "theirs"]:
				var mesh := node.get_node_or_null("Glow_" + key) as MeshInstance3D
				found.append(float((mesh.mesh.material as ShaderMaterial).get_shader_parameter("strength")) if mesh != null else 0.0)
	return found


## The stage's own lamp over its middle (the look's `light`): the fighters read clear over the
## darkened map, a room's lamps or none.
func _lamp() -> void:
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "StageLight"
		_light.shadow_enabled = false
		add_child(_light)
	var lamp: Dictionary = _look.get("light", {})
	_light.light_color = Color(String(lamp.get("colour", "ffe6c0")))
	_light.light_energy = float(lamp.get("energy", 1.0))
	_light.omni_range = float(lamp.get("range", 7.0))
	_light.position = Vector3(0.0, float(lamp.get("height", 3.2)), float(lamp.get("forward", 1.2)))


static func _on_edge(cells: Dictionary, cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not cells.has(cell + step):
			return true
	return false


func _process(delta: float) -> void:
	_clock += delta
	if _laying:
		_advance_laying()
	if not _restyle.is_empty():
		_advance_restyle(delta)
	if _taking_down >= 0.0:
		_advance_take_down(delta)
	if not _jolts.is_empty():
		_advance_jolts()
	var boost: float = _advance_flare()
	for flame: MeshInstance3D in _flames:
		if is_instance_valid(flame):
			var flicker: float = 1.0 + 0.18 * sin(_clock * 17.0 + flame.position.x * 3.0) + 0.08 * sin(_clock * 31.0)
			flame.scale = Vector3(1.0 + 0.3 * boost, flicker * (1.0 + boost), 1.0 + 0.3 * boost)
	if not _laying and _restyle.is_empty() and _taking_down < 0.0 and _flames.is_empty() and _jolts.is_empty() and _flare.is_empty():
		set_process(false)


## 战斗特效: the bricks round `at` (the base's own space) hop — highest at the middle, none
## past `radius`, the hop spreading outward, each brick `seconds` in the air. Not while the base
## is being laid, restained or taken down.
func jolt(at: Vector3, radius: float, height: float, seconds: float) -> void:
	if _laying or _taking_down >= 0.0 or not _restyle.is_empty() or _bricks.is_empty() or seconds <= 0.0 or radius <= 0.0 or height <= 0.0:
		return
	_jolts.append([_clock, Vector2(at.x, at.z), radius, height, seconds])
	set_process(true)


## Whether a hop of the bricks is under way (tests).
func jolting() -> bool:
	return not _jolts.is_empty()


## How many bricks are in the air now (tests: the renderer's own copy cannot be read headless).
func lifted_bricks() -> int:
	return _lifted if not _jolts.is_empty() else 0


## How high the brick whose place is `rest` stands over it now (tests).
func lift_at(rest: Vector3) -> float:
	var lift: float = 0.0
	for hop: Array in _jolts:
		var distance: float = Vector2(rest.x, rest.z).distance_to(hop[1])
		if distance > float(hop[2]):
			continue
		var p: float = (_clock - float(hop[0]) - distance * RIPPLE) / float(hop[4])
		if p > 0.0 and p < 1.0:
			lift += float(hop[3]) * (1.0 - distance / float(hop[2])) * sin(p * PI)
	return lift


func _advance_jolts() -> void:
	# A hop cut short (the base restained or coming down): every brick back where it lies.
	var cut: bool = _laying or _taking_down >= 0.0
	_lifted = 0
	for brick: Array in _bricks:
		var rest: Vector3 = brick[2]
		var near: bool = false
		for hop: Array in _jolts:
			near = near or Vector2(rest.x, rest.z).distance_to(hop[1]) <= float(hop[2])
		if near and not cut:
			var lift: float = lift_at(rest)
			_lifted += 1 if lift > 0.0 else 0
			_meshes[brick[7]].multimesh.set_instance_transform(brick[5], Transform3D(Basis(), rest + Vector3.UP * lift))
	_jolts = _jolts.filter(func(hop: Array) -> bool: return not cut and _clock - float(hop[0]) < float(hop[4]) + float(hop[2]) * RIPPLE)


## 战斗特效: the braziers leap and the flags snap — `strength` at once, dying away over `seconds`.
func flare(strength: float, seconds: float) -> void:
	if seconds <= 0.0 or strength <= 0.0 or (_flames.is_empty() and _flags.is_empty()):
		return
	_flare = [_clock, seconds, strength]
	set_process(true)


## Whether the braziers and flags are in a flare (tests).
func flaring() -> bool:
	return not _flare.is_empty()


## The flare a frame on: how much stronger the flames burn now (0 none); the lights with them,
## the flags snapping; everything as it was once it is over.
func _advance_flare() -> float:
	if _flare.is_empty():
		return 0.0
	var left: float = clampf(1.0 - (_clock - _flare[0]) / _flare[1], -1.0, 1.0)
	var boost: float = maxf(0.0, left) * _flare[2]
	for light: OmniLight3D in _flame_lights:
		if is_instance_valid(light):
			light.light_energy = FLAME_LIGHT * (1.0 + boost)
	for flag: Node3D in _flags:
		if is_instance_valid(flag):
			flag.rotation.z = FLAG_SNAP * maxf(0.0, left) * sin((_clock - _flare[0]) * 38.0)
	if left <= 0.0:
		_flare = []
	return boost


func _advance_laying() -> void:
	for brick: Array in _bricks:
		var t: float = _clock - float(brick[3])
		var mesh: MultiMeshInstance3D = _meshes[brick[7]]
		var rest: Vector3 = brick[2]
		if t < 0.0:
			continue
		var p: float = 1.0 if _brick_seconds <= 0.0 else clampf(t / _brick_seconds, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - p, 3.0)
		var at: Vector3 = rest + Vector3.UP * float(brick[6]) * (1.0 - eased)
		mesh.multimesh.set_instance_transform(brick[5], Transform3D(Basis(), at))
	# A row's knock as it lands, at most one every ROW_SOUND_GAP (so a quick base is a run of
	# knocks, not a buzz), its pitch turning a little each time.
	while _next_row_sound < _rows.size() and _clock >= _rows[_next_row_sound]:
		if _last_row_sound < 0.0 or _clock - _last_row_sound >= ROW_SOUND_GAP:
			_row_sound_flip = not _row_sound_flip
			BattleSounds.cue(StringName(_look.get("row_sound", "brick_wood")), 1.0 if _row_sound_flip else 0.9, -4.0)
			_last_row_sound = _clock
		_next_row_sound += 1
	if _clock >= _laid_at:
		_finish_laying()


const ROW_SOUND_GAP: float = 0.07


## Everything in place at once (a key pressed during the opening).
func skip() -> void:
	if not _laying:
		return
	_clock = _laid_at
	_advance_laying()


func _finish_laying() -> void:
	_laying = false
	for brick: Array in _bricks:
		_meshes[brick[7]].multimesh.set_instance_transform(brick[5], Transform3D(Basis(), brick[2]))
	if not _quiet:
		for sound: Array in _look.get("done_sounds", []):
			BattleSounds.cue(StringName(sound[0]), float(sound[1]), float(sound[2]))
	_dress(_look)
	laid.emit()


# --- the dressing: flags, braziers, rubble ----------------------------------------------------


## The base's corners: the bottom step's brick nearest each corner of its box (a broken edge may
## leave the box's own corner cells empty).
func _corners() -> Array[Vector2i]:
	if steps.is_empty() or steps[0].is_empty():
		return []
	var box := Rect2i(steps[0].keys()[0], Vector2i.ONE)
	for cell: Vector2i in steps[0]:
		box = box.expand(cell).expand(cell + Vector2i.ONE)
	var found: Array[Vector2i] = []
	for corner: Vector2i in [box.position, Vector2i(box.end.x - 1, box.position.y), Vector2i(box.position.x, box.end.y - 1), box.end - Vector2i.ONE]:
		var best: Vector2i = corner
		var nearest: float = INF
		for cell: Vector2i in steps[0]:
			var distance: float = Vector2(cell - corner).length_squared()
			if distance < nearest:
				nearest = distance
				best = cell
		found.append(best)
	return found


func _dress(look: Dictionary) -> void:
	var height: float = float(_arena.get("tier_height", 0.1))
	match String(look.get("corners", "none")):
		"flag":
			for cell: Vector2i in _corners():
				if steps[0].has(cell):
					_flag(cell, look, height)
		"brazier":
			for cell: Vector2i in _corners():
				if steps[0].has(cell):
					_brazier(cell, look, height)
	_sides_glow(look)
	var rubble: int = int(look.get("rubble", 0))
	if rubble > 0:
		_rubble(rubble, look.get("rubble_colours", ["4a1712"]))
	for node: Node3D in _dressing:
		var full: Vector3 = node.scale
		node.scale = Vector3.ZERO
		create_tween().tween_property(node, "scale", full, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _corner_node(cell: Vector2i, name_text: String, height: float) -> Node3D:
	var node := Node3D.new()
	node.name = name_text
	var centre: Vector2 = centre_of(cell)
	node.position = Vector3(centre.x / VoxelMapGeometry.UNIT, height, centre.y / VoxelMapGeometry.UNIT)
	add_child(node)
	_dressing.append(node)
	return node


func _flag(cell: Vector2i, look: Dictionary, height: float) -> void:
	var node: Node3D = _corner_node(cell, "Flag", height)
	_flags.append(node)
	_box(node, Vector3(0.07, 1.25, 0.07), Vector3(0, 0.625, 0), Color(String(look.get("pole", "5a3820"))))
	_box(node, Vector3(0.42, 0.28, 0.04), Vector3(0.24, 1.08, 0), Color(String(look.get("flag", "4f8f78"))))
	_box(node, Vector3(0.44, 0.04, 0.05), Vector3(0.24, 0.93, 0), Color(String(look.get("flag_edge", "e9b84c"))))


func _brazier(cell: Vector2i, look: Dictionary, height: float) -> void:
	var node: Node3D = _corner_node(cell, "Brazier", height)
	var bowl := Color(String(look.get("bowl", "2b2e2f")))
	_box(node, Vector3(0.1, 0.32, 0.1), Vector3(0, 0.16, 0), bowl.darkened(0.2))
	_box(node, Vector3(0.36, 0.14, 0.36), Vector3(0, 0.38, 0), bowl)
	var flame: MeshInstance3D = _box(node, Vector3(0.22, 0.26, 0.22), Vector3(0, 0.52, 0), Color(String(look.get("flame", "ff8a2a"))), true)
	_box(flame, Vector3(0.1, 0.16, 0.1), Vector3(0, 0.02, 0), Color(String(look.get("flame_core", "ffd27a"))), true)
	_flames.append(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(String(look.get("flame", "ff8a2a")))
	light.omni_range = 2.6
	light.light_energy = FLAME_LIGHT
	light.position = Vector3(0, 0.7, 0)
	node.add_child(light)
	_flame_lights.append(light)


func _rubble(count: int, colours: Array) -> void:
	if steps.is_empty():
		return
	var ring: Array[Vector2i] = []
	for cell: Vector2i in steps[0]:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not steps[0].has(cell + step):
				ring.append(cell + step)
	if ring.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Rubble"
	add_child(holder)
	_dressing.append(holder)
	for index: int in count:
		var cell: Vector2i = ring[_rng.randi_range(0, ring.size() - 1)]
		var centre: Vector2 = centre_of(cell) + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0))
		var side: float = _rng.randf_range(0.08, 0.18)
		var stone: MeshInstance3D = _box(holder, Vector3(side, side * 0.7, side * _rng.randf_range(0.8, 1.3)), Vector3(centre.x / VoxelMapGeometry.UNIT, side * 0.35, centre.y / VoxelMapGeometry.UNIT), Color(String(colours[_rng.randi_range(0, colours.size() - 1)])))
		stone.rotation.y = _rng.randf_range(0.0, TAU)


# --- a 切磋 turning 死斗; the end ------------------------------------------------------------------


## The base restained into `mode`'s look from the middle out over `seconds` (a 切磋 turned 死斗):
## the corners' dressing goes and the new look's comes, with its finishing sounds.
func restyle(mode: int, seconds: float) -> void:
	var key: String = look_for(mode)
	if key == look_key or steps.is_empty():
		return
	if _laying:
		skip()
	look_key = key
	_look = data().get("looks", {}).get(key, {})
	_lamp()
	for node: Node3D in _dressing:
		if is_instance_valid(node):
			node.queue_free()
	_dressing.clear()
	_flames.clear()
	# What answered a blow goes with the dressing (the base's clock starts over when it is built
	# again): no hop or flare carries over.
	_flags.clear()
	_flame_lights.clear()
	_flare = []
	var centre := Vector2.ZERO
	for brick: Array in _bricks:
		centre += Vector2(brick[1])
	centre /= maxf(1.0, float(_bricks.size()))
	var reach: float = 0.001
	for brick: Array in _bricks:
		reach = maxf(reach, Vector2(brick[1]).distance_to(centre))
	var colours: Array = _look.get("tiers", [])
	var rim := Color(String(_look.get("rim", "a3301f")))
	var plan_colours: Array = []
	for brick: Array in _bricks:
		var index: int = brick[0]
		var top_edge: bool = index == steps.size() - 1 and _on_edge(steps[index], brick[1])
		var pick: Array = colours[mini(index, colours.size() - 1)] if not colours.is_empty() else ["4a1712"]
		var to: Color = rim if top_edge else Color(String(pick[_rng.randi_range(0, pick.size() - 1)]))
		if not top_edge and not steps[index].has(Vector2i(brick[1]) + Vector2i(0, 1)):
			to = to.lightened(FRONT_EDGE_LIGHTEN)
		if bool(brick[8]):
			var glows_now: Array = _look.get("glow_bricks", {}).get("colours", ["ffb347"])
			to = Color(String(glows_now[_rng.randi_range(0, glows_now.size() - 1)]))
		plan_colours.append([brick[4], to, Vector2(brick[1]).distance_to(centre) / reach * seconds * 0.7])
	_restyle = {"clock": 0.0, "seconds": maxf(0.001, seconds), "colours": plan_colours}
	set_process(true)
	if seconds <= 0.0:
		_advance_restyle(1.0)


func restyling() -> bool:
	return not _restyle.is_empty()


func _advance_restyle(delta: float) -> void:
	_restyle["clock"] = float(_restyle["clock"]) + delta
	var now: float = _restyle["clock"]
	var part: float = float(_restyle["seconds"]) * 0.3
	var colours: Array = _restyle["colours"]
	for at: int in _bricks.size():
		var entry: Array = colours[at]
		var p: float = 1.0 if part <= 0.0 else clampf((now - float(entry[2])) / part, 0.0, 1.0)
		var colour: Color = (entry[0] as Color).lerp(entry[1], p)
		_meshes[_bricks[at][7]].multimesh.set_instance_color(_bricks[at][5], colour)
		if p >= 1.0:
			_bricks[at][4] = entry[1]
	if now >= float(_restyle["seconds"]) or float(_restyle["seconds"]) <= 0.001:
		_restyle = {}
		for sound: Array in _look.get("done_sounds", []):
			BattleSounds.cue(StringName(sound[0]), float(sound[1]), float(sound[2]))
		_dress(_look)


## The base taken down over `seconds`, top step first, then freed (0: at once).
func take_down(seconds: float) -> void:
	# Bricks not dropped yet stay unseen while the rest come down.
	_taken_at = _clock if _laying else INF
	_laying = false
	_restyle = {}
	if seconds <= 0.0:
		queue_free()
		return
	_take_down_seconds = seconds
	_taking_down = 0.0
	if _light != null:
		create_tween().tween_property(_light, "light_energy", 0.0, seconds)
	for node: Node3D in _dressing:
		if is_instance_valid(node):
			create_tween().tween_property(node, "scale", Vector3.ZERO, seconds * 0.4)
	set_process(true)


func taking_down() -> bool:
	return _taking_down >= 0.0


func _advance_take_down(delta: float) -> void:
	_taking_down += delta
	var share: float = _take_down_seconds / float(maxi(1, steps.size()))
	for brick: Array in _bricks:
		if float(brick[3]) > _taken_at:
			continue
		var from_top: int = steps.size() - 1 - int(brick[0])
		var p: float = clampf((_taking_down - float(from_top) * share * 0.6) / share, 0.0, 1.0)
		var rest: Vector3 = brick[2]
		var shrink: float = 1.0 - p
		_meshes[brick[7]].multimesh.set_instance_transform(brick[5], Transform3D(Basis().scaled(Vector3(shrink, shrink, shrink)), rest + Vector3.DOWN * 0.2 * p))
	if _taking_down >= _take_down_seconds:
		queue_free()
