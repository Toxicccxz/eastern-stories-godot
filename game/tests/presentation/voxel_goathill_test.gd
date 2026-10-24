extends RefCounted

const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const Existing = preload("res://tests/presentation/voxel_gameplay_test.gd")
var assertions: int = 0
var failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary:
	var session: WorldSessionController = Work.create_session(tree)
	await _frames(tree,3)
	var furnishing_check := Existing.new()
	for entry: Array in [[&"goathill.mroad1",&"goathill.mroad1.snow_entry"],[&"goathill.cavern1",&"goathill.cavern1.canyon_entry"],[&"goathill.temple1",&"goathill.temple1.mroad3_entry"]]:
		var map: WorldMapController = MapPlaces.enter(session,entry[0],entry[1])
		_check(map!=null,"original arrival is usable: "+String(entry[0]))
		if map==null:
			continue
		await _frames(tree,3)
		var view := map.get_node("MapView") as WorldVoxelView
		_check(view!=null and map.projected_view and view.camera.current,"voxel camera takes over: "+String(map.map_id()))
		_check(view.geometry.unknown_kinds.is_empty(),"every authored prop is drawn: "+String(map.map_id()))
		var def: MapDefinition = GameContent.catalog().map(map.map_id())
		furnishing_check._check_furnishings(load(def.scene_path) as PackedScene,String(map.map_id()))
		var start: Vector2 = map.player_body.global_position
		for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
			var at: Vector2 = MapPlaces.zone_spot(map,zone.zone_id)
			_check(at.is_finite() and not MapRoute.path(map,start,at).is_empty(),"a body can reach "+String(zone.zone_id))
		for npc: NpcRuntimeState in map.npc_runtimes():
			var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
			var reach: float = WorldMapSelection.NEARBY_REACH
			var at: Vector2 = MapPlaces.spot(map,npc.world_location().zone_id,body.global_position,reach)
			_check(at.is_finite() and at.distance_to(body.global_position)<=reach and not MapRoute.path(map,start,at).is_empty(),"NPC stays within accessible interaction reach: "+String(npc.spawn_point_id))
		for id: StringName in view.entrances:
			var arrow := view.entrances[id]["arrow"] as MeshInstance3D
			var previous: float = arrow.position.y
			view._entrance_clock += 0.3
			view._reveal_entrances()
			_check(arrow.mesh!=null and not is_equal_approx(previous,arrow.position.y),"exit has a bobbing triangle: "+String(id))
		for left: bool in [false,true]:
			view.set_view_side(left,true)
			_check(view.geometry.side_walls[1].visible==left and view.geometry.side_walls[0].visible!=left,"rock cutaway follows the fixed view side")
			for night: bool in [false,true]:
				session.set_process(false)
				var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
				view.set_night(night,true)
				view._process(0.1)
				_check(GameSaveJsonCodec.encode(Work.capture(session)).text==saved,"light, wind, crawling and camera leave saves and gameplay RNG unchanged")
				session.set_process(true)
		if map.map_id()==&"goathill.caverns":
			for zone: StringName in [&"goathill.cavern2",&"goathill.cavern3",&"goathill.cavern2",&"goathill.cavern1",&"goathill.cavern4",&"goathill.cavern1"]:
				_check(await MapPlaces.drive_to_zone(tree,map,zone),"walk the tunnels by map direction: "+String(zone))
			_check(await MapPlaces.take_passage(tree,map,&"goathill.cavern1.west"),"walk back out to the canyon")
		elif map.map_id()==&"goathill.temple_house":
			_check(await MapPlaces.drive_to_zone(tree,map,&"goathill.temple1"),"walk into the shrine room")
			_check(await MapPlaces.take_passage(tree,map,&"goathill.temple1.west"),"west door remains clear in the left voxel view")
	assertions += furnishing_check.assertions
	failures.append_array(furnishing_check.failures)
	session.free()
	await _frames(tree,2)
	return {"assertions":assertions,"failures":failures}

func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame

func _check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
