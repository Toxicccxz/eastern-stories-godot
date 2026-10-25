class_name WorldVoxelView
extends Node

## A 3D presentation of an existing physical map. It never moves actors, takes exits,
## grants items or changes a rule. Runtime bodies remain the single position authority.
const Person = preload("res://presentation/voxel/actors/voxel_person.gd")
const Crawler = preload("res://presentation/voxel/actors/voxel_crawler.gd")
const Snake = preload("res://presentation/voxel/actors/voxel_snake.gd")
const Flyer = preload("res://presentation/voxel/actors/voxel_flyer.gd")
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const VIEW_ROTATION_SECONDS: float = 0.6
const VIEW_SIDE_ANGLE: float = PI/4.0
const VIEW_RADIUS: float = 30.0
@export_file("*.json") var layout_path: String
var map: WorldMapController
var camera: Camera3D
var world: Node3D
var geometry: VoxelMapGeometry
var occlusion := VoxelOcclusion.new()
var layout: Dictionary
var lighting := VoxelLighting.new()
var night: bool = false
var left_view: bool = false
var actors: Dictionary[StringName, Node3D] = {}
var labels: Dictionary[StringName, Label3D] = {}
## The red marks over the heads of NPCs whose 2D body shows its AlertMark (进门一起上).
var alert_marks: Dictionary[StringName, Label3D] = {}
var objects: Dictionary[StringName, Node3D] = {}
var entrances: Dictionary[StringName, Dictionary] = {}
var shutters: Dictionary[StringName, Node3D] = {}
## The bobbing triangle over every exit (owner's map rule 2): a passage's points out of
## its room, a door's away from the side the player stands on.
var arrows: Dictionary[StringName, Node3D] = {}
var _arrow_clock: float = 0.0
var _built: bool = false
var _active: bool = false
var _old_modulate: Color = Color.WHITE
var _old_msaa: Viewport.MSAA = Viewport.MSAA_DISABLED
var _target: Vector3
var _offset := Vector3(21.213203,26,21.213203)
var _view_yaw: float = VIEW_SIDE_ANGLE
var _turn_from: float = VIEW_SIDE_ANGLE
var _turn_elapsed: float = VIEW_ROTATION_SECONDS
var _cutaway_left: bool = false
var _last_player: Vector2 = Vector2.INF
var _context_names: bool = false

func _ready() -> void:
	map = get_parent() as WorldMapController
	process_priority = -20

func _exit_tree() -> void:
	_deactivate()

func _process(delta: float) -> void:
	if map == null or map.player_body == null or not map.player_body.player_controlled:
		_deactivate()
		return
	if not _built:
		_build()
	if not _active:
		_activate()
	_advance_view_rotation(delta)
	_follow(delta)
	_sync_actors(delta)
	_sync_objects()
	geometry.sync_passages(map)
	_reveal_entrances()
	_bob_arrows(delta)
	_update_occlusion()
	lighting.advance(delta,VoxelMapGeometry.point(map.player_body.global_position))
	if geometry.foliage != null:
		geometry.foliage.advance(delta, _plant_contacts())
	geometry.ambience.night = lighting.amount
	geometry.ambience.advance(delta)

func _build() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	world = Node3D.new()
	world.name = "VoxelWorld"
	add_child(world)
	geometry = VoxelMapGeometry.new()
	world.add_child(geometry)
	geometry.make(map,layout)
	geometry.set_view_side(_cutaway_left)
	camera = Camera3D.new()
	# This camera is already smoothed in _process; engine physics interpolation would
	# interpolate its first projection from a stale transform during map handoff.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(layout.get("camera_size",24.0))
	camera.near = 0.1
	camera.far = 160.0
	world.add_child(camera)
	camera.position = _offset
	camera.look_at(Vector3.ZERO,Vector3.UP)
	_make_entrances()
	_make_shutters()
	for entry: Dictionary in geometry.occluders:
		occlusion.register(entry["node"])
	for shutter: Node3D in shutters.values():
		occlusion.register(shutter)
	lighting.build(world,occlusion,layout.get("indoor",false),layout.get("light",{}))
	lighting.set_night(night,true)
	_built = true

