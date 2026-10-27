extends RefCounted

const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const Still = preload("res://tests/runtime/snow_south_road_test.gd")
const Existing = preload("res://tests/presentation/voxel_gameplay_test.gd")
var assertions: int = 0
var failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary:
	var initial_msaa: Viewport.MSAA = tree.root.msaa_3d
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree,4)
	var hud: SharedGameplayUI = session.shared_ui()
	var button := hud.find_child("ViewSide",true,false) as VoxelViewSideButton
	_check(button!=null and button.is_visible_in_tree(),"the view button is shown in the voxel inn")
	_check(hud.find_child("DayNight",true,false)==null,"the HUD has no day/night button: 昼夜 is a setting (DECISIONS「昼夜」)")
	var inn := session.active_map() as WorldMapController
	var view := inn.get_node("MapView") as WorldVoxelView
	var before: Vector2 = inn.player_body.global_position
	_click(tree,button)
	await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS+0.05).timeout
	_check(button.left_view and view.left_view and before==inn.player_body.global_position,"HUD click changes side without relocating the player")
	_check(absf(view.camera.basis.z.x+view.camera.basis.z.z)<0.001,"left camera has equal horizontal axes, facing from -45 degrees")
	var waiter: WorldCharacterBody2D = inn.runtime_body_for_spawn_point(&"snow.inn.main_floor.inn.waiter.1")
	_check(inn.place_player(&"snow.inn.main_floor",Vector2(0,-105)),"stand within waiter reach for projection check")
	await _frames(tree,4)
	var at: Vector2 = view.camera.unproject_position(view.actors[waiter.character_id].position+Vector3.UP)
	_check(view.pick_at(at)==waiter.character_id,"left projection still picks the original waiter")
	# The inn's life (room_life.json inn_hall): every table has something left on it, its walls
	# something hung on them.
	var tables: Array[Dictionary] = view.geometry.life._tables
	_check(view.geometry.life.rooms.has(&"snow.inn.main_floor") and tables.size()==6 and tables.all(func(t: Dictionary) -> bool: return t.has("set")),"the inn's six tables are each left with a meal, wine or tea")
	_check(view.geometry.mounted_props.size()>6,"the inn's walls have things hung on them: %d" % view.geometry.mounted_props.size())
	var furnishings := Existing.new()
	for zone_id: StringName in [&"snow.bank",&"snow.smithy",&"snow.herbshop",&"snow.postoffice",&"snow.workplace",&"snow.hockshop",&"snow.school2",&"snow.temple",&"snow.school",&"snow.secret_storage"]:
		var def: MapDefinition = GameContent.catalog().map(MapPlaces.map_of(zone_id))
		furnishings._check_furnishings(load(def.scene_path) as PackedScene,String(def.map_id))
		var map := MapPlaces.enter(session,zone_id,def.entry_spawn_id)
		_check(map!=null,"enter "+String(zone_id))
		await _frames(tree,3)
		view = map.get_node("MapView") as WorldVoxelView
		_check(map.projected_view and view.camera.current and view.left_view,"left view preference follows handoff to "+String(zone_id))
		_check(view.geometry.unknown_kinds.is_empty(),"all furnishings render in %s: %s" % [zone_id,view.geometry.unknown_kinds])
		_check(not view.geometry.life.rooms.is_empty(),"%s's rooms are lived in (RoomLife)" % zone_id)
		if zone_id in [&"snow.school2",&"snow.herbshop"]:
			_check(view.geometry.occluders.size()>3,"large new furnishings participate in local actor reveal")
		_check(await MapPlaces.drive_to_zone(tree,map,zone_id),"walk from entry to the interior of "+String(zone_id))
		# Leave room to either side of the player's body (the mill stands at the centre).
		var clear: Vector2 = _clear_floor(map,zone_id)
		_check(await MapPlaces.drive(tree,map,clear),"walk to clear floor for both screen-direction checks in "+String(zone_id))
		for left: bool in [false,true]:
			_click(tree,button)
			await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS+0.05).timeout
			_check(view.left_view==left and view.geometry.side_walls[1].visible==left and view.geometry.side_walls[0].visible!=left,"near wall cutaway swaps with camera in "+String(zone_id))
			var start: Vector2 = map.player_body.global_position
			Input.action_press("move_right")
			await _frames(tree,8)
			MapPlaces.release()
			var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position-start)
			_check(moved.x>4 and absf(moved.y)<2,"D walks screen-right from either side in "+String(zone_id))
			_check(map.place_player(zone_id,start),"return to clear floor in "+String(zone_id))
			await _frames(tree,2)
		if zone_id==&"snow.school2":
			await _check_hidden_floor(tree,session,map,view)
	# 室内生活气息 B + C: 绮云镇, 水烟阁, 老松寨's hall, the 土地庙 and 青石村's 石室. Every room
	# with a life is worn where feet go and has something hung on its walls; every furnishing
	# the painter placed stands on its blocked box; no prop kind is unknown.
	# TEST-ONLY: the bandits of 老松寨's hall and the 土地庙 would notice the room and start a fight
	# that holds the world; out of the way (oldpine_keep_caves_test and goathill_test meet them).
	for other: WorldMapController in session.world_maps():
		if other.map_id() in [&"oldpine.keep_hall",&"goathill.temple_house"]:
			for npc: NpcRuntimeState in other.npc_runtimes():
				other.npcs.vanish(npc)
	for zone_id: StringName in [&"cloud.biaoju",&"cloud.bookstore",&"cloud.butchery",&"cloud.drugstore",&"cloud.duchang",&"cloud.duchang2",
			&"cloud.woodboxy",&"cloud.jiyuan",&"cloud.jiyuan2",&"cloud.rich",&"cloud.marry_room",&"cloud.monky",&"cloud.tailory",&"cloud.tearoom",
			&"cloud.tearoom2",&"cloud.weapony",&"cloud.zaihuoy",&"waterfog.entrance",&"waterfog.west_2f",&"oldpine.outdoor.keep_hall",
			&"goathill.temple1",&"green.stoneroom"]:
		var def: MapDefinition = GameContent.catalog().map(MapPlaces.map_of(zone_id))
		furnishings._check_furnishings(load(def.scene_path) as PackedScene,String(def.map_id))
		var map := MapPlaces.enter(session,zone_id,def.entry_spawn_id)
		if map == null:
			# A map entered in another of its rooms (the coffin shop behind the yard).
			for other: ZoneDefinition in GameContent.catalog().zones_for_map(def.map_id):
				map = MapPlaces.enter(session,other.zone_id,def.entry_spawn_id)
				if map != null:
					break
		_check(map!=null,"enter "+String(zone_id))
		if map == null:
			continue
		await _frames(tree,3)
		view = map.get_node("MapView") as WorldVoxelView
		_check(view.geometry.unknown_kinds.is_empty(),"all furnishings render in %s: %s" % [zone_id,view.geometry.unknown_kinds])
		var specs: Dictionary = map.get_node("RoomLife").get_meta("rooms")
		for room: String in specs:
			var id := StringName(room)
			_check(view.geometry.life.rooms.has(id),"%s is lived in (RoomLife)" % room)
			_check(view.geometry.life.worn_cells.get(id,0)>0,"%s's floor is worn where people walk: %d cells" % [room,view.geometry.life.worn_cells.get(id,0)])
			_check(view.geometry.life.hung.get(id,0)>0,"%s has things hung on its walls: %d" % [room,view.geometry.life.hung.get(id,0)])
		if zone_id==&"cloud.tearoom":
			_check(view.geometry.ambience._falling.size()>=8 and view.geometry.ambience._motes.size()>=4,"香茗坊: steam off the tea stove, moths round a lamp")
		if zone_id==&"green.stoneroom":
			_check(view.geometry.life.rooms.size()==1,"石室: only the room its text describes has a life (大厅 and 外室 keep theirs: 一尘不染, nothing else)")
	# Every preset's pieces and hangings are kinds some props file draws (a misspelt kind would
	# otherwise leave a silent gap in every room of that use). Drawn under the last view, out of
	# sight, and freed with it: a piece's smoke or flame is the view's ambience's until then.
	var presets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VoxelLife.PRESETS))
	var holder := Node3D.new()
	holder.visible = false
	view.add_child(holder)
	for use: String in presets["uses"]:
		var spec: Dictionary = presets["uses"][use]
		for piece: Dictionary in spec.get("pieces",[]):
			var node := Node3D.new()
			holder.add_child(node)
			_check(view.geometry.draw_look(view.geometry.shapes,node,piece.duplicate(true)),"%s's %s is a known piece" % [use,piece["kind"]])
		for name: String in spec.get("hangings",[]):
			var prop: Dictionary = {"kind":name.get_slice(":",0),"size":[48,16],"wall_mounted":true,"seed":1}
			if VoxelLife.HANGING_KINDS.has(prop["kind"]):
				prop.merge(VoxelLife.HANGING_KINDS[prop["kind"]],true)
			var node := Node3D.new()
			holder.add_child(node)
			_check(view.geometry.draw_look(view.geometry.shapes,node,prop),"%s's %s is a known hanging" % [use,name])
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	# Both the saved state and gameplay RNG are unchanged by a camera or light toggle.
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	_click(tree,button)
	view.set_night(true,true)
	view._follow(0)
	view._update_occlusion()
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text==saved,"view and night toggles change no saved values or RNG")
	session.set_process(true)
	# Leaving this region still restores the unchanged 2D fallback.
	var fallback: MapDefinition = GameContent.catalog().map(&"canyon.pass")
	if fallback!=null:
		var map := MapPlaces.enter(session,&"canyon.canyon1",fallback.entry_spawn_id)
		await _frames(tree,3)
		_check(map!=null and not map.projected_view and not button.visible,"unconverted regions keep their 2D presentation")
		_check(tree.root.get_camera_3d()==null and tree.root.msaa_3d==initial_msaa,"2D handoff restores viewport camera and MSAA")
	session.free()
	await _frames(tree,2)
	return {"assertions":assertions,"failures":failures}

