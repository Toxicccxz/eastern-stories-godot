extends SceneTree
## The 地图 page's pictures (DECISIONS「总图」): each place's real voxel world seen whole from the
## view's own angle, one low warm sun for every place, no people, no HUD, no far scenery, on a
## transparent ground. Windowed (it needs the renderer). Run by bake.py, a few maps a run:
##   godot --path game --script <this> -- <out dir> <px per unit> <map> ...
## An argument `@arrow` draws the sand table's arrow instead. Prints TRIM and PIN lines.

const DROPPED: Array[String] = ["far_peak", "cloud_sea"]
const SUN_COLOUR := Color("ffba80")
const SKY_COLOUR := Color("8fa4c8")
var session: WorldSessionController


class Still extends WorldInteractionRandomSource:
	func next_below(bound: int) -> int:
		return bound - 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	var scale: float = float(args[1])
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(640, 360)
	if args.has("@arrow"):
		await _bake_arrow(out.path_join("arrow.png"))
		quit()
		return
	for npc: NpcDefinition in GameContent.catalog().npcs():
		npc.attitude = NpcDefinition.Attitude.PEACEFUL
		npc._capability_ids.clear()
	session = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	session.configure_source_entry("沈沧海", CharacterState.GENDER_MALE)
	session.configure_npc_ambience_random_source(Still.new())
	root.add_child(session)
	await create_timer(0.6).timeout
	for map_id: String in args.slice(2):
		var map: WorldMapController = await _enter(StringName(map_id))
		if map == null:
			print("NO MAP ", map_id)
			continue
		await create_timer(1.2).timeout
		var view := map.get_node_or_null("MapView") as WorldVoxelView
		if view == null or view.camera == null:
			print("NO VIEW ", map_id)
			continue
		await _bake(view, map, out.path_join(map_id + ".png"), scale)
	quit()


## Onto the map, its voxel config first stripped of what stands far off.
func _enter(map_id: StringName) -> WorldMapController:
	var resident := session.resident_map(map_id) as WorldMapController
	var waiting: WorldVoxelView = null if resident == null else resident.get_node_or_null("MapView") as WorldVoxelView
	if waiting != null and not waiting._built:
		waiting.layout_path = _without_far_scenery(waiting.layout_path, map_id)
	if session.active_map_id() == map_id:
		return session.active_map() as WorldMapController
	var definition: MapDefinition = GameContent.catalog().map(map_id)
	var entry: String = String(definition.entry_spawn_id)
	var zone: StringName = &""
	for candidate: ZoneDefinition in GameContent.catalog().zones_for_map(map_id):
		if entry.begins_with(String(candidate.zone_id) + ".") and String(candidate.zone_id).length() > String(zone).length():
			zone = candidate.zone_id
	if not session.handoff_to(map_id, zone, zone, definition.entry_spawn_id).succeeded():
		return null
	return session.active_map() as WorldMapController


## The map's config beside its region's flora and light under user://, its far scenery gone.
func _without_far_scenery(path: String, map_id: StringName) -> String:
	var dir: String = "user://atlas/%s/voxel" % map_id
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in ["flora.json", "light.json"]:
		var from: String = path.get_base_dir().path_join(name)
		if FileAccess.file_exists(from):
			FileAccess.open(dir.path_join(name), FileAccess.WRITE).store_string(FileAccess.get_file_as_string(from))
	var target: String = dir.path_join(path.get_file())
	var filtered: Variant = _filtered(JSON.parse_string(FileAccess.get_file_as_string(path)))
	FileAccess.open(target, FileAccess.WRITE).store_string(JSON.stringify(filtered))
	return target


func _filtered(value: Variant) -> Variant:
	if value is Array:
		var kept: Array = []
		for item: Variant in value:
			if item is Dictionary and DROPPED.has(String(item.get("kind", ""))):
				continue
			kept.append(_filtered(item))
		return kept
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value:
			copy[key] = _filtered(value[key])
		return copy
	return value