func _activate() -> void:
	_old_modulate = map.modulate
	map.modulate.a = 0.0
	_old_msaa = get_viewport().msaa_3d
	get_viewport().msaa_3d = Viewport.MSAA_4X
	(map.player_body.get_node("Camera2D") as Camera2D).enabled = false
	world.visible = true
	camera.current = true
	_target = VoxelMapGeometry.point(map.player_body.global_position,0.7)
	_active = true
	map.projected_view = true
	set_view_side(left_view,true)

func _update_movement_basis() -> void:
	var right := Vector2(camera.basis.x.x,camera.basis.x.z).normalized()
	var down := Vector2(camera.basis.z.x,camera.basis.z.z).normalized()
	map.player_body.movement_basis = Transform2D(right,down,Vector2.ZERO)

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	map.projected_view = false
	map.modulate = _old_modulate
	map.player_body.movement_basis = Transform2D.IDENTITY
	world.visible = false
	# Leaving by a passage removes the map: its camera has left the tree before this
	# view's _exit_tree, so restore unless another map's 3D view already took over.
	var viewport: Viewport = get_viewport()
	var other: Camera3D = null if viewport == null else viewport.get_camera_3d()
	if viewport != null and (other == null or other == camera):
		if camera.is_inside_tree():
			camera.current = false
		viewport.canvas_transform = Transform2D.IDENTITY
		viewport.msaa_3d = _old_msaa

func set_night(enabled: bool, immediate: bool = false) -> void:
	night = enabled
	if _built:
		lighting.set_night(enabled,immediate)

## Orbit between two fixed angles, sharing the same height and distance to the player.
## Nothing in the map, reach, collision or saved location rotates with the camera.
func set_view_side(left: bool, immediate: bool = false) -> void:
	left_view = left
	_turn_from = _view_yaw
	_turn_elapsed = 0.0
	# A new/reactivated map inherits the chosen side without replaying a stale turn.
	if immediate or not _active:
		_advance_view_rotation(VIEW_ROTATION_SECONDS)
		if _active:
			_follow(0.0)
			_update_occlusion()

func _advance_view_rotation(delta: float) -> void:
	if _turn_elapsed>=VIEW_ROTATION_SECONDS:
		return
	_turn_elapsed = minf(_turn_elapsed+delta,VIEW_ROTATION_SECONDS)
	var progress: float = smoothstep(0.0,1.0,_turn_elapsed/VIEW_ROTATION_SECONDS)
	_view_yaw = lerpf(_turn_from,-VIEW_SIDE_ANGLE if left_view else VIEW_SIDE_ANGLE,progress)
	_offset = Vector3(sin(_view_yaw)*VIEW_RADIUS,26,cos(_view_yaw)*VIEW_RADIUS)
	# Swap the cutaway when the camera crosses the centre, not when the button is hit.
	var near_left: bool = _view_yaw<0.0
	if near_left!=_cutaway_left:
		_cutaway_left = near_left
		if _built:
			geometry.set_view_side(near_left)

func _follow(delta: float) -> void:
	# Large changes are placements/arrivals; never pan across the whole map after restore.
	var at: Vector2 = map.player_body.global_position
	var wanted: Vector3 = VoxelMapGeometry.point(at,0.7)
	if not _last_player.is_finite() or at.distance_to(_last_player)>96:
		_target = wanted
	else:
		_target = _target.lerp(wanted,1.0-exp(-delta*8.0))
	_last_player = at
	camera.position = _target+_offset
	camera.look_at(_target,Vector3.UP)
	_update_movement_basis()
	# Reproject on resize; orientation stays fixed between explicit side switches.
	var zero: Vector2 = camera.unproject_position(Vector3.ZERO)
	var projection := Transform2D(
		camera.unproject_position(Vector3.RIGHT/VoxelMapGeometry.UNIT)-zero,
		camera.unproject_position(Vector3.BACK/VoxelMapGeometry.UNIT)-zero,zero)
	# A minimized/new viewport can briefly have no projectable area. Keep the last
	# valid transform rather than hand the UI an uninvertible canvas for that frame.
	if absf(projection.determinant())<0.000001:
		return
	map.view_ground = projection
	map.view_up = camera.unproject_position(Vector3.UP/VoxelMapGeometry.UNIT)-zero
	get_viewport().canvas_transform = map.view_ground

