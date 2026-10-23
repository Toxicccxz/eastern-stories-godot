extends RefCounted

const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const Still = preload("res://tests/runtime/snow_south_road_test.gd")
const Interiors = preload("res://tests/presentation/voxel_interiors_test.gd")
var assertions: int = 0
var failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree,4)
	var map := session.active_map() as WorldMapController
	var view := map.get_node("MapView") as WorldVoxelView
	var button := session.shared_ui().find_child("ViewSide",true,false) as VoxelViewSideButton
	var waiter: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"snow.inn.main_floor.inn.waiter.1")
	_check(map.place_player(&"snow.inn.main_floor",Vector2(0,-105)),"place within waiter reach")
	await _frames(tree,3)
	# Feed render deltas explicitly: headless speed must not skip the middle of a turn.
	view.set_process(false)
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	var before: Vector2 = map.player_body.global_position
	var focus: Vector3 = VoxelMapGeometry.point(before,0.7)
	var previous: float = _yaw(view)
	Interiors.new()._click(tree,button)
	_check(button.left_view and is_equal_approx(_yaw(view),previous),"click starts a turn without jumping to its destination")
	for i: int in 6:
		view._process(0.1)
		var angle: float = _yaw(view)
		_check(angle<previous and angle>=-PI/4.0-0.001,"left turn advances without overshoot, sample %d" % i)
		var offset: Vector3 = view.camera.position-focus
		_check(absf(Vector2(offset.x,offset.z).length()-30.0)<0.001 and absf(offset.y-26.0)<0.001,"orbit keeps distance and elevation, sample %d" % i)
		_check(view.geometry.side_walls[1].visible==(angle<0.0),"cutaway follows current camera side, sample %d" % i)
		_check_projection(map,view,waiter)
		previous = angle
	_check(absf(_yaw(view)+PI/4.0)<0.001,"turn settles at the exact left preset")
	view._process(1.0)
	_check(is_equal_approx(_yaw(view),previous),"camera remains fixed after the animation")
	_check(map.player_body.global_position==before and GameSaveJsonCodec.encode(Work.capture(session)).text==saved,"a full animated turn changes no physical position, save state or gameplay RNG")
	# Reverse an in-progress turn, starting at its current position rather than a preset.
	Interiors.new()._click(tree,button)
	view._process(0.2)
	var partial: float = _yaw(view)
	_check(partial>-PI/4.0 and partial<0.0,"reverse setup is between the two presets")
	Interiors.new()._click(tree,button)
	_check(is_equal_approx(_yaw(view),partial),"a second click does not snap the camera")
	view._process(0.3)
	_check(_yaw(view)<partial and _yaw(view)>-PI/4.0,"a repeated click turns smoothly back from the current angle")
	view._process(0.3)
	_check(absf(_yaw(view)+PI/4.0)<0.001,"reversal reaches the requested side")
	# A handoff during a turn inherits its destination, including on a cached return.
	Interiors.new()._click(tree,button)
	view._process(0.2)
	view.set_process(true)
	session.set_process(true)
	var def: MapDefinition = GameContent.catalog().map(MapPlaces.map_of(&"snow.bank"))
	var bank := MapPlaces.enter(session,&"snow.bank",def.entry_spawn_id)
	await _frames(tree,4)
	var bank_view := bank.get_node("MapView") as WorldVoxelView
	_check(not bank_view.left_view and absf(_yaw(bank_view)-PI/4.0)<0.001,"new map immediately inherits the chosen destination")
	def = GameContent.catalog().map(&"snow.inn")
	map = MapPlaces.enter(session,&"snow.inn.main_floor",def.entry_spawn_id)
	await _frames(tree,4)
	view = map.get_node("MapView") as WorldVoxelView
	_check(absf(_yaw(view)-PI/4.0)<0.001,"returning to a cached map cannot resume an old partial turn")
	session.free()
	await _frames(tree,2)
	return {"assertions":assertions,"failures":failures}

func _check_projection(map: WorldMapController, view: WorldVoxelView, waiter: WorldCharacterBody2D) -> void:
	var world_at := Vector2(40,-50)
	var projected: Vector2 = view.camera.unproject_position(VoxelMapGeometry.point(world_at))
	_check(projected.distance_to(map.view_ground*world_at)<0.01,"ground canvas follows intermediate camera angle")
	var basis: Transform2D = map.player_body.movement_basis
	var right: Vector2 = map.view_ground.basis_xform(basis.x)
	var down: Vector2 = map.view_ground.basis_xform(basis.y)
	_check(right.x>0 and absf(right.y)<0.001 and down.y>0 and absf(down.x)<0.001,"movement stays screen-relative while rotating")
	var actor: Node3D = view.actors[waiter.character_id]
	_check(view.pick_at(view.camera.unproject_position(actor.position+Vector3.UP))==waiter.character_id,"NPC picking follows intermediate camera angle")

func _yaw(view: WorldVoxelView) -> float:
	return atan2(view.camera.basis.z.x,view.camera.basis.z.z)

func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