func _check_hidden_floor(tree: SceneTree, session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
	var entry: Dictionary = view.geometry.passage_props[0]
	_check(not (entry["node"] as Node3D).visible and (entry["cover"] as Node3D).visible,"closed hidden passage shows floor, not stairs")
	_check(await MapPlaces.drive_to_zone(tree,map,&"snow.weapon_storage"),"weapon room remains reachable")
	var shelf: StringName = &"snow.weapon_storage.landmark.shelf"
	_check(map.select_landmark(shelf),"the empty shelf remains selectable")
	for i: int in 3:
		map.traverse_selected_portal()
	await _frames(tree,2)
	_check(map.is_portal_open(&"snow.weapon_storage.down") and (entry["node"] as Node3D).visible and not (entry["cover"] as Node3D).visible,"original three pushes reveal the recessed stairs")
	session.hidden_passages().advance(11.0)
	await _frames(tree,2)
	_check(not (entry["node"] as Node3D).visible and (entry["cover"] as Node3D).visible,"expiry restores floor cover")
	session.shared_ui().dismiss_current_panel()

func _click(tree: SceneTree, button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tree.root.push_input(click,true)
	click.pressed = false
	tree.root.push_input(click,true)

func _clear_floor(map: WorldMapController, zone: StringName) -> Vector2:
	var area: Rect2 = MapPlaces.zone_rect(map,zone).grow(-80)
	var grid: WorldNpcWalker.Grid = MapRoute.grid(map,MapPlaces.npc_bodies(map))
	var candidates: Array[Vector2] = []
	for y: int in range(int(area.position.y),int(area.end.y),32):
		for x: int in range(int(area.position.x),int(area.end.x),32):
			var at := Vector2(x,y)
			var clear: bool = true
			for dy: int in [-40,0,40]:
				for dx: int in [-40,0,40]:
					var cell: Vector2i = grid.cell_of(at+Vector2(dx,dy))
					clear = clear and grid._astar.is_in_boundsv(cell) and not grid._astar.is_point_solid(cell)
			if clear:
				candidates.append(at)
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(area.get_center())<b.distance_squared_to(area.get_center()))
	return candidates[0] if not candidates.is_empty() else Vector2.INF

func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