func _label(parent: Node3D, text: String, height: float = 2.2) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position.y = height
	label.font_size = 36
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 6
	label.modulate = Color("f0e6ce")
	parent.add_child(label)
	return label

func _sync_actors(delta: float) -> void:
	var hovered: StringName = pick_at(get_viewport().get_mouse_position()) if _context_names else &""
	var bodies: Array[WorldCharacterBody2D] = [map.player_body]
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body != null:
			bodies.append(body)
	var seen: Dictionary[StringName,bool] = {}
	for body: WorldCharacterBody2D in bodies:
		var id: StringName = body.character_id
		seen[id] = true
		if not actors.has(id):
			_make_actor(body)
		var actor: Node3D = actors[id]
		actor.visible = body.visible and body.is_visible_in_tree()
		var at: Vector2 = body.global_position
		var next: Vector3 = VoxelMapGeometry.point(at,0.02)
		var step: float = actor.position.distance_to(next)
		actor.position = next
		var model: Node3D = actor.get_child(0) as Node3D
		if model is Person or model is Crawler or model is Snake or model is Flyer:
			# Render frames may outnumber physics steps: a held direction must not flicker
			# between the walk and idle poses on the intervening frames.
			model.walking = (body.velocity.length_squared()>1.0 if body == map.player_body else step>0.003) and step<1.5
		var direction: float = atan2(body.facing.x,body.facing.y)
		model.rotation.y = lerp_angle(model.rotation.y,direction,minf(1.0,delta*17))
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(id) if body != map.player_body else null
		var life: CharacterRuntimeLifeStatus.Value = map.player_runtime().life_status if body == map.player_body else (npc.life_status if npc != null else CharacterRuntimeLifeStatus.Value.ACTIVE)
		var unconscious: bool = life == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
		model.rotation.z = PI/2 if unconscious else 0.0
		var name_label := body.get_node_or_null("NameLabel") as Label
		if name_label != null:
			var label: Label3D = labels[id]
			label.text = name_label.text
			var color: Color = name_label.get_theme_color("font_color")
			color.a *= float(label.get_meta("name_alpha",1.0))
			label.modulate = color
			var reveal_distance: float = float(label.get_meta("name_distance",-1.0))
			label.visible = reveal_distance<0 or at.distance_squared_to(map.player_body.global_position)<=reveal_distance*reveal_distance or id==hovered or id==map.selected_character_id()
		var mark := body.get_node_or_null("AlertMark") as Label
		var marked: bool = mark != null and mark.visible
		if marked and not alert_marks.has(id):
			# Over the name, whatever the body's size (a beast's name sits lower or higher).
			var alert: Label3D = _label(actor, mark.text, (labels[id].position.y if labels.has(id) else 2.2) + 0.55)
			alert.font_size = 60
			alert.modulate = mark.get_theme_color("font_color")
			alert_marks[id] = alert
		if alert_marks.has(id):
			alert_marks[id].visible = marked
	for id: StringName in actors.keys():
		if not seen.has(id):
			actors[id].queue_free()
			actors.erase(id)
			labels.erase(id)
			alert_marks.erase(id)