func _bake(view: WorldVoxelView, map: WorldMapController, path: String, scale: float) -> void:
	for table: Dictionary in [view.actors, view.labels, view.alert_marks, view.arrows]:
		for node: Node3D in table.values():
			node.visible = false
	for entry: Dictionary in view.entrances.values():
		(entry["node"] as Node3D).visible = false
	if view.quest_marker != null:
		view.quest_marker.visible = false
	view.lighting.set_frame("day", true)
	view.process_mode = Node.PROCESS_MODE_DISABLED
	var environment: Environment = view.lighting.environment
	environment.fog_enabled = false
	environment.ambient_light_color = SKY_COLOUR
	environment.ambient_light_energy = 0.5
	var sun: DirectionalLight3D = view.lighting.sun
	sun.light_color = SUN_COLOUR
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-26, -50, 0)
	sun.directional_shadow_max_distance = 1200
	var basis: Basis = view.camera.global_transform.basis
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var middle := Vector3.ZERO
	var count: int = 0
	for zone: WorldPhysicalZoneArea2D in map.physical_zones():
		var rect: Rect2 = zone.global_rect()
		for corner: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
			var at: Vector3 = VoxelMapGeometry.point(corner)
			middle += at
			count += 1
			var seen := Vector2(at.dot(basis.x), at.dot(basis.y))
			low = Vector2(minf(low.x, seen.x), minf(low.y, seen.y))
			high = Vector2(maxf(high.x, seen.x), maxf(high.y, seen.y))
	var margin: float = 34.0
	low -= Vector2(margin, margin)
	high += Vector2(margin, margin + 6.0)
	var span: Vector2 = high - low
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ceili(span.x * scale), ceili(span.y * scale))
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = root.world_3d
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = span.y
	camera.near = 1.0
	camera.far = 1200.0
	viewport.add_child(camera)
	var centre: Vector2 = (low + high) / 2.0
	var along: float = (middle / count).dot(basis.z)
	camera.global_transform = Transform3D(basis, basis.x * centre.x + basis.y * centre.y + basis.z * (along + 500.0))
	camera.current = true
	for _frame: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var used: Rect2i = image.get_used_rect()
	image.get_region(used).save_png(path)
	var name: String = path.get_file().get_basename()
	var px := func(at: Vector3) -> Vector2:
		return Vector2((at.dot(basis.x) - low.x) * scale, (high.y - at.dot(basis.y)) * scale) - Vector2(used.position)
	var anchor: Vector2 = px.call(middle / count)
	print("TRIM ", name, " ", used.size.x, " ", used.size.y, " ", anchor.x, " ", anchor.y)
	for zone: WorldPhysicalZoneArea2D in map.physical_zones():
		var point: Vector2 = px.call(VoxelMapGeometry.point(zone.global_rect().get_center()))
		print("PIN ", name, " zone:", zone.zone_id, " ", point.x, " ", point.y)
	for node: Node in map.find_children("*", "Area2D", true, false):
		var passage := node as WorldPassageArea2D
		var portal: PortalDefinition = null if passage == null else GameContent.catalog().portal(passage.portal_id)
		if portal != null and portal.destination_map_id != portal.source_map_id:
			var point: Vector2 = px.call(VoxelMapGeometry.point(passage.global_position))
			print("PIN ", name, " door:", portal.destination_map_id, " ", point.x, " ", point.y)
	viewport.queue_free()
	view.process_mode = Node.PROCESS_MODE_INHERIT


## The arrow that stands on the sand table over the goal: a voxel arrow, lit like the places.
func _bake_arrow(path: String) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(180, 260)
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := WorldEnvironment.new()
	holder.environment = Environment.new()
	holder.environment.background_mode = Environment.BG_COLOR
	holder.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	holder.environment.ambient_light_color = SKY_COLOUR
	holder.environment.ambient_light_energy = 0.5
	viewport.add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOUR
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-26, -50, 0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 26.0
	camera.near = 1.0
	camera.far = 1200.0
	viewport.add_child(camera)
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(-21.213203, -26, -21.213203), Vector3.UP), Vector3(0, 7, 0) + Vector3(21.213203, 26, 21.213203).normalized() * 600.0)
	camera.current = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e8452a")
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = Color("d9452c")
	material.emission_energy_multiplier = 0.55
	var parts: Array[Array] = [[Vector3(0, 9.6, 0), Vector3(1.7, 8.0, 1.7)]]
	for layer: int in 6:
		var width: float = 0.6 + layer * 1.05
		parts.append([Vector3(0, 0.5 + layer * 1.0, 0), Vector3(width, 1.0, width)])
	for part: Array in parts:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.material_override = material
		box.position = part[0]
		box.scale = part[1]
		viewport.add_child(box)
	for _frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = viewport.get_texture().get_image()
	picture.get_region(picture.get_used_rect()).save_png(path)