func _make_actor(body: WorldCharacterBody2D) -> void:
	var actor := Node3D.new()
	world.add_child(actor)
	actors[body.character_id] = actor
	var look: Dictionary = layout.get("actors",{}).get("default",{})
	if body != map.player_body:
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(body.character_id)
		if npc != null:
			look = layout.get("actors",{}).get(String(NpcDefinition.unnamed_id(npc.definition().definition_id)),look)
	else:
		look = {"coat":"397c87"}
	var model: Node3D
	var size: float = float(look.get("scale",1.0))
	var body_kind: String = String(look.get("body",""))
	var crawler: bool = body_kind in ["crawler","snake","flyer"]
	if body_kind=="crawler":
		model = Crawler.new()
		model.scale = Vector3.ONE*size
		model.colors = look.get("colors",model.colors)
		model.spots = String(look.get("spots",model.spots))
		actor.add_child(model)
	elif body_kind=="snake":
		model = Snake.new()
		model.scale = Vector3.ONE*size
		model.colors = look.get("colors",model.colors)
		model.belly = String(look.get("belly",model.belly))
		model.bands = String(look.get("bands",""))
		model.crest = String(look.get("crest",""))
		model.rear = look.get("rear",false)
		actor.add_child(model)
	elif body_kind=="flyer":
		model = Flyer.new()
		model.scale = Vector3.ONE*size
		model.wings = look.get("wings",model.wings)
		model.hover = float(look.get("hover",model.hover))
		actor.add_child(model)
	elif look.get("animal",false):
		model = Node3D.new()
		model.scale = Vector3.ONE*size
		actor.add_child(model)
		var fur: Array = look.get("fur",["a88a60","846747","725638"])
		var s := Shapes.new()
		s.box(model,Vector3(0,0.45,0),Vector3(0.5,0.45,0.95),fur[0])
		s.box(model,Vector3(0,0.72,0.5),Vector3(0.4,0.4,0.42),fur[1])
		for x: float in [-0.18,0.18]:
			for z: float in [-0.3,0.3]:
				s.box(model,Vector3(x,0.18,z),Vector3(0.12,0.36,0.13),fur[2])
		if look.get("tail",false):
			s.tilted_box(model,Vector3(0,0.34,-0.82),Vector3(0.08,0.08,0.78),fur[1],Vector3(-0.35,0,0))
		s.flush()
	else:
		model = Person.new()
		model.coat = look.get("coat","817755")
		model.hat = look.get("hat",false)
		actor.add_child(model)
	var low: bool = crawler or look.get("animal",false)
	var label_height: float = (0.55*size+0.35 if crawler else 0.4+0.9*size) if low else 2.2
	if body_kind=="flyer":
		label_height = float(look.get("hover",1.1))*size+0.5
	labels[body.character_id] = _label(actor,"",label_height)
	var label: Label3D = labels[body.character_id]
	label.font_size = int(look.get("name_font_size",36))
	label.set_meta("name_alpha",float(look.get("name_alpha",1.0)))
	label.set_meta("name_distance",float(look.get("name_distance",-1.0)))
	_context_names = _context_names or float(look.get("name_distance",-1.0))>=0
	actor.set_meta("pick_height",(0.5*size if crawler else 1.15*size) if low else 1.85)
	actor.set_meta("pick_width",maxf(10,20*size) if low else 20.0)

func _sync_objects() -> void:
	var seen: Dictionary[StringName,bool] = {}
	for id: StringName in map.floor_items.floor_item_ids():
		var item: WorldFloorItemView = map.floor_items.floor_item_view(id)
		if item != null:
			_object(id,item.global_position,item.display_name,false)
			seen[id] = true
	for corpse: CorpseState in map.corpses.corpse_states():
		var view: CombatSliceCorpseView = map.corpses.corpse_view_for(corpse.corpse_item_instance_id)
		if view != null and map.corpses.corpse_is_live_in_world(corpse):
			_object(corpse.corpse_item_instance_id,view.global_position,map.corpses.corpse_name(corpse),true)
			seen[corpse.corpse_item_instance_id] = true
	for id: StringName in objects.keys():
		if not seen.has(id):
			objects[id].queue_free()
			objects.erase(id)
	for id: StringName in shutters:
		shutters[id].visible = not map.doors_by_id[id].is_open()

func _object(id: StringName, at: Vector2, title: String, corpse: bool) -> void:
	if not objects.has(id):
		var node := Node3D.new()
		world.add_child(node)
		var s := Shapes.new()
		# A floor item may have a look of its own (layout `items`: item definition -> look),
		# drawn by the props files; it goes when the item goes (a buried skeleton).
		var content: ItemContentDefinition = null if corpse else map.floor_items.floor_item_content(map.floor_items.floor_item_view(id))
		var look: Dictionary = {} if content == null else layout.get("items",{}).get(String(content.item_definition_id),{})
		if look.is_empty() or not geometry.draw_look(s,node,look):
			s.box(node,Vector3(0,0.15,0),Vector3(0.75,0.3,1.45) if corpse else Vector3(0.4,0.3,0.35),"6b6860" if corpse else "b5a079")
		s.flush()
		_label(node,title,0.7).name = "Title"
		objects[id] = node
	objects[id].position = VoxelMapGeometry.point(at)
	# A corpse's name changes as it decays (obj/corpse.c).
	var label := objects[id].get_node_or_null("Title") as Label3D
	if label != null and label.text != title:
		label.text = title

func _make_entrances() -> void:
	for node: Node in map.find_children("*","Area2D",true,false):
		var passage := node as WorldPassageArea2D
		if passage == null:
			continue
		var portal: PortalDefinition = GameContent.catalog().portal(passage.portal_id)
		var zone: ZoneDefinition = null if portal == null else GameContent.catalog().zone(portal.destination_zone_id)
		if zone == null:
			continue
		var settings: Dictionary = layout.get("entrances",{}).get(String(passage.portal_id),{})
		var title: String = tr(String(settings.get("title",zone.display_name)))
		var marker := Node3D.new()
		marker.position = VoxelMapGeometry.point(passage.global_position)
		world.add_child(marker)
		var label: Label3D = _label(marker,title+"  ›",float(settings.get("label_height",1.4)))
		label.modulate = Color("efd28a")
		label.font_size = 30
		var s := Shapes.new()
		if settings.get("floor_guides",true):
			for x: float in [-0.65,0.65]:
				s.box(marker,Vector3(x,0.035,0),Vector3(0.1,0.04,1.1),"d5ba7e")
		s.flush()
		entrances[passage.portal_id] = {"passage":passage,"node":marker,"label":label}
		var arrow: Node3D = _arrow(marker,_outward(passage,portal))
		arrows[passage.portal_id] = arrow
	for id: StringName in map.doors_by_id:
		var door: WorldDoor = map.doors_by_id[id]
		var holder := Node3D.new()
		holder.position = VoxelMapGeometry.point(door.wall_shape().global_position)
		world.add_child(holder)
		arrows[id] = _arrow(holder,Vector2.ZERO)
		arrows[id].set_meta("door",true)

## The way the exit leads: its original command's compass direction (diagonals too);
## for a verb without one (stairs, `enter`), across the passage's thin side, away from
## the middle of the room it belongs to.
func _outward(passage: WorldPassageArea2D, portal: PortalDefinition) -> Vector2:
	var shaped: Vector2 = _shape_outward(passage)
	var compass: Vector2 = VoxelMapGeometry.compass(portal.legacy_command)
	var settings: Dictionary = layout.get("entrances",{}).get(String(portal.portal_id),{})
	if settings.has("arrow"):
		var fixed: Array = settings["arrow"]
		return Vector2(float(fixed[0]),float(fixed[1])).normalized()
	# The command's compass unless the painted way out goes off another way (an "east"
	# exit drawn at the top of a north-south road): then the way the player walks out.
	return compass if compass != Vector2.ZERO and compass.dot(shaped) > 0.0 else shaped

func _shape_outward(passage: WorldPassageArea2D) -> Vector2:
	var at: Vector2 = passage.global_position
	var shape := passage.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var across: Vector2 = Vector2.DOWN
	if shape != null and shape.shape is RectangleShape2D:
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		across = Vector2.RIGHT if size.x < size.y else Vector2.DOWN
	var room: Vector2 = at
	var nearest: float = INF
	for node: Node in map.find_children("*","Area2D",true,false):
		var zone := node as WorldPhysicalZoneArea2D
		if zone == null:
			continue
		var rect: Rect2 = zone.global_rect()
		var gap: float = 0.0 if rect.has_point(at) else rect.get_center().distance_to(at)
		if gap < nearest:
			nearest = gap
			room = rect.get_center()
	var side: float = signf((at-room).dot(across))
	return across*(side if side != 0.0 else 1.0)

func _arrow(parent: Node3D, direction: Vector2) -> Node3D:
	var arrow := Node3D.new()
	arrow.set_meta("direction",direction)
	parent.add_child(arrow)
	var s := Shapes.new()
	# Flat, so it reads the same from either fixed angle; the wide row trails, the tip leads.
	for row: int in 5:
		s.box(arrow,Vector3(0,0,-0.4+row*0.2),Vector3(0.95-row*0.21,0.12,0.2),"f2a43a")
	s.flush()
	# A warm amber of its own: readable on pale ground by day and glowing by night.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("f2a43a")
	glow.emission_enabled = true
	glow.emission = Color("e8902a")
	glow.emission_energy_multiplier = 0.55
	for mesh: Node in arrow.find_children("*","GeometryInstance3D",true,false):
		(mesh as GeometryInstance3D).material_override = glow
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return arrow

func _bob_arrows(delta: float) -> void:
	_arrow_clock += delta
	var player: Vector2 = map.player_body.global_position
	for id: StringName in arrows:
		var arrow: Node3D = arrows[id]
		var direction: Vector2 = arrow.get_meta("direction")
		var near: bool
		if direction == Vector2.ZERO:
			var door: WorldDoor = map.doors_by_id[id]
			var wall: CollisionShape2D = door.wall_shape()
			var size: Vector2 = (wall.shape as RectangleShape2D).size
			var across: Vector2 = Vector2.RIGHT if size.x < size.y else Vector2.DOWN
			var side: float = signf((wall.global_position-player).dot(across))
			direction = across*(side if side != 0.0 else 1.0)
			near = wall.global_position.distance_to(player) < 360.0
		else:
			near = (arrow.get_parent() as Node3D).visible
		arrow.visible = near
		arrow.rotation.y = atan2(direction.x,direction.y)
		# A door's floats over its lintel, clear of the shut leaf; a passage's over the floor.
		arrow.position.y = (2.75 if arrow.get_meta("door",false) else 0.8)+sin(_arrow_clock*3.2)*0.14

func _make_shutters() -> void:
	for id: StringName in map.doors_by_id:
		var door: WorldDoor = map.doors_by_id[id]
		var collision: CollisionShape2D = door.wall_shape()
		var rect := collision.shape as RectangleShape2D
		var node := Node3D.new()
		node.position = VoxelMapGeometry.point(collision.global_position)
		world.add_child(node)
		var s := Shapes.new()
		var size := Vector3(rect.size.x/VoxelMapGeometry.UNIT,2.2,rect.size.y/VoxelMapGeometry.UNIT)
		var look: Dictionary = layout.get("door_looks",{}).get(String(id),{})
		if not look.is_empty():
			look = look.duplicate()
			look["size"] = look.get("size",[rect.size.x,rect.size.y])
			geometry.draw_look(s,node,look)
		elif geometry.indoor:
			_room_door(node,s,size)
		else:
			s.box(node,Vector3(0,1.1,0),size,"9d4d39")
		s.flush()
		shutters[id] = node

## An indoor 房门: a frame that always stands in the doorway, even in a cut-away wall,
## and a panelled leaf (the shutter node) that shows only while the door is shut.
func _room_door(leaf: Node3D, s: Shapes, size: Vector3) -> void:
	var across: bool = size.x>=size.z
	var width: float = size.x if across else size.z
	var frame := Node3D.new()
	frame.position = leaf.position
	frame.rotation.y = 0.0 if across else PI/2
	world.add_child(frame)
	leaf.rotation.y = frame.rotation.y
	for x: float in [-width/2+0.07,width/2-0.07]:
		s.box(frame,Vector3(x,1.2,0),Vector3(0.14,2.4,0.42),"5c3f2b")
	s.box(frame,Vector3(0,2.44,0),Vector3(width,0.16,0.46),"6e4d37")
	s.box(frame,Vector3(0,0.02,0),Vector3(width-0.14,0.04,0.44),"7a573c")
	s.box(leaf,Vector3(0,1.1,0),Vector3(width-0.18,2.2,0.16),"8f5a3a")
	for y: float in [0.62,1.52]:
		s.box(leaf,Vector3(0,y,0),Vector3(width-0.42,0.66,0.2),"a46a44")
	s.box(leaf,Vector3(width*0.28,1.1,0),Vector3(0.07,0.18,0.24),"c9a35e")

func _reveal_entrances() -> void:
	for id: StringName in entrances:
		var entry: Dictionary = entrances[id]
		var passage: WorldPassageArea2D = entry["passage"]
		var distance: float = passage.global_position.distance_to(map.player_body.global_position)
		(entry["node"] as Node3D).visible = passage.is_open() and distance<500.0

func _plant_contacts() -> PackedVector3Array:
	var contacts := PackedVector3Array()
	var player: Vector3 = VoxelMapGeometry.point(map.player_body.global_position)
	contacts.append(player)
	for id: StringName in actors:
		if id != map.player_body.character_id and actors[id].visible and actors[id].position.distance_squared_to(player)<400:
			contacts.append(actors[id].position)
	return contacts

func _update_occlusion() -> void:
	var targets := PackedVector4Array()
	var visible: Rect2 = get_viewport().get_visible_rect().grow(64)
	var player: Vector3 = VoxelMapGeometry.point(map.player_body.global_position)
	var nearby: Array[Node3D] = []
	for actor: Node3D in actors.values():
		if actor.visible and actor.position.distance_squared_to(player)<=196:
			nearby.append(actor)
	nearby.sort_custom(func(a: Node3D,b: Node3D) -> bool: return a.position.distance_squared_to(player)<b.position.distance_squared_to(player))
	for actor: Node3D in nearby:
		if targets.size() >= VoxelOcclusion.LIMIT:
			break
		var model := actor.get_child(0) as Node3D
		# Follow the body's middle even when it is lying unconscious; animals are lower.
		var centre: Vector3 = model.to_global(Vector3.UP*(1.0 if model is Person else 0.5))
		if visible.has_point(camera.unproject_position(centre)):
			targets.append(Vector4(centre.x, centre.y, centre.z, 1.75))
	# The player's opening reveals an approached door too. An empty threshold must
	# not punch an independent ghost patch into a roof without a person behind it.
	occlusion.update(camera, targets)

## A projected click uses the same reach and permission checks as E and the old sprites.
func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var mouse := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	if (mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed) and (touch == null or not touch.pressed):
		return
	var at: Vector2 = mouse.position if mouse != null else touch.position
	var selected: StringName = pick_at(at)
	if not selected.is_empty():
		map.selection.on_thing_clicked(selected)
	# Do not pick the hidden flat sprite underneath a projected figure.
	get_viewport().set_input_as_handled()

func pick_at(at: Vector2) -> StringName:
	var nearest: float = INF
	var picked: StringName = &""
	for id: StringName in actors:
		var actor: Node3D = actors[id]
		if id == map.player_body.character_id or not actor.visible:
			continue
		var feet: Vector2 = camera.unproject_position(actor.position)
		var head: Vector2 = camera.unproject_position(actor.position+Vector3.UP*float(actor.get_meta("pick_height",1.85)))
		var width: float = float(actor.get_meta("pick_width",20.0))
		var bounds := Rect2(head-Vector2(width,8),Vector2(width*2,feet.y-head.y+16))
		if bounds.has_point(at) and at.distance_to(head)<nearest:
			nearest = at.distance_to(head)
			picked = id
	if not picked.is_empty():
		return picked
	for thing: WorldNearbyThing in map.selection.nearby():
		var focus: WorldFocus = map.selection.focus_of(thing,"")
		if focus != null and map.screen_position(focus.at()).distance_to(at)<30:
			return thing.id
	return &""
